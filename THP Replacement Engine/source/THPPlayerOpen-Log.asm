#!A8007BE08
#!TC2
.include "lib/common.asm"
.align 3

.equ    OSReport, 0x801d8600
.equ    g_thpFmt, 0x805A74DF
_start:
    stwu    sp, -0x20(sp)
    mflr    r0
    stw     r0, 0x24(sp)
    stw     r31, 0x1C(sp)
    stw     r30, 0x18(sp)
    mr      r31, r3
    mr      r30, r4
    lis     r3, g_thpFmt@h
    ori     r3, r3, g_thpFmt@l
    mr      r4, r31
    call    OSReport
    mr      r3, r31
    mr      r4, r30
    lwz     r0, 0x24(sp)
    lwz     r31, 0x1c(sp)
    lwz     r30, 0x18(sp)
    mtlr    r0
    addi    sp, sp, 0x20
    mr      r4, r31 # replaced instruction
    nop
