; Zero page allocations. Since Choplifter was a strictly cold-boot-from-floppy game,
; it has total control of the machine. There is no ProDOS, AppleSoft, or anything else
; that it has to share the zero page with. As such, it uses basically all of it, as
; the 6502 Gods intended. The zero page is supposed to be treated as 256 registers,
; and boy-howdy does Choplifter indeed treat it that way.

ZP_VELX_16_L			= $00		; Our X velocity as a 16-bit signed (low byte) 	Positive is to the right
ZP_VELX_16_H			= $01		; Our X velocity as a 16-bit signed (high byte) Positive is to the right
ZP_VELY_16_L			= $02		; Our Y velocity as a 16-bit signed (low byte) 	Positive is up.
ZP_VELY_16_H			= $03		; Our Y velocity as a 16-bit signed (high byte) 	Positive is up.
CHOP_POS_X_L			= $04		; 16-bit X position of chopper in screenspace (low byte)
CHOP_POS_X_H			= $05		; 16-bit X position of chopper in screenspace (high byte)
CHOP_POS_Y				= $06		; Y position of chopper in screenspace, bottom relative. Sitting on ground is $07
CHOP_GROUND				= $07		; Offset from 0 to sit chopper on the ground (always $16 for chopper)


; Helicopter physics state
ZP_TURN_STATE			= $08		; Current sprite rotate-in-place frame. -5 is full left, 0 is facing camera, +5 is full right.
ZP_ACCELX				= $09		; $00 = on ground		Current acceleration accumulated by stick position
									; $01 = drift left
									; $05 = full left
									; $fb = full right
ZP_STICKX				= $0A		; $01 = drift left		Stick input from pilot
									; $05 = full left
									; $fb = full right (-5)
ZP_ACCELY				= $0B		; $08 = Normal gravity, $0f = Full thrust up
ZP_AIRBORNE				= $0C		; $01 if we're airborne. $00 means touched down, but not landed
ZP_LANDED				= $0D		; $01 if we're fully landed. $00 if we're airborne or not sitting on ground properly yet
ZP_LANDED_BASE			= $0E		; $01 if we're landed on the home base pad
ZP_GROUNDING			= $0F		; Set to $01 when we first intersect ground
ZP_DYING				= $10		; $01 during death animation
	
ZP_SINK_Y				= $11		; How far into the ground we've sunk (used for crashing)
ZP_DEATHTIMER			= $12		; Counts to $ff during death animation
ZP_BTN0DOWN				= $13		; $ff if joystick button 0 is down

ZP_OFFSETPTR0_L			= $14		; Pointer to render offset table, buffer 0 (low byte)
ZP_OFFSETPTR0_H			= $15		; Pointer to render offset table, buffer 0 (high byte)
ZP_OFFSETPTR1_L			= $16		; Pointer to render offset table, buffer 1 (low byte)
ZP_OFFSETPTR1_H			= $17		; Pointer to render offset table, buffer 1 (high byte)
ZP_OFFSET_ROW0			= $18		; Current position in render offset table (buffer 0)
ZP_OFFSET_ROW1			= $19		; Current position in render offset table (buffer 1)

ZP_SPRITE_PTR_L			= $1A		; Current sprite art pointer (low byte)
ZP_SPRITE_PTR_H			= $1B		; Current sprite art pointer (high byte)
ZP_RENDERPOS_XL			= $1C		; 16-bit X position parameter for rendering (low byte)
ZP_RENDERPOS_XH			= $1D		; 16-bit X position parameter for rendering (high byte)
ZP_RENDERPOS_Y			= $1E		; Y position parameter for rendering

ZP_POS_SCRATCH0			= $1F		; A scratch for calculating render offsets
ZP_POS_SCRATCH1			= $20		; A scratch for calculating render offsets
ZP_POS_SCRATCH2			= $21		; A scratch for calculating render offsets

ZP_INDIRECT_JMP_L		= $24		; An indirect jump vector used in the main loop (low byte)
ZP_INDIRECT_JMP_H		= $25		; An indirect jump vector used in the main loop (high byte)
ZP_STARTTITLE_JMP_L		= $28		; An indirect jump vector used to start the title sequence (high byte)
ZP_STARTTITLE_JMP_H		= $29		; An indirect jump vector used to start the title sequence (low byte)

ZP_LOADERVECTOR_L		= $2A		; Vector loader jumps to when loading finished (low byte). Always $09c7
ZP_LOADERVECTOR_H		= $2B		; Vector loader jumps to when loading finished (high byte). Always $09c7

ZP_GAMESTART_JMP_L		= $3A		; Vector to game start, used in demo mode (low byte)
ZP_GAMESTART_JMP_H		= $3B		; Vector to game start, used in demo mode (high byte)
ZP_NEWSORTIE_JMP_L		= $3C		; Vector used to start a new sortie (low byte)
ZP_NEWSORTIE_JMP_H		= $3D		; Vector used to start a new sortie (low byte)
ZP_GAMEINIT_L			= $4E		; Vector used in game init (low byte)
ZP_GAMEINIT_H			= $4F		; Vector used in game init (high byte)

; Scratch values are used generically for arithmetic and local data within functions.
; Occasionally these are persistent past a function's scope, but never for long. These
; are always treated as temporaries.
ZP_SCRATCH56			= $56
ZP_SCRATCH57			= $57
ZP_SCRATCH58			= $58
ZP_SCRATCH59			= $59
ZP_SCRATCH5A 			= $5A
ZP_SCRATCH5B			= $5B
ZP_SCRATCH5C			= $5C
ZP_SCRATCH16_L			= $5D		; A 16-bit scratch for wide math and pointers (low byte)
ZP_SCRATCH16_H			= $5E		; A 16-bit scratch for wide math and pointers (high byte)
ZP_SCRATCH5F			= $5F
ZP_SCRATCH60			= $60		

ZP_SCRATCH61			= $61
ZP_SCRATCH62			= $62
ZP_SCRATCH63			= $63
ZP_SCRATCH64			= $64
ZP_SCRATCH65			= $65
ZP_SCRATCH66			= $66
ZP_SCRATCH67			= $67
ZP_SCRATCH68			= $68
ZP_SCRATCH69			= $69
ZP_SCRATCH6A			= $6A
									; Curiously, zero page location $6B is completely unused in the game
ZP_SCRATCH6C			= $6C
ZP_SCRATCH6D			= $6D
ZP_SCRATCH6E			= $6E
ZP_SCRATCH6F			= $6F
ZP_SCRATCH70			= $70
ZP_SCRATCH71			= $71

ZP_SCROLLPOS_L			= $72		; Current horizontal scroll position of playfield. 16 bits, 0 at far end (low byte)
ZP_SCROLLPOS_H			= $73		; Current horizontal scroll position of playfield. 16 bits, 0 at far end (high byte)
ZP_SKY_BACK_H			= $74		; Height of sky area when erasing a sprite
ZP_LAND_BACK_H			= $75		; How deep into the ground a sprite is during erasure
ZP_RND					= $76		; Next random number to be generated
ZP_FRAME_COUNT			= $77		; A frame counter, like a timer. Resets often though.
ZP_BUFFER				= $78		; $00 = Using double buffer 1, $ff = Double buffer 2
ZP_GAMEACTIVE			= $79		; $ff if gameplay is underway, or $00 if player has lost control

ZP_CURR_ENTITY			= $7A		; ID of current entity being updated
ZP_NEXT_ENTITY			= $7B		; Next entity to update (local offset in entityTable)
ZP_FREE_ENTITY			= $7C		; First unallocated entity

ZP_SCREEN_Y				= $80		; Y position of current screenspace rendering (0 is screen bottom)
ZP_SCREEN_X_L			= $81		; 16-bit X position of current screenspace rendering (low byte)
ZP_SCREEN_X_H			= $82		; 16-bit X position of current screenspace rendering (high byte)

ZP_HGRPTR_L				= $83		; Pointer to start of a high-res row (low byte)
ZP_HGRPTR_H				= $84		; Pointer to start of a high-res row (high byte)

ZP_CURR_X_BYTE			= $85		; X position of current rendering in bytes (rounded up, see below for remainder)
ZP_CURR_X_BIT			= $86		; Current rendering X position remainder (bit within byte to render at)
ZP_CURR_X_BYTEC 		= $87		; A cache of ZP_CURR_X_BYTE
ZP_CURR_Y				= $88		; Y position of current rendering

ZP_RENDER_CURRBIT		= $89		; Current horizontal bit within byte in VRAM while rendering
ZP_RENDER_CURRBYTE		= $8A		; Current horizontal byte in VRAM while rendering
ZP_RENDER_CURR_W		= $8B		; Current width of image data while rendering, in pixels
ZP_PALETTE				= $8C		; Palette bit to use when blitting

ZP_PAGEMASK				= $8D		; Page flipping state as a bit mask. Holds $00 and $60 on alternate page flips. This is the bit pattern difference between $2000 and $4000 address ranges. Clever!

ZP_IMAGE_W				= $8E		; Width of current rendering image, in pixels
ZP_IMAGE_H				= $8F		; Height of current rendering image, in pixels

ZP_DRAWSCRATCH0			= $90		; Used as a scratch in various drawing routines
ZP_DRAWSCRATCH1			= $91		; Used as a scratch in various drawing routines
ZP_DRAWEND				= $93		; Used as end point for rendering rows or bytes in various routines
ZP_BITSCRATCH			= $94		; Scratch value for bit masks in rendering routines
ZP_PARAM_PTR_L 			= $95		; Pointer to inline params (low byte)
ZP_PARAM_PTR_H			= $96		; Pointer to inline params (high byte)
ZP_PIXELS				= $97		; Stores new pixels to write in various rendering routines
ZP_PIXEL_MASK			= $98		; A mask for pixels within a byte
ZP_PIXELSCRATCH			= $99		; Scratch value for pixels used during rendering
ZP_SPAN_COUNTER			= $9D		; A span counter used during rendering

ZP_INLINE_RTS_L			= $9E		; Return address for MLI-convention calling vector (low byte)
ZP_INLINE_RTS_H			= $9F		; Return address for MLI-convention calling vector (high byte)

ZP_REGISTER_A			= $A0		; A stackless way to save/restore accumulator
ZP_REGISTER_X			= $A1		; A stackless way to save/restore X register
ZP_REGISTER_Y			= $A2		; A stackless way to save/restore Y register

ZP_PSEUDORTS_L			= $A6		; Indirect jump used in parameter unpacking (low byte)
ZP_PSEUDORTS_H			= $A7		; Indirect jump used in parameter unpacking (high byte)

ZP_LEFTCLIP				= $A9		; Amount of sprite to clip from the left, in pixels. Used for rendering at screen edges
ZP_RIGHTCLIP			= $AA		; Amount of sprite to clip from the right, in pixels. Used for rendering at screen edges
ZP_TOPCLIP				= $AB		; Amount to clip off the top of thing we're rendering. Used for sinking/sliding effects
ZP_BOTTOMCLIP			= $AC		; Amount to clip off the bottom of thing we're rendering. Used for sinking/sliding effects
ZP_CLIPBITS				= $AD		; A bit value related to clipping. Exact purpose unclear, but possibly related to clipping on sub-byte boundaries
ZP_LEFTCLIP_BYTES		= $AE		; Amount of sprite to clip from the left, in bytes.
ZP_SOURCE_IMGPTR_L		= $AF		; Pointer into source image during rendering (low byte)
ZP_SOURCE_IMGPTR_H		= $B0		; Pointer into source image during rendering (high byte)
ZP_IMAGE_W_BYTES 		= $B1		; Width of current animating image, in bytes

ZP_SPRITE_TILT_OFFSET	= $B2		; Offset amount for rendering tilted sprites
ZP_SPRITE_TILT_SIGN		= $B3		; Offset direction for rendering tilted sprites. $ff or $01

ZP_UNUSEDB4				= $B4		; Curiously this is initialized to $00 but then never used in the game
ZP_UNUSEDB5				= $B5		; Curiously this is initialized to $00 but then never used in the game
ZP_UNUSEDB6				= $B6		; A scratch value only used in dead code (an abandoned attempt to calculated sprite tilt)
ZP_UNUSEDB7				= $B7		; A scratch value only used in dead code (an abandoned attempt to calculated sprite tilt)
ZP_UNUSEDB8				= $B8		; A scratch value only used in dead code (an abandoned attempt to calculated sprite tilt)

ZP_SPRITE_TILT			= $B9		; Sets tilt of rendered sprites $00 = left tilt, $ff = right tilt

ZP_UNUSEDBA				= $BA		; A tilt parameter for sprite rendering that ended up being unused in the end
ZP_REGISTER				= $BB		; A scratch value used to save and restore random registers in a couple of places

ZP_CURRTILT_OFFSET		= $BC		; Current offset during tilted sprite rendering
ZP_RENDER_CURR_Y		= $BD		; Current Y-position while rendering (bottom relative)
ZP_OFFSET_REMAINING		= $BE		; Offset remaining while rendering tilted
ZP_TILTSCRATCH			= $BF		; A scratch value used in tilted sprite rendering (the real one that shipped)

ZP_WORLD_X_L			= $C0		; 16-bit worldspace X position for current rendering (low byte)
ZP_WORLD_X_H			= $C1		; 16-bit worldspace X position for current rendering (high byte)
ZP_WORLD_Y				= $C2		; Worldspace Y position for current rendering

ZP_SPRITEANIM_PTR_L 	= $C3		; Pointer to a graphic to animate (low byte)
ZP_SPRITEANIM_PTR_H 	= $C4		; Pointer to a graphic to animate (high byte)

ZP_SCREENTOP			= $C5		; Y value of the top of the scroll window. Always $c0 now, but the game likely had vertical scrolling at one point
ZP_SCREENBOTTOM			= $C6		; Y value of the bottom of the scroll window. Always $00 now, but the game likely had vertical scrolling at one point
ZP_LOCALSCROLL_L		= $C7		; A pointer to a scroll position used indirectly for some rendering (low byte). Always points to ZP_SCROLLPOS anyway.
ZP_LOCALSCROLL_H		= $C8		; A pointer to a scroll position used indirectly for some rendering (high byte). Always points to ZP_SCROLLPOS anyway.
