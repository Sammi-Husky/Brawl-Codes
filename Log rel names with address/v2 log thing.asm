#!A800266C0
#!TC2
.include "lib/common.asm"
.align 3

STACK_SIZE  = 0x80
LR_SAVE     = STACK_SIZE + 0x04
OSReport    = 0x801d8600

# We can create a sort of "psuedo data section" by
# inserting our data here with a BL to our main
# code then grabbing the address from LR
start:
    stwu    r1, -STACK_SIZE(sp)
    mflr    r0
    stw     r0, LR_SAVE(sp)
    bl      main
    # === data start === #
    .int    0xCCCCCCCC
    .string  "<<gfModule>> create Instance (adr:0x%08x  size: 0x%08x text:0x%08x name:%s)\n\0\0\0"
    .int    0xCCCCCCCC
    # ==== data end ==== #
    
main:
    mflr    r3
    addi    r3, r3, 0x4             # our format string
    lis     r7, 0x805bc0c8@h        # address for gfModuleManager's list of loaded modules
    ori     r7, r7, 0x805bc0c8@l
    lwz     r8, 0x0(r4)
    li      r0, 0x0
    _loopStart:                     # Iterate over list and look for a module matching the module ID we are loading
        lwz     r9, 0(r7)           # loadedModules[i]
        cmpwi   r9, 0
        bne     _loaded
        _notLoaded:
            lwz     r9, 0x04(r7)    # not yet loaded but requested to be loaded, rel data at offset 4
            cmpwi   r9, 0
            beq     _nextLoop
            lwz     r9, 0(r9)
            b       _check
        _loaded:
            lwz     r9, 0(r9)       # already loaded, rel data is at offset 0
            lwz     r9, 0(r9)
        _check:
            cmpw    r9, r8
            beq     _loopEnd
    _nextLoop:
        addi    r7, r7, 0x3C        # get next entry in list
        cmpwi   r0, 0x10            # i < 0x10
        addi    r0,r0,1             # i++
        blt     _loopStart
        beq     report
        
    _loopEnd:
        addi    r7, r7, 0x1A        # rel filename is at entry + 0x1A
        
        
report:
    call    OSReport
    
end:
    lwz     r0, LR_SAVE(sp)
    mtlr    r0
    addi    sp, sp, STACK_SIZE
    nop
