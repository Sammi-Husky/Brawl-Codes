#!A805A7300
#!THYBRID
.include "lib/common.asm"
.align 3

MAKE_JUMPL(0x8007be0c, 0x805A7300) # THPPlayerOpen
MAKE_JUMPL(0x8007ed5c, 0x805A7300) # mvMoviePlayer::loadLastFrameInfo
MAKE_JUMPL(0x8007ee60, 0x805A7300) # mvMoviePlayer::loadLastFrame

.equ g_sdFile, 0x805A74F8
_sdopen:
    # save our context
    stwu    sp, -0x90(sp)
    stmw    r4, 0x08(sp)
    mflr    r0
    stw     r0, 0x94(sp)
    mr      r26, r3 # char* filepath
    mr      r27, r4 # DVDFileInfo*
    
    # allocate some stack space for our read request
    stwu    sp, -0x80(sp)
    mr      r4, r3
    lis     r3, g_fpcPath + 0x18@h     # <------------ CHANGE THIS TO MATCH YOUR FPC
    ori     r3, r3, g_fpcPath + 0x18@l # <------------ CHANGE THIS TO MATCH YOUR FPC
    li      r5, 64
    bl      strncpy
    
    addi    r3, r1, 8
    lis     r4, 0x8059c598@h
    ori     r4, r4, 0x8059c598@l
    bl      0x803fa280 # strcpy
    lis     r4, g_fpcPath+1@h # FPC path
    ori     r4, r4, g_fpcPath+1@l
    li      r5, 0x80
    bl      strncat  
    
    lis     r4, 0x8059c590@h     # open mode = 'r'
    ori     r4, r4, 0x8059c590@l # 
    bl      FAFOpen
    lis     r4, g_sdFile@h
    stw     r3, g_sdFile@l(r4)
    addi    sp, sp, 0x80 # restore sp
    
_end:
    mr      r3, r26
    lmw     r4, 0x08(sp)
    bl      DVDOpen
    lwz     r0, 0x94(sp)
    addi    sp, sp, 0x90
    mtlr    r0 # original LR
    blr
