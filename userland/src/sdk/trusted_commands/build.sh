# !/bin/sh

# stop on error
set -e

# bin dir
mkdir /opt/monolith/userland/sdk/trusted
mkdir /opt/monolith/userland/sdk/trusted/bin

# install git and docker
apk add --no-cache git docker-cli docker-cli-compose

# build trusted commands
cd /tmp/src/sdk/trusted_commands/
/opt/monolith/core/dart_sdk/bin/dart pub get
/opt/monolith/core/dart_sdk/bin/dart compile aot-snapshot lib/git.dart -o /opt/monolith/userland/sdk/trusted/bin/git.aot
/opt/monolith/core/dart_sdk/bin/dart compile aot-snapshot lib/dart.dart -o /opt/monolith/userland/sdk/trusted/bin/dart.aot
/opt/monolith/core/dart_sdk/bin/dart compile aot-snapshot lib/access.dart -o /opt/monolith/userland/sdk/trusted/bin/access.aot
/opt/monolith/core/dart_sdk/bin/dart compile aot-snapshot lib/docker.dart -o /opt/monolith/userland/sdk/trusted/bin/docker.aot
# set trusted bit
/opt/monolith/core/dart_sdk/bin/dartaotruntime /opt/monolith/core/bin/set_trusted_executable.aot /sdk/trusted/bin/access.aot "1"
/opt/monolith/core/dart_sdk/bin/dartaotruntime /opt/monolith/core/bin/set_trusted_executable.aot /sdk/trusted/bin/dart.aot "1"
/opt/monolith/core/dart_sdk/bin/dartaotruntime /opt/monolith/core/bin/set_trusted_executable.aot /sdk/trusted/bin/docker.aot "1"
/opt/monolith/core/dart_sdk/bin/dartaotruntime /opt/monolith/core/bin/set_trusted_executable.aot /sdk/trusted/bin/git.aot "1"
# set access level invisible on access tool (is root only)
/opt/monolith/core/dart_sdk/bin/dartaotruntime /opt/monolith/core/bin/set_access.aot /sdk/trusted/bin/access.aot "invisible"