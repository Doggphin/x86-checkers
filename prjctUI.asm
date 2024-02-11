;;;     BRENDAN LANCASTER WAS HERE ON 5/3/22
;;;     
;;;     God library that lets players act a turn and actually calls functions in other libraries.
;;;     Terribly organized, half of this should be in prjctDRW and the other half should be in projctCHK. (no time)
;;;     
;;;     Requires prjctGFX, prjctDRW and projectCHK to function.

.MODEL small, stdcall

.STACK 256

.CODE

    ;;; Graphics
	    ; Converts a tile index into sprite coordinates and stores it in AX (AL, AH)
		    GetCoordinates 		PROTO   tileIndex:BYTE, boardOffset:BYTE
        ; Draws four sprites together at positionX, positionY to the screen. Uses sprite space (x8) as coordinates.
        	Draw2x2Sprite   	PROTO   posX:BYTE, posY:BYTE, startSpriteID:WORD, paletteID:BYTE,
                                        flipTop:BYTE, flipBot:BYTE, paletteADDR:WORD, spritesADDR:WORD

    ;;; Draw
        ; Draws what's at tile[tileIndex] to the screen's board.
			DrawBoardIndex 		PROTO   tileIndex:BYTE, boardADDR:WORD, palettesADDR:WORD,
                                        spritesADDR:WORD, boardOffset:BYTE
        ; Finds all possible moves from this location and draws its type to each location. Returns whether it found anything.
            DrawPossibleMoves   PROTO   selectedIndex:BYTE, boardADDR:WORD, palettesADDR:WORD, spritesADDR:WORD,
                                        boardOffset:BYTE, drawType:BYTE, moveMask:BYTE
        ; Draws a highlight to the screen of either (clear out), grey, gold or red at a given location.
            DrawHighlight            PROTO   index:BYTE, drawType:BYTE, boardADDR:WORD, palettesADDR:WORD,
                                        spritesADDR:WORD, boardOffset:BYTE

    ;;; Checkers
        ; Checks if colliding with a border in a given direction (CCW starting at 0 and right)
            CheckBorder         PROTO   tileIndex:BYTE, direction:BYTE
        ; Returns the length that a piece can be moved in a given direction from a starting index.
            GetAllowedDistance  PROTO   tileIndex:BYTE, direction:BYTE, boardADDR:WORD
        ; Returns the index of BOARD in the direction of 0-3 from a starting point.
            GetIndexInDirection PROTO   tileIndex:BYTE, tileDirection:BYTE
        ; Returns the team of the unit of at a given index (0 = blank, 1 = player, 2 = enemy).
            GetIndexTeam        PROTO   tileIndex:BYTE, boardADDR:WORD
        ; Sets board[index] to a value.
            SetBoardValue       PROTO   index:BYTE, valueToSet:BYTE, boardADDR:WORD
        ; Gets the value at board[index].
            GetBoardValue       PROTO   index:BYTE, boardADDR:WORD
        ; Gets the amount of opposing player's checkers that are alive on the board.
            GetOpposingCount    PROTO   teamAsking:BYTE, boardADDR:WORD
        ; Returns the index of a given length from a starting index.
            GetMoveIndex        PROTO   index:BYTE, direction:BYTE, boardADDR:WORD

    ;;; Self
        ; Reads player input without drawing it to screen.
            GetPlayerInput      PROTO
        ; Starting from a direction, rotates until it reaches the next allowed move from a location.
            GetNextViableDir    PROTO   index:BYTE, startDirection:BYTE, dirToRotate:BYTE, boardADDR:WORD, moveMask:BYTE

; --------------------------------------------------------------------------------------
; A magical function that lets players move a highlight across the board,
; select a checker, generate moves for that checker, choose a move for that checker and
; move the checker. Also walks their dog, cooks their meals, etc.
;
; PARAMETERS:
;   boardADDR			is the address of BOARD in .data of prjctGAM (BOARD).
;   palettesADDR      is the address of the beginning of palettes (COLOR_PTR).
;   spritesADDR		is the beginning of the sprite database (SPRITE_PTR).
;   boardOffset		is the initial offset of the board (BOARD_OFF).
; team              is the player currently taking their turn; 1 = player, 2 = enemy.
;
; RESULTS:
; AL = Did player win? 1: win, 0: did not win
; --------------------------------------------------------------------------------------

StartPlayerTurn PROC USES CX DI BX, boardADDR:WORD, palettesADDR:WORD, spritesADDR:WORD, boardOffset:BYTE, team:BYTE
    LOCAL   direction:BYTE,         ; Controls direction, this direction goes from right counterclockwise; 0 right, 1 up, 2 left, 3 down (4 = E, 5 = Q)
            menuState:BYTE,         ; 0 = Checker select
            selectedIndex:BYTE,     ; Board index currently selected.
            selectedDirection:BYTE, ; Highlighted index's currently selected direction.
            moveMask:BYTE,          ; only allow a certain length of move.
            hasWon:BYTE             ; If 1 on endTurn, return 1.

    PUSH AX     ; Push original AX value to restore AH later

    ; Initially, start the menu state at 0 and selected index (roughly) in the middle.
    MOV hasWon, 0
    MOV menuState, 0
    MOV selectedIndex, 18
    MOV moveMask, 0

    ; First, get player input
    GetPlayerInputLoop:
        INVOKE GetPlayerInput
        CMP AL, 119 ; w
            JE UpClicked
        CMP AL, 87  ; W
            JE UpClicked
        CMP AL, 97  ; a
            JE LeftClicked
        CMP AL, 65  ; A
            JE LeftClicked
        CMP AL, 115 ; s
            JE DownClicked
        CMP AL, 83  ; S
            JE DownClicked
        CMP AL, 100 ; d
            JE RightClicked
        CMP AL, 68  ; D
            JE RightClicked
        CMP AL, 101 ; e
             JE EnterClicked
        CMP AL, 69 ; E
             JE EnterClicked
        CMP AL, 113 ; q
             JE QuitClicked
        CMP AL, 81 ; Q
             JE QuitClicked
        JMP GetPlayerInputLoop  ; Invalid input, check for a valid input.
;       |
        RightClicked:
            MOV direction, 0
            JMP CheckMenuState
        UpClicked:
            MOV direction, 1
            JMP CheckMenuState
        LeftClicked:
            MOV direction, 2
            JMP CheckMenuState
        DownClicked:
            MOV direction, 3
            JMP CheckMenuState
        EnterClicked:
            MOV direction, 4
            JMP CheckMenuState
        QuitClicked:
            MOV direction, 5
            ; Fall through to CheckMenuState

    ; Next, do different logic depending on menu state
    CheckMenuState:
        CMP menuState, 0
            JE MenuState0
        CMP menuState, 1
            JE MenuState1

    ; If menu state 0, currently moving selector across the board.
    MenuState0:
        ; Check if move is E or Q (special cases)
        CMP direction, 4
            JE MenuState0dir4
        CMP direction, 5
            JE GetPlayerInputLoop

        ; Check if move is valid before continuing
        CMP direction, 0    ; Don't check right
            JNE MenuState0CheckRight
            CMP selectedIndex, 31   ; Unless at the bottom right of the board
                JNE MenuState0EndInitialChecks  ; If not 31 end checks
                JMP GetPlayerInputLoop          ; If 31 cancel movement
;       |
        MenuState0CheckRight:
        CMP direction, 2    ; Don't check left
            JNE MenuState0CheckUpDown 
            CMP selectedIndex, 0    ; Unless at the top left of the board
                JNE MenuState0EndInitialChecks  ; If not 0 end checks
                JMP GetPlayerInputLoop          ; If 0 cancel movement
;       |
        MenuState0CheckUpDown:
        INVOKE CheckBorder, selectedIndex, direction
        CMP AL, 1   ; If on border and trying to move outside border, return back to player input loop
            JE GetPlayerInputLoop

        ; Old, can be removed
        MenuState0EndInitialChecks:
            INVOKE DrawHighlight, selectedIndex, 0, boardADDR, palettesADDR, spritesADDR, boardOffset   ; Clear old highlight

            INVOKE GetIndexTeam, selectedIndex, boardADDR
            CMP AL, team    ; Check if hovered over team
            JNE MenuState0EndInitialChecksHL    ; If not, go as usual
                INVOKE DrawPossibleMoves, selectedIndex, boardADDR, palettesADDR, spritesADDR, boardOffset, 0, moveMask   ; Clear old possible move highlights
        MenuState0EndInitialChecksHL:

        ; Check direction being moved in
        MenuState0GetDirections:
        CMP direction, 0
            JE MenuState0dir0
        CMP direction, 1
            JE MenuState0dir1
        CMP direction, 2
            JE MenuState0dir2
        CMP direction, 3
            JE MenuState0dir3

        ; If WASD, increase or decrease index value
        MenuState0dir0:
            INC selectedIndex
            JMP FinishMenuState0dirs
        MenuState0dir1:
            SUB selectedIndex, 4
            JMP FinishMenuState0dirs
        MenuState0dir2:
            DEC selectedIndex
            JMP FinishMenuState0dirs
        MenuState0dir3:
            ADD selectedIndex, 4
            ; Fall through to FinishMenuState0dirs

        ; Next, draw the new sprite
        FinishMenuState0dirs:
            ; Draw highlight on new index (old highlight got cleared)
            INVOKE DrawHighlight, selectedIndex, 2, boardADDR, palettesADDR, spritesADDR, boardOffset

            INVOKE GetIndexTeam, selectedIndex, boardADDR
            CMP AL, team
                JNE FinishMenuState0dirsHLEnd
                INVOKE DrawPossibleMoves, selectedIndex, boardADDR, palettesADDR, spritesADDR, boardOffset, 1, moveMask   ; Draw new possible moves

            FinishMenuState0dirsHLEnd:
            JMP GetPlayerInputLoop  ; Get next player input

        ; If dir 4 (E), draw possible moves.
        MenuState0dir4:
            ; Check if this index is the player's.
            INVOKE GetIndexTeam, selectedIndex, boardADDR
            CMP AL, team
                JNE GetPlayerInputLoop  ; If not player's, return to input loop

            INVOKE DrawPossibleMoves, selectedIndex, boardADDR, palettesADDR, spritesADDR, boardOffset, 8, moveMask   ; Replace highlights with faded gold
            CMP AL, 0   ; Check if no moves were found
                JE GetPlayerInputLoop  ; If no moves, return to GetPlayerInputLoop and stay in move select
                INVOKE DrawHighlight, selectedIndex, 1, boardADDR, palettesADDR, spritesADDR, boardOffset   ; Replace index highlight with grey
                MOV menuState, 1        ; Otherwise a valid move was found, so switch to "select move" mode
                ; Select and save a new direction
                INVOKE GetNextViableDir, selectedIndex, selectedDirection, 0, boardADDR, moveMask
                MOV selectedDirection, AL
                ; Draw initial selected direction
                INVOKE GetMoveIndex, selectedIndex, selectedDirection, boardADDR                ; Get index of new selected direction, store in AL
                MOV CL, AL                                                                      ; Store AL (new selected index) in CL for future procedure calls
                INVOKE DrawHighlight, CL, 2, boardADDR, palettesADDR, spritesADDR, boardOffset  ; Draw on new selected move with gold
                JMP GetPlayerInputLoop

    MenuState1:
        ; Draw over original highlight with faded gold

        MenuState1GetDirections:
        CMP direction, 1
            JE GetPlayerInputLoop
        CMP direction, 3
            JE GetPlayerInputLoop
        ; Knowing that a valid input has been input, clear the old direction
        INVOKE GetMoveIndex, selectedIndex, selectedDirection, boardADDR                ; Store current direction's index in AL
        MOV CL, AL                                                                      ; Store AL (selected direction's index) in CL for future procedure calls
        CMP CL, 32      ; Check if default starting direction caused original highlight to be 32 (invalid)
            JE MenuState1FinishRemoveHL     ; If default direction wasn't a viable move, make sure not to draw a faded highlight on it
            INVOKE DrawHighlight, CL, 4, boardADDR, palettesADDR, spritesADDR, boardOffset  ; Draw over old direction with faded gold
        MenuState1FinishRemoveHL:

        CMP direction, 0 
            JE MenuState1dir0
        CMP direction, 2
            JE MenuState1dir2
        CMP direction, 4
            JE MenuState1dir4
        CMP direction, 5
            JE MenuState1dir5
        JMP GetPlayerInputLoop  ; If invalid direction selected, poll next

        MenuState1dir0:     ; Move highlight to the right
            INVOKE GetNextViableDir, selectedIndex, selectedDirection, 1, boardADDR, moveMask         ; Find the next direction, store in AL
            MOV selectedDirection, AL                                                       ; Set selectedDirection to new viable direction
            INVOKE GetMoveIndex, selectedIndex, selectedDirection, boardADDR                ; Get index of new selected direction, store in AL
                MOV CL, AL                                                                  ; Store AL (new selected index) in CL for future procedure calls
            INVOKE DrawHighlight, CL, 2, boardADDR, palettesADDR, spritesADDR, boardOffset  ; Draw on new selected move with gold
            JMP GetPlayerInputLoop

        MenuState1dir2:     ; Move highlight to the left
            INVOKE GetNextViableDir, selectedIndex, selectedDirection, 0, boardADDR, moveMask         ; Find the next direction, store in AL
            MOV selectedDirection, AL                                                       ; Set selectedDirection to new viable direction
            INVOKE GetMoveIndex, selectedIndex, selectedDirection, boardADDR                ; Get index of new selected direction, store in AL
                MOV CL, AL                                                                  ; Store AL (new selected index) in CL for future procedure calls
            INVOKE DrawHighlight, CL, 2, boardADDR, palettesADDR, spritesADDR, boardOffset  ; Draw on new selected move with gold
            JMP GetPlayerInputLoop

        MenuState1dir4:     ; Lock in move
            INVOKE GetMoveIndex, selectedIndex, selectedDirection, boardADDR
                MOV BL, AL  ; Store final destination in BL
            INVOKE DrawPossibleMoves, selectedIndex, boardADDR, palettesADDR, spritesADDR, boardOffset, 0, moveMask   ; Clear out highlights

            INVOKE GetAllowedDistance, selectedIndex, selectedDirection, boardADDR      ; Store the length of this move in AL
            CMP AL, 1   ; Check if move length was of magnitude 1
                JE NormalMove
                JMP CaptureMove
                ; Otherwise move is a normal move; fall into NormalMove

            ; The following should have been several functions within checkers, but it's getting too late for good coding practices
            ; If magnitude was 1, move the checker one tile in selected direction.
            NormalMove:
                ; Remove original checker
                INVOKE GetBoardValue, selectedIndex, boardADDR                                          ; Get current piece
                    MOV CH, AL                                                                          ; Store it in CH
                INVOKE SetBoardValue, selectedIndex, 0, boardADDR                                       ; Set selected index to 0
                INVOKE DrawBoardIndex, selectedIndex, boardADDR, palettesADDR, spritesADDR, boardOffset ; Draw cleared out index to screen
                ; Make moved checker
                INVOKE SetBoardValue, BL, CH, boardADDR                                                 ; Set new index's value to old index's value
                INVOKE DrawBoardIndex, BL, boardADDR, palettesADDR, spritesADDR, boardOffset            ; Draw new checker to screen
                JMP EndMoveChecks                                                                       ; End this player's turn

            ; If magnitude was 2, move the checker two tiles in selected direction and set the tile one tile in selected direction to 0.
            CaptureMove:
                ; Remove original checker
                INVOKE GetBoardValue, selectedIndex, boardADDR                                          ; Get current piece
                    MOV CH, AL                                                                          ; Store it in CH
                INVOKE SetBoardValue, selectedIndex, 0, boardADDR                                       ; Set selected index to 0
                INVOKE DrawBoardIndex, selectedIndex, boardADDR, palettesADDR, spritesADDR, boardOffset ; Draw cleared out index to screen
                ; Clear checker being jumped over
                INVOKE GetIndexInDirection, selectedIndex, selectedDirection                            ; Get index being jumped on
                    MOV CL, AL                                                                          ; Store it in CL
                INVOKE SetBoardValue, CL, 0, boardADDR                                                  ; Set index value being jumped on to 0
                INVOKE DrawBoardIndex, CL, boardADDR, palettesADDR, spritesADDR, boardOffset            ; Draw cleared out index to screen
                ; Make moved checker                                                                    ; Move new index into CL
                INVOKE SetBoardValue, BL, CH, boardADDR                                                 ; Set new index's value to old index's value
                INVOKE DrawBoardIndex, BL, boardADDR, palettesADDR, spritesADDR, boardOffset            ; Draw new checker to screen
                MOV moveMask, 2                                                                         ; Set moveMask to two to check for any double jumps.
                ; Fall through to check if this move won the game

            ; Check if this capture won the game or not
            INVOKE GetOpposingCount, team, boardADDR
            CMP AL, 0                                                                                   ; Check if this move captured the last enemy piece.
                JNE EndMoveChecks                                                                       ; If not, continue as normal
                MOV hasWon, 1                                                                           ; Turn on hasWon flag
                JMP EndPlayerTurn                                                                       ; End player turn

            ; Check if piece landed on its respective opposite border, and if so, upgrade piece to a king
            EndMoveChecks:
                INVOKE GetBoardValue, BL, boardADDR ; Get the value of the moved piece and store in AL
                
                ;EndMoveCheckPlayer:
                    CMP AL, 1                           ; Check if this piece was a player checker
                        JNE EndMoveCheckEnemy               ; If not, finish up move
                        INVOKE CheckBorder, BL, 1           ; Check if bordering the top of the screen and store in AL
                        CMP AL, 0                           ; Check if border check returned false
                            JE EndMove                          ; If not touching top border, finish move

                    INVOKE SetBoardValue, BL, 2, boardADDR                                          ; Upgrade to player king
                    INVOKE DrawBoardIndex, BL, boardADDR, palettesADDR, spritesADDR, boardOffset    ; Update tile visual
                    JMP EndMove

                EndMoveCheckEnemy:
                    CMP AL, 3                           ; Check if this piece was an enemy checker
                        JNE EndMove                         ; If not, finish up move
                        INVOKE CheckBorder, BL, 3           ; Check if bordering the bottom of the screen and store in AL
                        CMP AL, 0                           ; Check if border check returned false
                            JE EndMove                          ; If not touching the bottom border, finish move

                    INVOKE SetBoardValue, BL, 4, boardADDR                                          ; Upgrade to enemy king
                    INVOKE DrawBoardIndex, BL, boardADDR, palettesADDR, spritesADDR, boardOffset    ; Update tile visual
                    JMP EndMove

                ; Finish up the move by checking if it's a double jump. If so, allow more jumps; if not, fully end move.
                EndMove:
                    CMP moveMask, 2     ; Check if moveMask was set to 2
                        JNE EndPlayerTurn           ; If it wasn't, end turn
                        MOV selectedIndex, BL       ; Otherwise set selected index to the jumped index
                        INVOKE DrawPossibleMoves, selectedIndex, boardADDR, palettesADDR, spritesADDR, boardOffset, 4, moveMask ; Draw new moves, but only ones of length 2 or more
                        CMP AL, 0       ; Check if any moves were found
                            JE EndPlayerTurn        ; If not, end turn
                            MOV MenuState, 1        ; Set menu state to 1 (selecting move phase)
                            INVOKE GetNextViableDir, selectedIndex, selectedDirection, 0, boardADDR, moveMask   ; Get and store the first viable direction in AL
                            MOV selectedDirection, AL                                                           ; Store AL (viable direction) in selectedDirection
                            INVOKE GetMoveIndex, selectedIndex, selectedDirection, boardADDR                    ; Get index of new selected direction, store in AL
                            MOV CL, AL                                                                          ; Store AL (new selected index) in CL for future procedure calls
                            INVOKE DrawHighlight, CL, 2, boardADDR, palettesADDR, spritesADDR, boardOffset      ; Draw on new selected move with gold
                            INVOKE DrawHighlight, selectedIndex, 1, boardADDR, palettesADDR, spritesADDR, boardOffset  ; Draw on grey highlight on new index
                            JMP GetPlayerInputLoop

        MenuState1dir5:     ; Exit menu state 1
            CMP moveMask, 0
                JE MenuState1dir5Cont
                ; If moveMask is not 0 (1, player is double jumping), end turn instead
                INVOKE DrawPossibleMoves, selectedIndex, boardADDR, palettesADDR, spritesADDR, boardOffset, 0, moveMask ; Clean up highlights
                INVOKE DrawHighlight, selectedIndex, 0, boardADDR, palettesADDR, spritesADDR, boardOffset               ; clear main highlight
                JMP EndPlayerTurn
            MenuState1dir5Cont:
            INVOKE DrawPossibleMoves, selectedIndex, boardADDR, palettesADDR, spritesADDR, boardOffset, 1, moveMask     ; Replace highlights with grey
            INVOKE DrawHighlight, selectedIndex, 2, boardADDR, palettesADDR, spritesADDR, boardOffset                   ; Replace main highlight with gold
            MOV MenuState, 0    ; Return to menu state 0
            JMP GetPlayerInputLoop

    EndPlayerTurn:      ; Officially end turn
    POP AX              ; Restore original AX
    MOV AL, hasWon      ; Replace AL with whether this player won or not
    RET

StartPlayerTurn ENDP

; --------------------------------------------------------------------------------------
; Gets a player keypress.

; RETURNS:
; AL = ASCII code of key pressed.
; --------------------------------------------------------------------------------------

GetPlayerInput PROC USES CX

    PUSH AX     ; Save AX to restore AH later

    MOV AH, 7   ; Direct char read (STDIN), no echo
    INT 21h     ; Call interrupt
    MOV CL, AL  ; Move key press into CL

    POP AX      ; Restore original AX
    MOV AL, CL  ; Replace AL with keyboard press code

    RET

GetPlayerInput ENDP

; --------------------------------------------------------------------------------------
; Starting from a direction, rotates until it reaches the next allowed move from a location.
;
; PARAMETERS:
; index             is the index to generate moves from.
; startDirection    is the direction from which to start rotating from.
; dirToRotate       is the direction in which to rotate to find a new move. 0 = CCW, 1 = CW
;   boardADDR         is the start of checkerboard data (BOARD).
;
; RETURNS:
; AL = new direction.
; --------------------------------------------------------------------------------------

GetNextViableDir PROC index:BYTE, startDirection:BYTE, dirToRotate:BYTE, boardADDR:WORD, moveMask:BYTE
    LOCAL direction:BYTE

    MOV AL, startDirection
    MOV direction, AL

    GetNextViableDirLoop:

        CMP dirToRotate, 0          ; Check if rotating CCW
            JNE CheckRotatingCW         ; If not rotating CCW, rotating CW
            DEC direction
            JMP CheckDirectionIsViableChecks

        CheckRotatingCW:
            INC direction
            JMP CheckDirectionIsViableChecks

        CheckDirectionIsViableChecks:
            CMP direction, 0FFH
                JNE CheckDirectionIsOverflow4
                MOV direction, 3
            CheckDirectionIsOverflow4:
            CMP direction, 4
                JNE CheckDirectionIsViable
                MOV direction, 0
                JMP CheckDirectionIsViable

        CheckDirectionIsViable:
            MOV AL, startDirection
            CMP direction, AL       ; Compare direction and StartDirection
                JE ReturnViableDirection    ; If equal, looped back to start, return startDirection
            INVOKE GetAllowedDistance, index, direction, boardADDR
            CMP AL, 0
                JE GetNextViableDirLoop
            
            CMP moveMask, 2 ; Check if moveMask is set to 2
                JNE ReturnViableDirection   ; If not, continue as normal
                CMP AL, 2                   ; Check if magnitude was 2
                    JNE GetNextViableDirLoop    ; If not, veto direction
                ; Otherwise fall through to ReturnViableDirection

    ReturnViableDirection:
    MOV AL, direction

    RET

GetNextViableDir ENDP

END