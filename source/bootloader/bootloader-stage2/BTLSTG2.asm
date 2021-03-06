;*****************************************************************************
; Bootloader (second stage)
;
; BTLSTG2.asm
;*****************************************************************************
bits	16
org 0x500

jmp	main

;*****************************************************************************
; Includes
;*****************************************************************************
%include "GDT.asm"
%include "A20.asm"
%include "FAT12.asm"
%include "memory.asm"
;*****************************************************************************
; Defines
;*****************************************************************************

;-----------------------------------------------------------------------------
;  START	  END		  SIZE			        PURPOSE
;-----------------------------------------------------------------------------
; 0x00000 	0x003FF 	1KB 			- Interrupt Vector Table
; 0x00400 	0x004FF 	256 bytes 		- BIOS Data Area
; 0x00500 	0x07BFF 	30 KB   	- FREE MEMORY
; 0x07C00  	0x07DFF 	512 bytes 		- bootsector (this code)
; 0x07E00 	0x7FFFF 	480.5 KB 		- FREE MEMORY
; 0x80000	0x9FFFF		121 KB			- Extended BIOS Data Area
; 0xA0000 	0xFFFFF		384 KB			- Video Memory, ROM Area

%define MEMORY_MAP_BASE 0x2000		
%define IMAGE_PMODE_BASE 0x1000000 ; protected mode location - 16MB
%define IMAGE_RMODE_BASE 0x07E00 ; real mode location (temporary)

;*****************************************************************************
; Data Declarations
;*****************************************************************************
ImageSize     			DB 0
ImageName     			DB "HAL     SYS"

msgFailure 				DB 0x0D, "Lindus could not start for the following reasons:", 0x0A, 0x00
msgLoadFailure 			DB 0x0D, "Hardware Abstraction Layer (HAL.SYS) is missing or corrupt.", 0x0A, 0x00
msgAwaitKeypress 		DB 0x0D, "Press any key to restart.", 0x0A, 0x00

struc bootInfo_t
	.memoryLow			resd	1
	.memoryHigh_KB			resd	1
	.mmap_addr			resd	1
	.mmap_entries		resd	1
	.imageSize			resd 	1
	.load_addr			resd 	1
endstruc	

bootInfo:
istruc bootInfo_t
	at bootInfo_t.memoryLow,			DD 0
	at bootInfo_t.memoryHigh_KB,			DD 0
	at bootInfo_t.mmap_addr,			DD MEMORY_MAP_BASE
	at bootInfo_t.mmap_entries,			DD 0
	at bootInfo_t.imageSize,			DD 0	
	at bootInfo_t.load_addr,			DD 0
iend

;*****************************************************************************
; puts
; Prints a string using BIOS interrupt 0x10
;
; Parameters: DS:SI => address of the null-terminated string
;*****************************************************************************
puts:
	lodsb
	or		al, al
	jz		.putsDone
	mov		ah, 0x0E	; print character function
	int		0x10
	jmp		puts
.putsDone:
	ret

;*****************************************************************************
; awaitKeypressAndReboot
; Sends await keypress message and waits for a keypress after which it reboots
;
; Parameters: DS:SI => adress of the null-terminated error string
;*****************************************************************************
awaitKeypressAndReboot:
	push si
	mov si, msgFailure
	call puts
	pop si
	call puts
	mov si, msgAwaitKeypress
	call puts
		
	mov ah, 0x01
	mov ch, 00010000b
	int 0x10
		
	; await keypress
    mov     ah, 0x00
    int     0x16			
		
	; cold reboot
	xor ax, ax
	mov WORD [0x00472], ax
	jmp 0xFFFF:0x00   

;*****************************************************************************
; Stage 2 Entry
;*****************************************************************************
main:
	;set the segment registers
	cli
	xor	ax, ax
	mov	ds, ax
	mov	es, ax
	
	; create the stack
	mov	ax, 0x0
	mov	ss, ax
	mov	sp, 0x7C00 ; use the space below the bootsector
	sti
	
	; obtain information from BIOS
	xor	eax, eax
	xor	ebx, ebx
	call BiosGetMemorySize
	
	mov	WORD [bootInfo + bootInfo_t.memoryHigh_KB], bx
	mov	WORD [bootInfo + bootInfo_t.memoryLow], ax

	mov	eax, 0x0
	mov	ds, ax
	mov	di, WORD [bootInfo + bootInfo_t.mmap_addr]
	call BiosGetMemoryMap
	
	mov WORD [bootInfo + bootInfo_t.mmap_entries], bp
	
	; load FAT and find the file
	call FAT12_LoadRoot

	mov	ebx, 0
    mov	bp, IMAGE_RMODE_BASE
	mov	si, ImageName
	call	FAT12_LoadFile
	
	mov	DWORD [ImageSize], ecx
	cmp	ax, 0
	jne	fileNotFound
	
	; Install GDT and enable A20 gate
	call InstallGDT
	call EnableA20
	
	; jump to protected mode
	cli
	mov	eax, cr0
	or	eax, 1
	mov	cr0, eax

	; far jump to fix the code segment
	jmp	CODE_DESC:Stage3
	
fileNotFound:
	mov		si, msgLoadFailure
	call 	awaitKeypressAndReboot
	cli
	hlt

;*****************************************************************************
;	32bit protected mode entry
;*****************************************************************************
bits 32

Stage3:
	mov	ax, DATA_DESC
	mov	ds, ax
	mov	ss, ax
	mov	es, ax
	mov	esp, 0x7FFFF

	mov 	edx, 0
  	mov		eax, DWORD [ImageSize]
  	movzx	ebx, WORD [bpbBytesPerSector]
  	mul		ebx
	mov DWORD [bootInfo + bootInfo_t.imageSize], eax
  	mov		ebx, 4
  	div		ebx
   	cld
   	mov    esi, IMAGE_RMODE_BASE
   	mov	edi, IMAGE_PMODE_BASE
   	mov	ecx, eax
   	repe	movsd

	mov eax, IMAGE_PMODE_BASE
	mov DWORD [bootInfo + bootInfo_t.load_addr], eax
	
	push	DWORD bootInfo
	jmp	CODE_DESC:IMAGE_PMODE_BASE

	cli
	hlt

