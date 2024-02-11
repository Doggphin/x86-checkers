;;;     BRENDAN LANCASTER WAS HERE ON 4/27/22
;;;
;;;     Main file for the checkers game.
;;;     Contains sprite bitmaps for checkers, checkerboard slots,
;;;     palettes, position pointer and uses some external libraries.
;;;
;;;     To assemble, link, and run:
;;; 	    MASM projectGAM.asm
;;; 	    MASM projectGFX.asm
;;; 	    MASM projectCHK.asm
;;;         MASM projectDRW.asm
;;;         LINK projectGAM.obj projectGFX.obj projectCHK.obj projectDRW.obj
;;;         projectGAM

.MODEL small, stdcall
.STACK 256

.DATA
    ; ============================================================
    ; CONSTANTS
    ; ============================================================

        BOARD_OFF       BYTE 4

    ; ============================================================
    ; DATA CACHES
    ; ============================================================

        BOARD_PTR               BYTE 32 dup(0)      ; Contains a 4x8 array representation of checkerboard slots

        ; 0 = Selecting checkers
        MENU_STATE          BYTE 0

    ; ============================================================
    ; PALETTES
    ; Sets of three bytes each used as address references for
    ; coloring sprites.
    ; ============================================================

    ; Checkers palettes
        COLOR_PTR           BYTE 37H, 01H, 68H      ; Blue shade gradient   [0]
        ;COLOR_CHKR_ENMY     BYTE 0CH, 04H, 70H      ; Red shade gradient    [1]
        COLOR_HILI_ENMY     BYTE 2BH, 2AH, 06H      ; Orange shade gradient [1]
        COLOR_TILE_NRML     BYTE 13H, 12H, 11H      ; Black shade gradient  [2]
        ;COLOR_TILE_NRML     BYTE 3BH, 25H, 05H      ; Pink shade gradient   [2]
        ;COLOR_TILE_ALTR     BYTE 1FH, 1EH, 1DH      ; White shade gradient  [3]
        ;COLOR_TILE_ALTR     BYTE 64H, 4CH, 4DH      ; Cyan shade gradient   [3]
        COLOR_CHKR_ALTR     BYTE 0CH, 04H, 70H      ; Red shade gradient    [3]
        COLOR_HILI          BYTE 5CH, 43H, 2BH      ; Gold shade graident   [4]
        COLOR_HILI_GREY     BYTE 1EH, 1DH, 1CH      ; Light grey shade gradient  [5]
        ;COLOR_HILI_DARK     BYTE 14H, 13H, 12H      ; Dark grey shade gradient   [6]
        COLOR_HILI_WHIT     BYTE 18H, 17H, 16H      ; Light grey shade gradient  [6]
        COLOR_HILI_GREN     BYTE 0AH, 2FH, 02H      ; Light green shade gradient [7]
        COLOR_HILI_FADE     BYTE 74H, 8CH, 0A4H     ; Faded gold shade gradient [8]
        COLOR_BACK          BYTE 12H, 1DH, 22H   ; Brendan was here! [9]

    ; ============================================================
    ; SPRITES
    ; Layouts for the colors to use for a sprite. All sprites are made
    ; of two 8x8 bitmaps to define a 4 color 8x8 sprite. 0,0 is always
    ; transparent.
    ; ============================================================

    ; [0] Checker top left AND right    [CHECKER 2x2]
        SPRIT_PTR BYTE 00000000b, 00000000b
        db 00000111b, 00000111b
        db 00011100b, 00011011b
        db 00100000b, 00111111b
        db 01000011b, 01111111b
        db 01000100b, 00111011b
        db 10001000b, 11111111b
        db 10001000b, 11111111b
    ; [1] Checker bot left AND right
        db 10001000b, 11111111b
        db 11000100b, 10111011b
        db 01100001b, 00011110b
        db 01110000b, 01001111b
        db 00111100b, 00100011b
        db 00011111b, 00011000b
        db 00000111b, 00000111b
        db 00000000b, 00000000b
    ; [2] Tile top left                 [TILE 2x2]
        db 11111111b, 11111111b
        db 11111100b, 10100011b
        db 11111001b, 11000110b
        db 11110011b, 10001100b
        db 11100111b, 10011000b
        db 11001110b, 10110001b
        db 10011101b, 11100010b
        db 10111011b, 11000100b
    ; [3] Tile top right
        db 11111111b, 11111111b
        db 11101111b, 00010001b
        db 11011111b, 00101001b
        db 10110111b, 01011101b
        db 01111111b, 10001001b
        db 11111111b, 00000001b
        db 11111111b, 00000001b
        db 11111111b, 00000011b
    ; [4] Tile bottom left
        db 11110111b, 10001001b
        db 11101110b, 10010011b
        db 11011111b, 10100001b
        db 10111111b, 11000000b
        db 11111111b, 10000000b
        db 11111111b, 10000000b
        db 11111111b, 10010001b
        db 11111111b, 11111111b
    ; [5] Tile bottom right
        db 11111101b, 00000111b
        db 11111011b, 10001101b
        db 11110111b, 00011001b
        db 11101111b, 00111001b
        db 11010111b, 01111101b
        db 10111111b, 11001001b
        db 01111111b, 10000001b
        db 11111111b, 11111111b
    ; [6] King top left                 [KING 2x2]
        db 00000111b, 00000111b
        db 00011100b, 00011011b
        db 00100000b, 00111111b
        db 01001000b, 01110111b
        db 01001101b, 00111010b
        db 10001111b, 11111111b
        db 10000111b, 11111111b
        db 10000111b, 11111110b
    ; [7] King top right
        db 11100000b, 11100000b
        db 00111000b, 11011000b
        db 00000100b, 11111100b
        db 10010010b, 01101110b
        db 10110010b, 11011100b
        db 11110001b, 11111111b
        db 11100001b, 11111111b
        db 11100000b, 01111111b
    ; [8] King bot left AND right
        db 11000011b, 10111110b
        db 11100010b, 10011101b
        db 11110000b, 01001111b
        db 11111100b, 10000011b
        db 01111111b, 01011000b
        db 00111111b, 00100011b
        db 00011111b, 00011000b
        db 00000111b, 00000111b
    ; [9] Highlight top left AND right  [HIGHLIGHT 2x2]
        db 00111000b, 11001000b
        db 01100000b, 10100000b
        db 11000000b, 01000000b
        db 10000000b, 00000000b
        db 10000000b, 10000000b
        db 00000000b, 00000000b
        db 00000000b, 00000000b
        db 00000000b, 00000000b
    ; [10] Highlight bot left AND right
        db 00000000b, 00000000b
        db 00000000b, 00000000b
        db 00000000b, 00000000b
        db 10000000b, 10000000b
        db 10000000b, 00000000b
        db 11000000b, 01000000b
        db 01100000b, 10100000b
        db 00111000b, 11001000b
    ; [11] Signature 1
        db 00000000b, 00000000b
        db 01100000b, 00000000b
        db 01010000b, 00000000b
        db 01100010b, 00000000b
        db 01010100b, 00000000b
        db 01110100b, 00000000b
        db 00000000b, 00000000b 
        db 00000000b, 00000000b
    ; [12] Signature 2
        db 00000000b, 00000000b
        db 00000000b, 00000000b
        db 01100000b, 00000000b
        db 10101100b, 00000000b
        db 11001010b, 00000000b
        db 01101010b, 00000000b
        db 00000000b, 00000000b
        db 00000000b, 00000000b
    ; [13] Signature 3
        db 00000000b, 00000000b
        db 00100000b, 00000000b
        db 00100000b, 00000000b
        db 01100110b, 00000000b
        db 10101010b, 00000000b
        db 11101110b, 00000000b
        db 00000000b, 00000000b
        db 00000000b, 00000000b
    ; [14] Signature 4
        db 00000000b, 00000000b
        db 00000000b, 00000000b
        db 00000000b, 00000000b
        db 11000101b, 00000000b
        db 10100111b, 00000000b
        db 10100111b, 00000000b
        db 00000000b, 00000000b
        db 00000000b, 00000000b
    ; [15] Signature 5
        db 00000000b, 00000000b
        db 00000000b, 00000000b
        db 00000011b, 00000000b
        db 00110110b, 00000000b
        db 01010011b, 00000000b
        db 01110110b, 00000000b
        db 00000000b, 00000000b
        db 00000000b, 00000000b
    ; [16] Signature 6
        db 00000000b, 00000000b
        db 00100000b, 00000000b
        db 00100001b, 00000000b
        db 00110010b, 00000000b
        db 00101011b, 00000000b
        db 00101001b, 00000000b
        db 00000000b, 00000000b
        db 00000000b, 00000000b
    ; [16] Signature 7
        db 00000000b, 00000000b
        db 00000000b, 00000000b
        db 10000011b, 00000000b
        db 10010101b, 00000000b
        db 00100110b, 00000000b
        db 10100011b, 00000000b
        db 00000000b, 00000000b
        db 00000000b, 00000000b
    ; [17] Pure color
        db 11111111b, 00000000b
        db 11111111b, 00000000b
        db 11111111b, 00000000b
        db 11111111b, 00000000b
        db 11111111b, 00000000b
        db 11111111b, 00000000b
        db 11111111b, 00000000b
        db 11111111b, 00000000b

.CODE
    ; ============================================================
    ; EXTERNAL FUNCTION REFERENCES
    ; ============================================================
    
    ;;; Graphics
        ; Sets up video mode.
            Initialize          PROTO

    ;;; Checkers - Controls checkers on BOARD_PTR
        ; Starts the board from scratch.
            InitializeBoard     PROTO   boardADDR:WORD

    ;;; Drawer - Draws board graphics.
        ; Draws the entire board.
        	DrawAllPositions 	PROTO   boardADDR:WORD, palettesADDR:WORD, spritesADDR:WORD, boardOffset:BYTE
        ; Draws background visuals
            DrawBackground      PROTO   palettesADDR:WORD, spritesADDR:WORD

    ;;; UI - User interface AND input
        ; Magical function to take player input and do everything with it
            StartPlayerTurn     PROTO   boardADDR:WORD, palettesADDR:WORD, spritesADDR:WORD, boardOffset:BYTE,
                                        team:BYTE

Start:
	MOV AX, @data
	MOV DS, AX

    ; Initialize video mode
    INVOKE Initialize

    ; Start a new checkers game
    GameLoop:
        INVOKE InitializeBoard, ADDR BOARD_PTR
        INVOKE DrawAllPositions, ADDR BOARD_PTR, ADDR COLOR_PTR, ADDR SPRIT_PTR, BOARD_OFF
        INVOKE DrawBackground, ADDR COLOR_PTR, ADDR SPRIT_PTR    ; I was here!

        ; Take turns between players
        MOV CL, 1       ; CL will control which player's turn it is (1 = Blue, 2 = Orange)
        TurnLoop:
            INVOKE StartPlayerTurn, ADDR BOARD_PTR, ADDR COLOR_PTR, ADDR SPRIT_PTR, BOARD_OFF, CL
            CMP AL, 1       ; Check if player won
                JE GameEnd      ; If so, break out of TurnLoop
            XOR CL, 3       ; Flip CL from 1 to 2 or vice versa
            JMP TurnLoop    ; Start next turn

        GameEnd:
            JMP GameLoop    ; Restart the board

Stop:
	MOV AX, 04C00H
	INT 21H

END Start