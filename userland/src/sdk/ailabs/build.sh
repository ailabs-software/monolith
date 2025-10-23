#!/bin/sh

set -e

mkdir /opt/monolith/userland/sdk/ailabs
mkdir /opt/monolith/userland/sdk/ailabs/bin

cp /tmp/src/sdk/ailabs/fetch_repos.sh /opt/monolith/userland/sdk/ailabs/bin/fetch_repos.sh
cp /tmp/src/sdk/ailabs/fetch_dart_pub.sh /opt/monolith/userland/sdk/ailabs/bin/fetch_dart_pub.sh
