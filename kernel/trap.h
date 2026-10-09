#pragma once

struct TrapFrame {
  unsigned long regs[32];
  unsigned long sepc;
  unsigned long sstatus;
  unsigned long scause;
  unsigned long stval;
};

static_assert(sizeof(unsigned long) == 8);
static_assert(sizeof(TrapFrame) == 288);
