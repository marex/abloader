/* SPDX-License-Identifier: GPL-2.0+ */

#define CPG_SMSTPCR4			0xe6150140
#define CPG_SMSTPCR4_RWDT		0x00000004
#define CPG_SMSTPCR9			0xe6150994
#define CPG_SMSTPCR9_DVFS		0x04000000

#define PRR				0xfff00044
#define MFISBTSTSR			0xe6260604
#define MFISWPCNTR			0xe6260900

#define RWDT_BASE			0xe6020000
#define RWDT_RWTCNT			0x00
#define RWDT_RWTCSRA			0x04

#define IIC_BASE			0xe60b0000
#define IIC_ICDR			0x00
#define IIC_ICCR			0x04
#define IIC_ICSR			0x08
#define IIC_ICIC			0x0c
#define IIC_ICCL			0x10
#define IIC_ICCH			0x14

#define IIC_ICDR_DUMMY			0x52

#define IIC_ICCR_ENABLE			0x80
#define IIC_ICCR_START			0x94
#define IIC_ICCR_STOP			0x90
#define IIC_ICCR_RETRANSMISSION		0x94
#define IIC_ICCR_CHANGE			0x81
#define IIC_ICCR_STOP_READ		0xc0

#define IIC_ICSR_BUSY			0x10
#define IIC_ICSR_AL			0x08
#define IIC_ICSR_TACK			0x04
#define IIC_ICSR_WAIT			0x02
#define IIC_ICSR_DTE			0x01

#define IIC_ICIC_TACKE			0x04
#define IIC_ICIC_WAITE			0x02
#define IIC_ICIC_DTEE			0x01

#define IIC_ICCL_EXTAL_TYPE_0		0x07
#define IIC_ICCL_EXTAL_TYPE_1		0x09
#define IIC_ICCL_EXTAL_TYPE_2		0x0b
#define IIC_ICCL_EXTAL_TYPE_3		0x0e
#define IIC_ICCL_EXTAL_TYPE_E		0x15

#define IIC_ICCH_EXTAL_TYPE_0		0x01
#define IIC_ICCH_EXTAL_TYPE_1		0x02
#define IIC_ICCH_EXTAL_TYPE_2		0x03
#define IIC_ICCH_EXTAL_TYPE_3		0x05
#define IIC_ICCH_EXTAL_TYPE_E		0x07

/*
 * dummy = dummy xfer
 * stop = read-mode:IIC_ICCR_STOP_READ / write-mode:IIC_ICCR_STOP
 */
.macro riic_check_error dummy stop
	ldrb	w1, [x0, IIC_ICSR]
	and	w1, w1, #(IIC_ICSR_AL | IIC_ICSR_TACK)
	cbz	w1, 6f

	tbz	w1, 1, 3f

	/*** ICSR AL=1 ***/
	ldrb	w1, [x0, IIC_ICSR]
	bic	w1, w1, #IIC_ICSR_AL
	strb	w1, [x0, IIC_ICSR]

	ldr	w1, =\dummy
	cbz	w1, 1f
	ldr	w1, =IIC_ICDR_DUMMY
	strb	w1, [x0, IIC_ICDR]

1:	ldrb	w1, [x0, IIC_ICSR]
	tbz	w1, 1, 1b	/* while IIC_ICSR_WAIT == 0 (tbz uses bit offset) */

	ldr	w1, =\stop
	strb	w1, [x0, IIC_ICCR]

	ldrb	w1, [x0, IIC_ICSR]
	bic	w1, w1, #IIC_ICSR_WAIT
	strb	w1, [x0, IIC_ICSR]

2:	ldrb	w1, [x0, IIC_ICSR]
	tbnz	w1, 4, 2b	/* while IIC_ICSR_BUSY != 0 (tbz uses bit offset) */

	b	5f

	/**************************/

3:	/*** ICSR AL=0 ***/
	ldr	w1, =\stop
	strb	w1, [x0, IIC_ICCR]

	ldrb	w1, [x0, IIC_ICIC]
	bic	w1, w1, #(IIC_ICIC_WAITE | IIC_ICIC_DTEE)
	strb	w1, [x0, IIC_ICIC]

	ldrb	w1, [x0, IIC_ICSR]
	bic	w1, w1, #IIC_ICSR_TACK
	strb	w1, [x0, IIC_ICSR]

4:	ldrb	w1, [x0, IIC_ICSR]
	tbnz	w1, 4, 4b	/* while IIC_ICSR_BUSY != 0 (tbz uses bit offset) */

5:
	strb	wzr, [x0, IIC_ICCR]
6:	nop
.endm

.macro riic_start
	/* Enable clock */
	ldr	x0, =CPG_SMSTPCR9
	ldr	w1, [x0]
	bic	w1, w1, #CPG_SMSTPCR9_DVFS
	str	w1, [x0]

	/* RIIC interaction */
	ldr	x0, =IIC_BASE
	strb	wzr, [x0, IIC_ICCR]

	ldrb	w1, [x0, IIC_ICCR]
	orr	w1, w1, #IIC_ICCR_ENABLE
	strb	w1, [x0, IIC_ICCR]

	/* FIXME: E3 and CHECK_MD13_MD14 */

	ldr	w1, =IIC_ICCL_EXTAL_TYPE_0
	strb	w1, [x0, IIC_ICCL]
	ldr	w1, =IIC_ICCH_EXTAL_TYPE_0
	strb	w1, [x0, IIC_ICCH]

	ldrb	w1, [x0, IIC_ICIC]
	orr	w1, w1, #(IIC_ICIC_TACKE | IIC_ICIC_WAITE | IIC_ICIC_DTEE)
	strb	w1, [x0, IIC_ICIC]

	ldr	w1, =IIC_ICCR_START
	strb	w1, [x0, IIC_ICCR]
.endm

.macro riic_set_pmic_addr addr
	riic_check_error dummy=1 stop=IIC_ICCR_STOP

1:	ldr	w1, [x0, IIC_ICSR]
	tbz	w1, 0, 1b	/* if IIC_ICSR_DTE != 0 (tbz uses bit offset) */

	ldrb	w1, [x0, IIC_ICIC]
	bic	w1, w1, #IIC_ICIC_DTEE
	strb	w1, [x0, IIC_ICIC]

	ldr	w1, =\addr
	strb	w1, [x0, IIC_ICDR]
.endm

.macro riic_write_reg_addr_reg reg
	riic_check_error dummy=0 stop=IIC_ICCR_STOP

1:	ldrb	w1, [x0, IIC_ICSR]
	tbz	w1, 1, 1b	/* if IIC_ICSR_WAIT != 0 (tbz uses bit offset) */

	strb	\reg, [x0, IIC_ICDR]

	ldrb	w1, [x0, IIC_ICSR]
	bic	w1, w1, #IIC_ICSR_WAIT
	strb	w1, [x0, IIC_ICSR]
.endm

.macro riic_write_reg_addr_data reg
	riic_check_error dummy=0 stop=IIC_ICCR_STOP

1:	ldrb	w1, [x0, IIC_ICSR]
	tbz	w1, 1, 1b	/* if IIC_ICSR_WAIT != 0 (tbz uses bit offset) */

	ldr	w1, =\reg
	strb	w1, [x0, IIC_ICDR]

	ldrb	w1, [x0, IIC_ICSR]
	bic	w1, w1, #IIC_ICSR_WAIT
	strb	w1, [x0, IIC_ICSR]
.endm

.macro riic_retransmit
	riic_check_error dummy=0 stop=IIC_ICCR_STOP

1:	ldrb	w1, [x0, IIC_ICSR]
	tbz	w1, 1, 1b	/* if IIC_ICSR_WAIT != 0 (tbz uses bit offset) */

	ldr	w1, =IIC_ICCR_RETRANSMISSION
	strb	w1, [x0, IIC_ICCR]

	ldrb	w1, [x0, IIC_ICSR]
	bic	w1, w1, #IIC_ICSR_WAIT
	strb	w1, [x0, IIC_ICSR]

	ldrb	w1, [x0, IIC_ICIC]
	orr	w1, w1, #IIC_ICIC_DTEE
	strb	w1, [x0, IIC_ICIC]
.endm

.macro riic_set_slave_read addr
	riic_check_error dummy=0 stop=IIC_ICCR_STOP

1:	ldrb	w1, [x0, IIC_ICSR]
	tbz	w1, 0, 1b	/* if IIC_ICSR_DTE != 0 (tbz uses bit offset) */

	ldrb	w1, [x0, IIC_ICIC]
	bic	w1, w1, #IIC_ICIC_DTEE
	strb	w1, [x0, IIC_ICIC]

	ldr	w1, =(\addr | 1)	/* FIXME: PMIC address (R) */
	strb	w1, [x0, IIC_ICDR]
.endm

.macro riic_change_send_to_receive
	riic_check_error dummy=0 stop=IIC_ICCR_STOP

1:	ldrb	w1, [x0, IIC_ICSR]
	tbz	w1, 1, 1b	/* if IIC_ICSR_WAIT != 0 (tbz uses bit offset) */

	ldr	w1, =IIC_ICCR_CHANGE
	strb	w1, [x0, IIC_ICCR]

	ldrb	w1, [x0, IIC_ICSR]
	bic	w1, w1, #IIC_ICSR_WAIT
	strb	w1, [x0, IIC_ICSR]
.endm

.macro riic_stop_read
	riic_check_error dummy=0 stop=IIC_ICCR_STOP_READ

1:	ldrb	w1, [x0, IIC_ICSR]
	tbz	w1, 1, 1b	/* if IIC_ICSR_WAIT != 0 (tbz uses bit offset) */

	ldr	w1, =IIC_ICCR_STOP_READ
	strb	w1, [x0, IIC_ICCR]

	ldrb	w1, [x0, IIC_ICSR]
	bic	w1, w1, #IIC_ICSR_WAIT
	strb	w1, [x0, IIC_ICSR]

	ldrb	w1, [x0, IIC_ICIC]
	orr	w1, w1, #IIC_ICIC_DTEE
	strb	w1, [x0, IIC_ICIC]
.endm

/* This sets w2 with the result */
.macro riic_read
1:	ldrb	w1, [x0, IIC_ICSR]
	tbz	w1, 0, 1b	/* if IIC_ICSR_DTE != 0 (tbz uses bit offset) */

	ldrb	w1, [x0, IIC_ICIC]
	bic	w1, w1, #IIC_ICIC_DTEE
	strb	w1, [x0, IIC_ICIC]

	ldrb	w2, [x0, IIC_ICDR]
.endm

.macro riic_done
1:	ldrb	w1, [x0, IIC_ICSR]
	tbnz	w1, 4, 1b	/* while IIC_ICSR_BUSY != 0 (tbz uses bit offset) */

	strb	wzr, [x0, IIC_ICCR]
.endm

.macro riic_stop
	riic_check_error dummy=0 stop=IIC_ICCR_STOP

1:	ldrb	w1, [x0, IIC_ICSR]
	tbz	w1, 1, 1b	/* if IIC_ICSR_WAIT != 0 (tbz uses bit offset) */

	ldr	w1, =IIC_ICCR_STOP
	strb	w1, [x0, IIC_ICCR]

	ldrb	w1, [x0, IIC_ICSR]
	bic	w1, w1, #IIC_ICSR_WAIT
	strb	w1, [x0, IIC_ICSR]
.endm

.macro riic_pmic_read_reg pmicreg
	riic_start
	riic_set_pmic_addr addr=(0x30 << 1)	/* PMIC address (W) */
	riic_write_reg_addr_data reg=\pmicreg	/* PMIC register address */
	riic_retransmit
	riic_set_slave_read addr=(0x30 << 1)	/* PMIC address (R) */
	riic_change_send_to_receive
	riic_stop_read
	riic_read
	riic_done
.endm

.macro rwdt_start
	/* Enable clock */
	ldr	x0, =CPG_SMSTPCR4
	ldr	w1, [x0]
	bic	w1, w1, #CPG_SMSTPCR4_RWDT
	str	w1, [x0]

	ldr	x0, =RWDT_BASE

	ldr	w1, =0x5a5a0000
	str	w1, [x0, RWDT_RWTCNT]

	ldr	w1, =0xa5a5a583	/* Start RWDT, timeout 64s */
	str	w1, [x0, RWDT_RWTCSRA]
.endm

.macro mfis_unlock
	ldr	x0, =PRR
	ldr	w1, [x0]
	lsr	w1, w1, #8
	and	w1, w1, #0xff
	cmp	w1, #0x52	/* M3W has no MFISWPCNTR */
	b.eq	mfisskip
	ldr	x0, =MFISWPCNTR
	ldr	w1, =0xacce0001
	str	w1, [x0]
mfisskip: nop
.endm

.macro load_copy_size
	ldr	x2, =0x00014000	/* E3/D3 => 80 kiB BL2 */
	ldr	x1, =PRR
	ldr	w3, [x1]
	lsr	w3, w3, #8
	and	w3, w3, #0xff
	cmp	w3, #0x57	/* E3 => 80 kiB BL2 */
	b.eq	ise3d3
	cmp	w3, #0x58	/* D3 => 80 kiB BL2 */
	b.eq	ise3d3
	ldr	x2, =0x0002c000	/* H3/M3-W/M3-W+/M3-N => 170 kiB BL2 */
ise3d3: nop	/* E3 or D3 */
.endm

.text
.global _start
_start:
	/* Enable WDT */
	rwdt_start

	/* Unlock MFIS write access */
	mfis_unlock

	riic_pmic_read_reg pmicreg=0x00
	cmp	w2, #0xdb
	b.ne	0f	/* PMIC Vendor code == 0xdb */
	riic_pmic_read_reg pmicreg=0x01
	cmp	w2, #0x60
	b.ne	0f	/* PMIC Part code == 0x60 */

	riic_pmic_read_reg pmicreg=0x70	/* 0x70..0x79 are REG_KEEP1..10[7:0] */
	cmp	w2, #0xa5	/* Magic */
	b.eq	samp
	eor	w2, w2, w2	/* Boot A-copy (bit 0 is not set) */
	b	flip

samp:	riic_pmic_read_reg pmicreg=0x71	/* 0x70..0x79 are REG_KEEP1..10[7:0] */

	/* Flip A-B boot bit 0x71[0] */
flip:	bic	w2, w2, #0x7c	/* Filter out other bits than 0x71[7,1,0] */
	eor	w2, w2, #0x01

	/* Update PMIC content to boot the other copy on next boot */
	riic_start
	riic_set_pmic_addr addr=(0x30 << 1)	/* PMIC address (W) */
	riic_write_reg_addr_data reg=0x70	/* PMIC register address */
	riic_write_reg_addr_data reg=0xa5	/* PMIC register magic */
	riic_write_reg_addr_reg	reg=w2		/* PMIC register data */
	riic_stop
	riic_done

	tbz	w2, 1, 3f	/* if (0x71[1] == 1) then boot flash-writer */
	ldr	x0, =0x08803c00	/* Technically SA0 B-copy, reuse for flash-writer */
	b	4f

	/* Flip A-B boot bit again and add it to MFISBTSTSR */
3:	and	w2, w2, #0x01
	eor	w2, w2, #0x01
	lsl	w2, w2, #4
	ldr	x0, =MFISBTSTSR
	ldr	w1, [x0]
	bic	w1, w1, #0x10
	orr	w1, w1, w2
	str	w1, [x0]
	lsr	w2, w2, #4

	ldr	x0, =0x08040000	/* ATF BL2 A-copy offset in RPC HF */

	tbz	w2, 0, 4f	/* if (0x71[0] == 0) then boot A-copy */
	/* Add 8 MiB = 0x0080_0000 offset to boot B-copy */
	orr	x0, x0, #0x00800000

4:	load_copy_size		/* BL2 size */
	ldr	x1, =0xe6304000	/* BL2 destination in SRAM */

5:	ldr	x3, [x0], #8
	str	x3, [x1], #8
	sub	x2, x2, #8
	cbnz	x2, 5b

	/* BOOT NEXT STAGE  */
	ldr	x1, =0xe6304000
	br	x1
9:	b	9b	/* NEVER REACHED */

/* Start the default option */
0:	ldr	x0, =0x08040000	/* ATF BL2 A-copy offset in RPC HF */
	b	3b
