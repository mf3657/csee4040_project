#include <linux/module.h>
#include <linux/init.h>
#include <linux/errno.h>
#include <linux/version.h>
#include <linux/kernel.h>
#include <linux/platform_device.h>
#include <linux/miscdevice.h>
#include <linux/slab.h>
#include <linux/io.h>
#include <linux/of.h>
#include <linux/of_address.h>
#include <linux/fs.h>
#include <linux/uaccess.h>
#include "fpga_intf.h"

#define DEVICE_NAME "fpga_intf"
#define CLASS_NAME  "fpgamidi"

#define HW_REGS_BASE   0xFF200000
#define HW_REGS_SPAN   0x00200000
#define MIDI_INPUT_OFFSET 0x00002008

#define IOCTL_START_GAME   _IO('M', 1)
#define IOCTL_RESET_SYSTEM _IO('M', 2)



static int    major;
static void __iomem *virtual_base;
static void __iomem *midi_base;
static struct class*  fpga_class;
static struct device* fpga_device;


/*
 * Information about our device
 */
struct fpga_intf_dev {
	struct resource res; /* Resource: our registers */
	void __iomem *virtbase; /* Where registers can be accessed in memory */
        fpga_intf_color_t background; // Placeholder ioctl argument from lab 3
} dev;



static long fpga_ioctl(struct file *f, unsigned int cmd, unsigned long arg) {
    switch (cmd) {
        case IOCTL_START_GAME:
            pr_info("FPGA MIDI: Game started\n");
            break;
        case IOCTL_RESET_SYSTEM:
            pr_info("FPGA MIDI: System reset\n");
            break;
        default:
            return -EINVAL;
    }
    return 0;
}

static ssize_t fpga_write(struct file *file, const char __user *buf, size_t len, loff_t *offset) {
    uint64_t packet;
    if (len != sizeof(uint64_t)) return -EINVAL;
    if (copy_from_user(&packet, buf, sizeof(packet))) return -EFAULT;

    for (int i = 0; i < 4; i++)
        iowrite8((packet >> ((7 - i) * 8)) & 0xFF, midi_base + 4); // High
    for (int i = 4; i < 8; i++)
        iowrite8((packet >> ((7 - i) * 8)) & 0xFF, midi_base + 5); // Low
    iowrite8(1, midi_base + 6); // Trigger

    return sizeof(packet);
}

static int fpga_open(struct inode *i, struct file *f) { return 0; }
static int fpga_release(struct inode *i, struct file *f) { return 0; }

static struct file_operations fops = {
    .owner = THIS_MODULE,
    .open = fpga_open,
    .release = fpga_release,
    .write = fpga_write,
    .unlocked_ioctl = fpga_ioctl
};

static int __init fpga_init(void) {
    major = register_chrdev(0, DEVICE_NAME, &fops);
    if (major < 0) return major;

    fpga_class = class_create(THIS_MODULE, CLASS_NAME);
    fpga_device = device_create(fpga_class, NULL, MKDEV(major, 0), NULL, DEVICE_NAME);

    virtual_base = ioremap(HW_REGS_BASE, HW_REGS_SPAN);
    midi_base = virtual_base + MIDI_INPUT_OFFSET;

    pr_info("FPGA MIDI: Module loaded with /dev/%s\n", DEVICE_NAME);
    return 0;
}

static void __exit fpga_exit(void) {
    iounmap(virtual_base);
    device_destroy(fpga_class, MKDEV(major, 0));
    class_destroy(fpga_class);
    unregister_chrdev(major, DEVICE_NAME);
    pr_info("FPGA MIDI: Module unloaded\n");
}

MODULE_LICENSE("GPL");
MODULE_AUTHOR("Zakiy Manigo");
MODULE_DESCRIPTION("FPGA MIDI char device driver");

module_init(fpga_init);
module_exit(fpga_exit);
