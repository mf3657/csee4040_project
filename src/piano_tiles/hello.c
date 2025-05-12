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

    // 3-bit colors: dark blue, white, light blue, dark red, green, ...
    // Let's define 10 color values: (leftmost = lowest key)
    // 000 001 010 011 100 101 110 111 001 010
    // Converted to hex: 0b000001010011100101110111001010
    // = 0x0A3CBCA2 (manually packed)
    piano_regs[0] = 0x0A3CBCA2; // packed 10 key colors
    piano_regs[1] = 0x49249249; // default white
    piano_regs[2] = 0x49249249; // default white
    piano_regs[3] = 0x00000000;

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
