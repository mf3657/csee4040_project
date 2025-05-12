#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>

#include "midi_common.h"  // ✅ Shared definitions and functions

#define INPUT_MIDI_FILE   "songs_in_midi/harmony.mid"
#define OUTPUT_TEXT_FILE  "parsed_midi_output.txt"

void write_event_to_file(FILE *out, MidiEvent event) {
    uint8_t duration_ms = (event.duration_us / 1000) & 0xFF;
    uint32_t midi_word = (event.note << 24) | (event.velocity << 16) | (duration_ms << 8);

    if (event.active) {
        fprintf(out, "MidiWord: 0x%08X  | Timestamp: %u us | Note: %d | Velocity: %d | Duration: %d ms\n",
                midi_word, event.timestamp_us, event.note, event.velocity, duration_ms);
    } else {
        fprintf(out, "REST     : --------  | Timestamp: %u us | Duration: %d ms\n",
                event.timestamp_us, duration_ms);
    }
}

int load_midi_file(const char *filename, MidiFile *midi) {
    FILE *f = fopen(filename, "rb");
    if (!f) {
        perror("❌ Cannot open MIDI file");
        return -1;
    }

    fseek(f, 0, SEEK_END);
    midi->size = ftell(f);
    fseek(f, 0, SEEK_SET);

    midi->data = (uint8_t *)malloc(midi->size);
    if (!midi->data) {
        fclose(f);
        fprintf(stderr, "❌ Failed to allocate memory for MIDI file.\n");
        return -1;
    }

    fread(midi->data, 1, midi->size, f);
    fclose(f);

    if (memcmp(midi->data, "MThd", 4) != 0) {
        fprintf(stderr, "❌ Not a valid MIDI file\n");
        return -1;
    }

    midi->division = read16(midi->data + 12);
    midi->tempo_us_per_quarter = 500000;  // Default 120 BPM
    return 0;
}

int main() {
    MidiFile midi;
    if (load_midi_file(INPUT_MIDI_FILE, &midi) != 0) return -1;

    FILE *out = fopen(OUTPUT_TEXT_FILE, "w");
    if (!out) {
        perror("❌ Cannot create output file");
        free(midi.data);
        return -1;
    }

    const uint8_t *ptr = midi.data + 14;
    if (memcmp(ptr, "MTrk", 4) != 0) {
        fprintf(stderr, "❌ No MTrk chunk found\n");
        fclose(out);
        free(midi.data);
        return -1;
    }
    ptr += 8;  // Skip 'MTrk' and length

    uint32_t current_ticks = 0;
    uint32_t last_event_us = 0;
    uint8_t last_status = 0;
    double micros_per_tick = (double)midi.tempo_us_per_quarter / midi.division;

    while (ptr < midi.data + midi.size) {
        uint32_t delta_ticks = read_variable_length(&ptr);
        current_ticks += delta_ticks;
        uint32_t current_us = (uint32_t)(current_ticks * micros_per_tick);

        uint8_t status = *ptr;
        if (status < 0x80) {
            status = last_status;  // Running status
        } else {
            ptr++;
            last_status = status;
        }

        if ((status & 0xF0) == 0x90 && ptr[1] > 0) {
            // Insert REST if there's a time gap
            if (current_us > last_event_us) {
                uint32_t rest_duration = current_us - last_event_us;
                if (rest_duration > 0) {
                    MidiEvent rest = {
                        .note = 0,
                        .velocity = 0,
                        .timestamp_us = last_event_us,
                        .duration_us = rest_duration,
                        .active = 0
                    };
                    write_event_to_file(out, rest);
                }
            }

            // NOTE ON: Search ahead for matching NOTE OFF
            uint8_t note = ptr[0];
            uint8_t velocity = ptr[1];
            uint32_t note_on_ticks = current_ticks;
            const uint8_t *search_ptr = ptr + 2;
            uint32_t search_ticks = current_ticks;
            uint8_t search_status = last_status;

            while (search_ptr < midi.data + midi.size) {
                uint32_t search_delta = read_variable_length(&search_ptr);
                search_ticks += search_delta;

                uint8_t s = *search_ptr;
                if (s < 0x80) s = search_status;
                else {
                    search_ptr++;
                    search_status = s;
                }

                if (((s & 0xF0) == 0x80 || ((s & 0xF0) == 0x90 && search_ptr[1] == 0)) && search_ptr[0] == note) {
                    uint32_t duration_ticks = search_ticks - note_on_ticks;
                    uint32_t duration_us = (uint32_t)(duration_ticks * micros_per_tick);

                    MidiEvent event = {
                        .note = transpose_note(note),
                        .velocity = velocity,
                        .timestamp_us = current_us,
                        .duration_us = duration_us,
                        .active = 1
                    };
                    write_event_to_file(out, event);
                    last_event_us = current_us + duration_us;
                    break;
                }
                search_ptr += 2;  // Skip note and velocity
            }
        }

        ptr += 2;  // Advance to next event
    }

    fclose(out);
    free(midi.data);

    printf("✅ Parsed MIDI saved to: %s\n", OUTPUT_TEXT_FILE);
    return 0;
}
