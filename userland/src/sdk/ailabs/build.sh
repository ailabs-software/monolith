#!/bin/sh

set -e

mkdir /opt/monolith/userland/sdk/ailabs
mkdir /opt/monolith/userland/sdk/ailabs/bin

cp /tmp/src/sdk/ailabs/fetch_repos.sh /opt/monolith/userland/sdk/ailabs/bin/fetch_repos.sh
cp /tmp/src/sdk/ailabs/fetch_dart_pub.sh /opt/monolith/userland/sdk/ailabs/bin/fetch_dart_pub.sh

# build cook
cd /opt/ailabs/source/tools/cook/
/opt/monolith/core/dart_sdk/bin/dart pub get
/opt/monolith/core/dart_sdk/bin/dart compile exe main.dart -o /opt/monolith/userland/sdk/ailabs/bin/cook
