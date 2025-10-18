#!/bin/sh

set -e

apk update && apk add --no-cache bash

mkdir /opt/monolith/userland/sdk/bash
mkdir /opt/monolith/userland/sdk/bash/lib
mkdir /opt/monolith/userland/sdk/bash/bin

# hard link into place
ln /bin/bash /opt/monolith/userland/sdk/bash/lib/bash.exe
cp /tmp/src/sdk/bash/compat.sh /opt/monolith/userland/sdk/bash/lib/compat.sh
cp /tmp/src/sdk/bash/bash.alias /opt/monolith/userland/sdk/bash/bin/bash.alias
