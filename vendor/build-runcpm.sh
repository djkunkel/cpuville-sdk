#!/bin/sh
#
# Build script for RunCPM (CP/M 2.2 Z80 emulator from
# https://github.com/MockbaTheBorg/RunCPM). RunCPM boots a full CP/M
# system with an internal CCP and uses host folders as disk drives,
# making it convenient for testing .com programs before transferring
# them to the Cpuvulle Z80.
#
# Built with STREAMIO support so the -s flag connects stdin/stdout
# directly, enabling automated testing with piped input:
#
#   printf "fprime\n30\n" | runcpm -s
#
# A patch to console.h fixes _chready() in STREAMIO mode: instead of
# always returning 0xFF (char ready), it peeks at the stream with
# fgetc()/ungetc() so that programs polling for console status (e.g.
# z88dk's getk() for CTRL-C handling) don't drain the pipe and abort
# on EOF. After stdin EOF, status checks return 0 (no char) and the
# program continues running normally.
#
# Upstream source under vendor/runcpm/ is fetched by vendor/clone.sh.
# This script builds it in place and copies the binary to ../bin/.
#
# Usage:
#   . ./env.sh
#   vendor/build-runcpm.sh
#
set -e

cd "$(dirname "$0")"            # -> vendor/

CC=${CC:-gcc}
CFLAGS=${CFLAGS:-"-Wall -O3 -fPIC -Wno-unused-variable -DSTREAMIO"}

VENDOR_DIR="$(pwd)"
SRC_DIR="$VENDOR_DIR/runcpm/RunCPM"
BIN_DIR="$(cd "$(pwd)/../bin" && pwd)"
PATCH="$VENDOR_DIR/runcpm-streamio-console-fix.patch"

if [ ! -d "$SRC_DIR" ]; then
    echo "Error: $SRC_DIR not found. Run 'sh vendor/clone.sh' first." >&2
    exit 1
fi

mkdir -p "$BIN_DIR"

# Apply the STREAMIO console fix patch (see comment at top of this file).
# The patch is kept in vendor/runcpm-streamio-console-fix.patch so it
# survives across clone.sh re-fetches of the upstream source.
cd "$SRC_DIR"
git apply "$PATCH" 2>/dev/null || true

rm -f *.o RunCPM

CFLAGS="$CFLAGS" make -f Makefile.posix CCP=INTERNAL

cp -f RunCPM "$BIN_DIR/runcpm"

# Set up a minimal disk A: with user area 0 for .com files.
# RunCPM chdir's to its own directory at startup and looks for A/ there.
mkdir -p "$BIN_DIR/A/0"

echo "Built and copied runcpm to $BIN_DIR/runcpm"
echo "Disk folder: $BIN_DIR/A/0/ (copy .COM files here, uppercase)"
