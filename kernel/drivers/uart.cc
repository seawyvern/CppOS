#include "uart.h"

void uart_putc(char character) {
  auto* uart = reinterpret_cast<volatile unsigned char*>(0x10000000UL);

  // Wait until the transmit holding register is empty (LSR bit 5).
  while ((uart[5] & 0x20) == 0) {
  }

  uart[0] = static_cast<unsigned char>(character);
}

void uart_puts(const char* text) {
  while (*text != '\0') {
    uart_putc(*text);
    ++text;
  }
}
