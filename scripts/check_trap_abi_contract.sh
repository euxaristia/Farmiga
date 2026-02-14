#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "usage: $0 <aarch64-elf> <coatl-kernel-file>" >&2
  exit 2
fi

elf="$1"
coatl_file="$2"

if ! command -v rg >/dev/null 2>&1; then
  echo "missing: rg" >&2
  exit 2
fi

nm_out="$(mktemp)"
trap 'rm -f "$nm_out"' EXIT

nm_bin="${NM:-nm}"
"$nm_bin" "$elf" > "$nm_out"

sym_hex() {
  local sym="$1"
  local hex
  hex="$(awk -v s="$sym" '$3==s { print tolower($1); exit }' "$nm_out")"
  if [ -z "$hex" ]; then
    echo "trap ABI check failed: missing symbol $sym" >&2
    exit 1
  fi
  printf '%s' "$hex"
}

coatl_const_dec() {
  local fn="$1"
  local line val
  line="$(rg "^fn ${fn}\\(\\) -> i32 \\{ return [0-9]+; \\}\$" "$coatl_file" | head -n1 || true)"
  val="$(printf '%s\n' "$line" | sed -n 's/^fn .* { return \([0-9][0-9]*\); }$/\1/p')"
  if [ -z "$val" ]; then
    echo "trap ABI check failed: missing Coatl ABI function $fn in $coatl_file" >&2
    exit 1
  fi
  printf '%s' "$val"
}

check_eq_hex() {
  local sym="$1"
  local expect_dec="$2"
  local got_hex expect_hex
  got_hex="$(sym_hex "$sym")"
  expect_hex="$(printf '%016x' "$expect_dec")"
  if [ "$got_hex" != "$expect_hex" ]; then
    echo "trap ABI check failed: $sym=$got_hex expected=$expect_hex" >&2
    exit 1
  fi
}

for s in \
  trap_snapshot_base \
  trap_snapshot_end \
  trap_snapshot_size \
  trap_snapshot_off_count \
  trap_snapshot_off_kind \
  trap_snapshot_off_esr \
  trap_snapshot_off_elr \
  trap_snapshot_off_spsr \
  trap_snapshot_off_x8 \
  trap_snapshot_off_x0 \
  trap_snapshot_off_x1 \
  trap_snapshot_off_x2 \
  trap_snapshot_off_route \
  el1_trap_count \
  last_trap_kind \
  last_esr_el1 \
  last_elr_el1 \
  last_spsr_el1 \
  last_x0 \
  last_x1 \
  last_x2 \
  last_x8 \
  last_sys_route \
  last_sys_ret
do
  sym_hex "$s" >/dev/null
done

check_eq_hex trap_snapshot_size "$(coatl_const_dec trap_snapshot_abi_size)"
check_eq_hex trap_snapshot_off_count "$(coatl_const_dec trap_snapshot_abi_off_count)"
check_eq_hex trap_snapshot_off_kind "$(coatl_const_dec trap_snapshot_abi_off_kind)"
check_eq_hex trap_snapshot_off_esr "$(coatl_const_dec trap_snapshot_abi_off_esr)"
check_eq_hex trap_snapshot_off_elr "$(coatl_const_dec trap_snapshot_abi_off_elr)"
check_eq_hex trap_snapshot_off_spsr "$(coatl_const_dec trap_snapshot_abi_off_spsr)"
check_eq_hex trap_snapshot_off_x8 "$(coatl_const_dec trap_snapshot_abi_off_x8)"
check_eq_hex trap_snapshot_off_x0 "$(coatl_const_dec trap_snapshot_abi_off_x0)"
check_eq_hex trap_snapshot_off_x1 "$(coatl_const_dec trap_snapshot_abi_off_x1)"
check_eq_hex trap_snapshot_off_x2 "$(coatl_const_dec trap_snapshot_abi_off_x2)"
check_eq_hex trap_snapshot_off_route "$(coatl_const_dec trap_snapshot_abi_off_route)"

base_dec=$((16#$(sym_hex trap_snapshot_base)))
end_dec=$((16#$(sym_hex trap_snapshot_end)))
size_dec=$((16#$(sym_hex trap_snapshot_size)))
span_dec=$((end_dec - base_dec))
if [ "$span_dec" -ne "$size_dec" ]; then
  echo "trap ABI check failed: span=$span_dec size=$size_dec" >&2
  exit 1
fi

echo "QEMU trap ABI contract check passed"
