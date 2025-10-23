#!/bin/sh

set -e

mkdir /opt/monolith/userland/sdk/ailabs
mkdir /opt/monolith/userland/sdk/ailabs/bin

cp /tmp/src/sdk/ailabs/fetch_repos.sh /opt/monolith/userland/sdk/ailabs/bin/fetch_repos.sh
cp /tmp/src/sdk/ailabs/recursive_dart_pub_get.sh /opt/monolith/userland/sdk/ailabs/bin/recursive_dart_pub_get.sh
