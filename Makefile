# === Variables ===
PWD         := $(shell pwd)
KVERSION    := $(shell uname -r)
KERNEL_SRC  ?= /lib/modules/$(KVERSION)/build
BUILD_DIR   := $(PWD)/build
BUILD_DIR_MAKEFILE := $(BUILD_DIR)/Makefile

# === Signing keys (optional) ===
SIGN_KEY    ?= ~/signing_key.priv
SIGN_CERT   ?= ~/signing_key.x509
SIGN_TOOL   := $(KERNEL_SRC)/scripts/sign-file
SIGN_HASH   := sha256
SUDO        ?= sudo

MODULE_FILES := mfd-ch347.ko i2c-ch347.ko gpio-ch347.ko spi-ch347.ko
MODULE_NAMES_UNLOAD := spi_ch347 gpio_ch347 i2c_ch347 mfd_ch347

# === Object files ===
obj-m += mfd-ch347.o
obj-m += i2c-ch347.o
obj-m += gpio-ch347.o
obj-m += spi-ch347.o

# === Targets ===
all: $(BUILD_DIR_MAKEFILE)
	$(MAKE) -C $(KERNEL_SRC) M=$(BUILD_DIR) src=$(PWD) modules
	@cp -u $(BUILD_DIR)/*.ko $(PWD) 2>/dev/null || true
	@echo "Modules (*.ko files) copied to source directory."
ifneq ("$(wildcard $(SIGN_KEY))","")
	@for m in $(PWD)/*.ko; do \
		echo "Signing $$m"; \
		$(SIGN_TOOL) $(SIGN_HASH) $(SIGN_KEY) $(SIGN_CERT) $$m; \
		if modinfo $$m >/dev/null 2>&1; then \
			echo "$$m signed and verified successfully"; \
		else \
			echo "ERROR: $$m signature verification failed"; \
			exit 1; \
		fi \
	done
	@echo "All modules signed."
else
	@echo "No signing keys found, skipping signing step."
endif

clean:
	$(MAKE) -C $(KERNEL_SRC) M=$(BUILD_DIR) src=$(PWD) clean
	@rm -rf $(BUILD_DIR)
	@rm -f $(PWD)/*.ko

modules_install:
	$(MAKE) -C $(KERNEL_SRC) M=$(BUILD_DIR) src=$(PWD) modules_install

load: all
	@set -e; \
	for m in $(MODULE_FILES); do \
		name=$$(echo "$${m%.ko}" | tr '-' '_'); \
		if lsmod | awk '{print $$1}' | grep -qx "$$name"; then \
			echo "$$name is already loaded, skipping"; \
		else \
			echo "Loading $$m"; \
			$(SUDO) insmod "$(PWD)/$$m"; \
		fi; \
	done

unload:
	@set -e; \
	for name in $(MODULE_NAMES_UNLOAD); do \
		if lsmod | awk '{print $$1}' | grep -qx "$$name"; then \
			echo "Unloading $$name"; \
			$(SUDO) rmmod "$$name"; \
		else \
			echo "$$name is not loaded, skipping"; \
		fi; \
	done

$(BUILD_DIR):
	@mkdir -p "$@"

$(BUILD_DIR_MAKEFILE): $(BUILD_DIR)
	@touch "$@"
