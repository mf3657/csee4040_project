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

#include "fpga_ioctl.h"

#define DEVICE_NAME "fpga_intf"
#define CLASS_NAME  "fpga"
#define FPGA_BASE_ADDR 0xFF200000  // Change this to match your system
#define FPGA_SPAN      0x20        // Enough for 7 registers (one byte each)

// Register offsets (matching SystemVerilog case)
#define REG_BACKGROUND_R 0x00
#define REG_BACKGROUND_G 0x01
#define REG_BACKGROUND_B 0x02
#define REG_BPM          0x03
#define REG_PACKET_HIGH  0x04
#define REG_PACKET_LOW   0x05
#define REG_MIDI_WRITE   0x06

static void __iomem *fpga_regs;
static int major_number;
static struct class*  fpga_class  = NULL;
static struct device* fpga_device = NULL;

// ───────────────────────────────────────────────
// File operations
// ───────────────────────────────────────────────

static long fpga_ioctl(struct file *file, unsigned int cmd, unsigned long arg) {
    struct midi_packet pkt;
    struct rgb_color color;
    uint16_t bpm;

    switch (cmd) {
        case IOCTL_SEND_MIDI_PACKET:
            if (copy_from_user(&pkt, (void __user *)arg, sizeof(pkt)))
                return -EFAULT;
            iowrite8((pkt.high >> 24) & 0xFF, fpga_regs + REG_PACKET_HIGH);
            iowrite8((pkt.high >> 16) & 0xFF, fpga_regs + REG_PACKET_HIGH);
            iowrite8((pkt.high >> 8)  & 0xFF, fpga_regs + REG_PACKET_HIGH);
            iowrite8(pkt.high & 0xFF,           fpga_regs + REG_PACKET_HIGH);

            iowrite8((pkt.low >> 24) & 0xFF,  fpga_regs + REG_PACKET_LOW);
            iowrite8((pkt.low >> 16) & 0xFF,  fpga_regs + REG_PACKET_LOW);
            iowrite8((pkt.low >> 8)  & 0xFF,  fpga_regs + REG_PACKET_LOW);
            iowrite8(pkt.low & 0xFF,          fpga_regs + REG_PACKET_LOW);

            iowrite8(1, fpga_regs + REG_MIDI_WRITE);  // Trigger packet write
            return 0;

        case IOCTL_SET_BACKGROUND:
            if (copy_from_user(&color, (void __user *)arg, sizeof(color)))
                return -EFAULT;
            iowrite8(color.r, fpga_regs + REG_BACKGROUND_R);
            iowrite8(color.g, fpga_regs + REG_BACKGROUND_G);
            iowrite8(color.b, fpga_regs + REG_BACKGROUND_B);
            return 0;

        case IOCTL_SET_BPM:
            if (copy_from_user(&bpm, (void __user *)arg, sizeof(bpm)))
                return -EFAULT;
            iowrite8(bpm & 0xFF, fpga_regs + REG_BPM);  // Send only lower byte
            return 0;

        default:
            return -EINVAL;
    }
}

static int fpga_open(struct inode *inodep, struct file *filep) {
    return 0;
}

static int fpga_release(struct inode *inodep, struct file *filep) {
    return 0;
}

static struct file_operations fops = {
    .owner          = THIS_MODULE,
    .unlocked_ioctl = fpga_ioctl,
    .open           = fpga_open,
    .release        = fpga_release,
};

// ───────────────────────────────────────────────
// Module init/exit
// ───────────────────────────────────────────────

static int __init fpga_init(void) {
    printk(KERN_INFO "[fpga_intf] Initializing driver\n");

    // Register character device
    major_number = register_chrdev(0, DEVICE_NAME, &fops);
    if (major_number < 0) {
        printk(KERN_ALERT "[fpga_intf] Failed to register char device\n");
        return major_number;
    }

    // Register device class
    fpga_class = class_create(THIS_MODULE, CLASS_NAME);
    if (IS_ERR(fpga_class)) {
        unregister_chrdev(major_number, DEVICE_NAME);
        return PTR_ERR(fpga_class);
    }

    // Register device driver
    fpga_device = device_create(fpga_class, NULL, MKDEV(major_number, 0), NULL, DEVICE_NAME);
    if (IS_ERR(fpga_device)) {
        class_destroy(fpga_class);
        unregister_chrdev(major_number, DEVICE_NAME);
        return PTR_ERR(fpga_device);
    }

    // Map physical address to virtual kernel address
    fpga_regs = ioremap(FPGA_BASE_ADDR, FPGA_SPAN);
    if (!fpga_regs) {
        device_destroy(fpga_class, MKDEV(major_number, 0));
        class_destroy(fpga_class);
        unregister_chrdev(major_number, DEVICE_NAME);
        printk(KERN_ALERT "[fpga_intf] Failed to ioremap\n");
        return -ENOMEM;
    }

    printk(KERN_INFO "[fpga_intf] Driver loaded: /dev/%s\n", DEVICE_NAME);
    return 0;
}

static void __exit fpga_exit(void) {
    iounmap(fpga_regs);
    device_destroy(fpga_class, MKDEV(major_number, 0));
    class_destroy(fpga_class);
    unregister_chrdev(major_number, DEVICE_NAME);
    printk(KERN_INFO "[fpga_intf] Driver unloaded\n");
}

module_init(fpga_init);
module_exit(fpga_exit);

MODULE_LICENSE("GPL");
MODULE_AUTHOR("Zakiy");
MODULE_DESCRIPTION("FPGA MIDI ioctl driver for piano tiles game");
MODULE_VERSION("1.0");
