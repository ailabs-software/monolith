#!/bin/sh

apk update && apk add --no-cache \
    curl \
    ca-certificates \
    libstdc++ \
    libc6-compat

echo "Using local install_vs_code.sh"
sh /tmp/src/sdk/vs_code/install_vs_code.sh --method=standalone --prefix=/usr/local
