# FarmigaKernel

FarmigaKernel is a UNIX SysV-inspired hobby kernel project with:
- `aarch64` as the primary boot target
- `x86_64` as a planned second target
- kernel logic authored in Coatl where practical

This repository currently provides a Stage 0 foundation:
- Bootable AArch64 kernel entry and UART console on QEMU `virt`
- SysV-like syscall dispatch core written in Coatl
- In-memory FS + init/exec + shell-command model layer in Coatl (`echo`, `ls`, `cat`, `mount`, `ps`)
- Build wiring for incremental migration of low-level kernel paths to Coatl

## Layout

- `arch/aarch64/boot.S`: reset entry, stack setup, UART console output
- `arch/aarch64/linker.ld`: bare-metal linker script
- `kernel/sysv_kernel.coatl`: SysV-inspired syscall/process core model in Coatl
- `Makefile`: build/run/smoke targets
- `docs/SYSV_PLAN.md`: staged plan from Stage 0 to multi-process SysV-like kernel
- `docs/PROGRESS.md`: dated implementation log and blockers

## Requirements

- GNU binutils for AArch64 (`aarch64-none-elf-as`, `aarch64-none-elf-ld`, `aarch64-none-elf-objcopy`) or compatible prefix
- `qemu-system-aarch64`
- Coatl compiler at `~/Projects/Coatl/coatl` (or set `COATL`)

The Makefile auto-detects `aarch64-none-elf-` and `aarch64-linux-gnu-` prefixes.
If your tools use a different prefix, override it:

```bash
make CROSS=<your-prefix> validate
```

## Quick Start

Build AArch64 ELF + raw image:

```bash
make aarch64
```

Run on QEMU:

```bash
make run-aarch64
```

You should see:

```text
FarmigaKernel: aarch64 stage0
```

Automated QEMU validation (recommended for every change):

```bash
make test-aarch64
```

This command boots the kernel in QEMU, captures serial output, and fails if the expected boot banner is missing.

Build and run the Coatl SysV core smoke test on `x86_64` host:

```bash
make coatl-sysv-smoke
```

Run the full validation suite (includes QEMU boot test):

```bash
make validate
```

## Notes

- Coatl AArch64 codegen is still evolving. This repo keeps the machine-entry path in assembly while growing portable kernel logic in Coatl.
- The goal is to move scheduler, syscall table, VFS, and IPC core progressively into Coatl as backend support hardens.
