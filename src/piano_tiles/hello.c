// hello.c - Userspace app to mmap and print VGA piano tile base
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

    void *virtual_base = mmap(NULL, HW_REGS_SPAN, PROT_READ | PROT_WRITE, MAP_SHARED, fd, HW_REGS_BASE);
    if (virtual_base == MAP_FAILED) {
        perror("mmap");
        close(fd);
        return 1;
    }

    volatile uint32_t *piano_regs = (uint32_t *)((char *)virtual_base + PIANO_BASE_OFFSET);

    // Read back the current register values to verify display config
    printf("initial state: %08x\n", piano_regs[0]);
    printf("               %08x\n", piano_regs[1]);
    printf("               %08x\n", piano_regs[2]);
    printf("               %08x\n", piano_regs[3]);

    munmap(virtual_base, HW_REGS_SPAN);
    close(fd);
    return 0;
}
