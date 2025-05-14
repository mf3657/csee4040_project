# ===============================
# Makefile for MIDI FPGA Project
# ===============================

ifneq ($(KERNELRELEASE),)

# ======== Kernel Module Only ========
obj-m := fpga_midi.o

else

# ======== Full Project Build (User + Kernel) ========
KERNEL_SOURCE := /lib/modules/$(shell uname -r)/build
PWD := $(shell pwd)

# ---------- Userspace App ----------
USER_OBJS := build/midi_logger_hw
USER_SRCS := midi_logger_hw.c
USER_INC  := -I.
USER_LIBS := -lusb-1.0

# ---------- Targets ----------
.PHONY: all kernel user clean clean_kernel clean_user tar

all: kernel user

# --- Kernel Module Build ---
kernel:
	@echo "🔧 Building kernel module..."
	$(MAKE) -C $(KERNEL_SOURCE) M=$(PWD) modules

# --- Userspace App Build ---
user:
	@echo "🔧 Building userspace app..."
	@mkdir -p build
	gcc -Wall -O2 $(USER_INC) -o $(USER_OBJS) $(USER_SRCS) $(USER_LIBS)

# --- Clean ---
clean: clean_kernel clean_user

clean_kernel:
	@echo "🧹 Cleaning kernel build..."
	$(MAKE) -C $(KERNEL_SOURCE) M=$(PWD) clean

clean_user:
	@echo "🧹 Cleaning userspace build..."
	rm -rf build

# --- Tar Project Source ---
TARFILES = Makefile fpga_ioctl.h fpga_midi.c midi_logger_hw.c
TARFILE = midi_fpga_project.tar.gz

tar: $(TARFILE)

$(TARFILE): $(TARFILES)
	tar zcf $(TARFILE) $(TARFILES)

endif
