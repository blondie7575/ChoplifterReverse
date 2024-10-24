;
;  loader
;  A very simplistic code loader for my reverse-engineered Choplifter
;
;  Created by Quinn Dunki on May 5, 2024
;

.segment "STARTUP"

MAINENTRY =		$2000		; Mandated by ProDOS for SYSTEM programs
LOADBUFFER =	$4000		; Use HGR2 as a loading buffer
PRODOS = 		$bf00		; MLI entry point

.org $2000

main:
	; Open the low code file
	jsr PRODOS
	.byte $c8
	.addr fileOpenCode0
	bne ioError

	; Load low code at $800
	jsr PRODOS
	.byte $ca
	.addr fileRead0
	bne ioError
	
	; Close the file
	jsr PRODOS
	.byte $cc
	.addr fileClose

	; Open the high code file
	jsr PRODOS
	.byte $c8
	.addr fileOpenCode1
	bne ioError

	; Load high code at $6000
	jsr PRODOS
	.byte $ca
	.addr fileRead1
	bne ioError

	; Close the file
	jsr PRODOS
	.byte $cc
	.addr fileClose

	; Open the graphics file
	jsr PRODOS
	.byte $c8
	.addr fileOpenGfx
	bne ioError

	; Load graphics at $a102
	jsr PRODOS
	.byte $ca
	.addr fileReadGfx
	bne ioError

	; Close the file
	jsr PRODOS
	.byte $cc
	.addr fileClose

	; We have another page of graphics that has to load on top of ProDOS, so load it in HGR2 first
	jsr PRODOS
	.byte $c8
	.addr fileOpenGfxHi
	bne ioError

	; Load high graphics at $5000 temporarily
	jsr PRODOS
	.byte $ca
	.addr fileReadGfxHi
	bne ioError

	; Close the file
	jsr PRODOS
	.byte $cc
	.addr fileClose

	; We're done with ProDOS for good now, so we can stomp on it with the last page of graphics
	; that Choplifter expects to find there
	ldx #$00

copyBytesLoop:
	lda	$5000,x
	sta	$bef0,x
	inx
	cpx #$70
	bne copyBytesLoop

	jmp initVectors

ioError:
	brk

initVectors:
	; Prepare game flow vectors. These are things that Dan's loader would have done
	; but have been lost in this reverse engineer because I've converted it to ProDOS
	; None of these vectors ever change during gameplay, so making them an indirection
	; was probably a development and debugging tool.
	lda		#$c7					; Initialize game start vector
	sta		$2a		; ZP_LOADERVECTOR_L
	lda		#$09
	sta		$2b		; ZP_LOADERVECTOR_H
	lda		#$1f
	sta		$28		; ZP_STARTTITLE_JMP_L
	lda		#$08
	sta		$29		; ZP_STARTTITLE_JMP_H
	lda		#$5f
	sta		$3a		; ZP_GAMESTART_JMP_L
	lda		#$0b
	sta		$3b		; ZP_GAMESTART_JMP_H
	lda		#$13
	sta		$3c		; ZP_NEWSORTIE_JMP_L
	lda		#$0c
	sta		$3d		; ZP_NEWSORTIE_JMP_H
	lda		#$9b
	sta		$4e		; ZP_GAMEINIT_L
	lda		#$0b
	sta		$4f		; ZP_GAMEINIT_H
	lda		#$92
	sta		$24		; ZP_INDIRECT_JMP_L
	lda		#$0c
	sta		$25		; ZP_INDIRECT_JMP_H

	; Give ourselves a stub in $300 because Choplifter is about to erase this area of memory
	lda 	#$20		; jsr jumpStartGraphicsDeadCode
	sta		$300
	lda		#$09
	sta		$301
	lda		#$90
	sta		$302

	; Jump into Choplifter loader entry, and Dan's code is none the wiser, partying like it's 1982.
	lda		#$4c		; jmp $0800
	sta		$303
	lda		#$00
	sta		$304
	lda		#$08
	sta		$305

	; Jump into our new stub, and this loader now ceases to exist
	jmp 	$0300


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

fileOpenCode0:
	.byte 3
	.addr codePath0
	.addr LOADBUFFER
	.byte 0					; Result (file handle)
	.byte 0					; Padding

fileRead0:
	.byte 4
	.byte 1					; File handle (we know it's gonna be 1)
	.addr $800
	.word $1800
fileRead0Len:
	.word 0					; Result (bytes read)

fileOpenCode1:
	.byte 3
	.addr codePath1
	.addr LOADBUFFER
	.byte 0					; Result (file handle)
	.byte 0					; Padding

fileRead1:
	.byte 4
	.byte 1					; File handle (we know it's gonna be 1)
	.addr $6000
	.word $4100				; Covers all code up to bottom of graphics area
fileRead1Len:
	.word 0					; Result (bytes read)

fileOpenGfx:
	.byte 3
	.addr gfxPath
	.addr LOADBUFFER
	.byte 0					; Result (file handle)
	.byte 0					; Padding

fileReadGfx:
	.byte 4
	.byte 1					; File handle (we know it's gonna be 1)
	.addr $a102
	.word $1ded				; Don't step on ProDOS when loading graphics
fileReadGfxLen:
	.word 0					; Result (bytes read)

fileOpenGfxHi:
	.byte 3
	.addr gfxPathHi
	.addr LOADBUFFER
	.byte 0					; Result (file handle)
	.byte 0					; Padding

fileReadGfxHi:
	.byte 4
	.byte 1					; File handle (we know it's gonna be 1)
	.addr $5000
	.word $70				; This little piece would step on ProDOS
fileReadGfxHiLen:
	.word 0					; Result (bytes read)

fileClose:
	.byte 1
	.byte 1					; File handle (we know it's gonna be 1)


.macro  pstring Arg
	.byte   .strlen(Arg), Arg
.endmacro


codePath0:
	pstring "/CHOPLIFTER/CHOP0"
codePath1:
	pstring "/CHOPLIFTER/CHOP1"
gfxPath:
	pstring "/CHOPLIFTER/CHOPGFX"
gfxPathHi:
	pstring "/CHOPLIFTER/CHOPGFXHI"
