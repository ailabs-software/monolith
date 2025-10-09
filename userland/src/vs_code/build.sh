#!/bin/sh

apk update && apk add --no-cache \
    curl \
    ca-certificates \
    libstdc++ \
    libc6-compat

# Download and install pre-built code-server binary
curl -fsSL https://code-server.dev/install.sh | sh -s -- --method=standalone --prefix=/usr/local
