#!/bin/sh
# Build the ROM monitor variants. bz80asm derives the .lst/.bin names from
# the source basename, so each line is just the source file. Requires the
# project bin/ on PATH (`. ../../env.sh` first).
set -e
bz80asm in_memory_monitor.asm
bz80asm 2k_rom_8.asm