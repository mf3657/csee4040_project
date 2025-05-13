#include <linux/module.h>
#include <linux/init.h>
#include <linux/errno.h>
#include <linux/version.h>
#include <linux/kernel.h>
#include <linux/platform_device.h>
#include <linux/miscdevice.h>
#include <linux/io.h>
#include <linux/of.h>
#include <linux/of_address.h>
#include <linux/fs.h>
#include <linux/uaccess.h>
#include "fpga_intf.h"

#define DRIVER_NAME "fpga_intf"

/* Register offsets (byte-aligned addresses) for FPGA registers */
#define BG_RED(x)      ((x) + 0x0)   /* Background red register address */
#define BG_GREEN(x)    ((x) + 0x4)   /* Background green */
#define BG_BLUE(x)     ((x) + 0x8)   /* Background blue */
#define NOTE_REG(x)    ((x) + 0xC)   /* Audio note command */
#define SAMPLE1_REG(x) ((x) + 0x10)  /* Audio sample1 */
#define SAMPLE2_REG(x) ((x) + 0x14)  /* Audio sample2 */

/* Device-specific structure to hold mapped resource and last values */
struct fpga_intf_dev {
    struct resource res;      /* memory resource for registers */
    void __iomem *virtbase;   /* virtual base address for FPGA regs */
    fpga_intf_color_t background; /* last written background color */
    fpga_intf_note_t note;        /* last written note value */
    fpga_intf_sample_t sample1;     /* last written sample1 value */
    fpga_intf_sample_t sample2;     /* last written sample2 value */
} dev;

/* Write VGA background color components to FPGA registers */
static void set_background(fpga_intf_color_t *bg)
{
    /* Write each color component to its aligned register (32-bit write) */
    iowrite8(bg->red,   BG_RED(dev.virtbase));
    iowrite8(bg->green, BG_GREEN(dev.virtbase));
    iowrite8(bg->blue,  BG_BLUE(dev.virtbase));
    dev.background = *bg;
}

/* Write audio note command to FPGA register */
static void set_note(fpga_intf_note_t *note)
{
    iowrite32(note->note, NOTE_REG(dev.virtbase));
    dev.note = *note;
}

/* Write first audio sample value to FPGA register */
static void set_sample1(fpga_intf_sample_t *samp)
{
    iowrite32(samp->sample, SAMPLE1_REG(dev.virtbase));
    dev.sample1 = *samp;
}

/* Write second audio sample value to FPGA register */
static void set_sample2(fpga_intf_sample_t *samp)
{
    iowrite32(samp->sample, SAMPLE2_REG(dev.virtbase));
    dev.sample2 = *samp;
}

/* ioctl handler for /dev/fpga_intf */
static long fpga_intf_ioctl(struct file *f, unsigned int cmd, unsigned long arg)
{
    fpga_intf_color_t color_arg;
    fpga_intf_note_t  note_arg;
    fpga_intf_sample_t sample_arg;

    switch (cmd) {
    case FPGA_INTF_SET_BACKGROUND:
        if (copy_from_user(&color_arg, (fpga_intf_color_t __user *)arg, sizeof(color_arg)))
            return -EACCES;
        set_background(&color_arg);
        break;

    case FPGA_INTF_GET_BACKGROUND:
        color_arg = dev.background;
        if (copy_to_user((fpga_intf_color_t __user *)arg, &color_arg, sizeof(color_arg)))
            return -EACCES;
        break;

    case FPGA_INTF_SET_NOTE:
        if (copy_from_user(&note_arg, (fpga_intf_note_t __user *)arg, sizeof(note_arg)))
            return -EACCES;
        set_note(&note_arg);
        break;

    case FPGA_INTF_SET_SAMPLE1:
        if (copy_from_user(&sample_arg, (fpga_intf_sample_t __user *)arg, sizeof(sample_arg)))
            return -EACCES;
        set_sample1(&sample_arg);
        break;

    case FPGA_INTF_SET_SAMPLE2:
        if (copy_from_user(&sample_arg, (fpga_intf_sample_t __user *)arg, sizeof(sample_arg)))
            return -EACCES;
        set_sample2(&sample_arg);
        break;

    default:
        return -EINVAL;
    }

    return 0;
}

/* File operations structure */
static const struct file_operations fpga_intf_fops = {
    .owner            = THIS_MODULE,
    .unlocked_ioctl   = fpga_intf_ioctl,
};

/* Misc device for /dev/fpga_intf */
static struct miscdevice fpga_intf_misc_device = {
    .minor = MISC_DYNAMIC_MINOR,
    .name  = DRIVER_NAME,
    .fops  = &fpga_intf_fops,
};

/* Driver probe function - called when device is initialized */
static int __init fpga_intf_probe(struct platform_device *pdev)
{
    fpga_intf_color_t init_color = { .red=0xF9, .green=0xE4, .blue=0xB7, .pad=0x00 }; // example color (beige)
    fpga_intf_note_t init_note = { .note = 0 };
    fpga_intf_sample_t init_sample = { .sample = 0 };
    int ret;

    /* Register the misc device (/dev/fpga_intf) */
    ret = misc_register(&fpga_intf_misc_device);
    if (ret) {
        dev_err(&pdev->dev, "Failed to register misc device\n");
        return ret;
    }

    /* Get the physical address of the registers from device tree */
    ret = of_address_to_resource(pdev->dev.of_node, 0, &dev.res);
    if (ret) {
        misc_deregister(&fpga_intf_misc_device);
        return -ENOENT;
    }
    /* Request and ioremap the memory region for FPGA registers */
    if (request_mem_region(dev.res.start, resource_size(&dev.res), DRIVER_NAME) == NULL) {
        misc_deregister(&fpga_intf_misc_device);
        return -EBUSY;
    }
    dev.virtbase = of_iomap(pdev->dev.of_node, 0);
    if (dev.virtbase == NULL) {
        release_mem_region(dev.res.start, resource_size(&dev.res));
        misc_deregister(&fpga_intf_misc_device);
        return -ENOMEM;
    }

    /* Initialize FPGA registers with default values */
    set_background(&init_color);    // set initial background color
    set_note(&init_note);           // initialize note register to 0
    set_sample1(&init_sample);      // initialize audio sample1 to 0
    set_sample2(&init_sample);      // initialize audio sample2 to 0

    pr_info(DRIVER_NAME ": probe successful, mapped regs at 0x%pa\n", &dev.res.start);
    return 0;
}

/* Driver remove function */
static int fpga_intf_remove(struct platform_device *pdev)
{
    iounmap(dev.virtbase);
    release_mem_region(dev.res.start, resource_size(&dev.res));
    misc_deregister(&fpga_intf_misc_device);
    return 0;
}

#ifdef CONFIG_OF
static const struct of_device_id fpga_intf_of_match[] = {
    { .compatible = "csee4840,fpga_intf-1.0" },
    {},
};
MODULE_DEVICE_TABLE(of, fpga_intf_of_match);
#endif

static struct platform_driver fpga_intf_driver = {
    .driver = {
        .name  = DRIVER_NAME,
        .owner = THIS_MODULE,
        .of_match_table = of_match_ptr(fpga_intf_of_match),
    },
    .probe  = fpga_intf_probe,
    .remove = __exit_p(fpga_intf_remove),
};

/* Module init and exit */
static int __init fpga_intf_init(void)
{
    pr_info(DRIVER_NAME ": init\n");
    return platform_driver_register(&fpga_intf_driver);
}
static void __exit fpga_intf_exit(void)
{
    platform_driver_unregister(&fpga_intf_driver);
    pr_info(DRIVER_NAME ": exit\n");
}

module_init(fpga_intf_init);
module_exit(fpga_intf_exit);
MODULE_LICENSE("GPL");
MODULE_AUTHOR("Team Piano Heros");
MODULE_DESCRIPTION("FPGA interface driver (VGA background and audio control)");
