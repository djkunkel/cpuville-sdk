# z80 — SDK for the Cpuvulle Z80 machine

This repository is a self-contained development kit for writing, building, and
loading Z80 programs on the **Cpuvulle Z80** machine. It bundles two
assemblers, a ROM monitor, and host-side serial tooling under a single
`env.sh` so a developer can go from source to running hardware with one shell
on PATH.

## Quick start

```sh
. ./env.sh                 # put bin/ on PATH (zmac, z80asm, runmon, ...)
vendor/zmac/build.sh       # build & install zmac into bin/
vendor/z80asm/build.sh     # build & install z80asm into bin/
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
│   └── cpmput        # send a file via XMODEM (sx) to a waiting receiver
├── sys/
│   └── monitor/      # ROM monitor source + build.sh
└── vendor/
    ├── zmac/         # upstream zmac source + build.sh
    └── z80asm/       # upstream z80asm source + build.sh
```

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

Each vendored tool has its own `build.sh` that compiles from source and
copies the resulting binary into `bin/` (the directory `env.sh` puts on
PATH). They honor the standard `CC`, `CFLAGS`, and `LDFLAGS` environment
variables, falling back to sane defaults.

```sh
vendor/zmac/build.sh      # builds zmac, installs to bin/zmac
vendor/z80asm/build.sh    # builds z80asm, installs to bin/z80asm
```

Re-running either script rebuilds from scratch (object files are recreated
in place). The upstream sources live untouched under `vendor/<tool>/src/`.

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

Three host scripts automate talking to the monitor. All of them read
`serial.conf` from the project root for the serial device and baud rate
(defaults `/dev/ttyUSB0` and `76800`).

| Command     | Does what                                                    |
|-------------|--------------------------------------------------------------|
| `runmon F`  | Full handshake (`bload`, `0800`, length, bytes) then `run 0800`. |
| `loadmon F` | Same handshake, but stops short of `run` (leaves it loaded). |
| `sendmon F` | Just pipes the raw bytes to the serial port (for manual handshaking). |
| `cpmput F`  | Sends `F` via XMODEM (classic checksum or CRC, auto-negotiated by `sx`). The receiver on the Z80 must already be waiting for an XMODEM transfer (e.g. a CP/M `PIP`/`LOAD` prompt) before invoking. |

Typical loop during development:

```sh
bz80asm myprog.asm && runmon myprog.bin
```

To watch monitor output / interact with the monitor by hand, run `./console.sh`
(which reads `SERIAL_DEV` and `BAUD_RATE` from `serial.conf`) in a separate
terminal.

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

## Notes

- `env.sh` must be **sourced**, not executed: `. ./env.sh` (or
  `source ./env.sh`). Running it directly refuses to modify your shell.
- `bz80asm` derives output names from the input basename, so any extension
  works: `bz80asm foo.z80` → `foo.bin`, `foo.lst`.
- The vendored `z80asm` is GPLv3; `zmac` has its own license — see
  `vendor/<tool>/src/` for the upstream COPYING/LICENSE files.
