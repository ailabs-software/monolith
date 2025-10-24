# -------- Stage 1: Minimal environment to run fuse / dartaotruntime / dart_sdk --------
FROM --platform=$TARGETARCH frolvlad/alpine-glibc:alpine-3.21_glibc-2.41 AS build_stage

# TODO wire up target arch
ARG TARGETARCH
ARG DART_VERSION='3.9.3'

# Environment variables for building monolith core
ENV CORE_PATH="/opt/monolith/core"
ENV DART_SDK_PATH="$CORE_PATH/dart_sdk"

# Add gcc, FUSE, linux-headers for fuse.h
# installs fuse3-dev-3.16.2-r1
RUN apk add --no-cache gcc pkgconfig fuse3-dev linux-headers musl-dev

# build monolith/core/src to /opt/monolith/core/bin
RUN mkdir -p "$CORE_PATH/bin"

# Download and install Dart SDK
RUN apk add --no-cache wget unzip
RUN wget --tries=5 https://storage.googleapis.com/dart-archive/channels/stable/release/${DART_VERSION}/sdk/dartsdk-linux-arm64-release.zip -O /tmp/dart_sdk.zip \
    && unzip /tmp/dart_sdk.zip -d "$CORE_PATH" \
    && mv "$CORE_PATH/dart-sdk" "$DART_SDK_PATH" \
    && rm /tmp/dart_sdk.zip

# copy in source to build
COPY src /tmp/src
COPY --from=common . /tmp/src/common/

# build our custom chroot
WORKDIR /tmp/src/chroot
RUN gcc -Wall -Wextra -g -o "$CORE_PATH/bin/monolith_chroot" main.c

# build fuse file system driver (c)
WORKDIR /tmp/src/file_system/lib/driver
RUN gcc -Wall monolith_fs_driver.c request.c cjson/cJSON.c `pkg-config fuse3 --cflags --libs` -o "$CORE_PATH/bin/monolith_fs_driver"


# build core's file system
WORKDIR /tmp/src/file_system/
RUN "$DART_SDK_PATH/bin/dart" pub get
RUN "$DART_SDK_PATH/bin/dart" compile aot-snapshot lib/monolith_file_system/main.dart -o "$CORE_PATH/bin/monolith_file_system.aot"
RUN "$DART_SDK_PATH/bin/dart" compile aot-snapshot lib/tools/set_access.dart -o "$CORE_PATH/bin/set_access.aot"
RUN "$DART_SDK_PATH/bin/dart" compile aot-snapshot lib/tools/set_trusted_executable.dart -o "$CORE_PATH/bin/set_trusted_executable.aot"

# build core's executor service
WORKDIR /tmp/src/user_execution/
RUN "$DART_SDK_PATH/bin/dart" pub get
RUN "$DART_SDK_PATH/bin/dart" compile aot-snapshot lib/execute_as_command.dart -o "$CORE_PATH/bin/execute_as.aot"
RUN "$DART_SDK_PATH/bin/dart" compile aot-snapshot lib/user_execution_service.dart -o "$CORE_PATH/bin/user_execution_service.aot"

# Stage 2: Final runtime-only image (no sources)
FROM --platform=$TARGETARCH frolvlad/alpine-glibc:alpine-3.21_glibc-2.41

# Final environment variables
ENV CORE_PATH="/opt/monolith/core"
ENV DART_SDK_PATH="$CORE_PATH/dart_sdk"
ENV DART_AOT_RUNTIME="$DART_SDK_PATH/bin/dartaotruntime"

COPY --from=build_stage /opt/monolith /opt/monolith

# Install runtime dependencies only
RUN apk add --no-cache fuse3-dev util-linux

# Copy in init script
COPY init.sh "$CORE_PATH/init.sh"
RUN chmod +x "$CORE_PATH/init.sh"
# Copy in userlist.json file
COPY userlist.json "$CORE_PATH/userlist.json"

# copy in secrets
COPY secrets/ /opt/monolith/secrets/

# The image contains only the Dart SDK and built binaries


