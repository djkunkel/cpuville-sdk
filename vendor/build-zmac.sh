#!/bin/sh
# Build script for zmac. Generates zmac.c from zmac.y with bison,
# builds the doc tool to produce doc.inl, compiles everything, and
# copies the resulting binary into ../bin (the project bin folder).
set -e

cd "$(dirname "$0")"            # -> vendor/

CC=${CC:-gcc}
CXX=${CXX:-g++}
# Old-style C declarations () require a pre-C23 standard.
CFLAGS=${CFLAGS:-"-Wall -std=gnu11"}
CXXFLAGS=${CXXFLAGS:-"-Wall -std=gnu++11"}

# Install into the project's bin/ folder (absolute path so cd zmac/src is safe).
BIN_DIR="$(pwd)/../bin"
mkdir -p "$BIN_DIR"

cd zmac/src

# Generate doc.inl from doc.c + doc.txt
$CC $CFLAGS -DMK_DOC -o doc doc.c
./doc >/dev/null

# Convert grammar into C code
bison --output=zmac.c zmac.y

# Compile everything
$CC $CFLAGS -c -o zmac.o zmac.c
$CC $CFLAGS -c -o mio.o mio.c
$CC $CFLAGS -c -o doc.o doc.c
$CXX $CXXFLAGS -c -o zi80dis.o zi80dis.cpp

# Link
$CXX $CXXFLAGS -o zmac zmac.o mio.o doc.o zi80dis.o

# Install into ../bin
cp -f zmac "$BIN_DIR/"
echo "Built and copied zmac to $BIN_DIR/zmac"
