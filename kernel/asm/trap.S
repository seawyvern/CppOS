.section .text.trap
.balign 4
.global trap_entry

trap_entry:
  addi sp, sp, -288

  sd zero, 0(sp)
  sd ra, 8(sp)
  sd t0, 40(sp)

  addi t0, sp, 288
  sd t0, 16(sp)

  sd gp, 24(sp)
  sd tp, 32(sp)
  sd t1, 48(sp)
  sd t2, 56(sp)
  sd s0, 64(sp)
  sd s1, 72(sp)
  sd a0, 80(sp)
  sd a1, 88(sp)
  sd a2, 96(sp)
  sd a3, 104(sp)
  sd a4, 112(sp)
  sd a5, 120(sp)
  sd a6, 128(sp)
  sd a7, 136(sp)
  sd s2, 144(sp)
  sd s3, 152(sp)
  sd s4, 160(sp)
  sd s5, 168(sp)
  sd s6, 176(sp)
  sd s7, 184(sp)
  sd s8, 192(sp)
  sd s9, 200(sp)
  sd s10, 208(sp)
  sd s11, 216(sp)
  sd t3, 224(sp)
  sd t4, 232(sp)
  sd t5, 240(sp)
  sd t6, 248(sp)

  csrr t0, sepc
  sd t0, 256(sp)
  csrr t0, sstatus
  sd t0, 264(sp)
  csrr t0, scause
  sd t0, 272(sp)
  csrr t0, stval
  sd t0, 280(sp)

  # S-mode traps on a valid, ABI-aligned kernel stack; no return yet.
  mv a0, sp
  call trap_handler

1:
  j 1b
