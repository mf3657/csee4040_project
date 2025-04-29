#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>

#define LOWEST_NOTE  60  // C5
#define HIGHEST_NOTE 83  // B6 (one below C7)

typedef struct {
    uint8_t note;
    uint8_t velocity;
    uint32_t timestamp_us;
    uint32_t duration_us;
    int active; // 1 = note, 0 = rest
} MidiEvent;

typedef struct {
    uint8_t *data;
    size_t size;
    uint16_t division; // ticks per quarter note
    uint32_t tempo_us_per_quarter; // default tempo
} MidiFile;

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
    const char *input_filename = "happy_birthday.mid";
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
    ptr += 8; // Skip 'MTrk' + track length

    uint32_t current_ticks = 0;
    uint32_t last_event_us = 0;
    uint8_t last_status = 0;
    uint8_t inside_note = 0;
    double micros_per_tick = (double)midi.tempo_us_per_quarter / midi.division;

    while (ptr < midi.data + midi.size) {
        const uint8_t *event_start = ptr;
        uint32_t delta_ticks = read_variable_length(&ptr);
        current_ticks += delta_ticks;

        uint8_t status = *ptr;
        if (status < 0x80) {
            status = last_status; // running status
        } else {
            ptr++;
            last_status = status;
        }

        if ((status & 0xF0) == 0x90 && ptr[1] > 0) {
            // Before playing the note, check if there was silent time
            uint32_t new_event_us = (uint32_t)(current_ticks * micros_per_tick);

            if (new_event_us > last_event_us) {
                uint32_t rest_duration = new_event_us - last_event_us;
                if (rest_duration > 0) {
                    MidiEvent rest;
                    rest.note = 0;
                    rest.velocity = 0;
                    rest.timestamp_us = last_event_us;
                    rest.duration_us = rest_duration;
                    rest.active = 0;
                    write_event_to_file(out, rest);
                }
            }

            // This is a Note On event
            uint8_t note = ptr[0];
            uint8_t velocity = ptr[1];
            uint32_t note_on_ticks = current_ticks;

            // Search for Note Off event
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
                    // Found Note Off
                    uint32_t duration_ticks = search_ticks - note_on_ticks;
                    uint32_t duration_us = (uint32_t)(duration_ticks * micros_per_tick);

                    MidiEvent note_event;
                    note_event.note = transpose_note(note);
                    note_event.velocity = velocity;
                    note_event.timestamp_us = new_event_us;
                    note_event.duration_us = duration_us;
                    note_event.active = 1;
                    write_event_to_file(out, note_event);

                    last_event_us = new_event_us + duration_us;
                    break;
                }
                search_ptr += 2;
            }
        }

        ptr += 2; // skip note number and velocity
    }

    fclose(out);
    free(midi.data);

    printf("✅ Parsed MIDI saved to: %s\n", output_filename);

    return 0;
}

// does not handle polyphonics