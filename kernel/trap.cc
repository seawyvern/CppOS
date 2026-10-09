#include "drivers/uart.h"
#include "trap.h"

namespace {

void print_hex(unsigned long value) {
  constexpr char digits[] = "0123456789abcdef";
  uart_puts("0x");
  for (int shift = 60; shift >= 0; shift -= 4) {
    uart_putc(digits[(value >> shift) & 0xf]);
  }
}

}  // namespace

extern "C" [[noreturn]] void trap_handler(const TrapFrame* frame) {
  uart_puts("\r\nKernel trap\r\nscause: ");
  print_hex(frame->scause);
  uart_puts("\r\nsepc:   ");
  print_hex(frame->sepc);
  uart_puts("\r\nstval:  ");
  print_hex(frame->stval);
  uart_puts("\r\n");

  for (;;) {
  }
}
