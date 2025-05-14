#ifndef _FPGA_INTF_H
#define _FPGA_INTF_H

#include <linux/ioctl.h>

/* Structure for VGA background color (3 bytes color + padding for alignment) */
typedef struct {
    unsigned char red;
    unsigned char green;
    unsigned char blue;
} fpga_intf_color_t;

/* Structure for audio note command */
typedef struct {
    unsigned double midi;
} fpga_intf_midi_t;

/* Magic number for ioctl commands */
#define FPGA_INTF_MAGIC  'F'

/* ioctl command codes */
#define FPGA_INTF_SET_BACKGROUND  _IOW(FPGA_INTF_MAGIC, 1, fpga_intf_color_t)
#define FPGA_INTF_GET_BACKGROUND  _IOR(FPGA_INTF_MAGIC, 2, fpga_intf_color_t)
#define FPGA_INTF_SET_NOTE        _IOW(FPGA_INTF_MAGIC, 3, fpga_intf_midi_t)

#endif /* _FPGA_INTF_H */
