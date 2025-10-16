#!/bin/sh

set -e

apk update && apk add --no-cache \
    nodejs \
    npm

mkdir /opt/monolith/userland/system/node_js
mkdir /opt/monolith/userland/system/node_js/bin

# hard link into place
ln /usr/bin/node /opt/monolith/userland/system/node_js/bin/node.exe
