"""Exercise a candidate relay image with disposable PostgreSQL and NATS containers.

Usage: python3 tests/relay.py <candidate-image>
Requires Docker, postgres:16-alpine, and nats:latest.
"""
import json
import socket
import subprocess
import sys
import time
import uuid
from contextlib import ExitStack


def docker(*args, **kwargs):
    return subprocess.run(["docker", *args], text=True, capture_output=True,
                          check=True, timeout=60, **kwargs).stdout.strip()


def main(image):
    prefix = "grass-test-" + uuid.uuid4().hex[:10]
    net, clients = prefix + "-relay", prefix + "-clients"
    pg, broker, relay = prefix + "-pg", prefix + "-nats", prefix + "-grass"

    def sql(query):
        return docker("exec", pg, "psql", "-U", "postgres", "-XqAt",
                      "-v", "ON_ERROR_STOP=1", "-c", query)

    def burst(first, last):
        sql("SELECT pg_notify('grass', json_build_object('subject','test.seq','seq',i)::text) "
            f"FROM generate_series({first},{last}) i")

    with ExitStack() as resources:
        for network in [net, clients]:
            docker("network", "create", network)
            resources.callback(docker, "network", "rm", network)

        def start(name, *args):
            docker("run", "-d", "--name", name, *args)
            resources.callback(docker, "rm", "-fv", name)

        start(pg, "--network", net, "-e", "POSTGRES_HOST_AUTH_METHOD=trust", "postgres:16-alpine")
        start(broker, "--network", clients, "-p", "127.0.0.1::4222", "nats:latest")
        for _ in range(60):
            if subprocess.run(["docker", "exec", pg, "pg_isready", "-h", "localhost"],
                              capture_output=True).returncode == 0:
                break
            time.sleep(0.5)

        port = int(docker("port", broker, "4222/tcp").rsplit(":", 1)[1])
        sock = resources.enter_context(socket.create_connection(("127.0.0.1", port), timeout=20))
        stream = resources.enter_context(sock.makefile("rb"))
        assert stream.readline().startswith(b"INFO ")
        sock.sendall(b'CONNECT {"verbose":false}\r\nSUB test.seq 1\r\nPING\r\n')
        assert stream.readline() == b"PONG\r\n"

        def receive(first, last):
            for expected in range(first, last + 1):
                header = stream.readline()
                while header == b"PING\r\n":
                    sock.sendall(b"PONG\r\n")
                    header = stream.readline()
                fields = header.split()
                assert fields[:3] == [b"MSG", b"test.seq", b"1"], header
                msg = json.loads(stream.read(int(fields[3])))
                assert stream.read(2) == b"\r\n"
                assert msg["seq"] == expected, (expected, msg)

        start(relay, "--network", net, "-e", "PG_CHANNEL=grass",
              "-e", f"PG_CONNECTION=postgres://postgres@{pg}/postgres?application_name=grass-test",
              "-e", "NAT_HOST=nats://broker:4222", image)
        for _ in range(60):
            if sql("SELECT count(*) FROM pg_stat_activity WHERE application_name='grass-test' "
                   "AND state='idle' AND query LIKE 'LISTEN %'") == "1":
                break
            time.sleep(0.5)
        else:
            raise RuntimeError("LISTEN did not start")

        burst(1, 1)
        docker("network", "connect", "--alias", "broker", net, broker)
        receive(1, 1)
        docker("exec", relay, "/scripts/health-check.sh")
        burst(2, 10001)
        receive(2, 10001)
        print("Initial NATS outage, delivery probe and 10,000-message burst passed", flush=True)

        docker("network", "disconnect", net, broker)
        burst(10002, 20001)
        probe = subprocess.run(["docker", "exec", "-e", "HEALTH_TIMEOUT=2", relay,
                                "/scripts/health-check.sh"], timeout=10)
        assert probe.returncode == 1, probe.returncode
        time.sleep(135)
        docker("network", "connect", "--alias", "broker", net, broker)
        receive(10002, 20001)
        docker("exec", relay, "/scripts/health-check.sh")
        assert sql("SELECT pg_terminate_backend(pid) FROM pg_stat_activity "
                   "WHERE application_name='grass-test'") == "t"
        docker("exec", "-e", "HEALTH_TIMEOUT=15", relay, "/scripts/health-check.sh")
        assert docker("inspect", "-f", "{{.RestartCount}}", relay) == "0"
        print("Long broker outage, ordered backlog and PostgreSQL resubscription passed")


if __name__ == "__main__":
    main(sys.argv[1])
