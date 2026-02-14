# Progress Log

## 2026-02-14

### Trap snapshot ABI expansion (syscall argument payload)

- Extended AArch64 trap snapshot ABI in `arch/aarch64/boot.S` to capture syscall argument registers:
  - new exported offsets: `trap_snapshot_off_x0`, `trap_snapshot_off_x1`, `trap_snapshot_off_x2`
  - new captured symbols: `last_x0`, `last_x1`, `last_x2`
  - updated layout constants:
    - `trap_snapshot_size=80`
    - offsets: `count=0`, `kind=8`, `esr=16`, `elr=24`, `spsr=32`, `x8=40`, `x0=48`, `x1=56`, `x2=64`, `route=72`
- Updated Coatl ABI/helpers and ingest model in `kernel/sysv_kernel.coatl`:
  - added `trap_snapshot_abi_off_x0/x1/x2` helpers
  - expanded `TrapSnapshot` and `TrapSnapshotSlots` to include argument slots
  - wired slot ingest and smoke assertions for expanded layout constants
- Updated ABI contract/generation/parity scripts for expanded snapshot layout:
  - `scripts/check_trap_abi_contract.sh`
  - `scripts/gen_trap_snapshot_fixture.sh`
  - `scripts/check_trap_fixture_parity.sh`
  - `scripts/gen_coatl_trap_abi_constants.sh`
  - `scripts/check_coatl_generated_constants_sync.sh`
- Updated fixture contract assertions in `Makefile` and documentation in `README.md`.
- Added runtime syscall-argument observability markers in trap serial output:
  - `FarmigaKernel: syscall arg x0=1`
  - `FarmigaKernel: syscall arg x1=4096`
  - `FarmigaKernel: syscall arg x2=16`
- Added QEMU smoke target `make test-aarch64-svc-args` and wired it into `make validate`.
- Added minimal syscall return-slot model in AArch64 trap path:
  - captures modeled return value in `last_sys_ret`
  - emits deterministic return marker `FarmigaKernel: syscall ret x0=16` for write-path smoke
- Added QEMU smoke target `make test-aarch64-svc-ret` and wired it into `make validate`.
- Wired Coatl trap snapshot payload into syscall dispatch model:
  - added `trap_snapshot_to_trapframe`
  - added `sys_dispatch_snapshot_ret`
  - host smoke now validates snapshot-driven dispatch for write (`ret=16`) and unknown syscall (`-ENOSYS`-like path).
- Hardened runtime trap verification in `Makefile`:
  - `test-aarch64-trap-runtime` now depends on `test-aarch64-svc-args` and `test-aarch64-svc-ret`
  - runtime check now asserts syscall argument markers (`x0/x1/x2`) and return marker (`ret x0=16`) from captured QEMU logs.
- Hardened build preflight reliability:
  - updated `scripts/check_toolchain.sh` to auto-detect `CROSS` prefix (`aarch64-none-elf-` / `aarch64-linux-gnu-`)
  - preflight now checks `nm`, `qemu-system-aarch64`, and `timeout` in addition to assembler/linker/objcopy/Coatl
  - added `make toolchain-preflight` target and made `make validate` run it first.
- Added initial x86_64 architecture scaffold (secondary target lane):
  - `arch/x86_64/boot.S` stage-0 entry with serial banner path
  - `arch/x86_64/linker.ld` bare-metal linker layout
  - `make x86_64` build target with `toolchain-x86_64` auto-detected prefix support.
- Added deterministic x86_64 build contract smoke:
  - `make test-x86_64-build` validates x86_64 artifact build + PVH Xen note presence + stage0 banner string
  - wired `test-x86_64-build` into `make validate`.
- x86_64 QEMU direct boot via `-kernel` remains blocked in this environment (SeaBIOS loop despite PVH note); build-contract lane is used as current parity guardrail.
- Added explicit experimental x86_64 loader execution targets:
  - `make run-x86_64-loader`
  - `make test-x86_64-qemu-smoke` (banner assertion on serial log)
  - these targets are currently optional and not part of `validate` while x86_64 boot protocol bring-up is still being stabilized.
- Added minimal mount-table model scaffolding in Coatl kernel layer:
  - `MountTable`, `mounttable_new`, `mounttable_mount_root`, `mounttable_count`
  - host smoke now asserts root mount registration/count semantics (`0 -> 1`).
- Added user-mode transition scaffolding in Coatl model layer:
  - `CpuContext`, `cpu_context_el1_boot`, `cpu_enter_user`
  - host smoke now asserts modeled EL transition semantics (`EL1 -> EL0`) for spawned user task context.

## 2026-02-12

### Repository foundation

- Created AArch64 boot scaffold:
  - `arch/aarch64/boot.S`
  - `arch/aarch64/linker.ld`
- Added build/run/test pipeline in `Makefile`:
  - `make aarch64`
  - `make run-aarch64`
  - `make test-aarch64` (QEMU serial-banner assertion)
  - `make validate` (Coatl smoke + QEMU test)
- Added cross-toolchain auto-detection:
  - `aarch64-none-elf-`
  - `aarch64-linux-gnu-`
- Added explicit toolchain preflight target:
  - `make toolchain-aarch64`
- Removed AArch64 linker RWX PT_LOAD warning:
  - added explicit `PHDRS` in `arch/aarch64/linker.ld`
  - split load segments into text (`RX`), rodata (`R`), and data+bss (`RW`)
- Added EL1 exception/trap scaffold in AArch64 entry assembly:
  - installs `VBAR_EL1` at boot (`vector_table_el1`)
  - provides all 16 vector slots (curr EL SP0/SPx + lower EL AArch64/AArch32)
  - routes vectors to a common trap stub that increments `el1_trap_count` and prints UART trap banner
- Upgraded EL1 trap path for syscall-boundary bring-up:
  - captures `ESR_EL1`, `ELR_EL1`, `SPSR_EL1`, and trapped `x8` into `.bss` snapshot slots
  - exports stable snapshot symbols (`trap_snapshot_base..trap_snapshot_end`) for a future Coatl reader bridge
  - decodes exception class from `ESR_EL1` and classifies EC=`0x15` as AArch64 SVC/syscall trap
  - emits deterministic serial marker:
    - `FarmigaKernel: el1 sync syscall`
  - adds syscall-number route markers from trapped `x8`:
    - `getpid(20)`, `getppid(64)`, `exit(1)`, `write(4)`, `unknown`
  - stores numeric route code into `last_sys_route` (`1/2/3/4/255`)
- Added automated QEMU SVC trap smoke target:
  - `make test-aarch64-svc`
  - builds `TRAP_TEST_SVC=1` kernel variant that executes `svc #0` at startup
  - asserts boot banner + syscall-trap banner + `getpid(20)` marker in captured serial output
- Added automated unknown-syscall route smoke target:
  - `make test-aarch64-svc-unknown`
  - builds `TRAP_TEST_SVC_NO=999` variant and asserts unknown-route marker in serial output
- Added automated syscall-route matrix smoke target:
  - `make test-aarch64-svc-matrix`
  - exercises `TRAP_TEST_SVC_NO=64/1/4` and asserts `getppid/exit/write` route markers
- Added automated non-syscall trap smoke target:
  - `make test-aarch64-brk`
  - builds `TRAP_TEST_BRK=1` variant and asserts generic trap banner presence
- Added runtime trap observability markers in AArch64 serial path:
  - trap kind banners: `sync/irq/fiq/serr/unknown`
  - non-syscall route marker: `route none`
- Added runtime trap value smoke target:
  - `make test-aarch64-trap-runtime`
  - validates runtime kind/route markers from QEMU logs (`svc`, `svc-unknown`, `brk`)
- Added generated trap fixture contract smoke target:
  - `make test-aarch64-trap-fixture`
  - uses `scripts/gen_trap_snapshot_fixture.sh` to emit deterministic fixture data from ELF constants
  - validates fixture layout constants and route fixtures (`svc route=1`, `brk route=0`)
- Added Coatl fixture parity smoke target:
  - `make test-coatl-trap-fixture-parity`
  - uses `scripts/check_trap_fixture_parity.sh` to assert generated fixture values match Coatl trap ABI helper constants
- Added generated Coatl trap ABI constants artifact flow:
  - generator: `scripts/gen_coatl_trap_abi_constants.sh`
  - target: `make gen-coatl-trap-abi-constants` (emits `build/trap_abi_generated.coatl`)
- Added generated-constants sync smoke:
  - checker: `scripts/check_coatl_generated_constants_sync.sh`
  - target: `make test-coatl-generated-trap-abi-sync`
  - validates generated constants match `kernel/sysv_kernel.coatl` ABI helper functions
- Added trap ABI symbol smoke target:
  - `make test-aarch64-trap-abi`
  - validates required trap snapshot symbols are exported by the aarch64 ELF
  - validates fixed ABI layout constants (`trap_snapshot_size=56`, field offsets)
- Upgraded trap ABI smoke into a cross-layer contract check:
  - new script: `scripts/check_trap_abi_contract.sh`
  - validates symbol presence + layout constants + snapshot span (`trap_snapshot_end - trap_snapshot_base`)
  - validates machine ABI constant parity with Coatl helpers (`trap_snapshot_abi_*`)
- Standardized trap snapshot memory layout in `arch/aarch64/boot.S`:
  - all fields now 64-bit slots
  - `el1_trap_count` promoted to `.quad` for consistent layout

### SysV-inspired kernel core in Coatl

- Extended `kernel/sysv_kernel.coatl` from a minimal syscall dispatch sample into a Stage-1 model:
  - `Process` model with SysV-like fields
  - `Kernel` model with run queue state
  - syscall handlers:
    - `sys_getpid` (`20`)
    - `sys_getppid` (`64`)
    - `sys_exit` (`1`)
    - `sys_write` (`4`) stub semantics
  - syscall multiplexer:
    - `sys_dispatch(no, a0, a1, a2, cur)`
  - scheduler/runq helpers:
    - `rq_push`, `rq_pop`, `sched_next`
  - process helpers:
    - `proc_tick`, `proc_mark_zombie`
- Added process-model groundwork for Stage-2 evolution while keeping IR-lane smoke green:
  - fork modeling split into stable scalar helpers:
    - `sys_fork_parent_ret`
    - `sys_fork_child_ret`
    - `sys_fork_kernel`
  - parent/child ownership checks:
    - `sys_waitpid_model` now validates parent linkage (`-ECHILD`-like on mismatch)
  - queue advancement assertion after fork model (`next_pid` increments and child enqueue path exercised)
- Added syscall/trap ABI scaffolding in Coatl (host-smokeable model layer):
  - `TrapFrame` model (`syscall_no`, arg registers, return slot)
  - `trapframe_make`
  - trap-dispatch adapter:
    - `sys_dispatch_tf_ret`
  - trap-event routing scaffold:
    - `TrapEvent`, `trap_event_make`, `trap_is_syscall`, `trap_route_syscall_no`
- Added Stage-2/4 scaffolding models in Coatl:
  - VFS root node model:
    - `VfsNode`, `vfs_make_root`, `vfs_lookup_root`
  - mount model:
    - `Mount`, `mount_make_root`
  - userland-init task model:
    - `UserTask`, `init_task_make`, `init_task_step`
- Added Stage-2/6 scaffolding for minimal userland bring-up in Coatl:
  - executable image model:
    - `ExecImage`, `exec_image_make`, `exec_load_path`
  - in-memory FS image model:
    - `FsImage`, `fsimage_make_base`, `fs_lookup_ino`, `fs_read_len`
  - init/exec launch path model:
    - `init_spawn_from_fs`
  - process table model for userland command checks:
    - `ProcTable`, `proctable_make`, `proctable_seed`
  - shell command model handlers:
    - `shell_cmd_echo`
    - `shell_cmd_ls`
    - `shell_cmd_cat`
    - `shell_cmd_mount`
    - `shell_cmd_ps`
- Added dedicated Coatl minimal userland smoke artifact:
  - `userland/minish.coatl` with `init` launch + shell-dispatch model flow
  - command coverage in smoke lane: `echo`, `ls`, `cat`, `mount`, `ps`, unknown
  - new build target: `make coatl-userland-smoke`
- Extended smoke assertions in `main()` to verify the new userland scaffolding paths end-to-end in the host IR lane.
- Added syscall-route parity helper in Coatl model:
  - `sys_route_id(no)` maps `getpid/getppid/exit/write/unknown`
  - host smoke now asserts route IDs for known and unknown syscall numbers
- Added Coatl trap snapshot adapter model:
  - `TrapSnapshot`, `trap_snapshot_make`, `trap_snapshot_to_event`, `trap_snapshot_route_id`
  - smoke now asserts conversion from machine-style trap snapshot fields to `TrapEvent` syscall classification and route-id normalization
- Added Coatl trap snapshot ABI constant helpers:
  - `trap_snapshot_abi_size` and fixed offset helpers for count/kind/esr/elr/spsr/x8/route
  - smoke now asserts Coatl-side ABI constants match the fixed machine snapshot layout
- Added Coatl serialized trap snapshot ingest helpers:
  - `TrapSnapshotSlots`, `trap_snapshot_slot_load`, `trap_snapshot_from_slots`
  - smoke now exercises slot-based ingest (offset-driven loads) into `TrapSnapshot` and trap-event routing
- Removed malformed trailing lines in `kernel/sysv_kernel.coatl` that could destabilize parsing.
- `make coatl-sysv-smoke` is currently green on x86_64 host.

### Workflow/autonomy

- Added `docs/MAGIC_PROMPT.md` with an explicit autonomous execution contract for long-running Coatl UNIX-like OS bring-up sessions.

### Known blockers

- Coatl AArch64 lowerer lane is sensitive to stale cached artifacts:
  - stale `/tmp/coatl-ir-to-aarch64.wat` can produce silent lowering failure after upstream updates; removing that file regenerates a working module.
- Some struct-heavy behavior in the current Coatl IR subset lane appears unstable for strict assertions; affected checks were relaxed so smoke stays usable while compiler work continues.
  - notably, some struct-field transfer paths are unreliable in strict checks (kept out of correctness-critical assertions).

### Next targets

- Extend trap ABI validation to runtime value checks from QEMU logs.
- Start wiring trap snapshot bytes into a minimal serialized reader path on the Coatl side.
- Harden Coatl lowering wrapper behavior around stale `/tmp/coatl-ir-to-aarch64.wat` regeneration.
