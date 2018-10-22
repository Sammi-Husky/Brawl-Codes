#!A8068AE24
#!THYBRID


.include "common.asm"
.align 3

.set randf,                     0x8003faf8
.set setCharPic,                0x8069742c
.set exchangeCharKindDetail,    0x806948d4
.set initCharKind,              0x80693d18
.set getNumCharColor,           0x800af8d0
.set setStockCharKind,          0x80692498

WRITE_WORD(0x8068ae20, 0x60000000)

_start:
    # Make sure we selected random
    cmpwi   r27, 0x28
    bne     _end
    
    stwu    sp, -0x20(sp)
    mflr    r0
    stw     r0, 0x24(sp)
    call    0x803f130c #savegpr_22

#############################################
##     Randomly select Character ID        ##
#############################################
_randChar:
    lis     r3, 0x805a
    addi    r3, r3, 0x0420
    call    randf
    lis     r4, 0x8068
    lhz     r3, 0x57f2(r4) #<-- Max rand, patched by Custom Random too.
    bl      _floatToInt
    
    lis     r4, 0x8068
    add     r4, r4, r3
    lbz     r4, 0xE80(r4)
    
    mr      r3, r28 #<--Coin OBJ
    call    exchangeCharKindDetail
    
    mr      r4, r3
    mr      r3, r28 #<--Coin OBJ
    call    initCharKind # adjusts CSS ID for special slots

#############################################
##     Randomly select Costume Color       ##
#############################################
    lis     r3, 0x805A
    addi    r3, r3, 0x0420
    call    randf
    lwz     r3, 0x1B8(r28)
    # get how many costums this
    # char has and use it as max
    call    getNumCharColor
    bl      _floatToInt
        
    # Store randomly selected Costume Number
    stw     r3, 0x1BC(r28)
    
#############################################
##       Update the displayed CSP          ##
#############################################
    call    0x803f1358 #restgpr_22
    lwz     r0, 0x24(sp)
    mtlr    r0
    addi    sp, sp, 0x20
    
    mr      r3, r28         #<--Coin OBJ
    lwz     r4, 0x1B8(r28)  #<--CSS ID
    lwz     r5, 0x1B4(r28)  #<--Unknown
    lwz     r6, 0x1BC(r28)  #<--Costume Number
    lwz     r7, 0x1F4(r28)  #<--Unknown
    lbz     r7, 0x5C8(r7)   #<--Unknown
    lwz     r8, 0x1C0(r28)  #<--Unknown
    lbz     r9, 0x1C4(r28)  #<--Unknown
    call    setCharPic # Set CSP
    
#############################################
##   Update the displayed Franchise Icon   ##
#############################################
    lwz     r3, 0x1B8(r28) #<--CSS ID
    call    0x800af82c # exchangeMuSelchkind2GmCharacterKind
    call    0x800af6f0 # exchangeMuStageKindToMsgID
    addi    r3, r3, 1
    bl      _intToFloat
    
    ## Sets the franchise icon ##
    lwz     r3, 0xB8(r28)
    call    0x800b7900 # setFrameTex
    
#############################################
##     Update the displayed Stock Icon     ##
#############################################

    # Make sure we're in a mode withs stock icons
    lwz     r0, 0x3DC(r31) 
    cmpwi   r0, 0
    lwz     r27, 0x1B8(r28)
    beq     _end
    
    lwz     r4, 0x1B8(r28) #<-- CSS ID
    mr      r3, r31
    lwz     r5, 0x1BC(r28) #<-- Costume ID
    call    setStockCharKind
    b       _end
    
_floatToInt:
    stwu    sp, -0x20(sp)
    mflr    r0
    stw     r0, 0x24(sp)
    
    xoris   r0, r3, 0x8000
    stw     r0, 0x0C(sp)
    lis     r26, 0x806A
    lfd     f2, 0x0838(r26)
    lis     r0, 0x4330
    stw     r0, 0x8(sp)
    lfd     f0, 0x8(sp)
    fsubs   f0, f0, f2
    fmuls   f0, f0, f1
    fctiwz  f0, f0
    stfd    f0, 0x10(sp)
    lwz     r3, 0x14(sp)
    
    lwz     r0, 0x24(sp)
    mtlr    r0
    addi    sp, sp, 0x20
    blr
    
_intToFloat:
    stwu    sp, -0x20(sp)
    mflr    r0
    stw     r0, 0x24(sp)
    
    lis     r0, 0x4330
    xoris   r3, r3, 0x8000
    lis     r4, 0x806A
    stw     r3, 0x0C(sp)
    lfd     f1, 0x0EB8(r4)
    stw     r0, 0x08(sp)
    lfd     f0, 0x08(sp)
    fsubs   f1, f0, f1
    
    lwz     r0, 0x24(sp)
    mtlr    r0
    addi    sp, sp, 0x20
    blr
    
_end:
    # C2 Replaced instruction
    mr      r3, r29
    nop
