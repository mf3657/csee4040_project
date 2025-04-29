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
#define HW_REGS_BASE         0xFF200000
#define HW_REGS_SPAN         0x00200000
#define MIDI_INPUT_OFFSET    0x00002008   // FPGA expects real-time input write at different address (address 0x1)

int main() {
    libusb_context *ctx = NULL;
    libusb_device_handle *handle = NULL;
    unsigned char buffer[64];
    int transferred, result;

    // mmap variables
    int mem_fd;
    void *virtual_base;
    volatile uint64_t *midi_input_ptr;

    printf("🎹 Launchkey MIDI Logger with FPGA HW Write (Real-Time User Input) Starting...\n");

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

    midi_input_ptr = (uint64_t *)(virtual_base + MIDI_INPUT_OFFSET);

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
                unsigned char note = buffer[i + 2];
                unsigned char velocity = buffer[i + 3];

                // Only handle valid Note On
                if ((status & 0xF0) == 0x90 && velocity > 0) {
                    // Print decoded output
                    printf("[%llu us] Note On: Note = %d, Velocity = %d\n", timestamp_us, note, velocity);

                    // Pack status, note, velocity and timestamp into 64 bits
                    uint64_t packed_data = 0;
                    packed_data |= ((uint64_t)status << 16);
                    packed_data |= ((uint64_t)note << 8);
                    packed_data |= (uint64_t)velocity;
                    packed_data |= ((uint64_t)(timestamp_us & 0xFFFFFFFF)) << 24;

                    *midi_input_ptr = packed_data; // Write to FPGA

                    usleep(100); // (optional) small delay to avoid overwriting
                }
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
