CROSS ?= $(shell \
	if command -v aarch64-none-elf-as >/dev/null 2>&1; then \
		printf '%s' aarch64-none-elf-; \
	elif command -v aarch64-linux-gnu-as >/dev/null 2>&1; then \
		printf '%s' aarch64-linux-gnu-; \
	else \
		printf '%s' aarch64-none-elf-; \
	fi)
AS := $(CROSS)as
LD := $(CROSS)ld
OBJCOPY := $(CROSS)objcopy
QEMU ?= qemu-system-aarch64
TIMEOUT ?= timeout
QEMU_TIMEOUT_SECS ?= 5
EXPECTED_BANNER ?= FarmigaKernel: aarch64 stage0

COATL ?= /home/euxaristia/Projects/Coatl/coatl
COATL_ARCH ?= x86_64
COATL_TOOLCHAIN ?= ir

BUILD_DIR := build
A64_ELF := $(BUILD_DIR)/farmiga-aarch64.elf
A64_IMG := $(BUILD_DIR)/farmiga-aarch64.img
A64_BOOT_OBJ := $(BUILD_DIR)/boot_aarch64.o
COATL_SMOKE_BIN := $(BUILD_DIR)/sysv_kernel_smoke

.PHONY: all validate toolchain-aarch64 aarch64 run-aarch64 test-aarch64 clean coatl-sysv-smoke

all: aarch64
validate: coatl-sysv-smoke test-aarch64

toolchain-aarch64:
	@command -v $(AS) >/dev/null 2>&1 || { echo "missing: $(AS)"; echo "install aarch64 cross binutils or set CROSS=<prefix> (example: CROSS=aarch64-linux-gnu-)"; exit 1; }
	@command -v $(LD) >/dev/null 2>&1 || { echo "missing: $(LD)"; echo "install aarch64 cross binutils or set CROSS=<prefix> (example: CROSS=aarch64-linux-gnu-)"; exit 1; }
	@command -v $(OBJCOPY) >/dev/null 2>&1 || { echo "missing: $(OBJCOPY)"; echo "install aarch64 cross binutils or set CROSS=<prefix> (example: CROSS=aarch64-linux-gnu-)"; exit 1; }

aarch64: toolchain-aarch64 $(A64_ELF) $(A64_IMG)

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(A64_BOOT_OBJ): arch/aarch64/boot.S | $(BUILD_DIR)
	$(AS) -o $@ $<

$(A64_ELF): $(A64_BOOT_OBJ) arch/aarch64/linker.ld | $(BUILD_DIR)
	$(LD) -T arch/aarch64/linker.ld -o $@ $(A64_BOOT_OBJ)

$(A64_IMG): $(A64_ELF) | $(BUILD_DIR)
	$(OBJCOPY) -O binary $< $@

run-aarch64: toolchain-aarch64 $(A64_ELF)
	$(QEMU) \
		-machine virt \
		-cpu cortex-a72 \
		-nographic \
		-kernel $(A64_ELF)

test-aarch64: toolchain-aarch64 $(A64_ELF) | $(BUILD_DIR)
	@command -v $(QEMU) >/dev/null 2>&1 || { echo "missing: $(QEMU)"; exit 1; }
	@command -v $(TIMEOUT) >/dev/null 2>&1 || { echo "missing: $(TIMEOUT)"; exit 1; }
	@set -eu; \
	out_file="$(BUILD_DIR)/qemu-aarch64.log"; \
	$(TIMEOUT) $(QEMU_TIMEOUT_SECS) $(QEMU) \
		-machine virt \
		-cpu cortex-a72 \
		-nographic \
		-kernel $(A64_ELF) \
		> "$$out_file" 2>&1 || true; \
	if ! grep -Fq "$(EXPECTED_BANNER)" "$$out_file"; then \
		echo "QEMU boot check failed: expected banner not found"; \
		echo "--- qemu output ---"; \
		cat "$$out_file"; \
		exit 1; \
	fi; \
	echo "QEMU boot check passed"

coatl-sysv-smoke: kernel/sysv_kernel.coatl | $(BUILD_DIR)
	$(COATL) build kernel/sysv_kernel.coatl --arch=$(COATL_ARCH) --toolchain=$(COATL_TOOLCHAIN) -o $(COATL_SMOKE_BIN)
	$(COATL_SMOKE_BIN)
	@echo "coatl sysv smoke exit=$$?"

clean:
	rm -rf $(BUILD_DIR)
