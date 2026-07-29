#!/bin/sh
#
# Build script for tnylpo (CP/M 2.2 Z80 emulator from
# https://gitlab.com/gbrein/tnylpo). tnylpo runs CP/M .COM files
# directly from the Unix command line — no CCP, no disk images —
# and integrates with the host filesystem. It supports piped stdin
# for automated testing, making it ideal for verifying .com programs
# before transferring them to the Cpuvulle Z80.
#
# The wrapper script bin/cpmrun invokes tnylpo with line-mode console
# (-b) so output goes to stdout and input is read from stdin.
#
# Upstream source under vendor/tnylpo/ is fetched by vendor/clone.sh.
# This script builds it in place and copies the binary to ../bin/.
# The companion tnylpo-convert (text file format converter) is also
# installed.
#
# Usage:
#   . ./env.sh
#   vendor/build-tnylpo.sh
#
set -e

cd "$(dirname "$0")"            # -> vendor/

CC=${CC:-gcc}

SRC_DIR="$(pwd)/tnylpo"
BIN_DIR="$(cd "$(pwd)/../bin" && pwd)"

if [ ! -d "$SRC_DIR" ]; then
    echo "Error: $SRC_DIR not found. Run 'sh vendor/clone.sh' first." >&2
    exit 1
fi

mkdir -p "$BIN_DIR"

cd "$SRC_DIR"
make clean 2>/dev/null || true
make CC="$CC"

cp -f tnylpo "$BIN_DIR/tnylpo"
cp -f tnylpo-convert "$BIN_DIR/tnylpo-convert"

echo "Built and copied tnylpo to $BIN_DIR/tnylpo"
echo "Also installed: $BIN_DIR/tnylpo-convert"
