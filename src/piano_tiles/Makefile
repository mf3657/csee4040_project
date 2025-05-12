# Makefile for compiling and running vga_test without sudo
TARGET = vga_test
SRC = vga_test.c
CC = gcc
CFLAGS = -Wall -O2

.PHONY: all run clean

all: $(TARGET)

$(TARGET): $(SRC)
	$(CC) $(CFLAGS) -o $@ $^

run: all
	@echo "Running without sudo..."
	@./$(TARGET) || echo "⚠️  Run failed — check permissions for /dev/fpga_intf"

clean:
	rm -f $(TARGET)
