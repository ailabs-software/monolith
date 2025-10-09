#!/bin/sh

apk update && apk add --no-cache \
    nodejs \
    npm

mkdir /opt/monolith/userland/system/node_js
mkdir /opt/monolith/userland/system/node_js/bin

# hard link into place
ln /usr/bin/node /opt/monolith/userland/system/node_js/bin/node.exe
ln /usr/bin/npm /opt/monolith/userland/system/node_js/bin/npm.exe