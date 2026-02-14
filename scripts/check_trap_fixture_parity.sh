#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "usage: $0 <fixture-env> <coatl-kernel-file>" >&2
  exit 2
fi

fixture="$1"
coatl_file="$2"

if [ ! -f "$fixture" ]; then
  echo "fixture parity check failed: missing fixture file $fixture" >&2
  exit 1
fi

if ! command -v rg >/dev/null 2>&1; then
  echo "missing: rg" >&2
  exit 2
fi

fixture_val() {
  local key="$1"
  local val
  val="$(sed -n "s/^${key}=\\([0-9][0-9]*\\)\$/\\1/p" "$fixture" | head -n1 || true)"
  if [ -z "$val" ]; then
    echo "fixture parity check failed: missing key $key in $fixture" >&2
    exit 1
  fi
  printf '%s' "$val"
}

coatl_const_dec() {
  local fn="$1"
  local line val
  line="$(rg "^fn ${fn}\\(\\) -> i32 \\{ return [0-9]+; \\}\$" "$coatl_file" | head -n1 || true)"
  val="$(printf '%s\n' "$line" | sed -n 's/^fn .* { return \([0-9][0-9]*\); }$/\1/p')"
  if [ -z "$val" ]; then
    echo "fixture parity check failed: missing Coatl ABI function $fn in $coatl_file" >&2
    exit 1
  fi
  printf '%s' "$val"
}

check_eq() {
  local lhs="$1"
  local rhs="$2"
  local msg="$3"
  if [ "$lhs" != "$rhs" ]; then
    echo "fixture parity check failed: $msg ($lhs != $rhs)" >&2
    exit 1
  fi
}

check_eq "$(fixture_val trap_snapshot_size)" "$(coatl_const_dec trap_snapshot_abi_size)" "trap_snapshot_size mismatch"
check_eq "$(fixture_val trap_snapshot_off_count)" "$(coatl_const_dec trap_snapshot_abi_off_count)" "trap_snapshot_off_count mismatch"
check_eq "$(fixture_val trap_snapshot_off_kind)" "$(coatl_const_dec trap_snapshot_abi_off_kind)" "trap_snapshot_off_kind mismatch"
check_eq "$(fixture_val trap_snapshot_off_esr)" "$(coatl_const_dec trap_snapshot_abi_off_esr)" "trap_snapshot_off_esr mismatch"
check_eq "$(fixture_val trap_snapshot_off_elr)" "$(coatl_const_dec trap_snapshot_abi_off_elr)" "trap_snapshot_off_elr mismatch"
check_eq "$(fixture_val trap_snapshot_off_spsr)" "$(coatl_const_dec trap_snapshot_abi_off_spsr)" "trap_snapshot_off_spsr mismatch"
check_eq "$(fixture_val trap_snapshot_off_x8)" "$(coatl_const_dec trap_snapshot_abi_off_x8)" "trap_snapshot_off_x8 mismatch"
check_eq "$(fixture_val trap_snapshot_off_x0)" "$(coatl_const_dec trap_snapshot_abi_off_x0)" "trap_snapshot_off_x0 mismatch"
check_eq "$(fixture_val trap_snapshot_off_x1)" "$(coatl_const_dec trap_snapshot_abi_off_x1)" "trap_snapshot_off_x1 mismatch"
check_eq "$(fixture_val trap_snapshot_off_x2)" "$(coatl_const_dec trap_snapshot_abi_off_x2)" "trap_snapshot_off_x2 mismatch"
check_eq "$(fixture_val trap_snapshot_off_route)" "$(coatl_const_dec trap_snapshot_abi_off_route)" "trap_snapshot_off_route mismatch"

check_eq "$(fixture_val fixture_svc_route)" "1" "fixture_svc_route expected 1"
check_eq "$(fixture_val fixture_brk_route)" "0" "fixture_brk_route expected 0"

echo "Coatl trap fixture parity check passed"
