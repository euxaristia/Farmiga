#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "usage: $0 <aarch64-elf> <out-fixture-file>" >&2
  exit 2
fi

elf="$1"
out_file="$2"
nm_bin="${NM:-nm}"

nm_out="$(mktemp)"
trap 'rm -f "$nm_out"' EXIT
"$nm_bin" "$elf" > "$nm_out"

sym_dec() {
  local sym="$1"
  local hex
  hex="$(awk -v s="$sym" '$3==s { print tolower($1); exit }' "$nm_out")"
  if [ -z "$hex" ]; then
    echo "fixture generation failed: missing symbol $sym" >&2
    exit 1
  fi
  printf '%d' "$((16#$hex))"
}

size="$(sym_dec trap_snapshot_size)"
off_count="$(sym_dec trap_snapshot_off_count)"
off_kind="$(sym_dec trap_snapshot_off_kind)"
off_esr="$(sym_dec trap_snapshot_off_esr)"
off_elr="$(sym_dec trap_snapshot_off_elr)"
off_spsr="$(sym_dec trap_snapshot_off_spsr)"
off_x8="$(sym_dec trap_snapshot_off_x8)"
off_route="$(sym_dec trap_snapshot_off_route)"

{
  echo "# generated from $elf"
  echo "trap_snapshot_size=$size"
  echo "trap_snapshot_off_count=$off_count"
  echo "trap_snapshot_off_kind=$off_kind"
  echo "trap_snapshot_off_esr=$off_esr"
  echo "trap_snapshot_off_elr=$off_elr"
  echo "trap_snapshot_off_spsr=$off_spsr"
  echo "trap_snapshot_off_x8=$off_x8"
  echo "trap_snapshot_off_route=$off_route"
  echo
  echo "# deterministic slot fixtures for ingest-model parity checks"
  echo "fixture_svc_count=1"
  echo "fixture_svc_kind=1"
  echo "fixture_svc_esr=1409286144"
  echo "fixture_svc_elr=1074266112"
  echo "fixture_svc_spsr=965"
  echo "fixture_svc_x8=20"
  echo "fixture_svc_route=1"
  echo
  echo "fixture_brk_count=1"
  echo "fixture_brk_kind=1"
  echo "fixture_brk_esr=4026531840"
  echo "fixture_brk_elr=1074266112"
  echo "fixture_brk_spsr=965"
  echo "fixture_brk_x8=0"
  echo "fixture_brk_route=0"
} > "$out_file"

echo "generated trap snapshot fixture: $out_file"
