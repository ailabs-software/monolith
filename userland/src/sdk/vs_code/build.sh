#!/bin/sh

apk update && apk add --no-cache \
    curl \
    ca-certificates \
    libstdc++ \
    libc6-compat

# Use local install.sh if available, otherwise download
if [ -f "/tmp/src/sdk/vs_code/install.sh" ]; then
    echo "Using local install.sh"
    sh /tmp/src/sdk/vs_code/install.sh --method=standalone --prefix=/usr/local
else
    curl -fsSL https://code-server.dev/install.sh | sh -s -- --method=standalone --prefix=/usr/local
fi
