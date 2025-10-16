#!/bin/sh

set -e

mkdir /opt/monolith/userland/system/frames/
# copy in frames
cp -r /tmp/src/frames/src/* /opt/monolith/userland/system/frames/