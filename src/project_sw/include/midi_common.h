#ifndef MIDI_COMMON_H
#define MIDI_COMMON_H

#include <stdint.h>
#include <stddef.h>

// Represents a note event (either from a MIDI file or live input)
typedef struct {
    uint8_t note;
    uint8_t velocity;
    uint32_t timestamp_us;
    uint32_t duration_us;
    int active; // 1 = note on, 0 = rest
} MidiEvent;

// Basic MIDI file metadata
typedef struct {
    uint8_t *data;
    size_t size;
    uint16_t division;
    uint32_t tempo_us_per_quarter;
} MidiFile;

// Function declarations (you'll implement these in Step 2)
uint16_t read16(const uint8_t *data);
uint32_t read_variable_length(const uint8_t **data_ptr);
int transpose_note(int note);

#endif // MIDI_COMMON_H
