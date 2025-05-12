#include <stdint.h>
#include "midi_common.h"

// Pack a MidiEvent (used by midi_song_loader_hw)
uint64_t pack_midi_event(MidiEvent e) {
    uint16_t duration_ms = (e.duration_us / 1000) & 0xFFFF;

    uint64_t packet = 0;
    packet |= ((uint64_t)e.note << 56);
    packet |= ((uint64_t)e.velocity << 48);
    packet |= ((uint64_t)duration_ms << 32);
    packet |= (uint64_t)e.timestamp_us;

    return packet;
}

// Pack live keyboard input (used by midi_logger_hw)
uint64_t pack_midi_input(uint8_t status, uint8_t note, uint8_t velocity, uint64_t timestamp_us) {
    uint64_t packet = 0;
    packet |= ((uint64_t)status << 16);
    packet |= ((uint64_t)note << 8);
    packet |= (uint64_t)velocity;
    packet |= ((timestamp_us & 0xFFFFFFFF) << 24);  // use only lower 32 bits

    return packet;
}
