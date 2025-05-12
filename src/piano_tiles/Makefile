# Makefile for compiling and running vga_test

TARGET = vga_test
SRC = vga_test.c
CC = gcc
CFLAGS = -Wall -O2

.PHONY: all run clean

all: $(TARGET)

$(TARGET): $(SRC)
	$(CC) $(CFLAGS) -o $@ $^

run: $(TARGET)
	sudo ./$(TARGET)

clean:
	rm -f $(TARGET)
