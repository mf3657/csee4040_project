/* * Device driver for the VGA video generator
 *
 * A Platform device implemented using the misc subsystem
 *
 * Stephen A. Edwards
 * Columbia University
 *
 * References:
 * Linux source: Documentation/driver-model/platform.txt
 *               drivers/misc/arm-charlcd.c
 * http://www.linuxforu.com/tag/linux-device-drivers/
 * http://free-electrons.com/docs/
 *
 * "make" to build
 * insmod fpga_intf.ko
 *
 * Check code style with
 * checkpatch.pl --file --no-tree fpga_intf.c
 */

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

#define DRIVER_NAME "fpga_intf"

/* Example Device registers from lab3, currently for sending background colours */
#define BG_RED(x) (x)
#define BG_GREEN(x) ((x)+1)
#define BG_BLUE(x) ((x)+2)

/*
 * Information about our device
 */
struct fpga_intf_dev {
	struct resource res; /* Resource: our registers */
	void __iomem *virtbase; /* Where registers can be accessed in memory */
        fpga_intf_color_t background; // Placeholder ioctl argument from lab 3
} dev;

/*
 * Write segments of a single digit
 * Assumes digit is in range and the device information has been set up
 * 
 * Note* the BG_***(dev.virtbase) calls are macros to clean up register access.
 */
static void write_background(fpga_intf_color_t *background)
{
	iowrite8(background->red, BG_RED(dev.virtbase) );
	iowrite8(background->green, BG_GREEN(dev.virtbase) );
	iowrite8(background->blue, BG_BLUE(dev.virtbase) );
	dev.background = *background;
}

/*
 * Handle ioctl() calls from userspace:
 * Read or write the segments on single digits.
 * Note extensive error checking of arguments
 */
static long fpga_intf_ioctl(struct file *f, unsigned int cmd, unsigned long arg)
{
	fpga_intf_arg_t vla;

	switch (cmd) {
	case FPGA_INTF_WRITE_BACKGROUND:
		if (copy_from_user(&vla, (fpga_intf_arg_t *) arg,
				   sizeof(fpga_intf_arg_t)))
			return -EACCES;
		write_background(&vla.background);
		break;

	case FPGA_INTF_READ_BACKGROUND:
	  	vla.background = dev.background;
		if (copy_to_user((fpga_intf_arg_t *) arg, &vla,
				 sizeof(fpga_intf_arg_t)))
			return -EACCES;
		break;

	default:
		return -EINVAL;
	}

	return 0;
}

/* The operations our device knows how to do */
static const struct file_operations fpga_intf_fops = {
	.owner		= THIS_MODULE,
	.unlocked_ioctl = fpga_intf_ioctl,
};

/* Information about our device for the "misc" framework -- like a char dev */
static struct miscdevice fpga_intf_misc_device = {
	.minor		= MISC_DYNAMIC_MINOR,
	.name		= DRIVER_NAME,
	.fops		= &fpga_intf_fops,
};

/*
 * Initialization code: get resources (registers) and display
 * a welcome message
 */
static int __init fpga_intf_probe(struct platform_device *pdev)
{
        fpga_intf_color_t beige = { 0xf9, 0xe4, 0xb7 };
	int ret;

	/* Register ourselves as a misc device: creates /dev/fpga_intf */
	ret = misc_register(&fpga_intf_misc_device);

	/* Get the address of our registers from the device tree */
	ret = of_address_to_resource(pdev->dev.of_node, 0, &dev.res);
	if (ret) {
		ret = -ENOENT;
		goto out_deregister;
	}

	/* Make sure we can use these registers */
	if (request_mem_region(dev.res.start, resource_size(&dev.res),
			       DRIVER_NAME) == NULL) {
		ret = -EBUSY;
		goto out_deregister;
	}

	/* Arrange access to our registers */
	dev.virtbase = of_iomap(pdev->dev.of_node, 0);
	if (dev.virtbase == NULL) {
		ret = -ENOMEM;
		goto out_release_mem_region;
	}
        
	/* Set an initial color */
        write_background(&beige);

	return 0;

out_release_mem_region:
	release_mem_region(dev.res.start, resource_size(&dev.res));
out_deregister:
	misc_deregister(&fpga_intf_misc_device);
	return ret;
}

/* Clean-up code: release resources */
static int fpga_intf_remove(struct platform_device *pdev)
{
	iounmap(dev.virtbase);
	release_mem_region(dev.res.start, resource_size(&dev.res));
	misc_deregister(&fpga_intf_misc_device);
	return 0;
}

/* Which "compatible" string(s) to search for in the Device Tree */
#ifdef CONFIG_OF
static const struct of_device_id fpga_intf_of_match[] = {
	{ .compatible = "csee4840,fpga_intf-1.0" },
	{},
};
MODULE_DEVICE_TABLE(of, fpga_intf_of_match);
#endif

/* Information for registering ourselves as a "platform" driver */
static struct platform_driver fpga_intf_driver = {
	.driver	= {
		.name	= DRIVER_NAME,
		.owner	= THIS_MODULE,
		.of_match_table = of_match_ptr(fpga_intf_of_match),
	},
	.remove	= __exit_p(fpga_intf_remove),
};

/* Called when the module is loaded: set things up */
static int __init fpga_intf_init(void)
{
	pr_info(DRIVER_NAME ": init\n");
	return platform_driver_probe(&fpga_intf_driver, fpga_intf_probe);
}

/* Calball when the module is unloaded: release resources */
static void __exit fpga_intf_exit(void)
{
	platform_driver_unregister(&fpga_intf_driver);
	pr_info(DRIVER_NAME ": exit\n");
}

module_init(fpga_intf_init);
module_exit(fpga_intf_exit);

MODULE_LICENSE("GPL");
MODULE_AUTHOR("Stephen A. Edwards, Columbia University");
MODULE_DESCRIPTION("FPGA intf driver");
