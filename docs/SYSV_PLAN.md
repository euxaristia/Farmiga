# SysV-Inspired Plan

Status snapshots are tracked in `docs/PROGRESS.md`.

## Stage 0 (current)

- AArch64 machine entry + serial console on QEMU `virt`
- Coatl syscall core model and dispatch table skeleton
- Build system prepared for architecture split

## Stage 1

- Interrupt vector table and exception decoding (EL1)
  - vector table scaffold is implemented in `arch/aarch64/boot.S`
  - `ESR_EL1`/`ELR_EL1`/`SPSR_EL1` capture + SVC EC decode path implemented
- Timer tick and cooperative scheduler (`proc`, `runq`) in Coatl
  - cooperative queue model implemented (`rq_push`, `rq_pop`, `sched_next`)
- Syscalls: `getpid`, `getppid`, `exit`, `write` (UART)
  - syscall dispatch model implemented in Coatl (`sys_dispatch`)

## Stage 2

- User/kernel split and syscall trap path
  - trapframe model + trap dispatch shim implemented in Coatl (`TrapFrame`, `sys_dispatch_tf_ret`)
  - Coatl trap snapshot adapter model implemented (`TrapSnapshot`, `trap_snapshot_to_event`)
  - Coatl trap snapshot ABI constants implemented (size + fixed field offsets)
  - AArch64 EL1 SVC classification + syscall-number route smoke implemented (`make test-aarch64-svc`, `make test-aarch64-svc-unknown`, `make test-aarch64-svc-matrix`)
  - Coatl syscall-route model parity helper implemented (`sys_route_id`)
  - AArch64 BRK trap observability smoke implemented (`make test-aarch64-brk`)
  - AArch64 trap snapshot ABI symbols + fixed layout constants smoke-validated (`make test-aarch64-trap-abi`)
- Simple SysV-like process model: `fork`, `wait`, `exec` subset
  - `fork`/`wait` model scaffolding implemented; minimal `exec` image/load scaffolding now implemented (`ExecImage`, `exec_load_path`)
- Flat in-memory FS image + pathname lookup
  - root lookup scaffold implemented (`vfs_lookup_root`)
  - fixed in-memory FS image model implemented for smoke paths (`FsImage`, `fs_lookup_ino`, `fs_read_len`)

## Stage 3

- SysV IPC subset (`msgget/msgsnd/msgrcv` or semaphore subset)
- Device layer split (`tty`, `block`, `clock`)
- x86_64 boot parity target

## Stage 4

- VFS-like abstraction and mount table
  - initial VFS node + mount scaffolds implemented (`VfsNode`, `Mount`)
- ELF loader, init process, shell prototype
  - init-task model scaffold implemented (`UserTask`)
  - init launch from FS and shell command handlers modeled for smoke (`init_spawn_from_fs`, `shell_cmd_echo/ls/cat/mount/ps`)
- Cross-arch CI for `aarch64` and `x86_64`
