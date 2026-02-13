.section .text.boot
.globl _start
.globl trap_snapshot_base
.globl trap_snapshot_end
.globl trap_snapshot_size
.globl trap_snapshot_off_count
.globl trap_snapshot_off_kind
.globl trap_snapshot_off_esr
.globl trap_snapshot_off_elr
.globl trap_snapshot_off_spsr
.globl trap_snapshot_off_x8
.globl trap_snapshot_off_route
.globl el1_trap_count
.globl last_esr_el1
.globl last_elr_el1
.globl last_spsr_el1
.globl last_x8
.globl last_trap_kind
.globl last_sys_route

.equ UART0_BASE, 0x09000000
.equ UARTDR,    0x00
.equ UARTFR,    0x18
.equ TXFF,      0x20

.ifndef TRAP_TEST_SVC_NO
  .equ TRAP_TEST_SVC_NO, 20
.endif

.ifndef TRAP_TEST_BRK_IMM
  .equ TRAP_TEST_BRK_IMM, 0
.endif

_start:
  ldr x0, =__stack_top
  mov sp, x0

  ldr x0, =vector_table_el1
  msr vbar_el1, x0
  isb

  ldr x0, =el1_trap_count
  mov x1, #0
  str x1, [x0]

  ldr x0, =boot_banner
  bl uart_puts

.ifdef TRAP_TEST_SVC
  mov x8, #TRAP_TEST_SVC_NO
  svc #0
.endif

.ifdef TRAP_TEST_BRK
  brk #TRAP_TEST_BRK_IMM
.endif

1:
  wfe
  b 1b

uart_puts:
  ldrb w1, [x0], #1
  cbz w1, 2f
  bl uart_putc
  b uart_puts
2:
  ret

uart_putc:
  ldr x2, =UART0_BASE
3:
  ldr w3, [x2, #UARTFR]
  and w3, w3, #TXFF
  cbnz w3, 3b
  str w1, [x2, #UARTDR]
  ret

.align 11
vector_table_el1:
  b exc_curr_sp0_sync
  .space 124
  b exc_curr_sp0_irq
  .space 124
  b exc_curr_sp0_fiq
  .space 124
  b exc_curr_sp0_serr
  .space 124
  b exc_curr_spx_sync
  .space 124
  b exc_curr_spx_irq
  .space 124
  b exc_curr_spx_fiq
  .space 124
  b exc_curr_spx_serr
  .space 124
  b exc_lower_a64_sync
  .space 124
  b exc_lower_a64_irq
  .space 124
  b exc_lower_a64_fiq
  .space 124
  b exc_lower_a64_serr
  .space 124
  b exc_lower_a32_sync
  .space 124
  b exc_lower_a32_irq
  .space 124
  b exc_lower_a32_fiq
  .space 124
  b exc_lower_a32_serr
  .space 124

exc_curr_sp0_sync:
  mov x10, #1
  b trap_common
exc_curr_sp0_irq:
  mov x10, #2
  b trap_common
exc_curr_sp0_fiq:
  mov x10, #3
  b trap_common
exc_curr_sp0_serr:
  mov x10, #4
  b trap_common
exc_curr_spx_sync:
  mov x10, #1
  b trap_common
exc_curr_spx_irq:
  mov x10, #2
  b trap_common
exc_curr_spx_fiq:
  mov x10, #3
  b trap_common
exc_curr_spx_serr:
  mov x10, #4
  b trap_common
exc_lower_a64_sync:
  mov x10, #1
  b trap_common
exc_lower_a64_irq:
  mov x10, #2
  b trap_common
exc_lower_a64_fiq:
  mov x10, #3
  b trap_common
exc_lower_a64_serr:
  mov x10, #4
  b trap_common
exc_lower_a32_sync:
  mov x10, #1
  b trap_common
exc_lower_a32_irq:
  mov x10, #2
  b trap_common
exc_lower_a32_fiq:
  mov x10, #3
  b trap_common
exc_lower_a32_serr:
  mov x10, #4
  b trap_common

trap_common:
  ldr x0, =last_trap_kind
  str x10, [x0]
  mov x11, #0

  mrs x2, esr_el1
  ldr x0, =last_esr_el1
  str x2, [x0]

  mrs x2, elr_el1
  ldr x0, =last_elr_el1
  str x2, [x0]

  mrs x2, spsr_el1
  ldr x0, =last_spsr_el1
  str x2, [x0]

  ldr x0, =last_x8
  str x8, [x0]

  ldr x0, =el1_trap_count
  ldr x1, [x0]
  add x1, x1, #1
  str x1, [x0]

  cmp x10, #1
  b.eq 11f
  cmp x10, #2
  b.eq 12f
  cmp x10, #3
  b.eq 13f
  cmp x10, #4
  b.eq 14f
  b 15f
11:
  ldr x0, =trap_kind_sync_banner
  bl uart_puts
  b 16f
12:
  ldr x0, =trap_kind_irq_banner
  bl uart_puts
  b 16f
13:
  ldr x0, =trap_kind_fiq_banner
  bl uart_puts
  b 16f
14:
  ldr x0, =trap_kind_serr_banner
  bl uart_puts
  b 16f
15:
  ldr x0, =trap_kind_unknown_banner
  bl uart_puts
16:

  cmp x10, #1
  b.ne 10f

  ldr x1, =last_esr_el1
  ldr x2, [x1]
  ubfx x2, x2, #26, #6
  cmp x2, #0x15
  b.eq 3f

  ldr x0, =trap_banner
  bl uart_puts
  ldr x0, =route_none_banner
  bl uart_puts
  b 4f

3:
  ldr x0, =syscall_banner
  bl uart_puts
  cmp x8, #20
  b.eq 5f
  cmp x8, #64
  b.eq 6f
  cmp x8, #1
  b.eq 7f
  cmp x8, #4
  b.eq 8f
  b 9f
5:
  mov x11, #1
  ldr x0, =sys_getpid_banner
  bl uart_puts
  b 4f
6:
  mov x11, #2
  ldr x0, =sys_getppid_banner
  bl uart_puts
  b 4f
7:
  mov x11, #3
  ldr x0, =sys_exit_banner
  bl uart_puts
  b 4f
8:
  mov x11, #4
  ldr x0, =sys_write_banner
  bl uart_puts
  b 4f
9:
  mov x11, #255
  ldr x0, =sys_unknown_banner
  bl uart_puts
  b 4f
10:
  ldr x0, =trap_banner
  bl uart_puts
  ldr x0, =route_none_banner
  bl uart_puts
4:
  ldr x0, =last_sys_route
  str x11, [x0]
2:
  wfe
  b 2b

.section .rodata
boot_banner:
  .asciz "FarmigaKernel: aarch64 stage0\r\n"
trap_banner:
  .asciz "FarmigaKernel: el1 trap entered\r\n"
trap_kind_sync_banner:
  .asciz "FarmigaKernel: trap kind sync\r\n"
trap_kind_irq_banner:
  .asciz "FarmigaKernel: trap kind irq\r\n"
trap_kind_fiq_banner:
  .asciz "FarmigaKernel: trap kind fiq\r\n"
trap_kind_serr_banner:
  .asciz "FarmigaKernel: trap kind serr\r\n"
trap_kind_unknown_banner:
  .asciz "FarmigaKernel: trap kind unknown\r\n"
syscall_banner:
  .asciz "FarmigaKernel: el1 sync syscall\r\n"
sys_getpid_banner:
  .asciz "FarmigaKernel: syscall getpid(20)\r\n"
sys_getppid_banner:
  .asciz "FarmigaKernel: syscall getppid(64)\r\n"
sys_exit_banner:
  .asciz "FarmigaKernel: syscall exit(1)\r\n"
sys_write_banner:
  .asciz "FarmigaKernel: syscall write(4)\r\n"
sys_unknown_banner:
  .asciz "FarmigaKernel: syscall unknown\r\n"
route_none_banner:
  .asciz "FarmigaKernel: route none\r\n"

.section .bss
.align 3
trap_snapshot_base:
.equ trap_snapshot_off_count, 0
.equ trap_snapshot_off_kind, 8
.equ trap_snapshot_off_esr, 16
.equ trap_snapshot_off_elr, 24
.equ trap_snapshot_off_spsr, 32
.equ trap_snapshot_off_x8, 40
.equ trap_snapshot_off_route, 48
.equ trap_snapshot_size, 56

el1_trap_count:
  .quad 0
last_esr_el1:
  .quad 0
last_elr_el1:
  .quad 0
last_spsr_el1:
  .quad 0
last_x8:
  .quad 0
last_trap_kind:
  .quad 0
last_sys_route:
  .quad 0
trap_snapshot_end:
