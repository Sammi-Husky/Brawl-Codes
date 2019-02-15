#!A807854B0
#!TC2


.align 3
.include "common.asm"
.set       getArgList, 0x80782320

_start:
    li      r3, 0x1
    lwz     r10, 104(r28)
    lwz     r9, 116(r10)
    lwz     r8, 120(r10)
    cmpwi   r4, 0x50
    beq-    is_50
    cmpwi   r4, 0x51
    beq-    is_51
    cmpwi   r4, 0x52
    beq-    is_52
    b       _end
####################################
## Button jump or any taunt press ##
####################################
is_50:
    andc    r7, r9, r8
    rlwinm  r6, r7, 0, 19, 21
    rlwinm  r5, r7, 0, 29, 29
    or.     r5, r6, r5
    beq+    _badend
    b       _end
    
###################################
## Button jump or any taunt held ##
###################################
is_51:
    rlwinm  r6, r9, 0, 19, 21
    rlwinm  r5, r9, 0, 29, 29
    or.     r5, r6, r5
    beq+    _badend
    b       _end

###################################
##   Specific Hitbox Connects    ##
###################################
is_52:
    ## Get what our hitbox hit ##
    lwz     r3, 0x00D8(r6)
    lwz     r3, 0x001C(r3)
    lwz     r12, 0(r3)
    lwz     r12, 0x00F8(r12)
    mtctr   r12
    bctrl
    
    ## Get Arg count for requirement ##
    mr        r28, r3
    cmpwi     r28, 0
    beq       _badend
    mr        r4, r27
    addi      r3, sp, 1104
    call      getArgList          #soGeneralTerm.getArgList
    lwz       r12, 0x0450(sp)
    addi      r3, sp, 1104
    lwz       r12, 0x0014(r12)
    mtctr     r12
    bctrl
    
    ## Get requirement arguments ## 
    cmpwi     r3, 1
    bne-      _badend
    lwz       r12, 0x0450(sp)
    addi      r3, sp, 1104
    li        r4, 0
    lwz       r12, 0x0010(r12)
    mtctr     r12
    bctrl

    li        r0, 0
    stw       r3, 0x0038(sp)
    stb       r0, 0x003C(sp)
    lwz       r0, 0x003C(sp)
    stw       r3, 0x0320(sp)
    stw       r0, 0x0324(sp)
    lbz       r0, 0x0324(sp)
    cmplwi    r0, 1
    bne       0x0C
    li        r0, 0
    b         0x08
    lhz       r0, 0x0006(r3)
    
    ## Check we hit what we wanted ##
    and       r3, r28, r0
    neg       r0, r3
    or        r0, r0, r3
    rlwinm    r3, r0, 1, 31, 31
    cmpwi     r3, 1
    bne       _badend

    ## Check hitbox ID ##
    lhz       r0, 0x0C(r5)    #hitbox ID requirement arg
    lwz       r6, 0x524(sp)   #SoModuleAccessor
    lwz       r6, 0xD8(r6)
    lwz       r6, 0x70(r6)    # soStatusModuleImpl
    lbz       r6, 0xA5(r6)    # hitbox ID
    cmpw      r0, r6
    beq       _end
    
_badend:
    li r3, 0x0

_end:
    nop