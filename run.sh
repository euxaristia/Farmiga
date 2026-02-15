#!/bin/bash
set -e
make aarch64
echo "Starting Farmiga OS..."
echo "---------------------------------------------------"
echo "PRO TIP: If the QEMU window shows '(qemu)', go to 'View' -> 'serial0'."
echo "---------------------------------------------------"
qemu-system-aarch64 -machine virt -cpu cortex-a72 -kernel build/farmiga-aarch64.elf -serial vc -monitor stdio
