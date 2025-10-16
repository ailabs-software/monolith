# !/bin/sh

set -e

# bin dir
mkdir /opt/monolith/userland/system/bin

# build userland /system/bin/ (commands)
cd /tmp/src/commands/
/opt/monolith/core/dart_sdk/bin/dart pub get
/opt/monolith/core/dart_sdk/bin/dart compile aot-snapshot lib/terminal.dart -o /opt/monolith/userland/system/bin/terminal.aot
/opt/monolith/core/dart_sdk/bin/dart compile aot-snapshot lib/shell.dart -o /opt/monolith/userland/system/bin/shell.aot
/opt/monolith/core/dart_sdk/bin/dart compile aot-snapshot lib/clear.dart -o /opt/monolith/userland/system/bin/clear.aot
/opt/monolith/core/dart_sdk/bin/dart compile aot-snapshot lib/echo.dart -o /opt/monolith/userland/system/bin/echo.aot

# provide standard commands
ln /bin/busybox /opt/monolith/userland/system/bin/busybox.exe
chmod +x /opt/monolith/userland/system/bin/busybox.exe
# copy in command aliases
cp lib/*.alias /opt/monolith/userland/system/bin/
