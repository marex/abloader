# SPDX-License-Identifier: GPL-2.0+
#
CROSS_COMPILE=aarch64-linux-gnu-

TGT = jump
ASRC += start.S
LDS = jump.ld

OBJS += $(ASRC:.S=.o)

CC=$(CROSS_COMPILE)gcc
OBJCOPY=$(CROSS_COMPILE)objcopy
OBJDUMP=$(CROSS_COMPILE)objdump
LD=$(CROSS_COMPILE)ld
NM=$(CROSS_COMPILE)nm
SIZE=$(CROSS_COMPILE)size

CFLAGS=-g -O0
LDFLAGS=-T$(LDS) -nostdlib -Map=$(TGT).map

all: update.itb $(TGT).elf

%.o: %.S
	$(CC) $(CFLAGS) -c $^ -o $@

$(TGT).elf: $(OBJS)
	$(LD) $(LDFLAGS) $^ -o $@

$(TGT).bin: $(TGT).elf
	$(OBJCOPY) $< -O binary $@

$(TGT).srec: $(TGT).elf
	$(OBJCOPY) --srec-forceS3 $< -O srec $@
	$(NM) -n $(TGT).elf > $(TGT).sym
	$(SIZE) $(TGT).elf

update.itb: $(TGT).bin
	mkimage -f update.its $@

clean:
	rm -rf *.elf *.hex *.map *.o *.disasm *.sym *.bin
