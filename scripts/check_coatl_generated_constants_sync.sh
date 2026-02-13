#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "usage: $0 <generated-coatl-file> <kernel-coatl-file>" >&2
  exit 2
fi

gen_file="$1"
kernel_file="$2"

if ! command -v rg >/dev/null 2>&1; then
  echo "missing: rg" >&2
  exit 2
fi

coatl_const_dec() {
  local file="$1"
  local fn="$2"
  local line val
  line="$(rg "^fn ${fn}\\(\\) -> i32 \\{ return [0-9]+; \\}\$" "$file" | head -n1 || true)"
  val="$(printf '%s\n' "$line" | sed -n 's/^fn .* { return \([0-9][0-9]*\); }$/\1/p')"
  if [ -z "$val" ]; then
    echo "sync check failed: missing function $fn in $file" >&2
    exit 1
  fi
  printf '%s' "$val"
}

check_pair() {
  local gen_fn="$1"
  local kernel_fn="$2"
  local a b
  a="$(coatl_const_dec "$gen_file" "$gen_fn")"
  b="$(coatl_const_dec "$kernel_file" "$kernel_fn")"
  if [ "$a" != "$b" ]; then
    echo "sync check failed: $gen_fn=$a != $kernel_fn=$b" >&2
    exit 1
  fi
}

check_pair gen_trap_snapshot_abi_size trap_snapshot_abi_size
check_pair gen_trap_snapshot_abi_off_count trap_snapshot_abi_off_count
check_pair gen_trap_snapshot_abi_off_kind trap_snapshot_abi_off_kind
check_pair gen_trap_snapshot_abi_off_esr trap_snapshot_abi_off_esr
check_pair gen_trap_snapshot_abi_off_elr trap_snapshot_abi_off_elr
check_pair gen_trap_snapshot_abi_off_spsr trap_snapshot_abi_off_spsr
check_pair gen_trap_snapshot_abi_off_x8 trap_snapshot_abi_off_x8
check_pair gen_trap_snapshot_abi_off_route trap_snapshot_abi_off_route

echo "Coatl generated trap ABI constants sync check passed"
