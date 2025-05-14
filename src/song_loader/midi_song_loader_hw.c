#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/mman.h>
#include <time.h>

#include "midi_common.h"
#include "hardware_defs.h"
#include "hw_writer.h"

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
    midi->tempo_us_per_quarter = 500000;
    return 0;
}

void parse_and_send_midi(MidiFile *midi, volatile uint8_t *song_loader_base, volatile uint32_t *song_ctrl_ptr) {
    const uint8_t *ptr = midi->data + 14;
    if (memcmp(ptr, "MTrk", 4) != 0) {
        fprintf(stderr, "❌ No MTrk chunk found\n");
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

                for (int i = 0; i < 8; i++) {
                    song_loader_base[i] = (packet >> (i * 8)) & 0xFF;
                }

                song_ctrl_ptr[3] = 1;

                printf("🎵 Packet Sent - Note: %d | Velocity: %d | Duration: %d ms | Timestamp: %u us\n",
                       e.note, e.velocity, e.duration_us / 1000, e.timestamp_us);

                active_notes[note].active = 0;
            }
            ptr += 2;
        } else {
            ptr += 2;
        }
    }
}

int main() {
    printf("🎼 Press KEY1 to load and send song1.mid...\n");

    int mem_fd = open("/dev/mem", O_RDWR | O_SYNC);
    if (mem_fd < 0) {
        perror("❌ Failed to open /dev/mem");
        return 1;
    }

    void *virtual_base = mmap(NULL, HW_REGS_SPAN, PROT_READ | PROT_WRITE, MAP_SHARED, mem_fd, HW_REGS_BASE);
    if (virtual_base == MAP_FAILED) {
        perror("❌ mmap failed");
        close(mem_fd);
        return 1;
    }

    volatile uint32_t *song_ctrl_ptr = (uint32_t *)((uint8_t *)virtual_base + SONG_CTRL_OFFSET);
    volatile uint8_t *song_loader_base = (uint8_t *)((uint8_t *)virtual_base + SONG_LOADER_OFFSET);

    while (1) {
        uint32_t trigger = song_ctrl_ptr[1];  // KEY1 press = trigger

        if (trigger) {
            printf("▶️ Detected KEY1 press. Loading song1.mid\n");

            MidiFile midi;
            if (load_midi("songs/song1.mid", &midi) == 0) {
                parse_and_send_midi(&midi, song_loader_base, song_ctrl_ptr);
                free(midi.data);
                song_ctrl_ptr[2] = 1;  // Done flag
                printf("✅ song1.mid loaded and packets sent.\n");
            } else {
                song_ctrl_ptr[2] = 0;
                fprintf(stderr, "❌ Failed to load song1.mid\n");
            }

            // Reset KEY1 trigger
            song_ctrl_ptr[1] = 0;
        }

        usleep(50000);  // check every 50ms
    }

    munmap(virtual_base, HW_REGS_SPAN);
    close(mem_fd);
    return 0;
}
