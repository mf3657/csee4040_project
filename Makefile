# ──────────────── Compiler Config ────────────────
CC = gcc
CFLAGS = -Wall -O2 -Iinclude
LIBUSB_CFLAGS = $(shell pkg-config --cflags libusb-1.0)
LIBUSB_LDFLAGS = $(shell pkg-config --libs libusb-1.0)

# ──────────────── File Paths ────────────────
SRC_DIR = src
UTILS = $(SRC_DIR)/utils/midi_parser.c $(SRC_DIR)/utils/hw_writer.c

BIN_DIR = build
BINARIES = $(BIN_DIR)/midi_logger \
           $(BIN_DIR)/midi_logger_hw \
           $(BIN_DIR)/midi_song_loader \
           $(BIN_DIR)/midi_song_loader_hw

KERNEL_NAME = fpga_intf
KERNEL_SRC = fpga_midi.c
KERNEL_OBJ = fpga_midi.ko

# ──────────────── Default Target ────────────────
all: $(BINARIES) $(KERNEL_OBJ)

# ──────────────── User Binary Targets ────────────────
$(BIN_DIR)/midi_logger: $(SRC_DIR)/logger/midi_logger.c $(UTILS)
	@mkdir -p $(BIN_DIR)
	$(CC) $(CFLAGS) $(LIBUSB_CFLAGS) -o $@ $^ $(LIBUSB_LDFLAGS)

$(BIN_DIR)/midi_logger_hw: $(SRC_DIR)/logger/midi_logger_hw.c $(UTILS)
	@mkdir -p $(BIN_DIR)
	$(CC) $(CFLAGS) $(LIBUSB_CFLAGS) -o $@ $^ $(LIBUSB_LDFLAGS)

$(BIN_DIR)/midi_song_loader: $(SRC_DIR)/song_loader/midi_song_loader.c $(UTILS)
	@mkdir -p $(BIN_DIR)
	$(CC) $(CFLAGS) -o $@ $^

$(BIN_DIR)/midi_song_loader_hw: $(SRC_DIR)/song_loader/midi_song_loader_hw.c $(UTILS)
	@mkdir -p $(BIN_DIR)
	$(CC) $(CFLAGS) -o $@ $^

# ──────────────── Kernel Module Targets ────────────────
obj-m := fpga_midi.o

$(KERNEL_OBJ): $(KERNEL_SRC)
	@echo "🧩 Building kernel module: $(KERNEL_OBJ)"
	$(MAKE) -C /lib/modules/$(shell uname -r)/build M=$(PWD) modules

kernel: $(KERNEL_OBJ)

load_kernel: $(KERNEL_OBJ)
	@echo "📦 Loading kernel module..."
	sudo insmod $(KERNEL_OBJ)
	@sleep 0.5
	@dmesg | tail -n 10

unload_kernel:
	@echo "🧹 Unloading kernel module..."
	sudo rmmod $(KERNEL_NAME)
	@sleep 0.5
	@dmesg | tail -n 10

clean_kernel:
	$(MAKE) -C /lib/modules/$(shell uname -r)/build M=$(PWD) clean
	@rm -f *.ko *.mod.* *.o *.order *.symvers .*.cmd

# ──────────────── Run Targets ────────────────
run_logger: $(BIN_DIR)/midi_logger
	@echo "🎧 Running midi_logger..."
	./$<

run_logger_hw: $(BIN_DIR)/midi_logger_hw
	@echo "🎧 Running midi_logger_hw (requires sudo)..."
	sudo ./$<

run_song_loader: $(BIN_DIR)/midi_song_loader
	@echo "🎼 Running midi_song_loader..."
	./$<

run_song_loader_hw: $(BIN_DIR)/midi_song_loader_hw
	@echo "🎼 Running midi_song_loader_hw (requires sudo)..."
	sudo ./$<

# ──────────────── Cleanup ────────────────
clean:
	rm -rf $(BIN_DIR)

.PHONY: all clean kernel clean_kernel load_kernel unload_kernel \
	run run_logger run_logger_hw run_song_loader run_song_loader_hw
