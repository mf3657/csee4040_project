#ifndef _FPGA_INTF_H
#define _FPGA_INTF_H

#include <linux/ioctl.h>

typedef struct {
  unsigned char red, green, blue;
} fpga_intf_color_t;
  

typedef struct {
  fpga_intf_color_t background;
} fpga_intf_arg_t;

#define VGA_BALL_MAGIC 'q'

/* ioctls and their arguments */
#define FPGA_INTF_WRITE_BACKGROUND _IOW(FPGA_INTF_MAGIC, 1, fpga_intf_arg_t)
#define FPGA_INTF_READ_BACKGROUND  _IOR(FPGA_INTF_MAGIC, 2, fpga_intf_arg_t)

#endif
