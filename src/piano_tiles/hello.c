// hello.c - Userspace app to mmap and optionally write VGA piano tile base

#include <stdio.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <stdint.h>
#include <unistd.h>

#define HW_REGS_BASE      0xFF200000
#define HW_REGS_SPAN      0x100000
#define PIANO_BASE_OFFSET 0x00000000

int main() {
    printf("[hello] VGA piano tile Userspace program started\n");

    int fd = open("/dev/mem", O_RDWR | O_SYNC);
    if (fd < 0) {
        perror("open");
        return 1;
    }

    void *virtual_base = mmap(NULL, HW_REGS_SPAN, PROT_READ | PROT_WRITE,
                              MAP_SHARED, fd, HW_REGS_BASE);
    if (virtual_base == MAP_FAILED) {
        perror("mmap");
        close(fd);
        return 1;
    }

    // Map the registers
    volatile uint32_t *piano_regs = (uint32_t *)((char *)virtual_base + PIANO_BASE_OFFSET);

    // Optional: Write custom pattern to simulate key colors (3-bit each)
    // Example pattern: keys 0–9 = red, green, blue, white, red, green, blue...
    // Each 3 bits = 0bRRR (e.g., 0b111 = dark red, 0b100 = light green, etc.)
    piano_regs[0] = 0b000_001_010_011_100_101_110_111_001_010; // 10 keys
    piano_regs[1] = 0x49249249; // default white for next 10
    piano_regs[2] = 0x49249249; // default white for last 5 (only 5 of 10 used)
    piano_regs[3] = 0x00000000; // unused

    // Read and print current state
    printf("[hello] Piano key registers:\n");
    for (int i = 0; i < 4; i++) {
        printf("  piano_regs[%d] = 0x%08X\n", i, piano_regs[i]);
    }

    // Clean up
    munmap(virtual_base, HW_REGS_SPAN);
    close(fd);
    printf("[hello] Done.\n");
    return 0;
}
