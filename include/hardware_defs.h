#ifndef HARDWARE_DEFS_H
#define HARDWARE_DEFS_H

// FPGA memory mapping
#define HW_REGS_BASE        0xFF200000  // Base physical address of lightweight bridge
#define HW_REGS_SPAN        0x00200000  // 2MB span

// FPGA component offsets (relative to base)
#define SONG_LOADER_OFFSET  0x00002000  // Address to send parsed MIDI song notes
#define MIDI_INPUT_OFFSET   0x00002008  // Address to send real-time keyboard inputs

#endif // HARDWARE_DEFS_H
