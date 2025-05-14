ifneq (${KERNELRELEASE},)

# KERNELRELEASE defined: we are being compiled as part of the Kernel
        obj-m := fpga_intf.o

else

# We are being compiled as a module: use the Kernel build system

	KERNEL_SOURCE := /usr/src/linux-headers-$(shell uname -r)
        PWD := $(shell pwd)

default: module main

module:
	${MAKE} -C ${KERNEL_SOURCE} SUBDIRS=${PWD} modules

clean:
	${MAKE} -C ${KERNEL_SOURCE} SUBDIRS=${PWD} clean
	${RM} main

TARFILES = Makefile README fpga_intf.h fpga_intf.c main.c
TARFILE = project_sw.tar.gz
.PHONY : tar
tar : $(TARFILE)

$(TARFILE) : $(TARFILES)
	tar zcfC $(TARFILE) .. $(TARFILES:%=project_sw/%)

endif 
