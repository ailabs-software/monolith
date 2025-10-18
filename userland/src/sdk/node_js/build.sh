#!/bin/sh

set -e

apk update && apk add --no-cache \
    nodejs \
    npm

mkdir /opt/monolith/userland/sdk/node_js
mkdir /opt/monolith/userland/sdk/node_js/bin

# hard link into place
ln /usr/bin/node /opt/monolith/userland/sdk/node_js/bin/node.exe
