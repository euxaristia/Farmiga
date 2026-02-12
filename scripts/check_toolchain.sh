#!/usr/bin/env bash
set -euo pipefail

: "${CROSS:=aarch64-none-elf-}"
: "${COATL:=/home/euxaristia/Projects/Coatl/coatl}"

need() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "missing: $1"
    return 1
  fi
}

need "${CROSS}as"
need "${CROSS}ld"
need "${CROSS}objcopy"
need qemu-system-aarch64
need "$COATL"

echo "toolchain looks available"
