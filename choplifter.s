.include "zeropage.s"

.macro UNUSED byteCount
	.repeat byteCount
		.byte $00
	.endrepeat
.endmacro

.segment "STARTUP"
.segment "LOCODE"


.org $0800
; The sector 0 loader on the floppy jumps to here, but it has not been disassembled for this reverse engineer.
; We will replace it with our own ProDOS-based loader. Since this is a single-load game, we don't need to
; write a full RWTS nor replace any such code in the game.
loaderEntry:	; $0800
		cld
		sei
		sei
		sta		ZP_RND		; Seeds random with whatever is in the accumulator after loader is done. Probably not very random.
		jsr		checkButtonInput
		jsr		jumpInitRendering

		;;;;;;;;;;;;;;;;;;;;;;;;;;;
		; This appears to be leftover testing code that Dan was playing with. The game
		; appears to have supported vertical scrolling at one point, but it either didn't work well
		; for gameplay or he never got it working, so it has been removed. All the vertical scrolling
		; parameters are hardcoded later on and never changed, but here in the loader we find these
		; two little test lines that shipped.
		jsr		jumpSetScrollBottom
				.byte $18,$70
		jsr		jumpSetScrollTop
				.byte $1e,$70
		;;;;;;;;;;;;;;;;;;;;;;;;;;;

		; Resume normal initialization
		jsr		jumpInitHelicopter
		lda		#$00
		sta		ZP_GAMEACTIVE
		jmp		(ZP_LOADERVECTOR_L)			; Points to $09c7 (startDemoMode)

; Begins the animated title sequence, starting with the animated Choplifter logo
startTitleSequence:		; $081f
		jsr     renderStartingGameStateForLoss		; End previous demo sequence
        jsr     jumpInitHelicopter

		lda     #$00
        sta     ZP_FRAME_COUNT

        jsr     jumpSetSpriteAnimPtr
		.word	$a0f2			; Set animation pointer to Broderbund Presents

		jsr		jumpSetAnimLoc	; Set animation screen position		; $082e
				.byte	$1f		; X pos (low byte)
				.byte	$00		; X pos (high byte)
				.byte	$8C		; Y pos, bottom-relative

		lda		#$ff					; Set high palette bit for this animation
		jsr     jumpSetPalette
        lda     #$0A					; Broderbund Presents animation is 10 frames long
        sta     animCounterBrod

animLoopBrod:
		jsr     jumpUpdateSlideAnim		; Render next frame of Broderbund Presents animation
					.byte	$00			; Left clip
					.byte	$00			; Right clip
animCounterBrod:	.byte	$ff			; Amount of image height to render
					.byte 	$00			; Bottom clip amount

        jsr     jumpBlitImage		; $0845
        jsr     jumpFlipPageMask
        jsr     jumpBlitImage
        jsr     jumpFlipPageMask
		dec     animCounterBrod
        bmi     animBeginChoplifter		; Wait for Broderbund Presents to finish
        jsr     checkButtonInput				; Check for button during demo to start game
        bcc     animLoopBrod
        jmp     (ZP_GAMESTART_JMP_L)	; Points to $b5f, to start game

animBeginChoplifter:				; Starts the layered Choplifter logo animation
		clc
        lda     ZP_SCROLLPOS_L
        adc     #$1F
        sta     choplifterLogoState
        lda     ZP_SCROLLPOS_H
        adc     #$00
        sta     choplifterLogoState+1

        lda     choplifterLogoState		; X position for crossed logos
        sta     ZP_RENDERPOS_XL
        lda     choplifterLogoState+1
        sta     ZP_RENDERPOS_XH
        lda     #$69					; Height at which to place crossed logos
        sta     ZP_RENDERPOS_Y

        jsr     jumpSetWorldspace
				.word   $001C					; Pointer to animation data for crossed Choplifter logos (not a real animation, just one frame)

        jsr     jumpSetSpriteAnimPtr			; $880
				.word	$a0f0			; Set animation graphic pointer to Choplifter logo

        jsr     jumpClipToScroll
        lda     #$02
        jsr     jumpSetSpriteTilt
        jsr     jumpFlipPageMask
        jsr     jumpRenderTiltedSpriteLeft				; Render first logo, tilted left (buffer 0)
        jsr     jumpFlipPageMask
        jsr     jumpRenderTiltedSpriteLeft				; Render first logo, tilted left (buffer 1)
        jsr     checkButtonInput
        bcc     animChopNoInput0
        jmp     (ZP_GAMESTART_JMP_L)				; Points to $b5f, to start game

animChopNoInput0:
		lda     #$FE
        jsr     jumpSetSpriteTilt
        jsr     jumpFlipPageMask
        jsr     jumpRenderTiltedSpriteLeft				; Render second logo, tilted left (buffer 0)
        jsr     jumpFlipPageMask
        jsr     jumpRenderTiltedSpriteLeft				; Render second logo, tilted left (buffer 1)
        jsr     checkButtonInput
        bcc     animChopNoInput1
        jmp     (ZP_GAMESTART_JMP_L)				; Points to $b5f, to start game

animChopNoInput1:
		lda     #$02
        jsr     jumpSetSpriteTilt
        jsr     jumpFlipPageMask
        jsr     jumpRenderTiltedSpriteRight				; Render third logo, tilted right (buffer 0)
        jsr     jumpFlipPageMask
        jsr     jumpRenderTiltedSpriteRight				; Render third logo, tilted right (buffer 1)
        jsr     checkButtonInput
        bcc     animChopNoInput2
        jmp     startNewGame						; Start the game when button pushed. Why is this direct, when the other two jumps above are indirect? No idea.

animChopNoInput2:
		lda     #$FE
        jsr     jumpSetSpriteTilt
        jsr     jumpFlipPageMask
        jsr     jumpRenderTiltedSpriteRight				; Render fourth logo, tilted right (buffer 0)
        jsr     jumpFlipPageMask
        jsr     jumpRenderTiltedSpriteRight				; Render fourth logo, tilted right (buffer 1)

        jsr     jumpInitEntityTable

slidingChoplifterLoop:				; $08e7
		inc     ZP_FRAME_COUNT
		lda   	ZP_FRAME_COUNT
        cmp     #$38
        bcc     animChopStartGame
        jmp     startDemoMode					; After $38 frames, escape title animation and start the demo

animChopStartGame:
		lda     ZP_FRAME_COUNT
        cmp     #$02
        bcc     animChopNoInput3			; Not allowed to start game during first two frames of sliding animation. This feels like a hacky bug fix for something. :D
        jsr     checkButtonInput
        bcc     animChopNoInput3
        jmp     startNewGame					; Start the game when button pushed. Why is this direct, when the other two jumps above are indirect? No idea.

animChopNoInput3:
		lda     ZP_FRAME_COUNT
        cmp     #$22
        bcs     animChopDemoNextBuffer
        cmp     #$14
        bcc     animChopDemoNextBuffer

        ldx     #$5D					; Erase all the titles to start demo
        ldy     #$69
        lda     #$80
        jsr     jumpScreenFill

animChopDemoNextBuffer:
		jsr     jumpEraseAllSprites
        jsr     jumpRenderMoonChunk		; Replace the piece of moon we erased above

        lda     ZP_FRAME_COUNT			; Calculate X position of lefthand Choplifter logo based on frame counter
        cmp     #$20
        bcc     animChopLowFrameCount
        lda     #$00
        jmp     animChopRenderSlideLogos

animChopLowFrameCount:
		lda     ZP_FRAME_COUNT
        eor     #$1F
        asl
        asl
        asl
animChopRenderSlideLogos:
		sta     ZP_SCRATCH56
        sec
        lda     choplifterLogoState
        sbc     ZP_SCRATCH56
        sta     ZP_RENDERPOS_XL
        lda     choplifterLogoState+1
        sbc     #$00
        sta     ZP_RENDERPOS_XH
        lda     #$69					; Y position of left-hand sliding choplifter logo
        sta     ZP_RENDERPOS_Y

        jsr     jumpSetWorldspace
        .word   $001C		; Pointer to animation data for left-hand sliding Choplifter logo

        jsr     jumpSetSpriteAnimPtr		; $0945
        .word 	$a0f0		; Set animation graphic pointer to Choplifter logo

        jsr     jumpClipToScroll
        bcs     animChopRenderSlideAnimDone
        lda     #$FF					; Set high palette bit for this animation
        jsr     jumpSetPalette
        jsr     jumpBlitImage

animChopRenderSlideAnimDone:
		inc     ZP_SCRATCH56			; Advance X position
        clc
        lda     choplifterLogoState
        adc     ZP_SCRATCH56
        sta     ZP_RENDERPOS_XL
        lda     choplifterLogoState+1
        adc     #$00
        sta     ZP_RENDERPOS_XH
        lda     #$69					; Y position of right-hand sliding choplifter logo
        sta     ZP_RENDERPOS_Y

        jsr     jumpSetWorldspace
				.word   $001C		; Pointer to animation data for right-hand sliding Choplifter logo

		jsr     jumpClipToScroll		; $0971
        bcs     chopSlideFinished
        lda     ZP_FRAME_COUNT
        cmp     #$14
        bcs     animChopRenderHighFrames
        jsr     jumpBlitImage
        jmp     chopSlideFinished

animChopRenderHighFrames:
		jsr     jumpRenderSpriteRight

chopSlideFinished:
		lda     ZP_FRAME_COUNT				; Wait $20 frames before next animation
        cmp     #$20
        bne     slidingChoplifterContinue
	
        jsr     jumpSetSpriteAnimPtr			; Animate the copyright message
				.word	$a0f4				; Set animation pointer to Dan Gorlin copyright

		jsr		jumpSetAnimLoc				; Set animation parameters
				.byte	$30		; X pos (low byte)
				.byte	$00		; X pos (high byte)
				.byte	$44		; Y pos, bottom-relative

		lda     #$FF		; $0996
        jsr     jumpSetPalette				; Set high palette bit for this animation
        ldx     #$10

chopSlideLoop:
		stx     animCounterChop

        jsr     jumpUpdateSlideAnim
					.byte	$00			; Left clip
					.byte	$00			; Right clip
animCounterChop:	.byte	$00			; Amount of image height to render		$09a5
					.byte	$00			; Bottom clip amount
		
        jsr     jumpBlitImage
        jsr     jumpFlipPageMask
        jsr     jumpBlitImage
        jsr     jumpFlipPageMask
        dex
        bpl     chopSlideLoop

slidingChoplifterContinue:
        jsr     jumpPageFlip
        jsr     jumpFlipPageMask
        lda     ZP_BUFFER			; Swap double buffer
        eor     #$FF
        sta     ZP_BUFFER
        jmp     slidingChoplifterLoop

choplifterLogoState:		; $09c5
	.byte	$00,$00


; Start the self playing demo. This is basically a copy of the main game loop
; with the addition of a big controls table to simulate flying the helicopter
startDemoMode:				; $09c7
		jsr     renderStartingGameStateForLoss		; Reset game state to a good place
        jsr     jumpInitGameState
        jsr     jumpInitHelicopter
        lda     #$00						; Initialize some state
        sta     ZP_FRAME_COUNT
        sta     mainLoopDemoAction			; Start with "positive" actions which send us out to hostages
        jsr     jumpSpawnInitialHostages
        lda     #$00
        sta     CURR_LEVEL

        jsr     jumpInitSlideAnim			; Show Your Mission: Rescue Hostages
        jsr     jumpSetSpriteAnimPtr
				.word $a0ee					; Pointer to Rescue Hostages graphic

		jsr		jumpSetAnimLoc
				.byte	$52		; X pos (low byte)
				.byte	$00		; X pos (high byte)
				.byte	$6e		; Y pos, bottom-relative

		lda		#$ff
        jsr     jumpSetPalette			; Set palette for this animation
        jsr     jumpBlitImage	; Show the Rescue Hostages graphic (as a one frame "animation")
        jsr     jumpPageFlip
        jsr     jumpFlipPageMask
        jsr     jumpBlitImage
        jsr     jumpPageFlip
        jsr     jumpFlipPageMask

; Main demo loop- this is duplicate of the main game loop, slightly stripped down for just what the self-playing demo needs
mainLoopDemo:			; $0a04
		inc     ZP_FRAME_COUNT			; Check if self-play is done
        lda     ZP_FRAME_COUNT
        cmp     #$E0					; Demo is 224 frames out, then 224 frames back. Same flight control table is used both ways. Neat!
        bne     mainLoopDemoDeathCheck
        bit     mainLoopDemoAction
        bpl     mainLoopDemoHeadHome
        jmp     (ZP_STARTTITLE_JMP_L)	; Points to startTitleSequence ($081f)

mainLoopDemoHeadHome:				; After first 224 frames, we turn around and head home
		lda     #$FF
        sta     mainLoopDemoAction	; Switch to "negative" actions
        lda     #$00				; Reinitialize various things to return home
        sta     ZP_VELX_16_L
        sta     ZP_VELX_16_H
        sta     ZP_VELY_16_L
        lda     #$FE
        sta     ZP_VELY_16_H

mainLoopDemoDeathCheck:
		lda     ZP_DYING
        beq     mainLoopDemoFetchControls

        lda     #$02				; During death, kill all control inputs
        sta     ZP_ACCELY			; I think this is insurance because it shouldn't be possible to die in the demo, but maybe the tanks get lucky sometimes
        lda     #$00
        sta     ZP_STICKX
        jsr     processChopTurn
        jmp     mainLoopDemoDeathCheck2

mainLoopDemoFetchControls:		; 0a37
        lda     ZP_FRAME_COUNT			; Fetch next demo control actions based on time
        and     #$F8					; Calculate row in flight control table
        lsr
        tax
        lda     mainLoopDemoTable,x		; Y acceleration taken directly from table
        sta     ZP_ACCELY

        lda     mainLoopDemoTable+1,x	; X acceleration is magnitude only in the table
        bit     mainLoopDemoAction		; Take sign from current action
        bpl     mainLoopDemoPosX		; Positive X acceleration
        eor     #$FF					; Otherwise negate acceleration to match action
        clc
        adc     #$01
mainLoopDemoPosX:
		sta     ZP_STICKX

        lda     mainLoopDemoTable+2,x	; Facing is taken from the table, but also modified
        bit     mainLoopDemoAction
        bpl     mainLoopDemoPosFace		; Negate facing if action is negative
        eor     #$FF
        clc
        adc     #$01
mainLoopDemoPosFace:
		sta     CHOP_FACE

        lda     mainLoopDemoTable+3,x	; Decide when to shoot
        beq     mainLoopDemoNoShoot
        eor     mainLoopDemoAction		; We shoot at different times going out or back, but using same control table
        bmi     mainLoopDemoNoShoot
        jsr     joystick0Push			; Fake joystick buttons to shoot. A wee-bit hacky, but I guess it was easiest :)
        jsr     clearButton0

mainLoopDemoNoShoot:		; $0a71
		lda     ZP_AIRBORNE				; If we're on the ground, sit and wait for hostages to load or unload
        beq     mainLoopDemoDeathCheck2
        jsr     processChopTurn

mainLoopDemoDeathCheck2:
		lda     ZP_DEATHTIMER
        beq     mainLoopDemoStillAlive

        clc								; Process death animation during demo, just in case we did die somehow
        lda     ZP_DEATHTIMER
        adc     #$05
        sta     ZP_DEATHTIMER
        bpl     mainLoopDemoStillAlive
        jmp     startTitleSequence		; Go back to titles when we finish dying

mainLoopDemoStillAlive:
		jsr     checkButtonInput				; Watch for player starting game
        bcc     mainLoopDemoNoInput
        jmp     (ZP_GAMESTART_JMP_L)

mainLoopDemoNoInput:
		jsr     jumpEraseAllSprites		; Erase everything so we can render again
        jsr     jumpRenderStars			; Render starfield
        jsr     jumpRenderMoon			; Render the moon
        jsr     jumpTableScroll			; Handle terrain scrolling
        jsr     jumpRenderMountains		; Render the mountains
        jsr     jumpRenderBase			; Render the home base
        jsr     jumpRenderFence			; Render the security fence
        jsr     jumpRenderHouses		; Render the hostage houses
        jsr     jumpUpdateHostages		; Renders the little dudes
        jsr     jumpSpawnEnemies		; Spawns enemies, as needed
        jsr     jumpUpdateEntities		; Updates all game objects
        jsr     jumpDefragmentEntityList

        jsr     jumpPageFlip			; Swap render buffers
        jsr     jumpFlipPageMask
        lda     #$FF
        eor     ZP_BUFFER
        sta     ZP_BUFFER

        bit     mainLoopDemoAction
        bmi     mainLoopDemoContinue
        lda     ZP_FRAME_COUNT			; After $30 frames, erase the Rescue Hostages banner shown while demo runs
        cmp     #$30
        beq     mainLoopDemoEraseBanner
        cmp     #$31					; Kind of a hack to make sure both buffers get erased :)
        beq     mainLoopDemoEraseBanner		; $0acd

mainLoopDemoContinue:
		jmp     mainLoopDemo

mainLoopDemoEraseBanner:
		ldx 	#$50					; Erases "Rescue Hostages" banner once demo starts self-playing
		ldy		#$70
		lda		#$80
		jsr		jumpScreenFill
		jmp     mainLoopDemo

mainLoopDemoAction:	; $0ade
	.byte	$ff		; $00 = On our way out to get hostages, or $ff = On our way home. The same control table does both!



; A table of flight control actions for running the demo. Current action is "going out" or "heading home"
; Each frame, a struct of four bytes is used:
; 0: Y Velocity
; 1: X Acceleration, with sign taken from high bit of current action
; 2: Facing, with sign taken from high bit of current action
; 3: Shooting, modified with current action
mainLoopDemoTable:				; $0adf
	.byte	$0D,$05,$00,$FF
	.byte	$0B,$05,$FF,$00
	.byte	$0A,$05,$FF,$00
	.byte	$0B,$05,$FF,$FF
	.byte	$0A,$05,$FF,$00
	.byte	$08,$05,$FF,$00
	.byte	$0B,$05,$FF,$00
	.byte	$0A,$05,$FF,$00
	.byte	$0A,$05,$FF,$00
	.byte	$0B,$05,$FF,$00
	.byte	$0B,$05,$FF,$00
	.byte	$0B,$05,$FF,$00
	.byte	$09,$03,$FF,$00
	.byte	$0A,$FE,$FF,$44
	.byte	$0B,$05,$FF,$00
	.byte	$0B,$05,$FF,$00
	.byte	$09,$00,$FF,$00
	.byte	$0A,$FB,$01,$44
	.byte	$09,$FB,$01,$00
	.byte	$09,$05,$00,$00
	.byte	$06,$00,$00,$00
	.byte	$06,$00,$00,$00
	.byte	$06,$00,$00,$00
	.byte	$06,$00,$00,$00
	.byte	$06,$00,$00,$00
	.byte	$06,$00,$00,$00
	.byte	$06,$00,$00,$00
	.byte	$06,$00,$00,$00
	.byte	$06,$00,$00,$00
	.byte	$06,$00,$00,$00
	.byte	$06,$00,$00,$00
	.byte	$06,$00,$00,$00


startNewGame:			; $0b5f
		jsr     renderStartingGameState		; Initialize game state
        lda     #$FF
        sta     ZP_GAMEACTIVE
        jsr     jumpInitGameState

        lda     #$03				; Play a little game start medley
        sta     ZP_SCRATCH56
startNewGameSoundLoop:
		lda     ZP_SCRATCH56
        asl
        asl
        asl
        asl
        asl
        clc
        adc     #$30
        tax							; Frequency
        ldy     #$30				; Duration
        lda     #$00				; Decay
        jsr     jumpPlaySound
        ldx     #$43				; Frequency
        ldy     #$30				; Duration
        lda     #$00				; Decay
        jsr     jumpPlaySound
        ldx     #$61				; Frequency
        ldy     #$30				; Duration
        lda     #$00				; Decay
        jsr     jumpPlaySound
        dec     ZP_SCRATCH56
        bne     startNewGameSoundLoop

        jsr     jumpSpawnInitialHostages
        jmp     (ZP_GAMEINIT_L)		; Holds $0b9b. Seems unnecessary, but maybe was a debugging tool

beginSortie:
		lda     SORTIE				; $0b9b
        cmp     #$03				; Three lives for you
        bne     sortiesAvailable
        jmp     gameOverLoss		; Game over man, game over!
sortiesAvailable:
		jsr     renderStartingGameState
        jsr     jumpInitHelicopter
        lda     #$00				; Reset frame time for the new sortie
        sta     ZP_FRAME_COUNT

sortieBannerLoop:
        inc     ZP_FRAME_COUNT
        lda     ZP_FRAME_COUNT
        cmp     #$18
        bcc     beginSortieWait			; Pause for $18 frames before next sortie really starts
        inc     SORTIE					; Increment sortie and let's go!
        jmp     (ZP_NEWSORTIE_JMP_L)	; Holds $0c13

beginSortieWait:
		jsr     checkButtonInput
        jsr     jumpEraseAllSprites
        jsr     jumpRenderStars
        jsr     jumpRenderMoon
        jsr     jumpRenderMountains
        jsr     jumpRenderBase

        jsr     jumpInitSlideAnim	; Render "X Sortie" banner
        lda     #$FF
        jsr     jumpSetPalette
        lda     SORTIE
        cmp     #$01
        beq     renderSortieTwo
        jsr     jumpSetAnimLoc
				.byte	$5f		; X pos (low byte)
				.byte	$00		; X pos (high byte)
				.byte	$6B		; Y pos, bottom-relative

        jmp     renderSortieBanner

renderSortieTwo:	; Second sortie renders shifted so we get a different palette
		jsr     jumpSetAnimLoc
				.byte	$59		; X pos (low byte)
				.byte	$00		; X pos (high byte)
				.byte	$6B		; Y pos, bottom-relative

renderSortieBanner:
		lda     SORTIE			; Find correct sortie banner art
        asl
        tax
        lda     sortieGraphicsTable,x
        sta     ZP_SPRITE_PTR_L
        lda     sortieGraphicsTable+1,x
        sta     ZP_SPRITE_PTR_H

        jsr     jumpSetSpriteAnimPtr		; Set title art pointer to what we just found
				.word $001a
        
        jsr     jumpBlitImage	; Render the banner (as a single frame "animation")
        jsr     jumpPageFlip
        jsr     jumpFlipPageMask
        lda     #$FF
        eor     ZP_BUFFER
        sta     ZP_BUFFER
        jmp     sortieBannerLoop

		; When sortie banner is done, we jump indirectly to here and fall through to main game loop
        jsr     renderStartingGameState			; $0c13
        lda     #$00
        sta     ZP_FRAME_COUNT

;
; MAIN GAME LOOP
;
mainLoop:										; $0c1a
        inc     ZP_FRAME_COUNT
        lda     #$00
        sta     HOSTAGE_FIRSTLOAD
        sta     HOSTAGE_FIRSTDEATH
        sta     ALIEN_ODDFRAME
        lda     TOTAL_RESCUES			; Check for victory condition
        cmp     #$40
        bne     mainLoopNormal
        jmp     mainLoopEndGame
mainLoopNormal:
		clc
        adc     HOSTAGES_KILLED			; Check for game failure on hostage deaths
        cmp     #$40
        bne     mainLoopNoLossYet
        jmp     (ZP_INDIRECT_JMP_L)		; Goes to 0c92 (gameOverLoss) in normal gameplay

mainLoopNoLossYet:
		lda     ZP_DEATHTIMER			; Track death animation
        beq     mainLoopRoutines
        clc
        adc     #$06
        sta     ZP_DEATHTIMER
        bpl     mainLoopRoutines
        jmp     beginSortie

mainLoopRoutines:
		jsr     checkButtonInput				; Check keyboard (and kinda joystick buttons)
        jsr     jumpTableJoystickY		; Check current joystick Y axis
        jsr     checkJoystick1			; Handle joystick button 1
        jsr     checkJoystick0			; Handle joystick button 0
        jsr     jumpEraseAllSprites		; Erase everything so we can draw again
        jsr     jumpRenderStars			; Renders background starfield
        jsr     jumpRenderMoon			; That's no... nevermind
        jsr     jumpTableScroll			; Appears to handle map scrolling?
        jsr     jumpRenderMountains		; Renders the mountain ranges
        jsr     checkJoystick0			; Handle joystick button 0 again
        jsr     jumpRenderBase			; Renders the base building and landing pad
        jsr     jumpRenderFence			; Renders the fence line left of the base
        jsr     jumpRenderHouses		; Renders the houses holding the hostages
        jsr     jumpUpdateHostages		; Renders the little dudes
        jsr     checkJoystick0			; Handle joystick button 0 yet again
        jsr     jumpTableJoystickX		; Check current joystick X axis
        jsr     jumpSpawnEnemies		; Spawns enemies, as needed
        jsr     jumpUpdateEntities		; Update all game objects
        jsr     jumpDefragmentEntityList	; Maintains a master entity ID array
        jsr     jumpPageFlip			; Flip graphics buffers in hardware
        jsr     jumpFlipPageMask		; Flip page mask
        lda     ZP_BUFFER				; Swap render buffers in game state
        eor     #$FF
        sta     ZP_BUFFER

        jmp     mainLoop				; Shazam, it's a game


gameOverLoss:		; $0c92 Victory condition indirect jump arrives here
		lda     #$00
        sta     ZP_FRAME_COUNT
        lda     #$00					; Player has lost due to hostages
        sta     mainLoopEndGameWon
        lda     #$00
        sta     ZP_GAMEACTIVE
        jmp     mainLoopEndGameLoop


mainLoopEndGame:		; $0ca2 Called when 64th hostage is rescued
		lda     #$00
        sta     ZP_FRAME_COUNT
        lda     #$FF					; Player has won!
        sta     mainLoopEndGameWon
        lda     #$00
        sta     ZP_GAMEACTIVE
mainLoopEndGameLoop:
        inc     ZP_FRAME_COUNT
        lda     ZP_FRAME_COUNT
        cmp     #$20
        bcc     mainLoopEndGameRoutines
        jmp     startTitleSequence		; Go back to title animations

mainLoopEndGameRoutines:
		lda     #$02					; Force helicopter to settle down for victory sequence
        sta     ZP_ACCELY
        lda     #$00
        sta     ZP_STICKX
        jsr     processChopTurn	; A subset copy of the main loop routines run during the end game sequence
        jsr     checkButtonInput
        jsr     jumpEraseAllSprites
        jsr     jumpRenderStars
        jsr     jumpRenderMoon
        jsr     jumpTableScroll
        jsr     jumpRenderMountains
        jsr     jumpRenderBase
        jsr     jumpRenderFence
        jsr     jumpRenderHouses
        jsr     jumpUpdateHostages
        jsr     jumpUpdateEntities
        jsr     jumpDefragmentEntityList
        jsr     jumpInitSlideAnim
        lda     #$FF					; Set high palette bit
        jsr     jumpSetPalette
        jsr     jumpSetAnimLoc
				.byte $75		; X pos (low byte)
				.byte $00		; X pos (high byte)
				.byte $70		; Y pos
		
		bit		mainLoopEndGameWon		; $0cf7
		bmi		mainLoopEndGameWinSprite
        jsr     jumpSetSpriteAnimPtr
				.word $a0f6				; Pointer to The End sprite
		
		jmp     mainLoopEndGameFinalize

mainLoopEndGameWinSprite:				; $0d04
        jsr     jumpSetSpriteAnimPtr
				.word	$a0f8			; Pointer to Broderbund Crown logo
        
mainLoopEndGameFinalize:
		jsr		jumpBlitImage	; Render, flip buffers, and loop
		jsr		jumpPageFlip
		jsr		jumpFlipPageMask
        lda     #$FF
        eor     ZP_BUFFER
        sta     ZP_BUFFER
        jmp     mainLoopEndGameLoop

mainLoopEndGameWon:		; $0d1b			; $00 = Player lost, $ff = Player won
		.byte	$00



; Renders everything needed to get the game into the initial state for gameplay (back at the base, etc)
renderStartingGameState:	; $0d1c
		lda     #$FF					; Assume victory on all new games
        sta     mainLoopEndGameWon1
        jmp     renderGameSetup

renderStartingGameStateForLoss:				; Called after time passes on loss condition (The End screen)	$0d24
		lda     #$00
        sta     mainLoopEndGameWon1

renderGameSetup:
        lda     SCROLL_START_L		; Initialize scrolling position
		sta		ZP_SCROLLPOS_L
        lda     SCROLL_START_H
        sta     ZP_SCROLLPOS_H

        jsr     jumpSetLocalScroll
				.word $0072			; Points to ZP_SCROLLPOS anyway
        
        jsr     jumpEraseAllSprites

        ldx     TITLEREGION_TOP			; Erase any titles that might still be there
        inx
        ldy     TITLEREGION_BOT
        lda     #$80
        jsr     jumpScreenFill

        jsr     jumpRenderStars1
        jsr     jumpRenderMoon
        jsr     jumpRenderMountains
        bit     mainLoopEndGameWon1			; Hide the base at demo end
        bpl     renderGameSetupSkipBase
        jsr     jumpRenderBase

renderGameSetupSkipBase:
		jsr     jumpPageFlip
        jsr     jumpFlipPageMask
        lda     #$FF
        eor     ZP_BUFFER
        sta     ZP_BUFFER
        jsr     jumpEraseAllSprites

        ldx     TITLEREGION_TOP				; Erase any titles that might still be there
        inx
        ldy     TITLEREGION_BOT
        lda     #$80
        jsr     jumpScreenFill

        jsr     jumpRenderStars1
        jsr     jumpRenderMoon
        jsr     jumpRenderMountains
        bit     mainLoopEndGameWon1			; Hide the base at demo end
        bpl     renderGameSetupSkipBase2
        jsr     jumpRenderBase

renderGameSetupSkipBase2:
		jsr     jumpPageFlip				; Flip the buffers and we're done
        jsr     jumpFlipPageMask
        lda     #$FF
        eor     ZP_BUFFER
        sta     ZP_BUFFER
        rts						; 0d90

mainLoopEndGameWon1:
		.byte	$ff				; 0d91			; $00 = Player lost/demo, $ff = Player won


; Checks for any form of button input (keyboard or joystick buttons).
; Returns carry set if something was detected. For keyboard, we do some
; processing of that input as well. Cheat keys will be checked, etc
checkButtonInput:						; $0d92
		lda     $C000			; Check any key
		cmp     #$80
		bcs     keyPushed
		lda     $C061			; Button 0
		cmp     #$80
		bcs     joystickPushed
		lda     $C062			; Button 1
		cmp     #$80
		bcs     joystickPushed
		clc						; Nothing pushed - clear carry and return
		rts

joystickPushed:					; Joystick button- set carry and return
		sec
		rts

keyPushed:						; High bit will still be set on these
		bit     $C010			; Clear strobe
        cmp     #$93			; Ctrl-S toggles sound
        bne     checkV
        lda     #$FF
        eor     PREFS_SOUND
        sta     PREFS_SOUND
        jmp     doneHandled
checkV:
		cmp     #$96			; Ctrl-V flips vertical joystick
        bne     checkA
        lda     #$FF
        eor     PREFS_JOY_Y
        sta     PREFS_JOY_Y
        jmp     doneHandled
checkA:
		cmp     #$81			; Ctrl-A flips horizontal joystick
        bne     checkESC
        lda     #$FF
        eor     PREFS_JOY_X
        sta     PREFS_JOY_X
        jmp     doneHandled
checkESC:
		cmp     #$9B			; ESC pauses game
        bne     checkL
pauseLoop:
		lda     $C000			; Wait for another key to unpause
        bpl     pauseLoop
        cmp     #$9B
        bne     keyPushed		; Handle preference keys while paused
        bit     $C010			; Clear strobe
        clc						; Don't count this second unpause key as "input detected"
        rts

checkL:
		cmp     #$8C			; Ctrl-L is a secret debug tool to set difficulty level
        bne     doneHandled
pauseLoopL:
		lda     $C000
        bpl     pauseLoopL		; Wait for level selection
        and     #$03			; Any key with 0-7 low bits will work, including number keys, conveniently
        sta     CURR_LEVEL
        bit     $C010
        clc						; Don't count this second unpause key as "input detected"
        rts

doneHandled:
		sec						; Carry set means key was detected, even if we handled it
		rts


; Checks the state of joystick button 0, and reacts to it during gameplay
checkJoystick0:					; $0e02
		lda     $C061			; Check button 0
        cmp     #$80
        bcs     joystick0Push
clearButton0:					; Demo code JSRs into here, piggyback style
        lda     #$00			; Button not down, so clear state and we're done
        sta     buttonZeroDown
        rts
joystick0Push:					; Demo code JSRs into here, piggyback style
		bit     ZP_BTN0DOWN
        bmi     joystickDone	; Joystick button already down
        lda     buttonZeroDown
        bne     joystickDone
        lda     #$FF
        sta     buttonZeroDown
								; Slightly hacky, but shooting conditions are checked directly here instead of in shooting routines
        lda     ZP_AIRBORNE		; Can't shoot on the ground
        beq     joystickDone
        lda     ZP_DYING		; Can't shoot while dying
        bne     joystickDone
        lda     CURR_SHOTS		; Can't shoot more than five times at once
        cmp     #$05
        bcs     joystickDone
        lda     #$FF			; Track that button zero is down
        sta     ZP_BTN0DOWN
        ldx     #$30			; Play shoot sound
        ldy     #$20
        lda     #$01
        jsr     jumpPlaySound
joystickDone:
		rts

buttonZeroDown:				; $0e3a
		.byte $00			; $ff if button zero is down




; Checks the state of joystick button 1, and reacts to it during gameplay
checkJoystick1:			; 0e3b:
		lda     $C062		; Check joystick button 1
        cmp     #$80
											; Slightly hacky, but rotation conditions are checked directly here, instead of in flight control routines
        bcc     checkJoystick1NoTurn		; Button not down so we're done
        lda     ZP_AIRBORNE
        beq     checkJoystick1NoTurn		; Can't rotate when on the ground
        lda     ZP_DYING
        bne     checkJoystick1NoTurn		; Can't rotate during death animation
        lda     buttonOneDown
        bne     processChopTurn		; Button already down
        lda     #$FF
        sta     buttonOneDown				; Button 1 now down
        lda     ZP_TURN_STATE
        beq     beginTurn
        cmp     #$01
        beq     beginTurn
        cmp     #$FF
        beq     beginTurn
        jmp     continueTurn
beginTurn:
		lda     #$00						; Clear turn request so turn can begin
        sta     CHOP_TURN_REQUEST
        bit     CHOP_STICKX					; Determine direction to go
        bmi     turnToLeft
        jmp     turnToRight
continueTurn:
        lda     ZP_TURN_STATE
        sta     CHOP_TURN_REQUEST			; During turn, we cache state in the request
        bmi     turnToRight
        jmp     turnToLeft
turnToRight:
		lda     #$01
        sta     CHOP_FACE					; Turn chopper to the right (internally the turn is instant)
        jmp     processChopTurn
turnToLeft:
		lda     #$FF
        sta     CHOP_FACE					; Turn chopper to the left (internally the turn is instant)
        jmp     processChopTurn

checkJoystick1NoTurn:						; No new turn permitted, but finish any existing one that is underway
		lda     buttonOneDown
        beq     processChopTurn
        lda     #$00
        sta     buttonOneDown
        lda     ZP_TURN_STATE
        beq     neutralStick
        cmp     #$01
        beq     neutralStick
        cmp     #$FF
        beq     neutralStick
        lda     CHOP_TURN_REQUEST
        beq     checkRight
        eor     ZP_TURN_STATE
        bmi     checkRight
neutralStick:
		lda     #$00
        sta     CHOP_FACE					; Turn chopper to face camera
        jmp     processChopTurn
checkRight:
		bit     ZP_TURN_STATE
        bmi     leftStick
        lda     #$01
        sta     CHOP_FACE					; Turn chopper to the right
        jmp     processChopTurn
leftStick:
		lda     #$FF
        sta     CHOP_FACE					; Turn chopper to the left


; Processes a chopper turn that is underway. We fall through to here from above,
; but this is also a self-contained subroutine called from elsewhere in the game
processChopTurn:				; 0ec2
		lda     CHOP_FACE
        beq     facingCamera
        bpl     facingRight
        bmi     facingLeft
facingCamera:
		clc					; When facing camera, turn direction is mapped from acceleration
        lda     ZP_ACCELX
        adc     #$05
        tax
        lda     facingTurnTable,x
        jmp     checkTurn
facingRight:
		lda     #$05
        jmp     checkTurn
facingLeft:
		lda     #$FB
checkTurn:
		cmp     ZP_TURN_STATE		; Never turn through zero all at once
        beq     turningDone

        clc							; Check where we are in the turn and where we need to go
        adc     #$05
        sta     ZP_SCRATCH58
        clc
        lda     ZP_TURN_STATE
        adc     #$05
        sec
        sbc     ZP_SCRATCH58
        bmi     checkLeft
        cmp     #$02
        bcc     turningLeft
        jmp     turningLeftHard
checkLeft:
		cmp     #$FF
        bcs     turningRight
        jmp     turningRightHard
turningLeft:
		dec     ZP_TURN_STATE
        jmp     turningDone
turningLeftHard:
        dec     ZP_TURN_STATE
        dec     ZP_TURN_STATE
        jmp     turningDone
turningRight:
		inc     ZP_TURN_STATE
        jmp     turningDone
turningRightHard:
        inc     ZP_TURN_STATE
        inc     ZP_TURN_STATE
turningDone:
		rts

buttonOneDown:				; $0f15
		.byte 0				; ; $ff if button one is down


facingTurnTable:	; $0f16 Maps acceleration direction to turn request when facing camera
		.byte $01,$01,$00,$00,$00,$00,$00,$00,$00,$00,$FF,$FF


; $0f22
; 222 Unused bytes. There are what look like possible fragments of valid code in here, but nothing
; in the game ever calls into this area, so at best it appears to be dead code. It's possible this is
; part of the copy protection or loader. I'm including these bytes just in case
	.byte	$A2,$7F,$8E,$32,$0F,$18,$8A,$69,$40,$8D,$35,$0F,$A0,$00,$B9,$00,$00,$99,$00,$00,$C8,$D0,$F7,$CA,$E0,$1F,$D0,$E6,$60,$20,$6F,$FD
	.byte	$E0,$00,$F0,$4F,$AD,$00,$02,$C9,$83,$D0,$0C,$A2,$1A,$20,$CD,$0A,$68,$68,$68,$68,$68,$68,$60,$A0,$1D,$B9,$2B,$13,$99,$74,$13,$A9
	.byte	$A0,$99,$2B,$13,$88,$10,$F2,$A0,$FF,$C8,$D9,$00,$02,$F0,$FA,$B9,$00,$02,$C9,$C0,$90,$54,$C9,$E0,$B0,$50,$A2,$00,$B9,$00,$02,$C9
	.byte	$8D,$F0,$90,$C9,$AC,$F0,$43,$9D,$2B,$13,$C8,$E8,$E0,$1E,$90,$EC,$4C,$15,$0F,$2C,$00,$19,$10,$29,$A2,$12,$20,$CD,$0A,$A2,$1D,$20
	.byte	$CD,$0A,$20,$6F,$FD,$AD,$00,$02,$C9,$D9,$F0,$0D,$C9,$CE,$F0,$88,$20,$3A,$FF,$20,$1A,$FC,$4C,$9F,$0F,$A9,$08,$8D,$F9,$18,$20,$66
	.byte	$12,$A9,$05,$8D,$F9,$18,$20,$66,$12,$60,$A2,$14,$20,$F0,$0A,$20,$1A,$FC,$20,$1A,$FC,$20,$1A,$FC,$A2,$1D,$BD,$74,$13,$9D,$2B,$13
	.byte	$CA,$10,$F7,$4C,$3A,$0F,$A0,$2C,$A9,$00,$99,$0F,$19,$88,$10,$FA,$AD,$1D,$13,$8D,$FE,$18,$AD,$1F,$13,$8D,$FF,$18,$AD,$25



; $1000  Gosh, Dan sure likes jump tables. This is the first of many.
jumpBlitRect:					jmp     blitRect				; $1000
jumpInitRendering:				jmp     initRendering			; $1003
jumpEnableHiResGraphics:		jmp     enableHiResGraphics		; $1006
jumpClearScreen:				jmp     clearScreen				; $1009
jumpScreenFill:					jmp     screenFill				; $100c
jumpInitPageMask:				jmp     initPageMask			; $100f
jumpFlipPageMask:				jmp     flipPageMask			; $1012
jumpPageFlip:					jmp     pageFlip				; $1015
jumpInitSlideAnim:				jmp     initSlideAnim			; $1018
jumpBlitImage:					jmp     blitImage				; $101b
jumpBlitImageFlip:				jmp     blitImageFlip			; $101e
jumpRenderSpriteRight:			jmp     renderSpriteRight		; $1021
jumpRenderSpriteLeft:			jmp     renderSpriteLeft		; $1024
jumpRenderSprite:				jmp     renderSprite			; $1027
jumpRenderSpriteFlip:			jmp     renderSpriteFlip		; $102a
jumpRenderTiltRightDeadCode:	jmp     renderTiltRightDeadCode	; $102d
jumpRenderTiltLeftDeadCode:		jmp     renderTiltLeftDeadCode	; $1030
jumpRenderTiltedSpriteLeft:		jmp     renderTiltedSpriteLeft	; $1033
jumpRenderTiltedSpriteRight:	jmp     renderTiltedSpriteRight	; $1036
jumpBlitAlignedImage:			jmp     blitAlignedImage		; $1039
jumpSetAnimLoc:					jmp     setAnimLoc				; $103c
jumpSetBlitPos:					jmp     setBlitPos				; $103f
jumpSetPalette:					jmp     setPalette				; $1042
jumpUpdateSlideAnim:			jmp     updateSlideAnim			; $1045
jumpSetSpriteTilt:				jmp     setSpriteTilt			; $1048
jumpSetImagePtr:				jmp     setImagePtr				; $104b
jumpSetSpriteAnimPtr:			jmp     setSpriteAnimPtr		; $104e
jumpSetWorldspaceDeadCode:		jmp     setWorldspaceDeadCode	; $1051
jumpSetWorldspace:				jmp     setWorldspace			; $1054
jumpSetLocalScroll:				jmp     setLocalScroll			; $1057
jumpSetScrollBottom:			jmp     setScrollBottom			; $105a
jumpSetScrollTop:				jmp     setScrollTop			; $105d
jumpClipToScroll:				jmp     clipToScroll			; $1060



; Finds a pointer to inline parameters for the routine that calls us (parameters will be at caller's caller's return address)
; Returns to caller with an indirect jump so we don't mess up the stack
findParamPointer:		; $1063
		clc
        pla								; Pull our own return address of the stack and stash it
        adc     #$01
        sta     ZP_PSEUDORTS_L
        pla
        adc     #$00
        sta     ZP_PSEUDORTS_H

        pla								; Pull caller's return address as our parameter pointer
        sta     ZP_PARAM_PTR_L
        pla
        sta     ZP_PARAM_PTR_H
        inc     ZP_PARAM_PTR_L			; Advance pointer one byte to get to parameters
        bne     findParamPointerDone
        inc     ZP_PARAM_PTR_H
findParamPointerDone:
		jmp     (ZP_PSEUDORTS_L)		; Return to caller of this routine without touching stack state



; Fetches an inline pointer from a caller's caller and stashes it in ZP_PARAM_PTR
unpackInlinePointer:							; $107d
        clc
        pla								; Pull our own return address of the stack and stash it
        adc     #$01
        sta     ZP_PSEUDORTS_L
        pla
        adc     #$00
        sta     ZP_PSEUDORTS_H

        pla								; Pull caller's desired call routine off stack and stash it
        sta     ZP_INLINE_RTS_L
        pla
        sta     ZP_INLINE_RTS_H
        inc     ZP_INLINE_RTS_L
        bne     unpackInlinePointer_Continue
        inc     ZP_INLINE_RTS_H

unpackInlinePointer_Continue:
		ldy     #$00					; Find the inline pointer and stash it
        lda     (ZP_INLINE_RTS_L),y
        sta     ZP_PARAM_PTR_L
        iny
        lda     (ZP_INLINE_RTS_L),y
        sta     ZP_PARAM_PTR_H
        clc
        lda     ZP_INLINE_RTS_L			; Advance caller's return vector past the inline pointer
        adc     #$02
        sta     ZP_INLINE_RTS_L
        lda     ZP_INLINE_RTS_H
        adc     #$00
        sta     ZP_INLINE_RTS_H
        jmp     (ZP_PSEUDORTS_L)		; Return to caller of this routine without touching stack state




; Set screen location of next title-slide animation. Preserves registers.
; This is only used for title card animations, but the zero page locations like ZP_ANIM_*
; are used in other animation and rendering contexts, so don't get confused.
setAnimLoc:			; $10af
		sta     ZP_REGISTER_A				; Save registers for pointer math
        sty     ZP_REGISTER_Y
        jsr     findParamPointer		; Fetch the three parameter bytes
        ldy     #$00
        lda     (ZP_PARAM_PTR_L),y
        sta     ZP_SCREEN_X_L
        iny
        lda     (ZP_PARAM_PTR_L),y
        sta     ZP_SCREEN_X_H
        iny
        lda     (ZP_PARAM_PTR_L),y
        sta     ZP_SCREEN_Y
        clc								; Advance rts pointer past our parameters
        lda     ZP_PARAM_PTR_L
        adc     #$03
        sta     ZP_PARAM_PTR_L
        lda     ZP_PARAM_PTR_H
        adc     #$00
        sta     ZP_PARAM_PTR_H
        lda     ZP_REGISTER_A				; Restore registers after pointer math
        ldy     ZP_REGISTER_Y
        jmp     (ZP_PARAM_PTR_L)		; Return to caller, skipping over parameters



; Sets up to blit an image by pulling X and Y destination on screen from
; a data structure pointed to by the caller (inline)
setBlitPos:							; $10da
        sta     ZP_REGISTER_A				; Save registers for pointer math
        sty     ZP_REGISTER_Y
        jsr     unpackInlinePointer		; Find parameters and jump vector
        ldy     #$00					; Cache inline parameters
        lda     (ZP_PARAM_PTR_L),y
        sta     ZP_SCREEN_X_L
        iny
        lda     (ZP_PARAM_PTR_L),y
        sta     ZP_SCREEN_X_H
        iny
        lda     (ZP_PARAM_PTR_L),y
        sta     ZP_SCREEN_Y
        lda     ZP_REGISTER_A				; Restore registers
        ldy     ZP_REGISTER_Y
        jmp     (ZP_INLINE_RTS_L)		; Jump to caller's desired vector



; Takes sign bit of accumulator to use as the palette for subsequent blitting
setPalette:				; $10f8
		and     #$80
        sta     ZP_PALETTE
        rts


; Updates a "title slide" style animation with new state taken from caller. Preserves registers
; Takes four inline parameters from caller and sets them as the animation state
updateSlideAnim:					; $10fd
		sta     ZP_REGISTER_A
        sty     ZP_REGISTER_Y
        jsr     findParamPointer	; Stash inline parameters from caller
        ldy     #$00
        lda     (ZP_PARAM_PTR_L),y
        sta     ZP_LEFTCLIP
        iny
        lda     (ZP_PARAM_PTR_L),y
        sta     ZP_RIGHTCLIP
        iny
        lda     (ZP_PARAM_PTR_L),y
        sta     ZP_TOPCLIP
        iny
        lda     (ZP_PARAM_PTR_L),y
        sta     ZP_BOTTOMCLIP
        clc							; Advance return pointer past parameters
        lda     ZP_PARAM_PTR_L
        adc     #$04
        sta     ZP_PARAM_PTR_L
        lda     ZP_PARAM_PTR_H
        adc     #$00
        sta     ZP_PARAM_PTR_H
        lda     ZP_REGISTER_A			; Restore registers
        ldy     ZP_REGISTER_Y
        jmp     (ZP_PARAM_PTR_L)	; Return to caller without touching stack



; Fetches an inline image pointer from the caller and caches it for the rendering
; operation. Preserves registers.
setImagePtr:						; $112d
        sta     ZP_REGISTER_A			; Save registers
        sty     ZP_REGISTER_Y
        jsr     findParamPointer	; Finder the pointer to caller's inline params
        ldy     #$00
        lda     (ZP_PARAM_PTR_L),y
        sta     ZP_SPRITEANIM_PTR_L	; Copy the sprite pointer
        iny
        lda     (ZP_PARAM_PTR_L),y
        sta     ZP_SPRITEANIM_PTR_H
        clc
        lda     ZP_PARAM_PTR_L		; Calculate our pesudo-RTS past the parameters
        adc     #$02
        sta     ZP_PARAM_PTR_L
        lda     ZP_PARAM_PTR_H
        adc     #$00
        sta     ZP_PARAM_PTR_H
        lda     ZP_REGISTER_A			; Restore registers
        ldy     ZP_REGISTER_Y
        jmp     (ZP_PARAM_PTR_L)	; Pseudo-RTS



; Initializes pointer to the title graphic to animate. Uses inline parameters at caller.
setSpriteAnimPtr:					; $1153
		sta     ZP_REGISTER_A
        sty     ZP_REGISTER_Y
        jsr     unpackInlinePointer
        ldy     #$00
        lda     (ZP_PARAM_PTR_L),y
        sta     ZP_SPRITEANIM_PTR_L
        iny
        lda     (ZP_PARAM_PTR_L),y
        sta     ZP_SPRITEANIM_PTR_H
        lda     ZP_REGISTER_A
        ldy     ZP_REGISTER_Y
        jmp     (ZP_INLINE_RTS_L)



; This is an alternate version of setWorldspace below. This is never called as far as I can tell.
setWorldspaceDeadCode:			; $116c
		sta     ZP_REGISTER_A
        sty     ZP_REGISTER_Y
        jsr     findParamPointer
        ldy     #$00
        lda     (ZP_PARAM_PTR_L),y
        sta     ZP_WORLD_X_L
        iny
        lda     (ZP_PARAM_PTR_L),y
        sta     ZP_WORLD_X_H
        iny
        lda     (ZP_PARAM_PTR_L),y
        sta     ZP_WORLD_Y
        clc
        lda     ZP_PARAM_PTR_L
        adc     #$03
        sta     ZP_PARAM_PTR_L
        lda     ZP_PARAM_PTR_H
        adc     #$00
        sta     ZP_PARAM_PTR_H
        lda     ZP_REGISTER_A
        ldy     ZP_REGISTER_Y
        jmp     (ZP_PARAM_PTR_L)



; Sets current worldspace rendering position using an inline pointer to a three-byte parameter block:
; 0 = X worldspace position to render at (low byte)
; 1 = X worldspace position to render at (low byte)
; 2 = Y worldspace position to render at
setWorldspace:			; $1197
		sta     ZP_REGISTER_A					; Save registers
        sty     ZP_REGISTER_Y

        jsr     unpackInlinePointer			; Fetch inline pointer parameter from caller (usually $001C)
        ldy     #$00
        lda     (ZP_PARAM_PTR_L),y			; Dereference it to get some data
        sta     ZP_WORLD_X_L
        iny
        lda     (ZP_PARAM_PTR_L),y
        sta     ZP_WORLD_X_H
        iny
        lda     (ZP_PARAM_PTR_L),y
        sta     ZP_WORLD_Y

        lda     ZP_REGISTER_A					; Restore registers
        ldy     ZP_REGISTER_Y
        jmp     (ZP_INLINE_RTS_L)			; Return to caller stackless



; Takes an inline pointer to a 16-bit scroll value to use for certain rendering functions.
; This is always used to point to the global scroll values (ZP_SCROLLPOS_*) anyway
; so I think this was a generalization that Dan thought he might use but never did.
; 90% of the rendering code uses the global scroll value directly so he seems to have
; given up on this idea along the way.
setLocalScroll:	; $11b5
		sta     ZP_REGISTER_A					; Save registers
        sty     ZP_REGISTER_Y
        jsr     unpackInlinePointer
        ldy     #$00
        lda     (ZP_PARAM_PTR_L),y			; Fish the pointer (which is always $0072)
        sta     ZP_LOCALSCROLL_L			; from the inline-code below the caller
        iny
        lda     (ZP_PARAM_PTR_L),y
        sta     ZP_LOCALSCROLL_H
        lda     ZP_REGISTER_A					; Restore registers
        ldy     ZP_REGISTER_Y
        jmp     (ZP_INLINE_RTS_L)			; Return to caller stackless



; Pulls two inline bytes from a caller and uses the first as the new bottom for the scroll
; window. For a while the game appears to have supported vertical scrolling, but it did not
; in the final version, so this is no longer used. The second byte in the caller is ignored.
; Preserves registers.
setScrollBottom:		; $11ce
		sta     ZP_REGISTER_A
        sty     ZP_REGISTER_Y
        jsr     unpackInlinePointer
        ldy     #$00
        lda     (ZP_PARAM_PTR_L),y
        sta     ZP_SCREENBOTTOM
        lda     ZP_REGISTER_A
        ldy     ZP_REGISTER_Y
        jmp     (ZP_INLINE_RTS_L)



; Pulls two inline bytes from a caller and uses the first as the new top for the scroll
; window. For a while the game appears to have supported vertical scrolling, but it did not
; in the final version, so this is no longer used. The second byte in the caller is ignored.
; Preserves registers.
setScrollTop:		; $11e2
		sta     ZP_REGISTER_A
        sty     ZP_REGISTER_Y
        jsr     unpackInlinePointer
        ldy     #$00
        lda     (ZP_PARAM_PTR_L),y
        sta     ZP_SCREENTOP
        lda     ZP_REGISTER_A
        ldy     ZP_REGISTER_Y
        jmp     (ZP_INLINE_RTS_L)


; Takes a tilt value in accumulator and converts it to offsets that will be used to render
; the next sprites. Preserves registers. Maximum tilt is +/- 5
setSpriteTilt:					; $11f6
		sty     ZP_REGISTER_Y					; Save registers
        stx     ZP_REGISTER_X
        clc
        adc     #$05
        asl
        tax
        lda     spriteTiltTable,x
        sta     ZP_SPRITE_TILT_SIGN
        lda     spriteTiltTable+1,x
        sta     ZP_SPRITE_TILT_OFFSET
        ldy     ZP_REGISTER_Y					; Restore registers
        ldx     ZP_REGISTER_X
        rts


spriteTiltTable:				; $120e		A lookup table to convert sprite tilt to offsets we can use in rendering
		.byte $FF,$03
		.byte $FF,$04
		.byte $FF,$05
		.byte $FF,$0A
		.byte $FF,$0D
		.byte $00,$00
		.byte $01,$0D
		.byte $01,$0A
		.byte $01,$05
		.byte $01,$04
		.byte $01,$03



; Takes a row of pixel data and uses it to blit an entire rectangle. The row of pixels
; given are replicated for each row. The pixel row comes from a standard sprite struct
; Preserves registers
blitRect:		; $1224
		sta     ZP_REGISTER_A		; Save registers
        stx     ZP_REGISTER_X
        sty     ZP_REGISTER_Y

        jsr     parseImageHeader	; Get image specs
        jsr     calcRowBitByte		; Figure out how wide the area is
        lda     ZP_SCREEN_Y
        sta     ZP_RENDER_CURR_Y
        clc
        lda     ZP_CURR_X_BYTE
        adc     ZP_IMAGE_W
        cmp     #$29
        bcc     blitRectLoop
        sec
        lda     #$28
        sbc     ZP_CURR_X_BYTE
        sta     ZP_IMAGE_W

blitRectLoop:  						; Blit the pixels
		ldx     ZP_RENDER_CURR_Y
        lda     hiResRowsLow,x
        sta     blitRectBlit+1	; Self-modifying code
        sta     blitRectBlit2+1

        lda     hiResRowsHigh,x
        eor     ZP_PAGEMASK
        sta     blitRectBlit+2	; Self-modifying code
        sta     blitRectBlit2+2
        lda     #$01
        and     ZP_RENDER_CURR_Y
        asl
        tay
        lda     (ZP_PARAM_PTR_L),y
        sta     blitRectLoad2+1
        iny
        lda     (ZP_PARAM_PTR_L),y
        sta     blitRectLoad+1	; Self-modifying code
        ldx     ZP_IMAGE_W
        ldy     ZP_CURR_X_BYTE
        tya
        and     #$01
        beq     blitRectLoad2

blitRectLoad:			; $1274
		lda		#$55		; Self-modification target
blitRectBlit:			; $1276
		sta		$2ad0,y		; Self-modification target

        iny
        dex
        beq     blitRectRowDone

blitRectLoad2:			; $127d
		lda		#$2a		; Self-modification target
blitRectBlit2:			; $127f
		sta		$2ad0,y		; Self-modification target

		iny
        dex
        bne     blitRectLoad

blitRectRowDone:
		dec     ZP_IMAGE_H
        beq     blitRectDone
        dec     ZP_RENDER_CURR_Y
        jmp     blitRectLoop

blitRectDone:
		lda     ZP_REGISTER_A		; Restore registers
        ldx     ZP_REGISTER_X
        ldy     ZP_REGISTER_Y
        rts


; Initializes a bunch of rendering state. Called from the loader
; Preserves registers
initRendering:		; $1296
		pha
        jsr     initSlideAnim
        lda     #$00
        sta     ZP_PAGEMASK
        sta     ZP_PALETTE
        sta     ZP_SPRITE_TILT_SIGN
        sta     ZP_SPRITE_TILT_OFFSET
        sta     ZP_UNUSEDB4
        sta     ZP_UNUSEDB5
        sta     ZP_SCREENBOTTOM			; Vertical scrolling no longer supported, so this is fixed at 0
        sta     ZP_LOCALSCROLL_L
        sta     ZP_LOCALSCROLL_H
        lda     #$C0
        sta     ZP_SCREENTOP			; Vertical scrolling no longer supported, so this is fixed at 192
        pla
        rts


; Initializes a new title slide animation
initSlideAnim:		; $12b4
		pha
		lda #$00
		sta ZP_LEFTCLIP	
		sta ZP_RIGHTCLIP
		sta ZP_TOPCLIP
		sta ZP_BOTTOMCLIP
		pla
		rts


; Enable HGR graphics
enableHiResGraphics:			; $12c1
		bit $c057
		bit $c052
		bit $c050
		rts


; Initializes the rendering buffer page mask
initPageMask:					; $12cb
		pha
		lda		#$00
		sta		ZP_PAGEMASK
		pla
		rts



; Swaps the page mask to render in the other buffer
flipPageMask:					; $12d2
		pha
        lda     ZP_PAGEMASK
        beq     flipPageMask0
        lda     #$00
        sta     ZP_PAGEMASK
        pla
        rts
flipPageMask0:
		lda		#$60		; This is clever because eor of high byte of an HGR row gets you the same line in the other page
		sta		ZP_PAGEMASK
		pla
		rts


; Flips the hardware graphics page
pageFlip:						; $12e3
		pha
		lda     ZP_PAGEMASK
		bne     pageFlip1
		bit     $C054			; The hardware page flip bit
		pla
		rts
pageFlip1:
		bit		$C055			; The other hardware page flip bit
		pla
		rts


; Clears current hi-res page to black. Preserves registers.
; Does not appear to be called from anywhere
clearScreen:	; $12f2
		pha			; Save registers. Dan switches to using zero page for this later
        tya			; Original 6502 (Apple II/II+) doesn't have phx/phy so this is the only way
        pha			; if you want to use the stack, as is common in later code
        txa
        pha
        lda     #$00		; Self modifying code to set $2000 or $4000 as needed
        sta     clearScreenStore+1
        lda     #$20
        eor     ZP_PAGEMASK		; Swap page if needed
        sta     clearScreenStore+2
        ldx     #$20
        ldy     #$00
        lda     #$00

clearScreenStore:			; Loop through all of VRAM
		sta		$1111,y	; $1309 ; Self modifying code target

        iny
        bne     clearScreenStore
        inc     clearScreenStore+2
        dex
        bne     clearScreenStore

        pla					; Restore registers
        tax
        pla
        tay
        pla
        rts


; Fills a block of the screen (full rows)
; A = Fill value, X = Start row (0 is screen bottom), Y = End Row (191 is screen top)
screenFill:		; $131b
		iny
        sty     ZP_DRAWEND
        sta     ZP_DRAWSCRATCH0
screenFillLoopRows:
		lda     hiResRowsLow,x
        sta     $1333		; Self modifies store below for current render page
        lda     hiResRowsHigh,x
        eor     ZP_PAGEMASK	; Convert high byte to correct page buffer
        sta     $1334		; Self modifies store below for current render page
        lda     ZP_DRAWSCRATCH0
        ldy     #$27		; Start a new row
screenFillLoopOneRow:		; $1332
		sta     $2000,y		; Self modifying code for row filling- will be $4000 range if Page 2 is current
        dey
        bpl     screenFillLoopOneRow
        inx
        cpx     ZP_DRAWEND
        bne     screenFillLoopRows
        rts



; Advances iterators to next row of the source image being copied to screen
nextImageSrcRow:		; $133e
		sec
        lda     ZP_IMAGE_W
        sbc     #$01
        sta     ZP_DRAWEND		; Cache width-1 in pixels

        clc
        lda     ZP_SCREEN_X_L		; Advance ZP_SCREEN_X_L to end of current image row
        sta     ZP_DRAWSCRATCH0
        adc     ZP_DRAWEND
        sta     ZP_SCREEN_X_L

        lda     ZP_SCREEN_X_H
        sta     ZP_DRAWSCRATCH1
        adc     #$00
        sta     ZP_SCREEN_X_H

        jmp     calcRowBitByteDirect	; Fall through to recalculate bit/byte position for new row


; Advances iterators to next row of the source image being copied to screen with tilt
nextImageSrcRowTilt:		; $1359
        lda     ZP_SCREEN_X_L				; Cache current X render position
        sta     ZP_DRAWSCRATCH0
        lda     ZP_SCREEN_X_H
        sta     ZP_DRAWSCRATCH1

        bit     ZP_SPRITE_TILT			; Check current tilt
        bmi     nextImageSrcRowTiltRightTilt
        jmp     nextImageSrcRowTiltLeftTilt

nextImageSrcRowTiltRightTilt:  			; For right tilt, advance to next source row
		sec
        lda     ZP_IMAGE_W
        sbc     #$01
        clc
        adc     ZP_SCREEN_X_L
        sta     ZP_SCREEN_X_L
        lda     ZP_SCREEN_X_H
        adc     #$00
        sta     ZP_SCREEN_X_H

nextImageSrcRowTiltLeftTilt:
		jsr     calcRowBitByteDirect	; Recalculate bit/byte for new row
        lda     #$80
        ldx     ZP_CURR_X_BIT
nextImageSrcRowTiltBitLoop:
		lsr
        dex
        bne     nextImageSrcRowTiltBitLoop
        sta     ZP_CURR_X_BIT
        rts



; Calculates the byte and bit-within-byte of where to draw a row of pixels based
; on the X start position in pixels. Position to calculate is in ZP_SCREEN_X_L on entry
calcRowBitByte:		; $1386
		lda     ZP_SCREEN_X_L			; Save pixel X because we're going to trash it
        sta     ZP_DRAWSCRATCH0		; Uses unrelated ZP locations for scratch
        lda     ZP_SCREEN_X_H			; Save ZP_SCREEN_X_H because we're going to trash it
        sta     ZP_DRAWSCRATCH1

calcRowBitByteDirect:
        lda     ZP_SCREEN_X_H			; Calculate X position in bytes and bit within final byte
        asl     ZP_SCREEN_X_L
        rol
        ldx     #$07
calcRowBitByte_Loop:
		asl     ZP_SCREEN_X_L
        rol
        cmp     #$07
        bcc     calcRowBitByte_Skip
        sbc     #$07
        inc     ZP_SCREEN_X_L
calcRowBitByte_Skip:
		dex
        bne     calcRowBitByte_Loop

        sta     ZP_CURR_X_BIT		; Bit within final byte of X pos pixel
        lda     ZP_SCREEN_X_L
        sta     ZP_CURR_X_BYTE
        sec
        lda     #$07				; Reverse bit counter since hi-res numbers them bottom up
        sbc     ZP_CURR_X_BIT
        sta     ZP_CURR_X_BIT

        lda     ZP_DRAWSCRATCH0		; Restore pixel X position
        sta     ZP_SCREEN_X_L
        lda     ZP_DRAWSCRATCH1			; Restore ZP_SCREEN_X_H
        sta     ZP_SCREEN_X_H
        rts



; Applies current clipping values to thing we're about to render. The clipping support
; is quite sophisticated. We need left/right clipping for scrolling enemies at screen edges,
; and vertical clipping is used for the chopper sinking/crash effect as well as title cards
applyClipping:				; $13b9
		lda     ZP_IMAGE_W				; Convert width to bytes by adding 7 and dividing by 8
        clc
        adc     #$07
        lsr
        lsr
        lsr
        sta     ZP_IMAGE_W_BYTES		; Cache this

        lda     ZP_TOPCLIP				; Check for top clipping
        beq     applyClippingNoTopClip

        sta     ZP_DRAWEND
        lda     #$00
        ldx     #$08

applyClippingFindTopLoop:					; Find the new top of the image for top clip amount
		lsr     ZP_DRAWEND
        bcc     applyClippingFindTopClamp	; Clamp to bottom so we don't overshoot
        clc
        adc     ZP_IMAGE_W_BYTES		; Loop, adding width (one row) to pointer
applyClippingFindTopClamp:
		ror
        ror     ZP_DRAWSCRATCH0
        dex
        bne     applyClippingFindTopLoop

        sta     ZP_DRAWSCRATCH1
        clc
        lda     ZP_PARAM_PTR_L
        adc     ZP_DRAWSCRATCH0
        sta     ZP_PARAM_PTR_L
        lda     ZP_PARAM_PTR_H
        adc     ZP_DRAWSCRATCH1
        sta     ZP_PARAM_PTR_H		; Pointers now moved into source image for clipped top

applyClippingNoTopClip:
		lda     ZP_LEFTCLIP			; Convert left clip edge to bytes
        lsr
        lsr
        lsr
        sta     ZP_LEFTCLIP_BYTES

        lda     ZP_LEFTCLIP
        and     #$07
        sta     ZP_DRAWEND

        sec							; Calculate remainder bits from clip edge
        lda     #$08
        sbc     ZP_DRAWEND
        sta     ZP_CLIPBITS

        clc
        lda     ZP_PARAM_PTR_L		; Advance source and destination image
        adc     ZP_LEFTCLIP_BYTES	; pointers for clipping left edge
        sta     ZP_PARAM_PTR_L
        sta     ZP_SOURCE_IMGPTR_L
        lda     ZP_PARAM_PTR_H
        adc     #$00
        sta     ZP_PARAM_PTR_H
        sta     ZP_SOURCE_IMGPTR_H

        lda     ZP_IMAGE_W			; Reduce width by clipping amounts
        sec
        sbc     ZP_LEFTCLIP
        sbc     ZP_RIGHTCLIP
        sta     ZP_IMAGE_W

        lda     ZP_IMAGE_H			; Reduce height for clipping amounts
        sec
        sbc     ZP_TOPCLIP
        sbc     ZP_BOTTOMCLIP
        sta     ZP_IMAGE_H

        lda     ZP_SCREEN_Y				; Initialize row counter for blitting
        sta     ZP_RENDER_CURR_Y
        rts



; Advances image pointers to the next row while copying an image to the screen
nextImageDestRow:	; $1425
        clc
        lda     ZP_SOURCE_IMGPTR_L
        sta     ZP_PARAM_PTR_L		; Param pointer caches pointer to previous row
        adc     ZP_IMAGE_W_BYTES
        sta     ZP_SOURCE_IMGPTR_L
        lda     ZP_SOURCE_IMGPTR_H
        sta     ZP_PARAM_PTR_H
        adc     #$00
        sta     ZP_SOURCE_IMGPTR_H

        lda     ZP_IMAGE_W			; Reset image width scratch area
        sta     ZP_RENDER_CURR_W

        ldy     #$00
        sty     ZP_RENDER_CURRBYTE	; Reset byte counter for row

        lda     (ZP_PARAM_PTR_L),y	; Fetch partial byte for start of next row
        ldx     ZP_CLIPBITS			; Taking only piece left by clipped bits
        stx     ZP_RENDER_CURRBIT

nextImageDestRow_Loop:
		cpx     #$08
        beq     nextImageDestRow_Break
        asl
        inx
        jmp     nextImageDestRow_Loop

nextImageDestRow_Break:
		sta     ZP_BITSCRATCH					; Cache first byte for next row

        ldx     ZP_RENDER_CURR_Y		; Calculate hires rows to render at
        lda     hiResRowsLow,x
        sta     ZP_HGRPTR_L
        lda     hiResRowsHigh,x
        eor     ZP_PAGEMASK
        sta     ZP_HGRPTR_H

        lda     ZP_CURR_X_BYTE			; Reset horizontal byte counter
        sta     ZP_CURR_X_BYTEC
        rts



; Takes a pointer to an image structure, fetches the W/H, and sets a pointer to the pixels
parseImageHeader:		; $1462
		lda     ZP_SPRITEANIM_PTR_L		; Copy image pointer into parameter pointer
        sta     ZP_PARAM_PTR_L
        lda     ZP_SPRITEANIM_PTR_H
        sta     ZP_PARAM_PTR_H
        ldy     #$00					; Dereference to get pointer to actual image struct
        lda     (ZP_PARAM_PTR_L),y
        sta     ZP_IMAGE_W
        ldy     #$01
        lda     (ZP_PARAM_PTR_L),y
        sta     ZP_IMAGE_H
        clc
        lda     ZP_PARAM_PTR_L			; Advance pointer to get past header data
        adc     #$02					; Param Pointer will now be to actual pixels
        sta     ZP_PARAM_PTR_L
        lda     ZP_PARAM_PTR_H
        adc     #$00
        sta     ZP_PARAM_PTR_H
        rts



; Clips the current rendering operation to the boundaries of the scrolling
; window. We return carry set if the sprite is completely outside the scroll
; window and thus does not need any rendering. If the sprite overlaps window
; edges, we update clipping as needed and return carry clear. Preserves registers
clipToScroll:						; $1484
		sta     ZP_REGISTER_A				; Save registers
        stx     ZP_REGISTER_X
        sty     ZP_REGISTER_Y

        ldy     #$00						; Fetch image size from header
        lda     (ZP_SPRITEANIM_PTR_L),y
        sta     ZP_IMAGE_W
        iny
        lda     (ZP_SPRITEANIM_PTR_L),y
        sta     ZP_IMAGE_H

        lda     #$00						; Initialize clipping state
        sta     ZP_LEFTCLIP
        sta     ZP_RIGHTCLIP
        sta     ZP_TOPCLIP
        sta     ZP_BOTTOMCLIP

        lda     ZP_WORLD_X_H				; Check if we're within scroll window
        cmp     ZP_LOCALSCROLL_H
        bcc     clipToScrollPastLeft
        bne     clipToScrollScreenspace
        lda     ZP_WORLD_X_L
        cmp     ZP_LOCALSCROLL_L
        bcc     clipToScrollPastLeft

clipToScrollScreenspace:					; Convert to screenspace for rendering
		sec
        lda     ZP_WORLD_X_L
        sbc     ZP_LOCALSCROLL_L
        sta     ZP_SCREEN_X_L
        lda     ZP_WORLD_X_H
        sbc     ZP_LOCALSCROLL_H
        sta     ZP_SCREEN_X_H
        jmp     clipToScrollCheckRight

clipToScrollPastLeft:						; Past left edge, so check right edge
		sec
        lda     ZP_LOCALSCROLL_L
        sbc     ZP_WORLD_X_L
        sta     ZP_DRAWSCRATCH0
        lda     ZP_LOCALSCROLL_H
        sbc     ZP_WORLD_X_H
        sta     ZP_DRAWSCRATCH1
        lda     ZP_DRAWSCRATCH1				; Check if any of us is within scroll window
        bne     clipToScrollOffscreen
        lda     ZP_DRAWSCRATCH0
        cmp     ZP_IMAGE_W
        bcs     clipToScrollOffscreen

        lda     ZP_DRAWSCRATCH0				; We're overlapping left edge, so clip us to that
        sta     ZP_LEFTCLIP
        lda     #$00
        sta     ZP_SCREEN_X_L				; Clamp to left screenspace edge since we're clipped
        sta     ZP_SCREEN_X_H
        jmp     clipToScrollCheckY

clipToScrollOffscreen:						; Sprite is completely offscreen, so no rendering to perform
		sec
        jmp     clipToScrollDone

clipToScrollCheckRight:  					; Check against right edge
		clc
        lda     ZP_LOCALSCROLL_L
        adc     #$18
        sta     ZP_DRAWSCRATCH0
        lda     ZP_LOCALSCROLL_H
        adc     #$01
        sta     ZP_DRAWSCRATCH1
        lda     ZP_DRAWSCRATCH1
        cmp     ZP_WORLD_X_H
        bcc     clipToScrollOffscreen
        bne     clipToScrollRightOverlap
        lda     ZP_DRAWSCRATCH0
        cmp     ZP_WORLD_X_L
        bcc     clipToScrollOffscreen
        beq     clipToScrollOffscreen

clipToScrollRightOverlap:
		sec
        lda     ZP_DRAWSCRATCH0			; Calculate amount that would be past right edge
        sbc     ZP_WORLD_X_L
        sta     ZP_DRAWSCRATCH0
        lda     ZP_DRAWSCRATCH1
        sbc     ZP_WORLD_X_H
        sta     ZP_DRAWSCRATCH1
        lda     ZP_DRAWSCRATCH1
        bne     clipToScrollCheckY
        lda     ZP_DRAWSCRATCH0
        cmp     ZP_IMAGE_W
        bcs     clipToScrollCheckY
        sec								; We're overlapping right edge, so clip us to that
        lda     ZP_IMAGE_W
        sbc     ZP_DRAWSCRATCH0
        sta     ZP_RIGHTCLIP

clipToScrollCheckY:						; Check for clipping at top of screen
		clc								; It looks line Dan explored the possibility of vertical scrolling
        lda     ZP_WORLD_Y				; here as well, and supports full clipping at screen top and bottom.
        adc     ZP_SCREENBOTTOM			; The shipped game never ended up needing this
        sta     ZP_SCREEN_Y
        lda     ZP_SCREENTOP
        cmp     ZP_WORLD_Y
        bcs     clipToScrollCheckBottom
        sec
        lda     ZP_WORLD_Y
        sbc     ZP_SCREENTOP
        cmp     ZP_IMAGE_H
        bcs     clipToScrollOffscreen2
        sta     ZP_TOPCLIP					; We are overlapping top edge, so clip to that
        clc
        lda     ZP_SCREENTOP
        adc     ZP_SCREENBOTTOM
        sta     ZP_SCREEN_Y
        jmp     clipToScrollOnscreen

clipToScrollOffscreen2:					; We're offscreen vertically, so no need to render
		sec
        jmp     clipToScrollDone

clipToScrollCheckBottom:
		lda     ZP_WORLD_Y
        beq     clipToScrollOffscreen2
        cmp     ZP_IMAGE_H					; We're overlapping the bottom edge, so clip us to that
        bcs     clipToScrollOnscreen
        sec
        lda     ZP_IMAGE_H
        sbc     ZP_WORLD_Y
        sta     ZP_BOTTOMCLIP

clipToScrollOnscreen:
		clc

clipToScrollDone:
		lda     ZP_REGISTER_A					; Restore registers
        ldx     ZP_REGISTER_X
        ldy     ZP_REGISTER_Y
        rts

	

; A simplest-case rendering routine which does no masking and assumes destination onscreen
; is byte-aligned. This can be used in some cases for best possible speed (such as background
; mountains). Image to render has been previously set up with helper functions such as clipToScroll.
; Preserves registers.
blitAlignedImage:		; $155d
		sta     ZP_REGISTER_A		; Save registers
        stx     ZP_REGISTER_X
        sty     ZP_REGISTER_Y
        jsr     parseImageHeader			; Prepare to render
        jsr     calcRowBitByte
        jsr     alignImg

blitAlignedImageLoop:
		clc
        lda     ZP_SOURCE_IMGPTR_L			; Copy source image pointer to code below
        adc     ZP_LEFTCLIP_BYTES			; Apply left clipping
        sta     blitAlignedImageLoad+1		; Self modifying code
        lda     ZP_SOURCE_IMGPTR_H
        adc     #$00
        sta     blitAlignedImageLoad+2
        clc
        lda     ZP_SOURCE_IMGPTR_L
        adc     ZP_IMAGE_W_BYTES
        sta     ZP_SOURCE_IMGPTR_L
        lda     ZP_SOURCE_IMGPTR_H
        adc     #$00
        sta     ZP_SOURCE_IMGPTR_H

        ldx     ZP_RENDER_CURR_Y			; Copy destination screen pointer to code below
        lda     hiResRowsLow,x
        sta     blitAlignedImageStore+1		; Self modifying code
        lda     hiResRowsHigh,x
        eor     ZP_PAGEMASK					; Render to correct page
        sta     blitAlignedImageStore+2
        ldx     ZP_IMAGE_W
        dex
        ldy     ZP_CURR_X_BYTE
blitAlignedImageLoad:				; Tight blitting loop
		lda		$1111,x				; Self modifying code target
blitAlignedImageStore:
		sta		$1111,y				; Self modifying code target
		dey
        dex
        bpl     blitAlignedImageLoad
        dec     ZP_IMAGE_H
        beq     blitAlignedImageDone
        dec     ZP_RENDER_CURR_Y		; Row complete
        jmp     blitAlignedImageLoop

blitAlignedImageDone:
		lda     ZP_REGISTER_A			; Restore registers
        ldx     ZP_REGISTER_X
        ldy     ZP_REGISTER_Y
        rts



; The exact purpose of this routine isn't clear to me. It looks like something to do with
; byte-aligning and clipping an image to be rendered using the fast byte-aligned renderer above.
; I've documented what I can figure out in the labels and data names.
alignImg:		; $15b7
        lda     ZP_IMAGE_W
        sta     alignImgImgWidth

        lda     #$00
        sta     alignImgState

        jsr     calcByteWidth
        lda     resultBitRemainder
        beq     alignImgByteAligned
        lda     #$01			; Add one byte if there were any remainder bits

alignImgByteAligned:
		clc
        adc     resultByteWidth
        sta     ZP_IMAGE_W_BYTES
        inc     ZP_IMAGE_W_BYTES
        lda     ZP_SCREEN_X_L
        bne     alignImgOddXPos
        lda     ZP_SCREEN_X_H
        bne     alignImgOddXPos
        jmp     alignImgEvenXPos

alignImgOddXPos:
		sec
        lda     #$07
        sbc     ZP_CURR_X_BIT
        sta     ZP_BITSCRATCH
        lda     #$00
        sta     ZP_LEFTCLIP_BYTES
        jmp     alignImgCopyPointers

alignImgEvenXPos:
		lda     ZP_LEFTCLIP
        bne     alignImgHaveClip
        lda     #$00
        sta     ZP_BITSCRATCH
        sta     ZP_LEFTCLIP_BYTES
        jmp     alignImgCopyPointers

alignImgHaveClip:
		dec     ZP_LEFTCLIP
        lda     ZP_LEFTCLIP
        sta     alignImgImgWidth
        lda     #$00
        sta     alignImgState
        jsr     calcByteWidth
        sec
        lda     #$06
        sbc     resultBitRemainder
        sta     ZP_BITSCRATCH
        inc     resultByteWidth
        lda     resultByteWidth
        sta     ZP_LEFTCLIP_BYTES

alignImgCopyPointers:
		lda     ZP_PARAM_PTR_L			; Copy the configured image pointers into blitter parameters
        sta     ZP_SOURCE_IMGPTR_L
        lda     ZP_PARAM_PTR_H
        sta     ZP_SOURCE_IMGPTR_H

        lda     ZP_BITSCRATCH
        beq     alignImgBitNoBits

        lda     ZP_IMAGE_W_BYTES
        sta     resultByteWidth
        lda     ZP_IMAGE_H
        sta     resultBitRemainder
        jsr     alignImgHelper

alignImgBitLoop:
		clc
        lda     ZP_SOURCE_IMGPTR_L
        adc     alignImgImgWidth
        sta     ZP_SOURCE_IMGPTR_L
        lda     ZP_SOURCE_IMGPTR_H
        adc     alignImgState
        sta     ZP_SOURCE_IMGPTR_H
        dec     ZP_BITSCRATCH
        bne     alignImgBitLoop

alignImgBitNoBits:
		clc
        lda     ZP_CURR_X_BYTE
        adc     ZP_IMAGE_W_BYTES
        sec
        sbc     ZP_LEFTCLIP_BYTES
        cmp     #$29
        bcs     alignImgLargeClip
        sec
        lda     ZP_IMAGE_W_BYTES
        sbc     ZP_LEFTCLIP_BYTES
        sta     ZP_IMAGE_W
        jmp     alignImgClipped

alignImgLargeClip:
		sec
        sbc     #$28
        clc
        adc     ZP_LEFTCLIP_BYTES
        eor     #$FF
        clc
        adc     #$01
        clc
        adc     ZP_IMAGE_W_BYTES
        sta     ZP_IMAGE_W

alignImgClipped:
		lda     ZP_SCREEN_Y
        sta     ZP_RENDER_CURR_Y

        sec								; Adjust final source image pointer for clipping
        lda     ZP_IMAGE_H
        sbc     ZP_TOPCLIP
        sbc     ZP_BOTTOMCLIP
        sta     ZP_IMAGE_H
        lda     ZP_TOPCLIP
        beq     alignImgDone

        sta     resultByteWidth
        lda     ZP_IMAGE_W_BYTES
        sta     resultBitRemainder
        jsr     alignImgHelper
        clc
        lda     ZP_SOURCE_IMGPTR_L
        adc     alignImgImgWidth
        sta     ZP_SOURCE_IMGPTR_L
        lda     ZP_SOURCE_IMGPTR_H
        adc     alignImgState
        sta     ZP_SOURCE_IMGPTR_H

alignImgDone:
		clc
        lda     ZP_CURR_X_BYTE
        adc     ZP_IMAGE_W
        sta     ZP_CURR_X_BYTE
        dec     ZP_CURR_X_BYTE
        rts



; A helper routine which calculates how many whole bytes (and remaining bits) that
; a given image width occupies. This is a division by 7 with remainder, essentially.
calcByteWidth:			; $169f
		lda     alignImgState
        asl     alignImgImgWidth
        rol
        ldx     #$07

calcByteWidthLoop:
		asl     alignImgImgWidth
        rol
        cmp     #$07
        bcc     calcByteWidthNoBit
        sbc     #$07
        inc     alignImgImgWidth

calcByteWidthNoBit:
		dex
        bne     calcByteWidthLoop
        sta     resultBitRemainder
        lda     alignImgImgWidth
        sta     resultByteWidth
        rts




; Really not sure what this routine is doing. Some sort of helper related to alignImg above.
; I have documented what I can.
alignImgHelper:		; $16c2
		lda     #$00
        ldx     #$08

alignImgHelperLoop:
		lsr     resultByteWidth
        bcc     alignImgHelperNoBit
        clc
        adc     resultBitRemainder

alignImgHelperNoBit:
		ror
        ror     alignImgImgWidth
        dex
        bne     alignImgHelperLoop
        sta     alignImgState
        rts


resultByteWidth:		; $16da
		.byte $00
resultBitRemainder:		; $16db
		.byte $00
alignImgImgWidth:	; $16dc
		.byte 	$00		; Cache of image width
alignImgState:		; $16dd
		.byte	$00



; Renders enemy sprites facing right. Data needed to render (sprite ptr, etc) has
; been set up previously with helper functions like clipToScroll and setWorldspace).
; Preserves registers.
renderSprite:			; $16de
		sta     ZP_REGISTER_A			; Save registers
        stx     ZP_REGISTER_X
        sty     ZP_REGISTER_Y

        jsr     parseImageHeader
        jsr     applyClipping
        jsr     calcRowBitByte

renderSpriteOuterLoop:
		jsr     nextImageDestRow
        ldx     ZP_CURR_X_BIT
        lda     #$00
        sta     ZP_PIXELSCRATCH
renderSpriteRowLoop:
		lda     #$00
        sta     ZP_PIXELS
        ldy     ZP_RENDER_CURRBIT
        lda     ZP_BITSCRATCH

renderSpriteStartLoop:
		asl
        ror     ZP_PIXELS
        dey
        beq     renderSpriteWrapWord

renderSpriteInnerLoop:
		dec     ZP_RENDER_CURR_W
        beq     renderSpriteRowBytesDone
        dex
        bne     renderSpriteStartLoop

        sty     ZP_RENDER_CURRBIT
        sta     ZP_BITSCRATCH
        lsr     ZP_PIXELS
        beq     renderSpriteByteDone
        asl     ZP_PIXELSCRATCH
        asl     ZP_PIXELSCRATCH
        lda     ZP_PIXELS
        rol
        sta     ZP_PIXEL_MASK
        lda     ZP_BITSCRATCH
        asl
        lda     ZP_PIXEL_MASK
        ror
        lsr
        and     ZP_PIXEL_MASK
        eor     #$7F				; Remove palette bit from sprite mask
        ldy     ZP_CURR_X_BYTEC
        and     (ZP_HGRPTR_L),y		; Combine existing screen byte with mask bits and...
        ora     ZP_PIXELS			; ... new pixels
        ora     ZP_PALETTE			; ... and palette
        sta     (ZP_HGRPTR_L),y		; Write back to screen
renderSpriteByteDone:
		inc     ZP_CURR_X_BYTEC
        lda     ZP_PIXELS
        sta     ZP_PIXELSCRATCH
        ldx     #$07				; Reset bit counter
        jmp     renderSpriteRowLoop

renderSpriteRowBytesDone:
		lda     ZP_PIXELS			; Whole bytes for this row finished
        beq     renderSpriteRowDone
        dex
        beq     renderSpriteSkipLoop
renderSpriteEndLoop:
		lsr
        dex
        bne     renderSpriteEndLoop
renderSpriteSkipLoop:
		lsr
        sta     ZP_PIXELS			; Now handle bits remaining at end of full row
        asl     ZP_PIXELSCRATCH
        asl     ZP_PIXELSCRATCH
        rol
        sta     ZP_PIXEL_MASK
        lsr
        lsr
        and     ZP_PIXEL_MASK
        eor     #$7F				; Remove palette bit from sprite mask
        ldy     ZP_CURR_X_BYTEC
        and     (ZP_HGRPTR_L),y		; Combine existing screen byte with mask bits and...
        ora     ZP_PIXELS			; ... new pixels
        ora     ZP_PALETTE			; ... and palette
        sta     (ZP_HGRPTR_L),y		; Write back to screen

renderSpriteRowDone:
		dec     ZP_IMAGE_H			; Advance to next row
        beq     renderSpriteDone

        dec     ZP_RENDER_CURR_Y
        jmp     renderSpriteOuterLoop

renderSpriteWrapWord:
		inc     ZP_RENDER_CURRBYTE
        ldy     ZP_RENDER_CURRBYTE
        lda     (ZP_PARAM_PTR_L),y	; Load next byte of pixels from sprite
        ldy     #$08				; Reset bit counter
        jmp     renderSpriteInnerLoop

renderSpriteDone:
		lda     ZP_REGISTER_A			; Restore registers
        ldx     ZP_REGISTER_X
        ldy     ZP_REGISTER_Y
        rts


; Renders enemy sprites facing left. This is a copy of the above routine, with horizontal
; iteration logic flipped to mirror the image. Data needed to render (sprite ptr, etc) has
; been set up previously with helper functions like clipToScroll and setWorldspace).
; Preserves registers.
renderSpriteFlip:		; $177c
		sta     ZP_REGISTER_A			; Save registers
        stx     ZP_REGISTER_X
        sty     ZP_REGISTER_Y

        ldx     ZP_LEFTCLIP			; Need to swap these for flipped rendering
        ldy     ZP_RIGHTCLIP
        sty     ZP_LEFTCLIP
        stx     ZP_RIGHTCLIP

        jsr     parseImageHeader	; Prepare to render the sprite
        jsr     applyClipping
        jsr     nextImageSrcRow

renderSpriteFlipOuterLoop:
		jsr     nextImageDestRow
        sec
        lda     #$08
        sbc     ZP_CURR_X_BIT
        tax
        lda     #$00
        sta     ZP_PIXELSCRATCH
renderSpriteFlipRowLoop:
		lda     #$00
        sta     ZP_PIXELS
        ldy     ZP_RENDER_CURRBIT
        lda     ZP_BITSCRATCH
renderSpriteFlipStartLoop:
		asl
        rol     ZP_PIXELS
        dey
        beq     renderSpriteFlipWrapWord

renderSpriteFlipInnerLoop:
		dec     ZP_RENDER_CURR_W
        beq     renderSpriteFlipRowBytesDone
        dex
        bne     renderSpriteFlipStartLoop
        sty     ZP_RENDER_CURRBIT
        sta     ZP_BITSCRATCH
        asl
        lda     ZP_PIXELS
        beq     renderSpriteFlipByteDone
        rol
        sta     ZP_PIXEL_MASK
        lsr     ZP_PIXELSCRATCH
        ror
        lsr
        and     ZP_PIXEL_MASK
        eor     #$7F				; Remove palette bit from sprite mask
        ldy     ZP_CURR_X_BYTEC
        and     (ZP_HGRPTR_L),y		; Combine existing screen byte with mask bits and...
        ora     ZP_PIXELS			; ... new pixels
        ora     ZP_PALETTE			; ... and palette
        sta     (ZP_HGRPTR_L),y		; Write back to screen
renderSpriteFlipByteDone:
		dec     ZP_CURR_X_BYTEC		; On to next byte of pixels
        lda     ZP_PIXELS
        sta     ZP_PIXELSCRATCH
        ldx     #$07				; Reset bit counter
        jmp     renderSpriteFlipRowLoop

renderSpriteFlipRowBytesDone:
		lda     ZP_PIXELS			; Whole bytes for this row finished
        dex
        beq     renderSpriteFlipSkipLoop
renderSpriteFlipEndLoop:
		asl
        dex
        bne     renderSpriteFlipEndLoop
renderSpriteFlipSkipLoop:
		sta     ZP_PIXELS			; Now handle any bits at the end of that full row
        lda     ZP_PIXELS
        beq     renderSpriteFlipRowDone
        clc
        rol
        sta     ZP_PIXEL_MASK
        lsr     ZP_PIXELSCRATCH
        ror
        lsr
        and     ZP_PIXEL_MASK
        eor     #$7F				; Remove palette bit from sprite mask
        ldy     ZP_CURR_X_BYTEC
        and     (ZP_HGRPTR_L),y		; Combine existing screen byte with mask bits and...
        ora     ZP_PIXELS			; ... new pixels
        ora     ZP_PALETTE			; ... and palette
        sta     (ZP_HGRPTR_L),y		; Write back to screen

renderSpriteFlipRowDone:
		dec     ZP_IMAGE_H			; Advance to next row
        beq     renderSpriteFlipDone
        dec     ZP_RENDER_CURR_Y
        jmp     renderSpriteFlipOuterLoop

renderSpriteFlipWrapWord:
		inc     ZP_RENDER_CURRBYTE
        ldy     ZP_RENDER_CURRBYTE
        lda     (ZP_PARAM_PTR_L),y	; Load next byte of pixels from sprite
        ldy     #$08				; Reset bit counter
        jmp     renderSpriteFlipInnerLoop

renderSpriteFlipDone:
		ldx     ZP_LEFTCLIP			; Flip these back to normal
        ldy     ZP_RIGHTCLIP
        sty     ZP_LEFTCLIP
        stx     ZP_RIGHTCLIP

        lda     ZP_REGISTER_A			; Restore registers
        ldx     ZP_REGISTER_X
        ldy     ZP_REGISTER_Y
        rts



; This routine appears to be dead code, intended to be a generalized form of tilted sprite
; rendering. It never appears to be called in game, and it looks like Dan replaced this idea
; with the more specific tilted-sprite rendering routines renderTiltedSpriteLeft and
; renderTiltedSpriteRight
renderTiltRightDeadCode:		; $1826
		lda		#$00
		sta 	ZP_REGISTER
		sta 	ZP_UNUSEDBA
		jmp		renderSpriteRightStub



; Renders a sprite facing right. Rendering has been previously
; configured with a helper routine such as clipToScroll, setWorldspace, etc.
renderSpriteRight:		; $182f
		sta     ZP_REGISTER			; Save accumulator

        lda     #$80			; Was intended to set tilt direction, but is unused
        sta     ZP_UNUSEDBA

renderSpriteRightStub:			; Stub entry for an alternate version of this routine
        stx     ZP_REGISTER_X		; Save registers
        sty     ZP_REGISTER_Y

        jsr     parseImageHeader
        jsr     applyClipping
        jsr     calcRowBitByte

renderSpriteRightOuterLoop:
		jsr     nextImageDestRow
        ldx     ZP_CURR_X_BIT

renderSpriteRightByteLoop:
		lda     #$00
        sta     ZP_PIXELS
        ldy     ZP_RENDER_CURRBIT
        lda     ZP_BITSCRATCH

renderSpriteRightBitLoop:
		asl
        ror     ZP_PIXELS
        dey
        beq     renderSpriteRightByteDone

renderSpriteRightNextByte:
		dec     ZP_RENDER_CURR_W
        beq     renderSpriteRightRowDone
        dex
        bne     renderSpriteRightBitLoop

        sty     ZP_RENDER_CURRBIT
        sta     ZP_BITSCRATCH
        lsr     ZP_PIXELS

        ldy     ZP_CURR_X_BYTEC		; Fetch current byte on screen
        lda     (ZP_HGRPTR_L),y
        bit     ZP_PIXELS
        beq     renderSpriteRightBlit
        bit     ZP_UNUSEDBA
        bmi     renderSpriteRightBlit
        jsr     tiltLeftDeadCode		; Never called because ZP_UNUSEDBA is hardcoded negative

renderSpriteRightBlit:
		ora     ZP_PIXELS			; Combine with new pixels
        sta     (ZP_HGRPTR_L),y		; ...and write back to screen
        iny
        sty     ZP_CURR_X_BYTEC
        ldx     #$07
        jmp     renderSpriteRightByteLoop

renderSpriteRightRowDone:
		dex
        beq     renderSpriteRightBlit2
renderSpriteRightShiftLoop:
		lsr     ZP_PIXELS
        dex
        bne     renderSpriteRightShiftLoop

renderSpriteRightBlit2:
		lsr     ZP_PIXELS
        ldy     ZP_CURR_X_BYTEC
        lda     (ZP_HGRPTR_L),y		; Fetch current byte on screen
        bit     ZP_PIXELS
        beq     renderSpriteRightBlit3
        bit     ZP_UNUSEDBA
        bmi     renderSpriteRightBlit3
        jsr     tiltLeftDeadCode	; Never called because ZP_UNUSEDBA is hardcoded negative

renderSpriteRightBlit3:
		ora     ZP_PIXELS			; Combine with new pixels
        sta     (ZP_HGRPTR_L),y		; ...and write back to screen
        dec     ZP_IMAGE_H
        beq     renderSpriteRightDone
        dec     ZP_RENDER_CURR_Y
        jmp     renderSpriteRightOuterLoop

renderSpriteRightByteDone:
		inc     ZP_RENDER_CURRBYTE		; Advance to next byte
        ldy     ZP_RENDER_CURRBYTE
        lda     (ZP_PARAM_PTR_L),y		; Load next source image byte
        ldy     #$08					; Reset bit counter
        jmp     renderSpriteRightNextByte

renderSpriteRightDone:
		lda     ZP_REGISTER		; Restore registers
        ldx     ZP_REGISTER_X
        ldy     ZP_REGISTER_Y
        rts



; This routine appears to be dead code, intended to be a generalized form of tilted sprite
; rendering. It never appears to be called in game, and it looks like Dan replaced this idea
; with the more specific tilted-sprite rendering routines renderTiltedSpriteLeft and
; renderTiltedSpriteRight
renderTiltLeftDeadCode:			; $18b5
		lda		#$00
		sta		ZP_REGISTER
		sta		ZP_UNUSEDBA
		jmp		renderSpriteLeftStub



; Renders a sprite facing left. Rendering has been previously
; configured with a helper routine such as clipToScroll, setWorldspace, etc.
; This is a copy of renderSpriteRight, but with the horizontal iteration logic flipped
; to flip the image left to right
renderSpriteLeft:		; $18be
		sta     ZP_REGISTER

        lda     #$80
        sta     ZP_UNUSEDBA

renderSpriteLeftStub:				; Stub entry for an alternate version of this routine
        stx     ZP_REGISTER_X			; Save registers
        sty     ZP_REGISTER_Y

        ldx     ZP_LEFTCLIP			; Need to swap these for reversed rendering
        ldy     ZP_RIGHTCLIP
        sty     ZP_LEFTCLIP
        stx     ZP_RIGHTCLIP

        jsr     parseImageHeader
        jsr     applyClipping
        jsr     nextImageSrcRow

renderSpriteLeftOuterLoop:
		jsr     nextImageDestRow
        sec
        lda     #$08			; Reverse bit counter in this version
        sbc     ZP_CURR_X_BIT
        tax
renderSpriteLeftByteLoop:
		lda     #$00
        sta     ZP_PIXELS
        ldy     ZP_RENDER_CURRBIT
        lda     ZP_BITSCRATCH

renderSpriteLeftBitLoop:
		asl
        rol     ZP_PIXELS
        dey
        beq     renderSpriteLeftByteDone

renderSpriteLeftNextByte:
		dec     ZP_RENDER_CURR_W
        beq     renderSpriteLeftRowDone
        dex
        bne     renderSpriteLeftBitLoop

        sty     ZP_RENDER_CURRBIT
        sta     ZP_BITSCRATCH

        ldy     ZP_CURR_X_BYTEC		; Fetch current byte on screen
        lda     (ZP_HGRPTR_L),y
        bit     ZP_PIXELS
        beq     renderSpriteLeftBlit
        bit     ZP_UNUSEDBA
        bmi     renderSpriteLeftBlit
        jsr     tiltRightDeadCode	; Never called because ZP_UNUSEDBA is hardcoded negative

renderSpriteLeftBlit:
		ora     ZP_PIXELS			; Combine with new pixels
        sta     (ZP_HGRPTR_L),y		; ...and write back to screen
        dey
        sty     ZP_CURR_X_BYTEC
        ldx     #$07
        jmp     renderSpriteLeftByteLoop

renderSpriteLeftRowDone:
		dex
        beq     renderSpriteLeftBlit2
renderSpriteLeftShiftLoop:
		asl     ZP_PIXELS
        dex
        bne     renderSpriteLeftShiftLoop

renderSpriteLeftBlit2:
		ldy     ZP_CURR_X_BYTEC		; Fetch current byte on screen
        lda     (ZP_HGRPTR_L),y
        bit     ZP_PIXELS
        beq     renderSpriteLeftBlit3
        bit     ZP_UNUSEDBA
        bmi     renderSpriteLeftBlit3
        jsr     tiltRightDeadCode	; Never called because ZP_UNUSEDBA is hardcoded negative

renderSpriteLeftBlit3:
		ora     ZP_PIXELS			; Combine with new pixels
        sta     (ZP_HGRPTR_L),y		; ...and write back to screen
        dec     ZP_IMAGE_H
        beq     renderSpriteLeftDone
        dec     ZP_RENDER_CURR_Y
        jmp     renderSpriteLeftOuterLoop

renderSpriteLeftByteDone:
		inc     ZP_RENDER_CURRBYTE	; Advance to next byte
        ldy     ZP_RENDER_CURRBYTE
        lda     (ZP_PARAM_PTR_L),y	; Load next source image byte
        ldy     #$08				; Reset bit counter
        jmp     renderSpriteLeftNextByte

renderSpriteLeftDone:
		ldx     ZP_LEFTCLIP			; Swap these back
        ldy     ZP_RIGHTCLIP
        sty     ZP_LEFTCLIP
        stx     ZP_RIGHTCLIP

        lda     ZP_REGISTER				; Restore registers
        ldx     ZP_REGISTER_X
        ldy     ZP_REGISTER_Y
        rts


; Unused graphics routine. I believe this was an attempt to handle sprite tilt in a clever
; algorithmic way that didn't work out. This code is never called. Looks like Dan ended up
; replacing this with dedicated tilted-sprite rendering code 
; (see renderTiltedSpriteLeft and renderTiltedSpriteRight). Documented here as best I can anyway.
; A = Current byte of pixels on screen
; Y = Index of current byte on current HGR row
tiltLeftDeadCode:		; $1954
		sta     tiltLeftDeadCodePixels		; Preserve registers
        sty     tiltLeftDeadCodeByteIndex

        lda     #$00					; Set tilt to left
        sta     ZP_SPRITE_TILT
        jmp     tiltDeadCode			; Then fall through to shared code

tiltRightDeadCode:						; An additional entry point piggybacked in
        sta     tiltLeftDeadCodePixels	; Preserve registers
        sty     tiltLeftDeadCodeByteIndex
        lda     #$FF					; Set tilt to left
        sta     ZP_SPRITE_TILT			; Then fall through to shared code

tiltDeadCode:
		lda     #$00	; Copies upper three bits from Y into bottom of B7, but
        sta     ZP_UNUSEDB7	; I'm not clear what this is actually doing. Possibly a sort
        tya				; of scan-line conversion for sampling the sprite at an angle
        asl
        rol     ZP_UNUSEDB7
        asl
        rol     ZP_UNUSEDB7
        asl
        rol     ZP_UNUSEDB7
        sec
        sbc     tiltLeftDeadCodeByteIndex
        sta     ZP_UNUSEDB6
        bcs     tiltDeadCodeCheckTilt
        dec     ZP_UNUSEDB7

tiltDeadCodeCheckTilt:
		bit     ZP_SPRITE_TILT
        bmi     tiltDeadCodeTiltLeft

        ldy     #$00					; Tilt is right
        lda     tiltLeftDeadCodePixels
        and     ZP_PIXELS
tiltDeadCodeTiltLeftFindLowBit:
		lsr
        bcs     tiltDeadCodeTiltLeftGotBit
        iny
        jmp     tiltDeadCodeTiltLeftFindLowBit

tiltDeadCodeTiltLeft:
		ldy     #$06
        lda     tiltLeftDeadCodePixels
        and     ZP_PIXELS

tiltDeadCodeTiltLeftFindHighBit:
		asl
        bmi     tiltDeadCodeTiltLeftGotBit
        dey
        jmp     tiltDeadCodeTiltLeftFindHighBit

tiltDeadCodeTiltLeftGotBit:
		clc
        tya
        adc     ZP_UNUSEDB6
        sta     ZP_UNUSEDB6
        lda     ZP_UNUSEDB7
        adc     #$00
        sta     ZP_UNUSEDB7
        lda     $BD
        sta     ZP_UNUSEDB8
        lda     #$80
        sta     $BA
        lda     #$B6
        sta     $BB
        clc
        lda     ZP_UNUSEDB6
        adc     ZP_LOCALSCROLL_L
        sta     ZP_UNUSEDB6
        lda     ZP_UNUSEDB7
        adc     ZP_LOCALSCROLL_H
        sta     ZP_UNUSEDB7
        sec
        lda     ZP_UNUSEDB8
        sbc     ZP_SCREENBOTTOM
        sta     ZP_UNUSEDB8

        lda     tiltLeftDeadCodePixels		; Restore registers
        ldy     tiltLeftDeadCodeByteIndex
        rts

tiltLeftDeadCodePixels:			; $19d6
		.byte $00
tiltLeftDeadCodeByteIndex:		; $19d7
		.byte $00




; Blits a rectangular image with pixel alignment that was previously configured with
; a helper routine (such as setBlitPos, setAnimLoc, or clipToScroll)
blitImage:			; $19d8
        sta     ZP_REGISTER_A			; Save registers
        stx     ZP_REGISTER_X
        sty     ZP_REGISTER_Y
        jsr     parseImageHeader
        jsr     applyClipping
        jsr     calcRowBitByte

blitImageLoop:
		jsr     nextImageDestRow

        ldx     ZP_CURR_X_BIT
        lda     pixelMasksRight,x
        sta     ZP_PIXEL_MASK

blitImageRowLoop:
		lda     #$00				; Calculate sub-byte alignment of row start
        sta     ZP_PIXELS
        ldy     ZP_RENDER_CURRBIT
        lda     ZP_BITSCRATCH
blitImageRowStartLoop:
		asl
        ror     ZP_PIXELS
        dey
        beq     blitImageRowWrapWord

blitImageRowWrapLoop:
		dec     ZP_RENDER_CURR_W			; Advance along row
        beq     blitImageRowDone
        dex
        bne     blitImageRowStartLoop
        sty     ZP_RENDER_CURRBIT
        sta     ZP_BITSCRATCH
        lsr     ZP_PIXELS					; $1a0a

        ldy     ZP_CURR_X_BYTEC		; Load pixels from this byte on screen
        lda     (ZP_HGRPTR_L),y
        and     ZP_PIXEL_MASK		; Mask out the area for the start of our line
        ora     ZP_PIXELS			; Combine with our new pixels
        ora     ZP_PALETTE			; Add palette as needed
        sta     (ZP_HGRPTR_L),y		; Write combined pixels back to screen
        iny							; Advance to next byte
        sty     ZP_CURR_X_BYTEC

        lda     #$00				; Full bytes for the row from now on
        sta     ZP_PIXEL_MASK
        ldx     #$07
        jmp     blitImageRowLoop

blitImageRowDone:
		lda     #$00				; Calculate sub-byte alignment of row end?
        dex
        beq     blitImageRowByteEnd ; Row end is byte aligned
blitImageRowEndLoop:
		lsr     ZP_PIXELS
        sec
        ror
        dex
        bne     blitImageRowEndLoop

blitImageRowByteEnd:
		lsr
        ora     ZP_PIXEL_MASK
        sta     ZP_PIXEL_MASK
        lsr     ZP_PIXELS
        ldy     ZP_CURR_X_BYTEC
        lda     (ZP_HGRPTR_L),y		; Load pixels from this byte on screen
        and     ZP_PIXEL_MASK		; Mask out the area for the end of our line?
        ora     ZP_PIXELS			; Combine with new pixels
        ora     ZP_PALETTE			; Add palette as needed
        sta     (ZP_HGRPTR_L),y		; Write combined pixels back to screen
									
        dec     ZP_IMAGE_H			; Any rows left?
        beq     blitImageDone

        dec     ZP_RENDER_CURR_Y
        jmp     blitImageLoop

blitImageRowWrapWord:
		inc     ZP_RENDER_CURRBYTE
        ldy     ZP_RENDER_CURRBYTE
        lda     (ZP_PARAM_PTR_L),y	; Fetch next source byte of pixels
        ldy     #$08
        jmp     blitImageRowWrapLoop

blitImageDone:
		lda     ZP_REGISTER_A		; Restore registers
        ldx     ZP_REGISTER_X
        ldy     ZP_REGISTER_Y
        rts


; Blits a rectangular image flipped left/right with pixel alignment. The image was previously
; configured with a helper routine (such as setBlitPos, setAnimLoc, or clipToScroll)
; This is a copy of blitImage above, but the left/right iteration is flipped
blitImageFlip:	; $1a5e
		sta     ZP_REGISTER_A				; Save registers
        stx     ZP_REGISTER_X
        sty     ZP_REGISTER_Y

        ldx     ZP_LEFTCLIP				; Swap clipping state for flipped rendering
        ldy     ZP_RIGHTCLIP
        sty     ZP_LEFTCLIP
        stx     ZP_RIGHTCLIP

        jsr     parseImageHeader
        jsr     applyClipping
        jsr     nextImageSrcRow

blitImageFlipOuterLoop:
		jsr     nextImageDestRow
        sec
        lda     #$08
        sbc     ZP_CURR_X_BIT
        tax
        lda     pixelMasksLeft,x
        sta     ZP_PIXEL_MASK
blitImageFlipRowLoop:
		lda     #$00
        sta     ZP_PIXELS
        ldy     ZP_RENDER_CURRBIT
        lda     ZP_BITSCRATCH
blitImageFlipStartLoop:
		asl
        rol     ZP_PIXELS
        dey
        beq     blitImageFlipWrapWord

blitImageFlipInnerLoop:
		dec     ZP_RENDER_CURR_W
        beq     blitImageFlipRowDone
        dex
        bne     blitImageFlipStartLoop
        sty     ZP_RENDER_CURRBIT
        sta     ZP_BITSCRATCH

        ldy     ZP_CURR_X_BYTEC
        lda     (ZP_HGRPTR_L),y		; Combine byte with...
        and     ZP_PIXEL_MASK		; ...background
        ora     ZP_PIXELS			; ...new pixels
        ora     ZP_PALETTE			; ...and palette
        sta     (ZP_HGRPTR_L),y		; Write it back to screen
        dey
        sty     ZP_CURR_X_BYTEC
        lda     #$00
        sta     ZP_PIXEL_MASK
        ldx     #$07
        jmp     blitImageFlipRowLoop

blitImageFlipRowDone:
		lda     #$00
        dex
        beq     blitImageFlipRowByteEnd
blitImageFlipEndLoop:
		asl     ZP_PIXELS
        sec
        rol
        dex
        bne     blitImageFlipEndLoop

blitImageFlipRowByteEnd:
		ora     ZP_PIXEL_MASK
        sta     ZP_PIXEL_MASK
        ldy     ZP_CURR_X_BYTEC

        lda     (ZP_HGRPTR_L),y		; Combine byte with...
        and     ZP_PIXEL_MASK		; ...background
        ora     ZP_PIXELS			; ...new pixels
        ora     ZP_PALETTE			; ...and palette
        sta     (ZP_HGRPTR_L),y		; Write it back to screen

        dec     ZP_IMAGE_H
        beq     blitImageFlipDone
        dec     ZP_RENDER_CURR_Y
        jmp     blitImageFlipOuterLoop

blitImageFlipWrapWord:
		inc     ZP_RENDER_CURRBYTE
        ldy     ZP_RENDER_CURRBYTE
        lda     (ZP_PARAM_PTR_L),y	; Fetch next source byte of pixels
        ldy     #$08
        jmp     blitImageFlipInnerLoop

blitImageFlipDone:
		ldx     ZP_LEFTCLIP			; Swap clipping state back
        ldy     ZP_RIGHTCLIP
        sty     ZP_LEFTCLIP
        stx     ZP_RIGHTCLIP

        lda     ZP_REGISTER_A			; Restore registers
        ldx     ZP_REGISTER_X
        ldy     ZP_REGISTER_Y
        rts



; Note from Quinn, the reverse engineer:
; Below are the tilted sprite rendering routines. This is really the secret sauce of the entire
; Choplifter rendering engine. This is what allows the game to use a single sprite (say, of the
; chopper) yet render at all different angles of flight. This is a complex
; and tricky system which is essentially a basic case of a scan-line converter that you would find
; in the texture mapper of a 3D renderer. It's not quite that general, but it's getting there. This
; is clever code, and I won't sit here and tell you I completely understand it. If I hadn't done my
; time writing software rasterizers in 3D engines in the mid 1990s, I'm not sure I would even
; understand the little bit of this that I do. I've done my best to highlight the broad strokes in
; comments and labels, but writing a texture mapper that works with the insane memory map of Apple II
; high res is no small feat. Yes, he could have perhaps included multiple sprites for each angle the
; chopper flies at instead, but he didn't. It is not for me to judge, it is only for me to document.
; Note that he doesn't always use this. When flying sideways, the chopper does use separate sprites,
; for example. However when flying head on, there is only one sprite and this tilt renderer is used.

; Renders a sprite tilted to the left. Preserves registers.
renderTiltedSpriteLeft:			; $1af3
		sta     ZP_REGISTER_A
        stx     ZP_REGISTER_X
        sty     ZP_REGISTER_Y
        lda     #$00
        sta     ZP_SPRITE_TILT
        jmp     renderTiltedSprite

; Renders a sprite tilted to the right. Preserves registers.
renderTiltedSpriteRight:
        sta     ZP_REGISTER_A
        stx     ZP_REGISTER_X
        sty     ZP_REGISTER_Y
        lda     #$FF
        sta     ZP_SPRITE_TILT

renderTiltedSprite:					; Stub entry point for left and right versions of this routine
		jsr     parseImageHeader
        jsr     nextImageSrcRowTilt
        lda     ZP_SCREEN_Y
        sta     ZP_CURR_Y
        lda     ZP_SPRITE_TILT_OFFSET
        sta     ZP_CURRTILT_OFFSET

renderTiltedSpriteLoop:
		lda     ZP_SPRITE_TILT_OFFSET
        sta     ZP_OFFSET_REMAINING
        lda     ZP_CURRTILT_OFFSET
        sta     ZP_TILTSCRATCH

        ldx     ZP_CURR_Y			; Calculate HGR memory row for Y position
        stx     ZP_RENDER_CURR_Y
        lda     hiResRowsLow,x
        sta     ZP_HGRPTR_L
        lda     hiResRowsHigh,x
        eor     ZP_PAGEMASK
        sta     ZP_HGRPTR_H

        lda     ZP_CURR_X_BYTE				; Reset our horizontal counters
        sta     ZP_RENDER_CURRBYTE
        lda     ZP_CURR_X_BIT
        sta     ZP_RENDER_CURRBIT
        lda     ZP_IMAGE_W
        sta     ZP_RENDER_CURR_W

        ldy     #$00
        sty     ZP_SPAN_COUNTER
        lda     (ZP_PARAM_PTR_L),y			; A=width of sprite in pixels
        sta     ZP_BITSCRATCH

renderTiltedSpriteInnerLoop:
		asl     ZP_BITSCRATCH
        bcc     renderTiltedSpriteNoBit

        lda     ZP_RENDER_CURRBIT			; Fetch next pixels from sprite
        ldy     ZP_RENDER_CURRBYTE
        ora     (ZP_HGRPTR_L),y				; Combine with background
        sta     (ZP_HGRPTR_L),y				; Write to screen

renderTiltedSpriteNoBit:
		dec     ZP_OFFSET_REMAINING
        bne     renderTiltedSpriteMoreOffset
        lda     ZP_SPRITE_TILT_OFFSET
        sta     ZP_OFFSET_REMAINING

        clc									; Modify Y pos for tilt
        lda     ZP_RENDER_CURR_Y
        adc     ZP_SPRITE_TILT_SIGN
        sta     ZP_RENDER_CURR_Y

        tax									; Calculate HGR memory position
        lda     hiResRowsLow,x
        sta     ZP_HGRPTR_L
        lda     hiResRowsHigh,x
        eor     ZP_PAGEMASK
        sta     ZP_HGRPTR_H

        clc									; Calculate next position caused by tilt
        lda     ZP_TILTSCRATCH
        adc     ZP_SPRITE_TILT_SIGN
        sta     ZP_TILTSCRATCH
        beq     renderTiltedSpriteNeutral
        cmp     ZP_SPRITE_TILT_OFFSET
        bcs     renderTiltedSpriteOverflow
        jmp     renderTiltedSpriteMoreOffset

renderTiltedSpriteNeutral:
		lda     ZP_SPRITE_TILT_OFFSET
        sta     ZP_TILTSCRATCH
        jmp     renderTiltedSpriteNextPixel

renderTiltedSpriteOverflow:
		lda     #$01						; Reset tilt to small right if overflow occurs
        sta     ZP_TILTSCRATCH
        jmp     renderTiltedSpriteNextPixel

renderTiltedSpriteMoreOffset:
		bit     ZP_SPRITE_TILT
        bmi     renderTiltedSpriteLeftward
        asl     ZP_RENDER_CURRBIT
        bpl     renderTiltedSpriteNextPixel
        lda     #$01
        sta     ZP_RENDER_CURRBIT
        inc     ZP_RENDER_CURRBYTE
        jmp     renderTiltedSpriteNextPixel

renderTiltedSpriteLeftward:
		lsr     ZP_RENDER_CURRBIT
        bne     renderTiltedSpriteNextPixel
        lda     #$40
        sta     ZP_RENDER_CURRBIT
        dec     ZP_RENDER_CURRBYTE

renderTiltedSpriteNextPixel:
		dec     ZP_RENDER_CURR_W		; Advance along width of source image
        beq     renderTiltedSpriteRowDone
        inc     ZP_SPAN_COUNTER
        lda     ZP_SPAN_COUNTER
        cmp     #$08
        bne     renderTiltedSpriteInnerLoop
        lda     #$00
        sta     ZP_SPAN_COUNTER

        inc     ZP_PARAM_PTR_L			; Advance image pointer
        bne     renderTiltedSpriteNoPtrWrap
        inc     ZP_PARAM_PTR_H

renderTiltedSpriteNoPtrWrap:
		ldy     #$00
        lda     (ZP_PARAM_PTR_L),y
        sta     ZP_BITSCRATCH					; Cache next byte of source pixels
        jmp     renderTiltedSpriteInnerLoop

renderTiltedSpriteRowDone:
		dec     ZP_IMAGE_H				; Next row. Are we done?
        beq     renderTiltedSpriteDone

        inc     ZP_PARAM_PTR_L			; Advance image pointer
        bne     renderTiltedSpriteNoPtrWrap2
        inc     ZP_PARAM_PTR_H

renderTiltedSpriteNoPtrWrap2:
		dec     ZP_CURR_Y				; Advance to next row
        dec     ZP_CURRTILT_OFFSET
        beq     renderTiltedSpriteOffsetDone
        jmp     renderTiltedSpriteLoop	; Do it all again!

renderTiltedSpriteOffsetDone:
		lda     ZP_SPRITE_TILT_OFFSET
        sta		ZP_CURRTILT_OFFSET
        lda     ZP_SPRITE_TILT_SIGN
        eor     ZP_SPRITE_TILT
        bmi     renderTiltedSpriteTiltWrap
        asl     ZP_CURR_X_BIT
        bpl     renderTiltedSpriteNextRow
        lda     #$01
        sta     ZP_CURR_X_BIT
        inc     ZP_CURR_X_BYTE
        jmp     renderTiltedSpriteNextRow

renderTiltedSpriteTiltWrap:
		lsr     ZP_CURR_X_BIT
        bne     renderTiltedSpriteNextRow
        lda     #$40
        sta     ZP_CURR_X_BIT
        dec     ZP_CURR_X_BYTE

renderTiltedSpriteNextRow:
		jmp     renderTiltedSpriteLoop

renderTiltedSpriteDone:
		lda     ZP_REGISTER_A
        ldx     ZP_REGISTER_X
        ldy     ZP_REGISTER_Y
        rts					; $1c01



; Graphics page lookup table. Remaps the wacky Apple II
; video memory into a linear order. Some version of this table exists in every Apple
; II game ever made so that Woz could save a chip. What's different about this one
; is that Dan chose to map line 0 to the bottom of the screen, not the top. This is
; a more classical formal computer graphics way to do it, but opposite of the norm
; in 2D game development.

hiResRowsLow:			; $1c02  192 rows, low byte
		.byte $D0,$D0,$D0,$D0,$D0,$D0,$D0,$D0,$50,$50,$50,$50,$50,$50,$50,$50
		.byte $D0,$D0,$D0,$D0,$D0,$D0,$D0,$D0,$50,$50,$50,$50,$50,$50,$50,$50
		.byte $D0,$D0,$D0,$D0,$D0,$D0,$D0,$D0,$50,$50,$50,$50,$50,$50,$50,$50
		.byte $D0,$D0,$D0,$D0,$D0,$D0,$D0,$D0,$50,$50,$50,$50,$50,$50,$50,$50
		.byte $A8,$A8,$A8,$A8,$A8,$A8,$A8,$A8,$28,$28,$28,$28,$28,$28,$28,$28
		.byte $A8,$A8,$A8,$A8,$A8,$A8,$A8,$A8,$28,$28,$28,$28,$28,$28,$28,$28
		.byte $A8,$A8,$A8,$A8,$A8,$A8,$A8,$A8,$28,$28,$28,$28,$28,$28,$28,$28
		.byte $A8,$A8,$A8,$A8,$A8,$A8,$A8,$A8,$28,$28,$28,$28,$28,$28,$28,$28
		.byte $80,$80,$80,$80,$80,$80,$80,$80,$00,$00,$00,$00,$00,$00,$00,$00
		.byte $80,$80,$80,$80,$80,$80,$80,$80,$00,$00,$00,$00,$00,$00,$00,$00
		.byte $80,$80,$80,$80,$80,$80,$80,$80,$00,$00,$00,$00,$00,$00,$00,$00
		.byte $80,$80,$80,$80,$80,$80,$80,$80,$00,$00,$00,$00,$00,$00,$00,$00

; Graphics page lookup table, rows, high byte  (192 rows)
hiResRowsHigh:		; $1cc2		192 rows, high byte

		.byte $3F,$3B,$37,$33,$2F,$2B,$27,$23,$3F,$3B,$37,$33,$2F,$2B,$27,$23
		.byte $3E,$3A,$36,$32,$2E,$2A,$26,$22,$3E,$3A,$36,$32,$2E,$2A,$26,$22
		.byte $3D,$39,$35,$31,$2D,$29,$25,$21,$3D,$39,$35,$31,$2D,$29,$25,$21
		.byte $3C,$38,$34,$30,$2C,$28,$24,$20,$3C,$38,$34,$30,$2C,$28,$24,$20
		.byte $3F,$3B,$37,$33,$2F,$2B,$27,$23,$3F,$3B,$37,$33,$2F,$2B,$27,$23
		.byte $3E,$3A,$36,$32,$2E,$2A,$26,$22,$3E,$3A,$36,$32,$2E,$2A,$26,$22
		.byte $3D,$39,$35,$31,$2D,$29,$25,$21,$3D,$39,$35,$31,$2D,$29,$25,$21
		.byte $3C,$38,$34,$30,$2C,$28,$24,$20,$3C,$38,$34,$30,$2C,$28,$24,$20
		.byte $3F,$3B,$37,$33,$2F,$2B,$27,$23,$3F,$3B,$37,$33,$2F,$2B,$27,$23
		.byte $3E,$3A,$36,$32,$2E,$2A,$26,$22,$3E,$3A,$36,$32,$2E,$2A,$26,$22
		.byte $3D,$39,$35,$31,$2D,$29,$25,$21,$3D,$39,$35,$31,$2D,$29,$25,$21
		.byte $3C,$38,$34,$30,$2C,$28,$24,$20,$3C,$38,$34,$30,$2C,$28,$24,$20

; Lookup tables for bit masks of pixels within a byte
pixelMasksRight:	; $1d82  Right end of byte, decreasing
	.byte	$00,$3f,$1f,$0f,$07,$03,$01,$00

pixelMasksLeft:		; $1d8a Left end of byte, decreasing
	.byte	$00,$7e,$7c,$78,$70,$60,$40,$00

.org $1d92

; 622 unused bytes until bottom of HGR page 0 at $2000
UNUSED 622


; Skip over high res pages
;UNUSED 16384

.segment "HICODE"

; Start of more code after the hi-res pages

.org $6000
; Another jump table. All of the spawn routines are called directly, bypassing
; this table. I guess Dan decided not to use it, or possibly forgot he had implemented it
jumpUpdateHostages:		jmp 	updateHostages	; $6000
jumpSpawnHostages:		jmp 	spawnHostages	; $6003
jumpSpawnTank:			jmp 	spawnTank		; $6006
jumpSpawnJet:			jmp 	spawnJet		; $6009
jumpSpawnAlien:			jmp 	spawnAlien		; $600c
jumpUpdateTank:			jmp 	updateTank		; $600f
jumpSpawnEnemies:		jmp 	spawnEnemies	; $6012




; Updates and renders all the hostages. This does it all- animation, game logic, rendering,
; and even waving at us to save them. The best feature in the game.
updateHostages:			; $6015
		lda     #$00
        sta     updateHostageIndex
        tax

updateHostagesLoop:
		lda     hostageTable,x
        bpl     updateHostagesGo		; Skip unallocated hostage slots
        jmp     updateHostagesNext

updateHostagesGo:
		sec
        lda     hostageTable+3,x		; X position (high byte)
        sbc     CHOP_POS_X_H			; Visible from player?
        beq     updateHostagesVisible
        cmp     #$03
        bcc     updateHostagesVisible
        cmp     #$FE
        bcs     updateHostagesVisible

        lda     hostageTable+3,x		; X position (high byte)
        cmp     BASE_X_H				; Is hostage close to base?
        bcs     updateHostagesEnterBase
        jmp     updateHostagesNext

updateHostagesEnterBase:				; You're saved, little buddy!
		dec     BASE_RUNNERS
        lda     #$FF					; Deallocate hostage slot
        sta     hostageTable,x
        jmp     updateHostagesNext

updateHostagesVisible:
		lda     hostageTable+1,x		; Check current action
        beq     updateHostagesWaving
        cmp     #$FF
        beq     updateHostagesRunLeft
        cmp     #$01
        bne     updateHostagesWaving

        clc								; Move to the right two pixels

        lda     hostageTable+2,x		; X position, low byte
        adc     #$02
        sta     hostageTable+2,x		; X position, low byte
        lda     hostageTable+3,x		; X position, high byte
        adc     #$00
        sta     hostageTable+3,x		; X position, high byte
        jmp     updateHostagesWaving

updateHostagesRunLeft:  				; Move to the left two pixels
		sec
        lda     hostageTable+2,x		; X position, low byte
        sbc     #$02
        sta     hostageTable+2,x		; X position, low byte
        lda     hostageTable+3,x		; X position, high byte
        sbc     #$00
        sta     hostageTable+3,x		; X position, high byte

updateHostagesWaving:
		inc     hostageTable,x			; Increment waving animation frame
        lda     hostageTable,x
        cmp     #$04					; Wrap at four frames
        bcs     updateHostagesWaveWrap
        jmp     updateHostagesActionChosen

updateHostagesWaveWrap:
		lda     #$00
        sta     hostageTable,x

        lda     ZP_DYING				; Is chopper crashing
        beq     updateHostagesPlayerAlive

        lda     hostageTable+3,x		; X position, high byte
        cmp     BASE_X_H
        bcs     updateHostagesDefault	; When in doubt run towards the base

        sec								; Where are we relative to player?
        lda     hostageTable+2,x		; X position, low byte
        sbc     CHOP_POS_X_L
        lda     hostageTable+3,x		; X position, high byte
        sbc     CHOP_POS_X_H
        bmi     updateHostagesChopperLeft	; Run away from the player since they are crashing

updateHostagesDefault:
		jmp     updateHostagesChopperRight

updateHostagesPlayerAlive:
		lda     ZP_AIRBORNE
        bne     updateHostagesPlayerAloft
        lda     hostageTable+3,x		; X position, high byte
        cmp     BASE_X_H
        bcc     updateHostagesPlayerAloft

        stx     updateHostageIndexSave	; Save hostage index so we can trash X
        jsr     jumpRandomNumber		; When player is touched down, scramble randomly under them
        ldx     updateHostageIndexSave
        and     #$29
        beq     updateHostagesStartWave
        jmp     updateHostagesChopperRight

updateHostagesPlayerAloft:
		lda     ZP_AIRBORNE				; Can we be picked up?
        bne     updateHostagesPlayerStillAloft
        lda     ZP_LANDED_BASE
        bne     updateHostagesPlayerStillAloft
        lda     HOSTAGES_LOADED
        cmp     #$10
        beq     updateHostagesPlayerStillAloft

        sec								; Where are we relative to player?
        lda     hostageTable+2,x		; X position, low byte
        sbc     CHOP_POS_X_L
        lda     hostageTable+3,x		; X position, high byte
        sbc     CHOP_POS_X_H
        bpl     updateHostagesChopperLeft		; Run towards chopper
        jmp     updateHostagesChopperRight

updateHostagesPlayerStillAloft:
		stx     updateHostageIndexSave		; Need to trash X again
        jsr     jumpRandomNumber
        sta     ZP_SCRATCH58
        ldx     updateHostageIndexSave
        and     #$09
        beq     updateHostagesCheckMoving	; Start a wave, unless we're already waving
        jmp     updateHostagesActionChosen

updateHostagesCheckMoving:
		lda     hostageTable+1,x
        beq     updateHostagesEndWave		; Time to run again

updateHostagesStartWave:
		lda     #$00
        sta     hostageTable+1,x
        jmp     updateHostagesActionChosen

updateHostagesEndWave:
		lda     hostageTable+3,x				; X position, high byte
        cmp     BASE_X_H
        bcs     updateHostagesChopperRight		; Pick a direction after waving
        lda     ZP_SCRATCH58
        and     #$20
        beq     updateHostagesChopperRight

updateHostagesChopperLeft:
		lda     #$FF					; Run towards chopper
        sta     hostageTable+1,x
        jmp     updateHostagesActionChosen

updateHostagesChopperRight:
		lda     #$01					; Run towards chopper
        sta     hostageTable+1,x

updateHostagesActionChosen:
		lda     hostageTable+3,x		; X position, high byte
        cmp     DOOR_X_H				; Are we at the door of the base?
        bne     updateHostagesNoExit
        lda     hostageTable+2,x		; X position, low byte
        cmp     DOOR_X_L
        bcc     updateHostagesNoExit

        dec     BASE_RUNNERS			; You made it to the door! You're saved!
        lda     #$FF					; Deallocate the hostage
        sta     hostageTable,x
        jmp     updateHostagesNext

updateHostagesNoExit:
		lda     ZP_LANDED
        beq     updateHostagesNotLanded
        lda     ZP_DYING
        bne     updateHostagesNotLanded
        jmp     updateHostagesCheckBoarding
updateHostagesNotLanded:
		jmp     updateHostagesBeginRender

updateHostagesCheckBoarding:			; Chopper fully landed, so boarding is possible
		lda     hostageTable+3,x		; X position, high byte
        cmp     BASE_X_H
        bcs     updateHostagesNotLanded	; Don't try to board if we're right of the base
        lda     hostageTable+1,x
        and     #$03
        cmp     #$02
        beq     updateHostagesNotLanded

        sec								; Determine direction to chopper to attempt boarding
        lda     hostageTable+2,x		; X position, low byte
        sbc     CHOP_POS_X_L
        sta     ZP_SCRATCH58				; Cache small vector to chopper
        lda     hostageTable+3,x		; X position, high byte
        sbc     CHOP_POS_X_H
        beq     updateHostagesProxCheckRight
        cmp     #$FF
        beq     updateHostagesProxCheckLeft
        jmp     updateHostagesBeginRender

updateHostagesProxCheckRight:
		lda     ZP_SCRATCH58
        cmp     #$08					; Are we close enough to board from the right?
        bcc     updateHostagesCrushedRight		; Too close! Too close!
        cmp     #$0A
        bcs     updateHostagesRenderBranch

        lda     HOSTAGES_LOADED			; Room for us onboard?
        cmp     #$10
        beq     updateHostagesChopperFullRight
        lda     #$FE					; Get on board!
        sta     hostageTable+1,x
        jmp     updateHostagesLoad

updateHostagesCrushedRight:
		jmp     updateHostagesDead
updateHostagesRenderBranch:
		jmp     updateHostagesBeginRender

updateHostagesChopperFullRight:
		lda     #$00
        sta     hostageTable,x
        lda     #$01					; Start running toward base again. There's no room for us!
        sta     hostageTable+1,x
        jmp     updateHostagesBeginRender

updateHostagesProxCheckLeft:
		lda     ZP_SCRATCH58
        cmp     #$F7					; Are we close enough to board from the left?
        bcs     updateHostagesDead		; Too close! Too close!
        cmp     #$F5
        bcc     updateHostagesBeginRender

        lda     HOSTAGES_LOADED			; Room for us onboard?
        cmp     #$10
        beq     updateHostagesChopperFullLeft
        lda     #$02					; Get on board!
        sta     hostageTable+1,x
        jmp     updateHostagesLoad

updateHostagesChopperFullLeft:
		lda     #$00					; Start running again. There's no room for us!
        sta     hostageTable,x
        lda     #$FF
        sta     hostageTable+1,x
        jmp     updateHostagesBeginRender

updateHostagesLoad:
		lda     #$00					; Load the hostage
        sta     hostageTable,x
        inc     HOSTAGES_LOADED
        dec     HOSTAGES_ACTIVE

        jsr     jumpIncrementHUDLoaded
        lda     #$FF
        sta     CHOP_LOADED
        bit     HOSTAGE_FIRSTLOAD			; Only play sound on first hostage per frame that is loaded
        bmi     updateHostagesRenderSkipSound

        stx     updateHostageIndexSave		; Need to borrow X for a moment
        ldx     #$FF
        ldy     #$0C
        lda     #$00
        jsr     jumpPlaySound				; Play the boarding ditty
        ldx     #$E0
        ldy     #$0E
        lda     #$00
        jsr     jumpPlaySound
        ldx     #$98
        ldy     #$10
        lda     #$00
        jsr     jumpPlaySound
        ldx     updateHostageIndexSave

        lda     #$FF						; No more loading sound until next frame
        sta     HOSTAGE_FIRSTLOAD

updateHostagesRenderSkipSound:
		jmp     updateHostagesBeginRender

updateHostagesDead:
		jsr     killHostage
        jmp     updateHostagesNext

updateHostagesBeginRender:
		lda     hostageTable+1,x		; Cache our action for rendering routine
        sta     ZP_SCRATCH63
        beq     updateHostagesDoWave
        and     #$01
        bne     updateHostagesDoRun
        jmp     updateHostagesDoLoad

updateHostagesDoWave:
		lda     hostageTable,x		; Calculate sprite pointer from animation frame
        asl
        eor     #$FF
        and     hostageTable,x
        asl
        tay
        lda     hostageWavingSpriteTable,y		; Prepare to render
        sta     ZP_SPRITE_PTR_L
        lda     hostageWavingSpriteTable+1,y
        sta     ZP_SPRITE_PTR_H
        jsr     jumpSetSpriteAnimPtr
				.word   $001a
        jsr     renderHostage					; Draw the little dude
        jmp     updateHostagesNext

updateHostagesDoRun:
		lda     hostageTable,x		; Calculate sprite pointer from animation frame
        asl
        tay
        lda     hostageRunningSpriteTable,y			; Prepare to render
        sta     ZP_SPRITE_PTR_L
        lda     hostageRunningSpriteTable+1,y
        sta     ZP_SPRITE_PTR_H
        jsr     jumpSetSpriteAnimPtr
				.word   $001a
        jsr     renderHostage				; Draw the little dude
        jmp     updateHostagesNext

updateHostagesDoLoad:
		lda     hostageTable,x		; Calculate sprite pointer from animation frame
        and     #$02
        tay
        lda     hostageLoadingSpriteTable,y			; Prepare to render
        sta     ZP_SPRITE_PTR_L
        lda     hostageLoadingSpriteTable+1,y
        sta     ZP_SPRITE_PTR_H
        jsr     jumpSetSpriteAnimPtr
				.word   $001a
        jsr     renderHostage				; Draw the little dude

        lda     hostageTable,x
        cmp     #$03						; When loading animation is done, we made it in
        beq     updateHostagesLoadDone
        lda     ZP_LANDED
        beq     updateHostagesLoadDone
        jmp     updateHostagesNext

updateHostagesLoadDone:
		lda     #$FF						; Deallocate the dude
        sta     hostageTable,x

updateHostagesNext:
		inc     updateHostageIndex			; On to the next hostage!
        lda     updateHostageIndex
        cmp     MAX_HOSTAGES
        beq     updateHostagesDone
        asl
        asl
        tax
        jmp     updateHostagesLoop

updateHostagesDone:
		rts


updateHostageIndex:			; $628c Current hostage being updated
		.byte 	$00
updateHostageIndexSave:		; $628d A cache to save above value
		.byte 	$00


; Internal utility routine for rendering hostages. Sprite has been previously setup
; and current hostage state above is assumed to be set.
renderHostage:				; $628e
		sec
        lda     hostageTable+2,x		; X position, low byte
        sbc     #$04					; Hostage sprite origin is -4
        sta     ZP_RENDERPOS_XL
        lda     hostageTable+3,x		; X position, high byte
        sbc     #$00
        sta     ZP_RENDERPOS_XH

        lda     ZP_SCROLLPOS_L			; Keep us on odd pixels for scrolling
        and     #$01					; Hostages move by 2 as well, so always render on odd
        eor     #$01
        eor     ZP_RENDERPOS_XL
        sta     ZP_RENDERPOS_XL

        clc
        lda     CHOP_GROUND				; Place us well in front of chopper's plane on ground
        adc     #$0B
        sta     ZP_RENDERPOS_Y

        jsr     jumpSetWorldspace		; Prepare to render
				.word   $001C
		jsr     jumpClipToScroll
        bcs     renderHostageClipped

        lda     #$11
        jsr     jumpPosToScreenspace
        lda     ZP_SCRATCH63				; This is our action, cached in update routine
        bmi     renderHostageLeftAction
        cmp     #$40					; Check for dying sprite
        beq     renderHostageSpecialAction
        jsr		jumpRenderSpriteRight
		rts

renderHostageLeftAction:
        jsr     jumpRenderSpriteLeft	; We're left-running or left-loading, so flip sprite
        rts

renderHostageClipped:
		rts

renderHostageSpecialAction:
        lda     #$FF					; Dying sprite needs different palette
        jsr     jumpSetPalette
        jsr     jumpRenderSprite
        rts



; Kills a hostage. Sorry, little buddy! We tried our best.
; X = Index of hostage to kill
killHostage:			; $62d7
		lda     #$FF					; Deallocate hostage
        sta     hostageTable,x

        jsr     jumpSetSpriteAnimPtr
				.word   $a092			; Pointer to dying hostage sprite
		lda     #$40					; Special marker for death used in renderHostage
        sta     ZP_SCRATCH63

        jsr     renderHostage
        inc     HOSTAGES_KILLED
        dec     HOSTAGES_ACTIVE
        jsr     jumpIncrementHUDKilled
        rts



; Spawns new hostages as needed
spawnHostages:		; $62f2
		clc
        lda     BASE_RUNNERS
        adc     HOSTAGES_ACTIVE
        cmp     #$10				; Can only have 16 active at once
        beq     spawnHostagesSkip
        lda     ZP_LANDED_BASE
        bne     spawnHostagesAtBase
        lda     HOSTAGES_LEFT		; Any hostages left in game?
        beq     spawnHostagesSkip
        lda     HOSTAGES_ACTIVE		; Only spawn a few at a time
        cmp     #$05
        bcs     spawnHostagesSkip
        jmp     spawnHostagesReady

spawnHostagesAtBase:
		lda     HOSTAGES_LOADED
        beq     spawnHostagesSkip	; No hostages in chopper. Sorry!
        jmp     spawnNewHostage2
spawnHostagesSkip:
		rts

spawnHostagesReady:
		sec
        lda     CHOP_POS_X_H		; Check if we're within spawning area
        sbc     FARHOUSE_X_H
        bmi     spawnHostagesChooseHouse
        cmp     #$04
        bcs     spawnHostagesChooseHouse

        tax
        lda     houseStates,x		; Check if this house on fire
        beq     spawnHostagesChooseHouse
        lda     hostagesInHouses,x	; Check if this house has anyone in it
        beq     spawnHostagesChooseHouse
        jmp     spawnNewHostage

spawnHostagesChooseHouse:
		jsr     jumpRandomNumber
        and     #$03
        tax
        sta     spawnHouseIndex

spawnHostagesLoop:
		lda     houseStates,x			; Is house on fire?
        beq     spawnHostagesNextHouse
        lda     hostagesInHouses,x		; Any hostages left inside?
        beq     spawnHostagesNextHouse
        jmp     spawnNewHostage

spawnHostagesNextHouse:			; That house was inelligible, so try another
		inx
        cpx     #$04
        bne     spawnHostagesNoWrap
        ldx     #$00
spawnHostagesNoWrap:
		cpx     spawnHouseIndex
        bne     spawnHostagesLoop
        rts

spawnNewHostage:
		stx     spawnHouseIndex
spawnNewHostage2:
		ldy     MAX_HOSTAGES			; Find a free hostage record in the table
spawnNewHostageLoop:
		dey
        tya
        asl								; Convert index to pointer
        asl
        tax
        lda     hostageTable,x
        bpl     spawnNewHostageLoop		; $00 means already allocated

        stx     newHostageIndex			; $ff indicates available hostage slot
        lda     ZP_LANDED_BASE			; Are we being spawned on base landing pad?
        beq     spawnNewHostageInField

        inc     TOTAL_RESCUES			; Spawning at home base as part of chopper unload
        dec     HOSTAGES_LOADED
        inc     BASE_RUNNERS
        jsr     jumpDecrementHUDLoaded
        jsr     jumpIncrementHUDRescued
        bit     CHOP_LOADED				; More hostages to unload?
        bpl     spawnNewHostageChopperEmpty
        lda     #$00
        sta     CHOP_LOADED
        lda     CURR_LEVEL				; Increase difficulty after each unload
        cmp     #$03
        beq     spawnNewHostageChopperEmpty
        inc     CURR_LEVEL

spawnNewHostageChopperEmpty:
		jsr     jumpRandomNumber
        and     #$03
        ldx     newHostageIndex
        sta     hostageTable,x			; Initial state set to random
        lda     #$01
        sta     hostageTable+1,x		; Unsure what this field is
        clc
        lda     CHOP_POS_X_L			; Set X position to chopper, with offset
        adc     #$04
        ora     #$01
        sta     hostageTable+2,x
        lda     CHOP_POS_X_H
        adc     #$00
        sta     hostageTable+3,x
        rts

spawnNewHostageInField:					; $63b2  Spawning a hostage in the field
		ldx     spawnHouseIndex
        dec     hostagesInHouses,x		; Remove them from the house
        dec     HOSTAGES_LEFT			; Update counters
        inc     HOSTAGES_ACTIVE
        jsr     jumpRandomNumber
        and     #$03
        ldx     newHostageIndex			; Start with random initial state
        sta     hostageTable,x
        jsr     jumpRandomNumber
        and     #$01
        bne     spawnNewHostageOdd
        lda     #$FF
spawnNewHostageOdd:
		sta     hostageTable+1,x		; Unsure what this field is
        clc
        lda     FARHOUSE_X_L			; Set X position to house we spawned from...
        adc     #$0A					; ...with small offset
        sta     hostageTable+2,x
        lda     spawnHouseIndex
        adc     FARHOUSE_X_H
        sta     hostageTable+3,x
        rts

spawnHouseIndex:		; $63E8 Caches random value generated for hostage spawning
		.byte $00
newHostageIndex:		; $63e9 Caches index of hostage just spawned
		.byte $00



; Spawns a new tank into play
spawnTank:				; $63ea
		sec
        lda     FENCE_X_H		; Is player in safe zone?
        sbc     CHOP_POS_X_H
        bmi     spawnTankSkip
        cmp     #$02
        bcc     spawnTankSkip
        lda     NUM_TANKS		; Room for more tanks?
        cmp     #$04
        bcc     spawnTankReady
spawnTankSkip:
		rts

spawnTankReady:  
		jsr     jumpAllocateEntity		; Allocate our new tank
        ldx     ZP_CURR_ENTITY
        lda     ZP_VELX_16_H			; Player VX affects spawning
        cmp     #$11
        bcc     spawnTankMedV
        cmp     #$EF
        bcs     spawnTankMedV
        bit     ZP_VELX_16_H
        bmi     spawnTankNegV
        jmp     spawnTankPosV

spawnTankMedV:					; Player VX is moderate
		jsr     jumpRandomNumber
        ldx     ZP_CURR_ENTITY
        and     #$08			; Randomly spawn behind you!
        bne     spawnTankPosV

spawnTankNegV:					; Player headed left, so spawn left of them
		sec
        lda     CHOP_POS_X_L
        sbc     #$B0
        sta     ENTITY_X_L,x
        lda     $05
        sbc     #$01
        sta     ENTITY_X_H,x
        lda     #$04			; Point cannon to our forward
        sta     ENTITY_DIR,x
        jmp     spawnTankY

spawnTankPosV:					; Player headed right, so spawn right of them
		clc
        lda     CHOP_POS_X_L
        adc     #$B0
        sta     ENTITY_X_L,x
        lda     CHOP_POS_X_H	; This does nothing- a bug or old code?
        adc     #$01			; This does nothing- a bug or old code?
        lda     #$00			; Point cannon to our forward
        sta     ENTITY_DIR,x	; Looks like there's a bug here- tanks are meant to spawn near you
        sta     ENTITY_X_H,x	; But High X is always set to zero when initialized like this

spawnTankY:
		lda     #$06
        sta     ENTITY_Y,x		; Set us on the ground

spawnTankPlaneLoop:				; Find a ground plane unused by other tanks
		jsr     jumpRandomNumber	; This is kind of a clunky hail mary loop
        and     #$07			; That starts randomly and then does iterate-and-pray
        clc						; to find an unused value
        adc     #$05
        ldy     NUM_TANKS
spawnTankPlaneLoop2:  
		dey
        bmi     spawnTankFinalize
        ldx     tankTable,y
        cmp     ENTITY_GROUND,x
        bne     spawnTankPlaneLoop2
        jmp     spawnTankPlaneLoop

spawnTankFinalize:
		ldx     ZP_CURR_ENTITY
        sta     ENTITY_GROUND,x
        lda     #$03			; Set type to tank
        sta     ENTITY_TYPE,x
        lda     #$0A
        sta     ENTITY_VX,x		; Standard tank rolling V
        lda     #$00
        sta     ENTITY_VY,x		; Tanks can't fly
        jsr     jumpDepthSortEntity

        ldx     NUM_TANKS		; Store our new entity ID in the tank table
        lda     ZP_CURR_ENTITY
        sta     tankTable,x
        inx
        stx     NUM_TANKS
        rts				; $6489



; Spawns a new jet into play
spawnJet:				; $648a
		lda     NUM_JETS
        cmp     #$04				; Room for more jets?
        bcc     spawnJetReady		; This check is also done below, so looks like there was a bug here at some point and this is a safeguard
        rts

spawnJetReady:
		jsr     jumpAllocateEntity		; Allocate the jet
        ldx     ZP_CURR_ENTITY
        lda     #$09				; Set type to jet
        sta     ENTITY_TYPE,x

        lda     #$00				; Start with level flight
        sta     ENTITY_VY,x

        lda     CHOP_POS_Y			; Spawn above player
        lsr
        clc
        adc     #$30
        cmp     #$69				; Clamp to highest altitude
        bcc     spawnJetAltClamp
        lda     #$68
spawnJetAltClamp:
		sta     ENTITY_Y,x

        clc
        lda     CHOP_GROUND			; Set plane away from player
        adc     #$20
        sta     ENTITY_GROUND,x

        lda     CURR_LEVEL
        cmp     #$02
        bcc     spawnJetRight		; Jets only come from in front on lower level
        jsr     jumpRandomNumber
        ldx     ZP_CURR_ENTITY
        ldy     CURR_LEVEL
        and     jetDifficultyTable,y
        beq     spawnJetLeft

spawnJetRight:
		lda     #$00				; "Easy" jets face right
        sta     ENTITY_VX,x
        jmp     spawnJetCheckV
spawnJetLeft:
		lda     #$80				; "Hard" jets come from behind you, facing left
        sta     ENTITY_VX,x
spawnJetCheckV:						; Player VX affects where we spawn
		lda     ZP_VELX_16_H
        cmp     #$11
        bcc     spawnJetMedV
        cmp     #$EF
        bcs     spawnJetMedV
        bit     ZP_VELX_16_H
        bmi     spawnJetNegV
        jmp     spawnJetPosV

spawnJetMedV:						; Moderate player velocity
		jsr     jumpRandomNumber	; Randomly spawn behind you!
        ldx     ZP_CURR_ENTITY
        and     #$10
        bne     spawnJetPosV

spawnJetNegV:
		lda     #$00				; Face right if player headed left
        sta     ENTITY_DIR,x

        sec
        lda     CHOP_POS_X_L		; Spawn left of player
        sbc     #$B8
        sta     ENTITY_X_L,x
        lda     CHOP_POS_X_H
        sbc     #$01
        sta     ENTITY_X_H,x
        jmp     spawnJetFinalize

spawnJetPosV:
		lda     #$FF				; Face left if player headed right
        sta     ENTITY_DIR,x

        clc							; Spawn right of player
        lda     CHOP_POS_X_L
        adc     #$B8
        sta     ENTITY_X_L,x
        lda     CHOP_POS_X_H
        adc     #$01
        sta     ENTITY_X_H,x

spawnJetFinalize:
		jsr     jumpDepthSortEntity
        ldx     NUM_JETS
        cpx     #$04
        beq     spawnJetFatal		; Assertion for too many jets

        lda     ZP_CURR_ENTITY		; Store our new entity ID in jet table
        sta     jetTable,x
        inx
        stx     NUM_JETS
        rts

spawnJetFatal:
		jsr     $fbdd				; Beep and crash
        brk

jetDifficultyTable:		; $6536 Modifies jet trickiness at higher levels
		.byte	$00,$00,$2C,$44



; Spawns a new alien into play
spawnAlien:				; $653a
		sec
        lda     FENCE_X_H
        sbc     CHOP_POS_X_H			; Has player left safe zone?
        bmi     spawnAlienSkip
        cmp     #$02
        bcc     spawnAlienSkip
        lda     NUM_ALIENS				; Room for more aliens?
        cmp     #$04					; This check is also done below, so looks like there was a bug here at some point and this is a safeguard
        bcc     spawnAlienReady
spawnAlienSkip:
		rts

spawnAlienReady:  
		jsr     jumpAllocateEntity		; Create the alien entity
        ldx     ZP_CURR_ENTITY
        lda     #$0A
        sta     ENTITY_TYPE,x			; Set type to Alien
        lda     #$00					; Velocity starts at zero
        sta     ENTITY_VX,x
        sta     ENTITY_VY,x
        sta     ENTITY_DIR,x

        lda     #$70					; Default altitude
        sta     ENTITY_Y,x

        sec								; Plane below player
        lda     CHOP_GROUND
        sbc     #$01
        sta     ENTITY_GROUND,x

        lda     ZP_VELX_16_H			; Spawn location depends on player VX
        cmp     #$11
        bcc     spawnAlienMedV			; Check for medium player V
        cmp     #$EF
        bcs     spawnAlienMedV
        bit     ZP_VELX_16_H
        bmi     spawnAlienMedNegV
        jmp     spawnAlienMedPosV

spawnAlienMedV:					; Player's VX is moderate
		jsr     jumpRandomNumber
        ldx     ZP_CURR_ENTITY
        and     #$10			; Randomly spawn behind them!
        bne     spawnAlienMedPosV

spawnAlienMedNegV:				; Spawn left of player
		sec
        lda     CHOP_POS_X_L
        sbc     #$B8
        sta     ENTITY_X_L,x
        lda     CHOP_POS_X_H
        sbc     #$01
        sta     ENTITY_X_H,x
        jmp     spawnAlienFinalize

spawnAlienMedPosV:  			; Spawn right of player
		clc
        lda     CHOP_POS_X_L
        adc     #$B8
        sta     ENTITY_X_L,x
        lda     CHOP_POS_X_H
        adc     #$01
        sta     ENTITY_X_H,x

spawnAlienFinalize:
		jsr     jumpDepthSortEntity
        ldx     NUM_ALIENS
        cpx     #$04
        beq     spawnAlienFatal		; Assertion check for excess aliens!
        lda     ZP_CURR_ENTITY		; Store our new entity in the alien table
        sta     alienTable,x
        inx
        stx     NUM_ALIENS
        rts

spawnAlienFatal:
		jsr		$fbdd				; Beep and die
		brk


; The main update routine for a tank entity
updateTank:		; $65c3
		ldx     #$0F
        ldy     #$00
        lda     #$02
        jsr     jumpSetRenderOffset

        jsr     jumpSetWorldspace
				.word $001c

		ldx     ZP_CURR_ENTITY
        lda     ENTITY_X_L,x			; Choose tread animation frame based on X pos
        and     #$04
        beq     updateTankFrame2

        jsr     jumpSetSpriteAnimPtr
				.word $a066				; Tank tread (frame 1)
        jmp     updateTankAnimate

updateTankFrame2:
		jsr     jumpSetSpriteAnimPtr
				.word $a068				; Tank tread (frame 2)
        
updateTankAnimate:
		lda     #$00					; Configure rendering
        jsr     jumpSetPalette
        jsr     jumpClipToScroll
        bcs     updateTankOffscreen

        lda     #$02
        jsr     jumpPosToScreenspace
        jsr     jumpRenderSprite		; Draw the tank body

        ldx     #$07					; Offset for the turret
        ldy     #$03
        lda     #$02
        jsr     jumpSetRenderOffset

        jsr     jumpSetWorldspace
				.word $001c
        
        jsr     jumpSetSpriteAnimPtr
				.word $a064
        
		jsr     jumpClipToScroll
        bcs     updateTankCannon
        lda     #$03
        jsr     jumpPosToScreenspace
        jsr     jumpRenderSprite			; Draw the tank turret

updateTankCannon:					; Prepare to render the cannon
		ldx     ZP_CURR_ENTITY
        lda     ENTITY_DIR,x		; We store cannon angle here
        asl							; Convert to sprite pointer offset
        tay
        lda     tankCannonSpriteTable,y		; Tank cannon, facing full right + offset
        sta     ZP_SPRITE_PTR_L
        lda     tankCannonSpriteTable+1,y	; Tank cannon, facing full right + offset
        sta     ZP_SPRITE_PTR_H
        jsr     jumpSetSpriteAnimPtr
				.word $001a
        
        ldy     ENTITY_DIR,x	; Set up offset for angled cannon rendering
        ldx     cannonAngleOffsets,y
        ldy     #$07
        lda     #$02
        jsr     jumpSetRenderOffset
        jsr     jumpSetWorldspace
				.word $001c
        
		jsr     jumpClipToScroll
        bcs     updateTankOffscreen
        lda     #$04
        jsr     jumpPosToScreenspace
        jsr     jumpRenderSprite		; Render cannon

updateTankOffscreen:
		lda     #$00
        sta     updateTankCanFire
        sec
        lda     CHOP_POS_X_L		; Subtract our position from player position
        sbc     ENTITY_X_L,x
        sta     ZP_SCRATCH64
        lda     CHOP_POS_X_H
        sbc     ENTITY_X_H,x
        sta     ZP_SCRATCH65
        sec
        lda     CHOP_POS_Y
        sbc     ENTITY_Y,x
        sta     ZP_SCRATCH66

        lda     ZP_SCRATCH65
        beq     updateTankUnder			; Very close to player
        cmp     #$FF
        beq     updateTankGetCloser
        cmp     #$FD
        bcs     updateTankClose
        cmp     #$03
        bcc     updateTankClose

        jsr     jumpRemoveCurrentTank		; Too far away, so time to deallocate
        jsr     jumpDeallocEntity
        rts

updateTankClose:
		lda     ZP_SCRATCH65
        eor     #$80
        sta     ZP_SCRATCH64
        jmp     updateTankDeathCheck

updateTankUnder:
        bit     ZP_SCRATCH64
        bpl     updateTankReadyToMove
        jmp     updateTankDeathCheck

updateTankGetCloser:
		bit     ZP_SCRATCH64
        bmi     updateTankReadyToMove

updateTankDeathCheck:
		lda     ZP_DYING				; If player is dead, then we're done here
        bne     updateTankPlayerDead
        jsr     updateTankGoLeft		; Head back home, for effect
        rts

updateTankPlayerDead:
		jsr     updateTankGoLeft2
        rts

updateTankReadyToMove:
        clc
        lda     ZP_SCRATCH64
        adc     #$80
        sta     ZP_SCRATCH64
        dec     ENTITY_VX,x
        beq     updateTankAnimDone				; Wait for animation to finish
        jsr     updateTankMovement
        jmp     updateTankActionChosen

updateTankAnimDone:								; Pick our next action
		jsr     jumpRandomNumber
        and     #$0F
        clc
        adc     #$08
        sta     ENTITY_VX,x

        lda     ZP_DYING
        bne     updateTankSkip

        ldy     ENTITY_DIR,x					; How's our aim?
        lda     ZP_SCRATCH64
        cmp     updateTankAimTable,y
        bcc     updateTankSkip
        lda     updateTankAimTable+1,y
        cmp     ZP_SCRATCH64
        bcc     updateTankSkip

        lda     #$FF							; Fire at will!
        sta     updateTankCanFire

updateTankSkip:
		ldx     ZP_CURR_ENTITY
        lda     ZP_DYING
        beq     updateTankSkipAgain

        jsr     updateTankGoLeft2
        jmp     updateTankActionChosen

updateTankSkipAgain:
		lda     ENTITY_VY,x
        beq     updateTankActionStopped
        eor     ZP_SCRATCH64
        bpl     updateTankAction2

        jsr     jumpRandomNumber
        and     #$05
        beq     updateTankAction1
        jsr     updateTankGoLeft
        jmp     updateTankActionChosen

updateTankAction1:
		jsr     updateTankStopped
        jmp     updateTankActionChosen

updateTankActionStopped:
		jsr     jumpRandomNumber
        and     #$17
        beq     updateTankAction3
        and     #$10
        beq     updateTankActionChosen
        jsr     updateTankGoLeft
        jmp     updateTankActionChosen

updateTankAction3:
		jsr     updateTankGoLeft2
        jmp     updateTankActionChosen

updateTankAction2:
		jsr     jumpRandomNumber
        and     #$10
        beq     updateTankActionChosen
        jsr     updateTankStopped

updateTankActionChosen:
		bit     updateTankCanFire
        bmi     updateTankReadyToFire		; Take a shot, if we're allowed to

        ldx     ZP_CURR_ENTITY
        ldy     ENTITY_DIR,x				; How's our aim?
        lda     ZP_SCRATCH64
        cmp     updateTankAimTable,y
        bcc     updateTankAimMoreLeft
        lda     updateTankAimTable+1,y
        cmp     ZP_SCRATCH64
        bcc     updateTankAimMoreRight
        jmp     updateTankReadyToFire

updateTankAimMoreLeft:						; Swing cannon to the left
		cpy     #$00
        beq     updateTankReadyToFire
        dec     ENTITY_DIR,x
        jmp     updateTankReadyToFire

updateTankAimMoreRight:						; Swing cannon to the right
		cpy     #$04
        beq     updateTankReadyToFire
        inc     ENTITY_DIR,x

updateTankReadyToFire:						; Take a shot, if we're allowed to
		bit     updateTankCanFire
        bmi     updateTankNewShot
        rts

updateTankNewShot:					; Fire a shell!
		jsr     updateTankFire
        rts

cannonAngleOffsets:		; $6757 Maps cannon angle to horizontal rendering position of cannon
	.byte	$0b,$07,$01,$ff,$fb

updateTankAimTable:	; $675c		Maps player distance/direction to cannon angle
	.byte	$00,$40,$70,$90,$C0,$FF

updateTankCanFire:		; $6762 High bit set if we're allowed to fire
	.byte	$00


updateTankMovement:		; $6763
		ldx     ZP_CURR_ENTITY
        lda     ENTITY_VY,x
        beq     updateTankStopped
        bpl     updateTankGoRight
        jmp     updateTankMoveLeft

updateTankStopped:			; Zero out VY for current entity
		ldx     ZP_CURR_ENTITY
        lda     #$00
        sta     ENTITY_VY,x
        rts

updateTankGoLeft:
        bit     ZP_SCRATCH64
        bmi     updateTankGoRight
        jmp     updateTankMoveLeft
updateTankGoLeft2:
        bit     ZP_SCRATCH64
        bpl     updateTankGoRight
        jmp     updateTankMoveLeft

updateTankGoRight:
		ldx     ZP_CURR_ENTITY			; Check for security fence that we can't' cross
        sec
        lda     FENCE_X_L
        sbc     ENTITY_X_L,x
        sta     ZP_SCRATCH56
        lda     FENCE_X_H
        sbc     ENTITY_X_H,x
        beq     updateTankFenceClose
        bpl     updateTankMoveRight
        rts								; At the fence, so go no farther

updateTankFenceClose:
		lda     ENTITY_GROUND,x			; Not sure what this code is doing when close to fence line
        asl
        asl
        asl
        eor     #$FF
        clc
        adc     #$C0
        cmp     ZP_SCRATCH56
        bcc     updateTankMoveRight
        rts

updateTankMoveRight:
		clc
        lda     ENTITY_X_L,x
        adc     #$04
        sta     ENTITY_X_L,x
        lda     ENTITY_X_H,x
        adc     #$00
        sta     ENTITY_X_H,x
        lda     #$04
        sta     ENTITY_VY,x		; Make a note of our last direction of travel
        rts

updateTankMoveLeft:  
		ldx     ZP_CURR_ENTITY
        sec
        lda     ENTITY_X_L,x
        sbc     #$04
        sta     ENTITY_X_L,x
        lda     ENTITY_X_H,x
        sbc     #$00
        sta     ENTITY_X_H,x
        lda     #$FC			; -4
        sta     ENTITY_VY,x		; Make a note of our last direction of travel
        rts

updateTankFire:					; Tank fires a shell!
		lda     ZP_CURR_ENTITY
        sta     updateTankOurEntity

        jsr     jumpAllocateEntity		; Create the shell
        ldx     updateTankOurEntity

        ldy     ZP_CURR_ENTITY			; Type 8 is tank shell
        lda     #$08
        sta     ENTITY_TYPE,y

        sec								; Starting X position is offset a bit from tank position
        lda     ENTITY_X_L,x
        sbc     #$10
        sta     ENTITY_X_L,y
        lda     ENTITY_X_H,x
        sbc     #$00
        sta     ENTITY_X_H,y

        ldy     ENTITY_DIR,x			; Offset shell position further for cannon angle
        lda     shellLaunchOffsets,y
        ldy     ZP_CURR_ENTITY
        clc
        adc     ENTITY_VY,x
        bmi     updateTankShellLeft

        clc
        adc     ENTITY_X_L,y
        sta     ENTITY_X_L,y
        lda     #$00
        adc     ENTITY_X_H,y
        sta     ENTITY_X_H,y
        jmp     updateTankShellY

updateTankShellLeft:
		clc
        adc     ENTITY_X_L,y
        sta     ENTITY_X_L,y
        lda     #$FF
        adc     ENTITY_X_H,y
        sta     ENTITY_X_H,y

updateTankShellY:
		clc								; Offset Y position up from tank
        lda     ENTITY_Y,x
        adc     #$09
        sta     ENTITY_Y,y
        clc
        lda     ENTITY_GROUND,x
        adc     #$01
        sta     ENTITY_GROUND,y

        lda     ENTITY_VY,x				; Configure shell physics
        sta     ZP_SCRATCH58
        lda     ENTITY_DIR,x
        tax
        clc
        lda     shellLaunchFrameTable,x
        adc     ZP_SCRATCH58
        sta     ENTITY_VX,y
        lda     shellLaunchVTable,x
        sta     ENTITY_VY,y
        lda     shellLaunchDirTable,x
        sta     ENTITY_DIR,y

        jsr     jumpDepthSortEntity		; Insert the entity and we're ready to go!
        lda     updateTankOurEntity
        sta     ZP_CURR_ENTITY			; Make tank active entity again

        ldx     #$F0
        ldy     #$0A
        lda     #$00
        jsr     jumpPlayShellSound		; Play tank firing sound
        rts

updateTankOurEntity:	; $686f
		.byte $00	; Caches tank's entity ID so we don't lose it while shooting

shellLaunchOffsets:		; $6870	 Shell X position offsets for each cannon angle
	.byte 	$00,$06,$10,$19,$1f

shellLaunchFrameTable:	; $6875		Table for mapping turret angle to frame for shell
	.byte	$F4,$F9,$00,$07,$0C

shellLaunchVTable:		; $687A		Table for mapping turret angle to initial shell V
	.byte	$03,$03,$03,$03,$03		; Looks like Dan decided this should always be 3

shellLaunchDirTable:	; $687F		Table to map turrent angle to shell angle
	.byte	$02,$03,$04,$03,$02


; Attempts to spawn new enemies. Called every frame, this decides when to spawn and what.
spawnEnemies:		; $6884
		lda     ZP_FRAME_COUNT			; Try spawning a hostage every three frames
        and     #$03
        bne     spawnEnemiesNoHostages
        jsr     spawnHostages

spawnEnemiesNoHostages:
		lda     ZP_FRAME_COUNT			; Try spawning enemies every 47 frames
        and     #$2F
        beq     spawnEnemyVehicles
        rts

spawnEnemyVehicles:
		jsr     jumpRandomNumber
        sta     ZP_SCRATCH58
        lda     CURR_LEVEL
        beq     spawnEnemyTanks			; Only tanks on level 0
        cmp     #$01
        beq     spawnEnemyJets			; Only tanks & jets on level 1
        lda     ZP_SCRATCH58
        and     #$28
        bne     spawnEnemyJets
        ldx     CURR_LEVEL
        lda     alienSpawnRateTable,x
        cmp     NUM_ALIENS				; Room for more aliens?
        beq     spawnEnemyJets
        jsr     spawnAlien				; Here we come!
        rts

spawnEnemyJets:
		bit     ZP_SCRATCH58
        bmi     spawnEnemyTanks
        ldx     CURR_LEVEL
        lda     jetSpawnRateTable,x
        cmp     NUM_JETS				; Room for more jets?
        beq     spawnEnemyTanks
        jsr     spawnJet				; Here we come!
        rts

spawnEnemyTanks:
		ldx     CURR_LEVEL
        lda     tankSpawnRateTable,x
        cmp     NUM_TANKS
        beq     spawnEnemiesDone
        jsr     spawnTank				; Here we come!

spawnEnemiesDone:
		rts


tankSpawnRateTable:			; $68d9   How many tanks to spawn at each game level
	.byte $01,$02,$02,$02

jetSpawnRateTable:			; $68dd How many jets to spawn at each game level
	.byte $00,$01,$02,$02

alienSpawnRateTable:		; $68e1 How many aliens to spawn at each game level
	.byte $00,$00,$01,$02

.org $68e5



; 795 unused bytes from $68e5 to $6c00
UNUSED 795


.org $6c00

; A series of little tables that map jet Y velocity to something. These tables are looked up
; in another table (jetXVelocityTable) from X velocity. Each mini table is four bytes:
; 0 = Sprite table offset (always zero, so maybe was an unused feature)
; 1 = X Velocity per frame - what we actually add to position each update
; 2 = Y Velocity per frame - what we actually add to position each update
; 3 = Ground plane change per frame - what we actually add to plane each update
jetYVelocityTables:		; $6c00
		.byte	$00,$08,$00,$00		; $6c00
		.byte	$00,$06,$01,$FF		; $6c04
		.byte	$00,$06,$00,$FF		; $6c08
		.byte	$00,$06,$00,$FF		; $6c0c


; $6c10  I believe these are 217 unused bytes. However it also looks like table data so just
; to be safe I am including it here in the binary.
		.byte	$00,$07,$00,$FE,$00,$07,$00,$FE,$01,$08,$FF,$FE,$01,$09,$FF,$FE
		.byte	$01,$09,$FF,$FE,$01,$09,$FF,$FE,$02,$08,$FF,$FE,$02,$08,$FF,$FE
		.byte	$02,$05,$FF,$FE,$03,$02,$FF,$FE,$04,$FC,$FF,$FE,$04,$F8,$FF,$FE
		.byte	$05,$F6,$FF,$FE,$06,$F4,$00,$FE,$06,$F4,$FF,$00,$00,$04,$01,$FF
		.byte	$00,$04,$00,$FF,$00,$03,$00,$FF,$00,$02,$00,$FE,$00,$01,$FF,$FE
		.byte	$00,$01,$FF,$FE,$00,$01,$FF,$FD,$01,$01,$FF,$FD,$01,$01,$FF,$FD
		.byte	$01,$01,$FF,$FD,$01,$02,$FF,$FD,$01,$03,$FF,$FD,$02,$05,$FF,$FD
		.byte	$03,$08,$FF,$FF,$04,$0B,$FF,$00,$00,$0C,$00,$00,$00,$0C,$00,$00
		.byte	$00,$0C,$00,$00,$00,$0C,$00,$00,$00,$0C,$00,$00,$01,$0C,$00,$01
		.byte	$01,$0C,$00,$01,$01,$0C,$01,$01,$01,$0C,$01,$01,$02,$0C,$01,$01
		.byte	$02,$0C,$01,$01,$02,$0C,$01,$01,$02,$0C,$01,$01,$03,$0C,$01,$01
		.byte	$03,$0C,$01,$01,$03,$0B,$01,$01,$03,$0B,$01,$01,$04,$0B,$01,$01
		.byte	$04,$0B,$01,$01,$04,$0B,$01,$01,$04,$0B,$01,$01,$04,$0B,$01,$01
		.byte	$04,$0B,$01,$01,$05,$0A,$01,$01,$00


jetClimbTable:		; $6ce9 A little table that dictates rate of climb based on VX
	.byte	$00,$12,$0F,$18,$18

tiltOffsetTable:	; $6cee A lookup for offsetting sprites vertically when tilted to keep origin about the same
	.byte	$FC,$FD,$FE,$00,$03,$03,$04,$06,$07					; Length uncertain, but fairly confident




; $6cf7 I believe these are 90 unused bytes. However it also looks like table data so just
; to be safe I am including it here in the binary.
	.byte	$FD,$FE,$FF,$00,$02,$02,$03,$04,$05,$FE,$FF,$FF,$00,$01,$01,$02,$03,$04
	.byte	$00,$00,$01,$01,$01,$01,$01,$02,$02,$00,$00,$01,$01,$01,$01,$01,$02,$02
	.byte	$00,$00,$00,$00,$00,$00,$00,$00,$00,$02,$02,$01,$01,$01,$01,$01,$00,$00
	.byte	$02,$02,$01,$01,$01,$01,$01,$00,$00,$04,$03,$02,$01,$00,$00,$FF,$FF,$FE
	.byte	$05,$04,$03,$02,$00,$00,$FF,$FE,$FD,$07,$06,$04,$03,$00,$00,$FE,$FD,$FC



mainRotorTiltTableX:	; $6d51 A lookup table for rendering every possible tilted X position of the main rotor in all chopper facings
	.byte	$FE,$06,$FF,$06,$FF,$07,$FF,$07,$FF,$07,$00,$07,$00,$07,$00,$07
	.byte	$00,$07,$FF,$07,$FE,$07,$FF,$06,$FF,$06,$FF,$06,$FF,$06,$FF,$06
	.byte	$00,$06,$00,$06,$00,$06,$00,$06,$FF,$06,$FE,$07,$FF,$06,$FF,$06
	.byte	$FF,$06,$FF,$06,$FF,$06,$00,$06,$00,$06,$00,$06,$00,$06,$FF,$06
	.byte	$FF,$07,$FF,$06,$FF,$06,$FF,$06,$FF,$07,$FF,$07,$00,$07,$00,$07
	.byte	$00,$07,$00,$07,$FF,$07,$FF,$07,$FF,$05,$FF,$06,$FF,$06,$FF,$06
	.byte	$FF,$06,$00,$06,$00,$06,$00,$06,$00,$07,$FF,$06,$FF,$06,$00,$05
	.byte	$00,$05,$00,$05,$00,$05,$00,$05,$00,$05,$00,$05,$00,$05,$00,$05
	.byte	$00,$05,$00,$05,$02,$06,$01,$06,$01,$07,$01,$06,$01,$06,$01,$06
	.byte	$01,$06,$01,$06,$01,$06,$01,$06,$01,$05,$04,$06,$03,$06,$03,$06
	.byte	$03,$06,$03,$06,$02,$06,$02,$06,$02,$06,$02,$06,$02,$06,$02,$05
	.byte	$04,$06,$04,$05,$04,$05,$04,$05,$04,$05,$03,$05,$03,$05,$03,$05
	.byte	$03,$05,$03,$05,$03,$05,$04,$06,$04,$05,$04,$05,$04,$05,$04,$05
	.byte	$04,$05,$04,$05,$04,$05,$04,$05,$04,$05,$04,$05,$05,$06,$03,$06
	.byte	$03,$06,$03,$06,$03,$06,$04,$05,$04,$05,$04,$05,$04,$05,$05,$05
	.byte	$05,$05

mainRotorTiltTableY:	; $6e43 A lookup table for rendering every possible tilted Y position of the main rotor in all chopper facings
	.byte	$10,$06,$11,$05,$12,$04,$12,$02,$13,$02,$13,$01,$12,$00,$11,$00
	.byte	$11,$FE,$10,$FD,$0E,$FC



tailRotorHeadOnOffsets:	; $6e59  Pairs of X,Y offsets for tail rotor at all chopper tilts when head-on
	.byte	$06,$08,$05,$07,$04,$06,$80,$80,$80,$80,$80,$80,$80,$80,$80,$80,$fd,$06,$fc,$07,$fb,$08			; Length uncertain

tailRotorSideRightOffsetTable:		; $6e6f  Lookup table for offsetting tail rotor at different chopper tilt angles (X,Y pairs)
	.byte	$12,$0B,$12,$0A,$12,$09,$13,$08,$13,$07,$13,$05,$13,$04,$13,$03,$13,$03,$13,$02,$13,$01

tailRotorSideLeftOffsetTable:		; $6e85  Lookup table for offsetting tail rotor at different chopper tilt angles (X,Y pairs)
	.byte	$F4,$01,$F3,$02,$F4,$03,$F3,$03,$F3,$04,$F3,$05,$F3,$07,$F4,$08,$F4,$09,$F5,$0A,$F5,$0B

; A table for computing offsets to the front of the chopper for all different
; facings and tilt angles. I've seen offsets as high as 220. Exact length uncertain, but all bytes up to the
; next confirmed table look like valid data so I am including them
chopperFrontOffsetTable:		; $6e9b
	.byte	$0E,$03,$0C,$03,$0A,$02,$07,$00,$04,$00,$03,$00,$02,$FF,$FF,$FE
	.byte	$FB,$FD,$F9,$FC,$F5,$FB,$0E,$02,$0C,$01,$0A,$01,$07,$00,$04,$FF
	.byte	$03,$FF,$01,$FE,$FE,$FD,$FA,$FC,$F7,$FC,$F4,$FC,$0F,$01,$0D,$01
	.byte	$0B,$01,$07,$FF,$04,$FF,$02,$FE,$00,$FE,$FD,$FD,$F9,$FD,$F6,$FD
	.byte	$F3,$FC,$0F,$00,$0D,$00,$0B,$00,$06,$00,$03,$FF,$01,$FF,$FF,$FF
	.byte	$FC,$FE,$F8,$FE,$F5,$FD,$F2,$FD,$0F,$FF,$0D,$FF,$0B,$FF,$06,$FF
	.byte	$03,$FF,$01,$FF,$FF,$FF,$FC,$FE,$F7,$FE,$F4,$FE,$F1,$FE,$0F,$FE
	.byte	$0E,$FE,$0B,$FE,$07,$FE,$03,$FE,$00,$FE,$FE,$FE,$FA,$FE,$F6,$FE
	.byte	$F3,$FE,$F1,$FE,$0F,$FE,$0E,$FE,$0B,$FE,$07,$FE,$03,$FF,$00,$FF
	.byte	$FE,$FF,$FA,$FF,$F6,$FF,$F4,$FF,$F1,$FF,$0F,$FD,$0D,$FD,$0A,$FE
	.byte	$06,$FE,$03,$FF,$01,$FF,$FE,$FF,$FA,$00,$F5,$00,$F3,$00,$F1,$00
	.byte	$0E,$FC,$0C,$FC,$08,$FC,$04,$FD,$02,$FE,$00,$FF,$FE,$FF,$FA,$FF
	.byte	$F6,$01,$F4,$01,$F2,$01,$0D,$FC,$0A,$FC,$08,$FC,$04,$FD,$01,$FE
	.byte	$FF,$FF,$FD,$00,$FA,$00,$F6,$01,$F4,$01,$F2,$02,$0C,$FB,$08,$FC
	.byte	$05,$FD,$02,$FD,$00,$FE,$FF,$FF,$FD,$00,$FA,$00,$F8,$02,$F5,$03
	.byte	$F2,$03		; 242 bytes

bulletVelocityTable:			; $6f8d		Size of this not totally certain. Highest offset I've seen is 47, but 72 bytes look like valid table data
	.byte	$00,$00,$00,$00,$01,$00,$02,$00,$02,$00,$02,$00,$03,$00,$03,$00
	.byte	$03,$00,$03,$00,$03,$01,$04,$02,$08,$00,$08,$00,$08,$00,$08,$01
	.byte	$08,$02,$08,$02,$0C,$00,$0C,$00,$0C,$01,$0C,$02,$0B,$02,$0A,$02
	.byte	$10,$00,$10,$01,$10,$01,$10,$01,$0F,$02,$0E,$02,$1A,$00,$1A,$02
	.byte	$1A,$04,$1A,$06,$19,$08,$19,$0A				; 72 bytes


; $6fd5  43 unused bytes. It looks like old graphics data, but on the off chance it's part of the above table, I'll include it
	.byte	$2A,$55,$2A,$55,$2A,$55,$2A,$55,$2A,$55,$2A,$55,$2A,$55,$2A,$55,$2A,$55,$2A,$55,$2A,$55,$2A,$55
	.byte	$2A,$55,$2A,$55,$2A,$55,$2A,$55,$2A,$55,$2A,$00,$00,$00,$00,$00,$00,$00,$00


; $7000  Global game state. Many of these are gameplay tuning constants that Dan set during playtesting
; and are never changed in game. Much fun can be had by messing with these yourself.


BOUNDS_LEFT_L:		; $7000 Left boundary of world, in 16-bit pixels (low byte). Always $d0
	.byte 	$d0
BOUNDS_LEFT_H:		; $7001 Left boundary of world, in 16-bit pixels (high byte). Always $02
	.byte 	$02
BOUNDS_RIGHT_L:		; $7002 Right boundary of world, in 16-bit pixels (low byte). Always $00
	.byte 	$00
BOUNDS_RIGHT_H:		; $7003 Right boundary of world, in 16-bit pixels (high byte). Always $13
	.byte 	$13
SCROLL_END_L:		; $7004	Leftmost scrolling limit of playfield, in 16-bit pixels (low byte). Always $b0
	.byte 	$b0
SCROLL_END_H:		; $7005	Leftmost scrolling limit of playfield, in 16-bit pixels high byte). Always $02
	.byte 	$02
SCROLL_START_L:		; $7006 Rightmost scrolling limit of playfield, in 16-bit pixels (low byte). Always $08
	.byte	$08
SCROLL_START_H:		; $7007 Rightmost scrolling limit of playfield, in 16-bit pixels (high byte). Always $12
	.byte	$12
BASE_X_L:			; $7008 X position of base, in 16-bit pixels (low byte). Always $74
	.byte	$74
BASE_X_H:			; $7009 X position of base, in 16-bit pixels (high byte). Always $12
	.byte	$12
DOOR_X_L:			; $700A X position of base door, in 16-bit pixels (low byte). Always $d5
	.byte 	$d5
DOOR_X_H:			; $700B X position of base door, in 16-bit pixels (high byte). Always $12
	.byte 	$12
FENCE_X_L:			; $700C 16-bit X position of the security fence (low byte). Always $74
	.byte	$74
FENCE_X_H:			; $700D 16-bit X position of the security fence (high byte). Always $11
	.byte	$11
FARHOUSE_X_L:		; $700E 16-bit X position of farthest-away house (low byte). Always $80
	.byte 	$80
FARHOUSE_X_H:		; $700F 16-bit X position of farthest-away house (high byte). Always $03
	.byte	$03
MIN_VY_L:			; $7010 Minimum Y velocity required to detect ground (low byte). Always $a0
	.byte	$a0
MIN_VY_H:			; $7011 Minimum Y velocity required to detect ground (high byte). Always $fb
	.byte	$fb
CRASHSPEED_L:		; $7012 The X velocity at which we will crash, stored as a 16-bit negative magnitude (low byte). Always $01
	.byte	$01
CRASHSPEED_H:		; $7013 The Y velocity at which we will crash, stored as a 16-bit negative magnitude (high byte). Always $EB
	.byte	$eb
LAUNCHTHRESH_L:		; $7014 The Y velocity at which we launch from the ground (low byte). Always $00
	.byte	$00
LAUNCHTHRESH_H:		; $7015 The Y velocity at which we launch from the ground (high byte). Always $01
	.byte	$01
MAX_SINK:			; $7016 The maximum distance into the ground that burning chopper sinks. Always $06
	.byte	$06
UNUSED_7017:		; $7017 Unused byte
	.byte	$00
SCROLLPOS_Y:		; $7018 Y Scroll pos. Always $00
	.byte	$00
UNUSED_7019:		; $7019 Unused byte
	.byte	$06
CHOP_GROUND_INIT:	; $701A	Initial value of chopper GROUND. Always $16
	.byte	$16
TITLEREGION_TOP:	; $701B Y position of the top of the title area. Always $19
	.byte	$19
MOUNTAIN_Y:			; $701C Y position (bottom relative) of mountain ranges. Always $1d
	.byte	$1d
BOUNDS_TOP:			; $701D Upper bounds of flight area. Always $70
	.byte	$70
TITLEREGION_BOT:	; $701E	Y position of the bottom of the title area. Always $a6
	.byte	$a6
LAND_POSY:			; $701F	Y position (bottom relative) of the top of the pink land. Always $19
	.byte	$19
SKY_HEIGHT:			; $7020	Y height of sky area (distance from land to screen top). Always $a6.
	.byte	$a6
SCROLL_LEAD_L_L:	; $7021 16-bit lead (low byte) amount in front of chopper for scrolling left. Always $46
	.byte	$46
SCROLL_LEAD_L_H:	; $7022	16-bit lead (high byte) amount in front of chopper for scrolling left. Always $00
	.byte	$00
SCROLL_LEAD_R_L:	; $7023 16-bit lead (low byte) amount in front of chopper for scrolling right. Always $d2
	.byte	$d2
SCROLL_LEAD_R_H:	; $7024 16-bit lead (high byte) amount in front of chopper for scrolling right. Always $00
	.byte	$00


; Table of rendering positions for sprites. Each row gives the offsets
; from the origin of that sprite to top left for screen writes. This table
; is double-buffered with the one below it. This is a scratch space that is
; consumed as needed each frame via the iterators ZP_OFFSET_ROW0/1, then reset next frame
; 0 = Table row index in spriteGeometry
; 1 = 16 bit X render offset in screenspace (corrected for scroll) (low byte)
; 2 = 16 bit X render offset in screenspace (corrected for scroll) (high byte)
; 3 = Y render position (localized to scroll, but Y scroll is always 0)
; Each entity sprite reserves its own row in this table
renderDisplayList0:		; $7025
	.byte	$01,$fc,$ff,$1D
	.byte	$11,$31,$00,$21
	.byte	$11,$79,$00,$21
	.byte	$11,$D7,$00,$21
	.byte	$11,$0F,$01,$21
	.byte	$00,$CE,$00,$56
	.byte	$0E,$7D,$00,$46
	.byte	$0E,$97,$00,$47
	.byte	$05,$92,$00,$1E
	.byte	$02,$CB,$00,$10
	.byte	$03,$D3,$00,$13
	.byte	$04,$CF,$00,$17
	.byte	$04,$F5,$00,$17
	.byte	$10,$4C,$5A,$10
	.byte	$4C,$5D,$10,$4C
	.byte	$60,$10,$FE,$00
	.byte	$01,$FF,$FD,$01
	.byte	$01,$FF,$FD,$01
	.byte	$01,$FF,$FD,$01
	.byte	$01,$FF,$FD,$01
	.byte	$02,$FF,$FD,$01
	.byte	$03,$FF,$FD,$02
	.byte	$05,$FF,$FD,$03
	.byte	$08,$FF,$FF,$04
	.byte	$0B,$FF,$00,$00
	.byte	$0C,$00,$00,$00
	.byte	$0C,$00,$00,$00
	.byte	$0C,$00,$00,$00
	.byte	$0C,$00,$00,$00
	.byte	$0C,$00,$00,$01
	.byte	$0C,$00,$01,$01
	.byte	$0C,$00,$01,$01
	.byte	$0C,$01,$01,$01
	.byte	$0C,$01,$01,$02
	.byte	$0C,$01,$01,$02
	.byte	$0C,$01,$01,$02
	.byte	$0C,$01,$01,$02
	.byte	$0C,$01,$01,$03
	.byte	$0C,$01,$01,$03
	.byte	$0C,$01,$01,$03

renderDisplayList1:		; $70c5
	.byte	$01,$fc,$ff,$1D
	.byte	$11,$31,$00,$21
	.byte	$11,$79,$00,$21
	.byte	$11,$D7,$00,$21
	.byte	$11,$0F,$01,$21
	.byte	$00,$CE,$00,$56
	.byte	$0E,$7D,$00,$46
	.byte	$0E,$97,$00,$47
	.byte	$05,$92,$00,$1E
	.byte	$02,$CB,$00,$10
	.byte	$03,$D3,$00,$13
	.byte	$04,$CF,$00,$17
	.byte	$04,$F5,$00,$17
	.byte	$10,$4C,$5A,$10
	.byte	$4C,$5D,$10,$4C
	.byte	$60,$10,$FE,$00
	.byte	$01,$FF,$FD,$01
	.byte	$01,$FF,$FD,$01
	.byte	$01,$FF,$FD,$01
	.byte	$01,$FF,$FD,$01
	.byte	$02,$FF,$FD,$01
	.byte	$03,$FF,$FD,$02
	.byte	$05,$FF,$FD,$03
	.byte	$08,$FF,$FF,$04
	.byte	$0B,$FF,$00,$00
	.byte	$0C,$00,$00,$00
	.byte	$0C,$00,$00,$00
	.byte	$0C,$00,$00,$00
	.byte	$0C,$00,$00,$00
	.byte	$0C,$00,$00,$01
	.byte	$0C,$00,$01,$01
	.byte	$0C,$00,$01,$01
	.byte	$0C,$01,$01,$01
	.byte	$0C,$01,$01,$02
	.byte	$0C,$01,$01,$02
	.byte	$0C,$01,$01,$02
	.byte	$0C,$01,$01,$02
	.byte	$0C,$01,$01,$03
	.byte	$0C,$01,$01,$03
	.byte	$0C,$01,$01,$03


	.byte $00,$00,$00,$00,$00,$00,$00,$00		; $7165 Unused bytes


entityListEnd:		; $716d
	.byte	$14		; Last element in the current entity list

; Linked list table of game objects (null-terminated). This is the "master table" that stores
; game state for every tank, bullet, jet, etc. All the magic. This list is kept sorted
; by screen depth, which we derive from ground height. The higher ground we're on,
; the deeper into screen we are.
entityTable:		; $716e
	; Each entry is ten bytes
	; 0 = Entity ID ($0A is always chopper, others are allocated first-come)
	; 1 = Entity type (0=chopper, 1=crashing chopper, 2=sinking chopper, 3=tank, 4=missile, 5=bomb, 6=bullet, 7=unused, 8=tank shell, 9=jet, 10=alien)
	; 2 = X Velocity - Interpreted slightly differently by different entity types
	; 3 = Y Velocity - Interpreted slightly differently by different entity types
	; 4 = Direction - Interpreted differently by different entities (gravity vector, aim angle, etc)
	; 5 = 16-bit X position in pixels, in screenspace (low byte)
	; 6 = 16-bit X position in pixels, in screenspace (high byte)
	; 7 = Y position in pixels, in screenspace
	; 8 = Ground offset (distance from zero to place us on terrain)
	; 9 = Pointer to next element in list (offset from start)
	.byte $0A,$00,$06,$00,$0E,$31,$0C,$11,$16,$00
	.byte $14,$03,$03,$04,$03,$FF,$0B,$06,$07,$0A
	.byte $1E,$02,$04,$00,$02,$9E,$0B,$00,$16,$0A
	.byte $28,$00,$06,$FF,$00,$FF,$07,$FF,$06,$FF
	.byte $32,$FF,$06,$FF,$07,$FF,$07,$00,$07,$00
	.byte $3C,$00,$07,$00,$07,$FF,$07,$FF,$07,$FF
	.byte $46,$FF,$06,$FF,$06,$FF,$06,$FF,$06,$00
	.byte $50,$00,$06,$00,$06,$00,$07,$FF,$06,$FF
	.byte $5A,$00,$05,$00,$05,$00,$05,$00,$05,$00
	.byte $64,$00,$05,$00,$05,$00,$05,$00,$05,$00
	.byte $6E,$00,$05,$02,$06,$01,$06,$01,$07,$01
	.byte $78,$01,$06,$01,$06,$01,$06,$01,$06,$01
	.byte $82,$01,$06,$01,$05,$04,$06,$03,$06,$03
	.byte $8C,$03,$06,$03,$06,$02,$06,$02,$06,$02
	.byte $96,$02,$06,$02,$06,$02,$05,$04,$06,$04
	.byte $A0,$04,$05,$04,$05,$04,$05,$03,$05,$03
	.byte $AA,$03,$05,$03,$05,$03,$05,$03,$05,$04
	.byte $B4,$04,$05,$04,$05,$04,$05,$04,$05,$04
	.byte $BE,$04,$05,$04,$05,$04,$05,$04,$05,$04
	.byte $C8,$05,$06,$03,$06,$03,$06,$03,$06,$03
	.byte $D2,$04,$05,$04,$05,$04,$05,$04,$05,$05
	.byte $DC,$05,$05,$10,$06,$11,$05,$12,$04,$12
	.byte $E6,$13,$02,$13,$01,$12,$00,$11,$00,$11
	.byte $F0,$10,$FD,$0E,$FC,$06,$08,$05,$07,$04
	.byte $FA,$80,$80,$80,$80,$80,$80,$80,$80,$80
	.byte $04,$FD,$06,$FC,$07,$FB,$08,$12,$0B,$12		; Init loop goes pear-shaped here. A nasty bug! See initEntityTable for details
	.byte $0E,$12,$09,$13,$08,$13,$07,$13,$05,$13
	.byte $04,$13,$03,$13,$03,$13,$02,$13,$01,$F4
	.byte $18,$F3,$02,$F4,$03,$F3,$03,$F3,$04,$F3

wastedByte:				; $7290 Apparent wasted byte between end of table and size value
	.byte	$05			; Looks like remnant of some other lookup table that used to be in this area

entityTableSize:		; $7291
	.byte		$1e		; The most entities there can ever be. Seems to always be 30, but perhaps should be 29

; Shortcut offsets into above table (used with indexed addressing on entity ID)
ENTITY_TYPE 		= $7165		; Byte 1 in record
ENTITY_VX			= $7166		; 2
ENTITY_VY			= $7167		; 3
ENTITY_DIR			= $7168		; 4
ENTITY_X_L 			= $7169		; 5
ENTITY_X_H 			= $716a		; 6
ENTITY_Y 			= $716b		; 7
ENTITY_GROUND 		= $716c		; 8
ENTITY_NEXT			= $716d		; 9


hostageTable:	; $7292  Current hostage states, 4 bytes per hostage, 16 rows max
	; 0 = Animation frame, and $ff = Unallocated
	; 1 = Current action - $00=Waving $ff=Run left, $01=Run right, $fe=Loading Right, $02=Loading Left
	; 2 = 16 bit X position (low byte)
	; 3 = 16 bit X position (high byte)
	.byte $00,$00,$00,$00
	.byte $00,$00,$00,$00
	.byte $00,$00,$00,$00
	.byte $00,$00,$00,$00
	.byte $00,$00,$00,$00
	.byte $00,$00,$00,$00
	.byte $00,$00,$00,$00
	.byte $00,$00,$00,$00
	.byte $00,$00,$00,$00
	.byte $00,$00,$00,$00
	.byte $00,$00,$00,$00
	.byte $00,$00,$00,$00
	.byte $00,$00,$00,$00
	.byte $00,$00,$00,$00
	.byte $00,$00,$00,$00
	.byte $00,$00,$00,$00

MAX_HOSTAGES: 		; $72d2
	.byte 	16		; Maximum number of active hostages. Always 16.


; An array-list of in-use entity IDs
entityIndexTable:		; $72d3
	.byte	$00,$00,$00,$00,$00,$00,$00,$00
	.byte	$00,$00,$00,$00,$00,$00,$00,$00
	.byte	$00,$00,$00,$00,$00,$00,$00,$00
	.byte	$00,$00,$00,$00,$00,$00

entityIndexIterator:	; $72f1 Used to iterate through above, and also marks end of the array
	.byte $00


; Helicopter flight control state
JOYSTICK_AXISX:
	.byte	$00				; $72f2 Current joystick X axis
JOYSTICK_AXISY:
	.byte	$01 			; $72f3 Current joystick Y axis

; Game preferences
PREFS_JOY_X:
	.byte	$00 			; $72f4 0=Regular $ff=Inverted
PREFS_JOY_Y:
	.byte	$00				; $72f5 0=Regular $ff=Inverted
PREFS_SOUND:
	.byte	$ff				; $72f6 $ff if sound is on

; Helicopter state
CHOP_STICKX:
	.byte	$80				; $72f7 $ff=left, $80=neutral, $00=right
CHOP_STICKY:
	.byte	$00				; $72f8 Current joystick Y axis
CHOP_FACE:
	.byte	$01				; $72f9 Logical turn state (which is instant, unlike animation) $00=facing camera, $FF=facing left, $01=facing right
CHOP_TURN_REQUEST:
	.byte	$00				; $72fa $00 when no turn is needed, and a copy of ZP_TURN_STATE when a turn is underway

; Enemy states
NUM_ALIENS:
	.byte	$00				; $72fb Current number of active aliens

alienTable:					; $72fc List of the entity IDs of all active aliens. Max four entries.
	.byte	$00,$00,$00,$00

NUM_JETS:
	.byte	$00				; $7300	Current number of active jets

jetTable:					; $7301 List of the entity IDs of all active jets. Max four entries.
	.byte 	$00,$00,$00,$00

NUM_TANKS:					; $7305	Current number of active tanks
	.byte 	$00

tankTable:					; $7306	List of the entity IDs of all active tanks. Max four entries.
	.byte 	$00,$00,$00,$00


; A bunch of game state
HOSTAGES_LEFT:		; $730A	Number of hostages remaining that can be rescued (still in houses, not counting in the open)
	.byte	$00
TOTAL_RESCUES:		; $730B	Total hostages rescued so far. At 64, you win (Broderbund logo shown and game goes back to demo)
	.byte	$00
HOSTAGES_KILLED:	; $730C Hostages killed so far. 64 ends the game.
	.byte	$00
HOSTAGES_ACTIVE:	; $730D Number of hostages running around in the open
	.byte	$00
HOSTAGES_LOADED:	; $730E Number of hostages on board the chopper
	.byte	$00
BASE_RUNNERS:		; $730F Number of hostages running from chopper to door on landing pad
	.byte	$00
CURR_SHOTS:			; $7310 Current number of active shots. 5 shots max.
	.byte	$00

houseStates:		; $7311 State of each house (left to right). $00=untouched, $01=on fire
	.byte	$00,$00,$00,$00

hostagesInHouses:	; $7315 Number of hostages remaining in each house (left to right)
	.byte	$00,$00,$00,$00

HOSTAGES_KILLED_BCD:	; $7319	Number of hostages killed, as BCD (for display)
	.byte	$00
TOTAL_RESCUES_BCD:		; $731A	Number of hostages rescued, as BCD (for display)
	.byte	$00
HOSTAGES_LOADED_BCD:	; $731B Number of hostages on board the chopper, as BCD (for display)
	.byte	$00

SORTIE:					; $731C 0-2, which sortie you are on (lives)
	.byte	$00
CURR_LEVEL:				; $731D 0-7 (difficulty level)
	.byte	$00
CHOP_LOADED:			; $731E $ff if we have hostages on board, $00 if not
	.byte	$00
HOSTAGE_FIRSTLOAD:		; $731F $ff if we have loaded a hostage this frame. Used to prevent duplicate sound effects
	.byte	$00
HOSTAGE_FIRSTDEATH:		; $7320 $ff if a hostage has died this frame. Used to prevent duplicate sound effects
	.byte	$00

ALIEN_ODDFRAME:			; $7321 Set to $00 on even frames, or $ff on odd frames in alien update. Used for jitter effect
	.byte	$00


; $7322		Yet another jump table. Probably was originally at $7000, but this is why jump tables are handy!
jumpChopperPhysics:			jmp     chopperPhysics			; $7322
jumpInitEntityTable:		jmp     initEntityTable			; $7325
jumpPosToScreenspace:		jmp     posToScreenspace		; $7328
jumpRenderMountains:		jmp     renderMountains			; $732b
jumpAddAndShift16DeadCode:	jmp     addAndShift16DeadCode	; $732e
jumpArithmeticShiftRight16:	jmp     arithmeticShiftRight16	; $7331
jumpInitBulletPhysics:		jmp     initBulletPhysics		; $7334
jumpChooseChopperSprite:	jmp     chooseChopperSprite		; $7337
jumpRenderMainRotor:		jmp     renderMainRotor			; $733a
jumpRenderTailRotor:		jmp     renderTailRotor			; $733d
jumpSetRenderOffset:		jmp     setRenderOffset			; $7340
jumpCalculateChopperFront:	jmp     calculateChopperFront	; $7343
jumpRandomNumber:			jmp     randomNumber			; $7346
jumpDeallocEntity:			jmp     deallocEntity			; $7349
jumpAllocateEntity:			jmp     allocateEntity			; $734c
jumpDepthSortEntity:		jmp     depthSortEntity			; $734f
jumpUpdateEntityList:		jmp     updateEntityList		; $7352
jumpDefragmentEntityList:	jmp     defragmentEntityList	; $7355
jumpIncrementHUDLoaded:		jmp     incrementHUDLoaded		; $7358
jumpDecrementHUDLoaded:		jmp     decrementHUDLoaded		; $735b
jumpZeroHUDLoaded:			jmp     zeroHUDLoaded			; $735e
jumpIncrementHUDKilled:		jmp     incrementHUDKilled		; $7361
jumpIncrementHUDKilledMany:	jmp     incrementHUDKilledMany  ; $7364
jumpIncrementHUDRescued:	jmp     incrementHUDRescued		; $7367
jumpRenderBCD:				jmp     renderBCD				; $736a
jumpPlayStaticNoise:		jmp     playStaticNoise			; $736d
jumpPlaySound:				jmp     playSound				; $7370
jumpPlayShellSound:			jmp     playShellSound			; $7373
jumpTableJoystickY:			jmp     handleJoystickY			; $7376
jumpTableJoystickX:			jmp     handleJoystickX			; $7379



; Integrates one frame of acceleration to velocity vectors on helicopter
integrateAcceleration:		; $737c
        lda     ZP_VELX_16_L
        sta     ZP_SCRATCH16_L
        lda     ZP_VELX_16_H
        sta     ZP_SCRATCH16_H
        ldy     #$04
        jsr     arithmeticShiftRight16
        sec
        lda     ZP_VELX_16_L
        sbc     ZP_SCRATCH16_L
        sta     ZP_VELX_16_L
        lda     ZP_VELX_16_H
        sbc     ZP_SCRATCH16_H
        sta     ZP_VELX_16_H

        lda     ZP_STICKX		; Get ABS value of acceleration
        bpl     integrateAccelerationABSAX
        eor     #$FF
        clc
        adc     #$01
integrateAccelerationABSAX:
		asl							; Convert |AccelX| to table lookup
        tay
        bit     ZP_STICKX
        bpl     integrateAccelerationPosAX
        bmi     integrateAccelerationNegAX

		; Note that math is reversed on acceleration vectors because acceleration sign is reversed from screen velocity
integrateAccelerationPosAX:	; If acceleration is positive, subtract acceleration
		sec
        lda     ZP_VELX_16_L
        sbc     integrateAccelerationAccelXTable,y
        sta     ZP_VELX_16_L
        lda     ZP_VELX_16_H
        sbc     integrateAccelerationAccelXTable+1,y
        sta     ZP_VELX_16_H
        jmp     integrateAccelerationCont

integrateAccelerationNegAX:	; If acceleration is negative, add acceleration
		clc
        lda     ZP_VELX_16_L
        adc     integrateAccelerationAccelXTable,y
        sta     ZP_VELX_16_L
        lda     ZP_VELX_16_H
        adc     integrateAccelerationAccelXTable+1,y
        sta     ZP_VELX_16_H

integrateAccelerationCont:
		lda     #$00
        sta     ZP_SCRATCH63				; Caches sign of velocity
        ldy     ZP_ACCELY				; Fetch Y acceleration based on requested acceleration
        sec
        lda     integrateAccelerationAccelYTable,y	; Apply to Y velocity
        sbc     ZP_VELY_16_H

        bpl     integrateAccelerationPosY			; Get absolute value of VY
        eor     #$FF					; Negate it
        clc
        adc     #$01
        ldx     #$FF					; Note that VY is negative
        stx     ZP_SCRATCH63

integrateAccelerationPosY:
		cmp     #$02				; Divide VY magnitude by 2 if it's bigger than 2
        bcc     integrateAccelerationSmallY
        lsr
integrateAccelerationSmallY:
		bit     ZP_SCRATCH63			; Apply original sign to scaled value
        bpl     integrateAccelerationSmallYPos
        eor     #$FF
        clc
        adc     #$01

integrateAccelerationSmallYPos:
		clc
        adc     ZP_VELY_16_H			; Add scaled acceleration to our velocity
        sta     ZP_VELY_16_H
        lda     #$00
        sta     ZP_VELY_16_L

        lda     ZP_VELX_16_H		; Clamp X velocity to maximum
        cmp     #$15
        bcc     integrateAccelerationDone
        cmp     #$EB
        bcs     integrateAccelerationDone
        bit     ZP_VELX_16_H
        bmi     integrateAccelerationClampNeg
        lda     #$00
        sta     ZP_VELX_16_L
        lda     #$15
        sta     ZP_VELX_16_H
        jmp     integrateAccelerationDone
integrateAccelerationClampNeg:
		lda     #$00
        sta     ZP_VELX_16_L
        lda     #$EB
        sta     ZP_VELX_16_H

integrateAccelerationDone:
		rts

; A table of horizontal acceleration values (16-bit signed)
integrateAccelerationAccelXTable:		; $7418
	.word	$0000, $0060, $00B4, $0108, $015C, $01A4

; A table of horizontal acceleration values (8-bit signed)
integrateAccelerationAccelYTable:			; $7424
	.byte	$F6,$F7,$F8,$F9,$FA,$FB,$FC,$FD,$FE,$FF,$00,$01,$02,$03,$04,$06
	


; Main chopper physics routine. This is complex and has a lot of smoothing and edge cases.
; It's no accident that flying the chopper feels as good as it does.
chopperPhysics:		; $7434
		jsr     integrateAcceleration		; Applies accelerations to velocities
        lda     ZP_AIRBORNE
        bne     chopperPhysicsAirborne

        jsr     chopperPhysicsGroundCheck		; We're on the ground, so we have things to check
        jsr     handleGround
        rts

chopperPhysicsAirborne:						; While airborne, handle velocity and ground
		jsr     integrateVelocity
        jsr     handleGround
        rts

chopperPhysicsGroundCheck:
		lda     ZP_GROUNDING				; Check for ground intersection being underway
        bne     chopperPhysicsIntersection

        lda     ZP_ACCELX
        beq     chopperPhysicsNoAccel
        jmp     chopperPhysicsHandleX

chopperPhysicsIntersection:
		lda     #$00			; Ground collision was previously detected
        sta     ZP_GROUNDING	; Clear flag. This alternation gives renderer a chance to render the squishing sprites
        clc
        lda     CHOP_POS_Y		; Keep chopper out of ground
        adc     #$01
        sta     CHOP_POS_Y
        jsr     deathBounceCancel
        jmp     chopperPhysics_Decay

chopperPhysicsNoAccel:
		bit     ZP_VELY_16_H
        bmi     chopperPhysicsNegY
        jmp     chopperPhysicsPosY

chopperPhysicsNegY:				; Handle downward velocity
		lda     ZP_VELY_16_H
        cmp     MIN_VY_H			; A minimum downward V is required to consider it a detection
        bcc     chopperPhysicsIntersection2
        bne     chopperPhysicsNormalFlight
        lda     ZP_VELY_16_L
        cmp     MIN_VY_L
        bcs     chopperPhysicsNormalFlight

chopperPhysicsIntersection2:		; Ground intersection detected!
		lda     #$01
        sta     ZP_GROUNDING
        sec
        lda     CHOP_POS_Y		; Decrement Y position when ground first touched
        sbc     #$01			; Not sure what this is for. Possibly to settle chopper visibly
        sta     CHOP_POS_Y
        jsr     bounceThrust
        rts

chopperPhysicsNormalFlight:
		jsr     deathBounceCancel
        jmp     chopperPhysics_Decay

chopperPhysicsPosY:				; Handle upward velocity
		jsr     bounceThrust
        jmp     chopperPhysics_Decay

chopperPhysicsHandleX:				; Handle X velocities
		lda     ZP_ACCELX
        eor     ZP_VELX_16_H
        bpl     chopperPhysics_LaunchCheck

chopperPhysics_Decay:					; This seems to decay Y velocity on the ground to settle the chopper better
		lda     ZP_VELX_16_L		; Cache velocity into scratch
        sta     ZP_SCRATCH16_L
        lda     ZP_VELX_16_H
        sta     ZP_SCRATCH16_H
        ldy     #$01
        jsr     arithmeticShiftRight16		; Shift it down one
        lda     ZP_SCRATCH16_L				; ... and copy it back to Y velocity
        sta     ZP_VELX_16_L
        lda     ZP_SCRATCH16_H
        sta     ZP_VELX_16_H

chopperPhysics_LaunchCheck:			; If we're not trying to launch, go into settling goo
		lda     ZP_VELY_16_H
        bmi     chopperPhysics_NoLaunch
        cmp     LAUNCHTHRESH_H
        bcc     chopperPhysics_NoLaunch
        bne     chopperPhysics_Done
        lda     ZP_VELY_16_L
        cmp     LAUNCHTHRESH_L
        bcs     chopperPhysics_Done
        jmp     chopperPhysics_NoLaunch

chopperPhysics_Done:
		jsr     integrateVelocity
        rts

chopperPhysics_NoLaunch:		; $74cb		; Figure out how to settle us down on the ground
		lda     ZP_VELX_16_L		; Cache X velocity in scratch
        sta     ZP_SCRATCH16_L
        lda     ZP_VELX_16_H
        sta     ZP_SCRATCH16_H
        lda     ZP_ACCELX
        beq     chopperPhysics_ZeroAccel
        bpl     chopperPhysics_PosAccel
        jmp     chopperPhysics_NegAccel

chopperPhysics_ZeroAccel:				; No modification required
		lda     ZP_VELX_16_H
        bmi     chopperPhysics_PosAccel
        bpl     chopperPhysics_NegAccel

chopperPhysics_PosAccel:
		sec
        lda     ZP_SCRATCH16_L		; Subtract Y velocity from X
        sbc     ZP_VELY_16_L
        sta     ZP_SCRATCH16_L
        lda     ZP_SCRATCH16_H
        sbc     ZP_VELY_16_H
        sta     ZP_SCRATCH16_H
        jmp     chopperPhysics_Settle

chopperPhysics_NegAccel:
		clc
        lda     ZP_SCRATCH16_L		; Add Y velocity to X
        adc     ZP_VELY_16_L
        sta     ZP_SCRATCH16_L
        lda     ZP_SCRATCH16_H
        adc     ZP_VELY_16_H
        sta     ZP_SCRATCH16_H


chopperPhysics_Settle:		; Calculate a reasonable acceleration magnitude for touch-down
		ldy     #$09				; Shift combined vector down 9 bits
        jsr     arithmeticShiftRight16
        sec
        lda     ZP_ACCELX
        sbc     ZP_SCRATCH16_L
        sta     ZP_SCRATCH56
        eor     ZP_ACCELX
        bpl     chopperPhysics_SettlePosAccel
        lda     ZP_ACCELX
        beq     chopperPhysics_SettlePosAccel
        lda     #$00
        sta     ZP_SCRATCH56

chopperPhysics_SettlePosAccel:
		lda     ZP_SCRATCH56
        bmi     chopperPhysics_SettleNeg
        cmp     #$06					; Clamp acceleration to within range of settling code
        bcc     chopperPhysics_SettleDone
        lda     #$05
        sta     ZP_SCRATCH56
        jmp     chopperPhysics_SettleDone
chopperPhysics_SettleNeg:
		cmp     #$FB					; Clamp acceleration to within range of settling code
        bcs     chopperPhysics_SettleDone
        lda     #$FB
        sta     ZP_SCRATCH56

chopperPhysics_SettleDone:
		lda     ZP_SCRATCH56				; Now do the actual settle with our processed touch-down acceleration
        jsr     groundSettle
        rts



; This little velocity fudge keeps the chopper from bouncing out of the ground
; as it sinks during the death animation
deathBounceCancel:		; $7534
		lda     ZP_VELY_16_L		; Cache Y velocity in scratch
        sta     ZP_SCRATCH16_L
        lda     ZP_VELY_16_H
        sta     ZP_SCRATCH16_H
        clc
        lda     ZP_DYING			; Shift it down by 3 or 4 depending on dying flag
        adc     #$03
        tay
        jsr     arithmeticShiftRight16
        clc
        lda     ZP_SCRATCH16_L		; Negate the scratch value and copy it
        eor     #$FF				; back into normal velocity
        adc     #$01
        sta     ZP_VELY_16_L
        lda     ZP_SCRATCH16_H
        eor     #$FF
        adc     #$00
        sta     ZP_VELY_16_H
        rts



; Handles thrust behaviour when sitting on the ground
bounceThrust:		; $7557
        lda     bounceThrustState		; Fetch the magic bounce-thrust and see if we need it
        sta     ZP_SCRATCH16_L
        lda     bounceThrustState+1
        sta     ZP_SCRATCH16_H
        bit     ZP_VELY_16_H
        bpl     bounceThrustPosVY
        jmp     bounceThrustNegVY
bounceThrustPosVY:
		lda     ZP_VELY_16_H			; If velocity is positive, then we
        sta     ZP_SCRATCH56			; scale down the bounce velocity
        lda     ZP_VELY_16_L			; before applying it. Not sure what this
        asl								; is doing. Something to ensure a clean-looking
        rol     ZP_SCRATCH56			; take-off, I guess? It ends up always zeroing
        asl								; the bounce V to zero, but this seems like a
        rol     ZP_SCRATCH56			; complex way to do that?
        asl
        rol     ZP_SCRATCH56
        ldy     ZP_SCRATCH56
        beq     bounceThrustNegVY
        jsr     arithmeticShiftRight16

bounceThrustNegVY:				; When player thrusts into the ground, offset it
		clc						; to give the little bounce effect.
        lda     ZP_VELY_16_L
        adc     ZP_SCRATCH16_L
        sta     ZP_VELY_16_L
        lda     ZP_VELY_16_H
        adc     ZP_SCRATCH16_H
        sta     ZP_VELY_16_H
        rts

bounceThrustState:		; $758c
		.word $04b0		; Offsets downthrust when sitting on the ground. A magic number that is always $04b0



; Integrates one frame of velocity to position vectors on helicopter
integrateVelocity:		; $758e
        clc
        lda     ZP_STICKX			; Apply stick position to acceleration
        adc     #$05
        sta     ZP_SCRATCH56
        clc
        lda     ZP_ACCELX
        adc     #$05
        sec
        sbc     ZP_SCRATCH56
        beq     integrateVelocityAccelZeroed
        bpl     integrateVelocityAccelNeg
        jmp     integrateVelocityAccelPos

integrateVelocityAccelNeg:			; Acceleration became/remained negative after acceleration
		dec     ZP_ACCELX
        sec
        lda     CHOP_POS_X_L			; Decrement position a bit- not certain why this is done here
        sbc     #$01				; Possibly to make the chopper feel like it's responding quickly to stick inputs
        sta     CHOP_POS_X_L
        lda     CHOP_POS_X_H
        sbc     #$00
        sta     CHOP_POS_X_H
        jmp     integrateVelocityAccelZeroed

integrateVelocityAccelPos:			; Acceleration became/remained positive after acceleration
		inc     ZP_ACCELX
        inc     CHOP_POS_X_L			; Increment position- not certain why this is done here
        bne     integrateVelocityAccelZeroed
        inc     CHOP_POS_X_H

integrateVelocityAccelZeroed:
		lda     ZP_VELX_16_L			; Scale down the X velocity before applying to position
        sta     ZP_SCRATCH16_L
        lda     ZP_VELX_16_H
        sta     ZP_SCRATCH16_H
        ldy     #$08
        jsr     arithmeticShiftRight16
        clc
        lda     CHOP_POS_X_L				; Now add VX to position
        adc     ZP_SCRATCH16_L
        sta     CHOP_POS_X_L
        lda     CHOP_POS_X_H
        adc     ZP_SCRATCH16_H
        sta     CHOP_POS_X_H

        lda     CHOP_POS_X_H			; Clamp position to boundaries of scrolling world
        cmp     BOUNDS_LEFT_H			; Clamping a 16-bit value is branch-tastic
        beq     integrateVelocityClamp0
        bcc     integrateVelocityClamp1
        jmp     integrateVelocityClamp2
integrateVelocityClamp0:
		lda     CHOP_POS_X_L
        cmp     BOUNDS_LEFT_L
        bcc     integrateVelocityClamp1
        jmp     integrateVelocityClamp2
integrateVelocityClamp1:
		lda     BOUNDS_LEFT_L			; Clamp to left edge
        sta     CHOP_POS_X_L
        lda     BOUNDS_LEFT_H
        sta     CHOP_POS_X_H
        lda     #$00					; Zero-out velocity
        sta     ZP_VELX_16_L
        sta     ZP_VELX_16_H
        jmp     integrateVelocityClamped
integrateVelocityClamp2:
		lda     CHOP_POS_X_H
        cmp     BOUNDS_RIGHT_H
        beq     integrateVelocityClamp3
        bcs     integrateVelocityClamp4
        jmp     integrateVelocityClamped
integrateVelocityClamp3:
		lda     CHOP_POS_X_L
        cmp     BOUNDS_RIGHT_L
        bcc     integrateVelocityClamped
        beq     integrateVelocityClamped
integrateVelocityClamp4:
		lda     BOUNDS_RIGHT_L			; Clamp to right edge
        sta     CHOP_POS_X_L
        lda     BOUNDS_RIGHT_H
        sta     CHOP_POS_X_H
        lda     #$00					; Zero-out velocity
        sta     ZP_VELX_16_L
        sta     ZP_VELX_16_H

integrateVelocityClamped:
		lda     ZP_VELY_16_L					; Scale down Y velocity before applying to position
        sta     ZP_SCRATCH16_L
        lda     ZP_VELY_16_H
        sta     ZP_SCRATCH16_H
        ldy     #$08
        jsr     arithmeticShiftRight16

        lda     ZP_SCRATCH16_L
        bpl     integrateVelocityPosY			; Get absolute value of scaled Y velocity
        eor     #$FF
        clc
        adc     #$01
        cmp     CHOP_POS_Y						; This seems to be an emergency bug prevention
        bcc     integrateVelocityPosY			; to keep huge negative velocities from pushing
        beq     integrateVelocityPosY			; us off the bottom of the screen. I can't find
        lda     #$00							; any way this could actually happen, but it's
        sta     CHOP_POS_Y						; cheap insurance, I guess
        jmp     integrateVelocityDone

integrateVelocityPosY:  
		clc
        lda     CHOP_POS_Y						; Apply scaled VY to poisiton
        adc     ZP_SCRATCH16_L
        sta     CHOP_POS_Y
        lda     BOUNDS_TOP						; Clamp Y position to top of sky
        cmp     CHOP_POS_Y
        bcc     integrateVelocityClampY
        jmp     integrateVelocityDone

integrateVelocityClampY:
		sta     CHOP_POS_Y
        lda     #$00							; Zero out Y velocity when clamped
        sta     ZP_VELY_16_L
        sta     ZP_VELY_16_H

integrateVelocityDone:
		rts



; Handle Y axis of joystick
handleJoystickY:	; $7663
        ldx     JOYSTICK_AXISY
        jsr     $fb1e				; ROM routine to read joystick. X = Axis to read, Y => Value read
        tya
        bit     PREFS_JOY_Y
        bmi     yInverted			; Check for inverted Y joystick
        eor     #$FF
yInverted:
		sta     CHOP_STICKY
        lsr
        lsr
        lsr
        lsr
        tax
        lda     joystickYTable,x	; Remap stick input to reasonable acceleration value
        sta     ZP_ACCELY
        lda     ZP_DYING			; Disable joystick during death
        bne     joystickYDying
        lda     ZP_DEATHTIMER
        bne     joystickYDying
        rts

joystickYDying:
		lda     #$02
        sta     ZP_ACCELY		; Keep us on the ground in a fixed spot while sinking
        rts

joystickYTable:			; $768c
		.byte	$00,$01,$02,$03,$04,$05,$06,$07,$08,$09,$0A,$0B,$0C,$0D,$0E,$0F



; Handle X axis of joystick
handleJoystickX:		; $769C
		ldx     JOYSTICK_AXISX
        jsr     $fb1e				; ROM routine to read joystick. X = Axis to read, Y => Value read
        tya
        bit     PREFS_JOY_X			; Check for inverted X joystick
        bmi     xInverted
        eor     #$FF
xInverted:
		sta     CHOP_STICKX			; Map joystick position to horizontal acceleration
        lsr
        lsr
        lsr
        lsr
        sec
        sbc     #$02
        bpl     xClampMin				; Clamp result to zero
        lda     #$00
xClampMin:
		cmp     #$0B
        bcc     xClampMax				; Clamp to max acceleration
        lda     #$0A
xClampMax:
		sec
        sbc     #$05
        sta     ZP_STICKX				; Store stick value to be used later by physics
        lda     ZP_DEATHTIMER			; Disable joystick during death
        bne     joystickXDying
        rts
joystickXDying:
		lda		#$00					; Zero stick during death animation
		sta		ZP_STICKX
		rts



; Plays a tank shell launching sound
; X=Second Time Index, Y=First Time Index, A=Loop Count
playShellSound:		; $76cd
		bit     PREFS_SOUND
        bpl     playShellSoundDone		; Sound is disabled
        bit     ZP_GAMEACTIVE
        bpl     playShellSoundDone		; Sound already playing

        stx     playShellSoundState0
        sta     playShellSoundState1
        lda     ZP_SINK_Y
        cmp     MAX_SINK
        beq     playShellSoundDone		; Player is dead so stop playing

playShellSoundOuterLoop:
		ldx     $8100,y					; Pulls random garbage from the middle of the jet update code
playShellSoundDelayLoop:				; to get some white noise. I SEE WHAT YOU DID THERE, DAN
		dex
        bne     playShellSoundDelayLoop
        bit     $C030				; Tick speaker
        bit     $C020				; Tick cassette port
        lda     playShellSoundState0
        lsr
        tax
playShellSoundDelayLoop2:
		dex
        bne     playShellSoundDelayLoop2
        bit     $C030				; Tick speaker
        bit     $C020				; Tick cassette port
        clc
        lda     playShellSoundState0
        adc     playShellSoundState1
        sta     playShellSoundState0
        dey
        bne     playShellSoundOuterLoop

playShellSoundDone:
		rts

playShellSoundState0:	; $770b
	.byte $00
playShellSoundState1:	; $770c
	.byte $00




; Handles all interactions with the chopper and the ground. Doesn't actually detect collisions.
; That's done elsewhere. This just decides between landing and crashes, etc.
handleGround:		; $770d
		bit     CHOP_POS_Y
        bmi     handleGroundNegY			; Seems like a panic edge case check for position ever going negative
        jmp     handleGroundPosY

handleGroundNegY:
		jmp     handleGroundAloft		; We're airborne, I guess? This case should never happen and would be very bad

handleGroundPosY:
		lda     ZP_GROUNDING
        beq     handleGroundAirborne
        jmp     handleGround_GroundDetected

handleGroundAirborne:
		lda     ZP_ACCELX
        ldx     ZP_TURN_STATE		; Get ABS of turn state
        bpl     handleGroundABS
        eor     #$FF
        clc
        adc     #$01
handleGroundABS:
		clc					; Convert |TurnState| into a table lookup
        adc     #$05
        asl
        tax
        sec
        lda     CHOP_POS_Y		; Find the bottom of the chopper
        sbc     handleGroundBottomTable,x
        bmi     handleGround_Clamp	; Negative values get clamped
        beq     handleGround_GroundDetected

handleGroundAloft:			; $7738
		lda     #$01			; Mark us as airborne and we're done
        sta     ZP_AIRBORNE
        lda     #$00
        sta     ZP_LANDED
        sta     ZP_LANDED_BASE
        rts

handleGround_Clamp:		; $7743
        lda     handleGroundBottomTable,x	; Clamp to table value
        sta     CHOP_POS_Y

handleGround_GroundDetected:
        lda     #$00			; We're touching the ground, so check all the possible outcomes
        sta     ZP_AIRBORNE

        sec								; Are we close to home?
        lda     CHOP_POS_X_L
        sbc     BASE_X_L
        sta     ZP_SCRATCH56
        lda     CHOP_POS_X_H
        sbc     BASE_X_H
        bne     handleGround_Afield

        lda     ZP_SCRATCH56				; We're in home base area
        bmi     handleGround_Afield		; Check if we're in the green pad area
        cmp     #$40
        bcs     handleGround_Afield
        cmp     #$0D
        bcc     handleGround_Afield
        lda     #$01					; On home-base landing pad
        sta     ZP_LANDED_BASE

handleGround_Afield:
		lda     ZP_SINK_Y
        beq     handleGround_NotCrashing
        jmp     handleGround_Crashing

handleGround_NotCrashing:
		lda     ZP_DYING
        beq     handleGround_StillAlive
        jmp     handleGround_StartDeath

handleGround_StillAlive:
		bit     ZP_VELX_16_H			; See what horizontal velocity is doing
        bmi     handleGroundNegVX
        lda     ZP_VELX_16_L			; VX is positive
        bne     handleGroundPosVX
        lda     ZP_VELX_16_H
        bne     handleGroundPosVX
        jmp     handleGroundZeroVX		; VX is zero

handleGroundNegVX:						; VX is  negative
		lda     ZP_VELX_16_L
        sta     ZP_SCRATCH16_L
        lda     ZP_VELX_16_H
        sta     ZP_SCRATCH16_H
        jmp     handleGroundMag

handleGroundPosVX:				; Negate positive VX to cache the magnitudes
		clc
        lda     ZP_VELX_16_L
        eor     #$FF
        adc     #$01
        sta     ZP_SCRATCH16_L
        lda     ZP_VELX_16_H
        eor     #$FF
        adc     #$00
        sta     ZP_SCRATCH16_H

handleGroundMag:					; Check for crashing due to excess velocity
		lda     ZP_SCRATCH16_H	; Scratches now contain negative magnitude of velocity
        cmp     CRASHSPEED_H
        bcc     handleGround_StartDeath
        bne     handleGroundZeroVX
        lda     ZP_SCRATCH16_L
        cmp     CRASHSPEED_L
        bcc     handleGround_StartDeath
        jmp     handleGroundZeroVX

handleGround_Crashing:
		lda     ZP_SINK_Y			; Update sinking if needed
        cmp     MAX_SINK
        bcc     handleGround_Sinking

        lda     ZP_DEATHTIMER		; Already dying
        bne     handleGround_Dying

        lda     #$01				; Start the new death timer
        sta     ZP_DEATHTIMER
        dec     ZP_SINK_Y

        lda     HOSTAGES_LOADED		; Murder all the hostages you had on board
        jsr     incrementHUDKilledMany

        inc     ZP_SINK_Y
        jsr     zeroHUDLoaded
        clc
        lda     HOSTAGES_LOADED
        adc     HOSTAGES_KILLED
        sta     HOSTAGES_KILLED
        lda     #$00				; Your wreckage is now empty
        sta     HOSTAGES_LOADED

handleGround_Dying:
		jmp     handleGround_Done

handleGround_Sinking:
		inc     ZP_SINK_Y			; Advance sinking and nothing more to do here
        jmp     handleGround_Done

handleGround_StartDeath:				; Start a new death sequence
		lda     #$01
        sta     ZP_SINK_Y
        sta     ZP_DYING
        jmp     handleGround_Done

handleGroundZeroVX:
		lda     ZP_ACCELX
        beq     handleGround_NoStick
        lda     #$00				; We've touched down, but not actually landed. This is the weird "angled but not moving on ground" state
        sta     ZP_LANDED
        jmp     handleGround_Done

handleGround_NoStick:				; We've fully and properly landed
		lda     #$01
        sta     ZP_LANDED

handleGround_Done:
		rts



; Settles the chopper firmly on the ground
; A=acceleration upon touchdown (must be in range -5..5)
groundSettle:		; $7803
		sta     groundSettleState
        tax
        lda     ZP_ACCELX
        tay
        bit     ZP_TURN_STATE
        bpl     groundSettle_PosTurn
        txa					; Turn state is negative
        eor     #$FF
        tax
        inx					; Store ABS in X
        tya
        eor     #$FF		; Store negative accel in Y
        tay
        iny

groundSettle_PosTurn:		; Turn state is positive
		txa
        clc
        adc     #$05		; Normalize turn state so we can make it a pointer
        asl
        tax					; Turn state lookup pointer now in X

        tya					; Convert accel magnitude to lookup pointer
        clc
        adc     #$05		; Normalize
        asl
        tay					; Accel lookup pointer now in Y
        sec

        lda     groundSettleTable,x		; Turn state minus acceleration
        sbc     groundSettleTable,y
        sta     ZP_SCRATCH16_L
        lda     groundSettleTable+1,x
        sbc     groundSettleTable+1,y
        sta     ZP_SCRATCH16_H

        bit     ZP_TURN_STATE			; Restore sign of turn state to that result
        bpl     groundSettle_PosTurn2

        lda     ZP_SCRATCH16_L
        eor     #$FF
        sta     ZP_SCRATCH16_L
        lda     ZP_SCRATCH16_H
        eor     #$FF
        sta     ZP_SCRATCH16_H
        inc     ZP_SCRATCH16_L
        bne     groundSettle_PosTurn2
        inc     ZP_SCRATCH16_H

groundSettle_PosTurn2:	; Scratch now holds table math result signed as turn state was
		clc
        lda     CHOP_POS_X_L		; Add that result to our X position
        adc     ZP_SCRATCH16_L
        sta     CHOP_POS_X_L
        lda     CHOP_POS_X_H
        adc     ZP_SCRATCH16_H
        sta     CHOP_POS_X_H

        sec						; Settle the chopper's bum on the ground
        lda     handleGroundBottomTable,x
        sbc     handleGroundBottomTable,y
        clc
        adc     CHOP_POS_Y
        sta     CHOP_POS_Y

        clc						; Modify acceleration state for being on the ground
        lda     ZP_ACCELX
        adc     #$05
        sta     ZP_SCRATCH56
        clc
        lda     groundSettleState
        adc     #$05
        sec
        sbc     ZP_SCRATCH56
        sta     ZP_SCRATCH56
        clc
        lda     ZP_ACCELX
        adc     ZP_SCRATCH56
        sta     ZP_ACCELX
        rts

groundSettleState:	; $787e
		.byte	$00
groundSettleTable:	; $787f
		.byte	$06,$00,$05,$00,$03,$00,$02,$00,$00,$00,$00,$00
		.byte 	$FF,$FF,$FE,$FF,$FC,$FF,$FB,$FF,$F9,$FF		; This may be unused bytes, or may be part of the table



; This table maps turn states to vertical offsets to the bottom of the chopper
handleGroundBottomTable:		; $7895		; Length should be 20, but looks like 22 in memory
	.byte	$0A,$00,$09,$00,$09,$00,$08,$00
	.byte	$08,$00,$07,$00,$07,$00,$07,$00
	.byte	$07,$00,$08,$00,$08,$00



; A white-noise generator for fires, explosions, etc
playStaticNoise:			; $78ab
        bit     PREFS_SOUND
        bpl     playStaticNoiseDone
        bit     ZP_GAMEACTIVE
        bpl     playStaticNoiseDone

        lda     ZP_SINK_Y			; Hacky abort to playing sound when chopper crash is done
        cmp     MAX_SINK
        beq     playStaticNoiseDone

        bit     $C030				; Tick speaker and cassette port
        bit     $C020
playStaticNoiseDone:
		rts




; Main sound-playing routine
; X = Tick Frequency Interval
; Y = Tick Count
; A = Decay
playSound:		; $78c2
		bit     PREFS_SOUND
        bpl     playSoundDone		; Sound is disabled
        bit     ZP_GAMEACTIVE
        bpl     playSoundDone		; Don't play sound during demo and end scenes
        stx     SOUND_COUNTER_X
        sta     SOUND_COUNTER_A
        lda     ZP_SINK_Y			; Hacky abort to playing sound when chopper crash is done
        cmp     MAX_SINK
        beq     playSoundDone
playSoundLoop:
		dex							; Short delay between ticks
        bne     playSoundLoop
        bit     $C030				; Tick speaker
        bit     $C020				; Tick cassette output for line-out sound
        dey
        beq     playSoundDone		; Count number of ticks
        clc
        lda     SOUND_COUNTER_X		; Increment frequency interval by decay
        adc     SOUND_COUNTER_A
        sta     SOUND_COUNTER_X
        tax
        jmp     playSoundLoop
playSoundDone:
		rts

SOUND_COUNTER_X:		; Currently playing sound, innermost time loop (within function)
		.byte 	$28
SOUND_COUNTER_A:		; Outermost time loop
		.byte	$00




; Generates a random number and returns it in accumulator.
; The initial seed of this is whatever was in the accumulator when the loader was done. Probably not
; super random but that doesn't matter much in this game. Seeding random on a computer with no clock
; or interrupts is never an easy thing.
randomNumber:				; $78f5
		lda		ZP_RND
		rol		ZP_RND
		eor		ZP_RND
		ror		ZP_RND
		inc		randomSeed
		adc		randomSeed
		bvc		randomNumberAlt
		inc		randomSeed
randomNumberAlt:
		sta		ZP_RND
		rts
randomSeed:					; $790b
		.byte $00



; Deallocates the current entity and frees it for other uses
deallocEntity:				; $790c
		clc
        lda     randomSeed			; Not sure why random seed is poked here? I guess it's
        adc     #$05				; a convenient "thing that happens regularly" to hook into
        sta     randomSeed

        ldx     ZP_CURR_ENTITY
        lda     ENTITY_NEXT,x
        ldy     entityTable,x
        tax
        sta     ENTITY_NEXT,y
        tya
        sta     entityTable,x
        ldx     ZP_CURR_ENTITY
        lda     ZP_FREE_ENTITY
        sta     entityTable,x
        stx     ZP_FREE_ENTITY
        rts




; Allocates a new entity in the table and sets it to the current one
allocateEntity:			; $792f
		ldx     ZP_FREE_ENTITY
        beq     allocateEntityFatal
        stx     ZP_CURR_ENTITY
        lda     entityTable,x
        sta     ZP_FREE_ENTITY
        rts
allocateEntityFatal:	; Ran out of entities! Dan must have had a bug with this so he's asserting here
        jsr     $fbdd			; Beep
        jsr     $fbdd			; Beep
        brk



; Does a sorted insertion of the current entity into the entity table to keep
; things sorted back to front. Ground level is a proxy for planar depth.
depthSortEntity:		; $7942
        ldx     ZP_CURR_ENTITY
        lda     ENTITY_GROUND,x
        sta     newEntityDepth
        ldy     entityTable

depthSortEntityLoop:			; Iterate through entities until we find one with lower ground than us
		lda     ENTITY_GROUND,y
        cmp     newEntityDepth
        bcc     theirGroundLower
        lda     entityTable,y
        tay
        beq     theirGroundLower
        jmp     depthSortEntityLoop

theirGroundLower:		; Found our insertion point, so fix up all the pointers
		cpy     ZP_NEXT_ENTITY
        bne     depthSortEntityPtr
        stx     ZP_NEXT_ENTITY
depthSortEntityPtr:
		lda     ENTITY_NEXT,y
        tax
        lda     ZP_CURR_ENTITY
        sta     entityTable,x
        sta     ENTITY_NEXT,y
        txa
        ldx     ZP_CURR_ENTITY
        sta     ENTITY_NEXT,x
        tya
        sta     entityTable,x
        rts

newEntityDepth:		; $797b
	.byte $00



; Updates the master array list of used entity IDs
updateEntityList:		; $797c
		ldx     entityIndexIterator
        lda     ZP_CURR_ENTITY
        sta     entityIndexTable,x
        inx
        stx     entityIndexIterator
        cpx     #$1E
        bcs     updateEntityListFatal		; If entity ID gets too high, this is fatal
        rts

updateEntityListFatal:
		jsr     $fbdd		; Beep three times and crash
        jsr     $fbdd		; This must have been a bug at some point, hence the aggressive debug tool
        jsr     $fbdd
        brk


; Runs through master entity index list and removes holes. Also
; fixes up entity table linked list pointers as it goes
defragmentEntityList:		; $7997
		ldy     entityIndexIterator
        beq     defragmentEntityListDone
        dey
        sty     entityIndexIterator
        ldx     entityIndexTable,y
        stx     ZP_CURR_ENTITY
        lda     ENTITY_NEXT,x
        ldy     entityTable,x
        tax
        sta     ENTITY_NEXT,y
        tya
        sta     entityTable,x
        jsr     depthSortEntity
        jmp     defragmentEntityList

defragmentEntityListDone:
		rts


; Increments the HUD counter for hostages loaded. Preserves registers.
incrementHUDLoaded:		; $79ba
        stx     ZP_SCRATCH6C		; Save registers
        sty     ZP_SCRATCH6D
        sed						; BCD alert!
        clc
        lda     HOSTAGES_LOADED_BCD
        tax
        adc     #$01
        sta     HOSTAGES_LOADED_BCD
        tay
        cld						; BCD alert!
        lda     #$01
        jsr     renderBCD
        ldx     ZP_SCRATCH6C		; Restore registers
        ldy     ZP_SCRATCH6D
        rts


; Decrements the HUD counter for hostages loaded. Preserves registers
decrementHUDLoaded:		; $79d5
		stx     ZP_SCRATCH6C		; Save registers
        sty     ZP_SCRATCH6D

        sed
        sec
        lda     HOSTAGES_LOADED_BCD
        tax
        sbc     #$01
        sta     HOSTAGES_LOADED_BCD
        tay
        cld
        lda     #$01
        jsr     renderBCD

        ldx     ZP_SCRATCH6C		; Restore registers
        ldy     ZP_SCRATCH6D
        rts


; Increments the HUD counter for hostages killed. Preserves registers.
incrementHUDKilled:	; $79f0
		stx     ZP_SCRATCH6C		; Save registers
        sty     ZP_SCRATCH6D

        sed								; Increment body count display
        clc
        lda     HOSTAGES_KILLED_BCD
        tax
        adc     #$01
        sta     HOSTAGES_KILLED_BCD
        tay
        cld

        lda     #$00
        jsr     renderBCD				; Render the new numbers
        bit     HOSTAGE_FIRSTDEATH		; Only play sound on the first death of the frame
        bmi     incrementHUDKilledDone
        ldx     #$30					; Play the death ditty
        ldy     #$30
        lda     #$00
        jsr     playSound
        ldx     #$43
        ldy     #$30
        lda     #$00
        jsr     playSound
        ldx     #$61
        ldy     #$30
        lda     #$00
        jsr     playSound
        lda     #$FF					; A hostage has died this frame, so no more sounds
        sta     HOSTAGE_FIRSTDEATH

incrementHUDKilledDone:
		ldx     ZP_SCRATCH6C		; Restore registers
        ldy     ZP_SCRATCH6D
        rts


; Increments the HUD counter for hostages rescued. Preserves registers.
incrementHUDRescued:		; $7a30
		stx     ZP_SCRATCH6C		; Save registers
        sty     ZP_SCRATCH6D

        sed
        clc
        lda     TOTAL_RESCUES_BCD	; Increment counter used for HUD
        tax
        adc     #$01
        sta     TOTAL_RESCUES_BCD
        tay
        cld
        lda     #$02
        jsr     renderBCD		; Render the new numbers
        ldx     #$28			; Play rescue sound
        ldy     #$28
        lda     #$00
        jsr     playSound

        ldx     ZP_SCRATCH6C		; Restore registers
        ldy     ZP_SCRATCH6D
        rts


; Zeroes the HUD counter for hostages loaded. Preserves registers.
zeroHUDLoaded:			; $7a54
        stx     ZP_SCRATCH6C		; Save registers
        sty     ZP_SCRATCH6D

        lda     #$00
        sta     HOSTAGES_LOADED_BCD
        ldx     #$FF
        ldy     #$00
        lda     #$01
        jsr     renderBCD

        ldx     ZP_SCRATCH6C		; Restore registers
        ldy     ZP_SCRATCH6D
        rts


; Increments the HUD counter for hostages killed by an amount. Preserves registers.
; A = Amount to increment counter
incrementHUDKilledMany:		; $7a6b
        stx     ZP_SCRATCH6C			; Save registers
        sty     ZP_SCRATCH6D
        tay
        beq     incrementHUDKilledManyDone
        ldx     HOSTAGES_KILLED_BCD

incrementHUDKilledManyLoop:
		sed
        clc
        lda     HOSTAGES_KILLED_BCD			; Loop and increment death counter
        adc     #$01
        sta     HOSTAGES_KILLED_BCD
        cld
        dey
        bne     incrementHUDKilledManyLoop

        ldy     HOSTAGES_KILLED_BCD			; Update HUD
        lda     #$00
        jsr     renderBCD

        ldx     #$40						; Play death ditty
        ldy     #$50
        lda     #$00
        jsr     playSound
        ldx     #$54
        ldy     #$40
        lda     #$00
        jsr     playSound
        ldx     #$61
        ldy     #$30
        lda     #$00
        jsr     playSound
        ldx     #$83
        ldy     #$20
        lda     #$00
        jsr     playSound

incrementHUDKilledManyDone:
		ldx     ZP_SCRATCH6C			; Restore registers
        ldy     ZP_SCRATCH6D
        rts



; Renders a BCD value up in the heads-up display
; X = Old value (BCD)
; Y = New Value (BCD)
; A = HUD position to render (0=Killed, 1=Loaded, 2=Rescued)
renderBCD:		; $7ab4
		bit     ZP_GAMEACTIVE
        bmi     renderBCDSoundPlaying
        jmp     renderBCDDone

renderBCDSoundPlaying:
		stx     renderBCDOld
        sty     renderBCDNew

        tax							; Configure digit rendering
        lda     renderBCDXPos,x		; Find X position of desired element
        sta     renderBCDState+1
        lda     #$00
        sta     renderBCDState+2
        lda     #$B2				; Y position of HUD numbers (bottom relative)
        sta     renderBCDState+3

        lda     #$FF				; Prepare to render
        jsr     jumpSetPalette
        jsr     jumpInitSlideAnim

        lda     renderBCDOld		; Determine if we have to touch both digits
        and     #$F0
        sta     renderBCDState

        lda     renderBCDNew
        and     #$F0
        cmp     renderBCDState
        beq     renderBCDLowDigit

        lsr			; Need a high digit
        lsr
        lsr
        tax
        lda     fontGraphicsTable,x			; Find sprite for the upper digit
        sta     ZP_SPRITE_PTR_L
        lda     fontGraphicsTable+1,x
        sta     ZP_SPRITE_PTR_H
        jsr     jumpSetSpriteAnimPtr
				.word $001a
        
        jsr     jumpSetBlitPos
				.word $7b56
        
        jsr     jumpBlitImage				; Draw it in both buffers
        jsr     jumpFlipPageMask

        jsr     jumpSetBlitPos
				.word $7b56

        jsr     jumpBlitImage
        jsr     jumpFlipPageMask

renderBCDLowDigit:
		clc
        lda     renderBCDState+1
        adc     #$08
        sta     renderBCDState+1
        bcc     renderBCD_Cont
        inc     renderBCDState+2
renderBCD_Cont:
		lda     renderBCDNew
        and     #$0F
        asl
        tax
        lda     fontGraphicsTable,x			; Find sprite for the lower digit
        sta     ZP_SPRITE_PTR_L
        lda     fontGraphicsTable+1,x
        sta     ZP_SPRITE_PTR_H

        jsr     jumpSetSpriteAnimPtr
				.word $001a
	
        jsr     jumpSetBlitPos
				.word $7b56

        jsr     jumpBlitImage				; Draw it in both buffers
        jsr     jumpFlipPageMask
        jsr     jumpSetBlitPos
				.word $7b56
        
        jsr     jumpBlitImage
        jsr     jumpFlipPageMask
renderBCDDone:
		rts


renderBCDXPos:		; $7b50
	.byte $3f,$8d,$db	; X screen positions of the three HUD numbers

renderBCDOld:			; $7b53
	.byte $00
renderBCDNew:			; $7b54
	.byte $00

renderBCDState:		; $7b55
	.byte	$00
	.byte	$00,$00	; $7b56  Pointer to render structure (always $0095, I think)
	.byte	$00




; Applies desired offsets to render position of current entity, then caches it at $1c-$1e
; Render offsets are used for a lot of things- rendering the chopper accessories, rendering
; the tank cannons, and sometimes just as fudges for sprites that need to align a certain way
; X = X render offset (low byte)
; A = X render offset (high byte)
; Y = Y render offset
setRenderOffset:		; $7b59
		stx     ZP_SCRATCH61
        sty     ZP_SCRATCH62
        sta     ZP_SCRATCH58
        ldx     ZP_CURR_ENTITY
        sec
        lda     ENTITY_X_L,x			; Fetch X position of entity
        sbc     ZP_SCRATCH61				; Apply desired offset...
        sta     ZP_RENDERPOS_XL			; ...then store as global render position
        lda     ENTITY_X_H,x
        bit     ZP_SCRATCH61
        bmi     setRenderOffsetNeg
        sbc     #$00
        sta     ZP_RENDERPOS_XH
        jmp     setRenderOffsetPos

setRenderOffsetNeg:
		sbc     #$FF
        sta     ZP_RENDERPOS_XH

setRenderOffsetPos:
		clc
        lda     ENTITY_Y,x				; Fetch Y position of entity
        adc     ENTITY_GROUND,x			; Offset for ground plane
        adc     ZP_SCRATCH62				; Apply desired additional offset
        sta     ZP_RENDERPOS_Y			; ...then store as global render position
        lda     ZP_SCRATCH58
        beq     setRenderParamsDone
        lsr
        eor     ZP_SCROLLPOS_L
        eor     ZP_RENDERPOS_XL
        and     #$01
        beq     setRenderParamsDone
        inc     ZP_RENDERPOS_XL
        bne     setRenderParamsDone
        inc     ZP_RENDERPOS_XH

setRenderParamsDone:
		rts




; Initializes the entity (game object) table. This code is partly wrong- see below
initEntityTable:		; $7b9a
		lda     #$00			; Render offset table iterators
        sta     ZP_OFFSET_ROW0
        sta     ZP_OFFSET_ROW1

        lda     #$25			; Pointer to renderDisplayList0
        sta     ZP_OFFSETPTR0_L
        lda     #$70
        sta     ZP_OFFSETPTR0_H

        lda     #$C5			; Pointer to renderDisplayList1
        sta     ZP_OFFSETPTR1_L
        lda     #$70
        sta     ZP_OFFSETPTR1_H

        lda     #$00
        sta     entityIndexIterator

        ldx     #$0A			; Initialize entity linked list
        stx     entityListEnd	; One element, pointing to chopper
        stx     entityTable
        lda     #$00
        sta     ENTITY_TYPE,x	; Chopper is type 0
        lda     CHOP_GROUND_INIT
        sta     ENTITY_GROUND,x	; Place chopper on ground

		lda     #$00			; Terminate list after chopper
        sta     entityListEnd,x
        sta     entityTable,x

        ldx     #$14			; Chopper takes first entity, so advance free pointer
        stx     ZP_FREE_ENTITY

; There seems to be multiple possible bugs in the game here. The entity table size is one
; too high (30, but there's only room for 29 entries). Furthermore, it appears only
; 25 entries are properly initialized with their entity IDs. After that the loop overflows
; past ID $fa and starts generating nonsense IDs for the last four entries. I doubt the
; game can ever get more than 25 active things anyway, but I think this code would fail
; in multiple ways if it did.

		; Initialize all entity IDs in the table
        ldy     entityTableSize		; This is 30, but should be 29
        dey
        dey

initEntityTableLoop:
		dey
        beq     initEntityTableDone
        txa
        clc
        adc     #$0A
        sta     entityTable,x
        tax
        jmp     initEntityTableLoop

initEntityTableDone:
		lda     #$00				; This writes to a random place in the middle of the entity
        sta     entityTable,x		; table. This seems to be a bug related to the bad loop above
									; It's trying to null-terminate the list but it....misses. :)
        lda     #$00
        sta     NUM_ALIENS
        sta     NUM_JETS
        sta     NUM_TANKS
        rts



; Converts global rendering position of a sprite to screenspace
; and populates a row in renderDisplayList0/renderDisplayList1
; A = Row in spriteGeometry for this sprite
; Each entity type reserves its own row
posToScreenspace:			; $7bf8
		sta     ZP_SCRATCH5A			; Cache table row
        sec
        lda     ZP_RENDERPOS_XL
        sbc     ZP_SCROLLPOS_L
        sta     ZP_POS_SCRATCH0
        lda     ZP_RENDERPOS_XH
        sbc     ZP_SCROLLPOS_H
        sta     ZP_POS_SCRATCH1
        clc
        lda     ZP_RENDERPOS_Y
        adc     SCROLLPOS_Y			; Always 0. Perhaps Dan had visions of supporting vertical scrolling
        sta     ZP_POS_SCRATCH2
        ldy     ZP_OFFSET_ROW0

        lda     ZP_SCRATCH5A		; Byte 0 is table row for spriteGeometry
        sta     (ZP_OFFSETPTR0_L),y	; Points to renderDisplayList0 or renderDisplayList1 depending on buffer
        iny
        lda     ZP_POS_SCRATCH0	; Byte 1 is screenspace X (low byte)
        sta     (ZP_OFFSETPTR0_L),y
        iny
        lda     ZP_POS_SCRATCH1	; Byte 2 is screenspace X (high byte)
        sta     (ZP_OFFSETPTR0_L),y
        iny
        lda     ZP_POS_SCRATCH2	; Byte 3 is screenspace Y
        sta     (ZP_OFFSETPTR0_L),y
        iny
        sty     ZP_OFFSET_ROW0		; Advance to next row
        rts



; Renders all the mountains on the horizon
renderMountains:	;	$7c28
        lda     ZP_SCROLLPOS_H		; Scale down scrolling position to create a parallax effect
        lsr							; The mountains scroll "slower" than everything else
        sta     ZP_SCRATCH57
        lda     ZP_SCROLLPOS_L
        ror
        and     #$FE
        sta     ZP_SCRATCH56
        sec
        lda     ZP_SCROLLPOS_L
        sbc     ZP_SCRATCH56
        sta     ZP_SCRATCH5F
        lda     ZP_SCROLLPOS_H
        sbc     ZP_SCRATCH57
        sta     ZP_SCRATCH60
        lda     #$00
        sta     ZP_SCRATCH56
        clc
        lda     ZP_SCRATCH5F		; Store final processed X position in render parameters
        sta     ZP_RENDERPOS_XL
        lda     ZP_SCRATCH57
        adc     ZP_SCRATCH60
        sta     ZP_RENDERPOS_XH

        lda     MOUNTAIN_Y			; We always have the same Y
        sta     ZP_RENDERPOS_Y

        lda     #$03					; Iterate through all mountain ranges
        sta     renderMountainsIndex

renderMountainsLoop:
        lda     ZP_SCRATCH57				; Are we visible?
        cmp     #$04
        bcc     renderMountainsNext

        clc
        lda     ZP_SCRATCH57
        lsr
        lsr
        adc     ZP_SCRATCH57
        sta     ZP_SCRATCH58
        lda     ZP_SCRATCH58
        and     #$03					; Reduce our X position down to one of four mountain choices
        asl
        tax
        lda     mountainSpriteTable,x		; Prepare to render
        sta     ZP_SPRITE_PTR_L
        lda     mountainSpriteTable+1,x
        sta     ZP_SPRITE_PTR_H

        jsr     jumpSetWorldspace
				.word $001c
        
        jsr     jumpSetSpriteAnimPtr			; $7c7e
				.word	$001a

		jsr     jumpClipToScroll
        bcs     renderMountainsNext			; Skip if we're clipped out
        lda     #$01
        jsr     posToScreenspace
        jsr     jumpBlitAlignedImage		; Render!

renderMountainsNext:
		dec     renderMountainsIndex
        beq     renderMountainsDone
        inc     ZP_RENDERPOS_XH
        inc     ZP_SCRATCH57
        jmp     renderMountainsLoop

renderMountainsDone:
		rts

renderMountainsIndex:	; $7c9d			; Iterator for all the mountain ranges
		.byte $00



; Sets the correct helicopter sprite to render based on the current state
; of helicopter physics
chooseChopperSprite:		; $7c9e
		lda     ZP_ACCELX
        bit     ZP_TURN_STATE		; Sideways or facing camera?
        bpl     chooseChopperSpriteABS

        eor     #$FF				; Facing left, so negate to unify left/right cases
        clc
        adc     #$01

chooseChopperSpriteABS:
		sta     ZP_SCRATCH58			; Facing cases: $01=sideways, $00=head-on

        lda     ZP_ACCELX
        bne     chooseChopperSpriteMoving

        bit     ZP_TURN_STATE
        bmi     chooseChopperSpriteLeft

        lda     #$21				; Initialize render vector to right-facing
        sta     chopRenderVector
        lda     #$10
        sta     chopRenderVector+1
        jmp     chooseChopperSpriteCheckRot

chooseChopperSpriteLeft:
		lda     #$24				; Initialize render vector to left-facing
        sta     chopRenderVector
        lda     #$10
        sta     chopRenderVector+1
        jmp     chooseChopperSpriteCheckRot

chooseChopperSpriteMoving:
		clc
        lda     ZP_TURN_STATE		; Choose render vector based on our rotate-animation state
        adc     #$05
        asl
        tay
        lda     chopperRenderTable,y
        sta     chopRenderVector
        lda     chopperRenderTable+1,y
        sta     chopRenderVector+1

chooseChopperSpriteCheckRot:
		lda     ZP_TURN_STATE
        beq     chooseChopperSpriteHeadOn	; 0=Facing camera
        cmp     #$05		; 5=full right
        beq     chooseChopperSpriteFullSideways
        cmp     #$FB		; -5=full left
        beq     chooseChopperSpriteFullSideways

        jmp     chooseChopperSpriteUseRot		; Rotation under way

chooseChopperSpriteHeadOn:
		lda     ZP_ACCELX
        bne     chooseChopperSpriteUseRot
        lda     ZP_GROUNDING
        beq     chooseChopperSpriteUseRot
        jmp     chooseChopperSpriteHeadOnSquish

chooseChopperSpriteFullSideways:
		lda     ZP_ACCELX
        bne     chooseChopperSpriteUseSide
        lda     ZP_GROUNDING
        beq     chooseChopperSpriteUseSide
        jmp     chooseChopperSideSquishing

chooseChopperSpriteHeadOnSquish:	; Creates the spring-loaded landing gear effect when head on
		lda     chopperSquishingSpriteTable+2	; The "squished" head-on sprite
        sta     ZP_SPRITE_PTR_L
        lda     chopperSquishingSpriteTable+3	; The "squished" head-on sprite
        sta     ZP_SPRITE_PTR_H
        lda     #$00
        sta     ZP_SCRATCH58
        jmp     chooseChopperSpriteReady

chooseChopperSideSquishing:			; Creates the spring-loaded landing gear effect when head on
		lda     chopperSquishingSpriteTable
        sta     ZP_SPRITE_PTR_L
        lda     chopperSquishingSpriteTable+1
        sta     ZP_SPRITE_PTR_H
        lda     #$00
        sta     ZP_SCRATCH58
        jmp     chooseChopperSpriteReady

chooseChopperSpriteUseSide:
		clc							; Helicopter is sideways, so choose an angle sprite
        lda     ZP_SCRATCH58
        adc     #$05
        asl
        tay
        lda     chopperSideSpriteTable,y
        sta     ZP_SPRITE_PTR_L
        iny
        lda     chopperSideSpriteTable,y
        sta     ZP_SPRITE_PTR_H
        lda     #$00
        sta     ZP_SCRATCH58
        jmp     chooseChopperSpriteReady

chooseChopperSpriteUseRot:
		lda     ZP_TURN_STATE		; Get ABS value of rotation animation frame
        bpl     chooseChopperSpriteUseRotABS
        eor     #$FF
        clc
        adc     #$01

chooseChopperSpriteUseRotABS:
		asl						; Helicopter is face-on or mid-rotation so we use tilting renderer
        tay
        lda     chopperHeadOnSpriteTable,y
        sta     ZP_SPRITE_PTR_L
        lda     chopperHeadOnSpriteTable+1,y
        sta     ZP_SPRITE_PTR_H
        lda     ZP_SCRATCH58
        jsr     jumpSetSpriteTilt		; Sets tilt of chopper when facing camera

        clc								; Calculate a small vertical offset to keep tilted sprites on same apparent origin
        lda     ZP_ACCELX
        adc     #$05
        sta     ZP_SCRATCH56
        asl
        asl
        asl
        clc
        adc     ZP_SCRATCH56
        clc
        adc     ZP_TURN_STATE
        clc
        adc     #$04
        tax
        lda     tiltOffsetTable,x
        sta     ZP_SCRATCH58

chooseChopperSpriteReady:				; Got everything we need, so prepare to render
		ldy     #$00
        lda     (ZP_SPRITE_PTR_L),y
        lsr
        tax
        iny
        lda     (ZP_SPRITE_PTR_L),y
        lsr
        clc
        adc     ZP_SCRATCH58
        tay
        lda     #$00
        jsr     setRenderOffset

        jsr     jumpSetWorldspace			; Configure to render the chopper sprite that we chose above
				.word $001c
        
        jsr     jumpSetSpriteAnimPtr		; $7d8b
				.word $001a

		jsr		jumpClipToScroll

		lda		ZP_SINK_Y
		beq		chooseChopperSpriteDone
		sta		chopperSpriteCrashVal		; During crash, animate sinking here
		
		; Cleverly, the same code sinks the chopper into the ground also does the title animations
		; Which came first? My guess is the chopper sink effect was done first, then Dan went looking
		; for an easy way to do interesting titles at the end and reused this.
		jsr		jumpUpdateSlideAnim		; 7d9a
						.byte	$00			; Left clip
						.byte	$00			; Right clip
						.byte	$00			; Amount of image height to render $7d9f
chopperSpriteCrashVal:	.byte	$06			; Bottom clip amount (sink value when crashing) $7da0

chooseChopperSpriteDone:
		.byte 	$20				; jsr
chopRenderVector:				; $7da2 Self-modifying code target. Vector to render that we chose in code above
		.word	$1111
        rts

chopperRenderTable:				; $7da5		A lookup table of chopper rendering vectors based on tilt
		.word	jumpRenderSpriteLeft
		.word	jumpRenderTiltedSpriteRight
		.word	jumpRenderTiltedSpriteRight
		.word	jumpRenderTiltedSpriteRight
		.word	jumpRenderTiltedSpriteRight
		.word	jumpRenderTiltedSpriteLeft
		.word	jumpRenderTiltedSpriteLeft
		.word	jumpRenderTiltedSpriteLeft
		.word	jumpRenderTiltedSpriteLeft
		.word	jumpRenderTiltedSpriteLeft
		.word	jumpRenderSpriteRight


; Renders the main rotor with tilt as needed
renderMainRotor:			; $7dbb
		clc
        lda     ZP_ACCELX
        adc     #$05			; Normalize acceleration and convert to pointer
        asl
        sta     ZP_SCRATCH56
        asl
        sta     ZP_SCRATCH57
        asl
        asl
        clc
        adc     ZP_SCRATCH56
        adc     ZP_SCRATCH57
        sta     ZP_SCRATCH56
        clc
        lda     ZP_TURN_STATE	; Normalize turn state and convert to pointer
        adc     #$05
        asl
        clc
        adc     ZP_SCRATCH56
        tax
        lda     mainRotorTiltTableX,x		; Look up render X offsets to use for current chopper tilt
        sta     ZP_SCRATCH6F
        lda     mainRotorTiltTableX+1,x
        sta     ZP_SCRATCH70
        clc
        lda     ZP_ACCELX
        adc     #$05
        asl
        tax
        clc
        lda     mainRotorTiltTableY+1,x		; Look up render Y offsets to use for current chopper tilt
        adc     ZP_SCRATCH70
        tay
        clc
        lda     mainRotorTiltTableY,x
        adc     ZP_SCRATCH6F
        tax
        lda     #$00
        jsr     setRenderOffset			; Prepare to render

        jsr     jumpSetWorldspace
				.word	$001c
        
        lda     ZP_ACCELX
        jsr     jumpSetSpriteTilt

        lda     ZP_SINK_Y				; Freeze main rotor while crashing
        bne     mainRotorWrap

        lda     mainRotorFrame			; Update main rotor animation state
        beq     mainRotorWrap
        sec
        sbc     #$02
        sta     mainRotorFrame
        jmp     mainRotorReady

mainRotorWrap:
		lda     #$04
        sta     mainRotorFrame

mainRotorReady:
		ldx     mainRotorFrame			; Look up sprite based on animation frame
        lda     mainRotorAnimationTable,x
        sta     ZP_SPRITE_PTR_L
        inx
        lda     mainRotorAnimationTable,x
        sta     ZP_SPRITE_PTR_H

        jsr     jumpSetSpriteAnimPtr
				.word   $001a

        jsr		jumpClipToScroll		; Amazingly rotor is clipped to scroll window, even though it should never be possible
		jsr		jumpRenderTiltedSpriteLeft	; Render the rotor!

        rts

mainRotorFrame:			; $7e38	Main rotor animation frame. Counts 4,2,0
		.byte	$00




renderTailRotor:		; $7e39
		lda     ZP_TURN_STATE				; Basic cases for tail rotor
        beq     renderTailRotorHeadOn
        cmp     #$05
        beq     renderTailRotorFullSide
        cmp     #$FB
        beq     renderTailRotorFullSide
        cmp     #$FF
        beq     renderTailRotorNearSide
        cmp     #$01
        beq     renderTailRotorNearSide
        rts									; If in doubt, don't render it

renderTailRotorNearSide:
		eor     ZP_ACCELX					; Some weird edge cases here when moving sideways
        bmi     renderTailRotorHeadOn		; The tilt exposes the tail rotor a little bit
        rts

renderTailRotorHeadOn:
		lda     ZP_FRAME_COUNT
        and     #$01
        beq     renderTailRotorHeadOnEven	; Only render every other frame when head-on
        rts

renderTailRotorHeadOnEven:
		clc
        lda     ZP_ACCELX
        adc     #$05
        asl
        tay
        ldx     tailRotorHeadOnOffsets,y		; Look up render offsets based on our tilt
        lda     tailRotorHeadOnOffsets+1,y
        tay
        cpx     #$80
        bne     renderTailRotorStillVisible
        rts										; At some tilts, tail rotor isn't visible

renderTailRotorStillVisible:
		lda     #$00
        jsr     setRenderOffset				; Prepare to render

        jsr     jumpSetWorldspace
				.word $001c

        jsr     jumpSetImagePtr
				.word $7ee4
        
        jsr     jumpClipToScroll			; Amazingly the tail rotor is clipped
        jsr     jumpRenderSpriteRight		; Render it!
        rts

renderTailRotorFullSide:		; Find offset for tail rotor location depending on tilt
		clc						; Facing left or right?
        lda     ZP_ACCELX
        adc     #$05
        asl
        tax
        bit     ZP_TURN_STATE
        bmi     renderTailRotorSideLeft

        lda     tailRotorSideRightOffsetTable,x		; Facing right
        sta     ZP_SCRATCH6F
        lda     tailRotorSideRightOffsetTable+1,x
        sta     ZP_SCRATCH70
        jmp     renderTailRotorSideCont

renderTailRotorSideLeft:							; Facing left
		lda     tailRotorSideLeftOffsetTable,x
        sta     ZP_SCRATCH6F
        lda     tailRotorSideLeftOffsetTable+1,x
        sta     ZP_SCRATCH70

renderTailRotorSideCont:
		lda     ZP_SINK_Y				; Don't animate tail rotor when crashing
        bne     renderTailRotorSideRenderFrame

        lda     tailRotorFrame			; Advance tail rotor rotation state
        beq     renderTailRotorSideWrapFrame
        sec
        sbc     #$02
        sta     tailRotorFrame
        jmp     renderTailRotorSideRenderFrame

renderTailRotorSideWrapFrame:
		lda     #$06
        sta     tailRotorFrame

renderTailRotorSideRenderFrame:
		ldx     tailRotorFrame
        lda     tailRotorAnimationTable,x		; Look up which tail rotor sprite to use
        sta     ZP_SPRITE_PTR_L
        lda     tailRotorAnimationTable+1,x
        sta     ZP_SPRITE_PTR_H

        jsr     jumpSetSpriteAnimPtr		; Prepare to render
				.word $001a
        
        ldx     ZP_SCRATCH6F				; Apply offsets we looked up
        ldy     ZP_SCRATCH70
        lda     #$00
        jsr     setRenderOffset

        jsr     jumpSetWorldspace
				.word $001c
        
        jsr     jumpClipToScroll			; Yes, all the tail rotors are clipped
        jsr     jumpRenderSpriteRight		; Render it!
        rts

tailRotorFrame:		; $7ee3	Current tail rotor animation frame. Counts 6,4,2,0
		.byte   $02

tailRotorSprite:	; $7ee4		W,H, two bytes of pixels. Used for head-on tail rotor
		.byte	$01,$02,$80,$80


; Calculates offset to the front of the helicopter. Used for spawning bullets, for example.
; Returns X=X offset, Y=Y offset (8 bit signed)
calculateChopperFront:		; $7ee8
		clc
        lda     ZP_ACCELX
        adc     #$05
        asl
        sta     ZP_SCRATCH56
        asl
        sta     ZP_SCRATCH57
        asl
        asl
        clc
        adc     ZP_SCRATCH56
        adc     ZP_SCRATCH57
        sta     ZP_SCRATCH56
        clc
        lda     ZP_TURN_STATE
        adc     #$05
        asl
        clc
        adc     ZP_SCRATCH56
        tay
        ldx     chopperFrontOffsetTable,y
        lda     chopperFrontOffsetTable+1,y
        tay
        rts



; Little math utility that does addition and shift with 8 and 16 bit values. Doesn't
; seem to be called from anywhere, but takes input in $5c and returns result in $5e/$5f
addAndShift16DeadCode:			; $7f0e
		lda     #$00
        ldx     #$08
addAndShift16DeadCodeLoop:
		lsr     ZP_SCRATCH5B
        bcc     addAndShift16DeadCodeSkip
        clc
        adc     ZP_SCRATCH5C
addAndShift16DeadCodeSkip:
		ror
        ror     ZP_SCRATCH16_L
        dex
        bne     addAndShift16DeadCodeLoop
        sta     ZP_SCRATCH16_H
        rts



; Does an artimetic right-shift of a 16-bit value stored in the 16-bit scratch
; Y=Bits to shift
arithmeticShiftRight16:			; $7f22
		lda     ZP_SCRATCH16_H			; Get absolute value of 16-bit scratch
        sta     arithmeticShiftRight16Scratch		; Cache original sign
        bpl     arithmeticShiftRight16_Pos
        clc
        lda     ZP_SCRATCH16_L
        eor     #$FF
        adc     #$01
        sta     ZP_SCRATCH16_L
        lda     ZP_SCRATCH16_H
        eor     #$FF
        adc     #$00
        sta     ZP_SCRATCH16_H

arithmeticShiftRight16_Pos:
		lsr     ZP_SCRATCH16_H			; Shift bits down through both bytes
        ror     ZP_SCRATCH16_L
        dey
        bne     arithmeticShiftRight16_Pos

        lda     arithmeticShiftRight16Scratch	; If original was positive, we're done
        bpl     arithmeticShiftRight16_Done

        lda     ZP_SCRATCH16_L			; Negate to restore original sign
        eor     #$FF
        sta     ZP_SCRATCH16_L
        lda     ZP_SCRATCH16_H
        eor     #$FF
        sta     ZP_SCRATCH16_H
        inc     ZP_SCRATCH16_L
        bne     arithmeticShiftRight16_Done
        inc     ZP_SCRATCH16_H
arithmeticShiftRight16_Done:
		rts

arithmeticShiftRight16Scratch:		; $7f59
		.byte	$00



; Configures the motion of a newly created bullet, based on helicopter
; tilt and orientation
initBulletPhysics:		; $7f5a
		ldx     ZP_CURR_ENTITY

        lda     ZP_TURN_STATE		; Get ABS of turn state
        bpl     initBulletPhysicsABS0
        eor     #$FF
        clc
        adc     #$01
initBulletPhysicsABS0:
		sta     ZP_SCRATCH58
        asl
        sta     ZP_SCRATCH56
        asl
        clc
        adc     ZP_SCRATCH56
        sta     ZP_SCRATCH56
        asl     ZP_SCRATCH56

        lda     ZP_ACCELX			; Get ABS of stick value
        bpl     initBulletPhysicsABS1
        eor     #$FF
        clc
        adc     #$01
initBulletPhysicsABS1:
		asl
        clc
        adc     ZP_SCRATCH56
        tay
        lda     bulletVelocityTable,y

        bit     ZP_TURN_STATE		; Get ABS of turn state again
        bpl     initBulletPhysicsABS2
        eor     #$FF
        clc
        adc     #$01
initBulletPhysicsABS2:
		sta     ZP_SCRATCH56
        lda     ZP_VELX_16_H
        bpl     initBulletPhysicsABS2a
        clc
        adc     #$01
initBulletPhysicsABS2a:
		clc
        adc     ZP_SCRATCH56
        sta     ENTITY_VX,x
        lda     bulletVelocityTable+1,y
        sta     ZP_SCRATCH56
        lda     ZP_TURN_STATE		; Is tilt Y positive or negative?
        eor     ZP_ACCELX
        bpl     initBulletPhysicsABS3

        lda     ZP_SCRATCH56			; Negate Y velocity if needed for tilt
        eor     #$FF
        sta     ZP_SCRATCH56
        inc     ZP_SCRATCH56
initBulletPhysicsABS3:
		lda     ZP_SCRATCH56
        sta     ENTITY_VY,x

        ldy     ZP_SCRATCH58			; Look up gravity used by this bullet orientation
        lda     bulletGravityTable,y
        sta     ENTITY_DIR,x
        rts

bulletGravityTable:		; $7fbc  Maps turn state (0-5) to bullet gravity. Full side shots have no gravity, but bombs fall
		.byte $fe,$fe,$ff,$ff,$ff,$00



; $7fc2 A block of what appear to be unused bytes
		.byte	$80,$80,$80,$80,$80,$80,$80,$80,$80,$80,$80,$80,$80,$80,$55,$2A
		.byte	$55,$2A,$55,$2A,$55,$2A,$55,$2A,$55,$2A,$55,$2A,$55,$2A,$55,$2A
		.byte	$55,$2A,$55,$2A,$55,$2A,$55,$2A,$55,$2A,$55,$2A,$55,$2A,$55,$2A
		.byte	$55,$2A,$55,$2A,$55,$2A,$00,$00,$00,$00,$00,$00,$00,$A0



; $8000 A very small jump table. A curious thing that maybe Dan had bigger plans for
jumpUpdateEntities:		jmp		updateEntities			; $8000
jumpRemoveCurrentTank:	jmp		removeCurrentTank		; $8003		; This is kind of a hack, really



; Main entity update routine for jets
updateJet:			; $8006
		ldx     ZP_CURR_ENTITY		; We're the current entity. First job is to pick a sprite

        lda     ENTITY_VX,x			; Convert our velocity into a table lookup
        asl
        tay
        lda     jetXVelocityTable,y
        sta     ZP_SCRATCH58			; Cache X velocity table pointer for next lookup
        lda     jetXVelocityTable+1,y
        sta     ZP_SCRATCH59

        lda     ENTITY_VY,x			; X Velocity table gives us a pointer to a Y-velocity table
        asl
        asl
        tay
        lda     (ZP_SCRATCH58),y		; Fetch value from relevant Y velocity table (jetYVelocityTables)
        sta     ZP_SCRATCH6E		; Cache each entry in the Y velocity table
        iny
        lda     (ZP_SCRATCH58),y
        sta     ZP_SCRATCH6F
        iny
        lda     (ZP_SCRATCH58),y
        sta     ZP_SCRATCH70
        iny
        lda     (ZP_SCRATCH58),y
        sta     ZP_SCRATCH71

        lda     ENTITY_VX,x			; Map our X velocity to a sprite
        asl
        tay
        lda     jetSpriteTable,y
        sta     ZP_SCRATCH58			; Cache sprite pointer for rendering below
        lda     jetSpriteTable+1,y
        sta     ZP_SCRATCH59

        lda     ZP_SCRATCH6E		; Prepare to render
        asl
        tay
        lda     (ZP_SCRATCH58),y
        sta     ZP_SPRITE_PTR_L
        iny
        lda     (ZP_SCRATCH58),y
        sta     ZP_SPRITE_PTR_H
        jsr     jumpSetSpriteAnimPtr
				.word $001a

		ldy     #$00
        lda     (ZP_SPRITE_PTR_L),y
        lsr
        tax
        ldy     #$01
        lda     (ZP_SPRITE_PTR_L),y
        lsr
        tay
        lda     #$01
        jsr     jumpSetRenderOffset
        jsr     jumpSetWorldspace
				.word $001c

		lda     #$FF
        sta     ZP_SCRATCH67
        jsr     jumpClipToScroll
        bcs     updateJetOffscreen

        lda     #$00
        sta     ZP_SCRATCH67
        lda     #$FF
        jsr     jumpSetPalette
        ldx     ZP_CURR_ENTITY
        lda     ENTITY_DIR,x			; Check heading for final sprite render
        bmi     updateJetFaceLeft
        jsr     jumpRenderSprite		; Render the jet facing right
        jmp     updateJetPostRender

updateJetFaceLeft:
		jsr     jumpRenderSpriteFlip	; Render the jet facing left

updateJetPostRender:
		ldx     ZP_CURR_ENTITY			; Convert our X velocity into another table lookup
        lda     ENTITY_VX,x
        asl
        asl
        asl
        clc
        adc     ZP_SCRATCH6E			; Sprite table offset
        tay
        clc
        lda     #$07
        adc     jetXVelocityMatrix,y	; Each jet sprite has a row in spriteGeometry
        jsr     jumpPosToScreenspace

updateJetOffscreen:
		ldx     ZP_CURR_ENTITY
        clc
        lda     ENTITY_Y,x
        adc     ZP_SCRATCH70
        sta     ENTITY_Y,x
        clc
        lda     ENTITY_GROUND,x
        adc     ZP_SCRATCH71
        sta     ENTITY_GROUND,x
        lda     ENTITY_DIR,x
        bpl     updateJetFacingRight
        lda     ZP_SCRATCH6F				; Negate velocity vector if facing left
        eor     #$FF
        sta     ZP_SCRATCH6F
        inc     ZP_SCRATCH6F

updateJetFacingRight:
		clc								; Apply X velocity. Jets don't use VX directly, they take
        lda     ENTITY_X_L,x			; actual velocity from the jetYVelocityTables entry.
        adc     ZP_SCRATCH6F
        sta     ENTITY_X_L,x
        bit     ZP_SCRATCH6F
        bmi     updateJetNegV
        lda     ENTITY_X_H,x
        adc     #$00
        sta     ENTITY_X_H,x
        jmp     updateJetShotReady

updateJetNegV:
		lda     ENTITY_X_H,x
        adc     #$FF
        sta     ENTITY_X_H,x

updateJetShotReady:
		lda     ENTITY_VX,x
        beq     updateJetCheckForShot
        bmi     updateJetCheckForShot
        cmp     #$03					; Check actual X velocity for going fast to the right
        bcs     updateJetCheckForShot
        sec
        lda     ENTITY_Y,x				; Compare our altitude to player
        sbc     CHOP_POS_Y
        bmi     updateJetPlayerAbove
        cmp     #$1E
        bcc     updateJetCheckForShot
        jmp     updateJetPlayerBelow

updateJetPlayerAbove:
		inc     ENTITY_Y,x				; Gain altitude to try and catch player
        jmp     updateJetCheckForShot

updateJetPlayerBelow:
		dec     ENTITY_Y,x				; Lose altitude to try and catch player

updateJetCheckForShot:
		ldx     ZP_CURR_ENTITY
        lda     ENTITY_VX,x
        beq     updateJetNegOrZeroV
        bmi     updateJetNegOrZeroV
        cmp     #$03
        bcs     updateJetSlowPosV
        jmp     updateJetNoShot

updateJetSlowPosV:
		jmp     updateJetShotAvailable

updateJetNegOrZeroV:
		lda     ZP_DYING
        bne     updateJetPlayerDying

        lda     ENTITY_X_H,x			; Check for jet entering security zone
        cmp     FENCE_X_H
        bcc     updateJetInBounds

updateJetPlayerDying:					; Player dying or jet out of bounds, so skip ahead
		jmp     updateJetFastClimb

updateJetInBounds:
		lda     ZP_VELX_16_H			; Get absolute value of player's X velocity
        bpl     updateJetPlayerPosVX
        eor     #$FF					; A lazy negate. Interesting! Technically a bug perhaps, but not important
updateJetPlayerPosVX:
		sta     ZP_SCRATCH56

        sec								; Compare X position to player
        lda     ENTITY_X_L,x
        sbc     CHOP_POS_X_L
        sta     ZP_SCRATCH58
        lda     ENTITY_X_H,x
        sbc     CHOP_POS_X_H
        sta     ZP_SCRATCH59
        beq     updateJetPlayerClose
        cmp     #$01
        beq     updateJetPlayerSortaClose
        cmp     #$FE
        beq     updateJetPlayerSortaClose
        cmp     #$FF
        bne     updateJetFastClimb		; Player not close, so bail out of playfield
        lda     ZP_SCRATCH58				; Get absolute distance to player
        eor     #$FF
        sta     ZP_SCRATCH58

updateJetPlayerClose:
		lda     CURR_LEVEL				; If current level *4 is within 152...???
        asl								; Not sure what this little block is doing
        asl
        clc
        adc     #$98
        cmp     ZP_SCRATCH58
        bcs     updateJetCheckSign

updateJetPlayerSortaClose:
		lda     ZP_VELX_16_H			; Check if we're headed the same way as the player
        eor     ENTITY_DIR,x
        bpl     updateJetSameDir		; Both going right or both going left

        lda     ENTITY_VX,x				; If going different directions, then what?
        bmi     updateJetPlayerLeftCross
        lda     ZP_SCRATCH56				; Contains |PlayerVX|
        cmp     #$14
        bcs     updateJetSlowCruise
        jmp     updateJetSameDir

updateJetPlayerLeftCross:
		lda     ZP_SCRATCH56
        cmp     #$0F
        bcs     updateJetMedCruise
        jmp     updateJetSameDir

updateJetCheckSign:
		lda     ENTITY_VX,x				; Not sure what this little block is doing
        bpl     updateJetPlus			; Only attempt if we're going right
        jmp     updateJetMedCruise

updateJetPlus:
		lda     ZP_SCRATCH59			; Contains approx signed X distance to player
        eor     ENTITY_DIR,x
        bpl     updateJetSlowCruise
        lda     ZP_SCRATCH58				; Contains approx absolute X distance to player
        cmp     #$40
        bcs     updateJetSameDir
        lda     ZP_SCRATCH56				; Contains |PlayerVX|
        cmp     #$09
        bcc     updateJetSameDir
        lda     ZP_VELX_16_H
        eor     ENTITY_DIR,x
        bpl     updateJetMedCruise
        jmp     updateJetSlowCruise

updateJetSameDir:
		jmp     updateJetDone

updateJetSlowCruise:					; No shot available, so cruise
		lda     #$00
        sta     ENTITY_VY,x
        lda     #$01
        sta     ENTITY_VX,x
        jmp     updateJetDone

updateJetMedCruise:						; No shot available, so cruise quickly to catch up
		lda     #$00
        sta     ENTITY_VY,x
        lda     #$02
        sta     ENTITY_VX,x
        jmp     updateJetDone

updateJetFastClimb:
		lda     #$04					; Fast climb to get out of play
        sta     ENTITY_VX,x
        lda     #$13
        sta     ENTITY_VY,x
        jmp     updateJetDone

updateJetShotAvailable:					; We have a shot- decide between missile and bomb
		lda     ENTITY_VY,x
        bne     updateJetSetClimb
        lda     ENTITY_VX,x
        cmp     #$03
        bne     updateJetBombsAway
        jsr     fireJetMissiles
        jmp     updateJetSetClimb

updateJetBombsAway:						; We have a bomb shot, so take it
		jsr     dropJetBomb

updateJetSetClimb:  
		ldx     ZP_CURR_ENTITY
        lda     ENTITY_VY,x
        clc
        adc     #$01
        ldy     ENTITY_VX,x
        cmp     jetClimbTable,y
        beq     updateJetOutOfPlay
        sta     ENTITY_VY,x
        jmp     updateJetDone

updateJetOutOfPlay:
		bit     ZP_SCRATCH67
        bpl     updateJetOutOfPlay2
        jsr     removeCurrentJet
        jsr     jumpDeallocEntity
        rts

updateJetOutOfPlay2:
		jmp     updateJetDone

updateJetNoShot:					; We don't have a shot, so do some swooping
		inc     ENTITY_VY,x
        ldy     ENTITY_VX,x
        lda     jetClimbTable,y
        cmp     ENTITY_VY,x
        beq     updateJetBankCheck
        jmp     updateJetDone

updateJetBankCheck:
		ldx     ZP_CURR_ENTITY
        lda     ENTITY_VX,x
        cmp     #$01
        bne     updateJetLevelOff

        lda     ENTITY_DIR,x		; Do a bank turn by flipping direction
        eor     #$FF
        sta     ENTITY_DIR,x

updateJetLevelOff:
		lda     #$00
        sta     ENTITY_VY,x			; Level off our flight
        lda     ZP_AIRBORNE
        beq     updateJetPlayerGrounded
        lda     #$03
        sta     ENTITY_VX,x			; Cruise, if nothing else
        jmp     updateJetDone

updateJetPlayerGrounded:
		lda     #$04
        sta     ENTITY_VX,x

updateJetDone:
		rts


; A table of values looked up from jet X velocity. It maps our velocity
; to a row in the master spriteGeometry chart for the jet sprite used for
; every possible X velocity. This is how they do the cool swooping turns.
jetXVelocityMatrix:		; $823a
	.byte	$00,$FF,$FF,$FF,$FF,$FF,$FF,$FF
	.byte	$01,$01,$02,$02,$02,$03,$03,$FF
	.byte	$01,$02,$03,$04,$04,$FF,$FF,$FF
	.byte	$04,$03,$02,$02,$01,$01,$FF,$FF
	.byte	$04,$03,$02,$02,$01,$01,$FF,$FF


jetXVelocityTable:		; $8262 A lookup table of other tables based on X velocity of jets
	.word	$6c00,$6c04,$6c4c,$6c88,$6c88		; Pointers to jetYVelocityTables
	

jetSpriteTable:			; $826c Pointers into jetMasterSpriteTable to get jet sprites mapped from velocity
	.word	$a032,$a034,$a042,$a04c,$a058



; Main entity update routine for the helicopter
updateChopper:		; $8276
		ldx     ZP_CURR_ENTITY			; Update state in the entity table for the chopper
        lda     CHOP_POS_X_L
        sta     ENTITY_X_L,x
        lda     CHOP_POS_X_H
        sta     ENTITY_X_H,x
        sec
        lda     CHOP_POS_Y
        sbc     ZP_SINK_Y				; Apply death sinking to height if needed
        sta     ENTITY_Y,x
        lda     CHOP_GROUND
        sta     ENTITY_GROUND,x

        jsr     jumpChooseChopperSprite	; Render the chopper
        jsr     jumpRenderMainRotor
        jsr     jumpRenderTailRotor

        ldx     #$00		; Zero-out render offsets since rotor rendering messes them up
        ldy     #$00
        lda     #$00
        jsr     jumpSetRenderOffset
        lda     #$00
        jsr     jumpPosToScreenspace

        bit     ZP_BTN0DOWN				; Check for fire button
        bpl     updateChopperNoShoot

        lda     #$00					; We're shooting!
        sta     ZP_BTN0DOWN				; Clear button state
        inc     CURR_SHOTS				; One new shot in the air

        jsr     jumpCalculateChopperFront	; Find front of chopper
        clc							; Offset further from there for a nice bullet spot
        txa
        adc     #$03
        tax
        clc
        tya
        adc     #$01
        tay
        lda     #$02
        jsr     jumpSetRenderOffset	; Configure the rendering offsets

        jsr     jumpSetWorldspace		; Prepare to draw the bullet
				.word $001c				; Pointer to animation data

		jsr     jumpSetSpriteAnimPtr
				.word $a07c				; Pointer to muzzle flash sprite

        lda		#$FF					; Render starting bullet
        jsr     jumpSetPalette
        jsr     jumpClipToScroll
        jsr     jumpRenderSprite

        jsr     jumpAllocateEntity		; Allocate the new bullet
        ldx     ZP_CURR_ENTITY
        lda     #$06
        sta     ENTITY_TYPE,x

        jsr     jumpCalculateChopperFront	; Calculate starting position
        inx									; X, Page, Y, and Ground
        stx     ZP_SCRATCH6F

        ldx     ZP_CURR_ENTITY
        sec									; Add chopper X pos to calculated offset
        lda     CHOP_POS_X_L
        sbc     ZP_SCRATCH6F
        sta     ENTITY_X_L,x

        lda     CHOP_POS_X_H				; Compute page we're headed for based on direction
        bit     ZP_SCRATCH6F
        bmi     bulletLeft
        sbc     #$00
        sta     ENTITY_X_H,x
        jmp     bulletYPos
bulletLeft:
		sbc     #$FF
        sta     ENTITY_X_H,x

bulletYPos:
		clc
        tya								; Add chopper Y pos to calculated offset
        adc     CHOP_POS_Y
        sta     ENTITY_Y,x
        lda     CHOP_GROUND
        sta     ENTITY_GROUND,x

        jsr     jumpInitBulletPhysics	; Set up velocity and gravity for bullet
        jsr     jumpDepthSortEntity		; Added our new bullet to the entity list, and we're done

updateChopperNoShoot:
		lda     ZP_DYING
        bne     updateChopperDeathAnimation
        jmp     updateChopperDone

updateChopperDeathAnimation:			; Update our crash and sinking into the ground, if needed
		lda     ZP_AIRBORNE
        beq     updateChopperBeginCrash
        jsr     jumpRandomNumber		; Play random explosion frames
        and     #$03
        asl
        tax
        lda     explosionSpriteTable,x		; Set up all the usual rendering stuff
        sta     ZP_SPRITE_PTR_L
        lda     explosionSpriteTable+1,x
        sta     ZP_SPRITE_PTR_H

        jsr     jumpSetSpriteAnimPtr
				.word $001a

		ldy     #$00						; Set up rendering offsets
        lda     (ZP_SPRITE_PTR_L),y
        lsr
        tax
        ldy     #$01
        lda     (ZP_SPRITE_PTR_L),y
        lsr
        tay
        lda     #$01
        jsr     jumpSetRenderOffset
        jsr     jumpSetWorldspace
				.word $001c

		lda     #$FF
        jsr     jumpSetPalette
        jsr     jumpClipToScroll

        jsr     jumpPlayStaticNoise			; Play the rumbling/burning sound
        jsr     jumpRenderSprite			; ... while we render fire
        jsr     jumpPlayStaticNoise
        jmp     updateChopperDone

updateChopperBeginCrash:					; Chopper is just about to crash
		jsr     jumpAllocateEntity			; The crashing chopper is a new entity
        ldx     ZP_CURR_ENTITY
        sec
        lda     CHOP_POS_X_L					; Position it where the chopper hit
        sbc     #$08
        sta     ENTITY_X_L,x
        lda     CHOP_POS_X_H
        sbc     #$00
        sta     ENTITY_X_H,x

        jsr     jumpRandomNumber			; Offset randomly a little
        and     #$0F
        ldx     ZP_CURR_ENTITY
        clc
        adc     ENTITY_X_L,x
        sta     ENTITY_X_L,x
        lda     ENTITY_X_H,x
        adc     #$00
        sta     ENTITY_X_H,x
        lda     #$00
        sta     ENTITY_Y,x					; Place on ground, of course
        lda     CHOP_GROUND
        sta     ENTITY_GROUND,x
        jsr     initExplosion

        ldx     ZP_CURR_ENTITY				; Give it the sinking effect
        lda     #$04
        sta     ENTITY_VY,x
        jsr     jumpDepthSortEntity			; Insert into the list and we're done

updateChopperDone:
		jsr     jumpChopperPhysics			; Move switch from Magic to More Magic
        rts



; Entity update routine for chopper being shot down and falling from sky
crashingChopper:	; $83a7
        jsr     jumpPlayStaticNoise			; Play sound while we fall

        ldx     ZP_CURR_ENTITY			; Look up next animation frame
        lda     ENTITY_VX,x
        asl
        tay
        lda     explosionSpriteTable,y
        sta     ZP_SPRITE_PTR_L
        lda     explosionSpriteTable+1,y
        sta     ZP_SPRITE_PTR_H

        jsr     jumpSetSpriteAnimPtr	; Prepare to render it
				.word $001a
        
        lda     ENTITY_VX,x
        cmp     #$02
        bcs     crashingChopperRender
        jsr     jumpPlayStaticNoise		; Keep sound going

crashingChopperRender:
		ldy     #$00					; Set up rendering offsets
        lda     (ZP_SPRITE_PTR_L),y
        lsr
        tax
        ldy     #$01
        lda     (ZP_SPRITE_PTR_L),y
        lsr
        tay
        lda     #$01
        jsr     jumpSetRenderOffset

        jsr     jumpSetWorldspace
				.word $001c
        
        lda     #$FF
        jsr     jumpSetPalette
        jsr     jumpClipToScroll

        bcs     crashingChopperOffscreen
        lda     #$05
        jsr     jumpPosToScreenspace
        jsr     jumpRenderSprite			; Render the explosion

crashingChopperOffscreen:
		jsr     jumpPlayStaticNoise			; Keep sound going
        ldx     ZP_CURR_ENTITY
        lda     ENTITY_VX,x
        clc
        adc     #$01
        cmp     #$05						; Five frames and we're done
        beq     crashingChopper1
        sta     ENTITY_VX,x
        rts

crashingChopper1:
		jsr		jumpDeallocEntity			; Explosion is done
		rts



; Entity update routine for the chopper smoldering into the ground
sinkingChopper:		; $8409
        jsr     jumpPlayStaticNoise		; Play smoldering noise

        ldx     ZP_CURR_ENTITY			; Look up next animation frame
        lda     ENTITY_VX,x
        cmp     #$03
        bcs     sinkingChopperOffscreen

        lda     chopperRubbleSprite		; After first three frames, animation changes
        sta     ZP_SPRITE_PTR_L
        lda     chopperRubbleSprite+1
        sta     ZP_SPRITE_PTR_H

        jsr     jumpSetSpriteAnimPtr
				.word $001a

		ldy     #$00					; Set up render offsets	$8424
        lda     (ZP_SPRITE_PTR_L),y
        lsr
        tax
        ldy     #$01
        lda     (ZP_SPRITE_PTR_L),y
        lsr
        clc
        adc     #$04
        tay
        lda     #$01
        jsr     jumpSetRenderOffset
        jsr     jumpSetWorldspace
				.word $001c
        
        lda     #$FF					; $843d
        jsr     jumpSetPalette
        jsr     jumpClipToScroll
        bcs     sinkingChopperOffscreen
        jsr     jumpRenderSprite

sinkingChopperOffscreen:
		ldx     ZP_CURR_ENTITY			; Prepare to render normal explosion
        lda     ENTITY_VX,x
        asl
        tay
        lda     explosionSpriteTable,y
        sta     ZP_SPRITE_PTR_L
        lda     explosionSpriteTable+1,y
        sta     ZP_SPRITE_PTR_H

        jsr     jumpSetSpriteAnimPtr
				.word $001a
        
        lda     ENTITY_VX,x				; $8460
        cmp     #$02
        bcs     sinkingChopperNormalSoundPace
        jsr     jumpPlayStaticNoise		; Keep sound playing

sinkingChopperNormalSoundPace:
		ldy     #$00					; Set render offsets
        lda     (ZP_SPRITE_PTR_L),y
        lsr
        tax
        ldy     #$01
        lda     (ZP_SPRITE_PTR_L),y
        lsr
        clc
        adc     #$04
        tay
        lda     #$01
        jsr     jumpSetRenderOffset	; $847b
        jsr     jumpSetWorldspace
				.word $001c
        
        jsr     jumpClipToScroll		; $8483
        bcs     sinkingChopperOffscreen2

        lda     #$05
        jsr     jumpPosToScreenspace
        jsr     jumpRenderSpriteRight		; Render the frame

sinkingChopperOffscreen2:						; $8490
		jsr		jumpPlayStaticNoise			; Keep sound going

		ldx     ZP_CURR_ENTITY
        lda     ENTITY_VX,x					; $8495
		clc
		adc		#$01
		cmp		#$05
		beq		sinkingChopperDealloc		; When we've drifted far enough, we're done
		sta		ENTITY_VX,x
		rts

sinkingChopperDealloc:
		jsr		jumpDeallocEntity
		rts



; Main entity update routine for chopper-fired bullets and bombs
updateBullet:			; $84a7
		ldx     #$01				; Prepare to render
        ldy     #$01
        lda     #$00
        jsr     jumpSetRenderOffset
        
		jsr     jumpSetWorldspace
				.word $001c

		jsr     jumpSetSpriteAnimPtr
				.word $a074			; Pointer to bullet sprite
       
		jsr     jumpClipToScroll				; $84ba
        bcs     updateBulletOffscreen
        lda     #$0E
        jsr     jumpPosToScreenspace
        jsr     jumpRenderSpriteRight		; Render the bullet

updateBulletOffscreen:
		ldx     ZP_CURR_ENTITY
        lda     ENTITY_DIR,x
        beq     updateBulletDoPhysics
        lda     #$02						; Add gravity for bombs

updateBulletDoPhysics:
		jsr     updateBasicPhysics			; Bullets are simple enough to use standard physics

        ldx     ZP_CURR_ENTITY
        lda     ENTITY_X_H,x
        sbc     CHOP_POS_X_H				; Check that we're still within the playfield
        cmp     #$02
        bcc     updateBulletInBounds
        cmp     #$FF
        beq     updateBulletInBounds
        jmp     updateBulletDone

updateBulletInBounds:
		lda     ENTITY_GROUND,x				; Check for if we're hitting the ground
        bmi     updateBulletClampGround
        cmp     #$03
        bcs     updateBulletCheckY
updateBulletClampGround:
		lda     #$03						; Clamp us to ground level, in case physics pushed us too deep
        sta     ENTITY_GROUND,x
updateBulletCheckY:
		lda     ENTITY_Y,x
        cmp     #$E0
        bcs     updateBulletGroundCheck
        cmp     #$04
        bcc     updateBulletGroundCheck
        cmp     #$90
        bcs     updateBulletDone
        jsr   	checkBullet					; Check for hits on all possible enemies
        rts

updateBulletGroundCheck:
		lda     ENTITY_GROUND,x
        cmp     #$03
        beq     updateBulletDone
        lda     #$00					; We hit ground, so go boom
        sta     ENTITY_Y,x
        jsr     initExplosion			; Convert us into an explosion
        jsr     jumpUpdateEntityList
        jsr     ordinanceCollisionCheck	; Check if we actually hit something!
        dec     CURR_SHOTS
        rts

updateBulletDone:						; We're out of play so remove us
		jsr     jumpDeallocEntity
        dec     CURR_SHOTS
        rts




; Main entity update routine for jet-fired bombs
updateJetBomb:			; $8526
		ldx     #$04				; Prepare to render
		ldy     #$00
        lda     #$00
        jsr     jumpSetRenderOffset

        jsr     jumpSetWorldspace
				.word $001c
        
		jsr     jumpSetSpriteAnimPtr
				.word $a07a			; Jet bomb sprite
        
		jsr 	jumpClipToScroll

		bcs     updateJetBombOffscreen
        lda     #$10
        jsr     jumpPosToScreenspace
        jsr     jumpRenderSpriteRight

updateJetBombOffscreen:
		lda     #$04
        jsr     updateBasicPhysics		; Bombs use a basic falling integration
        ldx     ZP_CURR_ENTITY

        lda     ENTITY_Y,x				; Watch for us to hit the ground
        cmp     #$A0
        bcs     updateJetBombHitGround
        rts

updateJetBombHitGround:
		lda     #$00					; Snap to ground in case physics overshot
        sta     ENTITY_Y,x
        jsr     initExplosion			; Create explosion where we land
        jsr     ordinanceCollisionCheck	; Figure out if we hit anything!
        rts


 

; Main entity update routine for jet-fired missiles
updateMissile: 		; $8561
		ldx     #$04					; Prepare to render
        ldy     #$01
        lda     #$01
        jsr     jumpSetRenderOffset

        jsr     jumpSetWorldspace
				.word $001c

		jsr     jumpSetSpriteAnimPtr
				.word $a078				; Jet missile sprite
        
		jsr     jumpClipToScroll

        bcs     updateMissileOffscreen
        lda     #$0F
        jsr     jumpPosToScreenspace

        ldx     ZP_CURR_ENTITY
        lda     ENTITY_VX,x
        bmi     updateMissileGoingLeft
        jsr     jumpRenderSpriteRight
        jmp     updateMissileOffscreen

updateMissileGoingLeft:
		jsr     jumpRenderSpriteLeft

updateMissileOffscreen:
		lda     #$01
        jsr     updateBasicPhysics

        ldx     ZP_CURR_ENTITY
        lda     ENTITY_Y,x
        cmp     #$A0
        bcs     updateMissileHitGround		; Actually went too high, but treated the same
        cmp     #$03
        bcc     updateMissileHitGround
        jsr     checkChopperHit
        rts

updateMissileHitGround:
		lda     #$00
        sta     ENTITY_Y,x
        jsr     initExplosion
        jsr     ordinanceCollisionCheck
        rts



; Main entity update routine for tank-fired shells
updateTankShell:			; $85b0
		ldx     #$00						; Prepare to render
        ldy     #$00
        lda     #$00
        jsr     jumpSetRenderOffset

        jsr     jumpSetWorldspace
				.word $001c
        
        jsr     jumpSetSpriteAnimPtr
				.word $a076					; Pointer to tank shell sprite
        
		jsr     jumpClipToScroll
        bcs     updateTankShellOffscreen
        lda     #$0D
        jsr     jumpPosToScreenspace
        jsr     jumpRenderSpriteRight		; Render the shell

updateTankShellOffscreen:
		lda     #$03
        jsr     updateBasicPhysics			; Tank shells use the simple gravity physics
        ldx     ZP_CURR_ENTITY
        lda     ENTITY_Y,x					; Check for shell hitting the ground
        beq     updateTankShellCheckHit
        bmi     updateTankShellCheckHit
        rts									; Shell still airborne, so we're done

updateTankShellCheckHit:					; We may have hit something
		lda     #$00
        sta     ENTITY_Y,x					; Clamp to ground in case physics over shot
        lda     CHOP_GROUND
        sta     ENTITY_GROUND,x				; Snap to chopper ground plane
        jsr     initExplosion				; Convert us to explosion for hitting ground
        jsr     jumpUpdateEntityList
        jsr     ordinanceCollisionCheck		; See if we actually hit anything
        rts




; Does very basic physical state updating of current entity.
; Very simple entities like bullets and falling wreckage use this.
; A = Desired gravity
updateBasicPhysics:			; $85f3
        sta     updateBasicPhysicsGravity
        ldx     ZP_CURR_ENTITY
        clc
        lda     ENTITY_X_L,x
        adc     ENTITY_VX,x
        sta     ENTITY_X_L,x
        lda     ENTITY_X_H,x
        ldy     ENTITY_VX,x
        bmi     updateBasicPhysicsNeg
        adc     #$00
        jmp     updateBasicPhysicsStore
updateBasicPhysicsNeg:
		adc     #$FF
updateBasicPhysicsStore:
		sta     ENTITY_X_H,x
        clc
        lda     ENTITY_Y,x			; Add Y velocity to Y pos
        adc     ENTITY_VY,x
        sta     ENTITY_Y,x
        clc
        lda     ENTITY_GROUND,x		; Add gravity to ground level
        adc     ENTITY_DIR,x
        sta     ENTITY_GROUND,x
        sec
        lda     ENTITY_VY,x			; Apply desired gravity to VY
        sbc     updateBasicPhysicsGravity
        sta     ENTITY_VY,x
        rts

updateBasicPhysicsGravity:	; $8633
		.byte $00



; Initializes a new explosion entity
initExplosion:			; $8634
        ldx     ZP_CURR_ENTITY
        lda     #$00
        sta     ENTITY_VX,x
        sta     ENTITY_VY,x
        lda     ENTITY_Y,x
        beq     initExplosionChopper
        lda     #$01		; Normal enemy explosion
        sta     ENTITY_TYPE,x
        jmp     initExplosionDone
initExplosionChopper:
		lda     #$02		; Sinking and dramatic chopper explosion
        sta     ENTITY_TYPE,x
initExplosionDone:
		rts



; The main game entity update routine. It uses a table of vectors to determine
; how to update each entity in the main entity list.
updateEntities:		; $8651
		ldx     entityTable		; Start at beginning of list
updateEntitiesLoop:
		stx     ZP_CURR_ENTITY		; Cache entity ID
        lda     entityTable,x		; Find pointer to next entity (null-terminated)
        sta     ZP_NEXT_ENTITY		; Cache Next pointer
        lda     ENTITY_TYPE,x		; Find entity type
        asl							; Look up updating routine for that entity in table
        tay
        lda     updateEntitiesTable,y
        sta     updateEntitiesSMC+1
        lda     updateEntitiesTable+1,y
        sta     updateEntitiesSMC+2
updateEntitiesSMC:
		jsr		$8276				; Self modifying code target. Call the update routine for this entity
		ldx		ZP_NEXT_ENTITY		; Advance through linked list to next entity (null-terminated)
        bne     updateEntitiesLoop
        rts

; Lookup table up vectors for update routines of each game object type
updateEntitiesTable:	; $8674
		.word updateChopper		; Helicopter	$8276
		.word crashingChopper	; Chopper explosion falling from sky when shot down	 $83a7
		.word sinkingChopper	; Chopper smoldering into the ground   $8409
		.word jumpUpdateTank	; Tank	 $600f
		.word updateMissile		; Jet missile  $8561
		.word updateJetBomb		; Jet bomb	$8526
		.word updateBullet		; Chopper bullet $84a7
		.word $0000				; This entity type is unused. Maybe an enemy or bullet type Dan gave up on
		.word updateTankShell	; Tank shell $85b0
		.word updateJet			; Jet $8006
		.word updateAlien		; Alien $8c42



; This is a sort of "pre-processor" for chopper bullet collision detection, because chopper bullets
; can hit a lot of things that other ordinance can't. Tank shells can't hit jets or aliens, for example.
; So we check those special targets here, but any possible standard ground target hits are passed to the
; usual ordinance collision tester
checkBullet:		; $868a
		ldx     ZP_CURR_ENTITY			; This is us, and we're a chopper bullet
        lda     ENTITY_GROUND,x
        cmp     CHOP_GROUND				; Not sure what this ground plane check is for- how can our plane be different?
        beq     checkBulletCheckPos
        jmp     checkBulletDone

checkBulletCheckPos:
		lda     ENTITY_Y,x				; Check our Y pos to see if we're close to the ground
        cmp     #$0E
        bcs     checkBulletGroundClose
        sec
        lda     ENTITY_X_L,x			; Check for possibly hitting ground targets
        sbc     FARHOUSE_X_L
        bmi     checkBulletGroundClose
        cmp     #$18
        bcs     checkBulletGroundClose
        sec
        lda     ENTITY_X_H,x
        sbc     FARHOUSE_X_H
        cmp     #$04
        bcs     checkBulletGroundClose
        lda     #$00					; Hit ground within range of targets. Convert us to an explosion and check it
        sta     ENTITY_Y,x
        jsr     initExplosion
        jsr     jumpUpdateEntityList
        jsr     ordinanceCollisionCheck
        dec     CURR_SHOTS
        rts

checkBulletGroundClose:
		ldx     ZP_CURR_ENTITY
        lda     ENTITY_Y,x
        cmp     #$18
        bcc     checkBulletJetsDone
        sta     ZP_SCRATCH70			; Cache Y position of bullet for later

        ldx     NUM_JETS				; Check jets, if we need to
        beq     checkBulletJetsDone
        dex

checkBulletJetsLoop:
		ldy     jetTable,x				; Fetch next active jet entity ID
        sec
        lda     ENTITY_GROUND,y			; Compare its ground plane to chopper
        sbc     CHOP_GROUND
        cmp     #$08
        bcs     checkBulletJetsLoopCont	; Wrong plane, so no hit is possible
        sec
        lda     ZP_SCRATCH70			; Compare Y position of bullet to this jet
        sbc     ENTITY_Y,y				; If we're within +/-9, we may have a hit
        cmp     #$09
        bcc     checkBulletJetPossible
        cmp     #$F8
        bcs     checkBulletJetPossible
checkBulletJetsLoopCont:
		dex
        bpl     checkBulletJetsLoop
        jmp     checkBulletJetsDone

checkBulletJetPossible:					; We have a potential jet hit, so check further
		stx     ZP_SCRATCH56				; Cache jet index here
        ldx     ZP_CURR_ENTITY
        sec
        lda     ENTITY_X_L,x			; Compare jet's X position with ours
        sbc     ENTITY_X_L,y			; Y still contains entity ID of current jet from loop above
        sta     ZP_SCRATCH58
        lda     ENTITY_X_H,x
        sbc     ENTITY_X_H,y
        beq     checkBulletJetCheckRight
        cmp     #$FF
        beq     checkBulletJetCheckLeft
        ldx     ZP_SCRATCH56
        jmp     checkBulletJetsLoopCont	; That's a miss, so try next one

checkBulletJetCheckRight:
		lda     ZP_SCRATCH58
        cmp     #$14
        bcc     checkBulletJetHit
        ldx     ZP_SCRATCH56				; X check failed, so resume jet checking loop
        jmp     checkBulletJetsLoopCont	; That's a miss, so try next one

checkBulletJetCheckLeft:
		lda     ZP_SCRATCH58
        cmp     #$ED
        bcs     checkBulletJetHit
        ldx     ZP_SCRATCH56				; X check failed, so resume jet checking loop
        jmp     checkBulletJetsLoopCont	; That's a miss, so try next one

checkBulletJetHit:  
		jsr     initExplosion			; Gotcha! Convert us to an explosion and process the jet hit
        lda     ZP_SCRATCH56
        jsr     destroyJet
        dec     CURR_SHOTS
        jmp     checkBulletDone

checkBulletJetsDone:  
		ldx     ZP_CURR_ENTITY			; Check for hits on aliens, if needed
        lda     ENTITY_Y,x
        sta     ZP_SCRATCH70			; Cache our Y position for later
        ldx     NUM_ALIENS
        beq     checkBulletDone

        dex
checkBulletAlienLoop:
		ldy     alienTable,x			; Fetch entity ID of next alien
        sec
        lda     ZP_SCRATCH70			; Compare our Y position to alien
        sbc     ENTITY_Y,y
        cmp     #$09					; If we're within +/-9, we may have a hit
        bcc     checkBulletAlienPossible
        cmp     #$F8
        bcs     checkBulletAlienPossible
        jmp     checkBulletAlienLoopCont	; That's a miss, so try next one

checkBulletAlienPossible:				; A hit is possible, so now check X
		stx     ZP_SCRATCH56
        ldx     ZP_CURR_ENTITY
        sec
        lda     ENTITY_X_L,x			; Compare alien's X position to ours
        sbc     ENTITY_X_L,y
        sta     ZP_SCRATCH58
        lda     ENTITY_X_H,x
        sbc     ENTITY_X_H,y
        beq     checkBulletAlienCheckRight
        cmp     #$FF
        beq     checkBulletAlienCheckLeft
        ldx     ZP_SCRATCH56
        jmp     checkBulletAlienLoopCont	; That's a miss, so try next one

checkBulletAlienCheckRight:
		lda     ZP_SCRATCH58
        cmp     #$11
        bcc     checkBulletAlienHit
        ldx     ZP_SCRATCH56
        jmp     checkBulletAlienLoopCont	; That's a miss, so try next one

checkBulletAlienCheckLeft:  
		lda     ZP_SCRATCH58
        cmp     #$F0
        bcs     checkBulletAlienHit
        ldx     ZP_SCRATCH56

checkBulletAlienLoopCont:
		dex
        bpl     checkBulletAlienLoop
        jmp     checkBulletDone

checkBulletAlienHit:  					; Alien was hit! Convert us to explosion and process the hit
		jsr     initExplosion
        lda     ZP_SCRATCH56
        jsr     destroyAlien
        dec     CURR_SHOTS

checkBulletDone:
		rts



; Checks to see if the chopper was hit by the current entity. Can
; be called by missiles, aliens, and various things
checkChopperHit:		; $879f
        ldx     ZP_CURR_ENTITY
        sec
        lda     ENTITY_Y,x		; Close to player Y?
        sbc     CHOP_POS_Y
        cmp     #$0A
        bcc     checkChopperHitPlayerCloseY
        cmp     #$F7
        bcs     checkChopperHitPlayerCloseY
        rts						; Nope, we're done

checkChopperHitPlayerCloseY:
		sec
        lda     ENTITY_X_L,x	; Close to player X?
        sbc     CHOP_POS_X_L
        sta     ZP_SCRATCH56
        lda     ENTITY_X_H,x
        sbc     CHOP_POS_X_H
        beq     checkChopperHitPlayerRight
        cmp     #$FF
        beq     checkChopperHitPlayerLeft
        rts

checkChopperHitPlayerRight:
		lda     ZP_SCRATCH56
        cmp     #$0B
        bcc     checkChopperHitExplode
        rts

checkChopperHitPlayerLeft:
		lda     ZP_SCRATCH56
        cmp     #$F6
        bcs     checkChopperHitExplode
        rts

checkChopperHitExplode:			; $87d2
		sec								; Create alien collision explosion just behind player
        lda     CHOP_GROUND
        sbc     #$01
        sta     ENTITY_GROUND,x
        jsr     initExplosion
        jsr     jumpUpdateEntityList
        jsr     chopperHitByOrdinance	; Process the collision as though a bullet hit the player
        rts



; Checks for collisions between alien and player, since normal ordinance check won't detect this.
; Aliens tend to run into stuff on purpose, so this is very necessary
alienCollisionCheck:		; $87e4
		ldx     ZP_CURR_ENTITY
        sec
        lda     ENTITY_Y,x				; Check altitude relative to player
        sbc     CHOP_POS_Y
        cmp     #$08
        bcc     alienCollisionCheckPlayerCloseY
        cmp     #$F9
        bcs     alienCollisionCheckPlayerCloseY
        rts

alienCollisionCheckPlayerCloseY:
		sec
        lda     ENTITY_X_L,x
        sbc     CHOP_POS_X_L
        sta     ZP_SCRATCH56				; Caches low X delta to player
        lda     ENTITY_X_H,x
        sbc     CHOP_POS_X_H
        beq     alienCollisionCheckPlayerCloseLeft
        cmp     #$FF
        beq     alienCollisionCheckPlayerCloseXRight
        rts

alienCollisionCheckPlayerCloseLeft:
		lda     ZP_SCRATCH56
        cmp     #$13
        bcc     alienCollisionCheckHit
        rts

alienCollisionCheckPlayerCloseXRight:
		lda     ZP_SCRATCH56
        cmp     #$EE
        bcs     alienCollisionCheckHit
        rts

alienCollisionCheckHit:					; Gotcha!
		jsr     removeCurrentAlien
        jmp     checkChopperHitExplode	; A tail call into the player collision routine to handle the explosion



; Checks for a collision between ordinance (current entity) and other things that can be killed
ordinanceCollisionCheck:			; $881d
		ldx     ZP_CURR_ENTITY
        lda     ENTITY_X_H,x
        cmp     BASE_X_H
        bcs     ordinanceCollisionCheckDone		; Entity has gone into base area so do nothing

        lda     ENTITY_GROUND,x
        cmp     CHOP_GROUND
        bcs     ordinanceCollisionCheckChopper
        jmp     ordinanceCollisionCheckAllTanks

ordinanceCollisionCheckDone:
		rts

ordinanceCollisionCheckChopper:
		lda     ZP_AIRBORNE
        bne     ordinanceChopperMiss	; Chopper in weird ground state, so can't hit them
        sec
        lda     ENTITY_X_L,x			; Compare our X pos to chopper
        sbc     CHOP_POS_X_L
        sta     ZP_SCRATCH56
        lda     ENTITY_X_H,x
        sbc     CHOP_POS_X_H
        beq     ordinanceCollisionCheckRight
        cmp     #$FF
        beq     ordinanceCollisionCheckLeft
        jmp     ordinanceChopperMiss

ordinanceCollisionCheckRight:			; X position is close. Within 12 pixels right is a hit!
		lda     ZP_SCRATCH56
        cmp     #$0C
        bcs     ordinanceChopperMiss
        jsr     chopperHitByOrdinance	; Gotcha
        jmp     ordinanceChopperMiss

ordinanceCollisionCheckLeft:			; X position is close. Within 11 pixels left is a hit!
		lda     ZP_SCRATCH56
        cmp     #$F5
        bcc     ordinanceChopperMiss
        jsr     chopperHitByOrdinance	; Gotcha

ordinanceChopperMiss:
		lda     MAX_HOSTAGES			; Chopper missed. What about hostages?
        asl
        asl
        tay
ordinanceCollisionHostageLoop:			; Iterate through hostage table and check them all
		tya
        sec
        sbc     #$04
        bmi     ordinanceCollisionCheckHostagesDone
        tay
        lda     hostageTable,y
        bmi     ordinanceCollisionHostageLoop		; Unallocated, so skip
        lda     hostageTable+1,y				; Uncertain what this value is, but it apparently
        cmp     #$02							; Needs to be +/-2 for us to be hit. Ground maybe?
        beq     ordinanceCollisionHostageLoop
        cmp     #$FE
        beq     ordinanceCollisionHostageLoop
        lda     ENTITY_X_L,x					; Check X position against ours
        sbc     hostageTable+2,y
        sta     ZP_SCRATCH56
        lda     ENTITY_X_H,x
        sbc     hostageTable+3,y
        beq     ordinanceCollisionCheckHostageRight
        cmp     #$FF
        beq     ordinanceCollisionCheckHostageLeft
        jmp     ordinanceCollisionHostageLoop

ordinanceCollisionCheckHostageRight:	; X position is close. Within 10 pixels right is a hit!
		lda     ZP_SCRATCH56
        cmp     #$0A
        bcc     ordinanceCollisionCheckHostageKilled		; Gotcha
        jmp     ordinanceCollisionHostageLoop

ordinanceCollisionCheckHostageLeft:		; X position is close. Within 11 pixels left is a hit!
		lda     ZP_SCRATCH56
        cmp     #$F6
        bcs     ordinanceCollisionCheckHostageKilled		; Gotcha
        jmp     ordinanceCollisionHostageLoop

ordinanceCollisionCheckHostageKilled:
		jsr     killHostageWithEntity
        jmp     ordinanceCollisionHostageLoop

ordinanceCollisionCheckHostagesDone:
		sec
        lda     ENTITY_X_L,x					; See if we might hit a house
        sbc     FARHOUSE_X_L
        bmi     ordinanceCollisionCheckDone2
        cmp     #$18
        bcs     ordinanceCollisionCheckDone2
        sec
        lda     ENTITY_X_H,x
        sbc     FARHOUSE_X_H
        cmp     #$03
        bcs     ordinanceCollisionCheckDone2
        jsr     igniteHouse						; Gotcha
ordinanceCollisionCheckDone2:
		rts										; Hitting a house isn't possible, so we're done

ordinanceCollisionCheckAllTanks:
		lda     ENTITY_GROUND,x
        sta     ZP_SCRATCH71						; Cache ground plane of ordinance
        ldx     NUM_TANKS
        bne     ordinanceCollisionTankCheck
        rts										; No active tanks, so we're done

ordinanceCollisionTankCheck:
		dex
ordinanceCheckTankLoopPlane:					; Within plane of tanks?
		ldy     tankTable,x						; Fetch ground plane of this tank from entity table
        sec
        lda     ZP_SCRATCH71
        sbc     ENTITY_GROUND,y
        cmp     #$0A							; Within +/5 of this tank's plane?
        bcc     ordinanceCheckTank
        cmp     #$F5
        bcs     ordinanceCheckTank

ordinanceCheckTankLoopX:						; Any tank plane check that succeeds loops here
		dex										; and checks X for all tanks. They're all in the same plane
        bpl     ordinanceCheckTankLoopPlane		; anyway, so why not. This feels like a late optimization, perhaps
        rts

ordinanceCheckTank:								; Check if we're within X bounds of a tank
        stx     ZP_SCRATCH56
        ldx     ZP_CURR_ENTITY
        sec
        lda     ENTITY_X_L,x
        sbc     ENTITY_X_L,y
        sta     ZP_SCRATCH58
        lda     ENTITY_X_H,x
        sbc     ENTITY_X_H,y
        beq     ordinanceCheckTankRight
        cmp     #$FF
        beq     ordinanceCheckTankLeft
        ldx     ZP_SCRATCH56
        jmp     ordinanceCheckTankLoopX

ordinanceCheckTankRight:
		lda     ZP_SCRATCH58
        cmp     #$0E
        bcc     ordinanceCollisionTankHit
        ldx     ZP_SCRATCH56
        jmp     ordinanceCheckTankLoopX

ordinanceCheckTankLeft:
		lda     ZP_SCRATCH58
        cmp     #$F3
        bcs     ordinanceCollisionTankHit
        ldx     ZP_SCRATCH56
        jmp     ordinanceCheckTankLoopX

ordinanceCollisionTankHit:
		lda     ZP_SCRATCH56
        jsr     destroyTank		; Gotcha
        rts



; The player was hit by a shell, missile, etc! Commence death.
chopperHitByOrdinance:		; $8924
		lda     #$01
        sta     ZP_DYING
        ldx     ZP_CURR_ENTITY
        lda     #$04				; Force missile down after hit
        sta     ENTITY_VY,x
        rts


; Destroys an active tank
; A = Active Tank index to destroy (index into tankTable)
destroyTank:				; $8930
		sta     destroyTankVictim
        ldx     ZP_CURR_ENTITY		; This will be the entity ID of the bullet that killed us
        ldy     destroyTankVictim
        lda     tankTable,y			; Fetch entity ID of victim
        tay
        sec
        lda     ENTITY_X_L,y		; Teleport bullet the last little bit right into us
        sbc     #$03				; I presume this makes the hit feel solid
        sta     ENTITY_X_L,x
        lda     ENTITY_X_H,y
        sbc     #$00
        sta     ENTITY_X_H,x
        clc
        lda     ENTITY_X_L,y
        adc     #$03
        sta     ENTITY_X_L,y
        lda     ENTITY_X_H,y
        adc     #$00
        sta     ENTITY_X_H,y
        lda     #$00
        sta     ENTITY_Y,x
        sta     ENTITY_Y,y
        lda     ENTITY_GROUND,y
        sta     ENTITY_GROUND,x
        lda     #$01
        sta     ENTITY_VY,x

        sty     ZP_CURR_ENTITY		; Convert us into an explosion entity
        jsr     initExplosion
        jsr     jumpUpdateEntityList
        ldy     ZP_CURR_ENTITY
        lda     #$01
        sta     ENTITY_VY,y

        dec     NUM_TANKS			; One less tank in the world
        ldy     destroyTankVictim
        lda     tankTable,y
        jmp     removeTankFromTable

destroyTankVictim:			; Caches index of tank being killed
		.byte	$00

removeCurrentTank:					; $898d  A jump table elsewhere jumps into here as a hacky convenience
        dec     NUM_TANKS
        lda     ZP_CURR_ENTITY



; Removes a tank from the tank table and compacts it down to prevent holes
; A = Entity ID of tank to remove
removeTankFromTable:				; $8992
		cmp     tankTable
        beq     removeTankFromTable1
        cmp     tankTable+1
        beq     removeTankFromTable2
        cmp     tankTable+2
        beq     removeTankFromTable3
        jmp     removeTankFromTableDone
removeTankFromTable1:
		lda     tankTable+1
        sta     tankTable
removeTankFromTable2:  
		lda     tankTable+2
        sta     tankTable+1
removeTankFromTable3:
		lda     tankTable+3
        sta     tankTable+2
removeTankFromTableDone:
		rts


; Removes current entity from game, assuming it is an alien
removeCurrentAlien:				; $89b7  Code elsewhere jumps into here as a hacky convenience.
		dec     NUM_ALIENS
		lda     ZP_CURR_ENTITY	; Fall through


; Removes an alien from the alien table and compacts it down to prevent holes
; A = Entity ID of alien to remove
removeAlienFromTable:			; $89bc
		cmp     alienTable
        beq     removeAlienFromTable1
        cmp     alienTable+1
        beq     removeAlienFromTable2
        cmp     alienTable+2
        beq     removeAlienFromTable3
        jmp     removeAlienFromTable4
removeAlienFromTable1:
		lda     alienTable+1
        sta     alienTable
removeAlienFromTable2:
		lda     alienTable+2
        sta     alienTable+1
removeAlienFromTable3:
		lda     alienTable+3
        sta     alienTable+2
removeAlienFromTable4:
		rts


; Removes current entity from game, assuming it is a jet
removeCurrentJet:			; $89e1  Code elsewhere jumps into here as a hacky convenience.
		dec		NUM_JETS
		lda     ZP_CURR_ENTITY


; Removes a jet from the jet table and compacts it down to prevent holes
; A = Entity ID of jet to remove
removeJetFromTable:				; $89e6
		cmp     jetTable
        beq     removeJetFromTable1
        cmp     jetTable+1
        beq     removeJetFromTable2
        cmp     jetTable+2
        beq     removeJetFromTable3
        jmp     removeJetFromTableDone
removeJetFromTable1:
		lda     jetTable+1
        sta     jetTable
removeJetFromTable2:
		lda     jetTable+2
        sta     jetTable+1
removeJetFromTable3:
		lda     jetTable+3
        sta     jetTable+2
removeJetFromTableDone:
		rts



; Destroys a jet that has just been hit by a bullet
; A = Index of jet (into jetTable)
destroyJet:			; $8a0b
		sta     destroyJetIndex
        lda     ZP_CURR_ENTITY			; Bullet that hit us
        sta     destroyJetBulletID
        ldy     destroyJetIndex
        lda     jetTable,y				; Fetch the entity ID for the jet
        tay
        lda     ENTITY_X_L,y			; Cache dead jet's current position
        sta     ZP_SCRATCH68
        lda     ENTITY_X_H,y
        sta     ZP_SCRATCH69
        lda     ENTITY_Y,y
        sta     ZP_SCRATCH6A
        lda     CHOP_GROUND
        sta     ENTITY_GROUND,y
        sty     ZP_CURR_ENTITY			; Make dead jet entity current
        jsr     initExplosion			; Convert us to an explosion for the bullet hit
        jsr     jumpUpdateEntityList
        ldy     ZP_CURR_ENTITY
        lda     #$01
        sta     ENTITY_VY,y
        jsr     jumpAllocateEntity		; Create a new entity for the explosion of the jet
        ldx     ZP_CURR_ENTITY
        ldy     destroyJetBulletID
        sec
        lda     ZP_SCRATCH68			; Copy position from the dead jet, with some tweaks
        sbc     #$04
        sta     ENTITY_X_L,x
        lda     ZP_SCRATCH69
        sbc     #$00
        sta     ENTITY_X_H,x
        lda     ZP_SCRATCH6A
        sta     ENTITY_Y,x
        lda     CHOP_GROUND
        sta     ENTITY_GROUND,x
        clc
        lda     ZP_SCRATCH68			; Copy position from the dead jet to the bullet, to make hit look convincing
        adc     #$04
        sta     ENTITY_X_L,y
        lda     ZP_SCRATCH69
        adc     #$00
        sta     ENTITY_X_H,y
        lda     ZP_SCRATCH6A
        sta     ENTITY_Y,y
        lda     CHOP_GROUND
        sta     ENTITY_GROUND,y

        lda     #$01					; Set up the explosion entity we just created
        sta     ENTITY_VX,y
        sta     ENTITY_VY,y
        jsr     initExplosion
        jsr     jumpDepthSortEntity

        ldx     ZP_CURR_ENTITY			; Get the explosion a slightly drifting V, for effect
        lda     #$01
        sta     ENTITY_VX,x
        sta     ENTITY_VY,x
        ldy     ZP_CURR_ENTITY
        dec     NUM_JETS				; Remove the dead jet from the table
        ldy     destroyJetIndex
        lda     jetTable,y
        jmp     removeJetFromTable

destroyJetIndex:		; $8a9d
	.byte 	$00
destroyJetBulletID:	; $8a9e
	.byte	$00


; Destroys an alien that has just been hit by a bullet
; A = Index of alien (into alienTable)
destroyAlien:			; $8a9f
		sta     destroyAlienIndex
        lda     ZP_CURR_ENTITY				; Bullet that hit us
        sta     destroyAlienBulletID
        ldy     destroyAlienIndex
        lda     alienTable,y				; Fetch the entity ID for the alien
        tay
        lda     ENTITY_X_L,y				; Cache dead alien's current position
        sta     ZP_SCRATCH68
        lda     ENTITY_X_H,y
        sta     ZP_SCRATCH69
        lda     ENTITY_Y,y
        sta     ZP_SCRATCH6A
        lda     CHOP_GROUND
        sta     ENTITY_GROUND,y
        sty     ZP_CURR_ENTITY				; Make dead alien entity current
        jsr     initExplosion				; Convert us to an explosion for the bullet hit
        jsr     jumpUpdateEntityList
        ldy     ZP_CURR_ENTITY
        lda     #$02
        sta     ENTITY_VY,y
        jsr     jumpAllocateEntity			; Create a new entity for the explosion of the alien
        ldx     ZP_CURR_ENTITY
        ldy     destroyAlienBulletID
        sec
        lda     ZP_SCRATCH68				; Copy position from the dead alien, with some tweaks
        sbc     #$04
        sta     ENTITY_X_L,x
        lda     ZP_SCRATCH69
        sbc     #$00
        sta     ENTITY_X_H,x
        lda     ZP_SCRATCH6A
        sta     ENTITY_Y,x
        lda     CHOP_GROUND
        sta     ENTITY_GROUND,x
        clc
        lda     ZP_SCRATCH68				; Copy position from the dead alien to the bullet, to make hit look convincing
        adc     #$04
        sta     ENTITY_X_L,y
        lda     ZP_SCRATCH69
        adc     #$00
        sta     ENTITY_X_H,y
        lda     ZP_SCRATCH6A
        sta     ENTITY_Y,y
        lda     CHOP_GROUND
        sta     ENTITY_GROUND,y

        lda     #$01						; Set up the explosion entity we just created
        sta     ENTITY_VX,y
        lda     #$02
        sta     ENTITY_VY,y
        jsr     initExplosion
        jsr     jumpDepthSortEntity

        ldx     ZP_CURR_ENTITY				; Get the explosion a slightly drifting V, for effect
        lda     #$01
        sta     ENTITY_VX,x
        lda     #$02
        sta     ENTITY_VY,x
        ldy     ZP_CURR_ENTITY
        dec     NUM_ALIENS					; Remove the dead alien from the table
        ldy     destroyAlienIndex
        lda     alienTable,y
        jmp     removeAlienFromTable

destroyAlienIndex:		; $8b35
	.byte 	$00
destroyAlienBulletID:	; $8b36
	.byte	$00



; Kills a specific hostage with a specified entity
; Y = Hostage index (into hostageTable)
; X = Entity ID of ordinance or thing that killed them
killHostageWithEntity:		; $8b37
		lda     #$FF
		sta     hostageTable,y
		inc     HOSTAGES_KILLED
		dec     HOSTAGES_ACTIVE
		jsr     jumpIncrementHUDKilled
		lda     #$03
		sta     ENTITY_VY,x
		rts



; Sets a house on fire, releasing all the hostages inside
; A = Index of house to ignite (0=leftmost)
igniteHouse:			; $8b4b
		tax
        lda     houseStates,x
        beq     igniteHouseGo
        rts							; House was already on fure
igniteHouseGo:
		lda     #$01				; Ignite the house
        sta     houseStates,x
        ldx     ZP_CURR_ENTITY		; This will be the bullet that hit us
        lda     #$02
        sta     ENTITY_VY,x			; A visual fudge of unknown exact purpose
        rts



fireJetMissiles:		; $8b5f
		ldx     ZP_CURR_ENTITY			; Save current entity ID (which is the jet)
        stx     jetEntityCache

        lda     ENTITY_X_L,x			; Cache current state of jet for later setup
        sta     ZP_SCRATCH68
        lda     ENTITY_X_H,x
        sta     ZP_SCRATCH69
        lda     ENTITY_Y,x
        sta     ZP_SCRATCH6A
        lda     ENTITY_DIR,x
        sta     ZP_SCRATCH63

        jsr     jumpAllocateEntity			; Allocate entities for the two missiles
        ldy     ZP_CURR_ENTITY				; Missile 1 in X, Missile 2 in Y
        jsr     jumpAllocateEntity
        ldx     ZP_CURR_ENTITY

        lda     #$04						; Set types to jet missile
        sta     ENTITY_TYPE,x
        sta     ENTITY_TYPE,y

        lda     ZP_SCRATCH68				; Copy X position from jet
        sta     ENTITY_X_L,x
        sta     ENTITY_X_L,y
        lda     ZP_SCRATCH69
        sta     ENTITY_X_H,x
        sta     ENTITY_X_H,y

        clc
        lda     ZP_SCRATCH6A				; Place missiles slightly above us
        adc     #$08						; and one above the other
        sta     ENTITY_Y,x
        sec
        lda     ZP_SCRATCH6A
        sbc     #$09
        sta     ENTITY_Y,y

        lda     CHOP_GROUND					; Missiles go in same plane as player
        sta     ENTITY_GROUND,x
        sta     ENTITY_GROUND,y

        lda     #$18						; Determine VX from jet direction
        bit     ZP_SCRATCH63
        bpl     fireJetMissilesRight
        eor     #$FF						; Negate VX to face left
        clc
        adc     #$01

fireJetMissilesRight:
		sta     ENTITY_VX,x
        sta     ENTITY_VX,y

        lda     #$00						; Missiles fire straight
        sta     ENTITY_VY,x
        sta     ENTITY_VY,y
        sta     ENTITY_DIR,x
        sta     ENTITY_DIR,y

        stx     jetEntityCache+1			; Cache one missile ID for a moment
        sty     ZP_CURR_ENTITY				; ...so we can depth sort the two missiles
        jsr     jumpDepthSortEntity
        lda     jetEntityCache+1
        sta     ZP_CURR_ENTITY
        jsr     jumpDepthSortEntity

        lda     jetEntityCache				; Restore jet ID for caller
        sta     ZP_CURR_ENTITY

        ldx     #$20						; Play missile launch sound
        ldy     #$20
        lda     #$01
        jsr     jumpPlayShellSound
        rts


jetEntityCache:		; $8bf0
	.byte	$00,$00



dropJetBomb:		; $8bf2
		ldy     ZP_CURR_ENTITY
        sty     jetEntityCache			; Cache current entity (which is the jet)
        jsr     jumpAllocateEntity		; Allocate new entity for the bomb
        ldx     ZP_CURR_ENTITY
        lda     #$05					; Set type to jet bomb
        sta     ENTITY_TYPE,x
        ldy     jetEntityCache			; Copy X position from the jet
        lda     ENTITY_X_L,y
        sta     ENTITY_X_L,x
        lda     ENTITY_X_H,y
        sta     ENTITY_X_H,x

        sec
        lda     ENTITY_Y,y				; Place us slightly below the jet
        sbc     #$01
        sta     ENTITY_Y,x

        lda     CHOP_GROUND				; Put us in the player's plane
        sta     ENTITY_GROUND,x

        lda     ENTITY_DIR,y			; Give us initial VX based on jet facing
        sta     ZP_SCRATCH63
        lda     #$14
        bit     ZP_SCRATCH63
        bpl     dropJetBombRight
        eor     #$FF					; Facing left, so negate VX
        clc
        adc     #$01
dropJetBombRight:
		sta     ENTITY_VX,x
        lda     #$00
        sta     ENTITY_VY,x				; Let gravity take over
        sta     ENTITY_DIR,x
        jsr     jumpDepthSortEntity
        lda     jetEntityCache		; Restore current entity so jet code can resume
        sta     ZP_CURR_ENTITY
        rts


; Main entity update routine for aliens
updateAlien:		; $8c42
		lda     #$00
        sta     alienStillAnimating

        ldx     #$06					; Prepare to render
        ldy     #$07
        lda     #$01
        jsr     jumpSetRenderOffset
        jsr     jumpSetWorldspace
				.word $001c
        
        jsr     jumpSetSpriteAnimPtr
				.word $a07e				; Saucer body sprite
        
		jsr     jumpClipToScroll
        bcs     updateAlienChasePlayer

        lda     #$19
        jsr     jumpPosToScreenspace
        lda     #$FF
        jsr     jumpSetPalette
        jsr     jumpRenderSprite		; Draw the alien body

        lda     #$FF
        sta     alienStillAnimating

        bit     ALIEN_ODDFRAME			; Check even or odd frame for sound
        bmi     updateAlienOddFrame

        lda     #$FF
        sta     ALIEN_ODDFRAME			; Flip the frame state

        ldx     ZP_CURR_ENTITY
        lda     ENTITY_DIR,x			; Frequency of alien sound is derived from animation frame of mid-section
        asl
        asl
        ora     #$01
        tax
        ldy     #$05
        lda     #$00
        jsr     jumpPlaySound			; Play crackly alien noise

updateAlienOddFrame:
		sec								; Set the vertical offset for the sliding mid-section of the saucer
        lda     ZP_RENDERPOS_Y
        sbc     #$06
        sta     ZP_RENDERPOS_Y
        inc     ZP_RENDERPOS_XL
        bne     updateAlienAnimateMid
        inc     ZP_RENDERPOS_XH

updateAlienAnimateMid:
		jsr     jumpSetWorldspace
				.word	$001c

		ldx     ZP_CURR_ENTITY
        inc     ENTITY_DIR,x			; In the alien, the DIR field is used for mid-section animation frame
        lda     ENTITY_DIR,x
        cmp     #$03					; Loops over three frames, so wrap if needed
        bcc     updateAlienRenderMidSection
        lda     #$00
        sta     ENTITY_DIR,x

updateAlienRenderMidSection:
		asl								; Convert mid-section frame counter to sprite pointer
        tax
        lda     alienSpriteTable+2,x
        sta     ZP_SPRITE_PTR_L
        lda     alienSpriteTable+3,x
        sta     ZP_SPRITE_PTR_H
        jsr     jumpSetSpriteAnimPtr
				.word $001a
		jsr     jumpClipToScroll
        bcs     updateAlienChasePlayer
        lda     #$00
        jsr     jumpSetPalette
        jsr     jumpBlitImage

updateAlienChasePlayer:					; Find the player relative to us
		ldx     ZP_CURR_ENTITY
        sec
        lda     CHOP_POS_X_L
        sbc     ENTITY_X_L,x
        sta     ZP_SCRATCH64			; Caches low X pos delta to player
        lda     CHOP_POS_X_H
        sbc     ENTITY_X_H,x
        sta     ZP_SCRATCH65			; Caches high X pos delta to player
        lda     CHOP_POS_Y
        sbc     ENTITY_Y,x
        sta     ZP_SCRATCH66			; Caches Y pos delta to player

        lda     ZP_SCRATCH65			; Is player close horizontally?
        cmp     #$FD
        bcs     updateAlienCloseX
        cmp     #$03
        bcc     updateAlienCloseX

        jsr     removeCurrentAlien		; Too far away on X, so despawn us
        jsr     jumpDeallocEntity
        rts

updateAlienCloseX:
		bit     ZP_SCRATCH65			; Is player left or right of us?
        bmi     updateAlienPlayerLeft

        inc     ENTITY_VX,x				; Accelerate to the right, since player is right
        lda     ENTITY_VX,x
        cmp     #$06					; Clamp VX at 5
        bne     updateAlienHoverCheck
        lda     #$05
        sta     ENTITY_VX,x
        jmp     updateAlienHoverCheck

updateAlienPlayerLeft:					; Accelerate to the left, since player is left
		dec     ENTITY_VX,x
        lda     ENTITY_VX,x
        cmp     #$FA					; Clamp VX at -5
        bne     updateAlienHoverCheck
        lda     #$FB
        sta     ENTITY_VX,x

updateAlienHoverCheck:
		bit     alienStillAnimating
        bmi     updateAlienHoverDone
        lda     #$00					; Level out our flight after each animation cycle
        sta     ENTITY_VY,x				; I think this creates the slight hovering effect,
        jmp     updateAlienPhysics		; so it doesn't just dead-reckon right to us all the time

updateAlienHoverDone:
		bit     ZP_SCRATCH66			; Player above or below us?
        bmi     updateAlienPlayerBelow
        inc     ENTITY_VY,x				; Accelerate upwards since player is above
        lda     ENTITY_VY,x
        cmp     #$02					; Clamp vertical velocity at 1
        bne     updateAlienPhysics
        lda     #$01
        sta     ENTITY_VY,x
        jmp     updateAlienPhysics

updateAlienPlayerBelow:
		dec     ENTITY_VY,x				; Accelerate downwards since player is below
        lda     ENTITY_VY,x
        cmp     #$FE					; Clamp vertical velocity at -1
        bne     updateAlienPhysics
        lda     #$FF
        sta     ENTITY_VY,x

updateAlienPhysics:  
		lda     ENTITY_DIR,x
        sta     alienFrameCache			; Save animation frame so we can...
        lda     #$00					; ...zero out DIR temporarily so we don't mess up physics
        sta     ENTITY_DIR,x
        lda     #$00
        jsr     updateBasicPhysics		; Aliens only need basic physics
        ldx     ZP_CURR_ENTITY
        lda     alienFrameCache			; Restore animation frame
        sta     ENTITY_DIR,x
										
        lda     CURR_LEVEL				; Decide whether to shoot!
        cmp     #$03
        bne     updateAlienNoShot

        lda     ENTITY_DIR,x			; Only fire every third frame
        bne     updateAlienNoShot
        lda     alienStillAnimating
        beq     updateAlienNoShot

        lda     ENTITY_Y,x				; Only fire at lower altitudes
        cmp     #$58
        bcs     updateAlienNoShot
        jsr     jumpRandomNumber		; After all those checks, then choose randomly
        sta     ZP_SCRATCH58
        and     #$48
        bne     updateAlienNoShot

        lda     ZP_CURR_ENTITY			; Take a shot!
        sta     alienEntityCache		; Cache our entity so we can create the bullet
        jsr     jumpAllocateEntity

        ldx     ZP_CURR_ENTITY			; Copy some initial state from us to bullet
        lda     #$08					; Bullet type is 8 (technically tank shell!)
        sta     ENTITY_TYPE,x
        ldy     alienEntityCache

        lda     ENTITY_X_L,y			; Copy X position from us
        sta     ENTITY_X_L,x
        lda     ENTITY_X_H,y
        sta     ENTITY_X_H,x
        clc
        lda     ENTITY_Y,y				; Copy Y position from us, offset by velocity
        adc     ENTITY_VY,y
        sta     ENTITY_Y,x

        lda     CHOP_GROUND				; Set to same plane as player
        sta     ENTITY_GROUND,x
        lda     #$0A
        bit     ZP_SCRATCH58				; Holds random number
        bpl     udpateAlienBulletVX
        eor     #$FF					; Randomly negate VX to spray bullets
        clc
        adc     #$01

udpateAlienBulletVX:
		clc
        adc     ENTITY_VX,y				; Give bullet same VX as us
        sta     ENTITY_VX,x
        lda     #$00
        sta     ENTITY_VY,x				; Bullet has no VY or direction
        sta     ENTITY_DIR,x
        jsr     jumpDepthSortEntity		; Bullet away!

        lda     alienEntityCache		; Back to us as normal entity now
        sta     ZP_CURR_ENTITY
        ldx     #$30
        ldy     #$20
        lda     #$00
        jsr     jumpPlaySound			; Play shooty sound

updateAlienNoShot:
		ldx     ZP_CURR_ENTITY
        lda     ENTITY_Y,x
        cmp     #$A0					; See if we're crashing into things
        bcs     updateAlienCrashCheck
        cmp     #$0A
        bcc     updateAlienCrashCheck
        jsr     alienCollisionCheck
        rts

updateAlienCrashCheck:					; Aliens can kamikaze into things, so check
		lda     #$00					; for hitting stuff if we do
        sta     ENTITY_Y,x
        jsr     removeCurrentAlien
        jsr     initExplosion
        jsr     ordinanceCollisionCheck
        rts

alienFrameCache:		; $8dfe	To save/restore animation frame
		.byte 	$00
alienStillAnimating:	; $8dff	Set to $ff during animation cycle, $00 otherwise
		.byte	$00
alienEntityCache:		; $8e00	To save/restore entity ID
		.byte	$00


.org $8e01


; 511 unused bytes
UNUSED 511


.org $9000		; Rendering-focused jump table
jumpRenderMoon:				jmp     renderMoon				; $9000
jumpRenderStars:			jmp     renderStars				; $9003
jumpRenderHUD:				jmp     renderHUD				; $9006
jumpStartGraphicsDeadCode:	jmp     startGraphicsDeadCode	; $9009
jumpTableScroll:			jmp     scrollTerrain			; $900c
jumpEraseAllSprites:		jmp     eraseAllSprites			; $900f
jumpRenderBase:				jmp     renderBase				; $9012
jumpRenderFence:			jmp     renderFence				; $9015
jumpArithmeticShiftLeft16:	jmp     arithmeticShiftLeft16	; $9018
jumpRenderHouses:			jmp     renderHouses			; $901b
jumpSpawnInitialHostages:	jmp     spawnInitialHostages	; $901e
jumpInitGameState:			jmp     initGameState			; $9021
jumpInitHelicopter:			jmp     initHelicopter			; $9024
jumpRenderStars1:			jmp     renderStars1			; $9027
jumpRenderMoonChunk:		jmp     renderMoonChunk			; $902a



; Renders all the little hostage houses
renderHouses:	; $902d
		sec							; Any houses remotely close to onscreen?
        lda     ZP_SCROLLPOS_H
        sbc     FARHOUSE_X_H
        bmi     renderHousesProbably
        cmp     #$04
        bcc     renderHousesProbably
        rts

renderHousesProbably:
		lda     #$00
        sta     renderHousesIndex
        lda     ZP_SCROLLPOS_L
        and     #$01
        eor     #$01
        eor     FARHOUSE_X_L
        sta     renderHouses_XL
        dec     renderHouses_XL
        lda     FARHOUSE_X_H
        sta     renderHouses_XH
renderHousesLoop:
        sec
        lda     renderHouses_XL
        sbc     #$02
        sta     ZP_RENDERPOS_XL
        lda     renderHouses_XH
        sbc     #$00
        sta     ZP_RENDERPOS_XH
        lda     #$24
        sta     ZP_RENDERPOS_Y

        jsr     jumpSetWorldspace
				.word $001c

		ldx     renderHousesIndex		; Find sprite for normal or burning house
        lda     houseStates,x
        asl
        tax
        lda     houseSpriteTable,x
        sta     ZP_SPRITE_PTR_L
        lda     houseSpriteTable+1,x
        sta     ZP_SPRITE_PTR_H
        jsr     jumpSetSpriteAnimPtr
				.word $001a

		jsr     jumpClipToScroll
        bcs     renderHousesSill
        jsr     jumpBlitAlignedImage	; Render main part of house (intact or destroyed)

renderHousesSill:
		lda     #$19
        sta     ZP_RENDERPOS_Y
        jsr     jumpSetWorldspace
				.word $001c

        jsr		jumpSetSpriteAnimPtr		; $9094
				.word $a0ce					; houseSillSprite

		jsr     jumpClipToScroll
        bcc     renderHousesSillVisible		; If the sill is clipped, don't bother
        jmp     renderHouseNext				; with any other rendering

renderHousesSillVisible:
		lda     #$24
        sta     ZP_RENDERPOS_Y
        lda     #$17
        jsr     jumpPosToScreenspace
        jsr     jumpRenderSpriteRight		; Render the sill

        ldx     renderHousesIndex			; Check if house is on fire
        lda     houseStates,x
        beq     renderHouseNext				; Not on fire, so we're done

        lda     #$1C						; Prepare to render fire
        sta     ZP_RENDERPOS_Y

        clc
        lda     ZP_RENDERPOS_XL
        adc     #$06
        sta     ZP_RENDERPOS_XL
        lda     ZP_RENDERPOS_XH
        adc     #$00
        sta     ZP_RENDERPOS_XH
        jsr     jumpSetWorldspace
				.word $001c

		lda     ZP_FRAME_COUNT				; $90cb Modulus global frame count to pick a fire animation frame
        and     #$01
        bne     renderHousesFireFrame0
        jsr     jumpSetSpriteAnimPtr
				.word $a0d2					; houseFireSprites
		jmp		renderHousesFireFrameSet

renderHousesFireFrame0:
		jsr		jumpSetSpriteAnimPtr		; $90d9
				.word $a0d4					; houseFireSprites+2

renderHousesFireFrameSet:
		jsr     jumpClipToScroll			; $90de
        bcs     renderHouseNext				; Fire is clipped, so we're done

        lda     #$FF
        jsr     jumpSetPalette
        lda     ZP_FRAME_COUNT
        and     #$02						; Every third frame, flip the sprite
        bne     renderHousesFireFlipped		; to create a flickering effect
        jsr     jumpBlitImage				; Render the fire
        jmp     renderHousesFireDone
renderHousesFireFlipped:
		jsr     jumpBlitImageFlip

renderHousesFireDone:
		sec
        lda     ZP_RENDERPOS_Y
        sbc     #$06
        sta     ZP_RENDERPOS_Y
        sec
        lda     ZP_RENDERPOS_XL
        sbc     #$01
        sta     ZP_RENDERPOS_XL
        lda     ZP_RENDERPOS_XH
        sbc     #$00
        sta     ZP_RENDERPOS_XH

        jsr     jumpSetWorldspace
				.word $001c

		jsr		jumpSetSpriteAnimPtr			; $9110
				.word $a0d0					; houseDebrisSprite

		jsr     jumpClipToScroll
        bcs     renderHouseNext
        lda     #$18
        jsr     jumpPosToScreenspace
        jsr     jumpRenderSpriteRight

renderHouseNext:					; Next house
		inc     renderHousesIndex
        lda     renderHousesIndex
        cmp     #$04
        beq     renderHouseDone
        inc     renderHouses_XH
        jmp     renderHousesLoop

renderHouseDone:
		rts


renderHousesIndex:			; Current house being rendered
		.byte	$00			; $9133
renderHouses_XL:			; Current house X position (low byte)
		.byte	$00			; $9134
renderHouses_XH:			; Current house X position (high byte)
		.byte	$00			; $9135



; Renders the security fence near the base
renderFence:		; $9136
        sec								; See if we're roughly visible
        lda     ZP_SCROLLPOS_H
        sbc     FENCE_X_H
        beq     renderFenceOnScreen
        cmp     #$01
        beq     renderFenceOnScreen
        cmp     #$FF
        beq     renderFenceOnScreen
        rts								; No chance that we're onscreen, so skip it

renderFenceOnScreen:
		lda     ZP_SCROLLPOS_L			; Figure out where the fence origin is in screenspace
        and     #$01
        sta     ZP_SCRATCH56
        lda     FENCE_X_L
        and     #$FE
        ora     ZP_SCRATCH56
        sta     ZP_SCRATCH68
        lda     FENCE_X_H
        sta     ZP_SCRATCH69
        sec
        lda     FENCE_X_L
        sbc     ZP_SCROLLPOS_L
        sta     ZP_SCRATCH58
        lda     FENCE_X_H
        sbc     ZP_SCROLLPOS_H
        sta     ZP_SCRATCH59

        sec								; Compute parallax in X position for all the towers
        lda     ZP_SCRATCH58			; This is done with simple bitshifts from the fence origin
        sbc     #$8C
        and     #$FE
        sta     ZP_SCRATCH58
        lda     ZP_SCRATCH59
        sbc     #$00
        sta     ZP_SCRATCH59
        lda     ZP_SCRATCH58
        sta     ZP_SCRATCH16_L
        lda     ZP_SCRATCH59
        sta     ZP_SCRATCH16_H
        ldy     #$01
        jsr     jumpArithmeticShiftRight16

        clc									; Calculate parallax for tower 2
        lda     ZP_SCRATCH16_L
        and     #$FE
        adc     ZP_SCRATCH68
        sta     fenceTower2_X_L
        lda     ZP_SCRATCH16_H
        adc     ZP_SCRATCH69
        sta     fenceTower2_X_H
        ldy     #$01
        jsr     jumpArithmeticShiftRight16

        clc									; Calculate parallax for tower 3
        lda     ZP_SCRATCH16_L
        and     #$FE
        adc     ZP_SCRATCH68
        sta     fenceTower3_X_L
        lda     ZP_SCRATCH16_H
        adc     ZP_SCRATCH69
        sta     fenceTower3_X_H
        ldy     #$01
        jsr     jumpArithmeticShiftRight16

        clc									; Calculate parallax for tower 4
        lda     ZP_SCRATCH16_L
        and     #$FE
        adc     ZP_SCRATCH68
        sta     fenceTower4_X_L
        lda     ZP_SCRATCH16_H
        adc     ZP_SCRATCH69
        sta     fenceTower4_X_H

        clc									; Calculate parallax for tower 1
        lda     ZP_SCRATCH58
        sta     ZP_SCRATCH16_L
        adc     ZP_SCRATCH68
        sta     fenceTower1_X_L
        lda     ZP_SCRATCH59
        sta     ZP_SCRATCH16_H
        adc     ZP_SCRATCH69
        sta     fenceTower1_X_H
        ldy     #$01
        jsr     arithmeticShiftLeft16

        clc									; Render tower 4 (furthestmost)
        lda     ZP_SCRATCH16_L
        adc     ZP_SCRATCH68
        sta     fenceTower0_X_L
        lda     ZP_SCRATCH16_H
        adc     ZP_SCRATCH69
        sta     fenceTower0_X_H				; Calculate parallax for tower 0
        lda     fenceTower4_X_L
        sta     ZP_RENDERPOS_XL
        lda     fenceTower4_X_H
        sta     ZP_RENDERPOS_XH
        lda     fenceTower4_Y
        sta     ZP_RENDERPOS_Y
        jsr     jumpSetWorldspace
				.word $001c
		jsr		jumpSetSpriteAnimPtr		; $91fe
				.word $a0c0					; fenceTowerSprite4

		jsr     jumpClipToScroll
        bcs     renderFenceTower3
        lda     #$16
        jsr     jumpPosToScreenspace
        jsr     jumpRenderSpriteRight

renderFenceTower3:
		lda     fenceTower3_X_L				; Render tower 3
        sta     ZP_RENDERPOS_XL
        lda     fenceTower3_X_H
        sta     ZP_RENDERPOS_XH
        lda     fenceTower3_Y
        sta     ZP_RENDERPOS_Y
        jsr     jumpSetWorldspace
				.word $001c
        jsr		jumpSetSpriteAnimPtr
				.word $a0c2					; fenceTowerSprite3
		jsr     jumpClipToScroll
        bcs     renderFenceTower2
        lda     #$16
        jsr     jumpPosToScreenspace
        jsr     jumpRenderSpriteRight

renderFenceTower2:
		lda     fenceTower2_X_L				; Render tower 2
        sta     ZP_RENDERPOS_XL
        lda     fenceTower2_X_H
        sta     ZP_RENDERPOS_XH
        lda     fenceTower2_Y
        sta     ZP_RENDERPOS_Y
        jsr     jumpSetWorldspace
				.word $001c
        jsr		jumpSetSpriteAnimPtr
				.word $a0c4					; fenceTowerSprite2
		jsr     jumpClipToScroll
        bcs     renderFenceTower1
        lda     #$16
        jsr     jumpPosToScreenspace
        jsr     jumpRenderSpriteRight

renderFenceTower1:
		lda     fenceTower1_X_L				; Render tower 1
        sta     ZP_RENDERPOS_XL
        lda     fenceTower1_X_H
        sta     ZP_RENDERPOS_XH
        lda     fenceTower1_Y
        sta     ZP_RENDERPOS_Y
        jsr     jumpSetWorldspace
				.word $001c
        jsr		jumpSetSpriteAnimPtr
				.word $a0c6					; fenceTowerSprite1
		jsr     jumpClipToScroll
        bcs     renderFenceTower0
        lda     #$16
        jsr     jumpPosToScreenspace
        jsr     jumpRenderSpriteRight

renderFenceTower0:
		lda     fenceTower0_X_L				; Render tower 0
        sta     ZP_RENDERPOS_XL
        lda     fenceTower0_X_H
        sta     ZP_RENDERPOS_XH
        lda     fenceTower0_Y
        sta     ZP_RENDERPOS_Y
        jsr     jumpSetWorldspace
				.word $001c
        jsr		jumpSetSpriteAnimPtr
				.word $a0c8					; fenceTowerSprite0
		jsr		jumpClipToScroll
		bcs		renderFenceDone
		lda		#$16
		jsr		jumpPosToScreenspace
		jsr		jumpRenderSpriteRight

renderFenceDone:
		rts

; Towers are numbered 0 (closest to camera) to 4 (furthest into distance)
; The 16-bit X positions are calculated above during rendering to create parallax
fenceTower4_X_L:		; $92a9
		.byte 	$00
fenceTower4_X_H:		; $92aa
		.byte 	$00
fenceTower3_X_L:		; $92ab
		.byte 	$00
fenceTower3_X_H:		; $92ac
		.byte 	$00
fenceTower2_X_L:		; $92ad
		.byte 	$00
fenceTower2_X_H:		; $92ae
		.byte 	$00
fenceTower1_X_L:		; $92af
		.byte 	$00
fenceTower1_X_H:		; $92b0
		.byte 	$00
fenceTower0_X_L:		; $92b1
		.byte 	$00
fenceTower0_X_H:		; $92b2
		.byte 	$00

; The tower Y positions are fixed at load time because they don't change
fenceTower4_Y:		; $92b3
		.byte 	$1c
fenceTower3_Y:		; $92b4
		.byte 	$1b
fenceTower2_Y:		; $92b5
		.byte 	$19
fenceTower1_Y:		; $92b6
		.byte 	$16
fenceTower0_Y:		; $92b7
		.byte 	$11



; Renders the home base with the little flag and everything.
renderBase:		; $92b8
		sec
        lda     BASE_X_H			; Is base even close to onscreen?
        sbc     ZP_SCROLLPOS_H
        cmp     #$02
        bcc     renderBaseOnscreen
        rts							; Nope, we're done

renderBaseOnscreen:
		lda     BASE_X_L			; Figure out where to render it
        sta     ZP_SCRATCH68
        lda     BASE_X_H
        sta     ZP_SCRATCH69
        lda     ZP_SCROLLPOS_L
        and     #$01
        eor     ZP_SCRATCH68
        sta     ZP_SCRATCH68

        clc							; Draw the square part of the grass
        lda     ZP_SCRATCH68
        adc     #$07
        sta     ZP_RENDERPOS_XL
        lda     ZP_SCRATCH69
        adc     #$00
        sta     ZP_RENDERPOS_XH
        lda     #$19
        sta     ZP_RENDERPOS_Y
        jsr		jumpSetWorldspace
				.word $001c

		jsr		jumpSetImagePtr			; $92eb
				.word $9401				; renderBaseGrassSprite (pseudo-sprite below)

		jsr     jumpClipToScroll		; $92f0
        bcs     renderBaseGrassClipped
        jsr     jumpBlitRect

renderBaseGrassClipped:
		lda     ZP_SCRATCH68			; Prepare to render grass corners
        sta     ZP_RENDERPOS_XL
        lda     ZP_SCRATCH69
        sta     ZP_RENDERPOS_XH
        jsr     jumpSetWorldspace
				.word $001c
		jsr		jumpSetSpriteAnimPtr
				.word $a0b4				; baseGrassCornerSprite
		jsr     jumpClipToScroll
        bcc     renderBaseGrassLeft
        rts

renderBaseGrassLeft:
		lda     #$00					; Render left corner of grass
        jsr     jumpSetPalette
        lda     #$13
        jsr     jumpPosToScreenspace
        jsr     jumpBlitImageFlip

        clc								; Render right corner of grass
        lda     ZP_SCRATCH68
        adc     #$84
        sta     ZP_RENDERPOS_XL
        lda     ZP_SCRATCH69
        adc     #$00
        sta     ZP_RENDERPOS_XH
        jsr     jumpSetWorldspace
				.word $001c
		jsr     jumpClipToScroll
        bcs     renderBaseGrassDone
        jsr     jumpBlitImage

renderBaseGrassDone:  
		clc								; Render the main building
        lda     #$22
        sta     ZP_RENDERPOS_Y
        clc
        lda     ZP_SCRATCH68
        adc     #$49
        sta     ZP_RENDERPOS_XL
        lda     ZP_SCRATCH69
        adc     #$00
        sta     ZP_RENDERPOS_XH
        jsr     jumpSetWorldspace
				.word $001c
		jsr     jumpSetSpriteAnimPtr	; $934e
				.word $a0b2				; baseBuildingSprite
        
		jsr     jumpClipToScroll
        bcs     renderBaseBuildingDone
        lda     #$14
        jsr     jumpPosToScreenspace
        jsr     jumpBlitAlignedImage

renderBaseBuildingDone:
		clc								; Render sidewalk on left edge of base
        lda     ZP_SCRATCH68
        adc     #$3F
        sta     ZP_RENDERPOS_XL
        lda     ZP_SCRATCH69
        adc     #$00
        sta     ZP_RENDERPOS_XH
        lda     #$19
        sta     ZP_RENDERPOS_Y
        jsr     jumpSetWorldspace
				.word $001c
        jsr 	jumpSetSpriteAnimPtr
				.word $a0bc				; baseLeftSidewalkSprite
		jsr     jumpClipToScroll
        bcc     renderBaseSidewalkUnclipped
        rts

renderBaseSidewalkUnclipped:
		jsr     jumpRenderSpriteRight

        clc								; Render sidewalk on right edge of base
        lda     ZP_SCRATCH68
        adc     #$7B
        sta     ZP_RENDERPOS_XL
        lda     ZP_SCRATCH69
        adc     #$00
        sta     ZP_RENDERPOS_XH
        jsr     jumpSetWorldspace
				.word $001c
        
		jsr 	jumpSetSpriteAnimPtr
				.word $a0be				; baseRightSidewalkSprite
		jsr     jumpClipToScroll
        bcs     renderBaseBeginFlag
        jsr     jumpRenderSpriteRight

renderBaseBeginFlag:
		lda     #$2E					; Render the flagpole
        sta     ZP_RENDERPOS_Y
        clc
        lda     ZP_SCRATCH68
        adc     #$71
        sta     ZP_RENDERPOS_XL
        lda     ZP_SCRATCH69
        adc     #$00
        sta     ZP_RENDERPOS_XH
        jsr     jumpSetWorldspace
				.word $001c
        jsr		jumpSetSpriteAnimPtr
				.word $a0b6				; baseFlagpole
		jsr     jumpClipToScroll
        bcc     renderBaseFlagpole
        rts

renderBaseFlagpole:
		lda     #$15
        jsr     jumpPosToScreenspace
        lda     #$FF
        jsr     jumpSetPalette
        jsr     jumpBlitImage

        clc								; Prepare to render flag animation
        lda     ZP_RENDERPOS_XL
        adc     #$02
        sta     ZP_RENDERPOS_XL
        lda     ZP_RENDERPOS_XH
        adc     #$00
        sta     ZP_RENDERPOS_XH
        jsr     jumpSetWorldspace
				.word $001c
        
		lda     ZP_FRAME_COUNT
        and     #$01					; Modulous the global frame counter to get a flag frame
        asl
        tax
        lda     baseFlagSpriteTable,x
        sta     ZP_SPRITE_PTR_L
        lda     baseFlagSpriteTable+1,x
        sta     ZP_SPRITE_PTR_H
        jsr     jumpSetSpriteAnimPtr
				.word $001a

		jsr		jumpClipToScroll		; $93f8
		bcs		renderBaseDone
		jsr		jumpBlitImage

renderBaseDone:
		rts


renderBaseGrassSprite:	; $9401 Pseudo-sprite for the grass under the base. W/H and pixels
		.byte 	$13,$05
		.byte	$2A,$55,$2A,$55



; Renders the lower half (give or take) of the moon. The title animations only cover part
; part of it, so Dan only redraws what's needed. This is a clever stub that jumps into the
; middle of the compiled moon renderer.
renderMoonChunk:				; $9407
		bit     ZP_BUFFER
		bmi		renderMoonChunkBuff1
		jmp		renderMoonChunkBuffer0
renderMoonChunkBuff1:
		jmp		renderMoonChunkBuffer1



; Renders the moon. Sprite compiled! Makes sense in this context, though! There's only one and it always renders
; in the same place, so this is a rare occasion where sprite compiling on the 8-bit Apple II makes perfect sense
renderMoon:			; $9411
		bit     ZP_BUFFER
        bpl     renderMoonBuffer0
        jmp     renderMoonBuffer1
renderMoonBuffer0:
		lda     #$F0
        sta     $20C8
        lda     #$8B
        sta     $20C9
        lda     #$AE
        sta     $24C8
        lda     #$D5
        sta     $24C9
        lda     #$D7
        sta     $28C8
        lda     #$AB
        sta     $28C9
        lda     #$81
        sta     $28CA
        lda     #$C0
        sta     $2CC7
        lda     #$AA
        sta     $2CC8
        lda     #$D5
        sta     $2CC9
        lda     #$82
        sta     $2CCA
        lda     #$E0
        sta     $30C7
        lda     #$DD
        sta     $30C8
        lda     #$EA
        sta     $30C9
        lda     #$85
        sta     $30CA
        lda     #$D0
        sta     $34C7
        lda     #$AE
        sta     $34C8
        lda     #$DD
        sta     $34C9
        lda     #$8B
        sta     $34CA
        lda     #$B0
        sta     $38C7
        lda     #$D7
        sta     $38C8
        lda     #$B6
        sta     $38C9
        lda     #$8D
        sta     $38CA
        lda     #$D8
        sta     $3CC7
        lda     #$FF
        sta     $3CC8
        lda     #$D5
        sta     $3CC9
        lda     #$9B
        sta     $3CCA
        lda     #$B8
        sta     $2147
        lda     #$D9
        sta     $2148
        lda     #$BA
        sta     $2149
        lda     #$95
        sta     $214A
        lda     #$D8
        sta     $2547
        lda     #$BA
        sta     $2548
        lda     #$D5
        sta     $2549
        lda     #$9A
        sta     $254A
        lda     #$B8
        sta     $2947
        lda     #$D7
        sta     $2948
        lda     #$AA
        sta     $2949
        lda     #$97
        sta     $294A
        lda     #$D8
        sta     $2D47
        lda     #$AE
        sta     $2D48
        lda     #$F5
        sta     $2D49
        lda     #$9A
        sta     $2D4A
        lda     #$B0
        sta     $3147
        lda     #$D5
        sta     $3148
        lda     #$FE
        sta     $3149
        lda     #$8D
        sta     $314A
renderMoonChunkBuffer0:
        lda     #$F0
        sta     $3547
        lda     #$AA
        sta     $3548
        lda     #$D7
        sta     $3549
        lda     #$8B
        sta     $354A
        lda     #$A0
        sta     $3947
        lda     #$DD
        sta     $3948
        lda     #$AA
        sta     $3949
        lda     #$85
        sta     $394A
        lda     #$C0
        sta     $3D47
        lda     #$BA
        sta     $3D48
        lda     #$CF
        sta     $3D49
        lda     #$82
        sta     $3D4A
        lda     #$D7
        sta     $21C8
        lda     #$AA
        sta     $21C9
        lda     #$81
        sta     $21CA
        lda     #$AE
        sta     $25C8
        lda     #$DD
        sta     $25C9
        lda     #$F0
        sta     $29C8
        lda     #$8B
        sta     $29C9
        rts
renderMoonBuffer1:		; $9563
		lda     #$F0
        sta     $40C8
        lda     #$8B
        sta     $40C9
        lda     #$AE
        sta     $44C8
        lda     #$D5
        sta     $44C9
        lda     #$D7
        sta     $48C8
        lda     #$AB
        sta     $48C9
        lda     #$81
        sta     $48CA
        lda     #$C0
        sta     $4CC7
        lda     #$AA
        sta     $4CC8
        lda     #$D5
        sta     $4CC9
        lda     #$82
        sta     $4CCA
        lda     #$E0
        sta     $50C7
        lda     #$DD
        sta     $50C8
        lda     #$EA
        sta     $50C9
        lda     #$85
        sta     $50CA
        lda     #$D0
        sta     $54C7
        lda     #$AE
        sta     $54C8
        lda     #$DD
        sta     $54C9
        lda     #$8B
        sta     $54CA
        lda     #$B0
        sta     $58C7
        lda     #$D7
        sta     $58C8
        lda     #$B6
        sta     $58C9
        lda     #$8D
        sta     $58CA
        lda     #$D8
        sta     $5CC7
        lda     #$FF
        sta     $5CC8
        lda     #$D5
        sta     $5CC9
        lda     #$9B
        sta     $5CCA
        lda     #$B8
        sta     $4147
        lda     #$D9
        sta     $4148
        lda     #$BA
        sta     $4149
        lda     #$95
        sta     $414A
        lda     #$D8
        sta     $4547
        lda     #$BA
        sta     $4548
        lda     #$D5
        sta     $4549
        lda     #$9A
        sta     $454A
        lda     #$B8
        sta     $4947
        lda     #$D7
        sta     $4948
        lda     #$AA
        sta     $4949
        lda     #$97
        sta     $494A
        lda     #$D8
        sta     $4D47
        lda     #$AE
        sta     $4D48
        lda     #$F5
        sta     $4D49
        lda     #$9A
        sta     $4D4A
        lda     #$B0
        sta     $5147
        lda     #$D5
        sta     $5148
        lda     #$FE
        sta     $5149
        lda     #$8D
        sta     $514A
renderMoonChunkBuffer1:
        lda     #$F0
        sta     $5547
        lda     #$AA
        sta     $5548
        lda     #$D7
        sta     $5549
        lda     #$8B
        sta     $554A
        lda     #$A0
        sta     $5947
        lda     #$DD
        sta     $5948
        lda     #$AA
        sta     $5949
        lda     #$85
        sta     $594A
        lda     #$C0
        sta     $5D47
        lda     #$BA
        sta     $5D48
        lda     #$CF
        sta     $5D49
        lda     #$82
        sta     $5D4A
        lda     #$D7
        sta     $41C8
        lda     #$AA
        sta     $41C9
        lda     #$81
        sta     $41CA
        lda     #$AE
        sta     $45C8
        lda     #$DD
        sta     $45C9
        lda     #$F0
        sta     $49C8
        lda     #$8B
        sta     $49C9
        rts				; $96ad



; Renders the starfield in the background. The stars are always in the same places, so
; there's a form of sprite compiling here. However they actually twinkle as well, so that
; modifies the blits
renderStars:			; 96ae
		jsr     jumpRandomNumber	; Choose a random number, then apply twinkle
        sta     ZP_SCRATCH56			; routine as needed. The twinkle modifies the
        lsr							; star patterns which are later copied to VRAM
        and     ZP_SCRATCH56
        tax
        ldy     #$00
        jsr     renderStarsTwinkle
        jsr     jumpRandomNumber
        sta     ZP_SCRATCH56
        lsr
        and     ZP_SCRATCH56
        tax
        ldy     #$07
        jsr     renderStarsTwinkle
        bit     ZP_BUFFER
        bpl     blitStars0
        jmp     blitStars1
renderStars1:
        ldx     #$16
        ldy     #$00
        jsr     renderStarsTwinkle
        ldx     #$63
        ldy     #$07
        jsr     renderStarsTwinkle
        bit     ZP_BUFFER
        bpl     blitStars0
        jmp     blitStars1

renderStarsTwinkle:			; Modifies star bit patterns to make them twinkle
        txa
        and     #$40
        ora     #$A0
        sta     starStates,y		; Each twinkle pattern is used for multiple stars on screen
        txa
        and     #$20
        ora     #$C0
        sta     starStates+1,y
        txa
        and     #$10
        ora     #$A0
        sta     starStates+2,y
        txa
        and     #$08
        ora     #$84
        sta     starStates+3,y
        txa
        and     #$04
        ora     #$82
        sta     starStates+4,y
        txa
        and     #$02
        ora     #$84
        sta     starStates+5,y
        txa
        and     #$01
        ora     #$82
        sta     starStates+6,y
        rts

starStates: 		; $971f
		.byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0		; State stored so they can twinkle


; $972d Does actual blitting for the stars, buffer 0. The star states are copied to various places
; all over the screen so the stars all twinkle, but it looks random and chaotic without costing much. Neat!
blitStars0:
		lda     starStates
        sta     $2022
        sta     $2202
        sta     $2303
        sta     $20B0
        lda     $9727
        sta     $20CB
        sta     $39A0
        sta     $3D5D
        sta     $3743
        sta     $22BC
        sta     $20BA
        lda     starStates+1
        sta     $21BF
        sta     $29B6
        sta     $35C4
        sta     $2045
        lda     $9728
        sta     $2338
        sta     $3000
        sta     $27AF
        sta     $2FFF
        sta     $21F0
        sta     $2176
        lda     $9729
        sta     $20EE
        sta     $2157
        sta     $20D4
        sta     $21D3
        sta     $3033
        sta     $3DD0
        lda     starStates+2
        sta     $22B3
        sta     $234B
        sta     $2BBE
        sta     $205E
        sta     $2005
        lda     $972A
        sta     $21F9
        sta     $2319
        sta     $256A
        sta     $29AA
        sta     $31AF
        sta     $3A22
        lda     starStates+3
        sta     $2413
        sta     $2329
        sta     $3028
        sta     $2FA5
        lda     $972B
        sta     $354C
        sta     $296F
        sta     $20FF
        sta     $3FAC
        sta     $3030
        lda     starStates+4
        sta     $241D
        sta     $3DCF
        sta     $2075
        sta     $30D0
        sta     $2385
        sta     $230A
        lda     $972C
        sta     $3AA7
        sta     $2800
        sta     $318D
        sta     $2201
        sta     $221C
        sta     $2330
        sta     $20E3
        lda     starStates+5
        sta     $2010
        sta     $28DF
        sta     $2977
        sta     $32C6
        sta     $20D8
        lda     starStates+6
        sta     $2427
        sta     $2253
        sta     $2261
        sta     $3DF2
        sta     $2E03
        sta     $2E10
        lda     $9726
        sta     $3027
        sta     $2434
        sta     $2427
        sta     $3586
        sta     $3604
        sta     $2294
        sta     $2795
        rts


; $983f Does actual blitting for the stars, buffer 0. The star states are copied to various places
; all over the screen so the stars all twinkle, but it looks random and chaotic without costing much. Neat!
blitStars1:
		lda     starStates
        sta     $4022
        sta     $4202
        sta     $4303
        sta     $40B0
        lda     $9727
        sta     $40CB
        sta     $59A0
        sta     $5D5D
        sta     $5743
        sta     $42BC
        sta     $40BA
        lda     starStates+1
        sta     $41BF
        sta     $49B6
        sta     $55C4
        sta     $4045
        lda     $9728
        sta     $4338
        sta     $5000
        sta     $47AF
        sta     $4FFF
        sta     $41F0
        sta     $4176
        lda     $9729
        sta     $40EE
        sta     $4157
        sta     $40D4
        sta     $41D3
        sta     $5033
        sta     $5DD0
        lda     starStates+2
        sta     $42B3
        sta     $434B
        sta     $4BBE
        sta     $405E
        sta     $4005
        lda     $972A
        sta     $41F9
        sta     $4319
        sta     $456A
        sta     $49AA
        sta     $51AF
        sta     $5A22
        lda     starStates+3
        sta     $4413
        sta     $4329
        sta     $5028
        sta     $4FA5
        lda     $972B
        sta     $554C
        sta     $496F
        sta     $40FF
        sta     $5FAC
        sta     $5030
        lda     starStates+4
        sta     $441D
        sta     $5DCF
        sta     $4075
        sta     $50D0
        sta     $4385
        sta     $430A
        lda     $972C
        sta     $5AA7
        sta     $4800
        sta     $518D
        sta     $4201
        sta     $421C
        sta     $4330
        sta     $40E3
        lda     starStates+5
        sta     $4010
        sta     $48DF
        sta     $4977
        sta     $52C6
        sta     $40D8
        lda     starStates+6
        sta     $4427
        sta     $4253
        sta     $4261
        sta     $5DF2
        sta     $4E03
        sta     $4E10
        lda     $9726
        sta     $5027
        sta     $4434
        sta     $4427
        sta     $5586
        sta     $5604
        sta     $4294
        sta     $4795
        rts				; $9950



; Renders the backgrounds and bubble markers next to the numbers in the HUD
renderHUDBubbles:			; $9951
		jsr		jumpInitSlideAnim					; Prepare to render the black backgrounds
		jsr		jumpSetSpriteAnimPtr
				.word $a0ec							; hudBackgroundBubbleSprite

		lda		#$ff
		jsr		jumpSetPalette

		jsr		jumpSetAnimLoc		; $9959			; Three backgrounds at hard-coded locations
				.byte $29	; X pos (low byte)
				.byte $00	; X pos (high byte)
				.byte $b3	; Y pos (bottom relative)
		jsr		jumpBlitImage		; $9964

		jsr		jumpSetAnimLoc
				.byte $77	; X pos (low byte)
				.byte $00	; X pos (high byte)
				.byte $b3	; Y pos (bottom relative)
		jsr		jumpBlitImage		; $996d

		jsr		jumpSetAnimLoc
				.byte $c5	; X pos (low byte)
				.byte $00	; X pos (high byte)
				.byte $b3	; Y pos (bottom relative)
		jsr		jumpBlitImage		; $9976

		jsr		jumpSetSpriteAnimPtr				; Prepare to render the bubbles.
				.word $a0ea							; hudBubbleSprite

		jsr		jumpSetAnimLoc		; $997e			; All three bubbles are the same sprite. Colour is changed via position
				.byte $2f	; X pos (low byte)		; and one palette change on the third
				.byte $00	; X pos (high byte)
				.byte $b2	; Y pos (bottom relative)
		jsr		jumpBlitImage		; $9984

		jsr		jumpSetAnimLoc
				.byte $7c	; X pos (low byte)
				.byte $00	; X pos (high byte)
				.byte $b2	; Y pos (bottom relative)
		jsr		jumpBlitImage		; $998d
		
		lda		#$00								; The green bubble needs a palette change
		jsr		jumpSetPalette
		jsr		jumpSetAnimLoc
				.byte $cb	; X pos (low byte)
				.byte $00	; X pos (high byte)
				.byte $b2	; Y pos (bottom relative)
		jsr		jumpBlitImage		; $999b

		rts



; Renders the big blocks of colour for the HUD at the top of the screen
renderHUD:		; $999f
		sec							; Render a blue rectangle at the top
        tya
        sbc     #$02
        sta     ZP_SCRATCH6A
        lda     #$00
        sta     ZP_SCRATCH68
        sta     ZP_SCRATCH69
        jsr     jumpSetBlitPos
				.word $0068
        jsr     jumpSetImagePtr			; $99b0
				.word $9a3b				; hudSpriteBlueTop
        jsr     jumpBlitRect

        clc								; Render the sloped top corners
        lda     ZP_SCRATCH6A
        adc     #$02
        sta     ZP_SCRATCH6A
        jsr     jumpInitSlideAnim
        jsr     jumpSetBlitPos
				.word $0068
        lda     #$FF			; $99c7
        jsr     jumpSetPalette
        jsr     jumpSetSpriteAnimPtr
				.word $a0b0				; hudCornerSprite
        jsr     jumpBlitImage

        lda     #$06
        sta     ZP_SCRATCH68
        lda     #$01
        sta     ZP_SCRATCH69
        jsr     jumpSetBlitPos
				.word $0068
        jsr     jumpBlitImageFlip		; $99e1

        sec								; Render the large green background
        lda     #$00
        sta     ZP_SCRATCH68
        sta     ZP_SCRATCH69
        lda     ZP_SCRATCH6A
        sbc     #$08
        sta     ZP_SCRATCH6A
        jsr     jumpSetBlitPos
				.word $0068
        jsr     jumpSetImagePtr			; $99f6
				.word $9a41				; hudSpriteGreenField
        jsr     jumpBlitRect

        lda     #$17					; Render right border of green box, which requires a palette change
        sta     ZP_SCRATCH68
        lda     #$01
        sta     ZP_SCRATCH69
		jsr     jumpSetBlitPos
				.word $0068
        jsr     jumpSetSpriteAnimPtr	; $9a0b
				.word $a0ae				; hudBorderSprite
		lda 	#$00					; $9a10
        jsr     jumpSetPalette
        jsr     jumpBlitImage

        sec								; Render the smaller orange background inside
        lda     ZP_SCRATCH6A
        sbc     #$03
        sta     ZP_SCRATCH6A
        lda     #$08
        sta     ZP_SCRATCH68
        lda     #$00
        sta     ZP_SCRATCH69
        jsr     jumpSetBlitPos
				.word $0068
        
        jsr     jumpSetImagePtr			; $9a2c
				.word $9a35				; hudSpriteOrangeField
        
		jsr     jumpBlitRect
        rts

; Pseudo-sprites used to render colour blocks for the HUD. Each is W/H and some pixels.
hudSpriteOrangeField:		; $9a35
		.byte	$26,$0B
		.byte	$AA,$D5,$AA,$D5

hudSpriteBlueTop:		; $9a3b
		.byte	$28,$06
		.byte	$D5,$AA,$D5,$AA

hudSpriteGreenField:		; $9a41
		.byte	$28,$11
		.byte	$2A,$55,$2A,$55
        


; The main game initialization routine. This sets all our initial states for everything.
initGameState:	; $9a47
		bit     ZP_GAMEACTIVE
        bpl     initGameStateActive

		; Render initial HUD for demo mode
        ldy     #$BF			; This is mysterious, since Y isn't used anywhere in these routines. Possibly a debugging marker for Dan
        jsr     renderHUD
        jsr     renderHUDBubbles
        jsr     jumpPageFlip
        jsr     jumpFlipPageMask
        ldy     #$BF			; This is mysterious, since Y isn't used anywhere in these routines. Possibly a debugging marker for Dan
        jsr     renderHUD
        jsr     renderHUDBubbles
        jsr     jumpPageFlip
        jsr     jumpFlipPageMask

        ldx     #$FF			; Zero out HUD numbers during demo
        ldy     #$00
        lda     #$00
        jsr     jumpRenderBCD
        ldx     #$FF
        ldy     #$00
        lda     #$01
        jsr     jumpRenderBCD
        ldx     #$FF
        ldy     #$00
        lda     #$02
        jsr     jumpRenderBCD

initGameStateActive:
		lda     #$00				; Initialize hostage states
        sta     TOTAL_RESCUES
        sta     HOSTAGES_KILLED
        sta     HOSTAGES_ACTIVE
        sta     HOSTAGES_LOADED
        sta     BASE_RUNNERS
        lda     #$40
        sta     HOSTAGES_LEFT

        lda     #$00				; Initialize hostage houses
        sta     houseStates
        sta     houseStates+1
        sta     houseStates+2
        sta     houseStates+3

        lda     #$10				; Put the hostages in their houses
        sta     hostagesInHouses
        sta     hostagesInHouses+1
        sta     hostagesInHouses+2
        sta     hostagesInHouses+3

        lda     #$00				; Initialize level and sortie counters
        sta     CURR_LEVEL
        sta     SORTIE

        lda     #$00				; Initialize HUD state
        sta     HOSTAGES_KILLED_BCD
        sta     TOTAL_RESCUES_BCD
        sta     HOSTAGES_LOADED_BCD

        lda     MAX_HOSTAGES		; Initialize the hostage table
        asl
        asl
        tax
initHostageLoop:
		txa
        sec
        sbc     #$04
        bmi     initGameStateDone
        tax
        lda     #$FF
        sta     hostageTable,x
        jmp     initHostageLoop

initGameStateDone:
		rts							; Let's go!



; Initializes graphics, clears screen and draws HUD. Weirdly, this never seems to be called.
; It may be part of a different title screen that Dan was imagining, which was replaced
; by the stored screenshot that is displayed by the loader? I have set breaks in this code
; and it never seems to be called, even from the loader. Perhaps Dan used this during
; development as a clean startup routine to call from his development environment (likely DOS 3.3).
startGraphicsDeadCode:		; $9add
        jsr     jumpInitRendering
		jsr     jumpClearScreen
        jsr     jumpFlipPageMask
        jsr     jumpClearScreen
        jsr     jumpFlipPageMask
        ldx     #$00
		ldy     #$B4
		lda     #$80
        jsr     jumpScreenFill
        ldy     #$BF
		jsr     renderHUD
        jsr     jumpFlipPageMask
        ldx     #$00
        ldy     #$B4
        lda     #$80
        jsr     jumpScreenFill
        ldy     #$BF
        jsr     renderHUD
        jsr     jumpFlipPageMask

        jsr     jumpSetScrollBottom
				.byte $18,$70

		jsr		jumpSetScrollTop		; $9b13
				.byte $1e,$70

		
		clc							; $9b18
		lda		SCROLLPOS_Y
		adc		TITLEREGION_TOP
		sta		startGraphicsTarget+2
		clc
		lda		TITLEREGION_TOP
		adc		#$01
		sta		startGraphicsSprite+1
		jsr		jumpSetImagePtr
				.word $9b46			; startGraphicsSprite

		jsr		jumpSetAnimLoc		; $9b30
startGraphicsTarget: .byte $00	; X pos (low byte)
					.byte $00	; X pos (high byte)
					.byte $00	; Y pos (bottom relative)

		jsr jumpBlitRect
		jsr jumpFlipPageMask
		jsr jumpBlitRect
		jsr jumpFlipPageMask
		jsr jumpEnableHiResGraphics
		rts


startGraphicsSprite:	; $9b46 A pseudo-sprite used by startGraphics
		.byte	$28,$ff			; Width is set via self modiying code
		.byte	$55,$2a,$55,$2a



; Erases all the sprites last drawn by overwriting them with black and/or pink
; rectangles depending on where they intersect the ground. The data needed to
; do this is stored in a large double-buffered display list which was populated
; by last frame's rendering. This also makes use of a sprite geometry table which
; tells us what rectangles to erase relative to a sprite's size and position
eraseAllSprites:		; $9b4c
		ldx     ZP_OFFSETPTR0_L		; Swap renderDisplayList0/1 pointers
        ldy     ZP_OFFSETPTR1_L
        sty     ZP_OFFSETPTR0_L
        stx     ZP_OFFSETPTR1_L

        ldx     ZP_OFFSETPTR0_H
        ldy     ZP_OFFSETPTR1_H
        sty     ZP_OFFSETPTR0_H
        stx     ZP_OFFSETPTR1_H

        ldx     ZP_OFFSET_ROW0		; Swap offset table iterators
        ldy     ZP_OFFSET_ROW1
        sty     ZP_OFFSET_ROW0
        stx     ZP_OFFSET_ROW1

        lda     ZP_OFFSET_ROW0
        bne     eraseAllSpritesGo
        rts

eraseAllSpritesGo:
		ldy     #$00
eraseAllSpritesLoop:
        lda     (ZP_OFFSETPTR0_L),y
        sta     ZP_SCRATCH5A			; Fetch and cache table row index
        iny
        lda     (ZP_OFFSETPTR0_L),y
        sta     ZP_POS_SCRATCH0			; Fetch and cache X render position (low byte)
        iny
        lda     (ZP_OFFSETPTR0_L),y
        sta     ZP_POS_SCRATCH1			; Fetch and cache X render position (high byte)
        iny
        lda     (ZP_OFFSETPTR0_L),y
        sta     ZP_POS_SCRATCH2			; Fetch and cache Y render position
        iny
        lda     ZP_SCRATCH5A			; Map table row index to pointer
        asl
        asl
        tax								; Find matching row in spriteGeometry
        lda     spriteGeometry,x			; Look up origin -> left extent offset for X
        sta     ZP_SCRATCH5B				; Always zero except for chopper
        lda     spriteGeometry+1,x		; Look up origin -> top extent offset for Y
        sta     ZP_SCRATCH5C				; Always zero except for chopper
        lda     spriteGeometry+2,x
        sta     ZP_SCRATCH61				; Cache width of sprite in bytes
        lda     spriteGeometry+3,x
        sta     ZP_SCRATCH62				; Cache worst-case height of sprite (such as chopper at full tilt, which is 23)
        sec
        lda     ZP_POS_SCRATCH0			; Find left extent of sprite based on origin offset
        sbc     ZP_SCRATCH5B				; $9b9b
        sta     ZP_POS_SCRATCH0			; Now caching X left edge of sprite (low byte)
        lda     ZP_POS_SCRATCH1
        sbc     #$00
        sta     ZP_POS_SCRATCH1			; Now caching X left edge of sprite (high byte)

        clc								; Offset Y position from table
        lda     ZP_POS_SCRATCH2
        adc     ZP_SCRATCH5C				; Offset from origin to find Y extent
        sta     ZP_POS_SCRATCH2			; Now caching Y top of sprite

        bit     ZP_POS_SCRATCH1			; Check sign of original X position
        bpl     eraseAllSpritesCheckLandDepth

        lda     ZP_POS_SCRATCH0			; Convert left extent to byte value
        eor     #$FF					; Left extent will always be negative
        clc								; So negate it
        adc     #$01
        lsr								; Convert to byte value
        lsr
        lsr
        sta     ZP_SCRATCH56				; Cache byte of left extent
        sec
        lda     ZP_SCRATCH61				; Subtract left extent from width
        sbc     ZP_SCRATCH56
        sta     ZP_SCRATCH61				; Now caches width in bytes to erase
        lda     #$00
        sta     ZP_POS_SCRATCH0			; Position now normalized to top left
        sta     ZP_POS_SCRATCH1

eraseAllSpritesCheckLandDepth:				; $9bc9
		lda     LAND_POSY				; Are we inside the land?
        cmp     ZP_POS_SCRATCH2
        bcs     eraseAllSpritesWithinLand
        sec
        lda     ZP_POS_SCRATCH2			; Are we fully airborne?
        sbc     LAND_POSY
        cmp     ZP_SCRATCH62
        bcs     eraseAllSpritesAirborne
        sta     ZP_SKY_BACK_H
        sec
        lda     ZP_SCRATCH62				; Mix of land and sky
        sbc     ZP_SKY_BACK_H
        sta     ZP_LAND_BACK_H
        jmp     eraseSprite

eraseAllSpritesAirborne:			; Fully airborne, so land background is 0, and sky background is maximum
		lda     #$00			; $9be6
        sta     ZP_LAND_BACK_H
        lda     ZP_SCRATCH62
        sta     ZP_SKY_BACK_H
        jmp     eraseAllSpritesEraseReady

eraseAllSpritesWithinLand:  		; Fully in ground, so land background is maximum, and sky background is zero
		lda     #$00			; $9bf1
        sta     ZP_SKY_BACK_H
        lda     ZP_SCRATCH62
        sta     ZP_LAND_BACK_H
        jmp     eraseSprite

eraseAllSpritesEraseReady:
		sec								; $9bfc
        lda     ZP_POS_SCRATCH2			; Call appropriate erasure case- sky, land, or mixed
        sbc     SKY_HEIGHT
        bcc     eraseSprite
        beq     eraseSprite
        sta     ZP_SCRATCH56
        cmp     ZP_SKY_BACK_H
        bcs     eraseSpriteNoLand
        sec
        lda     ZP_SKY_BACK_H			; For mixed case, modify sky height from land height
        sbc     ZP_SCRATCH56
        sta     ZP_SKY_BACK_H
        lda     SKY_HEIGHT
        sta     ZP_POS_SCRATCH2

eraseSprite:  							; $9c18
		lda     ZP_SKY_BACK_H			; Set height of sprite background
        beq     eraseSpriteNoSky
        sta     skyBackground+1
        lda     ZP_SCRATCH61				; Set width (in bytes) of sprite background
        sta     skyBackground

        jsr     jumpSetImagePtr
				.word $9c5d				; Pointer to skyBackground pseudo-sprite

		jsr		jumpSetBlitPos			; $9c29
				.word	$001f
		
		jsr		jumpBlitRect			; Blit black rectangle to erase sprite in the sky
		
eraseSpriteNoSky:
		lda     ZP_LAND_BACK_H			; Set height of land area to erase
        beq     eraseSpriteNoLand
        sta     landBackground+1
        lda     ZP_SCRATCH61
        sta     landBackground			; Set width (in bytes) of land area to erase

        jsr     jumpSetImagePtr
				.word $9c63				; Pointer to landBackground

		sec								; Calculate height of on-land area
        lda     ZP_POS_SCRATCH2
        sbc     ZP_SKY_BACK_H			; Subtract overall back height to get on-land height
        sta     ZP_POS_SCRATCH2
        jsr     jumpSetBlitPos
				.word	$001f

		jsr     jumpBlitRect			; Blit pink rectangle to erase land area behind sprite

eraseSpriteNoLand:						; $9c51
		cpy     ZP_OFFSET_ROW0			; Now do it all again for the next sprite
        beq     eraseSpriteDone
        jmp     eraseAllSpritesLoop

eraseSpriteDone:  
		lda     #$00
        sta     ZP_OFFSET_ROW0
        rts


; This is a pesudo-sprite that erases the sky background behind a sprite
; W,H, Pixels for a sprite
skyBackground:			; $9c5d
	.byte	$07,$17			; W (in bytes) x H. Dimensions are modified as needed
	.byte	$80,$80,$80,$80	; Black line


; This is a pesudo-sprite that renders the pink ground behind a sprite
; W,H, Pixels for a sprite
landBackground:			; $9c63
	.byte	$07,$05			; Dimensions are modified as needed
	.byte	$55,$2A,$55,$2A	; Pink line



; A table of 4-byte records with geometry for each sprite.
; Each row belongs to a specific sprite in the game.
; 0 = X extent from sprite origin to left edge (8 bits only)
; 1 = Y extent from sprite origin to top (bottom relative)
; 2 = Width of sprite in bytes
; 3 = Height of sprite in worst-case rotation
spriteGeometry:				; $9c69
		.byte $16,$0E,$07,$17	; Chopper
		.byte $00,$00,$09,$04	; Unknown, possibly unused
		.byte $00,$00,$06,$06	; Tank body
		.byte $00,$00,$03,$03	; Tank turret
		.byte $00,$00,$02,$04	; Tank cannon
		.byte $00,$00,$05,$0C	; Crashing/sinking chopper
		.byte $00,$00,$00,$00	; Placeholder
		.byte $00,$00,$04,$05	; Jet sprite 1
		.byte $00,$00,$05,$0D	; Jet sprite 2
		.byte $00,$00,$05,$11	; Jet sprite 3
		.byte $00,$00,$06,$10	; Jet sprite 4
		.byte $00,$00,$07,$12	; Jet sprite 5
		.byte $00,$00,$00,$00	; Placeholder
		.byte $00,$00,$02,$03	; Tank shell
		.byte $00,$00,$02,$03	; Bullet
		.byte $00,$00,$03,$03	; Jet missile
		.byte $00,$00,$02,$01	; Jet bomb
		.byte $00,$00,$03,$0B	; Unknown, possibly unused
		.byte $00,$00,$00,$00	; Unknown, possibly unused
		.byte $00,$00,$16,$05	; Unknown, possibly unused
		.byte $00,$00,$09,$09	; Unknown, possibly unused
		.byte $00,$00,$03,$0C	; Unknown, possibly unused
		.byte $00,$00,$04,$0B	; Unknown, possibly unused
		.byte $00,$00,$05,$0D	; Unknown, possibly unused
		.byte $00,$00,$03,$02	; Unknown, possibly unused
		.byte $00,$00,$03,$0A	; Alien body



; Handles the actual scrolling of the terrain in response to the helicopter's position
; This is a surprisingly sophisticated function designed to make the scrolling feel smooth and nice
; based on the helicopter's position, velocity, and acceleration. This is much more than the
; naive "center on the player" method you might imagine (and what a lot of games would do).
; I will not claim to understand every nuance of what's being done here, but I did my best to
; document the broad strokes.
scrollTerrain:		; $9cd1
        lda     ZP_LANDED_BASE		; Check if we're on the landing pad
        bne     scrollAfield

        lda     ZP_AIRBORNE			; Check if we're touched down and/or landed
        beq     scrollTouchedDown

        lda     ZP_TURN_STATE		; Scrolling behaviour depends on facing from here
        beq     scrollFacingCamera
        bpl     scrollFacingRight
        bmi     scrollFacingLeft

scrollFacingRight:
		bit     ZP_VELX_16_H		; Flying backwards is treated like touchdown
        bmi     scrollTouchedDown
        jmp     scrollForwardFlight

scrollFacingLeft:
		bit     ZP_VELX_16_H		; Flying backwards is treated like touchdown
        bpl     scrollTouchedDown
        jmp     scrollForwardFlight

scrollFacingCamera:
		jmp     scrollForwardFlight

scrollAfield:
		clc
        lda     ZP_SCROLLPOS_L		; Scroll right by 4
        adc     #$04
        sta     ZP_SCROLLPOS_L
        lda     ZP_SCROLLPOS_H
        adc     #$00
        sta     ZP_SCROLLPOS_H
        jmp     scrollClamp

scrollTouchedDown:
		sec
        lda     CHOP_POS_X_L		; Check player delta to scroll position
        sbc     ZP_SCROLLPOS_L
        sta     ZP_SCRATCH56			; Caches low X difference
        lda     CHOP_POS_X_H
        sbc     ZP_SCROLLPOS_H
        sta     ZP_SCRATCH57			; Caches high X difference
        lda     SCROLL_LEAD_R_H
        cmp     ZP_SCRATCH57			; Check for exceeding lead distance towards the right
        bcc     scrollSnapToChopperRight
        bne     scrollCheckLeftLead	; Check for exceeding lead distance towards the left
        lda     SCROLL_LEAD_R_L
        cmp     ZP_SCRATCH56
        bcs     scrollCheckLeftLead

scrollSnapToChopperRight:
		sec
        lda     CHOP_POS_X_L
        sbc     SCROLL_LEAD_R_L
        sta     ZP_SCROLLPOS_L
        lda     CHOP_POS_X_H
        sbc     SCROLL_LEAD_R_H
        sta     ZP_SCROLLPOS_H
        jmp     scrollClamp

scrollCheckLeftLead:
		lda     ZP_SCRATCH57
        cmp     SCROLL_LEAD_L_H
        bcc     scrollSnapToChopperLeft
        bne     scrollDoneBounce
        lda     ZP_SCRATCH56
        cmp     SCROLL_LEAD_L_L
        bcs     scrollDoneBounce

scrollSnapToChopperLeft:
		sec
        lda     CHOP_POS_X_L
        sbc     SCROLL_LEAD_L_L
        sta     ZP_SCROLLPOS_L
        lda     CHOP_POS_X_H
        sbc     SCROLL_LEAD_L_H
        sta     ZP_SCROLLPOS_H
        jmp     scrollClamp

scrollDoneBounce:
		jmp     scrollTerrainDone

scrollForwardFlight:			; $9d56
		lda     ZP_VELX_16_L				; Get high 11 bits of chopper VX
        sta     ZP_SCRATCH16_L
        lda     ZP_VELX_16_H
        sta     ZP_SCRATCH16_H
        ldy     #$05
        jsr     jumpArithmeticShiftRight16

        clc
        lda     CHOP_POS_X_L				; Project chopper's next position
        adc     ZP_SCRATCH16_L
        sta     ZP_SCRATCH16_L
        lda     CHOP_POS_X_H
        adc     ZP_SCRATCH16_H
        sta     ZP_SCRATCH16_H
        bit     ZP_VELX_16_H				; Check travel direction to determine scroll direction
        bmi     scrollTowardLeft
        bpl     scrollTowardRight

scrollTowardLeft:
		sec
        lda     ZP_SCRATCH16_L
        sbc     SCROLL_LEAD_L_L			; Apply lead to projected position
        sta     ZP_SCRATCH56
        lda     ZP_SCRATCH16_H
        sbc     SCROLL_LEAD_L_H
        sta     ZP_SCRATCH57
        jmp     scrollWithLead

scrollTowardRight:
		sec
        lda     ZP_SCRATCH16_L
        sbc     SCROLL_LEAD_R_L			; Apply lead to projected position
        sta     ZP_SCRATCH56				; Cache projection+lead
        lda     ZP_SCRATCH16_H
        sbc     SCROLL_LEAD_R_H
        sta     ZP_SCRATCH57
scrollWithLead:							; Check actual scroll direction with projection and lead
        bit     ZP_VELX_16_H
        bpl     scrollWithLeadRight
        bmi     scrollWithLeadLeft
scrollWithLeadRight:
		lda     ZP_SCROLLPOS_H
        cmp     ZP_SCRATCH57
        bcc     scrollWithGoRight
        bne     scrollTerrainDone
        lda     ZP_SCROLLPOS_L
        cmp     ZP_SCRATCH56
        bcs     scrollTerrainDone
scrollWithGoRight:
		jsr     calculateScrollOffset
        clc
        lda     ZP_SCROLLPOS_L
        adc     ZP_SCRATCH5B
        sta     ZP_SCROLLPOS_L
        lda     ZP_SCROLLPOS_H
        adc     #$00
        sta     ZP_SCROLLPOS_H
        jmp     scrollClamp

scrollWithLeadLeft:
		lda     ZP_SCRATCH57
        cmp     ZP_SCROLLPOS_H
        bcc     scrollWithGoLeft
        bne     scrollTerrainDone
        lda     ZP_SCRATCH56
        cmp     ZP_SCROLLPOS_L
        bcs     scrollTerrainDone

scrollWithGoLeft:			; $9DCC
		jsr     calculateScrollOffset
        sec
        lda     ZP_SCROLLPOS_L
        sbc     ZP_SCRATCH5B
        sta     ZP_SCROLLPOS_L
        lda     ZP_SCROLLPOS_H
        sbc     #$00
        sta     ZP_SCROLLPOS_H

scrollClamp:					; Clamp scroll position to limits of playfield
        lda     SCROLL_START_H
        cmp     ZP_SCROLLPOS_H
        bcc     scrollClampToRight
        bne     scrollClampCheckLeft
        lda     SCROLL_START_L
        cmp     ZP_SCROLLPOS_L
        bcs     scrollFinalize

scrollClampToRight:
		lda     SCROLL_START_L
        sta     ZP_SCROLLPOS_L
        lda     SCROLL_START_H
        sta     ZP_SCROLLPOS_H
        jmp     scrollFinalize

scrollClampCheckLeft:
		lda     ZP_SCROLLPOS_H
        cmp     SCROLL_END_H
        bcc     scrollClampToLeft
        bne     scrollFinalize
        lda     ZP_SCROLLPOS_L
        cmp     SCROLL_END_L
        bcs     scrollFinalize

scrollClampToLeft:
		lda     SCROLL_END_L
        sta     ZP_SCROLLPOS_L
        lda     SCROLL_END_H
        sta     ZP_SCROLLPOS_H

scrollFinalize:
		jsr     jumpSetLocalScroll
				.word $0072		; Points to ZP_SCROLLPOS anyway

scrollTerrainDone:
		rts



; Calculates an offset for scrolling based on the chopper's velocity
; Returns the result in ZP_SCRATCH5B
calculateScrollOffset:			; $9e19
        lda     ZP_VELX_16_L			; Fetch high 8 bits of chopper VX
        sta     ZP_SCRATCH16_L
        lda     ZP_VELX_16_H
        sta     ZP_SCRATCH16_H
        ldy     #$08
        jsr     jumpArithmeticShiftRight16
        lda     ZP_SCRATCH16_L
        bpl     calculateScrollOffsetPos			; Get ABS value
        eor     #$FF
        clc
        adc     #$01

calculateScrollOffsetPos:  
		clc
        adc     #$04
        sta     ZP_SCRATCH5B			; Add 4 to |VX|

        sec
        lda     ZP_SCRATCH56			; Cache of projection+lead (low)
        sbc     ZP_SCROLLPOS_L		; Subtract scroll position
        sta     ZP_SCRATCH5F		; Cache of projection+lead-scroll (low)
        lda     ZP_SCRATCH57			; Cache of projection+lead (high)
        sbc     ZP_SCROLLPOS_H
        sta     ZP_SCRATCH60		; Cache of projection+lead-scroll (high)
        bit     ZP_SCRATCH60		; Get ABS of these projections
        bpl     calculateScrollOffsetSumPos

        clc
        lda     ZP_SCRATCH5F		; Both will have the same sign, so negate both
        eor     #$FF
        adc     #$01
        sta     ZP_SCRATCH5F

        lda     ZP_SCRATCH60
        eor     #$FF
        adc     #$00
        sta     ZP_SCRATCH60

calculateScrollOffsetSumPos:
		lda     ZP_SCRATCH5B
        ldx     ZP_SCRATCH60
        bne     calculateScrollOffsetLowMag
        cmp     ZP_SCRATCH5F
        bcc     calculateScrollOffsetLowMag
        lda     ZP_SCRATCH5F
calculateScrollOffsetLowMag:  
		sta     ZP_SCRATCH5B
        rts



; Does an artimetic left-shift of a 16-bit value stored in the 16-bit scratch
; Y=Bits to shift
arithmeticShiftLeft16:		; $9e65
        bit     ZP_SCRATCH16_H		; Cache sign of original value
        bmi     arithmeticShiftLeft16Neg
        lda     #$00
        sta     arithmeticShiftLeft16Sign
        jmp     arithmeticShiftLeft16Pos

arithmeticShiftLeft16Neg:
		lda     #$FF				; Get ABS value of original value
        sta     arithmeticShiftLeft16Sign
        lda     ZP_SCRATCH16_L
        eor     #$FF
        sta     ZP_SCRATCH16_L
        lda     ZP_SCRATCH16_H
        eor     #$FF
        sta     ZP_SCRATCH16_H
        inc     ZP_SCRATCH16_L
        bne     arithmeticShiftLeft16Pos
        inc     ZP_SCRATCH16_H

arithmeticShiftLeft16Pos:						; Shift Y bits left in 16-bit value
		asl     ZP_SCRATCH16_L		; by shifting low and rolling into high
        rol     ZP_SCRATCH16_H
        dey
        bne     arithmeticShiftLeft16Pos
        bit     arithmeticShiftLeft16Sign
        bmi     arithmeticShiftLeft16Negate
        rts

arithmeticShiftLeft16Negate:
		lda     ZP_SCRATCH16_L		; Restore original sign if needed
        eor     #$FF
        sta     ZP_SCRATCH16_L
        lda     ZP_SCRATCH16_H
        eor     #$FF
        sta     ZP_SCRATCH16_H
        inc     ZP_SCRATCH16_L
        bne     arithmeticShiftLeft16Done
        inc     ZP_SCRATCH16_H
arithmeticShiftLeft16Done:
		rts

arithmeticShiftLeft16Sign:	; $9ea8
		.byte	$00



; Spawn all the initial hostages to begin a game
spawnInitialHostages:	; $9ea9
		lda     #$08				; Spawn eight hostages to begin
        sta     HOSTAGES_ACTIVE
        sec
        lda     HOSTAGES_LEFT
        sbc     #$08
        sta     HOSTAGES_LEFT

        sec							; Remove those hostages from the right-most house
        lda     hostagesInHouses+3
        sbc     #$08
        sta     hostagesInHouses+3
        lda     #$01				; Set the right-most house on fire
        sta     houseStates+3
        clc
        lda     FARHOUSE_X_L
        adc     #$D0
        sta     ZP_SCRATCH58
        lda     FARHOUSE_X_H
        adc     #$03
        sta     $59
        lda     #$00
        sta     ZP_SCRATCH5A

        ldx     #$00				; Add them to the hostages table
        ldy     #$00
spawnInitialHostagesLoop:
		tya
        sta     hostageTable,x
        lda     #$00
        sta     hostageTable+1,x
        lda     ZP_SCRATCH58
        sta     hostageTable+2,x
        lda     $59
        sta     hostageTable+3,x
        inc     ZP_SCRATCH5A
        lda     ZP_SCRATCH5A
        cmp     #$08
        beq     spawnInitialHostagesDone
        asl
        asl
        tax
        iny
        cpy     #$04
        bne     spawnInitialHostagesNoWrap
        ldy     #$00
spawnInitialHostagesNoWrap:
		jsr     jumpRandomNumber
        and     #$7E
        clc
        adc     #$20
        clc
        adc     ZP_SCRATCH58
        sta     ZP_SCRATCH58
        lda     $59
        adc     #$00
        sta     $59
        jmp     spawnInitialHostagesLoop

spawnInitialHostagesDone:
		rts



; Initialize helicopter state for a new game. Also initializes some other game state
; related to rendering and game objects
initHelicopter:			; $9f18
        lda     #$05					; Facing and controls
        sta     ZP_TURN_STATE
        lda     #$01
        sta     CHOP_FACE
        lda     #$00
        sta     CHOP_TURN_REQUEST
        lda     #$00
        sta     ZP_ACCELX
        sta     ZP_STICKX
        sta     ZP_ACCELY

        lda     #$00					; Grounding states
        sta     ZP_AIRBORNE
        lda     #$01
        sta     ZP_LANDED
        sta     ZP_LANDED_BASE
        lda     #$00
        sta     ZP_SINK_Y
        sta     ZP_GROUNDING

        sta     ZP_DYING				; Death states
        sta     ZP_DEATHTIMER

        sta     ZP_BTN0DOWN				; Miscellaneous
        sta     CURR_SHOTS

        sta     ZP_VELX_16_L			; Velocity
        sta     ZP_VELX_16_H
        sta     ZP_VELY_16_L
        sta     ZP_VELY_16_H

        lda     #$93					; Set initial position to the base
        sta     CHOP_POS_X_L
        lda     #$12
        sta     CHOP_POS_X_H
        lda     #$07
        sta     CHOP_POS_Y
        lda     CHOP_GROUND_INIT
        sta     CHOP_GROUND

        jsr     jumpInitEntityTable		; Initialize the game entity table

        lda     #$00					; Initialize rendering double-buffer state
        sta     ZP_BUFFER
        jsr     jumpInitPageMask
        jsr     jumpFlipPageMask
        jsr     jumpPageFlip
        jsr     jumpFlipPageMask

        lda     #$00					; Start with no hostages onboard
        sta     CHOP_LOADED
        rts
.org $9f79


; 135 unused bytes from $9f79 to $a000
UNUSED 135


.org $a000

; Below are all the master tables of pointers to sprites.
; Each sprite pointer is to a structure that is used by all rendering routines:
; 	.byte widthInPixels
; 	.byte heightInPixels
; 	.byte pixelData...


; A list of the sprites needed for all sideways chopper angles.
; Same sprites are used for facing left and right, with renderer handling X-flip
chopperSideSpriteTable:		; $a000
	.word	$a102		; -5 Full tilt forward, nose down
	.word	$a14c
	.word	$a18e
	.word	$a1db
	.word	$a223
	.word	$a26b		;  No tilt
	.word	$a2ae
	.word	$a2f1
	.word	$a334
	.word	$a37c
	.word	$a3c9		; +5 Full tilt backward, backward nose up

; A table of sprites to use when head-on or in rotation animation. Tilt is done with tilt-renderer
chopperHeadOnSpriteTable:		; $a016
	.word	$a41b		; Normal head-on view, all tilt angles
	.word	$a437		; Partially rotated from head-on to sideways (frame 1)
	.word	$a453		; Partially rotated from head-on to sideways (frame 2)
	.word	$a47c		; Partially rotated from head-on to sideways (frame 3)
	.word	$a4b2		; Partially rotated from head-on to sideways (frame 4)

chopperSquishingSpriteTable:	; $a020
	.word	$a4e8		; Squished down a little sideways (mid-bounce) $a020
	.word	$a526		; Squished down a little head-on (mid-bounce)	$a022

mainRotorAnimationTable:			; $a024
	.word	$a540		; Main rotor (frame 1)
	.word	$a547		; Main rotor (frame 2)
	.word	$a54e		; Main rotor (frame 3)

tailRotorAnimationTable:			; $a02a
	.word	$a555		; Tail rotor (frame 1)
	.word 	$a55d		; Tail rotor (frame 2)
	.word 	$a565		; Tail rotor (frame 3)
	.word 	$a56b		; Tail rotor (frame 4)

; All the sprite frames for rendering the enemy jets. Pointers into this come from jetSpriteTable
jetMasterSpriteTable:	; $a032
	.word	$a574		; Enemy jet, level flight
	.word	$a585		; Enemy jet, turning (frame 1)
	.word	$a5b3		; Enemy jet, turning (frame 2)
	.word	$a5dc		; Enemy jet, turning (frame 3)
	.word	$a60b		; Enemy jet, turning (frame 4)
	.word	$a62d		; Enemy jet, turning (frame 5)
	.word	$a662		; Enemy jet, turning (frame 6)
	.word	$a6a4		; Enemy jet, turning (frame 7)
	.word	$a6e6		; Enemy jet, turning (frame 8)
	.word	$a709		; Enemy jet, turning (frame 9)
	.word	$a735		; Enemy jet, turning (frame 10)
	.word	$a75f		; Enemy jet, turning (frame 11)
	.word	$a789		; Enemy jet, turning (frame 12)
	.word	$a7c2		; Enemy jet, turning (frame 13)
	.word	$a81e		; Enemy jet, turning (frame 14)
	.word	$a85c		; Enemy jet, turning (frame 15)
	.word	$a892		; Enemy jet, turning (frame 16)
	.word	$a8c4		; Enemy jet, turning (frame 17)
	.word	$a8e7		; Enemy jet, turning (frame 18)
	.word	$a8fb		; Enemy jet, turning (frame 19)
	.word	$a957		; Enemy jet, turning (frame 20)
	.word	$a995		; Enemy jet, turning (frame 21)
	.word	$a9cb		; Enemy jet, turning (frame 22)
	.word	$aa01		; Enemy jet, turning (frame 23)
	.word	$aa24		; Enemy jet, turning (frame 24)

; All the sprite frames for rendering the enemy tanks
tankSpriteTable:		; $a064
	.word	$aa38		; Tank turret
	.word	$aa40		; Tank tread (frame 1)
	.word	$aa5a		; Tank tread (frame 2)

tankCannonSpriteTable:	; $a06a
	.word	$aa74		; Tank cannon, facing full right
	.word	$aa7b		; Tank cannon, facing up and right
	.word	$aa81		; Tank cannon, facing up
	.word	$aa87		; Tank cannon, facing up and left
	.word	$aa8d		; Tank cannon, facing full left

; All the sprites for the various bullets
bulletSpriteTable:		; $a074
	.word	$aa94		; Chopper bullet	$a074
	.word	$aa99		; Tank shell		$a076
	.word	$aa9e		; Jet missile (The big ones fired in pairs at high altitude)  $a078
	.word	$aaa6		; Jet bomb (The little one that drops at an angle)  $a07a
	.word	$aaa9		; Chopper muzzle flash	$a07c

; All the sprites for the alien saucer
alienSpriteTable:		; $a07e
	.word	$aaaf		; Saucer body					$a07e
	.word	$aac5		; Saucer mid section (frame 1) 	$a080
	.word	$aacb		; Saucer mid section (frame 2)	$a082
	.word	$aad1		; Saucer mid section (frame 3)	$a084

; All the sprite frames for rendering the explosions
explosionSpriteTable:	; $a086
	.word	$aad7		; Explosion (frame 1)
	.word	$aaf4		; Explosion (frame 2)
	.word	$ab17		; Explosion (frame 3)
	.word	$ab3d		; Explosion (frame 4)
	.word	$ab63		; Explosion (frame 5)

chopperRubbleSprite:
	.word	$ab7d		; $a090	Chopper rubble sprite

	.word	$ab87		; $a092	Dying hostage

; All the sprite frames for rendering the hostages
hostageRunningSpriteTable:		; $a094
	.word	$ab9f		; Running man (frame 1)
	.word	$abb7		; Running man (frame 2)
	.word	$abcf		; Running man (frame 3)
	.word	$abe7		; Running man (frame 4)

hostageWavingSpriteTable:		; $a09c
	.word	$abff		; Waving man (frame 1)
	.word	$ac17		; Waving man (frame 2)
	.word	$ac2f		; Waving man (frame 3)

hostageLoadingSpriteTable:		; $a0a2
	.word	$ac47		; Man jumping into chopper (frame 1)
	.word	$ac5f		; Man jumping into chopper (frame 2)

mountainSpriteTable:		; $a0a6
	.word	$ac77			; There are four different mountain patterns
	.word	$ad59
	.word	$ae1F
	.word	$af1D

hudBorderSprite:					; $a0ae
	.word	$b01B		; Right border (green) of HUD. Special sprite is used to render this

hudCornerSprite:					; $a0b0
	.word	$b034		; Sprite for angled top corners of HUD

baseBuildingSprite:		; The orange main building of the base
	.word	$b04E			; $a0b2

baseGrassCornerSprite:		; The little corners of grass at the base
	.word	$b344			; $a0b4

baseFlagpole:				; The flag pole (without the flapping flag)
	.word	$b350			; $a0b6

baseFlagSpriteTable:		; The animation frames of the flag
	.word	$b35E			; $a0b8
	.word	$b370

baseLeftSidewalkSprite:		; Little piece of sidewalk left of the base
	.word	$b382			; $a0bc
baseRightSidewalkSprite:	; Little piece of sidewalk right of the base
	.word	$b38A			; $a0be

fenceTowerSprite4:			; Smallest (furthest) security fence tower
	.word	$b392			; $a0c0
fenceTowerSprite3:
	.word	$b399			; $a0c2
fenceTowerSprite2:
	.word	$b3A7			; $a0c4
fenceTowerSprite1:
	.word	$b3B7			; $a0c6
fenceTowerSprite0:			; Largest (closest) security fence tower
	.word	$b3D4			; $a0c8

; All the sprites for the hostage houses
houseSpriteTable:
	.word	$b3F7			; $a0ca	Normal house
	.word	$b57A			;		House on fire

houseSillSprite:			; The white strip along the bottom of the house
	.word	$b6FD			; $a0ce

houseDebrisSprite:			; The debris in front of a burning house
	.word	$b707			; $a0d0

houseFireSprites:
	.word	$b70D			; $a0d2	Fire animation (Frame 1)
	.word	$b719			; $a0d4 Fire animation (Frame 2)


; A list of pointers to all the font glyphs
fontGraphicsTable:		; $a0d6
	.word	$b725		; 0
	.word	$b72E		; 1
	.word	$b737		; 2
	.word	$b740		; 3
	.word	$b749		; 4
	.word	$b752		; 5
	.word	$b75B		; 6
	.word	$b764		; 7
	.word	$b76D		; 8
	.word	$b776		; 9


hudBubbleSprite:			; The little bubbles next to the HUD numbers
	.word $b77f				; $a0ea

hudBackgroundBubbleSprite:	; The black background on the HUD numbers
	.word $b78F				; $a0ec



; A list of pointers to all the title graphic pieces
titleGraphicsTable:		; $a0ee
	.word	$b7c7		; Your Mission: Rescue Hostages $a0ee
	.word	$b943		; Choplifter logo			$a0f0
	.word	$ba70		; Broderbund Presents		$a0f2
	.word	$bba6		; Dan Gorlin logo			$a0f4
	.word	$bc85		; The End					$a0f6
	.word	$bcf0		; Broderbund crown logo		$a0f8

sortieGraphicsTable:	; $a0fa
	.word	$bd5b		; First Sortie				$a0fa
	.word	$be02		; Second Sortie				$a0fc
	.word 	$beb8		; Third Sortie				$a0fe


.org $a100

; 2 unused bytes
.byte $00,$00


.org $a102

; Actual graphics data is loaded here
; I assume graphics run from $a102 - $beff inclusive. It may be a little less, but this definitely
; covers the memory region of the highest sprite struct, and it conveniently stops short of ProDOS.
