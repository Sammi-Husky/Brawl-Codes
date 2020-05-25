#!A805A7200
#!THYBRID
.include "lib/common.asm"
.align 3

MAKE_JUMPL(0x8007c19c, 0x805A7200) # THPPlayerClose
MAKE_JUMPL(0x8007bf0c, 0x805A7200) # THPPlayerOpenProc
MAKE_JUMPL(0x8007c054, 0x805A7200) # THPPlayerOpenProc

MAKE_JUMPL(0x8007ee08, 0x805A7200) # mvMoviePlayer::closeLastFrameInfo
MAKE_JUMPL(0x8007ef28, 0x805A7200) # mvMoviePlayer::closeLastFrame
MAKE_JUMPL(0x8007eb98, 0x805A7200) # mvMoviePlayer::__dt

.equ g_sdFile, 0x805A74F8
_start:
    stwu    sp, -0x80(sp)
    mflr    r0
    stw     r0, 0x84(sp)
    stmw    r4, 0x08(sp)
    mr      r26, r3
    
    lis     r4, g_sdFile@h
    lwz     r0, g_sdFile@l(r4)
    cmpwi   r0, 0
    beq     _dvd
    
_sdclose:
    lis     r3, g_sdFile@h
    lwz     r3, g_sdFile@l(r3)
    bl      FAFClose
    lis     r4, g_sdFile@h
    stw     r3, g_sdFile@l(r4)
    
_dvd:
    mr      r3, r26
    lmw     r4, 0x08(sp)
    bl      DVDClose

_end:
    lwz     r0, 0x84(sp)
    mtlr    r0
    addi    sp, sp, 0x80
    blr
