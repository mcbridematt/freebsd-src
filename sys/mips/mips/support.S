/*	$OpenBSD: locore.S,v 1.18 1998/09/15 10:58:53 pefo Exp $	*/
/*-
 * Copyright (c) 1992, 1993
 *	The Regents of the University of California.  All rights reserved.
 *
 * This code is derived from software contributed to Berkeley by
 * Digital Equipment Corporation and Ralph Campbell.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 4. Neither the name of the University nor the names of its contributors
 *    may be used to endorse or promote products derived from this software
 *    without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 *
 * Copyright (C) 1989 Digital Equipment Corporation.
 * Permission to use, copy, modify, and distribute this software and
 * its documentation for any purpose and without fee is hereby granted,
 * provided that the above copyright notice appears in all copies.
 * Digital Equipment Corporation makes no representations about the
 * suitability of this software for any purpose.  It is provided "as is"
 * without express or implied warranty.
 *
 * from: Header: /sprite/src/kernel/mach/ds3100.md/RCS/loMem.s,
 *	v 1.1 89/07/11 17:55:04 nelson Exp  SPRITE (DECWRL)
 * from: Header: /sprite/src/kernel/mach/ds3100.md/RCS/machAsm.s,
 *	v 9.2 90/01/29 18:00:39 shirriff Exp  SPRITE (DECWRL)
 * from: Header: /sprite/src/kernel/vm/ds3100.md/vmPmaxAsm.s,
 *	v 1.1 89/07/10 14:27:41 nelson Exp  SPRITE (DECWRL)
 *
 *	from: @(#)locore.s	8.5 (Berkeley) 1/4/94
 *	JNPR: support.S,v 1.5.2.2 2007/08/29 10:03:49 girish
 * $FreeBSD$
 */

/*
 * Copyright (c) 1997 Jonathan Stone (hereinafter referred to as the author)
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. All advertising materials mentioning features or use of this software
 *    must display the following acknowledgement:
 *      This product includes software developed by Jonathan R. Stone for
 *      the NetBSD Project.
 * 4. The name of the author may not be used to endorse or promote products
 *    derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

/*
 *	Contains assembly language support routines.
 */

#include "opt_ddb.h"
#include <sys/errno.h>
#include <machine/asm.h>
#include <machine/cpu.h>
#include <machine/endian.h>
#include <machine/regnum.h>
#include <machine/cpuregs.h>
#include <machine/pcb.h>

#include "assym.inc"

	.set	noreorder		# Noreorder is default style!

/*
 * Primitives
 */

	.text

/*
 * Copy a null terminated string from the user address space into
 * the kernel address space.
 *
 *	copyinstr(fromaddr, toaddr, maxlength, &lencopied)
 *		caddr_t fromaddr;
 *		caddr_t toaddr;
 *		u_int maxlength;
 *		u_int *lencopied;
 */
LEAF(copyinstr)
	PTR_LA		v0, __copyinstr_err
	blt		a0, zero, __copyinstr_err  # make sure address is in user space
	GET_CPU_PCPU(v1)
	PTR_L		v1, PC_CURPCB(v1)
	PTR_S		v0, U_PCB_ONFAULT(v1)

	move		t0, a2
	beq		a2, zero, 4f
1:
	lbu		v0, 0(a0)
	PTR_SUBU	a2, a2, 1
	beq		v0, zero, 2f
	sb		v0, 0(a1)		# each byte until NIL
	PTR_ADDU	a0, a0, 1
	bne		a2, zero, 1b		# less than maxlen
	PTR_ADDU	a1, a1, 1
4:
	li		v0, ENAMETOOLONG	# run out of space
2:
	beq		a3, zero, 3f		# return num. of copied bytes
	PTR_SUBU	a2, t0, a2		# if the 4th arg was non-NULL
	PTR_S		a2, 0(a3)
3:

	PTR_S		zero, U_PCB_ONFAULT(v1)
	j		ra
	nop

__copyinstr_err:
	j		ra
	li		v0, EFAULT
END(copyinstr)

/*
 * Copy specified amount of data from user space into the kernel
 *	copyin(from, to, len)
 *		caddr_t *from;	(user source address)
 *		caddr_t *to;	(kernel destination address)
 *		unsigned len;
 */
NESTED(copyin, CALLFRAME_SIZ, ra)
	PTR_SUBU	sp, sp, CALLFRAME_SIZ
	.mask	0x80000000, (CALLFRAME_RA - CALLFRAME_SIZ)
	PTR_LA	v0, copyerr
	blt	a0, zero, _C_LABEL(copyerr)  # make sure address is in user space
	REG_S	ra, CALLFRAME_RA(sp)
	GET_CPU_PCPU(v1)
	PTR_L	v1, PC_CURPCB(v1)
	jal	_C_LABEL(bcopy)
	PTR_S	v0, U_PCB_ONFAULT(v1)
	REG_L	ra, CALLFRAME_RA(sp)
	GET_CPU_PCPU(v1)
	PTR_L	v1, PC_CURPCB(v1)	 	# bcopy modified v1, so reload
	PTR_S	zero, U_PCB_ONFAULT(v1)
	PTR_ADDU	sp, sp, CALLFRAME_SIZ
	j	ra
	move	v0, zero
END(copyin)

/*
 * Copy specified amount of data from kernel to the user space
 *	copyout(from, to, len)
 *		caddr_t *from;	(kernel source address)
 *		caddr_t *to;	(user destination address)
 *		unsigned len;
 */
NESTED(copyout, CALLFRAME_SIZ, ra)
	PTR_SUBU	sp, sp, CALLFRAME_SIZ
	.mask	0x80000000, (CALLFRAME_RA - CALLFRAME_SIZ)
	PTR_LA	v0, copyerr
	blt	a1, zero, _C_LABEL(copyerr) # make sure address is in user space
	REG_S	ra, CALLFRAME_RA(sp)
	GET_CPU_PCPU(v1)
	PTR_L	v1, PC_CURPCB(v1)
	jal	_C_LABEL(bcopy)
	PTR_S	v0, U_PCB_ONFAULT(v1)
	REG_L	ra, CALLFRAME_RA(sp)
	GET_CPU_PCPU(v1)
	PTR_L	v1, PC_CURPCB(v1)	 	# bcopy modified v1, so reload
	PTR_S	zero, U_PCB_ONFAULT(v1)
	PTR_ADDU	sp, sp, CALLFRAME_SIZ
	j	ra
	move	v0, zero
END(copyout)

LEAF(copyerr)
	REG_L	ra, CALLFRAME_RA(sp)
	PTR_ADDU	sp, sp, CALLFRAME_SIZ
	j	ra
	li	v0, EFAULT			# return error
END(copyerr)

/*
 * {fu,su},{byte,sword,word}, fetch or store a byte, short or word to
 * user-space.
 */
#ifdef __mips_n64
LEAF(fueword64)
XLEAF(fueword)
	PTR_LA	v0, fswberr
	blt	a0, zero, fswberr	# make sure address is in user space
	nop
	GET_CPU_PCPU(v1)
	PTR_L	v1, PC_CURPCB(v1)
	PTR_S	v0, U_PCB_ONFAULT(v1)
	ld	v0, 0(a0)		# fetch word
	PTR_S	zero, U_PCB_ONFAULT(v1)
	sd	v0, 0(a1)		# store word
	j	ra
	li	v0, 0
END(fueword64)
#endif

LEAF(fueword32)
#ifndef __mips_n64
XLEAF(fueword)
#endif
	PTR_LA	v0, fswberr
	blt	a0, zero, fswberr	# make sure address is in user space
	nop
	GET_CPU_PCPU(v1)
	PTR_L	v1, PC_CURPCB(v1)
	PTR_S	v0, U_PCB_ONFAULT(v1)
	lw	v0, 0(a0)		# fetch word
	PTR_S	zero, U_PCB_ONFAULT(v1)
	sw	v0, 0(a1)		# store word
	j	ra
	li	v0, 0
END(fueword32)

LEAF(fuesword)
	PTR_LA	v0, fswberr
	blt	a0, zero, fswberr	# make sure address is in user space
	nop
	GET_CPU_PCPU(v1)
	PTR_L	v1, PC_CURPCB(v1)
	PTR_S	v0, U_PCB_ONFAULT(v1)
	lhu	v0, 0(a0)		# fetch short
	PTR_S	zero, U_PCB_ONFAULT(v1)
	sh	v0, 0(a1)		# store short
	j	ra
	li	v0, 0
END(fuesword)

LEAF(fubyte)
	PTR_LA	v0, fswberr
	blt	a0, zero, fswberr	# make sure address is in user space
	nop
	GET_CPU_PCPU(v1)
	PTR_L	v1, PC_CURPCB(v1)
	PTR_S	v0, U_PCB_ONFAULT(v1)
	lbu	v0, 0(a0)		# fetch byte
	j	ra
	PTR_S	zero, U_PCB_ONFAULT(v1)
END(fubyte)

LEAF(suword32)
#ifndef __mips_n64
XLEAF(suword)
#endif
	PTR_LA	v0, fswberr
	blt	a0, zero, fswberr	# make sure address is in user space
	nop
	GET_CPU_PCPU(v1)
	PTR_L	v1, PC_CURPCB(v1)
	PTR_S	v0, U_PCB_ONFAULT(v1)
	sw	a1, 0(a0)		# store word
	PTR_S	zero, U_PCB_ONFAULT(v1)
	j	ra
	move	v0, zero
END(suword32)

#ifdef __mips_n64
LEAF(suword64)
XLEAF(suword)
	PTR_LA	v0, fswberr
	blt	a0, zero, fswberr	# make sure address is in user space
	nop
	GET_CPU_PCPU(v1)
	PTR_L	v1, PC_CURPCB(v1)
	PTR_S	v0, U_PCB_ONFAULT(v1)
	sd	a1, 0(a0)		# store word
	PTR_S	zero, U_PCB_ONFAULT(v1)
	j	ra
	move	v0, zero
END(suword64)
#endif

/*
 * casueword(9)
 * <v0>u_long casueword(<a0>u_long *p, <a1>u_long oldval, <a2>u_long *oldval_p,
 *		       <a3>u_long newval)
 */
/*
 * casueword32(9)
 * <v0>uint32_t casueword(<a0>uint32_t *p, <a1>uint32_t oldval,
 *			 <a2>uint32_t newval)
 */
LEAF(casueword32)
#ifndef __mips_n64
XLEAF(casueword)
#endif
	PTR_LA	v0, fswberr
	blt	a0, zero, fswberr	# make sure address is in user space
	nop
	GET_CPU_PCPU(v1)
	PTR_L	v1, PC_CURPCB(v1)
	PTR_S	v0, U_PCB_ONFAULT(v1)

	li	v0, 1
	move	t0, a3
	ll	t1, 0(a0)
	bne	a1, t1, 1f
	nop
	sc	t0, 0(a0)		# store word
	xori	v0, t0, 1
1:
	PTR_S	zero, U_PCB_ONFAULT(v1)
	jr	ra
	sw	t1, 0(a2)		# unconditionally store old word
END(casueword32)

#ifdef __mips_n64
LEAF(casueword64)
XLEAF(casueword)
	PTR_LA	v0, fswberr
	blt	a0, zero, fswberr	# make sure address is in user space
	nop
	GET_CPU_PCPU(v1)
	PTR_L	v1, PC_CURPCB(v1)
	PTR_S	v0, U_PCB_ONFAULT(v1)

	li	v0, 1
	move	t0, a3
	lld	t1, 0(a0)
	bne	a1, t1, 1f
	nop
	scd	t0, 0(a0)		# store double word
	xori	v0, t0, 1
1:
	PTR_S	zero, U_PCB_ONFAULT(v1)
	jr	ra
	sd	t1, 0(a2)		# unconditionally store old word
END(casueword64)
#endif

/*
 * Will have to flush the instruction cache if byte merging is done in hardware.
 */
LEAF(susword)
	PTR_LA	v0, fswberr
	blt	a0, zero, fswberr	# make sure address is in user space
	nop
	GET_CPU_PCPU(v1)
	PTR_L	v1, PC_CURPCB(v1)
	PTR_S	v0, U_PCB_ONFAULT(v1)
	sh	a1, 0(a0)		# store short
	PTR_S	zero, U_PCB_ONFAULT(v1)
	j	ra
	move	v0, zero
END(susword)

LEAF(subyte)
	PTR_LA	v0, fswberr
	blt	a0, zero, fswberr	# make sure address is in user space
	nop
	GET_CPU_PCPU(v1)
	PTR_L	v1, PC_CURPCB(v1)
	PTR_S	v0, U_PCB_ONFAULT(v1)
	sb	a1, 0(a0)		# store byte
	PTR_S	zero, U_PCB_ONFAULT(v1)
	j	ra
	move	v0, zero
END(subyte)

LEAF(fswberr)
	j	ra
	li	v0, -1
END(fswberr)

/*
 * memset(void *s1, int c, int len)
 * NetBSD: memset.S,v 1.3 2001/10/16 15:40:53 uch Exp
 */
LEAF(memset)
	.set noreorder
	blt	a2, 12, memsetsmallclr	# small amount to clear?
	move	v0, a0			# save s1 for result

	sll	t1, a1, 8		# compute  c << 8 in t1
	or	t1, t1, a1		# compute c << 8 | c in 11
	sll	t2, t1, 16		# shift that left 16
	or	t1, t2, t1		# or together

	PTR_SUBU	t0, zero, a0		# compute # bytes to word align address
	and	t0, t0, 3
	beq	t0, zero, 1f		# skip if word aligned
	PTR_SUBU	a2, a2, t0		# subtract from remaining count
	SWHI	t1, 0(a0)		# store 1, 2, or 3 bytes to align
	PTR_ADDU	a0, a0, t0
1:
	and	v1, a2, 3		# compute number of whole words left
	PTR_SUBU	t0, a2, v1
	PTR_SUBU	a2, a2, t0
	PTR_ADDU	t0, t0, a0		# compute ending address
2:
	PTR_ADDU	a0, a0, 4		# clear words
	bne	a0, t0, 2b		#  unrolling loop does not help
	sw	t1, -4(a0)		#  since we are limited by memory speed

memsetsmallclr:
	ble	a2, zero, 2f
	PTR_ADDU	t0, a2, a0		# compute ending address
1:
	PTR_ADDU	a0, a0, 1		# clear bytes
	bne	a0, t0, 1b
	sb	a1, -1(a0)
2:
	j	ra
	nop
	.set reorder
END(memset)

/*
 * blkclr(s1, n)
 */
LEAF(blkclr)
	.set	noreorder
	blt	a1, 12, smallclr	# small amount to clear?
	PTR_SUBU	a3, zero, a0		# compute # bytes to word align address
	and	a3, a3, 3
	beq	a3, zero, 1f		# skip if word aligned
	PTR_SUBU	a1, a1, a3		# subtract from remaining count
	SWHI	zero, 0(a0)		# clear 1, 2, or 3 bytes to align
	PTR_ADDU	a0, a0, a3
1:
	and	v0, a1, 3		# compute number of words left
	PTR_SUBU	a3, a1, v0
	move	a1, v0
	PTR_ADDU	a3, a3, a0		# compute ending address
2:
	PTR_ADDU	a0, a0, 4		# clear words
	bne	a0, a3, 2b		#  unrolling loop does not help
	sw	zero, -4(a0)		#  since we are limited by memory speed
smallclr:
	ble	a1, zero, 2f
	PTR_ADDU	a3, a1, a0		# compute ending address
1:
	PTR_ADDU	a0, a0, 1		# clear bytes
	bne	a0, a3, 1b
	sb	zero, -1(a0)
2:
	j	ra
	nop
END(blkclr)

/*
 * bit = ffs(value)
 */
LEAF(ffs)
	.set	noreorder
	beq	a0, zero, 2f
	move	v0, zero
1:
	and	v1, a0, 1		# bit set?
	addu	v0, v0, 1
	beq	v1, zero, 1b		# no, continue
	srl	a0, a0, 1
2:
	j	ra
	nop
END(ffs)

/**
 * void
 * atomic_set_16(u_int16_t *a, u_int16_t b)
 * {
 *	*a |= b;
 * }
 */
LEAF(atomic_set_16)
	.set	noreorder
	/* NB: Only bit 1 is masked so the ll catches unaligned inputs */
	andi	t0, a0, 2	# get unaligned offset
	xor	a0, a0, t0	# align pointer
#if _BYTE_ORDER == BIG_ENDIAN
	xori	t0, t0, 2
#endif
	sll	t0, t0, 3	# convert byte offset to bit offset
	sll	a1, a1, t0	# put bits in the right half
1:
	ll	t0, 0(a0)
	or	t0, t0, a1
	sc	t0, 0(a0)
	beq	t0, zero, 1b
	nop
	j	ra
	nop
END(atomic_set_16)

/**
 * void
 * atomic_clear_16(u_int16_t *a, u_int16_t b)
 * {
 *	*a &= ~b;
 * }
 */
LEAF(atomic_clear_16)
	.set	noreorder
	/* NB: Only bit 1 is masked so the ll catches unaligned inputs */
	andi	t0, a0, 2	# get unaligned offset
	xor	a0, a0, t0	# align pointer
#if _BYTE_ORDER == BIG_ENDIAN
	xori	t0, t0, 2
#endif
	sll	t0, t0, 3	# convert byte offset to bit offset
	sll	a1, a1, t0	# put bits in the right half
	not	a1, a1
1:
	ll	t0, 0(a0)
	and	t0, t0, a1
	sc	t0, 0(a0)
	beq	t0, zero, 1b
	nop
	j	ra
	nop
END(atomic_clear_16)


/**
 * void
 * atomic_subtract_16(uint16_t *a, uint16_t b)
 * {
 *	*a -= b;
 * }
 */
LEAF(atomic_subtract_16)
	.set	noreorder
	/* NB: Only bit 1 is masked so the ll catches unaligned inputs */
	andi	t0, a0, 2	# get unaligned offset
	xor	a0, a0, t0	# align pointer
#if _BYTE_ORDER == BIG_ENDIAN
	xori	t0, t0, 2	# flip order for big-endian
#endif
	sll	t0, t0, 3	# convert byte offset to bit offset
	sll	a1, a1, t0	# put bits in the right half
	li	t2, 0xffff
	sll	t2, t2, t0	# compute mask
1:
	ll	t0, 0(a0)
	subu	t1, t0, a1
	/* Exploit ((t0 & ~t2) | (t1 & t2)) = t0 ^ ((t0 ^ t1) & t2) */
	xor	t1, t0, t1
	and	t1, t1, t2
	xor	t0, t0, t1
	sc	t0, 0(a0)
	beq	t0, zero, 1b
	nop
	j	ra
	nop
END(atomic_subtract_16)

/**
 * void
 * atomic_add_16(uint16_t *a, uint16_t b)
 * {
 *	*a += b;
 * }
 */
LEAF(atomic_add_16)
	.set	noreorder
	/* NB: Only bit 1 is masked so the ll catches unaligned inputs */
	andi	t0, a0, 2	# get unaligned offset
	xor	a0, a0, t0	# align pointer
#if _BYTE_ORDER == BIG_ENDIAN
	xori	t0, t0, 2	# flip order for big-endian
#endif
	sll	t0, t0, 3	# convert byte offset to bit offset
	sll	a1, a1, t0	# put bits in the right half
	li	t2, 0xffff
	sll	t2, t2, t0	# compute mask
1:
	ll	t0, 0(a0)
	addu	t1, t0, a1
	/* Exploit ((t0 & ~t2) | (t1 & t2)) = t0 ^ ((t0 ^ t1) & t2) */
	xor	t1, t0, t1
	and	t1, t1, t2
	xor	t0, t0, t1
	sc	t0, 0(a0)
	beq	t0, zero, 1b
	nop
	j	ra
	nop
END(atomic_add_16)

/**
 * void
 * atomic_add_8(uint8_t *a, uint8_t b)
 * {
 *	*a += b;
 * }
 */
LEAF(atomic_add_8)
	.set	noreorder
	andi	t0, a0, 3	# get unaligned offset
	xor	a0, a0, t0	# align pointer
#if _BYTE_ORDER == BIG_ENDIAN
	xori	t0, t0, 3	# flip order for big-endian
#endif
	sll	t0, t0, 3	# convert byte offset to bit offset
	sll	a1, a1, t0	# put bits in the right quarter
	li	t2, 0xff
	sll	t2, t2, t0	# compute mask
1:
	ll	t0, 0(a0)
	addu	t1, t0, a1
	/* Exploit ((t0 & ~t2) | (t1 & t2)) = t0 ^ ((t0 ^ t1) & t2) */
	xor	t1, t0, t1
	and	t1, t1, t2
	xor	t0, t0, t1
	sc	t0, 0(a0)
	beq	t0, zero, 1b
	nop
	j	ra
	nop
END(atomic_add_8)


/**
 * void
 * atomic_subtract_8(uint8_t *a, uint8_t b)
 * {
 *	*a += b;
 * }
 */
LEAF(atomic_subtract_8)
	.set	noreorder
	andi	t0, a0, 3	# get unaligned offset
	xor	a0, a0, t0	# align pointer
#if _BYTE_ORDER == BIG_ENDIAN
	xori	t0, t0, 3	# flip order for big-endian
#endif
	sll	t0, t0, 3	# convert byte offset to bit offset
	sll	a1, a1, t0	# put bits in the right quarter
	li	t2, 0xff
	sll	t2, t2, t0	# compute mask
1:
	ll	t0, 0(a0)
	subu	t1, t0, a1
	/* Exploit ((t0 & ~t2) | (t1 & t2)) = t0 ^ ((t0 ^ t1) & t2) */
	xor	t1, t0, t1
	and	t1, t1, t2
	xor	t0, t0, t1
	sc	t0, 0(a0)
	beq	t0, zero, 1b
	nop
	j	ra
	nop
END(atomic_subtract_8)

	.set	noreorder		# Noreorder is default style!

#if defined(DDB) || defined(DEBUG)

LEAF(kdbpeek)
	PTR_LA	v1, ddberr
	and	v0, a0, 3			# unaligned ?
	GET_CPU_PCPU(t1)
	PTR_L	t1, PC_CURPCB(t1)
	bne	v0, zero, 1f
	PTR_S	v1, U_PCB_ONFAULT(t1)

	lw	v0, (a0)
	jr	ra
	PTR_S	zero, U_PCB_ONFAULT(t1)

1:
	LWHI	v0, 0(a0)
	LWLO	v0, 3(a0)
	jr	ra
	PTR_S	zero, U_PCB_ONFAULT(t1)
END(kdbpeek)

LEAF(kdbpeekd)
	PTR_LA	v1, ddberr
	and	v0, a0, 3			# unaligned ?
	GET_CPU_PCPU(t1)
	PTR_L	t1, PC_CURPCB(t1)
	bne	v0, zero, 1f
	PTR_S	v1, U_PCB_ONFAULT(t1)

	ld	v0, (a0)
	jr	ra
	PTR_S	zero, U_PCB_ONFAULT(t1)

1:
	REG_LHI	v0, 0(a0)
	REG_LLO	v0, 7(a0)
	jr	ra
	PTR_S	zero, U_PCB_ONFAULT(t1)
END(kdbpeekd)

ddberr:
	jr	ra
	nop

#if defined(DDB)
LEAF(kdbpoke)
	PTR_LA	v1, ddberr
	and	v0, a0, 3			# unaligned ?
	GET_CPU_PCPU(t1)
	PTR_L	t1, PC_CURPCB(t1)
	bne	v0, zero, 1f
	PTR_S	v1, U_PCB_ONFAULT(t1)

	sw	a1, (a0)
	jr	ra
	PTR_S	zero, U_PCB_ONFAULT(t1)

1:
	SWHI	a1, 0(a0)
	SWLO	a1, 3(a0)
	jr	ra
	PTR_S	zero, U_PCB_ONFAULT(t1)
END(kdbpoke)

	.data
	.globl	esym
esym:	.word	0

#endif /* DDB */
#endif /* DDB || DEBUG */

	.text
LEAF(breakpoint)
	break	MIPS_BREAK_SOVER_VAL
	jr	ra
	nop
END(breakpoint)

LEAF(setjmp)
	mfc0	v0, MIPS_COP_0_STATUS	# Later the "real" spl value!
	REG_S	s0, (SZREG * PCB_REG_S0)(a0)
	REG_S	s1, (SZREG * PCB_REG_S1)(a0)
	REG_S	s2, (SZREG * PCB_REG_S2)(a0)
	REG_S	s3, (SZREG * PCB_REG_S3)(a0)
	REG_S	s4, (SZREG * PCB_REG_S4)(a0)
	REG_S	s5, (SZREG * PCB_REG_S5)(a0)
	REG_S	s6, (SZREG * PCB_REG_S6)(a0)
	REG_S	s7, (SZREG * PCB_REG_S7)(a0)
	REG_S	s8, (SZREG * PCB_REG_S8)(a0)
	REG_S	sp, (SZREG * PCB_REG_SP)(a0)
	REG_S	ra, (SZREG * PCB_REG_RA)(a0)
	REG_S	v0, (SZREG * PCB_REG_SR)(a0)
	jr	ra
	li	v0, 0			# setjmp return
END(setjmp)

LEAF(longjmp)
	REG_L	v0, (SZREG * PCB_REG_SR)(a0)
	REG_L	ra, (SZREG * PCB_REG_RA)(a0)
	REG_L	s0, (SZREG * PCB_REG_S0)(a0)
	REG_L	s1, (SZREG * PCB_REG_S1)(a0)
	REG_L	s2, (SZREG * PCB_REG_S2)(a0)
	REG_L	s3, (SZREG * PCB_REG_S3)(a0)
	REG_L	s4, (SZREG * PCB_REG_S4)(a0)
	REG_L	s5, (SZREG * PCB_REG_S5)(a0)
	REG_L	s6, (SZREG * PCB_REG_S6)(a0)
	REG_L	s7, (SZREG * PCB_REG_S7)(a0)
	REG_L	s8, (SZREG * PCB_REG_S8)(a0)
	REG_L	sp, (SZREG * PCB_REG_SP)(a0)
	mtc0	v0, MIPS_COP_0_STATUS	# Later the "real" spl value!
	ITLBNOPFIX
	jr	ra
	li	v0, 1			# longjmp return
END(longjmp)
