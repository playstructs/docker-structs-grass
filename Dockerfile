# Base image
FROM ubuntu:24.04

# Information
LABEL maintainer="Slow Ninja <info@slow.ninja>"

# Variables
ENV DEBIAN_FRONTEND=noninteractive \
      PG_CHANNEL='GRASS' \
      NAT_HOST="" \
      PG_CONNECTION=""

# Install packages
RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y \
        git \
        golang \
        &&  \
    rm -rf /var/lib/apt/lists/*

ENV PATH=$PATH:/usr/local/go/bin

# Building latest structsd
RUN git clone https://github.com/playstructs/structs-grass.git && \
    cd structs-grass && \
    go build -o /usr/local/go/bin/grass grass.go

# Run Structs
CMD ["sh", "-c", "grass -channel $PG_CHANNEL -dbhost $PG_CONNECTION -nathost $NAT_HOST"]
