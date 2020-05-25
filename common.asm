.macro call func
    liw r12, \func
	mtctr r12
	bctrl
.endm

.macro liw reg, addr
    lis \reg, \addr@h
    ori \reg, \reg, \addr@l
.endm

####################
#     Globals      #
####################
.equ    g_fpcPath,      0x805a7c00
.equ    g_thpFilepath,  0x8049DDD0

####################
# String functions #
####################
.equ    strncpy,    0x803fa340
.equ    strzcpy,    0x80372dd8
.equ    strncat,    0x803fa3b0
.equ    strnlen,    0x80211af8
.equ    strcspn,    0x803fa5d0

################
# IO Functions #
################
.equ    checkSD,            0x8001f5a0
.equ    readSDFile,         0x8001cbf4
.equ    readDVDFile,        0x8001c144
.equ    setReadParam,       0x8002239c
.equ    DVDReadPrio,        0x801f67f0
.equ    DVDReadAsyncPrio,   0x801f6708
.equ    DVDOpen,            0x801f6278
.equ    DVDClose,           0x801f6524
.equ    FAFOpen,            0x803ebeb8
.equ    FAFSeek,            0x803ebee8
.equ    FAFRead,            0x803eb6e0
.equ    FAFClose,           0x803ebe8c

################
# OS Functions #
################
.equ    OSDisableInterrupts,    0x801dcf10
.equ    OSEnableInterrupts,     0x801dcf38
.equ    OSDisableScheduler,     0x801e0760
.equ    OSEnableScheduler,      0x801e079c
.equ    OSLockMutex,            0x801debb4
.equ    OSUnlockMutex,          0x801dec90
.equ    OSReceiveMessage,       0x801de1bc