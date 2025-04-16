#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <sys/time.h>
#include <libusb-1.0/libusb.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <unistd.h>

#define VENDOR_ID        0x1235
#define PRODUCT_ID       0x0102
#define INTERFACE_NUMBER 1
#define ENDPOINT_IN      0x81

// FPGA memory mapping
#define HW_REGS_BASE     0xFF200000
#define HW_REGS_SPAN     0x00200000
#define MIDI_DATA_OFFSET 0x00001000
#define MIDI_TIME_OFFSET 0x00001004

int main() {
    libusb_context *ctx = NULL;
    libusb_device_handle *handle = NULL;
    unsigned char buffer[64];
    int transferred, result;

    // mmap variables
    int mem_fd;
    void *virtual_base;
    volatile uint32_t *midi_data_ptr;
    volatile uint32_t *midi_time_ptr;

    printf("🎹 Launchkey MIDI Logger with FPGA HW Write Starting...\n");

    // Open /dev/mem and mmap FPGA registers
    if ((mem_fd = open("/dev/mem", O_RDWR | O_SYNC)) == -1) {
        perror("❌ Failed to open /dev/mem");
        return EXIT_FAILURE;
    }

    virtual_base = mmap(NULL, HW_REGS_SPAN, PROT_READ | PROT_WRITE, MAP_SHARED, mem_fd, HW_REGS_BASE);
    if (virtual_base == MAP_FAILED) {
        perror("❌ mmap failed");
        close(mem_fd);
        return EXIT_FAILURE;
    }

    midi_data_ptr = (uint32_t *)(virtual_base + MIDI_DATA_OFFSET);
    midi_time_ptr = (uint32_t *)(virtual_base + MIDI_TIME_OFFSET);

    // Initialize USB
    if (libusb_init(&ctx) < 0) {
        fprintf(stderr, "❌ Failed to initialize libusb.\n");
        return EXIT_FAILURE;
    }

    handle = libusb_open_device_with_vid_pid(ctx, VENDOR_ID, PRODUCT_ID);
    if (!handle) {
        fprintf(stderr, "❌ Could not find Launchkey Mini.\n");
        libusb_exit(ctx);
        return EXIT_FAILURE;
    }

    libusb_set_auto_detach_kernel_driver(handle, 1);
    libusb_detach_kernel_driver(handle, INTERFACE_NUMBER);

    if (libusb_claim_interface(handle, INTERFACE_NUMBER) != 0) {
        fprintf(stderr, "❌ Failed to claim interface.\n");
        libusb_close(handle);
        libusb_exit(ctx);
        return EXIT_FAILURE;
    }

    printf("✅ MIDI interface claimed. Listening and forwarding to FPGA...\n");

    while (1) {
        result = libusb_bulk_transfer(handle, ENDPOINT_IN, buffer, sizeof(buffer), &transferred, 1000);
        if (result == 0 && transferred > 0) {
            struct timeval tv;
            gettimeofday(&tv, NULL);
            uint64_t timestamp_us = (uint64_t)tv.tv_sec * 1000000 + tv.tv_usec;

            for (int i = 0; i < transferred; i += 4) {
                if (i + 3 >= transferred) break;
                unsigned char cin = buffer[i] & 0x0F;
                unsigned char status = buffer[i + 1];
                unsigned char data1 = buffer[i + 2];
                unsigned char data2 = buffer[i + 3];

                // Print decoded output
                printf("[%llu us] Raw: %02X %02X %02X %02X  ", timestamp_us, buffer[i], status, data1, data2);
                if ((status & 0xF0) == 0x90 && data2 > 0) {
                    printf("Note On - Note: 0x%02X (%d), Velocity: 0x%02X (%d)\n", data1, data1, data2, data2);
                } else {
                    printf("\n");
                }

                // Write to FPGA (example: pack into 32 bits: status | note | vel | timestamp LSB)
                uint32_t midi_data_word = (status << 16) | (data1 << 8) | data2;
                uint32_t timestamp_low = (uint32_t)(timestamp_us & 0xFFFFFFFF);

                *midi_data_ptr = midi_data_word;
                *midi_time_ptr = timestamp_low;

                // Optional: add delay if needed to prevent overwriting
                usleep(100); // 100 µs delay (tune this as needed)
            }
        } else if (result == LIBUSB_ERROR_TIMEOUT) {
            continue;
        } else {
            fprintf(stderr, "⚠️ Transfer error: %s\n", libusb_error_name(result));
            break;
        }
    }

    // Cleanup
    libusb_release_interface(handle, INTERFACE_NUMBER);
    libusb_close(handle);
    libusb_exit(ctx);

    munmap((void *)virtual_base, HW_REGS_SPAN);
    close(mem_fd);

    return EXIT_SUCCESS;
}

