.section .text.boot
.global _start

_start:
  la sp, stack_top
  call kernel_main

1:
  j 1b

.section .bss.stack, "aw", @nobits
.balign 16
stack_bottom:
  .skip 16384
stack_top:
