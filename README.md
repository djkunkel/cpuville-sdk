# z80 — SDK for the Cpuvulle Z80 machine

This repository is a self-contained development kit for writing, building, and
loading Z80 programs on the **Cpuvulle Z80** machine. It bundles two
assemblers, a ROM monitor, and host-side serial tooling under a single
`env.sh` so a developer can go from source to running hardware with one shell
on PATH.

## Quick start

```sh
. ./env.sh                 # put bin/ on PATH (zmac, z80asm, runmon, ...)
vendor/build-zmac.sh       # build & install zmac into bin/
vendor/build-z80asm.sh     # build & install z80asm into bin/
vendor/build-tio.sh        # build & install tio into bin/ (needed by console.sh)
vendor/build-zxcc.sh       # build & install zxcc into bin/ (CP/M .com emulator)
sh vendor/clone.sh         # fetch z88dk source (not committed; uses git submodules)
sh vendor/z88dk/build.sh   # build & install z88dk tools into bin/
./console.sh               # open a serial terminal (baud/device from serial.conf)
```

In another shell, assemble and load a program:

```sh
. ./env.sh
bz80asm myprog.asm         # produces myprog.bin and myprog.lst
runmon myprog.bin          # load into RAM at 0x0800 and run
```

## Project layout

```
z80/
├── env.sh            # source this to put bin/ on PATH
├── serial.conf       # SERIAL_DEV + BAUD_RATE used by all host tooling
├── console.sh        # serial terminal (tio) using serial.conf settings
├── bin/              # everything below is on PATH after `. ./env.sh`
│   ├── zmac          # vendored assembler (Russell Lennon's zmac)
│   ├── z80asm        # vendored assembler (shevek's z80asm)
│   ├── bzmac         # wrapper: zmac --oo cim,lst "$@"
│   ├── bz80asm       # wrapper: z80asm --list=<base>.lst -o <base>.bin <src>
│   ├── runmon        # load + run a .bin at 0x0800 over serial
│   ├── loadmon       # load a .bin at 0x0800 (no run)
│   ├── sendmon       # send raw bytes (for manual handshake)
│   ├── cpmput        # send a file via XMODEM (sx) to a waiting receiver
│   ├── cpmget        # receive a file via XMODEM (xmodem-recv) from a sender
│   ├── xmodem-recv   # Python XMODEM receiver (used by cpmget)
│   ├── serial-proxy-logger  # debug aid: hex-dump bytes on the serial line
│   ├── tio           # vendored serial terminal (used by console.sh)
│   ├── zxcc          # vendored CP/M emulator (runs .com files on the host)
│   └── bios.bin      # vestigial CP/M BIOS loaded by zxcc at startup
├── sys/
│   ├── monitor/      # ROM monitor source + build.sh
│   └── cpm/          # CP/M 2.2 sources + PCPUT/PCGET XMODEM programs
└── vendor/
    ├── build-zmac.sh    # builds zmac, installs to bin/zmac
    ├── build-z80asm.sh  # builds z80asm, installs to bin/z80asm
    ├── build-tio.sh     # builds tio, installs to bin/tio (meson + ninja)
    ├── build-zxcc.sh    # builds zxcc, installs to bin/zxcc
    ├── zmac/            # upstream zmac source
    ├── z80asm/          # upstream z80asm source
    ├── tio/             # forked from https://github.com/tio/tio
    ├── zxcc-0.5.7/      # upstream zxcc source (CP/M emulator)
    └── z88dk/           # upstream z88dk source (fetched by clone.sh; not committed)
```

> **See also:** [`PLAN.md`](PLAN.md) records design options for a
> known friction point — the single serial port is shared between the
> console terminal and file transfers (see
> [Pitfalls](#pitfalls) below).

## Toolchain

Two assemblers are bundled. Either can assemble for the Cpuvulle Z80; pick
the one whose syntax/features you prefer.

| Tool     | Upstream                | Output           | Wrapper   | Notes                                  |
|----------|-------------------------|------------------|-----------|----------------------------------------|
| `zmac`   | 48k.ca/zmac (Oct 2022)  | `.cim`, `.lst`   | `bzmac`   | Macro/rel-style, multiple output types |
| `z80asm` | shevek's z80asm v1.8    | `.bin`, `.lst`   | `bz80asm` | Strict two-pass, MSX-style headers     |

The wrappers reduce the most common case (assemble one file, get a listing
and a binary) to a single argument:

```sh
bzmac   foo.asm     # -> foo.cim, foo.lst
bz80asm foo.asm     # -> foo.bin, foo.lst
```

`bz80asm` strips the extension and reuses the basename for `--list` and `-o`,
so `bz80asm foo.asm` is exactly `z80asm --list=foo.lst -o foo.bin foo.asm`.

For anything beyond that one-shot case, call the underlying assembler
directly (`zmac --help` / `z80asm -h`).

### Building the vendored tools from source

Each vendored tool has a named build script in `vendor/` (`build-<tool>.sh`)
that compiles the upstream source and copies the resulting binary into `bin/`
(the directory `env.sh` puts on PATH). The upstream source trees under
`vendor/<tool>/` are kept untouched. The scripts honor the standard `CC`,
`CFLAGS`, and `LDFLAGS` environment variables, falling back to sane defaults.

```sh
vendor/build-zmac.sh      # builds zmac, installs to bin/zmac
vendor/build-z80asm.sh    # builds z80asm, installs to bin/z80asm
vendor/build-tio.sh       # builds tio, installs to bin/tio (meson + ninja)
vendor/build-zxcc.sh      # builds zxcc, installs to bin/zxcc (no curses; cpmio disabled)
```

Re-running `build-zmac.sh` / `build-z80asm.sh` rebuilds from scratch (object
files are recreated in place). `build-tio.sh` uses meson, so its `tio/build/`
directory is reused across runs for fast incremental rebuilds; delete
`vendor/tio/build` to force a full reconfigure. `build-zxcc.sh` writes
generated artifacts (a minimal `config.h`, object files, `libcpmredir.a`,
and the `zxcc` binary) to `vendor/zxcc-0.5.7/build/`; delete that directory
to force a clean rebuild.

### zxcc — CP/M emulator

`zxcc` (from zxcc-0.5.7) emulates a Z80 plus a subset of CP/M 3, letting
you run CP/M `.com` programs (such as the Hi-Tech C compiler or DRI's
MAC/RMAC/LINK) directly on the host. Only the emulator itself is built;
the `zxc`/`zxas`/`zxlibr`/`zxlink` frontends are thin argument-converting
wrappers around `zxcc` and are omitted. The optional `cpmio` (curses
console) layer is disabled, so console I/O uses plain stdio and ncurses
is not required.

```sh
zxcc program.com arg1 arg2 ...   # run a CP/M .com file on the host
```

`zxcc` searches `BINDIR80` then the current directory for `program.com`
and for `bios.bin` (the vestigial CP/M BIOS). `build-zxcc.sh` compiles
`BINDIR80` to point at the project's own `bin/` directory and copies the
bundled `bios.bin` (`vendor/zxcc-0.5.7/Z80/bios.bin`) there, so `zxcc`
finds it from any cwd after `. ./env.sh` — no separate install step.

The CP/M tools themselves (compiler `.com` files, libraries, headers)
are not bundled; see `vendor/zxcc-0.5.7/zxcc.html` for setup. Drop any
`.com` tools into `bin/` (or the current directory) and they'll be
found. `LIBDIR80`/`INCDIR80` keep the upstream defaults
(`/usr/local/lib/cpm/lib80/`, `.../include80/`); override the search
paths by editing the defines written to
`vendor/zxcc-0.5.7/build/config.h` and rerunning `build-zxcc.sh`.

A sample program lives in `src/cpm/hello/`:

```sh
. ./env.sh
zxcc src/cpm/hello/hello.com   # -> Hello from z88dk!
```

## The Cpuvulle Z80 machine

The target hardware assumed by this SDK:

- **CPU:** Zilog Z80
- **Serial UART:** data on I/O port `0x02`, control/status on I/O port `0x03`
  — initialized by the monitor for 9600 baud, 8 data bits, no parity,
  1 stop bit (16x baud mode).
- **IDE disk:** I/O ports `0x08`–`0x0F` (on the memory/disk expansion board).
- **Memory map (two configurations, selected by I/O port write):**
  - `out (0),a` → 2K ROM at `0x0000–0x07FF` + 62K RAM at `0x0800–0xFFFF`
  - `out (1),a` → all 64K RAM at `0x0000–0xFFFF`
- **User program load address:** `0x0800` (above the 2K ROM window).
- **Monitor stack:** `0xDBFF` (top of TPA, below the monitor's own RAM
  variables which start at `0xDB00`).

Programs assembled for the machine should `org 0x0800` and may use the
monitor's UART subroutines (see `sys/monitor/in_memory_monitor.asm`).

## ROM monitor

`sys/monitor/` contains the monitor firmware in two forms:

| File                     | ORG     | Purpose                                            |
|--------------------------|---------|----------------------------------------------------|
| `in_memory_monitor.asm`  | `0x0800`| RAM-resident monitor, loaded into user RAM         |
| `2k_rom_8.asm`           | `0x0000`| Burned into the 2K ROM at the bottom of the map    |

Both share the same command set and serial protocol. Build either with
`sys/monitor/build.sh` (uses `bz80asm`, so the project toolchain must be on
PATH — i.e. `. ./env.sh` first).

The monitor exposes (among others) these commands over the serial line:

- `bload` — binary load: prompts for address, length, then receives bytes.
- `run <addr>` — begin execution at `<addr>`.

See the source comments for the full command list and the UART subroutine
entry points (`write_char`, `write_string`, `get_line`, `bload`, `bdump`,
etc.) that user programs may call.

## Loading and running programs

The host scripts read `serial.conf` from the project root for the serial
device and baud rate (defaults `/dev/ttyUSB0` and `76800`).

### Monitor protocol (binary load + run)

| Command     | Does what                                                    |
|-------------|--------------------------------------------------------------|
| `runmon F`  | Full handshake (`bload`, `0800`, length, bytes) then `run 0800`. |
| `loadmon F` | Same handshake, but stops short of `run` (leaves it loaded). |
| `sendmon F` | Just pipes the raw bytes to the serial port (for manual handshaking). |

Typical loop during development:

```sh
bz80asm myprog.asm && runmon myprog.bin
```

### XMODEM file transfer (CP/M ↔ host)

`cpmput` and `cpmget` move files between the host and a CP/M program on
the Z80 using the XMODEM protocol (classic 8-bit checksum mode, matching
the `PCPUT`/`PCGET` programs in `sys/cpm/`).

| Command        | Does what                                                              |
|----------------|------------------------------------------------------------------------|
| `cpmput F`     | Sends `F` via XMODEM (`sx`). The Z80 receiver (`PCGET`) must already be waiting for the transfer. |
| `cpmget [-v] F`| Receives `F` via XMODEM (`xmodem-recv`). The Z80 sender (`PCPUT`) must already be running and waiting for the initial NAK. `-v` logs every byte in hex to stderr (useful for debugging protocol issues). Overwrites any existing local `F`. |

Workflow:

1. On the Z80 (via `console.sh`), run `PCGET file.ext` (to receive) or
   `PCPUT file.ext` (to send). It prints "Start XMODEM file receive
   now..." and waits.
2. **Disconnect `console.sh`** (see [Pitfalls](#pitfalls)).
3. On the host, run `cpmput file.ext` or `cpmget file.ext`.
4. Reconnect `console.sh` to resume interaction.

`cpmget` uses `bin/xmodem-recv` (a custom Python XMODEM receiver) rather
than lrzsz's `rx -X`, because `rx -X` fails to ACK the EOT byte in
classic checksum mode, causing `PCPUT` to report "No ACK received on
EOT" and `rx` to discard the received file. `xmodem-recv` mirrors
`pcput.asm`'s protocol exactly, including proper EOT acknowledgement,
stale-buffer flushing, and resync-on-bad-frame without cascading NAKs.

To watch monitor output / interact with the monitor by hand, run
`./console.sh` (which reads `SERIAL_DEV` and `BAUD_RATE` from
`serial.conf`) in a separate terminal.

## Writing your first program

A minimal "echo one byte to the serial line" program for the Cpuvulle Z80:

```asm
                org     0x0800
start:
                call    0x0040          ; replace with monitor's write_char entry
                halt
```

In practice you'll want to call the monitor's `write_char` subroutine; the
entry point depends on which monitor build is resident (see the listing
`*.lst` produced by `sys/monitor/build.sh` for the exact addresses). A more
complete example using the monitor's own UART primitives lives in
`sys/monitor/in_memory_monitor.asm` (the `write_string` routine is a good
template for user programs).

Assemble and run:

```sh
. ./env.sh
bz80asm hello.asm
runmon hello.bin
```

## Pitfalls

Lessons learned the hard way during development of this SDK.

### Serial port is exclusive — close `console.sh` during transfers

`/dev/ttyUSB0` is a single character device: the kernel hands each
incoming byte to whichever process reads first. If `console.sh` (tio)
is attached while `cpmget`/`cpmput` runs, **tio silently steals bytes
from the transfer**, causing truncated files and spurious "transfer
complete" reports (the Z80 sender exhausts its retries and sends EOT
early). This exact failure lost 29 of 256 blocks during a 32K
end-to-end test.

**Always disconnect `console.sh` before running `cpmget`/`cpmput`,**
then reconnect after. `runmon`/`loadmon`/`sendmon` are unaffected
because they own the port for their whole lifetime.

This friction is documented as a known issue with design options for a
future fix in [`PLAN.md`](PLAN.md). The Cpuvulle Z80's M82C51A-2 UART
provides only one serial port, so console and transfers cannot be
split across two devices.

### XMODEM padding — received files may be larger than the original

XMODEM transmits data in fixed 128-byte blocks. `PCPUT` pads the final
block with `0x1A` (CP/M EOF character) to fill the block. A 68-byte
source file arrives as 128 bytes on the host; a 1024-byte file arrives
as 1024 (already a multiple of 128). When verifying transfers with
`cmp` or `sha256sum`, compare against the *padded* length or strip
trailing `0x1A` bytes from the received file.

### `rx -X` (lrzsz) does not work with `PCPUT` — use `cpmget`

lrzsz 0.12.20's `rx -X` mishandles the EOT byte in classic checksum
mode: it treats `0x04` (EOT) as a bad sector header instead of
acknowledging it, so `PCPUT` never receives the final ACK, reports "No
ACK received on EOT, but transfer is complete," and `rx` discards the
file as incomplete. `cpmget` uses `bin/xmodem-recv` (custom Python
receiver) instead, which correctly ACKs the EOT. Don't substitute
`rx -X` directly.

### Stale bytes in the serial buffer

If a previous transfer failed or was interrupted, leftover bytes may
remain in the serial input buffer. The next `cpmget` will see them as
garbage at the start of the stream. `xmodem-recv` flushes the input
buffer on startup and resyncs on bad frames, but if you see a block-1
retry in `-v` mode, this is the likely cause — not an actual line
error.

## Notes

- `env.sh` must be **sourced**, not executed: `. ./env.sh` (or
  `source ./env.sh`). Running it directly refuses to modify your shell.
- `bz80asm` derives output names from the input basename, so any extension
  works: `bz80asm foo.z80` → `foo.bin`, `foo.lst`.
- The vendored `z80asm` is GPLv3; `zmac` has its own license; `zxcc`
  is GPLv2 (the Z80 engine) with its `cpmredir` library under the LGPL
  — see `vendor/<tool>/` for the upstream COPYING/LICENSE files.
- `cpmget -v` enables byte-level hex tracing to stderr, showing every
  byte transferred in both directions with timestamps. Useful for
  diagnosing protocol issues or counting retries.
- `bin/serial-proxy-logger` is a standalone debug tool that proxies
  bytes between the serial device and an XMODEM program, hex-dumping
  each chunk. Not used by the normal workflow but available for
  protocol debugging.
