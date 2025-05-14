# ===============================
# Makefile for MIDI FPGA Project
# ===============================

# ---------- Kernel Module ----------
obj-m := fpga_midi.o

KDIR := /lib/modules/$(shell uname -r)/build
PWD  := $(shell pwd)

# ---------- Userspace App ----------
USER_OBJS := build/midi_logger_hw
USER_SRCS := midi_logger_hw.c
USER_INC  := -I.
USER_LIBS := -lusb-1.0

# ---------- Targets ----------
.PHONY: all clean clean_kernel clean_user

all: kernel user

# --- Kernel Module Build ---
kernel:
	@echo "🔧 Building kernel module..."
	$(MAKE) -C $(KDIR) M=$(PWD) modules

# --- Userspace App Build ---
user:
	@echo "🔧 Building userspace app..."
	@mkdir -p build
	gcc -Wall -O2 $(USER_INC) -o $(USER_OBJS) $(USER_SRCS) $(USER_LIBS)

# --- Clean All ---
clean: clean_kernel clean_user

clean_kernel:
	@echo "🧹 Cleaning kernel build..."
	$(MAKE) -C $(KDIR) M=$(PWD) clean

clean_user:
	@echo "🧹 Cleaning userspace build..."
	rm -rf build
