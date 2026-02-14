ENTRY(_start)

PHDRS
{
  note PT_NOTE FLAGS(4);
  text PT_LOAD FLAGS(5);
  rodata PT_LOAD FLAGS(4);
  data PT_LOAD FLAGS(6);
}

SECTIONS
{
  . = 0x100000;

  .note : ALIGN(4)
  {
    *(.note*)
  } :text :note

  .text : ALIGN(0x1000)
  {
    *(.text.boot)
    *(.text*)
  } :text

  .rodata : ALIGN(0x1000)
  {
    *(.rodata*)
  } :rodata

  .data : ALIGN(0x1000)
  {
    *(.data*)
  } :data

  .bss : ALIGN(0x1000)
  {
    *(.bss*)
    *(COMMON)
  } :data
}
