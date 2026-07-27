;Putsys3 by Donn Stewart, June 2019

;Copies the memory image of CP/M loaded at E000h onto track 0 of the first CP/M disk
;Image size is <= 6400 bytes, so need to save 6400/128 = 50 sectors
;For system with 64-sector tracks, image can all be on track 0
;Load and run from ROM monitor


;Modified Dec 2020 by DJ Kunkel for different memory addresses
;Uses calls to cbios, in memory at F600h
;Writes track 0, sectors 1 to 50 (sector 0 has cpm loader)

;@dj reworked this to use offsets into the jump table for the CPM functions based on locations.asm
;we should be able to convert to z88dk assembler and do these assemblies together, with the cavet that cbios overlaps intentionally with cpm

;note that if the CBIOS's code actually ever extends much beyond its current end at F88E, this code might need to adjusted

import locations.asm


seldsk:		equ org_bios+(3*9);equ	$F7A5 		;pass disk no. in c
setdma:		equ org_bios+(3*12);equ	$F7CF  	;pass address in bc
settrk:		equ org_bios+(3*10);equ	$F7BE		;pass track in reg C
setsec:		equ org_bios+(3*11);		;pass sector in reg c
write:		equ org_bios+(3*14);equ	$F839		;write one CP/M sector to disk
monitor_warm_start:	equ	046Fh	;Return to ROM monitor
		org	0800h
		ld	c,00h		;CP/M disk a
		call	seldsk
;Write track 0, sectors 1 to 50
		ld	a,1		;starting sector
		ld	(sector),a
		ld	hl,org_ccp	;memory address to start
		ld	(address),hl
		ld	c,0		;CP/M track
		call	settrk
wr_trk_0_loop:	ld	a,(sector)
		ld	c,a		;CP/M sector
		call	setsec
		ld	bc,(address)	;memory location
		call	setdma
		call	write
		ld	a,(sector)
		cp	50
		jp	z,done
		inc	a
		ld	(sector),a
		ld	hl,(address)
		ld	de,128
		add	hl,de
		ld	(address),hl
		jp	wr_trk_0_loop
done:		jp	monitor_warm_start
sector:		db	00h
address:	dw	0000h
		end


