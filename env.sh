#!/bin/sh
# Source this file to put the project's bin/ directory on PATH so the
# Z80 tooling (zmac, etc.) is available from any shell:
#
#     . ./env.sh         # or: source ./env.sh
#
# Running it directly (./env.sh) cannot modify your shell's environment.

# When sourced, $0 is the invoking shell; when executed, $0 is this script.
# Refuse to run silently in the latter case so users aren't confused.
case "$0" in
  *env.sh)
    printf 'env.sh must be sourced, not executed.\n' >&2
    printf 'Run:  . ./env.sh   (or: source ./env.sh)\n' >&2
    exit 1
    ;;
esac

# Resolve this script's directory (works when sourced from bash or sh).
_env_sh_dir() {
  # shellcheck disable=SC2086
  cd "$(dirname -- "${BASH_SOURCE[0]:-$0}")" && pwd
}
SCRIPT_DIR="$(_env_sh_dir)"
unset -f _env_sh_dir

# Bring in z88dk's tooling (zcc, z80asm-legacy, etc.) by sourcing its
# own set_environment.sh, which prepends vendor/z88dk/bin to PATH and
# exports ZCCCFG (the config dir zcc needs at runtime). That script is
# written to be sourced from inside vendor/z88dk (it uses `pwd`), so we
# cd there first, source it, then restore the working directory.
#
# We source z88dk BEFORE prepending the project bin so that the project's
# wrappers (bzmac, bz80asm, runmon, ...) end up ahead of z88dk's tools in
# PATH, giving them precedence over any name collisions (e.g. z80asm).
Z88DK_DIR="$SCRIPT_DIR/vendor/z88dk"
if [ -f "$Z88DK_DIR/set_environment.sh" ]; then
  _saved_pwd=$(pwd)
  cd "$Z88DK_DIR"
  . ./set_environment.sh
  cd "$_saved_pwd"
  unset _saved_pwd
  echo "Added $Z88DK_DIR/bin to PATH (and set ZCCCFG=$ZCCCFG)"
else
  echo "Warning: $Z88DK_DIR/set_environment.sh not found; z88dk tools not on PATH" >&2
fi
unset Z88DK_DIR

export PATH="$SCRIPT_DIR/bin:$PATH"
echo "Added $SCRIPT_DIR/bin to PATH"
