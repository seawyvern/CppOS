OUTPUT_ARCH(riscv)
ENTRY(_start)

SECTIONS
{
  . = 0x80200000;

  .text : ALIGN(16)
  {
    KEEP(*(.text.boot))
    *(.text .text.*)
  }

  .rodata : ALIGN(4096)
  {
    *(.rodata .rodata.*)
    *(.srodata .srodata.*)
  }

  .data : ALIGN(4096)
  {
    *(.data .data.*)
    *(.sdata .sdata.*)
  }

  .bss (NOLOAD) : ALIGN(4096)
  {
    __bss_start = .;
    *(.bss .bss.*)
    *(.sbss .sbss.*)
    *(COMMON)
    . = ALIGN(16);
    __bss_end = .;
  }
}
