# docker-structs-grass

[Docker](https://www.docker.com) container for running the [Guild Rapid Alert System Stream](https://github.com/playstructs/structs-grass).

Docker Hub: [https://hub.docker.com/r/structs/structs-grass/](https://hub.docker.com/r/structs/structs-grass/)

## Structs
In the distant future the species of the galaxy are embroiled in a race for Alpha Matter, the rare and dangerous substance that fuels galactic civilization. Players take command of Structs, a race of sentient machines, and must forge alliances, conquer enemies and expand their influence to control Alpha Matter and the fate of the galaxy.

# How to Build

```
git clone git@github.com:playstructs/docker-structs-grass.git
cd docker-structs-grass
docker build --build-arg GRASS_REF="${GRASS_REF:?set GRASS_REF to the relay commit}" -t structs-grass:candidate .
```

Use a commit from the structs-grass remote when building a release candidate.
Run the relay integration check against the built image. It uses disposable
PostgreSQL and NATS containers, tests ordered delivery through a burst and a
135-second broker outage, then terminates the test LISTEN session and verifies
the delivery probe after resubscription.

```sh
python3 tests/relay.py structs-grass:candidate
```

# How to Use this Image

## Quickstart

Set `PG_CHANNEL`, `PG_CONNECTION` and `NAT_HOST` in a private env file.
Choose a Docker network from which both PostgreSQL and NATS are reachable
and set `GRASS_NETWORK` to its name.

```
docker run -d --rm --name=structs-grass --network "$GRASS_NETWORK" --env-file .env.grass structs/structs-grass:latest
```

## Interactive

To follow the running relay:

```
docker logs -f structs-grass
```

# Learn more

- [Structs](https://playstructs.com)
- [Project Wiki](https://watt.wiki)
- [@PlayStructs Twitter](https://twitter.com/playstructs)


# License

Copyright 2021 [Slow Ninja Inc](https://slow.ninja).

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

[http://www.apache.org/licenses/LICENSE-2.0](http://www.apache.org/licenses/LICENSE-2.0)

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.