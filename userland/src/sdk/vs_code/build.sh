#!/bin/sh
set -e

apk update && apk add --no-cache \
    ca-certificates \
    libstdc++

# TARGETARCH values: amd64, arm64, etc.
# code-server uses: amd64 -> x64, arm64 -> arm64
case "${TARGETARCH}" in
    amd64)
        CODESERVER_ARCH="x64"
        ;;
    arm64)
        CODESERVER_ARCH="arm64"
        ;;
    *)
        echo "Unsupported architecture: ${TARGETARCH}"
        exit 1
        ;;
esac

VERSION="4.105.1"
TARBALL="code-server-${VERSION}-linux-${CODESERVER_ARCH}.tar.gz"
CACHE_PATH="/tmp/src/sdk/vs_code/cache/${TARBALL}"

echo "Installing code-server ${VERSION} for ${CODESERVER_ARCH} (TARGETARCH=${TARGETARCH})"

# Check if cached file exists
if [ ! -f "${CACHE_PATH}" ]; then
    echo "ERROR: Cached tarball not found at ${CACHE_PATH}"
    echo "Please download it first with:"
    echo "  curl -L -o userland/src/sdk/vs_code/cache/${TARBALL} https://github.com/coder/code-server/releases/download/v${VERSION}/${TARBALL}"
    exit 1
fi

# Extract to /usr/local
mkdir -p /usr/local/lib /usr/local/bin
tar -C /usr/local/lib -xzf "${CACHE_PATH}"
mv -f /usr/local/lib/code-server-${VERSION}-linux-${CODESERVER_ARCH} /usr/local/lib/code-server-${VERSION}
ln -fs /usr/local/lib/code-server-${VERSION}/bin/code-server /usr/local/bin/code-server

echo "code-server installed successfully to /usr/local/bin/code-server"