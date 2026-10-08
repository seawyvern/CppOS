#include "drivers/uart.h"

extern "C" void kernel_main() {
  uart_putc('A');

  for (;;) {
  }
}
