#include "midi_common.h"

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
    while (note < 60) note += 12;     // C5
    while (note > 83) note -= 12;     // B6
    return note;
}
