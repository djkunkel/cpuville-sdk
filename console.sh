#!/bin/sh
# Open a serial terminal to the Cpuvulle Z80. Reads SERIAL_DEV and
# BAUD_RATE from serial.conf in the same directory as this script.
#
# ODELBS maps local line editing: O=enter sends CR, D=backspace sends DEL,
# E=escape sends ^[, L=nl sends LF, B=bothsides echo, S=strip high bit.
# Run:  ./console.sh   (or:  . ./env.sh && console.sh)

set -e

# Resolve this script's directory (works whether invoked as ./console.sh
# or via PATH after `. ./env.sh`).
_self=$0
case $_self in
  */*) ;;
  *)
    _oldifs=$IFS; IFS=:
    for _d in $PATH; do
      [ -x "${_d:-.}/$_self" ] && { _self=${_d:-.}/$_self; break; }
    done
    IFS=$_oldifs ;;
esac
SCRIPT_DIR=$(cd "$(dirname -- "$_self")" && pwd)

SERIAL_DEV=/dev/ttyUSB0
BAUD_RATE=76800
if [ -f "$SCRIPT_DIR/serial.conf" ]; then
  . "$SCRIPT_DIR/serial.conf"
fi

exec tio --map ODELBS -b "$BAUD_RATE" "$SERIAL_DEV"
