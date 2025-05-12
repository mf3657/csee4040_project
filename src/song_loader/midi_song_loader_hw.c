#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/mman.h>

#include "midi_common.h"
#include "hardware_defs.h"
#include "hw_writer.h"  // ✅ use shared FPGA writer

#define MAX_ACTIVE_NOTES 128

typedef struct {
    uint8_t note;
    uint8_t velocity;
    uint32_t start_ticks;
    uint32_t start_us;
    int active;
} ActiveNote;

int load_midi(const char *filename, MidiFile *midi) {
    FILE *f = fopen(filename, "rb");
    if (!f) {
        perror("❌ Cannot open MIDI file");
        return -1;
    }

    fseek(f, 0, SEEK_END);
    midi->size = ftell(f);
    fseek(f, 0, SEEK_SET);
    midi->data = (uint8_t *)malloc(midi->size);
    fread(midi->data, 1, midi->size, f);
    fclose(f);

    if (memcmp(midi->data, "MThd", 4) != 0) {
        fprintf(stderr, "❌ Not a valid MIDI file\n");
        return -1;
    }

    midi->division = read16(midi->data + 12);
    midi->tempo_us_per_quarter = 500000; // default 120 BPM

    return 0;
}

int main() {
    const char *input_filename = "harmony.mid";

    MidiFile midi;
    if (load_midi(input_filename, &midi) != 0) return -1;

    // Setup memory-mapped FPGA access
    int mem_fd = open("/dev/mem", O_RDWR | O_SYNC);
    if (mem_fd == -1) {
        perror("❌ Failed to open /dev/mem");
        free(midi.data);
        return -1;
    }

    void *virtual_base = mmap(NULL, HW_REGS_SPAN, PROT_READ | PROT_WRITE, MAP_SHARED, mem_fd, HW_REGS_BASE);
    if (virtual_base == MAP_FAILED) {
        perror("❌ mmap failed");
        close(mem_fd);
        free(midi.data);
        return -1;
    }

    volatile uint64_t *song_loader_ptr = (uint64_t *)((uint8_t *)virtual_base + SONG_LOADER_OFFSET);

    // Parse track
    const uint8_t *ptr = midi.data + 14;
    if (memcmp(ptr, "MTrk", 4) != 0) {
        fprintf(stderr, "❌ No MTrk chunk found\n");
        munmap(virtual_base, HW_REGS_SPAN);
        close(mem_fd);
        free(midi.data);
        return -1;
    }
    ptr += 8; // skip 'MTrk' + track length

    ActiveNote active_notes[MAX_ACTIVE_NOTES] = {0};
    uint32_t current_ticks = 0;
    uint8_t last_status = 0;
    double micros_per_tick = (double)midi.tempo_us_per_quarter / midi.division;

    while (ptr < midi.data + midi.size) {
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

        // Note On
        if ((status & 0xF0) == 0x90 && ptr[1] > 0) {
            uint8_t note = transpose_note(ptr[0]);
            uint8_t velocity = ptr[1];

            active_notes[note].note = note;
            active_notes[note].velocity = velocity;
            active_notes[note].start_ticks = current_ticks;
            active_notes[note].start_us = current_us;
            active_notes[note].active = 1;

        // Note Off or Note On with velocity 0
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
                *song_loader_ptr = packet;

                printf("Packet Sent - Note: %d | Velocity: %d | Duration: %d ms | Timestamp: %u us\n",
                       e.note, e.velocity, e.duration_us / 1000, e.timestamp_us);

                active_notes[note].active = 0;
            }
        }

        ptr += 2; // skip note and velocity
    }

    // Cleanup
    munmap(virtual_base, HW_REGS_SPAN);
    close(mem_fd);
    free(midi.data);

    printf("✅ All MIDI events transmitted to FPGA.\n");

    return 0;
}
