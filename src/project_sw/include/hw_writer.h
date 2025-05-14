#ifndef HW_WRITER_H
#define HW_WRITER_H

#include <stdint.h>
#include "midi_common.h"

uint64_t pack_midi_event(MidiEvent e);
uint64_t pack_midi_input(uint8_t status, uint8_t note, uint8_t velocity, uint64_t timestamp_us);

#endif // HW_WRITER_H
