;stores the locations in memory that the OS components will live at

;we can use this unless any changes are made to the ccp or bdos that affect its length
;the bios can grow unless it exceeds putsys.asm's ability to save it as it only saves 6400 bytes right now


org_ccp:    equ     $E000
org_bdos:   equ     org_ccp+$806
org_bios:   equ     org_ccp+$1600

