ENTRY(_start)

PHDRS {
  text PT_LOAD FLAGS(5);
  rodata PT_LOAD FLAGS(4);
  data PT_LOAD FLAGS(6);
}

SECTIONS {
  . = 0x40080000;

  .text : {
    KEEP(*(.text.boot))
    *(.text*)
  } :text

  .rodata : {
    *(.rodata*)
  } :rodata

  .data : {
    *(.data*)
  } :data

  .bss : {
    __bss_start = .;
    *(.bss*)
    *(COMMON)
    __bss_end = .;
  } :data

  . = ALIGN(16);
  __stack_top = . + 0x4000;
}
