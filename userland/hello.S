.text
.globl _start
_start:
    // 1. Syscall write(1, msg, 14)
    mov x8, #4      // syscall no
    mov x0, #1      // fd
    adr x1, msg     // buf
    mov x2, #14     // len
    svc #0

    // 2. Syscall exit(42)
    mov x8, #1      // syscall no
    mov x0, #42     // code
    svc #0

    // Should never reach here
1:  b 1b

.section .rodata
msg:
    .asciz "Hello from EL0\n"
