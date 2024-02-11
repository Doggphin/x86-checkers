;;;     BRENDAN LANCASTER WAS HERE ON 4/28/22
;;;     
;;;     Library for drawing pixels and sprites to the screen.
;;;         A "sprite" is defined as two horizontally interlaced 8x8 bitmaps.
;;;         0,0, 0,1, 1,0 and 1,1 within a bitmap pair will correspond to different colors.
;;;         Sprites can be reused by flipping them along their X axis in some functions.
;;;         (I didn't add Y flipping because checkers didn't use enough sprites that would make use of it, but would be a to-do)
;;;
;;;     Standalone library.

.MODEL small, stdcall

.DATA

	MOV AX, @data
	MOV DS, AX

.CODE

;;; Self
    ; Draws a single pixel to the screen.
        DrawPixel       PROTO   posX:WORD, posY:WORD, color:BYTE
    ; Draws a sprite to the screen.
        DrawSprite      PROTO   posX:WORD, posY:WORD, spriteID:WORD, isFlipped:BYTE, paletteADDR:WORD, spritesADDR:WORD

; --------------------------------------------------------------------------------------
; Initializes video mode and background.
; --------------------------------------------------------------------------------------

Initialize      PROC USES AX

    MOV AH, 00H     ; Initialize "Set video mode" function
    MOV AL, 13H     ; Select 13H as video mode (320x200, 256 colors, no pages)
    INT 10H

    RET

Initialize ENDP

; --------------------------------------------------------------------------------------
; Draws a single pixel to the screen.
;
; PARAMETERS:
; posX      is the X position to write to.
; posY      is the Y position to write to.
; color     is the color to set the pixel to.
; --------------------------------------------------------------------------------------

DrawPixel PROC USES AX BX CX DX,    posX:WORD, posY:WORD, color:BYTE

    MOV AH, 0CH     ; Initialize "Write graphics pixel" function
    MOV AL, color   ; Set AL to color of pixel to be drawn
    MOV BH, 00H     ; Set page number to default since 13H can't use them
    MOV CX, posX    ; Set CX to X position of pixel to draw
        ADD CX, 48      ; Illegal position correction since I don't have the time to split boardOffset
    MOV DX, posY    ; Set DX to Y position of pixel to draw
    INT 10h

    ; Uncomment these to see pixels being drawn in real time.
    ;MOV CX, 35000
    ;TestLoop:
    ;    PUSH CX
    ;    MOV CX, 5
    ;    InnerTestLoop:
    ;        LOOP InnerTestLoop
    ;    POP CX
    ;    Loop TestLoop

    RET

DrawPixel ENDP

; --------------------------------------------------------------------------------------
; Draws a sprite to the screen.
;
; PARAMETERS:
; posX          is the X slot position, starting from the top left of the screen.
; posY          is the Y slot position, starting from the top left of the screen.
; spriteID      is the "ID" of the sprite to be drawn (sprites are labelled in comments).
; isFlipped     is a boolean that determines if the sprite should be drawn in reverse upon the X axis.
;   paletteADDR   is a 3 byte array describing the colors to use for the sprite. 
;   spriteADDR    is the beginning pointer of the sprite database.
; --------------------------------------------------------------------------------------
DrawSprite PROC USES AX BX CX DX SI,    posX:WORD, posY:WORD, spriteID:WORD, isFlipped:BYTE, paletteADDR:WORD, spriteADDR:WORD

    ; Get sprite location from spriteID
    MOV SI, spriteADDR
    MOV AX, 16          ; Sprites take up 16 bytes each
    IMUL spriteID       ; Multiply ID by 16 bytes
    ADD SI, AX          ; Move the stack index to result

    MOV CH, 8           ; Initialize CX (loop condition) as amount of rows in a sprite
    MOV DH, 0           ; DH is Y offset
    MOV DL, 8           ; DL is X offset  
    CMP isFlipped, 0    ; Check if flipped
        JE DrawRowLoop
        MOV DL, 1           ; If flipped, start from the left instead of the right

    DrawRowLoop:
        PUSH CX             ; Save CX register (rows left)
        MOV CH, 8           ; Initialize CX (loop condition) as amount of pixels in row
        MOV CL, 0           ; Use CL as bit shift counter (how much to move the masked value to the right so it's least sig bit)
        MOV BL, 00000001b   ; Use BL as bit mask for bitmaps, start on right
        
        DrawColumnLoop:
            ; Load bitmaps from memory
            MOV AH, [SI]        ; Load bitmap 1 into AH
            MOV AL, [SI+1]      ; Load bitmap 2 into AL

            ; Get palette ID and store in AL
            AND AH, BL          ; Apply bitmask to bitmap 1
            AND AL, BL          ; Apply bitmask to bitmap 2
            SHR AL, CL          ; Shift AL to the right CL times (full right)
            SHR AH, CL          ; Shift AH to the right CL times (full right)
            SHL AH, 1           ; Shift AH over to the left once
            OR AL, AH           ; Combine AL and AH, result color is stored in AL.

            ; Store coordinates as (BX,CX) = (posX + DL, posY + DH)
            PUSH BX             ; Push BX (bitmap and bitmask), will be temporary Y position
            PUSH CX             ; Push CX (pixels left in row), will be temporary X position
            MOV BX, posX        ; Store X position in BX
            MOV CX, posY        ; Store Y position in CX
            SHL BX, 1           ; Multiply BX and CX by 8
            SHL BX, 1           ; I wish CL wasn't taken here
            SHL BX, 1
            SHL CX, 1           
            SHL CX, 1
            SHL CX, 1
            ADD BL, DL          ; Add X offset
            ADD CL, DH          ; Add Y offset

            ; Load palette
            PUSH SI             ; Push SI (sprite pointer) to stack
            PUSH DX             ; Push DX (X offset) to stack
            MOV SI, paletteADDR ; Load palette colors start index into SI

            ; Print resultant color at position
            CMP AL, 0           ; If bitmaps combined into 0, skip pixel
                JE FinishPixel    
            CMP AL, 1           ; If bitmaps combined into 1, draw color1
                JE DrawColor1        
            CMP AL, 2           ; If bitmaps combined into 2, draw color2
                JE DrawColor2        
            JMP DrawColor3      ; Bitmaps combined must be 3, draw color3
            DrawColor1:
                MOV DL, [SI]
                INVOKE DrawPixel, BX, CX, DL
                JMP FinishPixel
            DrawColor2:
                MOV DL, [SI+1]  
                INVOKE DrawPixel, BX, CX, DL
                JMP FinishPixel
            DrawColor3:
                MOV DL, [SI+2]
                INVOKE DrawPixel, BX, CX, DL
                JMP FinishPixel
            FinishPixel:        ; Drop out of print section

            ; Advance position, bit shift counter and bitmask for next pixel and restore registers
            POP DX              ; Restore DL (X offset) (DH isn't used)
            POP SI              ; Restore SI (sprite address)
            POP CX              ; Restore CX (pixels left in row)
            POP BX              ; Restore BX (bitmap and bitmask)

            INC CL              ; Increment bit shift counter
            SHL BL, 1           ; Move Bitmask left by one
            DEC DL              ; Move PositionX left by one
            CMP isFlipped, 0    ; Check if flipped
                JE ContinueToEndColumnLoop
                ADD DL, 2           ; If flipped, move X position right instead of left
            ContinueToEndColumnLoop:

            DEC CH              ; Decrease loop condition
            JNZ DrawColumnLoop  ; Loop to next pixel

        ADD SI, 2           ; Advance to next rows of sprite's bitmap
        INC DH              ; Move printer down a pixel
        POP CX              ; Recover CX register (rows left)
        ADD DL, 8           ; Return printer to the right side of the sprite
        CMP isFlipped, 0
            JE ContinueToEndRowLoop
            SUB DL, 16          ; If flipped, start on the right side instead of the left
        ContinueToEndRowLoop:

        DEC CH          ; Decrease loop condition 
        JNZ DrawRowLoop ; Start drawing next line

    RET

DrawSprite ENDP

; --------------------------------------------------------------------------------------
; Draws a 2x2 sprite to the screen.
;
; Sprites must be laid out consecutively within SPRITE_MARKER in order of:
; Top left (REQUIRED)
; Top right (optional, can be flipped version of top left)
; Bottom left (REQUIRED)
; Bottom right (optional, can be flipped version of bottom left)
;
; posX              is the X slot position, starting at the top left of the sprite.
; posY              is the Y slot position, starting at the top left of the sprite.
; spriteID          is the "ID" of the start of the sprite to be drawn (sprites are labelled in comments).
; flipTop           is a boolean value for if this sprite reuses its top left sprite by flipping it along the X axis for its top right.
; flipBot           is a boolean value for if this sprite reuses its bot left sprite by flipping it along the X axis for its bot right.
;   paletteADDR       is a 3 byte array describing the colors to use for the sprite.
;   startSpriteID     is the "index" of the beginning of the 2x2 sprite to be drawn that will be incremented.
;   spriteADDR        is the beginning pointer of the sprite database.
; --------------------------------------------------------------------------------------

Draw2x2Sprite PROC USES DX BX CX DI AX,     posX:BYTE, posY:BYTE, startSpriteID:WORD, paletteID:BYTE, flipTop:BYTE,
                                            flipBot:BYTE, paletteADDR:WORD, spritesADDR:WORD

    ; Move starting values to registers as they'll be incremented   
    MOV CX, startSpriteID
        XOR DX, DX
    MOV DL, posX        ; Store posX in DL
        XOR BX, BX
    MOV BL, posY        ; Store posY in BL
    PUSH AX
        MOV DI, paletteADDR ; Point DI at palettes
            MOV AL, 3
            IMUL paletteID
        ADD DI, AX          ; Move DI to palette ID
    POP AX                 
    DrawTopLeft:
    INVOKE DrawSprite,  DX, BX, CX, 0, DI, spritesADDR

    CMP flipTop, 1      ; Check if top is flippable
        JE DrawTopRight     ; If top can be flipped, hold sprite index
        INC CX              ; If top has a separate sprite, advance sprite index
    DrawTopRight:
    INC DX              ; Move to (1, 0)
    INVOKE DrawSprite,  DX, BX, CX, flipTop, DI, spritesADDR

    INC CX              ; Advance sprite index
    DEC DX              ; Move to (0, 1)
    INC BX
    INVOKE DrawSprite,  DX, BX, CX, 0, DI, spritesADDR

    CMP flipBot, 1
        JE DrawBotRight     ; If bottom can be flipped, hold sprite index
        INC CX              ; If bottom has a separate sprite, advance sprite index  
    DrawBotRight:       
    INC DX              ; Move to (1, 1)
    INVOKE DrawSprite,  DX, BX, CX, flipBot, DI, spritesADDR

    RET

Draw2x2Sprite ENDP

; --------------------------------------------------------------------------------------
; Gets the screen coordinates of a tile index and returns it in AX.
;
; PARAMETERS:
; tileIndex			is the index to find the coordinates of.
;   boardOffset		is the amount the board is initially shifted from the top left corner.
;
; RETURNS:
; AL = x position of the tile.
; AH = y position of the tile.
; --------------------------------------------------------------------------------------

GetCoordinates PROC USES BX, tileIndex:BYTE, boardOffset:BYTE

	; Clear out registers to be used
	XOR BX, BX			; Probably not necessary
	XOR AX, AX

	; Y position on board can be gotten by dividing the index by four.
	; Do this by shifting it right twice
	; Find Y coordinate
	MOV AH, tileIndex	; Stick the tile's index in AH
	SHR AH, 1			; Divide it by two
	SHR AH, 1			; Divide it by two again

	; X position would normally be found by getting the remainder of dividing the index by four.
	; The checkerboard has a zigzag pattern to it though, so if on an odd Y position, move to the right one.
	; Find X coordinate
	MOV AL, tileIndex	; Stick the tile's index in AL
	AND AL, 00000011b	; Single out 0-3 from the tileIndex
	MOV BH, AH			; Temporarily store Y coordinate in BX
	AND BH, 00000001b	; Check if Y coordinate uses a 1
	ADD AL, BH			; Add that 1 to the X coordinate (or do nothing)

	; Shift X over by a variable amount to add spacing between tiles
	MOV BL, tileIndex	; Stick the tile's index in BL
	AND BL, 00000011b	; Get 0-3 for the "x index" of the tile
	ADD AL, BL			; Add it to the cumulative x position

	ADD AH, AH			; Multiply x and y by two since these are all 2x2 sprites
	ADD AL, AL
	ADD AH, boardOffset	; Add board offset to x and y
	ADD AL, boardOffset

	RET

GetCoordinates ENDP

END 