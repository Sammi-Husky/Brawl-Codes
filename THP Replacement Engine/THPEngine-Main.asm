#!A805A7500
#!THYBRID
.include "lib/common.asm"
.align 0x3

MAKE_JUMPL(0x8007bea0, 0x805A7500)
MAKE_JUMPL(0x8007bf58, 0x805A7500)
MAKE_JUMPL(0x8007c024, 0x805A7500)
MAKE_JUMPL(0x8007c044, 0x805A7500)

MAKE_JUMPL(0x8007e270, 0x805A7500)
MAKE_JUMPL(0x8007c6ac, 0x805A7500)
MAKE_JUMPL(0x8007c770, 0x805A7500)

MAKE_JUMPL(0x8007ed80, 0x805A7500)
MAKE_JUMPL(0x8007ee84, 0x805A7500)

.equ g_sdFile, 0x805A74F8
_start:
    stwu    sp, -0x30(sp)
    mflr    r0
    stw     r0, 0x34(sp)
    stmw    r26, 0x8(sp) # save all regs
    mr      r26, r3
    mr      r27, r4
    mr      r28, r5
    mr      r29, r6
    mr      r30, r7
    
    lis     r3, g_sdFile@h
    lwz     r3, g_sdFile@l(r3)
    cmpwi   r3, 0
    beq     _disk

_body:
    lis     r3, g_thpFilepath@h     # Currently loaded THP filepath
    ori     r3, r3, g_thpFilepath@l # Currently loaded THP filepath
    mr      r4, r27 # addr
    mr      r5, r28 # size
    mr      r6, r29 # offset
    bl      _sdload # FPC SD Load
    b       _end
    
_disk:
    mr      r3, r26
    mr      r4, r27
    mr      r5, r28
    mr      r6, r29
    mr      r7, r30
    cmpwi   r7, 2
    beq     _sync
    
_async:
    bl      DVDReadAsyncPrio
    b       _end
    
_sync:
    bl      DVDReadPrio
    
_end:
    lmw     r26, 0x08(sp)
    lwz     r0, 0x34(sp)
    addi    sp, sp, 0x30 # restore sp
    mtlr    r0 # original LR
    blr
    

# returns number of bytes read
_sdload:
    stwu    sp, -0x80(sp)
    mflr    r0
    stw     r0, 0x84(sp)
    stmw    r4, 0x08(sp)
    mr      r26, r3 # filepath (TODO: remove)
    mr      r27, r4 # addr
    mr      r28, r5 # size
    mr      r29, r6 # offset
    
    cmpwi   r29, 0
    beq     _sdload_read
    
_sdload_seek:
    lis     r3, g_sdFile@h
    lwz     r3, g_sdFile@l(r3)
    mr      r4, r29
    li      r5, 0 # seek_origin
    bl      FAFSeek
    cmpwi   r3, 0
    bne     _sdload_end
    
_sdload_read:
    mr      r3, r27 # addr
    li      r4, 1 # size of each read
    mr      r5, r28 # length
    lis     r6, g_sdFile@h # File descriptor
    lwz     r6, g_sdFile@l(r6)
    bl      FAFRead
    b       _sdload_end
    
_sdload_end:
    lmw     r4, 0x08(sp)
    lwz     r0, 0x84(sp)
    mtlr    r0
    addi    sp, sp, 0x80
    blr

