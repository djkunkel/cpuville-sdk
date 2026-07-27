# Serial Console Sharing — Design Plan

## Problem

`/dev/ttyUSB0` is a single character device. The kernel hands each
incoming byte to whichever process reads first, so two simultaneous
readers (e.g. `tio` via `console.sh` + `cpmget`/`cpmput`) silently split
the stream. This caused a real failure during the 32K end-to-end test:
with `tio` attached, `cpmget` received only 3584 of 32768 bytes because
`tio` was stealing blocks in the background, yet `cpmget` reported
"transfer complete" (pcput had sent EOT after its own retries exhausted).

The development workflow needs the console terminal *except* during
file transfers, so "just don't run tio" is workable but fragile. We
want something better.

## Constraint

The Cpuvulle Z80 uses a single **M82C51A-2 UART** with one serial port
(I/O `0x02` data / `0x03` control). `pcput.asm` defines a port B
(`0x12/0x13`) in its equates, but **no second port is wired on this
board**. So a two-port split (console on A, XMODEM on B) is not a
software-only fix and is off the table for now. Any solution must work
over the single existing `/dev/ttyUSB0`.

## Options

### A. Detection + clear error (safety net only)

`cpmget`/`cpmput` use `flock` or `fuser` to refuse to run while another
process (tio) holds the serial device, printing a message like
"console is attached to /dev/ttyUSB0 — disconnect it first."

- **Pros:** ~10 lines, prevents the silent-corruption footgun, no
  behavior change to the existing workflow.
- **Cons:** Still manual: quit tio, run transfer, relaunch tio. Doesn't
  reduce friction, only prevents data loss.
- **Cost:** Trivial.
- **When to pick:** As an immediate safety net regardless of which
  larger option is chosen later.

### B. Auto-manage tio's lifecycle

`console.sh` writes its tio PID to a well-known file (e.g.
`/tmp/z80-console.pid`). `cpmget`/`cpmput` send that tio `SIGTERM`,
perform the transfer, then relaunch tio in the background. The Z80
keeps running across the swap — only tio's scrollback and any in-flight
typing is lost.

- **Pros:** Single command does the right thing; user never has to
  remember to close tio. Medium complexity.
- **Cons:** If you're mid-typing a CP/M command when cpmget fires, that
  input is interrupted. Relaunching tio from inside a script is awkward
  — which terminal window does it land in? Needs a notion of "the
  console's parent terminal" or a launcher wrapper. PID file can go
  stale if tio dies uncleanly.
- **Cost:** ~30 min, ~50-80 lines across console.sh + cpmget/cpmput.
- **When to pick:** Pragmatic improvement; you're okay with tio
  restarting (possibly in a different window) as long as you don't have
  to do it by hand.

### C. Serial multiplexer daemon

A small Python daemon owns `/dev/ttyUSB0` exclusively and exposes a
Unix socket. `console.sh` connects via a pty bridge (socat or our own
minimal client) so tio sees a normal tty. `cpmget`/`cpmput` connect to
the same socket and request "exclusive transfer mode"; the daemon
pauses console forwarding during the transfer and resumes after.
Non-protocol bytes the Z80 emits during a transfer (e.g. pcput's
"Transfer Complete") get tee'd to the console client too.

- **Pros:** Best UX — you literally never close tio. Console scrollback
  is preserved. Z80-side status messages still surface during
  transfers. Roughly what `ser2net`/`picocom` ecosystems do, tailored
  to our XMODEM case.
- **Cons:** Most work. A daemon to write and debug, plus a bridge for
  tio. New moving part that must be running for the workflow to work.
  Failure modes if the daemon dies.
- **Cost:** ~150-250 lines of daemon + a pty bridge. Half a day.
- **When to pick:** Long-term right answer if you're going to be doing
  a lot of transfer-heavy development and want zero friction.

### D. Second serial port — REJECTED

`pcput.asm` defines 2SIO port B (`0x12/0x13`), and in principle we
could put XMODEM on port B and the console on port A for zero
contention. **However, the Cpuvulle Z80 uses a single M82C51A-2 UART
with one port. Port B is not wired.** This option is documented only to
record that it was considered and rejected on hardware grounds.

## Complement (orthogonal to A/B/C): tee non-protocol bytes to stderr

Regardless of which option is chosen, `cpmget`/`cpmput` could tee any
non-protocol bytes the Z80 emits during a transfer (e.g. pcput's
"Transfer Complete", "Cannot Open File", "Transfer Aborted") to
stderr. This surfaces Z80-side status even when tio is detached, so the
user isn't flying blind during a transfer.

- **Cost:** Cheap (~20 lines in `xmodem-recv`; `sx` already prints some
  of this for `cpmput`).
- **Pairs well with:** A (makes the no-tio case less painful), B
  (covers the window while tio is down), C (redundant but harmless).

## Recommendation

1. **Land A now** — it's trivial and stops the silent-corruption footgun
   we just hit. No downside.
2. **Add the stderr tee** — cheap, useful in every scenario.
3. **Decide between B and C** based on how much transfer friction
   actually hurts. B is a quick win if "restart tio automatically" is
   good enough; C is the real fix if you want tio to stay live
   throughout. Defer until the pain is felt.
4. **D is off the table** for this hardware.

## Open questions

- For B: where should the relaunched tio land? Same TTY as the
  original? A new window? A tmux pane? Depends on how the user starts
  tio today (`./console.sh` in an arbitrary terminal).
- For C: daemon lifecycle — systemd user unit, or launched by
  `env.sh`/`console.sh` on demand?
- Does `flock` on the character device actually block a second open on
  this kernel, or do we need `fuser`-based detection? Needs a quick
  experiment before committing to option A's implementation.
