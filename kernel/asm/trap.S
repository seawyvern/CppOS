.section .text.trap
.balign 4
.global trap_entry

trap_entry:
  csrr a0, scause
  csrr a1, sepc
  csrr a2, stval

  # Fatal kernel traps only: use the current stack and never resume execution.
  andi sp, sp, -16
  tail trap_handler
