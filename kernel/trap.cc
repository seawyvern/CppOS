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

extern "C" [[noreturn]] void trap_handler(unsigned long cause,
                                       unsigned long epc,
                                       unsigned long tval) {
  uart_puts("\r\nKernel trap\r\nscause: ");
  print_hex(cause);
  uart_puts("\r\nsepc:   ");
  print_hex(epc);
  uart_puts("\r\nstval:  ");
  print_hex(tval);
  uart_puts("\r\n");

  for (;;) {
  }
}
