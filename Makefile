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
NM := $(CROSS)nm
QEMU ?= qemu-system-aarch64
TIMEOUT ?= timeout
QEMU_TIMEOUT_SECS ?= 5
EXPECTED_BANNER ?= FarmigaKernel: aarch64 stage0
EXPECTED_SYSCALL_BANNER ?= FarmigaKernel: el1 sync syscall
EXPECTED_SYSCALL_GETPID_BANNER ?= FarmigaKernel: syscall getpid(20)
EXPECTED_SYSCALL_UNKNOWN_BANNER ?= FarmigaKernel: syscall unknown

COATL ?= /home/euxaristia/Projects/Coatl/coatl
COATL_ARCH ?= x86_64
COATL_TOOLCHAIN ?= ir

BUILD_DIR := build
A64_ELF := $(BUILD_DIR)/farmiga-aarch64.elf
A64_IMG := $(BUILD_DIR)/farmiga-aarch64.img
A64_BOOT_OBJ := $(BUILD_DIR)/boot_aarch64.o
COATL_SMOKE_BIN := $(BUILD_DIR)/sysv_kernel_smoke

.PHONY: all validate toolchain-aarch64 aarch64 run-aarch64 test-aarch64 clean coatl-sysv-smoke
.PHONY: test-aarch64-svc test-aarch64-svc-unknown test-aarch64-svc-matrix test-aarch64-brk
.PHONY: test-aarch64-trap-abi

all: aarch64
validate: coatl-sysv-smoke test-aarch64 test-aarch64-svc test-aarch64-svc-unknown test-aarch64-svc-matrix test-aarch64-brk test-aarch64-trap-abi

toolchain-aarch64:
	@command -v $(AS) >/dev/null 2>&1 || { echo "missing: $(AS)"; echo "install aarch64 cross binutils or set CROSS=<prefix> (example: CROSS=aarch64-linux-gnu-)"; exit 1; }
	@command -v $(LD) >/dev/null 2>&1 || { echo "missing: $(LD)"; echo "install aarch64 cross binutils or set CROSS=<prefix> (example: CROSS=aarch64-linux-gnu-)"; exit 1; }
	@command -v $(OBJCOPY) >/dev/null 2>&1 || { echo "missing: $(OBJCOPY)"; echo "install aarch64 cross binutils or set CROSS=<prefix> (example: CROSS=aarch64-linux-gnu-)"; exit 1; }
	@command -v $(NM) >/dev/null 2>&1 || { echo "missing: $(NM)"; echo "install aarch64 cross binutils or set CROSS=<prefix> (example: CROSS=aarch64-linux-gnu-)"; exit 1; }

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

test-aarch64-svc: toolchain-aarch64 | $(BUILD_DIR)
	@command -v $(QEMU) >/dev/null 2>&1 || { echo "missing: $(QEMU)"; exit 1; }
	@command -v $(TIMEOUT) >/dev/null 2>&1 || { echo "missing: $(TIMEOUT)"; exit 1; }
	$(AS) --defsym TRAP_TEST_SVC=1 --defsym TRAP_TEST_SVC_NO=20 -o $(BUILD_DIR)/boot_aarch64_svc.o arch/aarch64/boot.S
	$(LD) -T arch/aarch64/linker.ld -o $(BUILD_DIR)/farmiga-aarch64-svc.elf $(BUILD_DIR)/boot_aarch64_svc.o
	@set -eu; \
	out_file="$(BUILD_DIR)/qemu-aarch64-svc.log"; \
	$(TIMEOUT) $(QEMU_TIMEOUT_SECS) $(QEMU) \
		-machine virt \
		-cpu cortex-a72 \
		-nographic \
		-kernel $(BUILD_DIR)/farmiga-aarch64-svc.elf \
		> "$$out_file" 2>&1 || true; \
	if ! grep -Fq "$(EXPECTED_BANNER)" "$$out_file"; then \
		echo "QEMU svc trap check failed: boot banner not found"; \
		echo "--- qemu output ---"; \
		cat "$$out_file"; \
		exit 1; \
	fi; \
	if ! grep -Fq "$(EXPECTED_SYSCALL_BANNER)" "$$out_file"; then \
		echo "QEMU svc trap check failed: syscall banner not found"; \
		echo "--- qemu output ---"; \
		cat "$$out_file"; \
		exit 1; \
	fi; \
	if ! grep -Fq "$(EXPECTED_SYSCALL_GETPID_BANNER)" "$$out_file"; then \
		echo "QEMU svc trap check failed: getpid syscall marker not found"; \
		echo "--- qemu output ---"; \
		cat "$$out_file"; \
		exit 1; \
	fi; \
	echo "QEMU svc trap check passed"

test-aarch64-svc-unknown: toolchain-aarch64 | $(BUILD_DIR)
	@command -v $(QEMU) >/dev/null 2>&1 || { echo "missing: $(QEMU)"; exit 1; }
	@command -v $(TIMEOUT) >/dev/null 2>&1 || { echo "missing: $(TIMEOUT)"; exit 1; }
	$(AS) --defsym TRAP_TEST_SVC=1 --defsym TRAP_TEST_SVC_NO=999 -o $(BUILD_DIR)/boot_aarch64_svc_unknown.o arch/aarch64/boot.S
	$(LD) -T arch/aarch64/linker.ld -o $(BUILD_DIR)/farmiga-aarch64-svc-unknown.elf $(BUILD_DIR)/boot_aarch64_svc_unknown.o
	@set -eu; \
	out_file="$(BUILD_DIR)/qemu-aarch64-svc-unknown.log"; \
	$(TIMEOUT) $(QEMU_TIMEOUT_SECS) $(QEMU) \
		-machine virt \
		-cpu cortex-a72 \
		-nographic \
		-kernel $(BUILD_DIR)/farmiga-aarch64-svc-unknown.elf \
		> "$$out_file" 2>&1 || true; \
	if ! grep -Fq "$(EXPECTED_BANNER)" "$$out_file"; then \
		echo "QEMU svc unknown check failed: boot banner not found"; \
		echo "--- qemu output ---"; \
		cat "$$out_file"; \
		exit 1; \
	fi; \
	if ! grep -Fq "$(EXPECTED_SYSCALL_BANNER)" "$$out_file"; then \
		echo "QEMU svc unknown check failed: syscall banner not found"; \
		echo "--- qemu output ---"; \
		cat "$$out_file"; \
		exit 1; \
	fi; \
	if ! grep -Fq "$(EXPECTED_SYSCALL_UNKNOWN_BANNER)" "$$out_file"; then \
		echo "QEMU svc unknown check failed: unknown syscall marker not found"; \
		echo "--- qemu output ---"; \
		cat "$$out_file"; \
		exit 1; \
	fi; \
	echo "QEMU svc unknown check passed"

test-aarch64-svc-matrix: toolchain-aarch64 | $(BUILD_DIR)
	@command -v $(QEMU) >/dev/null 2>&1 || { echo "missing: $(QEMU)"; exit 1; }
	@command -v $(TIMEOUT) >/dev/null 2>&1 || { echo "missing: $(TIMEOUT)"; exit 1; }
	@set -eu; \
	for no in 64 1 4; do \
		case "$$no" in \
			64) expect='FarmigaKernel: syscall getppid(64)' ;; \
			1) expect='FarmigaKernel: syscall exit(1)' ;; \
			4) expect='FarmigaKernel: syscall write(4)' ;; \
			*) echo "internal matrix error for $$no"; exit 1 ;; \
		esac; \
		obj="$(BUILD_DIR)/boot_aarch64_svc_$$no.o"; \
		elf="$(BUILD_DIR)/farmiga-aarch64-svc-$$no.elf"; \
		out="$(BUILD_DIR)/qemu-aarch64-svc-$$no.log"; \
		$(AS) --defsym TRAP_TEST_SVC=1 --defsym TRAP_TEST_SVC_NO=$$no -o "$$obj" arch/aarch64/boot.S; \
		$(LD) -T arch/aarch64/linker.ld -o "$$elf" "$$obj"; \
		$(TIMEOUT) $(QEMU_TIMEOUT_SECS) $(QEMU) \
			-machine virt \
			-cpu cortex-a72 \
			-nographic \
			-kernel "$$elf" \
			> "$$out" 2>&1 || true; \
		grep -Fq "$(EXPECTED_BANNER)" "$$out" || { echo "QEMU svc matrix check failed($$no): boot banner missing"; cat "$$out"; exit 1; }; \
		grep -Fq "$(EXPECTED_SYSCALL_BANNER)" "$$out" || { echo "QEMU svc matrix check failed($$no): syscall banner missing"; cat "$$out"; exit 1; }; \
		grep -Fq "$$expect" "$$out" || { echo "QEMU svc matrix check failed($$no): expected route marker missing"; cat "$$out"; exit 1; }; \
	done; \
	echo "QEMU svc matrix check passed"

test-aarch64-brk: toolchain-aarch64 | $(BUILD_DIR)
	@command -v $(QEMU) >/dev/null 2>&1 || { echo "missing: $(QEMU)"; exit 1; }
	@command -v $(TIMEOUT) >/dev/null 2>&1 || { echo "missing: $(TIMEOUT)"; exit 1; }
	$(AS) --defsym TRAP_TEST_BRK=1 --defsym TRAP_TEST_BRK_IMM=42 -o $(BUILD_DIR)/boot_aarch64_brk.o arch/aarch64/boot.S
	$(LD) -T arch/aarch64/linker.ld -o $(BUILD_DIR)/farmiga-aarch64-brk.elf $(BUILD_DIR)/boot_aarch64_brk.o
	@set -eu; \
	out_file="$(BUILD_DIR)/qemu-aarch64-brk.log"; \
	$(TIMEOUT) $(QEMU_TIMEOUT_SECS) $(QEMU) \
		-machine virt \
		-cpu cortex-a72 \
		-nographic \
		-kernel $(BUILD_DIR)/farmiga-aarch64-brk.elf \
		> "$$out_file" 2>&1 || true; \
	if ! grep -Fq "$(EXPECTED_BANNER)" "$$out_file"; then \
		echo "QEMU brk trap check failed: boot banner not found"; \
		echo "--- qemu output ---"; \
		cat "$$out_file"; \
		exit 1; \
	fi; \
	if ! grep -Fq "FarmigaKernel: el1 trap entered" "$$out_file"; then \
		echo "QEMU brk trap check failed: generic trap banner not found"; \
		echo "--- qemu output ---"; \
		cat "$$out_file"; \
		exit 1; \
	fi; \
	echo "QEMU brk trap check passed"

test-aarch64-trap-abi: toolchain-aarch64 $(A64_ELF)
	@set -eu; \
	nm_out="$(BUILD_DIR)/farmiga-aarch64.nm"; \
	$(NM) $(A64_ELF) > "$$nm_out"; \
	grep -Eq '[[:space:]]trap_snapshot_base$$' "$$nm_out" || { echo "trap ABI check failed: missing trap_snapshot_base"; cat "$$nm_out"; exit 1; }; \
	grep -Eq '[[:space:]]trap_snapshot_end$$' "$$nm_out" || { echo "trap ABI check failed: missing trap_snapshot_end"; cat "$$nm_out"; exit 1; }; \
	grep -Eq '[[:space:]]trap_snapshot_size$$' "$$nm_out" || { echo "trap ABI check failed: missing trap_snapshot_size"; cat "$$nm_out"; exit 1; }; \
	grep -Eq '[[:space:]]trap_snapshot_off_count$$' "$$nm_out" || { echo "trap ABI check failed: missing trap_snapshot_off_count"; cat "$$nm_out"; exit 1; }; \
	grep -Eq '[[:space:]]trap_snapshot_off_kind$$' "$$nm_out" || { echo "trap ABI check failed: missing trap_snapshot_off_kind"; cat "$$nm_out"; exit 1; }; \
	grep -Eq '[[:space:]]trap_snapshot_off_esr$$' "$$nm_out" || { echo "trap ABI check failed: missing trap_snapshot_off_esr"; cat "$$nm_out"; exit 1; }; \
	grep -Eq '[[:space:]]trap_snapshot_off_elr$$' "$$nm_out" || { echo "trap ABI check failed: missing trap_snapshot_off_elr"; cat "$$nm_out"; exit 1; }; \
	grep -Eq '[[:space:]]trap_snapshot_off_spsr$$' "$$nm_out" || { echo "trap ABI check failed: missing trap_snapshot_off_spsr"; cat "$$nm_out"; exit 1; }; \
	grep -Eq '[[:space:]]trap_snapshot_off_x8$$' "$$nm_out" || { echo "trap ABI check failed: missing trap_snapshot_off_x8"; cat "$$nm_out"; exit 1; }; \
	grep -Eq '[[:space:]]trap_snapshot_off_route$$' "$$nm_out" || { echo "trap ABI check failed: missing trap_snapshot_off_route"; cat "$$nm_out"; exit 1; }; \
	grep -Eq '[[:space:]]last_esr_el1$$' "$$nm_out" || { echo "trap ABI check failed: missing last_esr_el1"; cat "$$nm_out"; exit 1; }; \
	grep -Eq '[[:space:]]last_elr_el1$$' "$$nm_out" || { echo "trap ABI check failed: missing last_elr_el1"; cat "$$nm_out"; exit 1; }; \
	grep -Eq '[[:space:]]last_spsr_el1$$' "$$nm_out" || { echo "trap ABI check failed: missing last_spsr_el1"; cat "$$nm_out"; exit 1; }; \
	grep -Eq '[[:space:]]last_x8$$' "$$nm_out" || { echo "trap ABI check failed: missing last_x8"; cat "$$nm_out"; exit 1; }; \
	grep -Eq '[[:space:]]last_trap_kind$$' "$$nm_out" || { echo "trap ABI check failed: missing last_trap_kind"; cat "$$nm_out"; exit 1; }; \
	grep -Eq '[[:space:]]last_sys_route$$' "$$nm_out" || { echo "trap ABI check failed: missing last_sys_route"; cat "$$nm_out"; exit 1; }; \
	awk '$$3=="trap_snapshot_size" { if (tolower($$1)!="0000000000000038") { print "trap ABI check failed: trap_snapshot_size=" $$1 " expected 0000000000000038"; exit 1 } }' "$$nm_out"; \
	awk '$$3=="trap_snapshot_off_count" { if (tolower($$1)!="0000000000000000") { print "trap ABI check failed: trap_snapshot_off_count=" $$1 " expected 0"; exit 1 } }' "$$nm_out"; \
	awk '$$3=="trap_snapshot_off_kind" { if (tolower($$1)!="0000000000000008") { print "trap ABI check failed: trap_snapshot_off_kind=" $$1 " expected 8"; exit 1 } }' "$$nm_out"; \
	awk '$$3=="trap_snapshot_off_esr" { if (tolower($$1)!="0000000000000010") { print "trap ABI check failed: trap_snapshot_off_esr=" $$1 " expected 16"; exit 1 } }' "$$nm_out"; \
	awk '$$3=="trap_snapshot_off_elr" { if (tolower($$1)!="0000000000000018") { print "trap ABI check failed: trap_snapshot_off_elr=" $$1 " expected 24"; exit 1 } }' "$$nm_out"; \
	awk '$$3=="trap_snapshot_off_spsr" { if (tolower($$1)!="0000000000000020") { print "trap ABI check failed: trap_snapshot_off_spsr=" $$1 " expected 32"; exit 1 } }' "$$nm_out"; \
	awk '$$3=="trap_snapshot_off_x8" { if (tolower($$1)!="0000000000000028") { print "trap ABI check failed: trap_snapshot_off_x8=" $$1 " expected 40"; exit 1 } }' "$$nm_out"; \
	awk '$$3=="trap_snapshot_off_route" { if (tolower($$1)!="0000000000000030") { print "trap ABI check failed: trap_snapshot_off_route=" $$1 " expected 48"; exit 1 } }' "$$nm_out"; \
	echo "QEMU trap ABI symbol check passed"

coatl-sysv-smoke: kernel/sysv_kernel.coatl | $(BUILD_DIR)
	$(COATL) build kernel/sysv_kernel.coatl --arch=$(COATL_ARCH) --toolchain=$(COATL_TOOLCHAIN) -o $(COATL_SMOKE_BIN)
	$(COATL_SMOKE_BIN)
	@echo "coatl sysv smoke exit=$$?"

clean:
	rm -rf $(BUILD_DIR)
