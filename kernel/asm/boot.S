.section .text.boot
.global _start

_start:
  la t0, __bss_start
  la t1, __bss_end

1:
  bgeu t0, t1, 2f
  sd zero, 0(t0)
  addi t0, t0, 8
  j 1b

2:
  la sp, stack_top

  la t0, trap_entry
  csrw stvec, t0

  call kernel_main

3:
  j 3b

.section .bss.stack, "aw", @nobits
.balign 16
stack_bottom:
  .skip 16384
stack_top:
