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
    unsigned int note;
} fpga_intf_note_t;

/* Structure for audio sample value */
typedef struct {
    unsigned int sample;
} fpga_intf_sample_t;

/* Magic number for ioctl commands */
#define FPGA_INTF_MAGIC  'F'

/* ioctl command codes */
#define FPGA_INTF_SET_BACKGROUND  _IOW(FPGA_INTF_MAGIC, 1, fpga_intf_color_t)
#define FPGA_INTF_GET_BACKGROUND  _IOR(FPGA_INTF_MAGIC, 2, fpga_intf_color_t)
#define FPGA_INTF_SET_NOTE        _IOW(FPGA_INTF_MAGIC, 3, fpga_intf_note_t)
#define FPGA_INTF_SET_SAMPLE1     _IOW(FPGA_INTF_MAGIC, 4, fpga_intf_sample_t)
#define FPGA_INTF_SET_SAMPLE2     _IOW(FPGA_INTF_MAGIC, 5, fpga_intf_sample_t)

#endif /* _FPGA_INTF_H */
