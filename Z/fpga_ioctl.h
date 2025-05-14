#ifndef FPGA_IOCTL_H
#define FPGA_IOCTL_H

#include <linux/ioctl.h>
#include <stdint.h>  // Use standard fixed-width types

#define FPGA_MAGIC 'F'  // Unique magic number for ioctl group

// ───────────────────────────────────────────────
// IOCTL command codes
// ───────────────────────────────────────────────

/**
 * Send a 64-bit MIDI packet to the FPGA.
 * Argument: struct midi_packet
 */
#define IOCTL_SEND_MIDI_EVENT _IOW(FPGA_MAGIC, 0x01, struct midi_packet)

/**
 * Set the background RGB color of the VGA display.
 * Argument: struct rgb_color
 */
#define IOCTL_SET_BACKGROUND _IOW(FPGA_MAGIC, 0x02, struct rgb_color)

/**
 * Set Beats Per Minute (tempo).
 * Argument: uint16_t bpm
 */
#define IOCTL_SET_BPM _IOW(FPGA_MAGIC, 0x03, uint16_t)


// ───────────────────────────────────────────────
// Structs for ioctl arguments
// ───────────────────────────────────────────────

/**
 * Struct representing a 64-bit MIDI event split into high and low 32 bits.
 */
struct midi_packet {
    uint32_t high;  // Upper 32 bits
    uint32_t low;   // Lower 32 bits
};

/**
 * Struct representing an RGB color.
 */
struct rgb_color {
    uint8_t r;
    uint8_t g;
    uint8_t b;
};

#endif // FPGA_IOCTL_H
