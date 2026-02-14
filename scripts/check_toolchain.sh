#!/usr/bin/env bash
set -euo pipefail

if [ -z "${CROSS:-}" ]; then
  if command -v aarch64-none-elf-as >/dev/null 2>&1; then
    CROSS="aarch64-none-elf-"
  elif command -v aarch64-linux-gnu-as >/dev/null 2>&1; then
    CROSS="aarch64-linux-gnu-"
  else
    CROSS="aarch64-none-elf-"
  fi
fi

: "${COATL:=/home/euxaristia/Projects/Coatl/coatl}"
: "${QEMU:=qemu-system-aarch64}"
: "${TIMEOUT:=timeout}"

need() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "missing: $1"
    return 1
  fi
}

need "${CROSS}as"
need "${CROSS}ld"
need "${CROSS}objcopy"
need "${CROSS}nm"
need "$QEMU"
need "$TIMEOUT"
need "$COATL"

echo "toolchain looks available (CROSS=$CROSS)"
