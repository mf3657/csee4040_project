/* * Device driver for the VGA video generator
 *
 * A Platform device implemented using the misc subsystem
 *
 * Stephen A. Edwards
 * Columbia University
 *
 * References:
 * Linux source: Documentation/driver-model/platform.txt
 *               drivers/misc/arm-charlcd.c
 * http://www.linuxforu.com/tag/linux-device-drivers/
 * http://free-electrons.com/docs/
 *
 * "make" to build
 * insmod fpga_intf.ko
 *
 * Check code style with
 * checkpatch.pl --file --no-tree fpga_intf.c
 */

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/mman.h>
#include <time.h>

#include "fpga_intf.h"


#define MAX_ACTIVE_NOTES 128

typedef struct {
    uint8_t note;
    uint8_t velocity;
    uint32_t start_ticks;
    uint32_t start_us;
    int active;
} ActiveNote;

static volatile uint8_t *song_loader_base = NULL;
static void *virtual_base = NULL;

// ------------------- MIDI Helpers -------------------

int load_midi_file(const char *filename, MidiFile *midi) {
    FILE *f = fopen(filename, "rb");
    if (!f) {
        perror("Cannot open MIDI file");
        return -1;
    }

    fseek(f, 0, SEEK_END);
    midi->size = ftell(f);
    fseek(f, 0, SEEK_SET);
    midi->data = (uint8_t *)malloc(midi->size);
    if (!midi->data) {
        fclose(f);
        fprintf(stderr, "Memory allocation failed\n");
        return -1;
    }
    fread(midi->data, 1, midi->size, f);
    fclose(f);

    if (memcmp(midi->data, "MThd", 4) != 0) {
        fprintf(stderr, " Not a valid MIDI file\n");
        free(midi->data);
        return -1;
    }

    midi->division = read16(midi->data + 12);
    midi->tempo_us_per_quarter = 500000;
    return 0;
}

void write_midi_packet(uint64_t packet) {
    for (int i = 7; i >= 4; i--) {
        song_loader_base[4] = (packet >> (8 * i)) & 0xFF;
        usleep(100);
    }
    for (int i = 3; i >= 0; i--) {
        song_loader_base[5] = (packet >> (8 * i)) & 0xFF;
        usleep(100);
    }
    song_loader_base[6] = 0x01;
}

void parse_and_send_midi(MidiFile *midi) {
    const uint8_t *ptr = midi->data + 14;
    if (memcmp(ptr, "MTrk", 4) != 0) {
        fprintf(stderr, " No MTrk chunk found\n");
        return;
    }
    ptr += 8;

    ActiveNote active_notes[MAX_ACTIVE_NOTES] = {0};
    uint32_t current_ticks = 0;
    uint8_t last_status = 0;
    double micros_per_tick = (double)midi->tempo_us_per_quarter / midi->division;

    while (ptr < midi->data + midi->size) {
        uint32_t delta_ticks = read_variable_length(&ptr);
        current_ticks += delta_ticks;
        uint32_t current_us = (uint32_t)(current_ticks * micros_per_tick);

        uint8_t status = *ptr;
        if (status < 0x80) {
            status = last_status;
        } else {
            ptr++;
            last_status = status;
        }

        if (status == 0xFF && ptr[0] == 0x51 && ptr[1] == 0x03) {
            ptr += 2;
            uint32_t new_tempo = (ptr[0] << 16) | (ptr[1] << 8) | ptr[2];
            midi->tempo_us_per_quarter = new_tempo;
            micros_per_tick = (double)new_tempo / midi->division;
            printf("🎼 Tempo Change: %u us/quarter → %.2f µs/tick\n", new_tempo, micros_per_tick);
            ptr += 3;
            continue;
        }

        if ((status & 0xF0) == 0x90 && ptr[1] > 0) {
            uint8_t note = transpose_note(ptr[0]);
            uint8_t velocity = ptr[1];

            active_notes[note].note = note;
            active_notes[note].velocity = velocity;
            active_notes[note].start_ticks = current_ticks;
            active_notes[note].start_us = current_us;
            active_notes[note].active = 1;
            ptr += 2;
        } else if ((status & 0xF0) == 0x80 || ((status & 0xF0) == 0x90 && ptr[1] == 0)) {
            uint8_t note = transpose_note(ptr[0]);

            if (active_notes[note].active) {
                uint32_t note_on_us = active_notes[note].start_us;
                uint32_t duration_us = current_us - note_on_us;

                MidiEvent e = {
                    .note = note,
                    .velocity = active_notes[note].velocity,
                    .timestamp_us = note_on_us,
                    .duration_us = duration_us,
                    .active = 1
                };

                uint64_t packet = pack_midi_event(e);
                write_midi_packet(packet);

                printf("Packet Sent - Note: %d | Velocity: %d | Duration: %d ms | Timestamp: %u us\n",
                       e.note, e.velocity, e.duration_us / 1000, e.timestamp_us);

                active_notes[note].active = 0;
            }
            ptr += 2;
        } else {
            ptr += 2;
        }
    }
}

// ------------------- Main Entry -------------------

int main() {
    printf("🎼 Initializing...\n");

    int mem_fd = open("/dev/mem", O_RDWR | O_SYNC);
    if (mem_fd < 0) {
        perror("Failed to open /dev/mem");
        return 1;
    }

    virtual_base = mmap(NULL, HW_REGS_SPAN, PROT_READ | PROT_WRITE, MAP_SHARED, mem_fd, HW_REGS_BASE);
    if (virtual_base == MAP_FAILED) {
        perror("mmap failed");
        close(mem_fd);
        return 1;
    }

    song_loader_base = (volatile uint8_t *)((uint8_t *)virtual_base + MIDI_INPUT_OFFSET);

    const char *filename = "songs/song0.mid";
    MidiFile midi;
    if (load_midi_file(filename, &midi) == 0) {
        parse_and_send_midi(&midi);
        free(midi.data);
        printf("Finished loading and sending MIDI file.\n");
    }

    munmap(virtual_base, HW_REGS_SPAN);
    close(mem_fd);
    return 0;
}
