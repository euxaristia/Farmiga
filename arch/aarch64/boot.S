.section .text.boot
.globl _start

.equ UART0_BASE, 0x09000000
.equ UARTDR,    0x00
.equ UARTFR,    0x18
.equ TXFF,      0x20

_start:
  ldr x0, =__stack_top
  mov sp, x0

  ldr x0, =vector_table_el1
  msr vbar_el1, x0
  isb

  ldr x0, =el1_trap_count
  mov x1, #0
  str w1, [x0]

  ldr x0, =boot_banner
  bl uart_puts

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
exc_curr_sp0_irq:
exc_curr_sp0_fiq:
exc_curr_sp0_serr:
exc_curr_spx_sync:
exc_curr_spx_irq:
exc_curr_spx_fiq:
exc_curr_spx_serr:
exc_lower_a64_sync:
exc_lower_a64_irq:
exc_lower_a64_fiq:
exc_lower_a64_serr:
exc_lower_a32_sync:
exc_lower_a32_irq:
exc_lower_a32_fiq:
exc_lower_a32_serr:
  ldr x0, =el1_trap_count
  ldr w1, [x0]
  add w1, w1, #1
  str w1, [x0]

  ldr x0, =trap_banner
  bl uart_puts
2:
  wfe
  b 2b

.section .rodata
boot_banner:
  .asciz "FarmigaKernel: aarch64 stage0\r\n"
trap_banner:
  .asciz "FarmigaKernel: el1 trap entered\r\n"

.section .bss
.align 4
el1_trap_count:
  .word 0
