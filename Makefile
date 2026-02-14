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
EXPECTED_SYSCALL_WRITE_BANNER ?= FarmigaKernel: syscall write(4)
EXPECTED_SYSCALL_UNKNOWN_BANNER ?= FarmigaKernel: syscall unknown
EXPECTED_TRAP_KIND_SYNC_BANNER ?= FarmigaKernel: trap kind sync
EXPECTED_ROUTE_NONE_BANNER ?= FarmigaKernel: route none
EXPECTED_SYSCALL_ARG_X0_BANNER ?= FarmigaKernel: syscall arg x0=1
EXPECTED_SYSCALL_ARG_X1_BANNER ?= FarmigaKernel: syscall arg x1=4096
EXPECTED_SYSCALL_ARG_X2_BANNER ?= FarmigaKernel: syscall arg x2=16
EXPECTED_SYSCALL_RET_X0_16_BANNER ?= FarmigaKernel: syscall ret x0=16

COATL ?= /home/euxaristia/Projects/Coatl/coatl
COATL_ARCH ?= x86_64
COATL_TOOLCHAIN ?= ir

BUILD_DIR := build
A64_ELF := $(BUILD_DIR)/farmiga-aarch64.elf
A64_IMG := $(BUILD_DIR)/farmiga-aarch64.img
A64_BOOT_OBJ := $(BUILD_DIR)/boot_aarch64.o
COATL_SMOKE_BIN := $(BUILD_DIR)/sysv_kernel_smoke
COATL_USERLAND_SMOKE_BIN := $(BUILD_DIR)/minish_smoke

.PHONY: all validate toolchain-aarch64 aarch64 run-aarch64 test-aarch64 clean coatl-sysv-smoke
.PHONY: test-aarch64-svc test-aarch64-svc-args test-aarch64-svc-ret test-aarch64-svc-unknown test-aarch64-svc-matrix test-aarch64-brk
.PHONY: test-aarch64-trap-abi test-aarch64-trap-runtime test-aarch64-trap-fixture test-coatl-trap-fixture-parity
.PHONY: gen-coatl-trap-abi-constants test-coatl-generated-trap-abi-sync
.PHONY: coatl-userland-smoke

all: aarch64
validate: coatl-sysv-smoke coatl-userland-smoke test-aarch64 test-aarch64-svc test-aarch64-svc-args test-aarch64-svc-ret test-aarch64-svc-unknown test-aarch64-svc-matrix test-aarch64-brk test-aarch64-trap-abi test-aarch64-trap-runtime test-aarch64-trap-fixture test-coatl-trap-fixture-parity test-coatl-generated-trap-abi-sync

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
	if ! grep -Fq "$(EXPECTED_TRAP_KIND_SYNC_BANNER)" "$$out_file"; then \
		echo "QEMU svc trap check failed: trap kind sync marker not found"; \
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

test-aarch64-svc-args: toolchain-aarch64 | $(BUILD_DIR)
	@command -v $(QEMU) >/dev/null 2>&1 || { echo "missing: $(QEMU)"; exit 1; }
	@command -v $(TIMEOUT) >/dev/null 2>&1 || { echo "missing: $(TIMEOUT)"; exit 1; }
	$(AS) --defsym TRAP_TEST_SVC=1 --defsym TRAP_TEST_SVC_NO=4 --defsym TRAP_TEST_SVC_ARG0=1 --defsym TRAP_TEST_SVC_ARG1=4096 --defsym TRAP_TEST_SVC_ARG2=16 -o $(BUILD_DIR)/boot_aarch64_svc_args.o arch/aarch64/boot.S
	$(LD) -T arch/aarch64/linker.ld -o $(BUILD_DIR)/farmiga-aarch64-svc-args.elf $(BUILD_DIR)/boot_aarch64_svc_args.o
	@set -eu; \
	out_file="$(BUILD_DIR)/qemu-aarch64-svc-args.log"; \
	$(TIMEOUT) $(QEMU_TIMEOUT_SECS) $(QEMU) \
		-machine virt \
		-cpu cortex-a72 \
		-nographic \
		-kernel $(BUILD_DIR)/farmiga-aarch64-svc-args.elf \
		> "$$out_file" 2>&1 || true; \
	if ! grep -Fq "$(EXPECTED_BANNER)" "$$out_file"; then \
		echo "QEMU svc args check failed: boot banner not found"; \
		echo "--- qemu output ---"; \
		cat "$$out_file"; \
		exit 1; \
	fi; \
	if ! grep -Fq "$(EXPECTED_SYSCALL_BANNER)" "$$out_file"; then \
		echo "QEMU svc args check failed: syscall banner not found"; \
		echo "--- qemu output ---"; \
		cat "$$out_file"; \
		exit 1; \
	fi; \
	if ! grep -Fq "$(EXPECTED_TRAP_KIND_SYNC_BANNER)" "$$out_file"; then \
		echo "QEMU svc args check failed: trap kind sync marker not found"; \
		echo "--- qemu output ---"; \
		cat "$$out_file"; \
		exit 1; \
	fi; \
	if ! grep -Fq "$(EXPECTED_SYSCALL_ARG_X0_BANNER)" "$$out_file"; then \
		echo "QEMU svc args check failed: x0 marker not found"; \
		echo "--- qemu output ---"; \
		cat "$$out_file"; \
		exit 1; \
	fi; \
	if ! grep -Fq "$(EXPECTED_SYSCALL_ARG_X1_BANNER)" "$$out_file"; then \
		echo "QEMU svc args check failed: x1 marker not found"; \
		echo "--- qemu output ---"; \
		cat "$$out_file"; \
		exit 1; \
	fi; \
	if ! grep -Fq "$(EXPECTED_SYSCALL_ARG_X2_BANNER)" "$$out_file"; then \
		echo "QEMU svc args check failed: x2 marker not found"; \
		echo "--- qemu output ---"; \
		cat "$$out_file"; \
		exit 1; \
	fi; \
	if ! grep -Fq "$(EXPECTED_SYSCALL_WRITE_BANNER)" "$$out_file"; then \
		echo "QEMU svc args check failed: write route marker not found"; \
		echo "--- qemu output ---"; \
		cat "$$out_file"; \
		exit 1; \
	fi; \
	echo "QEMU svc args check passed"

test-aarch64-svc-ret: toolchain-aarch64 | $(BUILD_DIR)
	@command -v $(QEMU) >/dev/null 2>&1 || { echo "missing: $(QEMU)"; exit 1; }
	@command -v $(TIMEOUT) >/dev/null 2>&1 || { echo "missing: $(TIMEOUT)"; exit 1; }
	$(AS) --defsym TRAP_TEST_SVC=1 --defsym TRAP_TEST_SVC_NO=4 --defsym TRAP_TEST_SVC_ARG0=1 --defsym TRAP_TEST_SVC_ARG1=4096 --defsym TRAP_TEST_SVC_ARG2=16 -o $(BUILD_DIR)/boot_aarch64_svc_ret.o arch/aarch64/boot.S
	$(LD) -T arch/aarch64/linker.ld -o $(BUILD_DIR)/farmiga-aarch64-svc-ret.elf $(BUILD_DIR)/boot_aarch64_svc_ret.o
	@set -eu; \
	out_file="$(BUILD_DIR)/qemu-aarch64-svc-ret.log"; \
	$(TIMEOUT) $(QEMU_TIMEOUT_SECS) $(QEMU) \
		-machine virt \
		-cpu cortex-a72 \
		-nographic \
		-kernel $(BUILD_DIR)/farmiga-aarch64-svc-ret.elf \
		> "$$out_file" 2>&1 || true; \
	if ! grep -Fq "$(EXPECTED_BANNER)" "$$out_file"; then \
		echo "QEMU svc ret check failed: boot banner not found"; \
		echo "--- qemu output ---"; \
		cat "$$out_file"; \
		exit 1; \
	fi; \
	if ! grep -Fq "$(EXPECTED_SYSCALL_BANNER)" "$$out_file"; then \
		echo "QEMU svc ret check failed: syscall banner not found"; \
		echo "--- qemu output ---"; \
		cat "$$out_file"; \
		exit 1; \
	fi; \
	if ! grep -Fq "$(EXPECTED_SYSCALL_WRITE_BANNER)" "$$out_file"; then \
		echo "QEMU svc ret check failed: write route marker not found"; \
		echo "--- qemu output ---"; \
		cat "$$out_file"; \
		exit 1; \
	fi; \
	if ! grep -Fq "$(EXPECTED_SYSCALL_RET_X0_16_BANNER)" "$$out_file"; then \
		echo "QEMU svc ret check failed: return marker not found"; \
		echo "--- qemu output ---"; \
		cat "$$out_file"; \
		exit 1; \
	fi; \
	echo "QEMU svc ret check passed"

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
	if ! grep -Fq "$(EXPECTED_TRAP_KIND_SYNC_BANNER)" "$$out_file"; then \
		echo "QEMU svc unknown check failed: trap kind sync marker not found"; \
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
		grep -Fq "$(EXPECTED_TRAP_KIND_SYNC_BANNER)" "$$out" || { echo "QEMU svc matrix check failed($$no): trap kind sync marker missing"; cat "$$out"; exit 1; }; \
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
	if ! grep -Fq "$(EXPECTED_TRAP_KIND_SYNC_BANNER)" "$$out_file"; then \
		echo "QEMU brk trap check failed: trap kind sync marker not found"; \
		echo "--- qemu output ---"; \
		cat "$$out_file"; \
		exit 1; \
	fi; \
	if ! grep -Fq "$(EXPECTED_ROUTE_NONE_BANNER)" "$$out_file"; then \
		echo "QEMU brk trap check failed: route none marker not found"; \
		echo "--- qemu output ---"; \
		cat "$$out_file"; \
		exit 1; \
	fi; \
	echo "QEMU brk trap check passed"

test-aarch64-trap-abi: toolchain-aarch64 $(A64_ELF)
	@NM=$(NM) bash scripts/check_trap_abi_contract.sh $(A64_ELF) kernel/sysv_kernel.coatl

test-aarch64-trap-runtime: test-aarch64-svc test-aarch64-svc-unknown test-aarch64-brk
	@set -eu; \
	grep -Fq "$(EXPECTED_TRAP_KIND_SYNC_BANNER)" "$(BUILD_DIR)/qemu-aarch64-svc.log" || { echo "trap runtime check failed: missing sync kind marker in svc log"; cat "$(BUILD_DIR)/qemu-aarch64-svc.log"; exit 1; }; \
	grep -Fq "$(EXPECTED_SYSCALL_GETPID_BANNER)" "$(BUILD_DIR)/qemu-aarch64-svc.log" || { echo "trap runtime check failed: missing getpid route marker"; cat "$(BUILD_DIR)/qemu-aarch64-svc.log"; exit 1; }; \
	grep -Fq "$(EXPECTED_SYSCALL_UNKNOWN_BANNER)" "$(BUILD_DIR)/qemu-aarch64-svc-unknown.log" || { echo "trap runtime check failed: missing unknown route marker"; cat "$(BUILD_DIR)/qemu-aarch64-svc-unknown.log"; exit 1; }; \
	grep -Fq "$(EXPECTED_ROUTE_NONE_BANNER)" "$(BUILD_DIR)/qemu-aarch64-brk.log" || { echo "trap runtime check failed: missing route-none marker in brk log"; cat "$(BUILD_DIR)/qemu-aarch64-brk.log"; exit 1; }; \
	echo "QEMU trap runtime value check passed"

test-aarch64-trap-fixture: toolchain-aarch64 $(A64_ELF) | $(BUILD_DIR)
	@set -eu; \
	fixture="$(BUILD_DIR)/trap_snapshot_fixture.env"; \
	NM=$(NM) bash scripts/gen_trap_snapshot_fixture.sh $(A64_ELF) "$$fixture"; \
	grep -Eq '^trap_snapshot_size=80$$' "$$fixture" || { echo "trap fixture check failed: size mismatch"; cat "$$fixture"; exit 1; }; \
	grep -Eq '^trap_snapshot_off_count=0$$' "$$fixture" || { echo "trap fixture check failed: off_count mismatch"; cat "$$fixture"; exit 1; }; \
	grep -Eq '^trap_snapshot_off_kind=8$$' "$$fixture" || { echo "trap fixture check failed: off_kind mismatch"; cat "$$fixture"; exit 1; }; \
	grep -Eq '^trap_snapshot_off_esr=16$$' "$$fixture" || { echo "trap fixture check failed: off_esr mismatch"; cat "$$fixture"; exit 1; }; \
	grep -Eq '^trap_snapshot_off_elr=24$$' "$$fixture" || { echo "trap fixture check failed: off_elr mismatch"; cat "$$fixture"; exit 1; }; \
	grep -Eq '^trap_snapshot_off_spsr=32$$' "$$fixture" || { echo "trap fixture check failed: off_spsr mismatch"; cat "$$fixture"; exit 1; }; \
	grep -Eq '^trap_snapshot_off_x8=40$$' "$$fixture" || { echo "trap fixture check failed: off_x8 mismatch"; cat "$$fixture"; exit 1; }; \
	grep -Eq '^trap_snapshot_off_x0=48$$' "$$fixture" || { echo "trap fixture check failed: off_x0 mismatch"; cat "$$fixture"; exit 1; }; \
	grep -Eq '^trap_snapshot_off_x1=56$$' "$$fixture" || { echo "trap fixture check failed: off_x1 mismatch"; cat "$$fixture"; exit 1; }; \
	grep -Eq '^trap_snapshot_off_x2=64$$' "$$fixture" || { echo "trap fixture check failed: off_x2 mismatch"; cat "$$fixture"; exit 1; }; \
	grep -Eq '^trap_snapshot_off_route=72$$' "$$fixture" || { echo "trap fixture check failed: off_route mismatch"; cat "$$fixture"; exit 1; }; \
	grep -Eq '^fixture_svc_route=1$$' "$$fixture" || { echo "trap fixture check failed: svc route fixture mismatch"; cat "$$fixture"; exit 1; }; \
	grep -Eq '^fixture_brk_route=0$$' "$$fixture" || { echo "trap fixture check failed: brk route fixture mismatch"; cat "$$fixture"; exit 1; }; \
	echo "QEMU trap fixture contract check passed"

test-coatl-trap-fixture-parity: test-aarch64-trap-fixture
	@bash scripts/check_trap_fixture_parity.sh $(BUILD_DIR)/trap_snapshot_fixture.env kernel/sysv_kernel.coatl

gen-coatl-trap-abi-constants: test-aarch64-trap-fixture | $(BUILD_DIR)
	@bash scripts/gen_coatl_trap_abi_constants.sh $(BUILD_DIR)/trap_snapshot_fixture.env $(BUILD_DIR)/trap_abi_generated.coatl

test-coatl-generated-trap-abi-sync: gen-coatl-trap-abi-constants
	@bash scripts/check_coatl_generated_constants_sync.sh $(BUILD_DIR)/trap_abi_generated.coatl kernel/sysv_kernel.coatl

coatl-sysv-smoke: kernel/sysv_kernel.coatl | $(BUILD_DIR)
	$(COATL) build kernel/sysv_kernel.coatl --arch=$(COATL_ARCH) --toolchain=$(COATL_TOOLCHAIN) -o $(COATL_SMOKE_BIN)
	$(COATL_SMOKE_BIN)
	@echo "coatl sysv smoke exit=$$?"

coatl-userland-smoke: userland/minish.coatl | $(BUILD_DIR)
	$(COATL) build userland/minish.coatl --arch=$(COATL_ARCH) --toolchain=$(COATL_TOOLCHAIN) -o $(COATL_USERLAND_SMOKE_BIN)
	$(COATL_USERLAND_SMOKE_BIN)
	@echo "coatl userland smoke exit=$$?"

clean:
	rm -rf $(BUILD_DIR)
