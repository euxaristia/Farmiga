#!/bin/bash
# Farmiga: QEMU run helper
# Copyright (C) 2026 euxaristia
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

set -e
make aarch64
echo "Starting Farmiga OS..."
echo "---------------------------------------------------"
echo "PRO TIP: If the QEMU window shows '(qemu)', go to 'View' -> 'serial0'."
echo "---------------------------------------------------"
qemu-system-aarch64 -machine virt -cpu cortex-a72 -kernel build/farmiga-aarch64.elf -serial vc -monitor stdio
