#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <sys/time.h>
#include <libusb-1.0/libusb.h>

#define VENDOR_ID        0x1235   // Focusrite-Novation
#define PRODUCT_ID       0x0102   // Launchkey Mini
#define INTERFACE_NUMBER 1        // MIDI Streaming Interface
#define ENDPOINT_IN      0x81     // MIDI IN endpoint (Bulk IN)

int main() {
    libusb_context *ctx = NULL;
    libusb_device_handle *handle = NULL;
    unsigned char buffer[64];
    int transferred;
    int result;

    printf("🎹 Launchkey MIDI Logger with Timestamp & Note Parsing Starting...\n");

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

    printf("✅ MIDI interface claimed. Listening for input...\n");

    while (1) {
        result = libusb_bulk_transfer(handle, ENDPOINT_IN, buffer, sizeof(buffer), &transferred, 1000);
        if (result == 0 && transferred > 0) {
            struct timeval tv;
            gettimeofday(&tv, NULL);
            uint64_t timestamp_us = (uint64_t)tv.tv_sec * 1000000 + tv.tv_usec;

            // MIDI messages are in 4-byte packets in USB MIDI
            for (int i = 0; i < transferred; i += 4) {
                if (i + 3 >= transferred) break;  // Avoid out-of-bounds
                unsigned char cin = buffer[i] & 0x0F;
                unsigned char status = buffer[i + 1];
                unsigned char data1 = buffer[i + 2];
                unsigned char data2 = buffer[i + 3];

                printf("[%llu us] ", timestamp_us);
                printf("Raw: %02X %02X %02X %02X  ", buffer[i], status, data1, data2);

                if ((status & 0xF0) == 0x90 && data2 > 0) {  // Note On, velocity > 0
                    printf("Note On - Note: 0x%02X (%d), Velocity: 0x%02X (%d)\n",
                           data1, data1, data2, data2);
                } else {
                    printf("\n");
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

