/* SPDX-License-Identifier: GPL-2.0+ */
OUTPUT_FORMAT("elf64-littleaarch64", "elf64-littleaarch64", "elf64-littleaarch64")
OUTPUT_ARCH(aarch64)
ENTRY(_start)
SECTIONS
{
	.text 0xe6302000 : { *(.text*) }
}
