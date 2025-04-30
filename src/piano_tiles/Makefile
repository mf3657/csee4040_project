# Makefile for piano_heroes kernel module and userspace app

KDIR := /usr/src/linux-headers-$(shell uname -r)
PWD  := $(shell pwd)

obj-m := piano_heroes.o

all:
	$(MAKE) -C $(KDIR) M=$(PWD) modules
	gcc -o hello hello.c

clean:
	rm -f *.o *.ko *.mod.* *.order *.symvers hello