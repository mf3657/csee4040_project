/*
 * Userspace program that communicates with the fpga_intf device driver
 * through ioctls
 *
 * Stephen A. Edwards
 * Columbia University
 */

#include <stdio.h>
#include "fpga_intf.h"
#include <sys/ioctl.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <string.h>
#include <unistd.h>

int fpga_intf_fd;

/* Example usage of the ioctl
void set_background_color(const fpga_intf_color_t *c)
{
  fpga_intf_arg_t vla;
  vla.background = *c;
  if (ioctl(fpga_intf_fd, fpga_intf_WRITE_BACKGROUND, &vla)) {
      perror("ioctl(FPGA_INTF_SET_BACKGROUND) failed");
      return;
  }
} */


int main()
{
  fpga_intf_arg_t vla;

  static const char filename[] = "/dev/fpga_intf";

  printf("FPGA interface Userspace program started\n");

  if ( (fpga_intf_fd = open(filename, O_RDWR)) == -1) {
    fprintf(stderr, "could not open %s\n", filename);
    return -1;
  }

  printf("Interface Ready.\n");

  printf("FPGA BALL Userspace program terminating\n");
  return 0;
}
