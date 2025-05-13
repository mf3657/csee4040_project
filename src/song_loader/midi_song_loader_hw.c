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

void parse_and_send_midi(MidiFile *midi, volatile uint64_t *song_loader_ptr) {
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
        // --- Read delta time and update time ---
        uint32_t delta_ticks = read_variable_length(&ptr);
        current_ticks += delta_ticks;
        uint32_t current_us = (uint32_t)(current_ticks * micros_per_tick);

        // --- Get status byte ---
        uint8_t status = *ptr;
        if (status < 0x80) {
            status = last_status;
        } else {
            ptr++;
            last_status = status;
        }

        // --- Tempo Change Meta Event ---
        if (status == 0xFF && ptr[0] == 0x51 && ptr[1] == 0x03) {
            ptr += 2;
            uint32_t new_tempo = (ptr[0] << 16) | (ptr[1] << 8) | ptr[2];
            midi->tempo_us_per_quarter = new_tempo;
            micros_per_tick = (double)new_tempo / midi->division;
            printf("🎼 Tempo Change: %u us/quarter → %.2f µs/tick\n", new_tempo, micros_per_tick);
            ptr += 3;
            continue;
        }

        // --- Note On ---
        if ((status & 0xF0) == 0x90 && ptr[1] > 0) {
            uint8_t note = transpose_note(ptr[0]);
            uint8_t velocity = ptr[1];

            active_notes[note].note = note;
            active_notes[note].velocity = velocity;
            active_notes[note].start_ticks = current_ticks;
            active_notes[note].start_us = current_us;
            active_notes[note].active = 1;
            ptr += 2;

        // --- Note Off or Note On with 0 velocity ---
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

                printf("🎵 Packet Sent - Note: %d | Velocity: %d | Duration: %d ms | Timestamp: %u us\n",
                       e.note, e.velocity, e.duration_us / 1000, e.timestamp_us);

                active_notes[note].active = 0;
            }

            ptr += 2;

        // --- Skip unknown event types (safely) ---
        } else {
            ptr += 2;
        }
    }
}

int main() {
    printf("🎼 Waiting for song trigger...\n");

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

    volatile uint64_t *song_loader_ptr = (uint64_t *)((uint8_t *)virtual_base + SONG_LOADER_OFFSET);
    volatile uint32_t *song_ctrl_ptr   = (uint32_t *)((uint8_t *)virtual_base + SONG_CTRL_OFFSET); // 0: index, 1: trigger, 2: done

    while (1) {
        uint32_t trigger = song_ctrl_ptr[1];  // song_load_trigger
        uint32_t index = song_ctrl_ptr[0];    // song_index

        if (trigger) {
            char midi_path[64], mp3_path[64];
            snprintf(midi_path, sizeof(midi_path), "songs/song%d.mid", index);
            snprintf(mp3_path, sizeof(mp3_path), "songs/song%d.mp3", index);

            printf("▶️ Loading MIDI: %s\n", midi_path);

            MidiFile midi;
            if (load_midi(midi_path, &midi) == 0) {
                parse_and_send_midi(&midi, song_loader_ptr);
                free(midi.data);
                song_ctrl_ptr[2] = 1;  // song_loaded_done
                printf("✅ Song loaded and sent to FPGA.\n");

                // 🔊 Trigger MP3 playback
                pid_t pid = fork();
                if (pid == 0) {
                    execlp("mpg123", "mpg123", mp3_path, NULL);
                    perror("❌ Failed to launch mpg123");
                    exit(1);
                } else if (pid < 0) {
                    perror("❌ Fork failed");
                } else {
                    printf("🔊 MP3 playback started: %s\n", mp3_path);
                }

            } else {
                song_ctrl_ptr[2] = 0;
                fprintf(stderr, "❌ Failed to load or parse song %d.\n", index);
            }
        }

        usleep(50000);  // check every 50ms
    }

    munmap(virtual_base, HW_REGS_SPAN);
    close(mem_fd);
    return 0;
}
