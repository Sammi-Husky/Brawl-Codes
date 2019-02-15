.macro call func
	lis r12, \func@h
	ori r12,r12,\func@l
	mtctr r12
	bctrl
.endm

####################
# String functions #
####################
.equ strncpy, 0x803fa340
.equ strzcpy, 0x80372dd8
.equ strncat, 0x803fa3b0
.equ strnlen, 0x80211af8
.equ strcspn, 0x803fa5d0

################
# IO Functions #
################
.equ checkSD, 0x8001f5a0
.equ readSDFile, 0x8001cbf4
.equ readDVDFile, 0x8001c144
