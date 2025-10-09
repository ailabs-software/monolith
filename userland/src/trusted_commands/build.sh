# !/bin/sh

# bin dir
mkdir /opt/monolith/userland/system/trusted
mkdir /opt/monolith/userland/system/trusted/bin

# install git
apk add --no-cache git

# build trusted commands
cd /tmp/src/trusted_commands/
/opt/monolith/core/dart_sdk/bin/dart pub get
/opt/monolith/core/dart_sdk/bin/dart compile aot-snapshot lib/git.dart -o /opt/monolith/userland/system/trusted/bin/git.aot
/opt/monolith/core/dart_sdk/bin/dart compile aot-snapshot lib/access.dart -o /opt/monolith/userland/system/trusted/bin/access.aot
# set trusted bit
/opt/monolith/core/dart_sdk/bin/dartaotruntime /opt/monolith/core/bin/set_trusted_executable.aot /system/trusted/bin/git.aot "1"
/opt/monolith/core/dart_sdk/bin/dartaotruntime /opt/monolith/core/bin/set_trusted_executable.aot /system/trusted/bin/access.aot "1"
# set access level invisible on access tool (is root only)
/opt/monolith/core/dart_sdk/bin/dartaotruntime /opt/monolith/core/bin/set_access.aot /system/trusted/bin/access.aot "invisible"