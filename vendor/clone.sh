#!/bin/sh
# Fetch vendored upstream source trees that are NOT committed to this
# repository. Currently that is z88dk and tnylpo.
#
# z88dk uses git submodules (optparse, regex, Unity, UNIXem, uthash under
# ext/), so it must be cloned with --recursive.
# tnylpo is a CP/M 2.2 emulator that integrates CP/M programs into the
# Unix command line (runs .com files directly, no CCP/disk images).
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
TNYLPO_URL="https://gitlab.com/gbrein/tnylpo.git"

if [ -e z88dk ]; then
  printf 'vendor/z88dk already exists; skipping clone.\n' >&2
  printf 'To re-clone, remove it first:  rm -rf vendor/z88dk\n' >&2
else
  printf 'Cloning z88dk (with submodules) at latest master...\n'
  git clone --recursive "$Z88DK_URL" z88dk
  printf 'Done. z88dk source is in vendor/z88dk.\n'
  printf 'Next: sh vendor/z88dk/build.sh\n'
fi

if [ -e tnylpo ]; then
  printf 'vendor/tnylpo already exists; skipping clone.\n' >&2
  printf 'To re-clone, remove it first:  rm -rf vendor/tnylpo\n' >&2
else
  printf 'Cloning tnylpo at latest master...\n'
  git clone "$TNYLPO_URL" tnylpo
  printf 'Done. tnylpo source is in vendor/tnylpo.\n'
  printf 'Next: sh vendor/build-tnylpo.sh\n'
fi

printf '\nRun . ./env.sh to put built tools on PATH.\n'
