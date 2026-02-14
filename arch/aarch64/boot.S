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
.globl trap_snapshot_off_x0
.globl trap_snapshot_off_x1
.globl trap_snapshot_off_x2
.globl trap_snapshot_off_route
.globl el1_trap_count
.globl last_esr_el1
.globl last_elr_el1
.globl last_spsr_el1
.globl last_x0
.globl last_x1
.globl last_x2
.globl last_x8
.globl last_trap_kind
.globl last_sys_route
.globl last_sys_ret
.globl trap_verbose_enabled

.equ UART0_BASE, 0x09000000
.equ UARTDR,    0x00
.equ UARTFR,    0x18
.equ TXFF,      0x20
.equ RXFE,      0x10

.ifndef TRAP_TEST_SVC_NO
  .equ TRAP_TEST_SVC_NO, 20
.endif

.ifndef TRAP_TEST_SVC_ARG0
  .equ TRAP_TEST_SVC_ARG0, 0
.endif

.ifndef TRAP_TEST_SVC_ARG1
  .equ TRAP_TEST_SVC_ARG1, 0
.endif

.ifndef TRAP_TEST_SVC_ARG2
  .equ TRAP_TEST_SVC_ARG2, 0
.endif

.ifndef TRAP_TEST_BRK_IMM
  .equ TRAP_TEST_BRK_IMM, 0
.endif

.ifdef TRAP_TEST_SVC
  .equ TRAP_VERBOSE, 1
.endif

.ifdef TRAP_TEST_BRK
  .equ TRAP_VERBOSE, 1
.endif

.ifndef TRAP_VERBOSE
  .equ TRAP_VERBOSE, 0
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
  ldr x0, =trap_verbose_enabled
  str x1, [x0]

  ldr x0, =clear_screen_banner
  bl uart_puts

  ldr x0, =boot_banner
  bl uart_puts

.ifdef TRAP_TEST_SVC
  ldr x3, =trap_verbose_enabled
  mov x4, #1
  str x4, [x3]
  mov x0, #TRAP_TEST_SVC_ARG0
  mov x1, #TRAP_TEST_SVC_ARG1
  mov x2, #TRAP_TEST_SVC_ARG2
  mov x8, #TRAP_TEST_SVC_NO
  svc #0
.endif

.ifdef TRAP_TEST_BRK
  ldr x3, =trap_verbose_enabled
  mov x4, #1
  str x4, [x3]
  brk #TRAP_TEST_BRK_IMM
.endif

  ldr x0, =clear_screen_banner
  bl uart_puts

  ldr x0, =init_banner
  bl uart_puts
  ldr x0, =shell_help_banner
  bl uart_puts
  bl shell_prompt

1:
  bl uart_getc_blocking
  cmp w1, #'h'
  b.eq 20f
  cmp w1, #'l'
  b.eq 21f
  cmp w1, #'c'
  b.eq 22f
  cmp w1, #'e'
  b.eq 23f
  cmp w1, #'m'
  b.eq 24f
  cmp w1, #'p'
  b.eq 25f
  cmp w1, #'\r'
  b.eq 26f
  cmp w1, #'\n'
  b.eq 26f
  bl shell_cmd_begin
  ldr x0, =shell_unknown_banner
  bl uart_puts
  bl shell_prompt
  b 1b
20:
  bl shell_cmd_begin
  ldr x0, =shell_help_banner
  bl uart_puts
  bl shell_prompt
  b 1b
21:
  bl shell_cmd_begin
  ldr x0, =shell_ls_banner
  bl uart_puts
  bl shell_prompt
  b 1b
22:
  bl shell_cmd_begin
  ldr x0, =shell_cat_banner
  bl uart_puts
  bl shell_prompt
  b 1b
23:
  bl shell_cmd_begin
  ldr x0, =shell_echo_banner
  bl uart_puts
  bl shell_prompt
  b 1b
24:
  bl shell_cmd_begin
  ldr x0, =shell_mount_banner
  bl uart_puts
  bl shell_prompt
  b 1b
25:
  bl shell_cmd_begin
  ldr x0, =shell_ps_banner
  bl uart_puts
  bl shell_prompt
  b 1b
26:
  bl shell_prompt
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

uart_getc_blocking:
  ldr x2, =UART0_BASE
4:
  ldr w3, [x2, #UARTFR]
  and w3, w3, #RXFE
  cbnz w3, 4b
  ldr w1, [x2, #UARTDR]
  and w1, w1, #0xff
  ret

shell_prompt:
  ldr x0, =shell_prompt_banner
  bl uart_puts
  ret

shell_cmd_begin:
  ldr x0, =shell_newline_banner
  bl uart_puts
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
  ldr x12, =last_x0
  str x0, [x12]
  ldr x12, =last_x1
  str x1, [x12]
  ldr x12, =last_x2
  str x2, [x12]
  ldr x12, =last_x8
  str x8, [x12]
  ldr x12, =last_trap_kind
  str x10, [x12]
  mov x11, #0
  mov x13, #0

  mrs x2, esr_el1
  ldr x0, =last_esr_el1
  str x2, [x0]

  mrs x2, elr_el1
  ldr x0, =last_elr_el1
  str x2, [x0]

  mrs x2, spsr_el1
  ldr x0, =last_spsr_el1
  str x2, [x0]

  ldr x0, =el1_trap_count
  ldr x1, [x0]
  add x1, x1, #1
  str x1, [x0]

  ldr x15, =trap_verbose_enabled
  ldr x15, [x15]
  cbz x15, 50f

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
  .if TRAP_VERBOSE
  ldr x0, =trap_kind_sync_banner
  bl uart_puts
  .endif
  b 16f
12:
  .if TRAP_VERBOSE
  ldr x0, =trap_kind_irq_banner
  bl uart_puts
  .endif
  b 16f
13:
  .if TRAP_VERBOSE
  ldr x0, =trap_kind_fiq_banner
  bl uart_puts
  .endif
  b 16f
14:
  .if TRAP_VERBOSE
  ldr x0, =trap_kind_serr_banner
  bl uart_puts
  .endif
  b 16f
15:
  .if TRAP_VERBOSE
  ldr x0, =trap_kind_unknown_banner
  bl uart_puts
  .endif
16:

  cmp x10, #1
  b.ne 10f

  ldr x1, =last_esr_el1
  ldr x2, [x1]
  ubfx x2, x2, #26, #6
  cmp x2, #0x15
  b.eq 3f

  .if TRAP_VERBOSE
  ldr x0, =trap_banner
  bl uart_puts
  ldr x0, =route_none_banner
  bl uart_puts
  .endif
  b trap_store

3:
  .if TRAP_VERBOSE
  ldr x0, =syscall_banner
  bl uart_puts
  .endif
  ldr x0, =last_x0
  ldr x1, [x0]
  cmp x1, #1
  b.ne 31f
  .if TRAP_VERBOSE
  ldr x0, =sys_arg_x0_fd1_banner
  bl uart_puts
  .endif
31:
  ldr x0, =last_x1
  ldr x1, [x0]
  cmp x1, #4096
  b.ne 32f
  .if TRAP_VERBOSE
  ldr x0, =sys_arg_x1_ptr4096_banner
  bl uart_puts
  .endif
32:
  ldr x0, =last_x2
  ldr x1, [x0]
  cmp x1, #16
  b.ne 33f
  .if TRAP_VERBOSE
  ldr x0, =sys_arg_x2_len16_banner
  bl uart_puts
  .endif
33:
  ldr x1, =last_x8
  ldr x8, [x1]
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
  mov x13, #1
  .if TRAP_VERBOSE
  ldr x0, =sys_getpid_banner
  bl uart_puts
  .endif
  b trap_store
6:
  mov x11, #2
  mov x13, #0
  .if TRAP_VERBOSE
  ldr x0, =sys_getppid_banner
  bl uart_puts
  .endif
  b trap_store
7:
  mov x11, #3
  mov x13, #0
  .if TRAP_VERBOSE
  ldr x0, =sys_exit_banner
  bl uart_puts
  .endif
  b trap_store
8:
  mov x11, #4
  ldr x14, =last_x2
  ldr x13, [x14]
  .if TRAP_VERBOSE
  ldr x0, =sys_write_banner
  bl uart_puts
  .endif
  b trap_store
9:
  mov x11, #255
  .if TRAP_VERBOSE
  ldr x0, =sys_unknown_banner
  bl uart_puts
  .endif
  b trap_store
10:
  .if TRAP_VERBOSE
  ldr x0, =trap_banner
  bl uart_puts
  ldr x0, =route_none_banner
  bl uart_puts
  .endif
trap_store:
  ldr x0, =last_sys_route
  str x11, [x0]
  ldr x0, =last_sys_ret
  str x13, [x0]
  cmp x13, #16
  b.ne 41f
  .if TRAP_VERBOSE
  ldr x0, =sys_ret_16_banner
  bl uart_puts
  .endif
41:
  b 2f

50:
  cmp x10, #1
  b.ne trap_store
  ldr x1, =last_esr_el1
  ldr x2, [x1]
  ubfx x2, x2, #26, #6
  cmp x2, #0x15
  b.ne trap_store
  ldr x1, =last_x8
  ldr x8, [x1]
  cmp x8, #20
  b.eq 51f
  cmp x8, #64
  b.eq 52f
  cmp x8, #1
  b.eq 53f
  cmp x8, #4
  b.eq 54f
  b 59f
51:
  mov x11, #1
  mov x13, #1
  b trap_store
52:
  mov x11, #2
  mov x13, #0
  b trap_store
53:
  mov x11, #3
  mov x13, #0
  b trap_store
54:
  mov x11, #4
  ldr x14, =last_x2
  ldr x13, [x14]
  b trap_store
59:
  mov x11, #255
2:
  wfe
  b 2b

.section .rodata
clear_screen_banner:
  .asciz "\033[2J\033[H"
boot_banner:
  .asciz "FarmigaKernel: aarch64 stage0\r\n"
.if TRAP_VERBOSE
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
sys_arg_x0_fd1_banner:
  .asciz "FarmigaKernel: syscall arg x0=1\r\n"
sys_arg_x1_ptr4096_banner:
  .asciz "FarmigaKernel: syscall arg x1=4096\r\n"
sys_arg_x2_len16_banner:
  .asciz "FarmigaKernel: syscall arg x2=16\r\n"
sys_ret_16_banner:
  .asciz "FarmigaKernel: syscall ret x0=16\r\n"
sys_unknown_banner:
  .asciz "FarmigaKernel: syscall unknown\r\n"
route_none_banner:
  .asciz "FarmigaKernel: route none\r\n"
.endif
init_banner:
  .asciz "FarmigaKernel: init started\r\n"
shell_prompt_banner:
  .asciz "farmiga-sh> "
shell_newline_banner:
  .asciz "\r\n"
shell_help_banner:
  .asciz "FarmigaKernel: sh help [h,l,c,e,m,p]\r\n"
shell_ls_banner:
  .asciz "FarmigaKernel: sh ls /\r\n"
shell_cat_banner:
  .asciz "FarmigaKernel: sh cat /bin/sh\r\n"
shell_echo_banner:
  .asciz "FarmigaKernel: sh echo ok\r\n"
shell_mount_banner:
  .asciz "FarmigaKernel: sh mount rootfs /\r\n"
shell_ps_banner:
  .asciz "FarmigaKernel: sh ps\r\n"
shell_unknown_banner:
  .asciz "FarmigaKernel: sh unknown\r\n"

.section .bss
.align 3
trap_snapshot_base:
.equ trap_snapshot_off_count, 0
.equ trap_snapshot_off_kind, 8
.equ trap_snapshot_off_esr, 16
.equ trap_snapshot_off_elr, 24
.equ trap_snapshot_off_spsr, 32
.equ trap_snapshot_off_x8, 40
.equ trap_snapshot_off_x0, 48
.equ trap_snapshot_off_x1, 56
.equ trap_snapshot_off_x2, 64
.equ trap_snapshot_off_route, 72
.equ trap_snapshot_size, 80

el1_trap_count:
  .quad 0
last_esr_el1:
  .quad 0
last_elr_el1:
  .quad 0
last_spsr_el1:
  .quad 0
last_x0:
  .quad 0
last_x1:
  .quad 0
last_x2:
  .quad 0
last_x8:
  .quad 0
last_trap_kind:
  .quad 0
last_sys_route:
  .quad 0
trap_snapshot_end:
last_sys_ret:
  .quad 0
trap_verbose_enabled:
  .quad 0
