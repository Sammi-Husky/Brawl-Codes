##############################################################################################
File Patch Code REDUX v0.77 (/Project+) [Sammi Husky]
##############################################################################################
.alias    _pf               = 0x80507b70
.alias    FPC_PATH          = 0x805a7c00
.alias    MOD_FOLDER        = 0x80406920
.alias    THP_FILEPATH      = 0x8049DDD0

.alias     checkSD          = 0x8001f5a0
.alias     strncpy          = 0x803fa340
.alias     strcpy           = 0x803fa280
.alias     strcat           = 0x803fa384
.alias     FAFStat          = 0x803ebf6c
.alias     FAFOpen          = 0x803ebeb8
.alias     FAFSeek          = 0x803ebee8
.alias     FAFRead          = 0x803ebee4
.alias     FAFClose         = 0x803ebe8c
.alias     DVDClose         = 0x801f6524

.macro lwi(<reg>, <val>)
{
    .alias  temp_Hi = <val> / 0x10000
    .alias  temp_Lo = <val> & 0xFFFF
    lis     <reg>, temp_Hi
    ori     <reg>, <reg>, temp_Lo
}
.macro call(<addr>)
{
  %lwi(r12, <addr>)
  mtctr r12
  bctrl    
}
.macro jump(<addr>)
{
  %lwi(r12, <addr>)
  mtctr r12
  bctr
}
.macro buildPathPF(<filepathRegister>)
{
        %lwi    (r3, FPC_PATH)              # \
        %lwi    (r4, MOD_FOLDER)            # | copy mod patch folder to address where
        li      r5, 0x17                    # | we will build our SD filepath
        %call   (strncpy)                   # /  
        %lwi    (r4, _pf)                   # \ Append /pf to our mod folder
        %call   (strcat)                    # /
        mr      r4, <filepathRegister>
        %call   (strcat)
}

.RESET
* 225664EC 00000000 # only execute if value at 0x805664EC != 0x0 (sd mounted)

string    "/Project+/"      @ $80406920 # Sets path used for SD lookups / reads
string    "pf"              @ $80507b70

#################################################################
#                         MAIN SEGMENT                          #
#################################################################
# Intercepts read requests that would normally go to DVD        #
# and checks if the file exists on SD. If it does, it will      #
# redirect the file to load from the SD card.                   #
#################################################################
HOOK @ $8001BF38
{
    _start:
        mr      r29, r3
        cmpwi   r3, 1 # if DVD
        bne     end
        stwu    r1, -0x90(r1)
        mflr    r0
        stw     r0, 0x94(r1)
        stmw    r4, 0x08(r1)                # | store registers r4 - r31 to stack
        
    _main:
        lwz     r3, 0x0(r28)
        subis   r3, r3, 0x6476              # \
        cmpwi   r3, 0x643A                  # | check if string starts with 'dvd:'
        bne     _skipAdjust                 # | and adjust pointer if it does
        addi    r28, r28, 0x04              # /
    
    _skipAdjust:
        %buildPathPF(r28)
        stw     r3, 0(r30)                  # \
        mr      r3, r30                     # | overwrite string ptr in orignal request and
        %call   (checkSD)                   # | use modified request to check sd for file
        cmpwi   r3, 0                       # /
        bne     _dvd
        mr      r3, r28                     # \
        %lwi    (r4, FPC_PATH)              # | If the file exists, copy our modifed path
        li      r5, 0x80                    # | to the original request's path field.
        %call   (strncpy)                   # | and set request type to SD read.
        li      r3, 3                       # | 
        b       _restore                    # /
    _dvd:
        li      r3, 1                       # \ if file doesn't exist, restore pointer to original
        stw     r28, 0(r30)                 # / path string and set request type to dvd read.
        
    _restore:
        lmw     r4, 0x08(r1)
        lwz     r0, 0x94(r1)
        mtlr    r0
        addi    r1, r1, 0x90
    end:
        mr      r29, r3                     # | original instruction
}

################################################################
#                     GetFileSize patch                          
################################################################
# Description:                                                  
#     force getFileSize to return the size of the file 
#     on the SD card (if it exists), else return size 
#     from the file on disk.
#################################################################
HOOK @ $8001FFF8
{
    _start:
        mr      r28, r3 # original instruction
        stwu    r1, -0x40(r1)
        mflr    r0
        stw     r0, 0x44(r1)  
    _main:
        %buildPathPF(r28)
        addi    r4, r1, 0x08
        %call   (FAFStat)
        cmpwi   r3, 0
        lwz     r3, 0x08(r1)    # get filesize returned from FAFStat
        lwz     r0, 0x44(r1)
        mtlr    r0
        addi    r1, r1, 0x40
        bne     end             # if filesize was zero, use the original size (already in r28)
        mr      r28, r3         # otherwise, overwrite r28 with size from SD
        %jump   (0x80020338)    # branch to the end of getFileSize
    end:
        mr  r3, r28
    
}

################################################################
#                     ReadSD Allocation Fix                          
################################################################                                 
# Description:                                                  
#     Patch game's SDRead function to use the pointer
#     in the request object as destination for loaded
#     data. Allocate new memory if field is zero.
#################################################################
HOOK @ $8001CD0C
{
    _main:
        cmpwi     r3, 0x0       # | does our request object specify a heap to use?
        bne       _doAlloc      # | if yes, allocate new memory with that heap.
        lwz       r3, 0x0C(r24) # | Otherwise, use target load addr from request object.
        b         %END%
    
    _doAlloc:
        %call     (0x80025c58) # gfMemoryPool::alloc
}

################################################################
#                     ReadSD Length Fix                          
################################################################                                 
# Description:                                                  
#     Patch game's SDRead function to use the length
#     field in the request object instead of always
#     reading the full file. If zero, will read entire file.
################################################################
HOOK @ $8001CCB8
{
    _main:
        lwz     r0, 0x8(r24) # check request length field
        cmpwi   r0, 0        # if zero, load full file
        beq     end
        mr      r30, r0      # if non-zero, use as length when reading file
        
    end:
        cmpwi   r30, 0       # original instruction
    
}

################################################################
#                     Custom SDLoad routine                          
################################################################                                 
# Description:                                                  
#     The original FPC provided this utility function
#     to load files from SD. We implement our own for 
#     compatability here, but without the r19/r18 jank.
#################################################################
CODE @ $805A7900
{
    stwu    r1, -128(r1)
    mflr    r0
    stw     r0, 12(r1)
    stmw    r4, 16(r1)
    stwu    r1, -256(r1)
    mr      r7, r4
    li      r4, 0x0
    stw     r5, 12(r1)   # reguest.offset
    stw     r6, 16(r1)   # request.length
    stw     r3, 20(r1)   # request.loadAddress
    stw     r4, 24(r1)   # request.heap
    li      r4, 0xFFFF
    stw     r4, 28(r1)
    addi    r3, r1, 0x20 # request + 0x14
    stw     r3, 8(r1)    # request.pFilepath
    mr      r4, r7
    li      r5, 0x80
    %call   (strncpy)    # copy our filepath to request.filepath
    addi    r3, r1, 0x8
    %call   (0x8001cbf4) # readSDFile
    lwz     r1, 0(r1)
    lmw     r4, 16(r1)
    lwz     r0, 12(r1)
    mtlr    r0
    lwz     r1, 0(r1)
    blr 
}

################################################################
#                     SDStreamOpen                          
################################################################                                 
# @params:
#     r3 = filepath
#     r4 = slotID
# @desc:
#   Opens an SD file for streaming and saves 
#   it to a specific streaming file slot.
#################################################################
.alias      STREAM_FILES        = 0x805a7450
CODE @ $805A7500
{
    start:
        stwu    r1, -0x90(r1)
        mflr    r0
        stw     r0, 0x94(r1)
        stmw    r4, 0x08(r1)
        mr      r26, r3
        mr      r27, r4
        
    _body:
        %buildPathPF(r26)
        %lwi    (r4, 0x8059c590) # open mode = 'r'
        %call   (FAFOpen)
        cmpwi   r3, 0
        beq     _end
        %lwi    (r4, STREAM_FILES)
        mulli   r27, r27, 0x04
        stwx    r3, r27, r4
    _end:
        lmw     r4, 0x08(r1)
        lwz     r0, 0x94(r1)
        mtlr    r0
        addi    r1, r1, 0x90
        blr
}

################################################################
#                     SDStreamRead                          
################################################################                                 
# @params:
#     r3 = slotID
#     r4 = address
#     r5 = length
#     r6 = offset
# @desc:
#   Reads data from a specific stream
#   file slot
#################################################################
CODE @ $805A7700
{
    start:
        stwu    r1, -0x90(r1)
        mflr    r0
        stw     r0, 0x94(r1)
        stmw    r4, 0x08(r1)
        mr      r26, r3
        mr      r27, r4
        mr      r28, r5
        mr      r29, r6
        
        %lwi    (r4, STREAM_FILES)  # \
        mulli   r3, r3, 4           # | Check if specified stream slot is valid
        lwzx    r31, r3, r4         # | 
        cmpwi   r31, 0              # /
        beq     badend
        cmpwi   r29, 0
        beq     _read
        
    _seek:
        mr      r3, r31
        mr      r4, r29
        li      r5, 0 # seek_origin
        %call   (FAFSeek)
        cmpwi   r3, 0
        bne     badend
        
    _read:
        mr      r3, r27 # addr
        li      r4, 1   # size
        mr      r5, r28 # length
        mr      r6, r31 # file descriptor
        %call   (FAFRead)
        b       end
        
    badend:
        li r3, 0
        
    end:
        lmw     r4, 0x08(r1)
        lwz     r0, 0x94(r1)
        mtlr    r0
        addi    r1, r1, 0x90
        blr
}

################################################################
#                     SDStreamClose                          
################################################################                                 
# @params:
#     r3 = slotID
# @desc:
#   Closes a specific SD streaming file
#################################################################
CODE @ $805A7600
{
    start:
        stwu    r1, -0x90(r1)
        mflr    r0
        stw     r0, 0x94(r1)
        stmw    r4, 0x08(r1)
        mr      r31, r3
        %lwi    (r30, STREAM_FILES)
        
    _body:
        lwzx    r3, r3, r30
        cmpwi   r3, 0
        beq     _dvd
        %call   (FAFClose)
        li      r0, 0
        stwx    r0, r31, r30
        b       _end
        
    _dvd:
        mr      r3, r31
        %call   (DVDClose)
        
    _end:
        lmw     r4, 0x08(r1)
        lwz     r0, 0x94(r1)
        mtlr    r0
        addi    r1, r1, 0x90
        blr
    
}

################################################################
#                Read BRSTM Header from SD                          
################################################################                                 
HOOK @ $801CCF90
{
    _start:
        stwu    r1, -0x90(r1)
        mflr    r0
        stw     r0, 0x94(r1)
        li      r3, 1
        mr      r4, r31
        li      r5, 0x4000
        lis     r6, 0
        %call   (0x805a7700) # SDStreamRead
        lwz     r3, 8(r31)
        stw     r3, 0x14(r26)
        stw     r3, 0x5C(r26)
        stw     r3, 0x74(r26)
        
    end:
        lwz     r3, 0(r31)
        lwz     r0, 0x94(r1)
        mtlr    r0
        addi    r1, r1, 0x90
}
################################################################
#                BRSTM SDStreamOpen Wrapper                     
#         NOTE: Automatically closes existing open file
################################################################  
HOOK @ $801beeb8
{
    _start:
        stwu    r1, -0x30(r1)
        mflr    r0
        stw     r0, 0x34(r1)
        stmw    r29, 0x08(r1)
        mr      r31, r3
        mr      r30, r4
        mr      r29, r5
        
    _body:
        mr      r3, r27
        li      r4, 1
        li      r5, 1
        %call   (0x805a7500) # SDStreamOpen
        
    end:
        mr      r3, r31
        mr      r4, r30
        mr      r5, r29
        lmw     r29, 0x08(r1)
        lwz     r0, 0x34(r1)
        mtlr    r0
        addi    r1, r1, 0x30
        mr      r3, r6 # replaced instruction
}
#HOOK @ $801BEEDC
#{
#    _start:
#        stwu    r1, -0x30(r1)
#        mflr    r0
#        stw     r0, 0x34(r1)
#        stmw    r29, 0x08(r1)
#        mr      r31, r3
#        mr      r30, r4
#        mr      r29, r5
#        
#    _body:
#        mr      r3, r27
#        li      r4, 1
#        li      r5, 1
#        %call   (0x805a7500) # SDStreamOpen
#        
#    end:
#        mr      r3, r31
#        mr      r4, r30
#        mr      r5, r29
#        lmw     r29, 0x08(r1)
#        lwz     r0, 0x34(r1)
#        mtlr    r0
#        addi    r1, r1, 0x30
#        mr      r3, r29 # replaced instruction
#}
################################################################
#                BRSTM SDStreamRead Wrapper                          
################################################################
HOOK @ $801CDF84
{
    _start:
        stwu    r1, -0x90(r1)
        mflr    r0
        stw     r0, 0x94(r1)
        stmw    r27, 0x08(r1)
        mr      r31, r3
        mr      r30, r4
        mr      r29, r5
        mr      r28, r6
        mr      r27, r12 # original branch target
        li      r3, 1
        mr      r4, r30
        mr      r5, r29
        mr      r6, r28
        %call   (0x805a7700) # SDStreamRead
        cmpwi   r3, 0
        bne     end
        mr      r3, r31
        mr      r4, r30
        mr      r5, r29
        mr      r6, r28
        mtctr   r27
        bctrl
        
    end:
        lmw     r27, 0x08(r1)
        lwz     r0, 0x94(r1)
        mtlr    r0
        addi    r1, r1, 0x90
}
################################################################
#          gfCollection thread fixes
################################################################                                 
# Description:                                                  
#     Normally the gfCollection threads unmount the
#     SD and idle while they wait for a request. These
#     patches prevent file read errors caused by the
#     unmounting.
#################################################################
op b      0x14     @ $803EE9D8
op b      0x14     @ $803EEBD4 
op b      0x18     @ $803D8B9C
op li     r3, 0    @ $803E9B4C
op li     r3, 0    @ $803E9D38
op NOP             @ $803D8C80

#################################################
#           Remove "RSBX" from SD Path
#################################################
op stb r0, -0x1(r5) @ $8003A430
op NOP				@ $8003A43C
op stb r0, -0x1(r5) @ $8003A8E0
op NOP				@ $8003A8EC
op stb r0, -0x1(r5) @ $8003AF40
op NOP				@ $8003AF4C
op stb r0, -0x1(r5) @ $8003B960
op NOP				@ $8003B96C
op stb r0, -0x1(r5) @ $8003BDDC
op NOP				@ $8003BDE8
op stb r0, -0x1(r5) @ $8003CB1C
op NOP				@ $8003CB28

################################################################
#           pfmenu2 fixes
################################################################                                 
# Description:                                                  
#     These paths are the only ones in the game that
#     lack a leading forward slash. 
#################################################################
string "/menu2/sc_title.pac"     @ $806FF9A0
string "/menu2/mu_menumain.pac"  @ $806FB248
string "/menu2/if_adv_mngr.pac"  @ $80B2C7F8
.RESET