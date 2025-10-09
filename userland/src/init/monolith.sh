#!/bin/sh

# run core in first
/opt/monolith/core/init.sh

# copy over dart sdk TODO FIXME use hardlinks
cp -r /opt/monolith/core/dart_sdk /opt/monolith/userland/dart_sdk

# add libs & executables inside chroot
cp -r /lib/* /opt/monolith/userland/lib/
cp -r /usr /opt/monolith/userland/usr
cp -r /usr/local/lib/* /opt/monolith/userland/usr/local/lib/
cp -r /usr/lib/* /opt/monolith/userland/usr/lib/
cp /usr/bin/node /opt/monolith/userland/usr/bin/node
/opt/monolith/core/dart_sdk/bin/dartaotruntime /opt/monolith/core/bin/set_access.aot "/usr/**" readable
/opt/monolith/core/dart_sdk/bin/dartaotruntime /opt/monolith/core/bin/set_access.aot "/system/bin/**" readable

# monolith running inside userland chroot under standard access
# start the first userland process with standard access
/opt/monolith/core/dart_sdk/bin/dartaotruntime /opt/monolith/core/bin/execute_as.aot standard /system/monolith_userland_startup.sh
