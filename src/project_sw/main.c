/*
 * Userspace program that communicates with the fpga_intf device driver
 * through ioctls
 *
 * Stephen A. Edwards
 * Columbia University
 */

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <termios.h>
#include <fcntl.h>
#include <string.h>
#include "fpga_intf.h"

static struct termios orig_termios;

// Restore terminal mode
void reset_terminal_mode() {
    tcsetattr(STDIN_FILENO, TCSANOW, &orig_termios);
}

// Set non-blocking raw mode
void set_raw_mode() {
    struct termios raw;

    tcgetattr(STDIN_FILENO, &orig_termios);
    atexit(reset_terminal_mode);

    raw = orig_termios;
    raw.c_lflag &= ~(ICANON | ECHO); // Disable line buffering & echo
    raw.c_cc[VMIN] = 0;
    raw.c_cc[VTIME] = 0;
    tcsetattr(STDIN_FILENO, TCSANOW, &raw);
}

// Write color to background registers
void set_background_color(uint8_t r, uint8_t g, uint8_t b, volatile uint8_t *base) {
    base[0] = r; // Red
    base[1] = g; // Green
    base[2] = b; // Blue
}

int main() {
    printf("FPGA Test Program: MIDI + Color Keys\n");

    if (init_fpga_loader() != 0) {
        fprintf(stderr, "Failed to initialize FPGA interface\n");
        return 1;
    }

    // MIDI song loader region (base + 0x2008)
    volatile uint8_t *ctrl_base = (volatile uint8_t *)((uint8_t *)virtual_base + MIDI_INPUT_OFFSET);

    // Play test MIDI file
    printf("Sending song0.mid to FPGA...\n");
    if (load_and_send_midi("songs/song0.mid") != 0) {
        fprintf(stderr, "Failed to send MIDI song\n");
        shutdown_fpga_loader();
        return 1;
    }

    // Enable raw mode for keyboard input
    set_raw_mode();

    printf(" Press keys to change color: [r]ed [g]reen [b]lue [y]ellow [w]hite [q]uit\n");

    while (1) {
        char ch;
        int n = read(STDIN_FILENO, &ch, 1);
        if (n > 0) {
            if (ch == 'q') break;

            switch (ch) {
                case 'r': set_background_color(255, 0, 0, ctrl_base); break;
                case 'g': set_background_color(0, 255, 0, ctrl_base); break;
                case 'b': set_background_color(0, 0, 255, ctrl_base); break;
                case 'y': set_background_color(255, 255, 0, ctrl_base); break;
                case 'w': set_background_color(255, 255, 255, ctrl_base); break;
                default: break;
            }
        }

        usleep(50000); // 50ms debounce
    }

    printf(" Exiting...\n");
    shutdown_fpga_loader();
    return 0;
}
