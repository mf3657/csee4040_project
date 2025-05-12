// piano_heroes.c - Kernel module for VGA piano tiles (writes default key colors)

#include <linux/module.h>
#include <linux/init.h>
#include <linux/kernel.h>
#include <linux/fs.h>
#include <linux/io.h>
#include <linux/uaccess.h>

#define HW_REGS_BASE      0xFF200000
#define HW_REGS_SPAN      0x100000
#define PIANO_BASE_OFFSET 0x00000000

static void __iomem *hw_regs_base = NULL;
static void __iomem *piano_virtual_base = NULL;

static int __init piano_init(void) {
    printk(KERN_INFO "[piano_heroes] Initializing VGA piano tile module\n");

    // Map the hardware registers into kernel virtual address space
    hw_regs_base = ioremap(HW_REGS_BASE, HW_REGS_SPAN);
    if (!hw_regs_base) {
        printk(KERN_ERR "[piano_heroes] Failed to map HW_REGS_BASE\n");
        return -ENOMEM;
    }

    // Offset into the register block (if needed)
    piano_virtual_base = hw_regs_base + PIANO_BASE_OFFSET;

    // Set first 4 registers with 3-bit color codes for keys
    // 0x49249249 = pattern of 3'b001 (white) for 10 keys per register
    iowrite32(0x49249249, piano_virtual_base + 0);  // keys 0–9
    iowrite32(0x49249249, piano_virtual_base + 4);  // keys 10–19
    iowrite32(0x49249249, piano_virtual_base + 8);  // keys 20–24 (rest unused)
    iowrite32(0x00000000, piano_virtual_base + 12); // padding

    printk(KERN_INFO "[piano_heroes] VGA piano keys initialized to white\n");
    return 0;
}

static void __exit piano_exit(void) {
    printk(KERN_INFO "[piano_heroes] Exiting module and cleaning up\n");

    if (hw_regs_base)
        iounmap(hw_regs_base);
}

module_init(piano_init);
module_exit(piano_exit);

MODULE_LICENSE("GPL");
MODULE_AUTHOR("Robel Wondwossen");
MODULE_DESCRIPTION("VGA Piano Heroes: Display static keys at screen bottom");
