#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <sys/time.h>
#include <libusb-1.0/libusb.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/ioctl.h>

#include "midi_common.h"
#include "hw_writer.h"
#include "fpga_ioctl.h"  // ✅ Include IOCTL command macros

#define VENDOR_ID        0x1235
#define PRODUCT_ID       0x0102
#define INTERFACE_NUMBER 1
#define ENDPOINT_IN      0x81
#define FPGA_DEVICE      "/dev/fpga_intf"

int main() {
    libusb_context *ctx = NULL;
    libusb_device_handle *handle = NULL;
    unsigned char buffer[64];
    int transferred, result;

    printf("🎹 Launchkey MIDI Logger with Kernel Driver Starting...\n");

    // Open FPGA kernel device
    int fd = open(FPGA_DEVICE, O_RDWR);
    if (fd < 0) {
        perror("❌ Failed to open /dev/fpga_intf");
        return EXIT_FAILURE;
    }

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

    printf("✅ MIDI interface claimed. Listening for input...\n");

    while (1) {
        result = libusb_bulk_transfer(handle, ENDPOINT_IN, buffer, sizeof(buffer), &transferred, 1000);
        if (result == 0 && transferred > 0) {
            struct timeval tv;
            gettimeofday(&tv, NULL);
            uint64_t timestamp_us = (uint64_t)tv.tv_sec * 1000000 + tv.tv_usec;

            for (int i = 0; i < transferred; i += 4) {
                if (i + 3 >= transferred) break;

                uint8_t status   = buffer[i + 1];
                uint8_t note     = buffer[i + 2];
                uint8_t velocity = buffer[i + 3];

                if ((status & 0xF0) == 0x90 && velocity > 0) {
                    uint64_t packet = pack_midi_input(status, note, velocity, timestamp_us);

                    printf("[%llu us] Note On: Note = %d, Velocity = %d\n",
                           timestamp_us, note, velocity);

                    if (ioctl(fd, IOCTL_SEND_MIDI_EVENT, &packet) < 0) {
                        perror("❌ ioctl failed to send MIDI packet");
                    }

                    usleep(100);  // throttle
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
    close(fd);

    return EXIT_SUCCESS;
}
