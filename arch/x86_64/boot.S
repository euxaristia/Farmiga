.section .text.boot
.globl _start

_start:
  lea boot_banner(%rip), %rsi
  call uart_puts

1:
  hlt
  jmp 1b

uart_puts:
  movzbq (%rsi), %rax
  test %al, %al
  je 2f
  call uart_putc
  inc %rsi
  jmp uart_puts
2:
  ret

uart_putc:
  mov %al, %bl
  mov $0x3fd, %dx
3:
  in %dx, %al
  test $0x20, %al
  jz 3b
  mov $0x3f8, %dx
  mov %bl, %al
  out %al, %dx
  ret

.section .rodata
boot_banner:
  .asciz "FarmigaKernel: x86_64 stage0\r\n"
