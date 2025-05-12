CC = gcc
CFLAGS = -Wall -O2 -Iinclude
LIBUSB_CFLAGS = $(shell pkg-config --cflags libusb-1.0)
LIBUSB_LDFLAGS = $(shell pkg-config --libs libusb-1.0)

SRC_DIR = src
UTILS = $(SRC_DIR)/utils/midi_parser.c $(SRC_DIR)/utils/hw_writer.c

BIN_DIR = build
BINARIES = $(BIN_DIR)/midi_logger \
           $(BIN_DIR)/midi_logger_hw \
           $(BIN_DIR)/midi_song_loader \
           $(BIN_DIR)/midi_song_loader_hw

all: $(BINARIES)

# ─────────────────────────────────────────────────────
# Build Targets
# ─────────────────────────────────────────────────────

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

# ─────────────────────────────────────────────────────
# Run Targets
# ─────────────────────────────────────────────────────

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

# Optional default run target
run: run_logger

clean:
	rm -rf $(BIN_DIR)

.PHONY: all clean run_logger run_logger_hw run_song_loader run_song_loader_hw run
