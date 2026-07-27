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

export PATH="$SCRIPT_DIR/bin:$PATH"
echo "Added $SCRIPT_DIR/bin to PATH"
