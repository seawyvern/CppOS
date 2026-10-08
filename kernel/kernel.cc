#include "drivers/uart.h"

extern "C" void kernel_main() {
  uart_puts("Hello from CppOS\r\n");

  for (;;) {
  }
}
