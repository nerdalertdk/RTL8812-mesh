SHELL := /bin/sh

KVER ?= $(if $(KERNELRELEASE),$(KERNELRELEASE),$(shell uname -r))
KSRC ?= $(if $(KERNEL_SRC),$(KERNEL_SRC),/lib/modules/$(KVER)/build)
JOBS ?= $(shell nproc 2>/dev/null || echo 1)
DEPMOD ?= /sbin/depmod
INSTALL_MOD_DIR ?= updates/rtl8812au-mesh
MODDESTDIR := $(INSTALL_MOD_PATH)/lib/modules/$(KVER)/$(INSTALL_MOD_DIR)
FWDIR := $(INSTALL_MOD_PATH)/lib/firmware/rtw88
MODULES := rtw_core rtw_usb rtw_88xxa rtw_8812a rtw_8812au

ifneq ($(strip $(INSTALL_MOD_PATH)),)
DEPMOD_CMD = $(DEPMOD) -b "$(INSTALL_MOD_PATH)" "$(KVER)"
else
DEPMOD_CMD = $(DEPMOD) "$(KVER)"
endif

ccflags-y += -O2 -std=gnu11 -Wno-declaration-after-statement
ccflags-y += -DCONFIG_RTW88_LEDS=1
ccflags-y += -DCONFIG_RTW88_DEBUG=1
ccflags-y += -DCONFIG_RTW88_DEBUGFS=1
ccflags-y += -D__CHECK_ENDIAN__

obj-m += rtw_core.o
rtw_core-objs := main.o led.o mac80211.o util.o debug.o tx.o rx.o mac.o \
		 phy.o coex.o efuse.o fw.o ps.o sec.o bf.o regd.o sar.o

ifeq ($(CONFIG_PM),y)
rtw_core-objs += wow.o
endif

obj-m += rtw_usb.o
rtw_usb-objs := usb.o

obj-m += rtw_88xxa.o
rtw_88xxa-objs := rtw88xxa.o

obj-m += rtw_8812a.o
rtw_8812a-objs := rtw8812a.o rtw8812a_table.o

obj-m += rtw_8812au.o
rtw_8812au-objs := rtw8812au.o

.PHONY: all check-static clean preflight install install_fw uninstall

all:
	$(MAKE) -j$(JOBS) -C $(KSRC) M=$$PWD modules

check-static:
	./scripts/check-upstream-baseline.sh
	./scripts/check-upstream-series.sh
	./scripts/check-hardware-event-classifiers.sh
	@set -e; for script in scripts/*.sh tests/*.sh; do \
		sh -n "$$script"; \
	done
	@echo "shell_syntax=clean"

clean:
	$(MAKE) -C $(KSRC) M=$$PWD clean

preflight:
	@if [ -n "$(INSTALL_MOD_PATH)" ]; then \
		echo "Skipping loaded-module check for staged root $(INSTALL_MOD_PATH)"; \
	else \
		./scripts/check-loaded-rtw88-conflicts.sh; \
	fi

install: preflight all
	@install -d "$(MODDESTDIR)"
	@set -e; for module in $(MODULES); do \
		install -m 0644 "$$module.ko" "$(MODDESTDIR)/$$module.ko"; \
	done
	@$(DEPMOD_CMD)
	@echo "Installed RTL8812AU mesh modules in $(MODDESTDIR)"

install_fw:
	@install -D -m 0644 firmware/rtw8812a_fw.bin \
		"$(FWDIR)/rtw8812a_fw.bin"
	@echo "Installed RTL8812A firmware in $(FWDIR)"

uninstall:
	@set -e; for module in $(MODULES); do \
		rm -f "$(MODDESTDIR)/$$module.ko" \
		      "$(MODDESTDIR)/$$module.ko.gz" \
		      "$(MODDESTDIR)/$$module.ko.xz" \
		      "$(MODDESTDIR)/$$module.ko.zst"; \
	done
	@rmdir "$(MODDESTDIR)" 2>/dev/null || true
	@$(DEPMOD_CMD)
	@echo "Removed RTL8812AU mesh modules from $(MODDESTDIR)"
