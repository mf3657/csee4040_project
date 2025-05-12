#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <sys/time.h>
#include <libusb-1.0/libusb.h>

#include "midi_common.h"  // For future reuse of transpose_note(), etc.

#define VENDOR_ID        0x1235   // Focusrite-Novation
#define PRODUCT_ID       0x0102   // Launchkey Mini
#define INTERFACE_NUMBER 1        // MIDI Streaming Interface
#define ENDPOINT_IN      0x81     // MIDI IN endpoint (Bulk IN)

// Prints raw and decoded MIDI event with timestamp
void log_midi_packet(const unsigned char *packet, uint64_t timestamp_us) {
    uint8_t status = packet[1];
    uint8_t note   = packet[2];
    uint8_t velocity = packet[3];

    printf("[%llu us] Raw: %02X %02X %02X %02X  ", 
           timestamp_us, packet[0], status, note, velocity);

    if ((status & 0xF0) == 0x90 && velocity > 0) {
        printf("Note On - Note: %d, Velocity: %d\n", note, velocity);
    } else if ((status & 0xF0) == 0x80 || ((status & 0xF0) == 0x90 && velocity == 0)) {
        printf("Note Off - Note: %d\n", note);
    } else {
        printf("Unhandled MIDI event\n");
    }
}

int main() {
    libusb_context *ctx = NULL;
    libusb_device_handle *handle = NULL;
    unsigned char buffer[64];
    int transferred, result;

    printf("🎹 Launchkey MIDI Logger Starting...\n");

    if (libusb_init(&ctx) < 0) {
        fprintf(stderr, "❌ libusb initialization failed.\n");
        return EXIT_FAILURE;
    }

    handle = libusb_open_device_with_vid_pid(ctx, VENDOR_ID, PRODUCT_ID);
    if (!handle) {
        fprintf(stderr, "❌ Could not find Launchkey Mini (VID: 0x1235, PID: 0x0102).\n");
        libusb_exit(ctx);
        return EXIT_FAILURE;
    }

    libusb_set_auto_detach_kernel_driver(handle, 1);
    libusb_detach_kernel_driver(handle, INTERFACE_NUMBER);

    if (libusb_claim_interface(handle, INTERFACE_NUMBER) != 0) {
        fprintf(stderr, "❌ Failed to claim interface %d.\n", INTERFACE_NUMBER);
        libusb_close(handle);
        libusb_exit(ctx);
        return EXIT_FAILURE;
    }

    printf("✅ MIDI interface claimed. Listening for MIDI events...\n");

    while (1) {
        result = libusb_bulk_transfer(handle, ENDPOINT_IN, buffer, sizeof(buffer), &transferred, 1000);
        if (result == 0 && transferred > 0) {
            struct timeval tv;
            gettimeofday(&tv, NULL);
            uint64_t timestamp_us = (uint64_t)tv.tv_sec * 1000000 + tv.tv_usec;

            for (int i = 0; i < transferred; i += 4) {
                if (i + 3 >= transferred) break;
                log_midi_packet(&buffer[i], timestamp_us);
            }
        } else if (result == LIBUSB_ERROR_TIMEOUT) {
            continue;
        } else {
            fprintf(stderr, "⚠️ USB Transfer Error: %s\n", libusb_error_name(result));
            break;
        }
    }

    libusb_release_interface(handle, INTERFACE_NUMBER);
    libusb_close(handle);
    libusb_exit(ctx);

    return EXIT_SUCCESS;
}
