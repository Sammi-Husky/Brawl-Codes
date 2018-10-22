#!A805A7E00
#!THYBRID

.include "common.asm"


_start:
    li      r5, 0x67
    addi    r4, r1, 0x20
    lis     r7, 0x805A
    ori     r3, r7, 0x7C09
    bl      strncpy

    li      r5, 0x7F
    subi    r4, r3, 0x9
    addi    r3, r1, 0x20
    bl      strncpy

    li      r5, 0x68
    ori     r4, r7, 0x7C09
    addi    r3, r1, 0x20
    stwu    r1, -128(r1)
    stmw    r2, 8(r1)
    addi    r3, r1, 0x88
    bl      checkSD
    cmpwi   r3, 0
    bne     _disc
  
_sd:
  addi      r3, r1, 0x88
  li        r4, 0
  stw       r4, 0x8(r3)
  bl        readSDFile
  mr        r28, r3
  cmpwi     r3, 0x0
  bne-      _disc
  addi      r1, r1, 0x80
  b         _end

_disc:
  lmw       r2, 8(r1)
  addi      r1, r1, 0x80
  bl        strncpy
  addi      r3, r1, 0x8
  bl        readDVDFile 
  mr        r28, r3

_end:
  b         0x8001c054
