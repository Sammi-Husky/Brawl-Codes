##############################################################################################
File Patch Code REDUX v0.80 (/Project+) [Sammi Husky]
##############################################################################################
.alias _pf               = 0x80507b70
.alias FPC_PATH          = 0x805a7c00
.alias MOD_FOLDER        = 0x80406920
.alias THP_FILEPATH      = 0x8049DDD0

.alias checkSD          = 0x8001f5a0
.alias strncpy          = 0x803fa340
.alias strcpy           = 0x803fa280
.alias strcat           = 0x803fa384
.alias FAFStat          = 0x803ebf6c
.alias FAFOpen          = 0x803ebeb8
.alias FAFSeek          = 0x803ebee8
.alias FAFRead          = 0x803ebee4
.alias FAFClose         = 0x803ebe8c
.alias DVDClose         = 0x801f6524
.alias DVDOpen          = 0x801f6278
.alias DVDReadPrio      = 0x801f67f0
.alias DVDReadAsyncPrio = 0x801f6708
.alias OSReport         = 0x801d8600

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
.macro FPCPath(<stackOffset>, <filepathRegister>)
{
		addi	r3, sp, <stackOffset> 		# \     
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

string    "/Project+/"                          @ $80406920 # Sets path used for SD lookups / reads
string    "pf"                                  @ $80507b70
string    "SDStreamOpen (slot:%d): %s"          @ $80507b80
uint8_t   0xA                                   @ $80507b9a
string    "SDStreamOpen Failed: %s"             @ $80507ba0
uint8_t   0xA                                   @ $80507bb7


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
    cmpwi   r3, 1 # if DVD
    bne     end
    stwu    r1, -0x100(r1)
    mflr    r0
    stw     r0, 0x104(r1)
    stmw    r4, 0x88(r1)                # | store registers r4 - r31 to stack
    
_main:
    lwz     r29, 0x0(r30)               # | r30 contains pointer to request object
    lwz     r3, 0(r29)                  # | load first 4 characters of path string
    subis   r3, r3, 0x6476              # \
    cmpwi   r3, 0x643A                  # | check if string starts with 'dvd:'
    bne     _skipAdjust                 # | and adjust pointer if it does
    addi    r28, r28, 0x04              # / use r28 for modified path pointer

_skipAdjust:
    %FPCPath(0x08, r28)
    stw     r3, 0(r30)                  # \
    mr      r3, r30                     # | overwrite string ptr in orignal request and
    %call   (checkSD)                   # | use modified request to check sd for file
    cmpwi   r3, 0                       # /
    bne     _dvd
    mr      r3, r29                     # \ copy new string to unadjusted pointer
    %lwi    (r4, FPC_PATH)              # | If the file exists, copy our modifed path
    li      r5, 0x7f                    # | to the original request's path field.
    %call   (strncpy)                   # | and set request type to SD read.
    li      r3, 3                       # | 
    b       _restore                    # /
_dvd:
    li      r3, 1                       # \ if file doesn't exist, restore pointer to original
    stw     r29, 0(r30)                 # / path string and set request type to dvd read.
    
_restore:
    lmw     r4, 0x88(r1)
    lwz     r0, 0x104(r1)
    mtlr    r0
    addi    r1, r1, 0x100
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
    stwu    r1, -0xA0(r1)
    mflr    r0
    stw     r0, 0xA4(r1)  
_main:
    %FPCPath(0x08, r28)
    addi    r4, r1, 0x90
    %call   (FAFStat)
    cmpwi   r3, 0
    lwz     r3, 0x90(r1)    # get filesize returned from FAFStat
    addi    r3, r3, 0x1f
    rlwinm  r3, r3, 0, 0, 26
    lwz     r0, 0xA4(r1)
    mtlr    r0
    addi    r1, r1, 0xA0
    bne     _end            # if filesize was zero, use the original size (already in r28)
    mr      r28, r3         # otherwise, overwrite r28 with size from SD
    %jump   (0x80020338)    # branch to the end of getFileSize
_end:
    mr      r3, r28
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

#################################################################
##                     ReadSD Length Fix                          
#################################################################                                 
## Description:                                                  
##     Patch game's SDRead function to use the length
##     field in the request object instead of always
##     reading the full file. If zero, will read entire file.
#################################################################
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
.alias STREAM_FILES        = 0x805a7450
.alias SDStreamOpen        = 0x805a7500
.alias SDStreamRead        = 0x805a7700
.alias SDStreamClose       = 0x805a7600
CODE @ $805A7500
{
start:
    stwu    r1, -0x100(r1)
    mflr    r0
    stw     r0, 0x104(r1)
    stmw    r4, 0x88(r1)
    mr      r26, r3
    mr      r27, r4
    
_body:
    %FPCPath(0x08, r26)
    mr      r30, r3
    %lwi    (r4, 0x8059c590) # open mode = 'r'
    %call   (FAFOpen)
    cmpwi   r3, 0
    beq     _failed
    %lwi    (r4, STREAM_FILES)
    mulli   r28, r27, 0x04
    stwx    r3, r28, r4
    mr      r29, r3
    %lwi    (r3, 0x80507b80)    # format string for SDStreamOpen success
    mr      r4, r27
    mr      r5, r30
    %call   (OSReport)
    mr      r3, r29
    b       _end
_failed:
    %lwi    (r3, 0x80507ba0)    # format string for SDStreamOpen failed
    mr      r4, r30
    %call   (OSReport)
    li      r3, 0
_end:
    lmw     r4, 0x88(r1)
    lwz     r0, 0x104(r1)
    mtlr    r0
    addi    r1, r1, 0x100
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
    
_body:
    %lwi    (r30, STREAM_FILES)
    mulli   r31, r31, 4
    lwzx    r3, r31, r30
    cmpwi   r3, 0
    beq     _badend
    %call   (FAFClose)
    li      r0, 0
    stwx    r0, r31, r30

_badend:
    li      r3,  -1

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
    li      r3, 1           # slot
    mr      r4, r31         # address
    li      r5, 0x4000      # length
    lis     r6, 0           # offset
    %call   (SDStreamRead)
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
HOOK @ $801c6ce4
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
    li      r3, 1           # \ Close existing BRSTM file if still open
    %call   (SDStreamClose) # /
    mr      r3, r31         # \ filename
    li      r4, 1           # | slot
    %call   (SDStreamOpen)  # /
    
end:
    mr      r3, r31         # \
    mr      r4, r30         # | Restore registers and return
    mr      r5, r29         # /
    lmw     r29, 0x08(r1)
    lwz     r0, 0x34(r1)
    mtlr    r0
    addi    r1, r1, 0x30
    addi    r27, r1, 0x150  # replaced instruction
}
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
    mr      r27, r12    # save original branch target

    li      r3, 1       # slot
    mr      r4, r30     # address
    mr      r5, r29     # length
    mr      r6, r28     # offset
    %call   (SDStreamRead)
    cmpwi   r3, 0       # if successfull, branch to end
    bne     end
    mr      r3, r31     # \
    mr      r4, r30     # | Otherwise, put original branch target
    mr      r5, r29     # | back in r12 and branch to it.
    mr      r6, r28     # /
    mtctr   r27
    bctrl
    
end:
    lmw     r27, 0x08(r1)
    lwz     r0, 0x94(r1)
    mtlr    r0
    addi    r1, r1, 0x90
}
################################################################
#                THPOpen Routine                         
################################################################
op  bl 0x52B9F4 @ $8007be0c    # THPPlayerOpen
op  bl 0x528AA4 @ $8007ed5c    # mvMoviePlayer::loadLastFrameInfo
op  bl 0x5289A0 @ $8007ee60    # mvMoviePlayer::loadLastFrame
CODE @ $805A7800
{
_sdopen:
    # save our context
    stwu    r1, -0x90(r1)
    stmw    r4, 0x08(r1)
    mflr    r0
    stw     r0, 0x94(r1)
    mr      r26, r3 # char* filepath
    mr      r27, r4 # DVDFileInfo*
    li      r4, 0
    %call   (SDStreamOpen)
    cmpwi   r3, 0
    bne     _end # only fall to DVD if open fails
    
_dvd:
    mr      r3, r26
    mr      r4, r27
    %call   (DVDOpen)

_end:
    lmw     r4, 0x08(r1) # restore original registers
    lwz     r0, 0x94(r1)
    addi    r1, r1, 0x90
    mtlr    r0 # original LR
    blr
}
################################################################
#                THPClose Routine                          
################################################################
op  bl 0x52B964   @ $8007c19c   # THPPlayerClose
op  bl 0x52BBF4   @ $8007bf0c   # THPPlayerOpenProc
op  bl 0x52BAAC   @ $8007c054   # THPPlayerOpenProc
op  bl 0x528CF8   @ $8007ee08   # mvMoviePlayer::closeLastFrameInfo
op  bl 0x528BD8   @ $8007ef28   # mvMoviePlayer::closeLastFrame
op  bl 0x528F68   @ $8007eb98   # mvMoviePlayer::__dt
CODE @ $805A7B00
{
_start:
    stwu    r1, -0x80(r1)
    mflr    r0
    stw     r0, 0x84(r1)
    stmw    r4, 0x08(r1)
    mr      r26, r3
    
    li      r3, 0
    %call   (SDStreamClose)    # SDStreamClose
    cmpwi   r0, -1
    bne     _end
    
_dvd:
    mr      r3, r26
    lmw     r4, 0x08(r1)
    %call   (DVDClose)

_end:
    lwz     r0, 0x84(r1)
    mtlr    r0
    addi    r1, r1, 0x80
    blr

}
################################################################
#                THPRead Routine                          
################################################################
op bl 0x52BB60 @ $8007bea0  # THPPlayerOpenProc
op bl 0x52BAA8 @ $8007bf58  # THPPlayerOpenProc
op bl 0x52B9DC @ $8007c024  # THPPlayerOpenProc
op bl 0x52B9BC @ $8007c044  # THPPlayerOpenProc

op bl 0x529790 @ $8007e270  # Reader/(mv_THPRead.o)
op bl 0x52B354 @ $8007c6ac  # THPPlayerPrepare
op bl 0x52B290 @ $8007c770  # THPPlayerPrepare

op bl 0x528C80 @ $8007ed80  # loadLastFrameInfo/[mvMoviePlayer]
op bl 0x528B7C @ $8007ee84  # loadLastFrame/[mvMoviePlayer]
CODE @ $805A7A00
{
_start:
    stwu    r1, -0x30(r1)
    mflr    r0
    stw     r0, 0x34(r1)
    stmw    r26, 0x8(r1) # save all regs
    mr      r26, r3
    mr      r27, r4 # addr
    mr      r28, r5 # size
    mr      r29, r6 # offset
    mr      r30, r7
    
    li      r3, 0
    %call   (SDStreamRead)    # SDStreamRead
    cmpwi   r3, 0
    beq     _disk
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
    %call   (DVDReadAsyncPrio)
    b       _end
    
_sync:
    %call   (DVDReadPrio)
    
_end:
    lmw     r26, 0x08(r1)
    lwz     r0, 0x34(r1)
    addi    r1, r1, 0x30 # restore sp
    mtlr    r0 # original LR
    blr
    
}
################################################################
#                   Never unmount SD
################################################################                                 
# Description:                                                  
#     Normally the gfCollection threads unmount the
#     SD and idle while they wait for a request. These
#     patches prevent file read errors caused by the
#     unmounting.
#################################################################
op  blr  @ $8001eb94

################################################################
#                   pfmenu2 fixes
################################################################                                 
# Description:                                                  
#     These paths are the only ones in the game that
#     lack a leading forward slash. 
#################################################################
string "/menu2/sc_title.pac"     @ $806FF9A0
string "/menu2/mu_menumain.pac"  @ $806FB248
string "/menu2/if_adv_mngr.pac"  @ $80B2C7F8
.RESET