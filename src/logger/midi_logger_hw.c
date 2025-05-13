#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <sys/time.h>
#include <libusb-1.0/libusb.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <unistd.h>

#include "midi_common.h"
#include "hardware_defs.h"
#include "hw_writer.h"  // ✅ Use shared pack_midi_input()

#define VENDOR_ID        0x1235
#define PRODUCT_ID       0x0102
#define INTERFACE_NUMBER 1
#define ENDPOINT_IN      0x81

int main() {
    libusb_context *ctx = NULL;
    libusb_device_handle *handle = NULL;
    unsigned char buffer[64];
    int transferred, result;

    int mem_fd;
    void *virtual_base;
    volatile uint64_t *midi_input_ptr;
    volatile uint32_t *song_ctrl_ptr;

    printf("🎹 Launchkey MIDI Logger with FPGA HW Write (Real-Time Input) Starting...\n");

    // FPGA memory access
    mem_fd = open("/dev/mem", O_RDWR | O_SYNC);
    if (mem_fd == -1) {
        perror("❌ Failed to open /dev/mem");
        return EXIT_FAILURE;
    }

    virtual_base = mmap(NULL, HW_REGS_SPAN, PROT_READ | PROT_WRITE, MAP_SHARED, mem_fd, HW_REGS_BASE);
    if (virtual_base == MAP_FAILED) {
        perror("❌ mmap failed");
        close(mem_fd);
        return EXIT_FAILURE;
    }

    midi_input_ptr = (uint64_t *)((uint8_t *)virtual_base + MIDI_INPUT_OFFSET);
    song_ctrl_ptr  = (uint32_t *)((uint8_t *)virtual_base + SONG_CTRL_OFFSET);  // ctrl[3] = game_started_hw

    // Initialize USB MIDI connection
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
        fprintf(stderr, "❌ Failed to claim MIDI interface.\n");
        libusb_close(handle);
        libusb_exit(ctx);
        return EXIT_FAILURE;
    }

    printf("✅ MIDI interface claimed. Listening...\n");

    while (1) {
        result = libusb_bulk_transfer(handle, ENDPOINT_IN, buffer, sizeof(buffer), &transferred, 1000);
        if (result == 0 && transferred > 0) {
            struct timeval tv;
            gettimeofday(&tv, NULL);
            uint64_t timestamp_us = (uint64_t)tv.tv_sec * 1000000 + tv.tv_usec;

            // Only send data if game has started
            int game_started = song_ctrl_ptr[3];  // [3] = game_started_hw

            for (int i = 0; i < transferred; i += 4) {
                if (i + 3 >= transferred) break;

                uint8_t status = buffer[i + 1];
                uint8_t note = buffer[i + 2];
                uint8_t velocity = buffer[i + 3];

                if ((status & 0xF0) == 0x90 && velocity > 0) {
                    printf("[%llu us] Note On: Note = %d, Velocity = %d %s\n",
                           timestamp_us, note, velocity,
                           game_started ? "✅ sent" : "(preview)");

                    if (game_started) {
                        uint64_t packet = pack_midi_input(status, note, velocity, timestamp_us);
                        *midi_input_ptr = packet;
                        usleep(100);  // avoid bus contention
                    }
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

    munmap(virtual_base, HW_REGS_SPAN);
    close(mem_fd);

    return EXIT_SUCCESS;
}
