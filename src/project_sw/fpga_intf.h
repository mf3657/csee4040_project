#ifndef _FPGA_INTF_H
#define _FPGA_INTF_H

#include <stdint.h>
#include <stddef.h>

/* --- Hardware Register Definitions --- */
#define HW_REGS_BASE        0xFF200000  // Base physical address of lightweight bridge
#define HW_REGS_SPAN        0x00200000  // 2MB span

#define SONG_LOADER_OFFSET  0x00002000  // 64-bit packet input (song playback)
#define MIDI_INPUT_OFFSET   0x00002008  // 8-bit register interface (real-time input)
#define SONG_CTRL_OFFSET    0x00003000  // [0]=song_index, [1]=load_trigger, [2]=loaded_done

/* --- MIDI Event & File Structures --- */
typedef struct {
    uint8_t note;
    uint8_t velocity;
    uint32_t timestamp_us;
    uint32_t duration_us;
    int active;
} MidiEvent;

typedef struct {
    uint8_t *data;
    size_t size;
    uint16_t division;
    uint32_t tempo_us_per_quarter;
} MidiFile;

/* --- MIDI Utility Functions --- */
static inline uint16_t read16(const uint8_t *data) {
    return (data[0] << 8) | data[1];
}

static inline uint32_t read_variable_length(const uint8_t **data_ptr) {
    const uint8_t *ptr = *data_ptr;
    uint32_t value = 0;
    uint8_t byte;
    do {
        byte = *ptr++;
        value = (value << 7) | (byte & 0x7F);
    } while (byte & 0x80);
    *data_ptr = ptr;
    return value;
}

static inline int transpose_note(int note) {
    return note - 60;  // Middle C = 0
}

/* --- MIDI Packet Packing (64-bit) --- */
static inline uint64_t pack_midi_event(MidiEvent e) {
    uint64_t packet = 0;
    packet |= ((uint64_t)e.note      << 56);
    packet |= ((uint64_t)e.velocity  << 48);
    packet |= ((uint64_t)e.timestamp_us & 0xFFFFFFFFULL) << 16;
    packet |= ((uint64_t)e.duration_us  & 0xFFFF);
    return packet;
}

static inline uint64_t pack_midi_input(uint8_t status, uint8_t note, uint8_t velocity, uint64_t timestamp_us) {
    uint64_t packet = 0;
    packet |= ((uint64_t)status << 56);
    packet |= ((uint64_t)note   << 48);
    packet |= ((uint64_t)velocity << 40);
    packet |= (timestamp_us & 0xFFFFFFFFFFULL); // lower 40 bits
    return packet;
}

#endif // _FPGA_INTF_H
