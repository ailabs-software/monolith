#!/usr/bin/env bash

set -e

docker build -t monolith_core --progress=plain --build-context common=common/ core/

docker build -t monolith --progress=plain --build-context common=common/ --build-context ailabs_source=/opt/ailabs/source/ userland/
