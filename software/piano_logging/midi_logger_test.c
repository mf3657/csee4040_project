#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <sys/time.h>
#include <libusb-1.0/libusb.h>

#define VENDOR_ID        0x1235   // Focusrite-Novation
#define PRODUCT_ID       0x0102   // Launchkey Mini
#define INTERFACE_NUMBER 1        // MIDI Streaming Interface
#define ENDPOINT_IN      0x81     // MIDI IN endpoint (Bulk IN)

typedef struct {
    uint8_t active;      // 1 = note pressed, 0 = released
    uint64_t timestamp_on; // timestamp when Note On occurred
} ActiveNote;

#define MAX_NOTES 128

int main() {
    libusb_context *ctx = NULL;
    libusb_device_handle *handle = NULL;
    unsigned char buffer[64];
    int transferred;
    int result;

    ActiveNote notes[MAX_NOTES] = {0}; // Track notes 0–127

    printf("🎹 Launchkey MIDI Logger with Polyphonic Tracking Starting...\n");

    if (libusb_init(&ctx) < 0) {
        fprintf(stderr, "❌ Failed to initialize libusb.\n");
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

    result = libusb_claim_interface(handle, INTERFACE_NUMBER);
    if (result != 0) {
        fprintf(stderr, "❌ Failed to claim interface %d (error %d).\n", INTERFACE_NUMBER, result);
        libusb_close(handle);
        libusb_exit(ctx);
        return EXIT_FAILURE;
    }

    printf("✅ MIDI interface claimed. Listening for key presses...\n");

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
                unsigned char data1 = buffer[i + 2]; // Note number
                unsigned char data2 = buffer[i + 3]; // Velocity

                if ((status & 0xF0) == 0x90 && data2 > 0) {  // Note On
                    notes[data1].active = 1;
                    notes[data1].timestamp_on = timestamp_us;

                    printf("🎵 Note ON  - Note: %3d  | Time: %llu us\n", data1, timestamp_us);

                } else if (((status & 0xF0) == 0x80) || ((status & 0xF0) == 0x90 && data2 == 0)) { // Note Off
                    if (notes[data1].active) {
                        uint64_t press_time = notes[data1].timestamp_on;
                        uint64_t duration = timestamp_us - press_time;

                        printf("🔚 Note OFF - Note: %3d  | Pressed at: %llu us | Released at: %llu us | Duration: %llu ms\n",
                               data1, press_time, timestamp_us, duration / 1000);

                        notes[data1].active = 0;
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

    libusb_release_interface(handle, INTERFACE_NUMBER);
    libusb_close(handle);
    libusb_exit(ctx);

    return EXIT_SUCCESS;
}

//need to test for polyphony when using keyboard