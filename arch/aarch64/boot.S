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
.equ UARTCR,    0x30
.equ TXFF,      0x20
.equ TXFE,      0x80
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

  bl uart_init

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

  // Test link to Coatl kernel
  mov w0, #20       // sys_getpid code
  bl sys_route_id
  cmp w0, #1        // Expecting route ID 1
  b.ne 99f
  ldr x0, =coatl_link_ok_banner
  bl uart_puts
99:

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
  bl shell_prompt

1:
  bl shell_readline
  mov x19, x1
  cmp x19, #0
  b.eq 26f

  cmp x19, #5
  b.ne 10f
  ldrb w2, [x0, #0]
  cmp w2, #'c'
  b.ne 10f
  ldrb w2, [x0, #1]
  cmp w2, #'l'
  b.ne 10f
  ldrb w2, [x0, #2]
  cmp w2, #'e'
  b.ne 10f
  ldrb w2, [x0, #3]
  cmp w2, #'a'
  b.ne 10f
  ldrb w2, [x0, #4]
  cmp w2, #'r'
  b.ne 10f
  ldr x0, =clear_screen_banner
  bl uart_puts
  bl shell_prompt
  b 1b

10:
  cmp x19, #4
  b.ne 20f
  ldrb w2, [x0, #0]
  cmp w2, #'h'
  b.ne 20f
  ldrb w2, [x0, #1]
  cmp w2, #'e'
  b.ne 20f
  ldrb w2, [x0, #2]
  cmp w2, #'l'
  b.ne 20f
  ldrb w2, [x0, #3]
  cmp w2, #'p'
  b.ne 20f
  bl shell_cmd_begin
  ldr x0, =shell_help_banner
  bl uart_puts
  bl shell_prompt
  b 1b

20:
  cmp x19, #4
  b.ne 21f
  ldrb w2, [x0, #0]
  cmp w2, #'e'
  b.ne 21f
  ldrb w2, [x0, #1]
  cmp w2, #'x'
  b.ne 21f
  ldrb w2, [x0, #2]
  cmp w2, #'i'
  b.ne 21f
  ldrb w2, [x0, #3]
  cmp w2, #'t'
  b.ne 21f
  bl shell_cmd_begin
  ldr x0, =shell_exit_banner
  bl uart_puts
  bl shell_prompt
  b 1b

21:  // ls
  cmp x19, #2
  b.ne 22f
  ldrb w2, [x0, #0]
  cmp w2, #'l'
  b.ne 22f
  ldrb w2, [x0, #1]
  cmp w2, #'s'
  b.ne 22f
  bl shell_cmd_begin
  ldr x0, =shell_ls_output
  bl uart_puts
  bl shell_prompt
  b 1b

22:  // cat
  cmp x19, #3
  b.lt 23f
  ldrb w2, [x0, #0]
  cmp w2, #'c'
  b.ne 23f
  ldrb w2, [x0, #1]
  cmp w2, #'a'
  b.ne 23f
  ldrb w2, [x0, #2]
  cmp w2, #'t'
  b.ne 23f

  // If length == 3, it's "cat" with no args
  cmp x19, #3
  b.eq 221f
  
  // Must be "cat " (check for space)
  ldrb w2, [x0, #3]
  cmp w2, #' '
  b.ne 227f

  // If length is 4, it's just "cat ", treat like "cat" (loop)
  cmp x19, #4
  b.eq 221f

  // cat with args: check filename
  add x21, x0, #4    // x21 = pointer to filename arg
  
  // Null terminate the line for strcmp
  ldr x2, =shell_line_buf
  add x2, x2, x19
  mov w3, #0
  strb w3, [x2]

  // Try "hello.txt"
  mov x0, x21
  ldr x1, =str_hello_txt
  bl strcmp
  cbz w0, 225f

  // Try "bin"
  mov x0, x21
  ldr x1, =str_bin
  bl strcmp
  cbz w0, 228f

  // Try "etc"
  mov x0, x21
  ldr x1, =str_etc
  bl strcmp
  cbz w0, 228f

  // Try "sh"
  mov x0, x21
  ldr x1, =str_sh
  bl strcmp
  cbz w0, 226f

  // Try "bin/sh"
  mov x0, x21
  ldr x1, =str_bin_sh
  bl strcmp
  cbz w0, 226f

  // Not found
  bl shell_cmd_begin
  ldr x0, =shell_cat_not_found
  bl uart_puts
  mov x0, x21
  bl uart_puts
  ldr x0, =shell_newline_banner
  bl uart_puts
  bl shell_prompt
  b 1b

225: // cat hello.txt
  bl shell_cmd_begin
  ldr x0, =file_hello_content
  bl uart_puts
  bl shell_prompt
  b 1b

226: // cat sh or bin/sh
  bl shell_cmd_begin
  ldr x0, =file_sh_content
  bl uart_puts
  bl shell_prompt
  b 1b

228: // cat directory
  bl shell_cmd_begin
  ldr x0, =shell_cat_prefix
  bl uart_puts
  mov x0, x21
  bl uart_puts
  ldr x0, =shell_cat_is_dir
  bl uart_puts
  bl shell_prompt
  b 1b

227: // command didn't match cat with args, restore x0 and continue
  ldr x0, =shell_line_buf
  b 23f

221: // cat with no args: loop and echo
  bl shell_cmd_begin
  bl uart_mode_tx_rx
222:
  bl uart_getc_blocking
  // Check for Ctrl-C (ETX, ASCII 3)
  cmp w1, #3
  b.eq 223f
  // Check for Ctrl-D (EOT, ASCII 4)
  cmp w1, #4
  b.eq 223f
  
  // Echo the character
  mov w2, w1 // save char
  bl uart_putc
  cmp w2, #'\r'
  b.ne 222b
  mov w1, #'\n'
  bl uart_putc
  b 222b

223:
  bl uart_mode_tx_only
  bl shell_cmd_begin
  bl shell_prompt
  b 1b

23:  // echo
  cmp x19, #4
  b.lt 24f
  ldrb w2, [x0, #0]
  cmp w2, #'e'
  b.ne 24f
  ldrb w2, [x0, #1]
  cmp w2, #'c'
  b.ne 24f
  ldrb w2, [x0, #2]
  cmp w2, #'h'
  b.ne 24f
  ldrb w2, [x0, #3]
  cmp w2, #'o'
  b.ne 24f

  // Check if it's exactly "echo" or "echo "
  cmp x19, #4
  b.eq 231f
  ldrb w2, [x0, #4]
  cmp w2, #' '
  b.ne 24f

231:
  bl shell_cmd_begin
  ldr x0, =shell_line_buf
  cmp x19, #5
  b.lt 232f
  add x0, x0, #5    // x0 points to first char of arg

  // Quote stripping: check if first and last chars are '"'
  ldrb w2, [x0]
  cmp w2, #'"'
  b.ne 235f         // No leading quote

  ldr x2, =shell_line_buf
  add x2, x2, x19
  sub x2, x2, #1    // x2 = pointer to last char
  ldrb w3, [x2]
  cmp w3, #'"'
  b.ne 235f         // No trailing quote

  // Both quotes found: strip them
  add x0, x0, #1    // Skip leading quote
  mov w3, #0
  strb w3, [x2]     // Remove trailing quote (null terminate)

235:
  bl uart_puts
232:
  ldr x0, =shell_newline_banner
  bl uart_puts
  bl shell_prompt
  b 1b

24:  // mount
  cmp x19, #5
  b.ne 245f
  ldrb w2, [x0, #0]
  cmp w2, #'m'
  b.ne 245f
  ldrb w2, [x0, #1]
  cmp w2, #'o'
  b.ne 245f
  ldrb w2, [x0, #2]
  cmp w2, #'u'
  b.ne 245f
  ldrb w2, [x0, #3]
  cmp w2, #'n'
  b.ne 245f
  ldrb w2, [x0, #4]
  cmp w2, #'t'
  b.ne 245f
  bl shell_cmd_begin
  ldr x0, =shell_mount_banner
  bl uart_puts
  bl shell_prompt
  b 1b

245: // hello
  cmp x19, #5
  b.ne 25f
  ldrb w2, [x0, #0]
  cmp w2, #'h'
  b.ne 25f
  ldrb w2, [x0, #1]
  cmp w2, #'e'
  b.ne 25f
  ldrb w2, [x0, #2]
  cmp w2, #'l'
  b.ne 25f
  ldrb w2, [x0, #3]
  cmp w2, #'l'
  b.ne 25f
  ldrb w2, [x0, #4]
  cmp w2, #'o'
  b.ne 25f
  bl shell_cmd_begin
  ldr x0, =hello_banner
  bl uart_puts
  bl shell_prompt
  b 1b

25:  // ps
  cmp x19, #2
  b.ne 27f
  ldrb w2, [x0, #0]
  cmp w2, #'p'
  b.ne 27f
  ldrb w2, [x0, #1]
  cmp w2, #'s'
  b.ne 27f
  bl shell_cmd_begin
  ldr x0, =shell_ps_banner
  bl uart_puts
  bl shell_prompt
  b 1b
26:
  bl shell_prompt
  b 1b
27:
  bl shell_cmd_begin
  ldr x0, =shell_unknown_banner
  bl uart_puts
  bl shell_prompt
  b 1b

uart_puts:
  mov x2, #UART0_BASE
2:
  ldrb w1, [x0], #1
  cbz w1, 3f
4:
  ldr w3, [x2, #UARTFR]
  and w3, w3, #TXFF
  cbnz w3, 4b
  str w1, [x2, #UARTDR]
  b 2b
3:
  ret

uart_putc:
  mov x2, #UART0_BASE
3:
  ldr w3, [x2, #UARTFR]
  and w3, w3, #TXFF
  cbnz w3, 3b
  str w1, [x2, #UARTDR]
  ret

uart_init:
  b uart_mode_tx_only

uart_mode_tx_only:
  mov x2, #UART0_BASE
  mov w3, #0x70
  str w3, [x2, #0x2c]
  mov w3, #0x101
  str w3, [x2, #UARTCR]
  ret

uart_mode_tx_rx:
  mov x2, #UART0_BASE
  mov w3, #0x70
  str w3, [x2, #0x2c]
  mov w3, #0x301
  str w3, [x2, #UARTCR]
  ret

uart_getc_blocking:
  mov x2, #UART0_BASE
4:
  ldr w3, [x2, #UARTFR]
  and w3, w3, #RXFE
  cbnz w3, 4b
  ldr w1, [x2, #UARTDR]
  and w1, w1, #0xff
  ret

shell_prompt:
  ldr x0, =shell_prompt_banner
  b uart_puts

shell_cmd_begin:
  ldr x0, =shell_newline_banner
  b uart_puts

shell_readline:
  sub sp, sp, #16
  str x30, [sp]
  bl uart_mode_tx_rx
  ldr x0, =shell_line_buf
  mov x4, #0
  bl uart_tx_drain
30:
  bl uart_getc_blocking
  cmp w1, #'\r'
  b.eq 31f
  cmp w1, #'\n'
  b.eq 31f

  // Handle backspace (8) or DEL (127)
  cmp w1, #8
  b.eq 35f
  cmp w1, #127
  b.eq 35f

  // Handle Tab (9)
  cmp w1, #9
  b.eq 40f

  // Handle Ctrl+C (3)
  cmp w1, #3
  b.eq 38f

  // Handle ESC (27) for arrow keys etc.
  cmp w1, #27
  b.eq 50f

  cmp x4, #31
  b.ge 30b
  strb w1, [x0, x4]
  bl uart_putc
  add x4, x4, #1
  b 30b

50: // ESC sequence handler
  bl uart_getc_blocking
  cmp w1, #'['
  b.ne 30b // Not a CSI sequence, ignore ESC and continue
51:
  bl uart_getc_blocking
  // Sequences usually end with a char in range 64-126 (@ to ~)
  cmp w1, #64
  b.lt 51b
  cmp w1, #126
  b.gt 51b
  b 30b

38: // Ctrl+C handler
  // Erase current line: for each char in x4, print BS, Space, BS
  cbz x4, 382f
  mov x5, x4
381:
  mov w1, #8
  bl uart_putc
  mov w1, #' '
  bl uart_putc
  mov w1, #8
  bl uart_putc
  sub x5, x5, #1
  cbnz x5, 381b
382:
  mov x4, #0 // clear buffer length
  ldr x0, =shell_line_buf // restore x0
  b 30b

40: // Tab autocompletion
  // Find start of last word
  mov x5, x4 // x5 = current cursor
41:
  cbz x5, 42f
  sub x5, x5, #1
  ldrb w6, [x0, x5]
  cmp w6, #' '
  b.eq 43f
  b 41b
42: // Word starts at beginning of buffer
  mov x5, #0
  b 44f
43: // Word starts at x5 + 1
  add x5, x5, #1
44:
  // Prefix is in shell_line_buf[x5..x4-1]
  // Ignore if prefix is empty
  cmp x5, x4
  b.ge 30b

  // We need a null-terminated copy of the prefix for str_startswith
  sub sp, sp, #32
  mov x7, #0
45:
  add x8, x5, x7
  cmp x8, x4
  b.ge 46f
  ldrb w9, [x0, x8]
  strb w9, [sp, x7]
  add x7, x7, #1
  b 45b
46:
  strb wzr, [sp, x7]
  
  // Search for matches
  cmp x5, #0
  beq 470f
  ldr x10, =file_list
  b 471f
470:
  ldr x10, =command_list
471:
  mov x11, #0 // match count
  mov x12, #0 // last match ptr
47:
  ldr x13, [x10], #8
  cbz x13, 48f
  
  mov x0, x13
  mov x1, sp // prefix copy
  bl str_startswith
  cbz w0, 47b
  
  add x11, x11, #1
  mov x12, x13
  b 47b

48:
  add sp, sp, #32 // restore stack from prefix copy
  ldr x0, =shell_line_buf // RESTORE x0
  
  cbz x11, 30b // no matches, ignore tab
  
  cmp x11, #1
  b.ne 60f // multiple matches, show menu

  // Single match: x12 has the string
  // Append missing part to buffer and echo it
  mov x0, x12
  bl strlen // x0 = total length
  mov x13, x0
  
  // Calculate how many chars to append
  sub x14, x4, x5 // prefix length
  sub x15, x13, x14 // suffix length
  ldr x0, =shell_line_buf // RESTORE x0 again
  cbz x15, 30b // already complete
  
  mov x16, #0
49:
  add x17, x14, x16
  ldrb w18, [x12, x17]
  strb w18, [x0, x4]
  mov w1, w18
  bl uart_putc
  add x4, x4, #1
  add x16, x16, #1
  cmp x16, x15
  b.lt 49b
  
  b 30b

60: // Multiple matches: show menu (fish/zsh style)
  // 1. Move to new line
  ldr x0, =shell_newline_banner
  bl uart_puts
  
  // 2. Print all matches
  cmp x5, #0
  beq 610f
  ldr x10, =file_list
  b 611f
610:
  ldr x10, =command_list
611:
  ldr x13, [x10], #8
  cbz x13, 62f
  
  // Re-push prefix for the loop
  sub sp, sp, #32
  mov x7, #0
  ldr x0, =shell_line_buf
65:
  add x8, x5, x7
  cmp x8, x4
  b.ge 66f
  ldrb w9, [x0, x8]
  strb w9, [sp, x7]
  add x7, x7, #1
  b 65b
66:
  strb wzr, [sp, x7]

  mov x0, x13
  mov x1, sp
  bl str_startswith
  add sp, sp, #32
  cbz w0, 611b
  
  // It's a match, print it
  mov x0, x13
  bl uart_puts
  mov w1, #' '
  bl uart_putc
  b 611b

62:
  // 3. Restore prompt and current buffer
  bl shell_cmd_begin
  bl shell_prompt
  ldr x0, =shell_line_buf
  mov x16, #0
63:
  cmp x16, x4
  b.ge 30b
  ldrb w1, [x0, x16]
  bl uart_putc
  add x16, x16, #1
  b 63b

35: // Backspace handler
  cbz x4, 30b
  sub x4, x4, #1
  mov w1, #8
  bl uart_putc
  mov w1, #' '
  bl uart_putc
  mov w1, #8
  bl uart_putc
  b 30b
31:
  mov w2, #0
  strb w2, [x0, x4]
  mov x1, x4
  bl uart_mode_tx_only
  ldr x30, [sp]
  add sp, sp, #16
  ret

uart_tx_drain:
  mov x2, #UART0_BASE
42:
  ldr w3, [x2, #UARTFR]
  and w3, w3, #TXFE
  cbz w3, 42b
  ret

// strcmp(x0: s1, x1: str2) returns w0: 0 if equal
strcmp:
1:
  ldrb w2, [x0], #1
  ldrb w3, [x1], #1
  cmp w2, w3
  b.ne 2f
  cbz w2, 2f
  b 1b
2:
  sub w0, w2, w3
  ret

// str_startswith(x0: str, x1: prefix) returns w0: 1 if matches, 0 if not
str_startswith:
1:
  ldrb w2, [x1], #1
  cbz w2, 3f // reached end of prefix, success
  ldrb w3, [x0], #1
  cmp w2, w3
  b.ne 2f
  b 1b
2:
  mov w0, #0
  ret
3:
  mov w0, #1
  ret

// strlen(x0: str) returns x0: length
strlen:
  mov x1, #0
1:
  ldrb w2, [x0, x1]
  cbz w2, 2f
  add x1, x1, #1
  b 1b
2:
  mov x0, x1
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
  .asciz "Farmiga: aarch64 stage0\r\n"
coatl_link_ok_banner:
  .asciz "Farmiga: Coatl kernel link established\r\n"
.if TRAP_VERBOSE
trap_banner:
  .asciz "Farmiga: el1 trap entered\r\n"
trap_kind_sync_banner:
  .asciz "Farmiga: trap kind sync\r\n"
trap_kind_irq_banner:
  .asciz "Farmiga: trap kind irq\r\n"
trap_kind_fiq_banner:
  .asciz "Farmiga: trap kind fiq\r\n"
trap_kind_serr_banner:
  .asciz "Farmiga: trap kind serr\r\n"
trap_kind_unknown_banner:
  .asciz "Farmiga: trap kind unknown\r\n"
syscall_banner:
  .asciz "Farmiga: el1 sync syscall\r\n"
sys_getpid_banner:
  .asciz "Farmiga: syscall getpid(20)\r\n"
sys_getppid_banner:
  .asciz "Farmiga: syscall getppid(64)\r\n"
sys_exit_banner:
  .asciz "Farmiga: syscall exit(1)\r\n"
sys_write_banner:
  .asciz "Farmiga: syscall write(4)\r\n"
sys_arg_x0_fd1_banner:
  .asciz "Farmiga: syscall arg x0=1\r\n"
sys_arg_x1_ptr4096_banner:
  .asciz "Farmiga: syscall arg x1=4096\r\n"
sys_arg_x2_len16_banner:
  .asciz "Farmiga: syscall arg x2=16\r\n"
sys_ret_16_banner:
  .asciz "Farmiga: syscall ret x0=16\r\n"
sys_unknown_banner:
  .asciz "Farmiga: syscall unknown\r\n"
route_none_banner:
  .asciz "Farmiga: route none\r\n"
.endif
init_banner:
  .asciz "Farmiga: init started\r\n"
shell_prompt_banner:
  .asciz "farmiga-sh> "
shell_newline_banner:
  .asciz "\r\n"
shell_ctrl_c_banner:
  .asciz "^C\r\n"
shell_help_banner:
  .asciz "Farmiga: sh help [help,ls,cat,echo,mount,clear,hello,ps,exit]\r\n"
hello_banner:
  .asciz "Hello from Farmiga OS!\r\n"
shell_ls_output:
  .asciz "bin\r\netc\r\nhello.txt\r\n"
shell_cat_prefix:
  .asciz "cat: "
shell_cat_not_found:
  .asciz "cat: file not found: "
shell_cat_is_dir:
  .asciz ": Is a directory\r\n"
str_hello_txt:
  .asciz "hello.txt"
str_bin:
  .asciz "bin"
str_etc:
  .asciz "etc"
str_sh:
  .asciz "sh"
str_bin_sh:
  .asciz "bin/sh"
file_hello_content:
  .asciz "This is a test file on the Farmiga mock filesystem.\r\nIt works!\r\n"
file_sh_content:
  .asciz "#!/bin/sh\r\necho \"Farmiga Shell starting...\"\r\n"
shell_echo_banner:
  .asciz "Farmiga: sh echo ok\r\n"
shell_mount_banner:
  .asciz "Farmiga: sh mount rootfs /\r\n"
shell_ps_banner:
  .asciz "Farmiga: sh ps\r\n"
shell_unknown_banner:
  .asciz "Farmiga: sh unknown\r\n"
shell_exit_banner:
  .asciz "Farmiga: sh exit\r\n"

.align 3
command_list:
  .quad str_help
  .quad str_ls
  .quad str_cat
  .quad str_echo
  .quad str_mount
  .quad str_clear
  .quad str_hello
  .quad str_ps
  .quad str_exit
  .quad 0

.align 3
file_list:
  .quad str_hello_txt
  .quad str_bin
  .quad str_etc
  .quad str_bin_sh
  .quad 0

str_help: .asciz "help"
str_ls:   .asciz "ls"
str_cat:  .asciz "cat"
str_echo: .asciz "echo"
str_mount: .asciz "mount"
str_clear: .asciz "clear"
str_hello: .asciz "hello"
// str_ps, str_exit already defined or similar
str_ps:   .asciz "ps"
str_exit: .asciz "exit"

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
shell_line_buf:
  .space 32
