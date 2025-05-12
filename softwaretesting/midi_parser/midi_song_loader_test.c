#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>

#define LOWEST_NOTE  60  // C5
#define HIGHEST_NOTE 83  // B6
#define MAX_ACTIVE_NOTES 128

typedef struct {
    uint8_t note;
    uint8_t velocity;
    uint32_t start_ticks;
    uint32_t start_us;
    int active;
} ActiveNote;

typedef struct {
    uint8_t *data;
    size_t size;
    uint16_t division;
    uint32_t tempo_us_per_quarter;
} MidiFile;

typedef struct {
    uint8_t note;
    uint8_t velocity;
    uint32_t timestamp_us;
    uint32_t duration_us;
    int active;
} MidiEvent;

// --- Utility Functions ---
uint16_t read16(const uint8_t *data) {
    return (data[0] << 8) | data[1];
}

uint32_t read_variable_length(const uint8_t **data_ptr) {
    uint32_t value = 0;
    const uint8_t *data = *data_ptr;
    uint8_t byte;
    do {
        byte = *data++;
        value = (value << 7) | (byte & 0x7F);
    } while (byte & 0x80);
    *data_ptr = data;
    return value;
}

int transpose_note(int note) {
    while (note < LOWEST_NOTE) note += 12;
    while (note > HIGHEST_NOTE) note -= 12;
    return note;
}

int load_midi(const char *filename, MidiFile *midi) {
    FILE *f = fopen(filename, "rb");
    if (!f) {
        perror("Cannot open MIDI file");
        return -1;
    }
    fseek(f, 0, SEEK_END);
    midi->size = ftell(f);
    fseek(f, 0, SEEK_SET);
    midi->data = (uint8_t *)malloc(midi->size);
    fread(midi->data, 1, midi->size, f);
    fclose(f);

    if (memcmp(midi->data, "MThd", 4) != 0) {
        fprintf(stderr, "Not a valid MIDI file\n");
        return -1;
    }
    midi->division = read16(midi->data + 12);
    midi->tempo_us_per_quarter = 500000; // default to 120 BPM
    return 0;
}

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

// --- Main Program ---
int main() {
    const char *input_filename = "harmony.mid";
    const char *output_filename = "parsed_midi_output.txt";

    MidiFile midi;
    if (load_midi(input_filename, &midi) != 0) return -1;

    FILE *out = fopen(output_filename, "w");
    if (!out) {
        perror("Cannot create output file");
        free(midi.data);
        return -1;
    }

    const uint8_t *ptr = midi.data + 14;
    if (memcmp(ptr, "MTrk", 4) != 0) {
        fprintf(stderr, "No MTrk chunk found\n");
        free(midi.data);
        fclose(out);
        return -1;
    }
    ptr += 8; // Skip 'MTrk' header and length

    ActiveNote active_notes[MAX_ACTIVE_NOTES] = {0};
    uint32_t current_ticks = 0;
    uint32_t last_ticks = 0;
    uint32_t last_us = 0;
    uint8_t last_status = 0;
    double micros_per_tick = (double)midi.tempo_us_per_quarter / midi.division;

    int active_note_count = 0;

    while (ptr < midi.data + midi.size) {
        uint32_t delta_ticks = read_variable_length(&ptr);
        current_ticks += delta_ticks;
        uint32_t current_us = (uint32_t)(current_ticks * micros_per_tick);

        uint8_t status = *ptr;
        if (status < 0x80) {
            status = last_status; // running status
        } else {
            ptr++;
            last_status = status;
        }

        if ((status & 0xF0) == 0x90 && ptr[1] > 0) {
            // Note On
            uint8_t note = transpose_note(ptr[0]);
            uint8_t velocity = ptr[1];

            if (delta_ticks > 0 && active_note_count == 0 && current_us > last_us) {
                // Gap between last notes and now → REST
                MidiEvent rest_event;
                rest_event.note = 0;
                rest_event.velocity = 0;
                rest_event.timestamp_us = last_us;
                rest_event.duration_us = current_us - last_us;
                rest_event.active = 0;
                write_event_to_file(out, rest_event);
            }

            active_notes[note].note = note;
            active_notes[note].velocity = velocity;
            active_notes[note].start_ticks = current_ticks;
            active_notes[note].start_us = current_us;
            active_notes[note].active = 1;
            active_note_count++;

        } else if ((status & 0xF0) == 0x80 || ((status & 0xF0) == 0x90 && ptr[1] == 0)) {
            // Note Off
            uint8_t note = transpose_note(ptr[0]);

            if (active_notes[note].active) {
                uint32_t note_on_us = active_notes[note].start_us;
                uint32_t duration_us = current_us - note_on_us;

                MidiEvent note_event;
                note_event.note = note;
                note_event.velocity = active_notes[note].velocity;
                note_event.timestamp_us = note_on_us;
                note_event.duration_us = duration_us;
                note_event.active = 1;
                write_event_to_file(out, note_event);

                active_notes[note].active = 0;
                active_note_count--;

                if (active_note_count == 0) {
                    last_us = current_us;
                    last_ticks = current_ticks;
                }
            }
        }

        ptr += 2; // Skip data bytes
    }

    fclose(out);
    free(midi.data);

    printf("✅ Polyphonic parsed MIDI saved to: %s\n", output_filename);

    return 0;
}

// polyphonic but have to test (not correct)