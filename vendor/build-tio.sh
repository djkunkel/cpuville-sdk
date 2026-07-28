#!/bin/sh
# Build script for tio (the serial terminal used by console.sh). tio
# uses meson + ninja, so we configure a private build directory, compile,
# and copy the resulting binary into ../bin (the project bin folder
# added to PATH by env.sh). We do NOT run `meson install`, which would
# install to the system; only the binary is needed.
#
# Upstream: https://github.com/tio/tio
# The source under vendor/tio/ is a fork tracked directly in this repo.
set -e

cd "$(dirname "$0")"            # -> vendor/

SRC_DIR="$(pwd)/tio"
BIN_DIR="$(pwd)/../bin"
BUILD_DIR="$SRC_DIR/build"

mkdir -p "$BIN_DIR"

# Configure once. meson regenerates build.ninja when sources change, so
# a plain `meson compile` is enough for incremental rebuilds.
if [ ! -f "$BUILD_DIR/build.ninja" ]; then
  meson setup "$BUILD_DIR" "$SRC_DIR" \
    --buildtype=release \
    -Dinstall_man_pages=false \
    -Dbashcompletiondir=no
fi

# Compile
meson compile -C "$BUILD_DIR"

# Install into ../bin (meson places the binary under build/src/)
cp -f "$BUILD_DIR/src/tio" "$BIN_DIR/"
echo "Built and copied tio to $BIN_DIR/tio"
