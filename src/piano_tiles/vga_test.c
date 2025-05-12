#include <stdio.h>
#include <stdlib.h>
#include <fcntl.h>
#include <unistd.h>
#include <stdint.h>
#include <errno.h>
#include <string.h>

#define FPGA_DEV "/dev/fpga_intf"

// Write 8-bit value to a specific address (register)
void write_reg(int fd, uint8_t addr, uint8_t value) {
    if (lseek(fd, addr, SEEK_SET) < 0) {
        perror("lseek");
        exit(1);
    }
    if (write(fd, &value, 1) != 1) {
        perror("write");
        exit(1);
    }
}

int main() {
    int fd = open(FPGA_DEV, O_RDWR);
    if (fd < 0) {
        perror("open");
        return 1;
    }

    // Set background color to dark blue
    write_reg(fd, 0, 0x00);  // background_r
    write_reg(fd, 1, 0x00);  // background_g
    write_reg(fd, 2, 0x40);  // background_b

    // Set rectangle size and Y position
    write_reg(fd, 4, 150);   // rect_y
    write_reg(fd, 5, 80);    // rect_w
    write_reg(fd, 6, 50);    // rect_h

    // Animate rectangle moving from left to right
    for (uint8_t x = 0; x < 200; x++) {
        write_reg(fd, 3, x);  // rect_x
        usleep(20000);        // 20 ms delay (~50 FPS)
    }

    // Hold position at the end
    sleep(2);

    close(fd);
    return 0;
}
