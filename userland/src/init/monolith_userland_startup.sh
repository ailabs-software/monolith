#!/bin/sh

# monolith running inside userland chroot under standard access

/system/bin/busybox.exe nohup /system/dart_sdk/bin/dartaotruntime /system/bin/terminal.aot &

# TODO -- fix fragile dependency on vs code location, TODO add &
# TODO fix authentication
/usr/bin/node /usr/local/lib/code-server-*/out/node/entry.js --bind-addr 0.0.0.0:8080 --auth none /

# wait for both processes to end before ending monolith_userland_startup.sh
#wait -n TODO FIXME