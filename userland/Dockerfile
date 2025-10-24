FROM monolith_core:latest

# build userland

COPY src /tmp/src
COPY --from=common . /tmp/src/common/
RUN mkdir -p /opt/ailabs/
COPY --from=ailabs_source . /opt/ailabs/source

RUN mkdir /opt/monolith/userland
RUN mkdir /opt/monolith/userland/system

# copy over glibc, etc -- TODO come up with a better way. Hardlinks? TODO better path
RUN mkdir -p /opt/monolith/userland/lib/ && \
    mkdir -p /opt/monolith/userland/usr/ && \
    ln /lib/ld-linux-aarch64.so.1 /opt/monolith/userland/lib/ld-linux-aarch64.so.1 && \
    cp /lib/ld-musl-*.so.1 /opt/monolith/userland/lib/ && \
    cp /lib/libc.musl-*.so.1 /opt/monolith/userland/lib/ && \
    cp -r /usr/* /opt/monolith/userland/usr/

# hardlink dart sdk into userland
RUN mkdir -p /opt/monolith/userland/system/dart_sdk/bin/ && \
    ln /opt/monolith/core/dart_sdk/bin/dartaotruntime /opt/monolith/userland/system/dart_sdk/bin/dartaotruntime

# /tmp is needed in userland chroot
RUN mkdir /opt/monolith/userland/tmp

# build userland
WORKDIR /tmp/src/
RUN /tmp/src/init/build.sh
RUN /tmp/src/commands/build.sh
RUN /tmp/src/frames/build.sh
# build userland sdk
RUN mkdir /opt/monolith/userland/sdk/
RUN /tmp/src/sdk/trusted_commands/build.sh
RUN /tmp/src/sdk/node_js/build.sh
RUN /tmp/src/sdk/bash/build.sh
RUN /tmp/src/sdk/vs_code/build.sh
RUN /tmp/src/sdk/ailabs/build.sh

# Make all files in userland accessible as read only standard access
RUN /opt/monolith/core/dart_sdk/bin/dartaotruntime /opt/monolith/core/bin/set_access.aot "**" readable

# clean up -- TODO remove source from final image FFS
RUN rm -rf /tmp/src && \
    rm -rf /opt/ailabs

WORKDIR /

# we run terminal.aot on port 80
EXPOSE 80
# we run vs code server on port 8080
EXPOSE 8080

# run monolith
CMD ["/opt/monolith/monolith.sh"]
