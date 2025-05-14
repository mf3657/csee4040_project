#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/ioctl.h>
#include <libusb-1.0/libusb.h>
#include <sndfile.h>
#include "fpga_intf.h"

#define VENDOR_ID        0x1235
#define PRODUCT_ID       0x0102
#define INTERFACE_NUMBER 1
#define ENDPOINT_IN      0x81

int open_fpga_interface() {
    int fd = open("/dev/fpga_intf", O_RDWR);
    if (fd < 0) {
        perror("Failed to open /dev/fpga_intf");
        exit(EXIT_FAILURE);
    }
    return fd;
}

libusb_device_handle* init_midi_device(libusb_context **ctx) {
    libusb_device_handle *handle;

    if (libusb_init(ctx) < 0) {
        fprintf(stderr, "libusb init failed.\n");
        exit(EXIT_FAILURE);
    }

    handle = libusb_open_device_with_vid_pid(*ctx, VENDOR_ID, PRODUCT_ID);
    if (!handle) {
        fprintf(stderr, "MIDI device not found.\n");
        libusb_exit(*ctx);
        exit(EXIT_FAILURE);
    }

    libusb_set_auto_detach_kernel_driver(handle, 1);
    libusb_detach_kernel_driver(handle, INTERFACE_NUMBER);
    if (libusb_claim_interface(handle, INTERFACE_NUMBER) != 0) {
        fprintf(stderr, "Failed to claim MIDI interface.\n");
        libusb_close(handle);
        libusb_exit(*ctx);
        exit(EXIT_FAILURE);
    }

    return handle;
}


void load_wav_samples(const char *filename, int sample_id, int dev_fd) {
    SNDFILE *file;
    SF_INFO info;
    sf_count_t frames_read;
    fpga_intf_sample_t sample;
    
    memset(&info, 0, sizeof(info));
    file = sf_open(filename, SFM_READ, &info);
    if (!file) {
        fprintf(stderr, "Failed to open %s: %s\n", filename, sf_strerror(NULL));
        return;
    }

    if (info.channels != 1 || info.samplerate != 48000 || info.format != (SF_FORMAT_WAV | SF_FORMAT_PCM_16)) {
        fprintf(stderr, "Unsupported WAV format (must be 16-bit mono @ 48kHz): %s\n", filename);
        sf_close(file);
        return;
    }

    printf("Loading %s as sample %d...\n", filename, sample_id);

    for (int i = 0; i < 48000; ++i) {
        short pcm;
        frames_read = sf_read_short(file, &pcm, 1);
        if (frames_read == 0) break;

        sample.sample = (uint16_t) pcm;

        if (sample_id == 1) {
            if (ioctl(dev_fd, FPGA_INTF_SET_SAMPLE1, &sample) < 0)
                perror("ioctl SET_SAMPLE1 failed");
        } else if (sample_id == 2) {
            if (ioctl(dev_fd, FPGA_INTF_SET_SAMPLE2, &sample) < 0)
                perror("ioctl SET_SAMPLE2 failed");
        }
    }

    sf_close(file);
    printf("Sample %d loaded.\n", sample_id);
}


void handle_midi_packet(unsigned char *packet, int fd) {
    unsigned char status = packet[1];
    unsigned char note   = packet[2];
    unsigned char vel    = packet[3];

    if ((status & 0xF0) == 0x90 && vel > 0) {
        // Note ON
        printf("Note On  - %3d (0x%02X), Vel: %3d\n", note, note, vel);

        fpga_intf_note_t note_cmd = { .note = note };
        if (ioctl(fd, FPGA_INTF_SET_NOTE, &note_cmd) < 0) {
            perror("ioctl FPGA_INTF_SET_NOTE failed");
        }

    } else if ((status & 0xF0) == 0x80 || ((status & 0xF0) == 0x90 && vel == 0)) {
        // Note OFF
        printf("Note Off - %3d (0x%02X)\n", note, note);

        fpga_intf_note_t note_cmd = { .note = 0 };  // send 0 to mute this note
        if (ioctl(fd, FPGA_INTF_SET_NOTE, &note_cmd) < 0) {
            perror("ioctl FPGA_INTF_SET_NOTE (off) failed");
        }
    }
}

int main() {
    int dev_fd = open_fpga_interface();

    load_wav_samples("c3.wav", 1, dev_fd);
    load_wav_samples("c4.wav", 2, dev_fd);

    libusb_context *ctx = NULL;
    libusb_device_handle *midi = init_midi_device(&ctx);

    unsigned char buffer[64];
    int transferred;
    int result;

    printf("Listening for MIDI events...\n");

    while (1) {
        result = libusb_bulk_transfer(midi, ENDPOINT_IN, buffer, sizeof(buffer), &transferred, 1000);
        if (result == 0 && transferred > 0) {
            for (int i = 0; i < transferred; i += 4) {
                if (i + 3 >= transferred) break;
                handle_midi_packet(&buffer[i], dev_fd);
            }
        } else if (result == LIBUSB_ERROR_TIMEOUT) {
            continue;
        } else {
            fprintf(stderr, "MIDI error: %s\n", libusb_error_name(result));
            break;
        }
    }

    libusb_release_interface(midi, INTERFACE_NUMBER);
    libusb_close(midi);
    libusb_exit(ctx);
    close(dev_fd);
    return 0;
}
