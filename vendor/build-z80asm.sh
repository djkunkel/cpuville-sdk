#!/bin/sh
# Build script for z80asm (shevek's assembler, v1.8). Compiles the
# upstream source (in z80asm/src/) and copies the resulting binary into
# ../bin (the project bin folder added to PATH by env.sh).
set -e

cd "$(dirname "$0")"            # -> vendor/

CC=${CC:-gcc}
# -Ignulib is required so <getopt.h> resolves to the bundled gnulib copy.
# -DVERSION embeds the upstream version string (read from src/VERSION).
CFLAGS=${CFLAGS:-"-O2 -Wall -Wwrite-strings -Wcast-qual -Wcast-align -Wstrict-prototypes -Wmissing-prototypes -Wmissing-declarations -Wredundant-decls -Wnested-externs -pedantic -ansi -Wshadow -W -Ignulib"}
LDFLAGS=${LDFLAGS:-""}

# Install into the project's bin/ folder (absolute path so cd z80asm/src is safe).
BIN_DIR="$(pwd)/../bin"
mkdir -p "$BIN_DIR"

cd z80asm/src

VERSION="$(cat VERSION)"

# Compile everything (matches the upstream Makefile's object list).
$CC $CFLAGS -DVERSION=\"$VERSION\" -c -o z80asm.o        z80asm.c
$CC $CFLAGS -DVERSION=\"$VERSION\" -c -o expressions.o   expressions.c
$CC $CFLAGS -DVERSION=\"$VERSION\" -c -o gnulib/getopt.o gnulib/getopt.c
$CC $CFLAGS -DVERSION=\"$VERSION\" -c -o gnulib/getopt1.o gnulib/getopt1.c

# Link
$CC $LDFLAGS -o z80asm z80asm.o expressions.o gnulib/getopt.o gnulib/getopt1.o

# Install into ../bin
cp -f z80asm "$BIN_DIR/"
echo "Built and copied z80asm to $BIN_DIR/z80asm"
