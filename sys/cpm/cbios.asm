;	CP/M CBIOS for CPUville 8-bit computers
;	version 3, June 2019 by Donn Stewart
;	Modified from skeletal cbios for first level of CP/M 2.0 alteration
;	64-sector tracks, numbering starting at zero (sectors 0 to 63)
;	Block size 2048
;	Disk size 2 mb, DSM 1023, yields 256 tracks (0 to 255)
;	4 disks
;	Made more efficient use of disk by OR-ing CP/M disk, track, sector values
;	to create logical block address (LBA) for IDE disk
;	Added greeting message to cold boot
;

;	Modifed by DJ Kunkel December 2020
;	Supports 8 disks with 4K block size

import locations.asm

ccp:	equ	org_ccp		;base of ccp
bdos:	equ	org_bdos		;bdos entry
bios:	equ	org_bios		;base of bios
cdisk:	equ	0004h		;address of current disk number 0=a,... l5=p
iobyte:	equ	0003h		;intel i/o byte
rst38: equ 0038h	;im 1 reset vector for interrupts
disks:	equ	08h		;number of disks in the system
;
	org	bios		;origin of this program
nsects:	equ	($-ccp)/128	;warm start sector count
;
;	jump vector for individual subroutines
;
	JP	boot	;cold start
wboote:	JP	wboot	;warm start
	JP	const	;console status
	JP	conin	;console character in
	JP	conout	;console character out
	JP	list	;list character out
	JP	punch	;punch character out
	JP	reader	;reader character out
	JP	home	;move head to home position
	JP	seldsk	;select disk
	JP	settrk	;set track number
	JP	setsec	;set sector number
	JP	setdma	;set dma address
	JP	read	;read disk
	JP	write	;write disk
	JP	listst	;return list status
	JP	sectran	;sector translate
	;nonstandard entries @dj
	JP prmsg ; print a 0 terminated string to console starting at hl
;
;	Data tables for disks
;	Four disks, 26 sectors/track, disk size = number of 1024 byte blocks
;	Number of directory entries (32-bytes each) set to 127 per 500 blocks
;	Allocation map bits = number of blocks needed to contain directory entries
;	No translations -- translation maps commented out
;
;	disk Parameter header for disk 00
dpbase:	
	.DW 0000h,0000h,0000h,0000h,dirbf,dpblk,0000h,all00
	.DW 0000h,0000h,0000h,0000h,dirbf,dpblk,0000h,all01
	.DW 0000h,0000h,0000h,0000h,dirbf,dpblk,0000h,all02
	.DW 0000h,0000h,0000h,0000h,dirbf,dpblk,0000h,all03
	.DW 0000h,0000h,0000h,0000h,dirbf,dpblk,0000h,all04
	.DW 0000h,0000h,0000h,0000h,dirbf,dpblk,0000h,all05
	.DW 0000h,0000h,0000h,0000h,dirbf,dpblk,0000h,all06
	.DW 0000h,0000h,0000h,0000h,dirbf,dpblk,0000h,all07

	;dj - pretty sure my ALVs are too small for 2048 DSM+1 according to: 
	;http://www.gaby.de/cpm/manuals/archive/cpm22htm/ch6.htm#Section_6.5
	;most likely need to be 256 bytes
	;block shift and mask are values from a table indicating how 
	;much data is in a block (2048 bytes is 4/15)

	;can we use 256 sectors per track and use the entire space 
	;in the lower lba?

	;what determines the max number of tracks? why/how is it 256 right now?
	;- the number of tracks are determined by the size of the disk
	;- since we have a DSM+1 of 2048 we are saying there are 2048 blocks on the disk
	;- the values of BSH(4) and BLM(15) by a table in the manual indicate a 2048 byte block size (BLS), so 2048*2048 = 4MB
	;- each sector contains 128 bytes, so each track is 128*128 = 16KB, so to
	;- reach 4MB there must be 256 tracks (16 * 256 * 1024)
	;--if we went to 256 SPT then (32 * 128 * 1024 = 4MB, so only 128 tracks)
	
	;if we reduced the DSM+1 to 1023, we could keep our smaller ALVs
	;but switching BLS to 4KB, means 5,31 for block shift factors
	;the ALV now needs to be DSM/8+1 which is 128
	;255 directory entires means we need 128*2 by the table, which gives us
	;2 bits which gives us C0 for AL0 and 00 for AL1
	;we also now need a EXM of 1
	;http://www.gaby.de/cpm/manuals/archive/cpm22htm/ch6.htm#Section_6.5
	;it is unclear if we need to subtract blocks from DSM to accomidate the OFFset
	;we can test with stat a: to see what happens

	;pretty sure we have to account for it now
	;since the total space of an empty disk shows 4088K which is 4096K - 8K (for 256x32 dir entries) = 4088K which is not
	;taking into account the 16K of the reserved track (128bytes x 128 sectors)
	;so the first disk needs 1023-4(4k) = 1019

dpblk:	;disk parameter block for all disks.
	defw	128		;SPT sectors per track (dj, doubled)
	defm	5		;BSH block shift factor
	defm	31		;BLM block mask - with block shift, sets block size to 4096
	defm	1		;EXM null mask
	defw	1023-4	;DSM disk size-1 = number of blocks in a disk - 1 (-4 for the reserved first track)
	defw	255		;SRM directory max = no. directory entries/disk, arbitrary
	defm	$C0		;AL0 alloc 0 -- need 2 bits (blocks) for 256 directory entries -- 
	defm	$00		;AL1 alloc 1 -- no. bits = (directory max x 32)/block size	
	defw	0		;CKS check size -- no checking, so zero
	defw	1		;OFF track offset -- first track for system
;
;	end of fixed tables
;
;	Greeting message for cold boot
greet:	defm	0dh, 0ah
	defm	"CP/M 2.2 for DJ-Cpuville 64K"
	defm	0dh, 0ah, 0	

;	individual subroutines to perform each function
boot:	;entry point from CP/M loader
	;CP/M loader has loaded BDOS, CCP and CBIOS
	;print greeting and perform parameter initialization
	ld	hl,greet	;address of greeting message
	call	prmsg		;print message subroutine
	XOR	a		;zero in the accum
	LD	(iobyte),A	;clear the iobyte
	LD	(cdisk),A	;select disk zero

	;@dj set up a simple interrupt handler for rst vector 38 that simply re-enables interrupts and returns
	;we only have a few bytes of space here, however our bios doesn't use the BIOS work area, so we have from $38 up to $5F before we get to the FCB
	;so a small handler could be put here by a program later on
	di ; make sure interrupts are off
	im 1 ; ensure im 1 (all maskable interrupts go to vector at 38h) is the mode
	ld hl, rst38
	ld (hl), $FB ; ei instruction since Z/80 disables interrupts as soon as a handler runs
	inc hl
	ld (hl), $C9 ; ret

	JP	gocpm		;initialize and go to cp/m
;
wboot:	;load BDOS and CCP only -- CBIOS should still be there...
	LD	sp, 80h		;use space below buffer for stack
	LD 	c, 0		;select disk 0
	call	seldsk
	call	home		;go to track 00
;
	LD 	b, nsects	;b counts * of sectors to load
	LD 	c, 0		;c has the current track number
	LD 	d, 1		;d has the next sector to read
;	note that we begin by reading track 0, sector 1 since sector 0
;	contains the cold start loader, which is skipped in a warm start
	LD	HL, ccp		;base of cp/m (initial load point)
load1:	;load	one more sector
	PUSH	BC		;save sector count, current track
	PUSH	DE		;save next sector to read
	PUSH	HL		;save dma address
	LD 	c, d		;get sector address to register C
	call	setsec		;set sector address from register C
	pop	BC		;recall dma address to b, C
	PUSH	BC		;replace on stack for later recall
	call	setdma		;set dma address from b, C
;
;	drive set to 0, track set, sector set, dma address set
	call	read
	CP	00h		;any errors?
	JP	NZ,wboot	;retry the entire boot if an error occurs
;
;	no error, move to next sector
	pop	HL		;recall dma address
	LD	DE, 128		;dma=dma+128
	ADD	HL,DE		;new dma address is in h, l
	pop	DE		;recall sector address
	pop	BC		;recall number of sectors remaining, and current trk
	DEC	b		;sectors=sectors-1
	JP	Z,gocpm		;transfer to cp/m if all have been loaded
;
;	more	sectors remain to load, check for track change
	INC	d
	LD 	a,d		;sector=64?, if so, change tracks
	CP	64
	JP	C,load1		;carry generated if sector<64
;
;	end of	current track,	go to next track
	LD 	d,0		;begin with first sector of next track
	INC	c		;track=track+1
;
;	save	register state, and change tracks
	PUSH	BC
	PUSH	DE
	PUSH	HL
	call	settrk		;track address set from register c
	pop	HL
	pop	DE
	pop	BC
	JP	load1		;for another sector
;
;	end of	load operation, set parameters and go to cp/m
gocpm:
	LD 	a, 0c3h		;c3 is a jmp instruction
	LD	(0),A		;for jmp to wboot
	LD	HL, wboote	;wboot entry point
	LD	(1),HL		;set address field for jmp at 0
;
	LD	(5),A		;for jmp to bdos
	LD	HL, bdos	;bdos entry point
	LD	(6),HL		;address field of Jump at 5 to bdos
;
	LD	BC, 80h		;default dma address is 80h
	call	setdma
;
	nop; ei			;enable the interrupt system (@dj I don't think we should do this, there's no defined handler for interrupts)
	LD	A,(cdisk)	;get current disk number
	cp	disks		;see if valid disk number
	jp	c,diskok	;disk valid, go to ccp
	ld	a,0		;invalid disk, change to disk 0
diskok:	LD 	c, a		;send to the ccp
	JP	ccp		;go to cp/m for further processing
;
;
;	simple i/o handlers (must be filled in by user)
;	in each case, the entry point is provided, with space reserved
;	to insert your own code
;
const:	;console status, return 0ffh if character ready, 00h if not
	in 	a,(3)		;get status
	and 	002h		;check RxRDY bit
	jp 	z,no_char
	ld	a,0ffh		;char ready	
	ret
no_char:ld	a,00h		;no char
	ret
;
conin:	;console character into register a
	in 	a,(3)		;get status
	and 	002h		;check RxRDY bit
	jp 	z,conin		;loop until char ready
	in 	a,(2)		;get char
	AND	7fh		;strip parity bit
	ret
;
conout:	;console character output from register c
	in	a,(3)
	and	001h		;check TxRDY bit
	jp	z,conout	;loop until port ready
	ld	a,c		;get the char
	out	(2),a		;out to port
	ret
;
list:	;list character from register c
	LD 	a, c	  	;character to register a
	ret		  	;null subroutine
;
listst:	;return list status (0 if not ready, 1 if ready)
	XOR	a	 	;0 is always ok to return
	ret
;
punch:	;punch	character from	register C
	LD 	a, c		;character to register a
	ret			;null subroutine
;
;
reader:	;reader character into register a from reader device
	LD     a, 1ah		;enter end of file for now (replace later)
	AND    7fh		;remember to strip parity bit
	ret
;
;
;	i/o drivers for the disk follow
;	for now, we will simply store the parameters away for use
;	in the read and write	subroutines
;
home:	;move to the track 00	position of current drive
;	translate this call into a settrk call with Parameter 00
	LD     c, 0		;select track 0
	call   settrk
	ret			;we will move to 00 on first read/write
;
seldsk:	;select disk given by register c
	LD	HL, 0000h	;error return code
	LD 	a, c
	LD	(diskno),A
	CP	disks		;must be between 0 and 3
	RET	NC		;no carry if 4, 5,...
;	disk number is in the proper range
;	defs	10		;space for disk select -- not needed for modern hard disk
;	compute proper disk Parameter header address
	LD	A,(diskno)
	LD 	l, a		;l=disk number 0, 1, 2, 3
	LD 	h, 0		;high order zero
	ADD	HL,HL		;*2
	ADD	HL,HL		;*4
	ADD	HL,HL		;*8
	ADD	HL,HL		;*16 (size of each header)
	LD	DE, dpbase
	ADD	HL,DE		;hl=,dpbase (diskno*16) Note typo here in original source.
	ret
;
settrk:	;set track given by register c
	LD 	a, c
	LD	(track),A
	ret
;
setsec:	;set sector given by register c
	LD 	a, c
	LD	(sector),A
	ret
;
;
sectran:
	;translate the sector given by bc using the
	;translate table given by de
	EX	DE,HL		;hl=.trans
	ADD	HL,BC		;hl=.trans (sector)
	ret			;debug no translation
	LD 	l, (hl)		;l=trans (sector)
	LD 	h, 0		;hl=trans (sector)
	ret			;with value in hl
;
setdma:	;set	dma address given by registers b and c
	LD 	l, c		;low order address
	LD 	h, b		;high order address
	LD	(dmaad),HL	;save the address
	ret
;
;	Subroutine to print greeting message
;	Address of zero-terminated string passed in HL
prmsg:	ld	a,0			;check if at end of string
	ld	c,(hl)
	or	c
	ret	z			;yes, return
	call	conout			;no, output character
	inc	hl
	jp	prmsg
;
;
read:
;Read one CP/M sector from disk.
;Return a 00h in register a if the operation completes properly, and 01h if an error occurs during the read.
;Disk number in 'diskno'
;Track number in 'track'
;Sector number in 'sector'
;Dma address in 'dmaad' (0-65535)
;dj - todo, it should be possible to avoid a read if you already have the second
;128 byte sector inside an already loaded hstbuf
;	how to do this? 
;	if you are reading the same disk, same track, but previous sector+1, you can read
;	the second section of the hstbuf
;
			ld	hl,hstbuf		;buffer to place disk sector (256 bytes)
rd_status_loop_1:	in	a,(0fh)			;check status
			and	80h			;check BSY bit
			jp	nz,rd_status_loop_1	;loop until not busy
rd_status_loop_2:	in	a,(0fh)			;check	status
			and	40h			;check DRDY bit
			jp	z,rd_status_loop_2	;loop until ready
			ld	a,01h			;number of sectors = 1
			out	(0ah),a			;sector count register
			ld	a,(sector)		;CP/M sector (0 to 127, 7 bits)
			out	(0bh),a			;lba bits 0 - 7
			ld	a,(track)		;CP/M track (0 to 255, 8 bits)
			out	(0ch),a			;lba bits 8 - 15
			ld	a,(diskno)			;(dj) upper bits with disk no
			out	(0dh),a			;lba bits 16 - 23
			ld	a,11100000b		;LBA mode, select host drive 0
			out	(0eh),a			;drive/head register
			ld	a,20h			;Read sector command
			out	(0fh),a
rd_wait_for_DRQ_set:	in	a,(0fh)			;read status
			and	08h			;DRQ bit
			jp	z,rd_wait_for_DRQ_set	;loop until bit set
rd_wait_for_BSY_clear:	in	a,(0fh)
			and	80h
			jp	nz,rd_wait_for_BSY_clear
			in	a,(0fh)			;clear INTRQ
read_loop:		in	a,(08h)			;get data
			ld	(hl),a
			inc	hl
			in	a,(0fh)			;check status
			and	08h			;DRQ bit
			jp	nz,read_loop		;loop until clear
			
			;copy from buffer using ldir
			ld hl, hstbuf ;host buffer
			ld de, (dmaad) ;memory location to place data read from disk
			ld bc, 128 ;size of CP/M sector
			ldir ;put in memory
				
			in	a,(0fh)			;get status
			and	01h			;error bit
			ret

write:
;Write one CP/M sector to disk.
;Return a 00h in register a if the operation completes properly, and 0lh if an error occurs during the read or write
;Disk number in 'diskno'
;Track number in 'track'
;Sector number in 'sector'
;Dma address in 'dmaad' (0-65535)

			;copy to buffer using ldir
			ld hl, (dmaad) ;source cp/m location
			ld de, hstbuf ;host buffer
			ld bc, 128 ;size of CP/M sector
			ldir ;put into hst buffer

			ld	hl,hstbuf		;location of data to write to disk
wr_status_loop_1:	in	a,(0fh)			;check status
			and	80h			;check BSY bit
			jp	nz,wr_status_loop_1	;loop until not busy
wr_status_loop_2:	in	a,(0fh)			;check	status
			and	40h			;check DRDY bit
			jp	z,wr_status_loop_2	;loop until ready
			ld	a,01h			;number of sectors = 1
			out	(0ah),a			;sector count register
			ld	a,(sector)		;CP/M sector (0 to 127, 7 bits)
			out	(0bh),a			;lba bits 0 - 7
			ld	a,(track)		;CP/M track (0 to 255, 8 bits)
			out	(0ch),a			;lba bits 8 - 15
			ld	a, (diskno)			;upper bits to diskno (dj)
			out	(0dh),a			;lba bits 16 - 23
			ld	a,11100000b		;LBA mode, select drive 0
			out	(0eh),a			;drive/head register
			ld	a,30h			;Write sector command
			out	(0fh),a
wr_wait_for_DRQ_set:	in	a,(0fh)			;read status
			and	08h			;DRQ bit
			jp	z,wr_wait_for_DRQ_set	;loop until bit set			
write_loop:		ld	a,(hl)
			out	(08h),a			;write data
			inc	hl
			in	a,(0fh)			;read status
			and	08h			;check DRQ bit
			jp	nz,write_loop		;write until bit cleared
wr_wait_for_BSY_clear:	in	a,(0fh)
			and	80h
			jp	nz,wr_wait_for_BSY_clear
			in	a,(0fh)			;clear INTRQ
			and	01h			;check for error
			ret

					
;
;	the remainder of the cbios is reserved uninitialized
;	data area, and does not need to be a Part of the
;	system	memory image (the space must be available,
;	however, between"begdat" and"enddat").
;
track:	defs	2		;two bytes for expansion
sector:	defs	2		;two bytes for expansion
dmaad:	defs	2		;direct memory address
diskno:	defs	1		;disk number 0-15
;
;	scratch ram area for bdos use
begdat:	equ	$	 	;beginning of data area
dirbf:	defs	128	 	;scratch directory area
;Allocation scratch areas, size of each must be (DSM/8)+1
all00:	defs	128	 	;allocation vector 0
all01:	defs	128	 	;allocation vector 1
all02:	defs	128	 	;allocation vector 2
all03:	defs	128	 	;allocation vector 3
all04:	defs	128	 	;allocation vector 4
all05:	defs	128	 	;allocation vector 5
all06:	defs	128	 	;allocation vector 6
all07:	defs	128	 	;allocation vector 7


;
enddat:	equ	$	 	;end of data area
datsiz:	equ	$-begdat;	;size of data area
hstbuf: ds	256		;buffer for host disk sector
bioslen: equ $-bios ; end bios
	end
