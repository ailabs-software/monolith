#!/bin/sh

# Copy in monolith start script
cp /tmp/src/init/monolith.sh /opt/monolith/monolith.sh
chmod +x /opt/monolith/monolith.sh
cp /tmp/src/init/monolith_userland_startup.sh /opt/monolith/userland/system/monolith_userland_startup.sh
chmod +x /opt/monolith/userland/system/monolith_userland_startup.sh
