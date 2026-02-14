.section .text.boot
.globl _start

_start:
  call uart_init
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

uart_init:
  mov $0x3f9, %dx
  xor %al, %al
  out %al, %dx

  mov $0x3fb, %dx
  mov $0x80, %al
  out %al, %dx

  mov $0x3f8, %dx
  mov $0x03, %al
  out %al, %dx

  mov $0x3f9, %dx
  xor %al, %al
  out %al, %dx

  mov $0x3fb, %dx
  mov $0x03, %al
  out %al, %dx

  mov $0x3fa, %dx
  mov $0xC7, %al
  out %al, %dx

  mov $0x3fc, %dx
  mov $0x0B, %al
  out %al, %dx
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

.section .note.Xen
.align 4
.long 4
.long 4
.long 18
.asciz "Xen"
.align 4
.long _start
