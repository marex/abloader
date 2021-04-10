PMIC-based A/B boot switcher for Gen3
=====================================

# 1. Overview
-------------

This tool permits switching between A and B copy of ATF, Optee-OS
and U-Boot, and implements reboot into flash-writer tool. This is
useful mostly for CI and other testing.

# 2. Compile components
-----------------------

Aarch64 cross compiler is mandatory.

## 2.1. Flash Writer tool
-------------------------

Example build for aarch64 salvator-x:
```shell
$ git clone https://github.com/renesas-rcar/flash_writer
$ cd flash_writer
$ CROSS_COMPILE=aarch64-linux-gnu- make AArch=64
# Use the following MOT file in SCIF loader:
# AArch64_output/AArch64_Flash_writer_SCIF_DUMMY_CERT_E6300400_salvator-x.mot
```

## 2.2 ABloader
---------------

```shell
$ CROSS_COMPILE=aarch64-linux-gnu- make
```

## 2.3 ATF
----------

Follow Gen3 ATF build [documentation](https://elinux.org/R-Car/Boards/ATF-Gen3),
use ATF commit 8078b5c5a ("Merge changes from topic "allwinner_h616" into integration")
and apply patches in this repository atf-patches/ until they are upstream, otherwise ATF
would disable RWDT and won't load from correct offsets.

Add RCAR_RPC_HYPERFLASH_LOCKED=0 to make arguments to unlock HF access from U-Boot.
This is convenient for easy updates of various boot components using U-Boot MTD
framework.

## 2.4 OpTeeOS
--------------

Follow OpTee [documentation](https://optee.readthedocs.io/en/latest/building/index.html).

In short, clone OpTee-OS git repository and compile it as follows:
```shell
$ git clone https://github.com/OP-TEE/optee_os.git
$ cd optee_os
$ make PLATFORM=rcar PLATFORM_FLAVOR=salvator_dt ARCH=arm CFG_ARM64_core=y
```

## 2.5 U-Boot
-------------

Follow Gen3 U-Boot build [documentation](https://elinux.org/R-Car/Boards/U-Boot-Gen3).

# 3. Installation
-----------------

## 3.1 Flash Writer tool
------------------------

To install the abloader tool into HF, use
[flash-writer](https://github.com/renesas-rcar/flash_writer)
as it supports writing raw binary files using the
[XLS3 command](https://github.com/renesas-rcar/flash_writer/blob/rcar_gen3/docs/application-note.md#342-write-to-the-raw-binary-images-to-the-serial-flash). Follow flash-writer
[documentation](https://github.com/renesas-rcar/flash_writer/blob/rcar_gen3/docs/application-note.md)
to compile and start flash-writer on your board.

## 3.2 The HF layout used by this tool
--------------------------------------

| HF offset	| Component				| Filename										|
|---------------|---------------------------------------|---------------------------------------------------------------------------------------|
| 0x000000	| bootparam.sa0 from this repository	| ABloader:bootparam.sa0								|
| 0x040000	| A-copy ATF BL2			| ATF:build/rcar/release/bl2.bin							|
| 0x080000	| jump.bin from this repository		| ABloader:jump.bin									|
| 0x180000	| A-copy ATF SA6			| ATF:tools/renesas/rcar_layout_create/cert_header_sa6.bin				|
| 0x1c0000	| A-copy ATF BL31			| ATF:build/rcar/release/bl31.bin							|
| 0x200000	| A-copy OpTee OS			| OpTeeOS:out/arm-plat-rcar/core/tee-pager_v2.bin					|
| 0x640000	| A-copy U-Boot				| U-Boot:u-boot.bin									|
| 0x800000	| Flash writer				| FWT:AArch64_output/AArch64_Flash_writer_SCIF_DUMMY_CERT_E6300400_salvator-x.bin	|
| 0x840000	| B-copy ATF BL2			| ATF:build/rcar/release/bl2.bin							|
| 0x980000	| B-copy ATF SA6			| ATF:tools/renesas/rcar_layout_create/cert_header_sa6.bin				|
| 0x9c0000	| B-copy ATF BL31			| ATF:build/rcar/release/bl31.bin							|
| 0xa00000	| B-copy OpTee OS			| OpTeeOS:out/arm-plat-rcar/core/tee-pager_v2.bin					|
| 0xe40000	| B-copy U-Boot				| U-Boot:u-boot.bin									|

## 3.3 Write raw binary file into HF using XLS3
-----------------------------------------------

Follow flash-writer [XLS3 command](https://github.com/renesas-rcar/flash_writer/blob/rcar_gen3/docs/application-note.md#342-write-to-the-raw-binary-images-to-the-serial-flash)
documentation and write newly built files to HF. HF offsets and file names are in
[3.2 The HF layout used by this tool](#the-hf-layout-used-by-this-tool).

Example of writing u-boot.bin that is 0x6adbd bytes long to 0xe40000:
```
Flash writer for R-Car H3/M3/M3N Series V1.11 Feb.12,2020

>xls3
===== Qspi/HyperFlash writing of Gen3 Board Command =============
Load Program to Spiflash
Writes to any of SPI address.
Please select,FlashMemory.
   1 : QspiFlash       (U5 : S25FS128S)
   2 : QspiFlash Board (CN3: S25FL512S)
   3 : HyperFlash      (SiP internal)
  Select (1-3)>3
 READ ID OK.
Program size & Qspi/HyperFlash Save Address
===== Please Input Program size ============
  Please Input : H'6adbd

===== Please Input Qspi/HyperFlash Save Address ===
  Please Input : H'e40000
Work RAM(H'50000000-H'53FFFFFF) Clear....
please send ! (binary)
```
At this point, send u-boot.bin file as raw data.

```
SPI Data Clear(H'FF) Check :H'00E40000-00EBFFFF Erasing...Erase Completed
SAVE SPI-FLASH....... complete!

======= Qspi/HyperFlash Save Information  =================
 SpiFlashMemory Stat Address : H'00E40000
 SpiFlashMemory End Address  : H'00EAADBC
===========================================================
```

# 4. Switching between copies
-----------------------------

ABloader switches between A and B copy of the ATF, OpTee OS and U-Boot between
consecutive boots. ABloader also starts watchdog, so in case of a hang, the
system reboots into the other copy after 60 seconds. Furthermore, it is possible
to reboot into specific copy or flash-writer.

Check which copy is booted:
```shell
u-boot=> i2c dev 7 && i2c md 0x30 0x70 2
Setting bus to 7
0070: a5 01    ..
#     ^^ ^^
# a5 is magic value
# 00 means A-copy / 01 means B-copy
```

Boot A-copy:
```shell
u-boot=> i2c dev 7 && i2c mw 0x30 0x70 0xa5 && i2c mw 0x30 0x71 0 ; reset
```

Boot B-copy:
```shell
u-boot=> i2c dev 7 && i2c mw 0x30 0x70 0xa5 && i2c mw 0x30 0x71 1 ; reset
```

Boot flash-writer
```shell
u-boot=> i2c dev 7 && i2c mw 0x30 0x70 0xa5 && i2c mw 0x30 0x71 3 ; reset
```

# 5. Tips and tricks
--------------------

ABloader build also generates update.itb fitImage, which contains the ABloader
SA0 and jump.bin, and which can be used by mainline U-Boot dfu tftp in case HF
is unlocked -- see ATF RCAR_RPC_HYPERFLASH_LOCKED=0 above.

To install update.itb fitImage from running U-Boot, download the file into DRAM
to address $loadaddr and run
```shell
u-boot=> dfu tftp ${loadaddr}
```
