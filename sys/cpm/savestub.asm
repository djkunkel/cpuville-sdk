;DJ Kunkel
;A stub meant to be loaded to 0800 that will copy 1024 bytes from 900 to to the CP/M TPA area

;To use
;Start CPM on the CPUville
;reset
;do a bload of this to 800
;do a bload of your max 1024 byte COM file to 900
;run 0800
;this will: switch to all RAM mode, copy 900 to 100, execute FA00 (restart CPM)
; 	then you can "SAVE 2 file.com" (or 3 or 4 depending on how many 256 byte blocks you want to save)

include locations.asm

cpm:		.equ	org_bios		;CP/M cold start entry
			
			
			.org	0800h
			
			ld a, 1
			out	(1),a		;switch memory config to all-RAM
			
			ld hl, 0900h
			ld de, 0100h
			ld bc, 1024
			ldir
			
			jp cpm
	
	
	