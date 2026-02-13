#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "usage: $0 <fixture-env> <out-coatl-file>" >&2
  exit 2
fi

fixture="$1"
out_file="$2"

if [ ! -f "$fixture" ]; then
  echo "missing fixture: $fixture" >&2
  exit 1
fi

fixture_val() {
  local key="$1"
  local val
  val="$(sed -n "s/^${key}=\\([0-9][0-9]*\\)\$/\\1/p" "$fixture" | head -n1 || true)"
  if [ -z "$val" ]; then
    echo "generator failed: missing key $key in $fixture" >&2
    exit 1
  fi
  printf '%s' "$val"
}

size="$(fixture_val trap_snapshot_size)"
off_count="$(fixture_val trap_snapshot_off_count)"
off_kind="$(fixture_val trap_snapshot_off_kind)"
off_esr="$(fixture_val trap_snapshot_off_esr)"
off_elr="$(fixture_val trap_snapshot_off_elr)"
off_spsr="$(fixture_val trap_snapshot_off_spsr)"
off_x8="$(fixture_val trap_snapshot_off_x8)"
off_route="$(fixture_val trap_snapshot_off_route)"

{
  echo "# generated from $fixture"
  echo "fn gen_trap_snapshot_abi_size() -> i32 { return $size; }"
  echo "fn gen_trap_snapshot_abi_off_count() -> i32 { return $off_count; }"
  echo "fn gen_trap_snapshot_abi_off_kind() -> i32 { return $off_kind; }"
  echo "fn gen_trap_snapshot_abi_off_esr() -> i32 { return $off_esr; }"
  echo "fn gen_trap_snapshot_abi_off_elr() -> i32 { return $off_elr; }"
  echo "fn gen_trap_snapshot_abi_off_spsr() -> i32 { return $off_spsr; }"
  echo "fn gen_trap_snapshot_abi_off_x8() -> i32 { return $off_x8; }"
  echo "fn gen_trap_snapshot_abi_off_route() -> i32 { return $off_route; }"
} > "$out_file"

echo "generated Coatl trap ABI constants: $out_file"
