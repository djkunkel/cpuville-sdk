;Formats four CP/M disks
;Updated June 2019 to match improved z80_cbios3
;Writes E5h to 128 sectors on tracks 1 to 255 of each disk (track 0 for system).
;Uses calls to cbios, in memory at FA00h

;updated by DJ for 8 disk setup, and only clearning the needed sectors on each disk

;since we have 256 director entries of 32 bytes each, we only need to clear
;the first (256*32)/128(sector size) = 64 sectors of the second track (first track reserved)

include locations.asm

seldsk:		equ org_bios+(3*9);equ	$F7A5 		;pass disk no. in c
setdma:		equ org_bios+(3*12);equ	$F7CF  	;pass address in bc
settrk:		equ org_bios+(3*10);equ	$F7BE		;pass track in reg C
setsec:		equ org_bios+(3*11);		;pass sector in reg c
write:		equ org_bios+(3*14);equ	$F839		;write one CP/M sector to disk
prmsg:		equ org_bios+(3*17);equ	0f7d9h		;subroutine to write message (nonstandard)
conout:		equ org_bios+(3*4);equ	0f78dh		;print a character

;rom routines
monitor_warm_start:	equ	046fh

;constants
num_disks: 			equ 8
num_entries:		equ 256
sec_per_track:		equ 128
sectors:			equ ((num_entries*32)/128)-1


		org	0800h
		ld (old_stack), sp
		ld	sp,format_stack
		ld	hl,format_string
		call	prmsg
		ld	a,00h		;starting disk
		ld	(disk),a
disk_loop:	ld	c,a		;CP/M disk a
		call	seldsk

		;print disk letter
		ld a, (disk)
		add $41 ; ascii A
		ld c, a
		call conout

		ld	a,1		;starting track (offset = 1)
		ld	(track),a
track_loop:	ld	a,0		;starting sector
		ld	(sector),a
		ld	hl,directory_sector	;address of data to write
		ld	(address),hl
		ld	a,(track)
		ld	c,a		;CP/M track
		call	settrk
sector_loop:	ld	a,(sector)
		ld	c,a		;CP/M sector
		call	setsec
		ld	bc,(address)	;memory location
		call	setdma
		call	write
		ld	a,(sector)
		cp	sectors ; only need to do first 64 sectors of this disk
		jp	z,next_disk
		inc	a
		ld	(sector),a
		jp	sector_loop
next_disk:	ld	a,(disk)
		inc	a
		cp	num_disks
		jp	z,done
		ld	(disk),a
		jp	disk_loop
done:	ld sp, (old_stack)
		jp	monitor_warm_start

disk:		db	00h
sector:		db	00h
track:		db	00h
address:	dw	0000h
format_string:	defm	0dh,0ah,'Formatting...',0dh,0ah,0
char_count:	db	00h
old_stack: dw 0
directory_sector:
		dc	128,0e5h	;byte for empty directory
		ds	32		;stack space
format_stack:
		end