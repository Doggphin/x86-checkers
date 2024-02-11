;;;     BRENDAN LANCASTER WAS HERE ON 4/30/22
;;;     
;;;		Library for communicating between graphics and checkers libraries.
;;;
;;;     Requires projectGFX and projectCHK to function.

	.MODEL small, stdcall
	
	.CODE
		;;; Graphics
	    ; Draws four sprites together at positionX, positionY to the screen. Uses sprite space (x8) as coordinates.
        	Draw2x2Sprite   	PROTO 	posX:BYTE, posY:BYTE, startSpriteID:WORD, paletteID:BYTE,
										flipTop:BYTE, flipBot:BYTE, paletteADDR:WORD, spritesADDR:WORD
		; Draws a sprite to the screen.
        	DrawSprite      PROTO   posX:WORD, posY:WORD, spriteID:WORD, isFlipped:BYTE, paletteADDR:WORD, spritesADDR:WORD
		; Converts a tile index into sprite coordinates and stores it in AX.
			GetCoordinates 		PROTO 	tileIndex:BYTE, boardOffset:BYTE

		;;; Checkers
			; Returns the index of a given length from a starting index.
            	GetMoveIndex        PROTO   index:BYTE, direction:BYTE, boardADDR:WORD
			; Returns the length that a piece can be moved in a given direction from a starting index.
            	GetAllowedDistance  PROTO   tileIndex:BYTE, direction:BYTE, boardADDR:WORD

		;;; Self
		; Draws what's at tile[tileIndex] to the screen's board.
			DrawBoardIndex 		PROTO 	tileIndex:BYTE, boardADDR:WORD, palettesADDR:WORD, spritesADDR:WORD, boardOffset:BYTE
		; Draws the initial board.
			DrawAllPositions 	PROTO 	boardADDR:WORD, palettesADDR:WORD, spritesADDR:WORD, boardOffset:BYTE
		; Finds all possible moves from this location and draws its type to each location. Returns whether it found anything.
            DrawPossibleMoves   PROTO   selectedIndex:BYTE, boardADDR:WORD, palettesADDR:WORD, spritesADDR:WORD,
                                        boardOffset:BYTE, drawType:BYTE, moveMask:BYTE
        ; Draws a highlight to the screen of either (clear out), grey, gold or red at a given location.
            DrawHighlight            PROTO   index:BYTE, drawType:BYTE, boardADDR:WORD, palettesADDR:WORD,
                                        spritesADDR:WORD, boardOffset:BYTE

; --------------------------------------------------------------------------------------
; I WAS HERE!
; last minute background additions
; --------------------------------------------------------------------------------------

DrawBackground PROC USES SI DI CX AX BX, palettesADDR:WORD, spritesADDR:WORD

	MOV DI, palettesADDR
	ADD DI, 26
	MOV CX, 11
	MOV BX, 3
	DrawSignatureLoop:
		INVOKE DrawSprite, BX, 21, CX, 0, DI, spritesADDR
		ADD BX, 1
		ADD CX, 1
		CMP CX, 18
			JE EndDrawSignature
		JMP DrawSignatureLoop
	EndDrawSignature:
	INC DI
	MOV CX, 18
	MOV BX, 3
	DrawBotBorderLoop:
		INVOKE DrawSprite, BX, 20, 18, 0, DI, spritesADDR
		ADD BX, 1
		LOOP DrawBotBorderLoop

	MOV CX, 18
	MOV BX, 3
	DrawTopBorderLoop:
		INVOKE DrawSprite, BX, 3, 18, 0, DI, spritesADDR
		ADD BX, 1
		LOOP DrawTopBorderLoop

	MOV CX, 16
	MOV BX, 4
	DrawLeftBorderLoop:
		INVOKE DrawSprite, 3, BX, 18, 0, DI, spritesADDR
		ADD BX, 1
		LOOP DrawLeftBorderLoop

	MOV CX, 16
	MOV BX, 4
	DrawRightBorderLoop:
		INVOKE DrawSprite, 20, BX, 18, 0, DI, spritesADDR
		ADD BX, 1
		LOOP DrawRightBorderLoop

	RET

DrawBackground ENDP

; --------------------------------------------------------------------------------------
; Draws the entire board and its contents to the screen.
;
; PARAMETERS:
; 	boardADDR			is the address of BOARD in .data of prjctGAM (BOARD).
; 	palettesADDR      is the address of the beginning of palettes (COLOR_PTR).
; 	spritesADDR		is the beginning of the sprite database (SPRITE_PTR).
; boardOffset		is the initial offset of the board (BOARD_OFF).
; --------------------------------------------------------------------------------------

DrawAllPositions PROC USES CX BX DX DI, boardADDR:WORD, palettesADDR:WORD, spritesADDR:WORD, boardOffset:BYTE

	XOR BX, BX	; Will be used as X coordinate
	XOR DX, DX	; Will be used as Y coordinate

	MOV CL, 32
    DrawLoop:
        DEC CL

		; First, draw the position 
        INVOKE DrawBoardIndex, CL, boardADDR, palettesADDR, spritesADDR, boardOffset

		; Next, draw the background to its right
		INVOKE GetCoordinates, CL, boardOffset
		MOV BL, AL				; Set BX to X coordinate
		ADD BX, 2				; Shift x coordinate over by a sprite to the right
		MOV DL, AH				; Set DX to Y coordinate
			MOV CH, 00000111b
			AND CH, CL
			CMP CH, 7				; Check if this tile index ends with 7
				JE DrawAllPositionsFlip	; If so, move it to the left end of the board
				JMP DrawAllPositionsEnd
				DrawAllPositionsFlip:
					SUB BX, 16				; Move the tile left by 16 sprites
					JMP DrawAllPositionsEnd
				DrawAllPositionsEnd:

		INVOKE Draw2x2Sprite, BL, DL, 2, 3, 0, 0, palettesADDR, spritesADDR

		CMP CL, 0
        JNZ DrawLoop
	
	RET

DrawAllPositions ENDP

; --------------------------------------------------------------------------------------
; Draws a tile's contents to the screen.
;
; PARAMETERS:
; tileIndex			is the index within BOARD to update.
; 	boardADDR			is the address of BOARD in .data of prjctGAM.
; 	palettesADDR      is the address of the beginning of palettes (COLR_CHKR_PLYR)
; --------------------------------------------------------------------------------------

DrawBoardIndex PROC USES AX CX SI DI,	tileIndex:BYTE, boardADDR:WORD, palettesADDR:WORD, spritesADDR:WORD, boardOffset:BYTE

	INVOKE GetCoordinates, tileIndex, boardOffset
	; Make CL = X position, CH = Y position
	XOR CX, CX
	MOV CL, AL
	MOV CH, AH

	; Point SI at the board slot to draw and DI at the beginning of palettes
	MOV SI, boardADDR		; Move SI to BOARD
		XOR AX, AX
		MOV AL, tileIndex
	ADD SI, AX				; Add tileIndex to SI to start pointing at the tile's byte to draw

	; Draw underlying dark tile
	INVOKE Draw2x2Sprite, CL, CH, 2, 2, 0, 0, palettesADDR, spritesADDR

	; Next, check what to draw on top of it.
	MOV AL, [SI]
	CMP AL, 0		; 0 = empty
		JE EndDrawBoardIndex
	CMP AL, 1		; 1 = player checker
		JE DrawBoardIndexPLYRCHKR
	CMP AL, 2		; 2 = player king
		JE DrawBoardIndexPLYRKING
	CMP AL, 3		; 3 = enemy king
		JE DrawBoardIndexENMYCHKR
	; Otherwise this is 4, draw an enemy king
		JMP DrawBoardIndexENMYKING

	DrawBoardIndexPLYRCHKR:
		;ADD DI, 0	; Use palette 0, 3*0 bytes forward (player)
		INVOKE Draw2x2Sprite, CL, CH, 0, 0, 1, 1, palettesADDR, spritesADDR
		JMP EndDrawBoardIndex
	DrawBoardIndexPLYRKING:
		;ADD DI, 0	; Use palette 0, 3*0 bytes forward (player)
		INVOKE Draw2x2Sprite, CL, CH, 6, 0, 0, 1, palettesADDR, spritesADDR
		JMP EndDrawBoardIndex
	DrawBoardIndexENMYCHKR:
		ADD DI, 3	; Use palette 1, 3*1 bytes forward (enemy)
		INVOKE Draw2x2Sprite, CL, CH, 0, 1, 1, 1, palettesADDR, spritesADDR
		JMP EndDrawBoardIndex
	DrawBoardIndexENMYKING:
		ADD DI, 3	; Use palette 1, 3*1 bytes forward (enemy)
		INVOKE Draw2x2Sprite, CL, CH, 6, 1, 0, 1, palettesADDR, spritesADDR
		;JMP EndDrawBoardIndex
	
	EndDrawBoardIndex:

    RET

DrawBoardIndex ENDP

; --------------------------------------------------------------------------------------
; Finds all possible moves from this location and draws its type to each location. Returns whether it found anything.
;
; PARAMETERS:
; selectedIndex     is the base point to find locations from.
;   boardADDR			is the address of BOARD in .data of prjctGAM (BOARD).
;   palettesADDR      is the address of the beginning of palettes (COLOR_PTR).
;   spritesADDR		is the beginning of the sprite database (SPRITE_PTR).
;   boardOffset		is the initial offset of the board (BOARD_OFF).
; drawType          is the ID of what to draw at this location. 0 = clear, 1 = grey highlight, 2 = gold highlight, 3 = red highlight.
;
; RESULTS:
; AL = whether any moves were drawn.
; --------------------------------------------------------------------------------------

DrawPossibleMoves PROC USES CX BX DX, selectedIndex:BYTE, boardADDR:WORD, palettesADDR:WORD, spritesADDR:WORD, boardOffset:BYTE, drawType:BYTE, moveMask:BYTE

    PUSH AX

    MOV CL, 4   ; CL will determine what directions to check
    MOV CH, 0   ; CH is the counter for how many directions were found
    DrawPossibleMovesLoop:
        DEC CL      ; Decrease loop condition

        INVOKE GetMoveIndex, selectedIndex, CL, boardADDR   ; Get index move would send player to
        CMP AL, 32   ; Check if directional move was invalid
            JNE DrawPossibleMovesContinue       ; If AL is not 32, continue as normal
            JMP DrawPossibleMovesLoopEnd        ; If AL is 32, skip this direction

        DrawPossibleMovesContinue:

            CMP moveMask, 2
                JNE ContinueAfterMask
                PUSH AX
                    INVOKE GetAllowedDistance, selectedIndex, CL, boardADDR
                    MOV DL, AL
                POP AX
                    CMP DL, 2   ; Check if magnitude was 2
                        JNE DrawPossibleMovesLoopEnd    ; If not, move doesn't count, skip it
            ContinueAfterMask:
                INC CH      ; Valid move found; increment CH.
                MOV BL, AL  ; Move AL (move's tile index) to BL for use in further procedures
                INVOKE DrawHighlight, BL, drawType, boardADDR, palettesADDR, spritesADDR, boardOffset

    DrawPossibleMovesLoopEnd:
    CMP CL, 0   ; Loop condition
        JNZ DrawPossibleMovesLoop   ; If not 0, check next direction


    POP AX
    MOV AL, CH

    RET

DrawPossibleMoves ENDP

; --------------------------------------------------------------------------------------
; Draws a highlight to the screen of either (clear out), grey, gold or red at a given location.
;
; PARAMETERS:
; selectedIndex     is the index to draw on.
; drawType          is the ID of what to draw at this location. 0 = clear, 1 = grey highlight, 2 = gold highlight, 3 = red highlight.
;   boardADDR			is the address of BOARD in .data of prjctGAM (BOARD).
;   palettesADDR      is the address of the beginning of palettes (COLOR_PTR).
;   spritesADDR		is the beginning of the sprite database (SPRITE_PTR).
;   boardOffset		is the initial offset of the board (BOARD_OFF).
; --------------------------------------------------------------------------------------

DrawHighlight PROC USES AX CX, index:BYTE, drawType:BYTE, boardADDR:WORD, palettesADDR:WORD, spritesADDR:WORD, boardOffset:BYTE

    INVOKE GetCoordinates, index, boardOffset
    MOV CL, AL  ; Switch coordinates to using (CL, CH) for further procedure calls
    MOV CH, AH
    ;DrawHighlight0:
        CMP drawType, 0 ; If 0, clear the index
            JNE DrawHighlight1
            INVOKE DrawBoardIndex, index, boardADDR, palettesADDR, spritesADDR, boardOffset
            JMP DrawHighlightEnd
    DrawHighlight1:
        CMP drawType, 1 ; If 1, draw a grey highlight
            JNE DrawHighlight2
            INVOKE Draw2x2Sprite, CL, CH, 9, 6, 1, 1, palettesADDR, spritesADDR
            JMP DrawHighlightEnd
    DrawHighlight2:
        CMP DrawType, 2 ; If 2, draw a gold highlight
            JNE DrawHighlight3
            INVOKE Draw2x2Sprite, CL, CH, 9, 4, 1, 1, palettesADDR, spritesADDR
            JMP DrawHighlightEnd
    DrawHighlight3:
        CMP DrawType, 3 ; If 3, draw a red highlight
            JNE DrawHighlight4
            INVOKE Draw2x2Sprite, CL, CH, 9, 7, 1, 1, palettesADDR, spritesADDR
            JMP DrawHighlightEnd
    DrawHighlight4:
        ; Draw type must be 4, draw a faded gold highlight
            INVOKE Draw2x2Sprite, CL, CH, 9, 8, 1, 1, palettesADDR, spritesADDR
            ; Fall out into DrawHighlightEnd

    DrawHighlightEnd:
    RET

DrawHighlight ENDP

END
