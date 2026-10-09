CROSS_COMPILE ?= riscv64-unknown-elf-
CC := $(CROSS_COMPILE)gcc
CXX := $(CROSS_COMPILE)g++
LD := $(CROSS_COMPILE)ld

BUILD_DIR := build
QEMU ?= qemu-system-riscv64
KERNEL := $(BUILD_DIR)/kernel.elf
LINKER_SCRIPT := kernel/ld/linker.ld
OBJECTS := $(BUILD_DIR)/boot.o $(BUILD_DIR)/trap.o \
           $(BUILD_DIR)/kernel.o $(BUILD_DIR)/uart.o \
           $(BUILD_DIR)/trap_handler.o
DEPS := $(OBJECTS:.o=.d)

ARCH_FLAGS := -march=rv64g -mabi=lp64d -mcmodel=medany -fno-pie
CPPFLAGS :=
ASFLAGS := $(ARCH_FLAGS)
CXXFLAGS := $(ARCH_FLAGS) -std=c++20 -ffreestanding \
            -fno-exceptions -fno-rtti -O2 -Wall -Wextra
LDFLAGS := --no-relax

.PHONY: all run clean
.DELETE_ON_ERROR:

all: $(KERNEL)

run: $(KERNEL)
	$(QEMU) -machine virt -smp 1 -m 128M -bios default \
		-kernel $(KERNEL) -nographic

$(KERNEL): $(OBJECTS) $(LINKER_SCRIPT) Makefile
	$(LD) $(LDFLAGS) -T $(LINKER_SCRIPT) $(OBJECTS) -o $@

$(BUILD_DIR)/boot.o: kernel/asm/boot.S Makefile | $(BUILD_DIR)
	$(CC) $(CPPFLAGS) $(ASFLAGS) -MMD -MP -c $< -o $@

$(BUILD_DIR)/trap.o: kernel/asm/trap.S Makefile | $(BUILD_DIR)
	$(CC) $(CPPFLAGS) $(ASFLAGS) -MMD -MP -c $< -o $@

$(BUILD_DIR)/kernel.o: kernel/kernel.cc Makefile | $(BUILD_DIR)
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) -MMD -MP -c $< -o $@

$(BUILD_DIR)/uart.o: kernel/drivers/uart.cc Makefile | $(BUILD_DIR)
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) -MMD -MP -c $< -o $@

$(BUILD_DIR)/trap_handler.o: kernel/trap.cc Makefile | $(BUILD_DIR)
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) -MMD -MP -c $< -o $@

$(BUILD_DIR):
	mkdir -p $@

clean:
	rm -f $(OBJECTS) $(DEPS) $(KERNEL)

-include $(DEPS)
