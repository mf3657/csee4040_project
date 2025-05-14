// fpga_ioctl.h
#ifndef FPGA_IOCTL_H
#define FPGA_IOCTL_H

#include <linux/ioctl.h>
#define IOCTL_SEND_MIDI_EVENT _IOW('M', 3, uint64_t)

#endif
