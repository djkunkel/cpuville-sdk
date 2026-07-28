#!/bin/sh
# Fetch vendored upstream source trees that are NOT committed to this
# repository. Currently that is z88dk and RunCPM.
#
# z88dk uses git submodules (optparse, regex, Unity, UNIXem, uthash under
# ext/), so it must be cloned with --recursive.
# RunCPM is a standalone CP/M 2.2 emulator.
#
# Run from anywhere; sources are placed in vendor/<tool>/ next to this
# script:
#
#     sh vendor/clone.sh
#
# Tracks the latest upstream master. If a newer commit breaks the build,
# we deal with that ourselves rather than pinning.
# After cloning, build with the respective build-*.sh and source env.sh
# to put the resulting tools on PATH.

set -e

cd "$(dirname "$0")"            # -> vendor/

Z88DK_URL="https://github.com/z88dk/z88dk.git"
RUNCPM_URL="https://github.com/MockbaTheBorg/RunCPM.git"

if [ -e z88dk ]; then
  printf 'vendor/z88dk already exists; skipping clone.\n' >&2
  printf 'To re-clone, remove it first:  rm -rf vendor/z88dk\n' >&2
else
  printf 'Cloning z88dk (with submodules) at latest master...\n'
  git clone --recursive "$Z88DK_URL" z88dk
  printf 'Done. z88dk source is in vendor/z88dk.\n'
  printf 'Next: sh vendor/z88dk/build.sh\n'
fi

if [ -e runcpm ]; then
  printf 'vendor/runcpm already exists; skipping clone.\n' >&2
  printf 'To re-clone, remove it first:  rm -rf vendor/runcpm\n' >&2
else
  printf 'Cloning RunCPM at latest master...\n'
  git clone --depth 1 "$RUNCPM_URL" runcpm
  printf 'Done. RunCPM source is in vendor/runcpm.\n'
  printf 'Next: sh vendor/build-runcpm.sh\n'
fi

printf '\nRun . ./env.sh to put built tools on PATH.\n'
