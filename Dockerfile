# Base image
FROM ubuntu:24.04

# Information
LABEL maintainer="Slow Ninja <info@slow.ninja>"

# Variables
ENV DEBIAN_FRONTEND=noninteractive \
      PG_CHANNEL='grass' \
      NAT_HOST="" \
      PG_CONNECTION=""

# Install packages
RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y \
        git \
        golang \
        postgresql-client \
        curl \
        unzip \
        &&  \
    rm -rf /var/lib/apt/lists/*

ENV PATH=$PATH:/usr/local/go/bin

# Install NATS CLI
RUN NATS_VERSION=$(curl -s https://api.github.com/repos/nats-io/natscli/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/') && \
    curl -L "https://github.com/nats-io/natscli/releases/download/${NATS_VERSION}/nats-${NATS_VERSION}-linux-amd64.zip" -o /tmp/nats.zip && \
    unzip /tmp/nats.zip -d /tmp && \
    mv /tmp/nats-${NATS_VERSION}-linux-amd64/nats /usr/local/bin/nats && \
    chmod +x /usr/local/bin/nats && \
    rm -rf /tmp/nats.zip /tmp/nats-${NATS_VERSION}-linux-amd64

# Building latest structsd
RUN git clone https://github.com/playstructs/structs-grass.git && \
    cd structs-grass && \
    go build -o /usr/local/go/bin/grass grass.go

# Copy scripts
COPY scripts/ /scripts/
RUN chmod +x /scripts/*.sh

# Run Structs
CMD ["sh", "-c", "grass -channel $PG_CHANNEL -dbhost $PG_CONNECTION -nathost $NAT_HOST"]
