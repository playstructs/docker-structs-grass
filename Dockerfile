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
        &&  \
    rm -rf /var/lib/apt/lists/*

ENV PATH=$PATH:/usr/local/go/bin:/root/go/bin

# Install NATS CLI
RUN go install github.com/nats-io/natscli/nats@latest

# Building latest structsd
RUN git clone https://github.com/playstructs/structs-grass.git && \
    cd structs-grass && \
    go build -o /usr/local/go/bin/grass grass.go

# Copy scripts
COPY scripts/ /scripts/
RUN chmod +x /scripts/*.sh

# Run Structs
CMD ["sh", "-c", "grass -channel $PG_CHANNEL -dbhost $PG_CONNECTION -nathost $NAT_HOST"]
