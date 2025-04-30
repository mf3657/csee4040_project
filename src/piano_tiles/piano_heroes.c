// piano_heroes.c - Kernel module for VGA piano tiles (writes default key colors)
#include <linux/module.h>
#include <linux/init.h>
#include <linux/kernel.h>
#include <linux/fs.h>
#include <linux/uaccess.h>
#include <linux/io.h>

#define HW_REGS_BASE      0xFF200000
#define HW_REGS_SPAN      0x100000
#define PIANO_BASE_OFFSET 0x00000000

static void __iomem *piano_virtual_base;

static int __init piano_init(void) {
    void __iomem *hw_regs;

    printk(KERN_INFO "[piano_heroes] Initializing VGA piano tile module\n");

    hw_regs = ioremap(HW_REGS_BASE, HW_REGS_SPAN);
    if (!hw_regs) {
        printk(KERN_ERR "[piano_heroes] Failed to map HW_REGS_BASE\n");
        return -ENOMEM;
    }

    piano_virtual_base = hw_regs + PIANO_BASE_OFFSET;

    // Set first 4 registers with 3-bit color codes (default = white)
    iowrite32(0x49249249, piano_virtual_base + 0);  // keys 0–9
    iowrite32(0x49249249, piano_virtual_base + 4);  // keys 10–19
    iowrite32(0x49249249, piano_virtual_base + 8);  // keys 20–29 (only 24 used)
    iowrite32(0x00000000, piano_virtual_base + 12); // zero-fill unused

    printk(KERN_INFO "[piano_heroes] VGA piano keys initialized to white\n");
    return 0;
}

static void __exit piano_exit(void) {
    printk(KERN_INFO "[piano_heroes] Exiting module and cleaning up\n");
    if (piano_virtual_base)
        iounmap((void __iomem *)((uintptr_t)piano_virtual_base & ~(PAGE_SIZE - 1)));
}

module_init(piano_init);
module_exit(piano_exit);

MODULE_LICENSE("GPL");
MODULE_AUTHOR("Robel Wondwossen");
MODULE_DESCRIPTION("VGA Piano Heroes: Display static keys at screen bottom");
