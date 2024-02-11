;;;     BRENDAN LANCASTER WAS HERE ON 4/30/22
;;;     
;;;		Library for managing a checkers game's board.
;;;			Assumes board is a 32 byte array (4x8 representation of a board)
;;;			Assumes checkers are:
;;;			0 - Empty
;;;			1 - Player checker
;;;			2 - Player king
;;;			3 - Enemy checker
;;;			4 - Enemy king
;;;
;;;     Standalone library.

.MODEL small, stdcall
	
.CODE

;;; Self references
    ; Returns the length that a piece can be moved in a given direction from a starting index.
        GetAllowedDistance  PROTO   tileIndex:BYTE, direction:BYTE, boardADDR:WORD
    ; Returns the index of BOARD in the direction of 0-3 from a starting point.
        GetIndexInDirection PROTO   tileIndex:BYTE, tileDirection:BYTE
    ; Returns the team of the unit of at a given index (0 = blank, 1 = player, 2 = enemy).
        GetIndexTeam        PROTO   tileIndex:BYTE, boardADDR:WORD
    ; Checks if a move is trying to move outside the board.
        CheckBorders        PROTO   tileIndex:BYTE, direction:BYTE
    ; Checks if an index is touching a border in this direction.
        CheckBorder         PROTO   tileIndex:BYTE, direction:BYTE
    ; Returns the index of a given length from a starting index.
        GetMoveIndex        PROTO   index:BYTE, direction:BYTE, boardADDR:WORD
    ; Sets board[index] to a value.
        SetBoardValue       PROTO   index:BYTE, valueToSet:BYTE, boardADDR:WORD
    ; Gets the value at board[index].
        GetBoardValue       PROTO   index:BYTE, boardADDR:WORD
    ; Gets the amount of opposing player's checkers that are alive on the board.
        GetOpposingCount    PROTO   teamAsking:BYTE, boardADDR:WORD
    ; Returns the index of a given length from a starting index.
        GetMoveIndex        PROTO   index:BYTE, direction:BYTE, boardADDR:WORD
 
; --------------------------------------------------------------------------------------
; Resets the board to the default checkerboard.
;
; PARAMETERS:
;   boardADDR         is the address of BOARD.
; --------------------------------------------------------------------------------------

InitializeBoard PROC USES SI CX AX,	boardADDR:WORD

    MOV SI, boardADDR

    ; Set indexes 0-11 to 3 (enemy checkers)
    MOV AL, 3
    MOV CX, 12
    InitializeBoardPlayerLoop:
        MOV [SI], AL
        INC SI
        LOOP InitializeBoardPlayerLoop

    ; Set indexes 12-19 to 0 (empty spaces)
    MOV AL, 0
    MOV CX, 8
    InitializeBoardEmptiesLoop:
        MOV [SI], AL
        INC SI
        LOOP InitializeBoardEmptiesLoop

    ; Set indexes 20-31 to 1 (player checkers)
    MOV AL, 1
    MOV CX, 12
    InitializeBoardEnemyLoop:
        MOV [SI], AL
        INC SI
        LOOP InitializeBoardEnemyLoop

    RET

InitializeBoard ENDP

; --------------------------------------------------------------------------------------
; Returns the length that a piece can be moved in a given direction from a starting index.
;
; PARAMETERS:
; tileIndex         is the index of the unit on board to check borders for.
; direction         is the direction trying to move in; 0 UL, 1 UR, 2 DL, 2 DR.
;   boardADDR         is the address of the checkerboard (BOARD).
;
; RETURNS:
; AL = Length of movement in direction. If 0, move was invalid; if 1, normal move; if 2, capture piece.
; --------------------------------------------------------------------------------------

GetAllowedDistance PROC USES SI CX, tileIndex:BYTE, direction:BYTE, boardADDR:WORD
    LOCAL team:byte, piece:BYTE

    PUSH AX         ; Save AX for later so AH can get conserved

    ; Find and save the team of this index
    INVOKE GetIndexTeam, tileIndex, boardADDR
    MOV team, AL
    INVOKE GetBoardValue, tileIndex, boardADDR
    MOV piece, AL

    ; First, check if this piece can move in this direction in the first place
    CMP piece, 1    ; If player checker,
        JE TryMoveInDirectionCheckPlayerCHKR
    CMP piece, 3    ; If enemy checker,
        JE TryMoveInDirectionCheckEnemyCHKR
    JMP TryMoveInDirectionStart     ; Otherwise, is a king
;   |
    TryMoveInDirectionCheckPlayerCHKR:  ; If this is a player checker,
        CMP direction, 2        ; Don't allow moving DL,
            JE TryMoveInDirection0
        CMP direction, 3        ; Don't allow moving DR
            JE TryMoveInDirection0
        JMP TryMoveInDirectionStart
;   |
    TryMoveInDirectionCheckEnemyCHKR:   ; If this is an enemy checker,
        CMP direction, 0        ; Don't allow moving UL,
            JE TryMoveInDirection0
        CMP direction, 1        ; Don't allow moving DR
            JE TryMoveInDirection0
        JMP TryMoveInDirectionStart

    ; Now check further logic.
    TryMoveInDirectionStart:
;   |
    ; Check if this piece is trying to leave the board. If so, return 0.
    INVOKE CheckBorders, tileIndex, direction
    CMP AL, 1
        JE TryMoveInDirection0
;   |
    ; Next, check what's in the direction this piece is trying to move in.
    INVOKE GetIndexInDirection, tileIndex, direction     ; Stores index in direction wanted inside AL
    MOV AH, AL      ; Temporarily store index in AH
    MOV CL, AL
    INVOKE GetIndexTeam, CL, boardADDR      ; Stores team of directed index in AL
    CMP AL, 0                   ; If trying to move into an empty slot,
        JE TryMoveInDirection1      ; move is valid- move one slot
    CMP AL, team                ; If trying to move onto own team,
        JE TryMoveInDirection0      ; move is invalid
;   |
    ; Otherwise, trying to jump on an enemy.
        MOV CH, AH
        INVOKE CheckBorders, CH, direction  ; Check and store in AL if direction from enemy checker location would go out of bounds
        CMP AL, 1
            JE TryMoveInDirection0      ; If so, move is invalid
        MOV CH, AH
        INVOKE GetIndexInDirection, CH, direction    ; Get index in direction and store it in AL
        MOV CL, AL
        INVOKE GetIndexTeam, CL, boardADDR                      ; Check if location behind checker index (AL) is empty
        CMP AL, 0
            JE TryMoveInDirection2      ; If so, move is a valid capture- move two slots
            JMP TryMoveInDirection0     ; Otherwise capture is blocked by a piece behind it, move is invalid

    TryMoveInDirection0:
        POP AX          ; Restore original AX
        MOV AL, 0       ; Return that move is invalid
        JMP TryMoveInDirectionEnd
    TryMoveInDirection1:
        POP AX          ; Restore original AX
        MOV AL, 1       ; Return that direction allows moving one slot (empty)
        JMP TryMoveInDirectionEnd
    TryMoveInDirection2:
        POP AX          ; Restore original AX
        MOV AL, 2       ; Return that direction allows moving two slots (capture)
        JMP TryMoveInDirectionEnd
    
    TryMoveInDirectionEnd:
    ; AH is restored above

    RET

GetAllowedDistance ENDP

; --------------------------------------------------------------------------------------
; Returns the index of BOARD in the direction of 0-3 from a starting point.
;
; PARAMETERS:
; tileIndex         is the index of the board to get the valid moves of.
; tileDirection     is the direction to move in, 0-3, going from up left, up right, down left, down right.
;   boardADDR         is the address of the board (BOARD).
;
; RETURNS:
; AL = index in a direction from an index.
; --------------------------------------------------------------------------------------

GetIndexInDirection PROC USES CX, tileIndex:BYTE, tileDirection:BYTE

    ; To find index in direction:
        ; If on an even y position, UL = -5, UR = -4, DL = +3, DR = +4
        ; If on an odd y position, UL = -4, UR = -3, DL = +4, DR = +5
    ; This can be simplified to:
        ; UL = -5, UR = -4, DL = +3, DR = +4
        ; If ((tileIndex AND 00000100) == 4) { index++ }

    ; Get initial offset from direction
    MOV CL, tileIndex       ; Temporarily store index in CL
    CheckDirectionIsUL:
    CMP tileDirection, 0
        JNE CheckDirectionIsUR
        SUB CL, 5
        JMP EndCheckDirections
    CheckDirectionIsUR:
    CMP tileDirection, 1
        JNE CheckDirectionIsDL
        SUB CL, 4
        JMP EndCheckDirections
    CheckDirectionIsDL:
    CMP tileDirection, 2
        JNE CheckDirectionIsDR
        ADD CL, 3
        JMP EndCheckDirections
    CheckDirectionIsDR:
    ; Direction must be 3
        ADD CL, 4   
    EndCheckDirections:

    ; If on an odd tile, increase index offset by 1
    MOV CH, tileIndex   ; Move tile index into CH
    AND CH, 00000100b   ; Check if CH contains a 4
    CMP CH, 4
        JNE EndGetIndexInDirection
        INC CL
    EndGetIndexInDirection:

    ; Move result into AL to return
    MOV AL, CL  ; Replace AL with index

    RET

GetIndexInDirection ENDP

; --------------------------------------------------------------------------------------
; Returns the team of the unit of at a given index (0 = blank, 1 = player, 2 = enemy).
;
; PARAMETERS:
; tileIndex         is the index of the unit on board to get the team of.
;   boardADDR           is the address of the board (BOARD).
;
; RETURNS:
; AL = team of the unit where 0 = blank, 1 = player, 2 = enemy.
; --------------------------------------------------------------------------------------

GetIndexTeam PROC USES SI CX, tileIndex:BYTE, boardADDR:WORD

    MOV SI, boardADDR
    XOR CX, CX
    MOV CL, tileIndex
    ADD SI, CX
    MOV CH, [SI]

    CMP CH, 0     ; Check if index is 0
        JNE CheckIndexIsPlayer
        MOV AL, 0
        JMP FinishGetIndexTeam
    CheckIndexIsPlayer:
    CMP CH, 2     ; Check if index is 1 or 2
        JG CheckIndexIsEnemy
        MOV AL, 1
        JMP FinishGetIndexTeam
    CheckIndexIsEnemy:
    CMP CH, 4     ; Check if index is 3 or 4
        JG FinishGetIndexTeam
        MOV AL, 2
        JMP FinishGetIndexTeam
    IndexIsOOB:
        MOV AL, 0   ; If index is 5 or above it shouldn't exist, treat as "empty"
        JMP FinishGetIndexTeam

    FinishGetIndexTeam:
    RET

GetIndexTeam ENDP

; --------------------------------------------------------------------------------------
; Checks if a move is trying to move outside the board.
;
; PARAMETERS:
; tileIndex         is the index of the unit on board to check borders for.
; direction         is the direction trying to move in; 0 UL, 1 UR, 2 DL, 2 DR. (ordinal)
;
; RETURNS:
; 0 if direction is inside board, 1 if direction tries to leave board.
; --------------------------------------------------------------------------------------

CheckBorders PROC USES CX, tileIndex:BYTE, direction:BYTE

    ; Check direction in direction trying to move
    CMP direction, 0
        JE CheckBorderUL
    CMP direction, 1
        JE CheckBorderUR
    CMP direction, 2
        JE CheckBorderDL
    ; Otherwise direction is 3
        JMP CheckBorderDR

    CheckBorderUL:
        INVOKE CheckBorder, tileIndex, 1    ; Check up
        CMP AL, 1
            JE CheckBorderInvalid
        INVOKE CheckBorder, tileIndex, 2    ; Check left
        CMP AL, 1
            JE CheckBorderInvalid
        JMP CheckBorderValid
;   |
    CheckBorderUR:
        INVOKE CheckBorder, tileIndex, 1    ; Check up
        CMP AL, 1
            JE CheckBorderInvalid
        INVOKE CheckBorder, tileIndex, 0    ; Check right
        CMP AL, 1
            JE CheckBorderInvalid
        JMP CheckBorderValid
;   |
    CheckBorderDL:
        INVOKE CheckBorder, tileIndex, 3    ; Check down
        CMP AL, 1
            JE CheckBorderInvalid
        INVOKE CheckBorder, tileIndex, 2    ; Check left
        CMP AL, 1
            JE CheckBorderInvalid
        JMP CheckBorderValid
;   |
    CheckBorderDR:
        INVOKE CheckBorder, tileIndex, 3    ; Check down
        CMP AL, 1
            JE CheckBorderInvalid
        INVOKE CheckBorder, tileIndex, 0    ; Check right
        CMP AL, 1
            JE CheckBorderInvalid
        JMP CheckBorderValid

    CheckBorderInvalid:
        MOV AL, 1
        JMP EndCheckBorders
;   |
    CheckBorderValid:
        MOV AL, 0
        JMP EndCheckBorders

    EndCheckBorders:

    RET

CheckBorders ENDP

; --------------------------------------------------------------------------------------
; Checks if an index is touching a border in this direction.
;
; PARAMETERS:
; tileIndex         is the index of the of the board to check for a border
; direction         is the direction to check; 0 right, 1 up, 2 left, 3 down. (cardinal)
;   boardADDR         is the address of the board (BOARD).
;
; RETURNS:
; 1 if this index has a border in this direction, 0 if not.
; --------------------------------------------------------------------------------------

CheckBorder PROC tileIndex:BYTE, direction:BYTE

; Slightly outdated comment, but same principles:
    ; Use bitmasks to determine if position is on an edge.
    ; All slot indexes are 31 or less, so only the last five bits matter.
    ; For example:
    ;   If trying to move up and left (UL), check if on the top or left borders.
    ;   Top border indexes are below 4, so use a bitmask to check if it has any digits 4 or above (0011100b)-
    ;   If true, the move is on the top border.
    ;       Return 0.
    ;   Left border indexes are divisible by 8, so use a bitmask to check if it has any digits less than 8 (00000111b)-
    ;   If true, move is on left border.
    ;       Return 0.
    ;   Otherwise return 1.

    ; First find what direction to check
    MOV AL, tileIndex
    CMP direction, 0
        JE CheckRightBorder
    CMP direction, 1
        JE CheckUpBorder
    CMP direction, 2
        JE CheckLeftBorder
        ; Direction must be 3
        JMP CheckDownBorder

    ; Jump to whichever border to check
    CheckRightBorder:
        AND AL, 00000111b       ; If minus seven is divisible by eight,
        CMP AL, 7
            JE ReturnBorderTrue
        JMP ReturnBorderFalse
    CheckUpBorder:
        AND AL, 00011100b       ; If below 4,
        CMP AL, 0
            JE ReturnBorderTrue
        JMP ReturnBorderFalse
    CheckLeftBorder:            ; If cleanly divisible by eight,
        AND AL, 00000111b
        CMP AL, 0
            JE ReturnBorderTrue
        JMP ReturnBorderFalse
    CheckDownBorder:
        AND AL, 00011100b       ; If 28 or above,
        CMP AL, 28
            JE ReturnBorderTrue
        JMP ReturnBorderFalse

    ; Return 1 for on border, 0 for fine
    ReturnBorderTrue:
        MOV AL, 1
        JMP EndCheckBorder
    ReturnBorderFalse:
        MOV AL, 0
        ;Fall through to EndCheckBorder
    
    EndCheckBorder:
    RET

CheckBorder ENDP

; --------------------------------------------------------------------------------------
; Returns the index of a given length from a starting index.
;
; PARAMETERS:
; tileIndex         is the index of the unit on board to get the team of.
; direction         is the direction to try to move.
;
; RETURNS:
; AL = new index. Returns 32 if move doesn't work, however this shouldn't be able to be reached
; --------------------------------------------------------------------------------------

GetMoveIndex PROC USES CX, index:BYTE, direction:BYTE, boardADDR:WORD

    PUSH AX     ; Store AX to restore AH later

    INVOKE GetAllowedDistance, index, direction, boardADDR  ; Get allowed distance, store in AL
    MOV CH, AL  ; Move AL (allowed distance) into CH for use in further procedures

    CMP CH, 0   ; Check if allowed distance is 0
        JNE GetMoveLocationCheck1
        MOV CL, 32  
        JMP GetMoveLocationEnd

    GetMoveLocationCheck1:
    CMP CH, 1
        JNE GetMoveLocationCheck2
        INVOKE GetIndexInDirection, index, direction
        MOV CL, AL
        JMP GetMoveLocationEnd

    GetMoveLocationCheck2:
    ; Must be 2 if not 0 or 1
        INVOKE GetIndexInDirection, index, direction    ; Get index in this direction
        MOV CL, AL                                      ; Move AL into CL to use in procedures
        INVOKE GetIndexInDirection, CL, direction       ; Get index in same direction again
        MOV CL, AL
        JMP GetMoveLocationEnd

    GetMoveLocationEnd:
    POP AX      ; Restore original AX
    MOV AL, CL  ; Replace AL with directed index
    RET

GetMoveIndex ENDP

; --------------------------------------------------------------------------------------
; Sets board[index] to a value.
;
; PARAMETERS:
; index             is the index of the board to set.
; valueToSet        is the value to set the index to.
;   boardADDR         is the address of the board (BOARD).
; --------------------------------------------------------------------------------------

SetBoardValue PROC USES SI CX AX, index:BYTE, valueToSet:BYTE, boardADDR:WORD

    MOV SI, boardADDR
        XOR AX, AX
        MOV AL, index
    ADD SI, AX          ; Point SI at index of board

    MOV CL, valueToSet  
    MOV [SI], CL        ; Replace board index's value with given value

    RET

SetBoardValue ENDP

; --------------------------------------------------------------------------------------
; Gets the value at board[index].
;
; PARAMETERS:
; index             is the index of the board to get.
;   boardADDR         is the address of the board (BOARD).
;
; RESULTS:
; AL = board[index]
; --------------------------------------------------------------------------------------

GetBoardValue PROC USES SI CX, index:BYTE, boardADDR:WORD

    PUSH AX             ; Save original AX

    MOV SI, boardADDR
        XOR AX, AX
        MOV AL, index
    ADD SI, AX          ; Point SI at index of board

    MOV CL, [SI]        ; Set CL to index's value

    POP AX              ; Restore original AX
    MOV AL, CL          ; Replace AL with board value

    RET

GetBoardValue ENDP

; --------------------------------------------------------------------------------------
; Gets the amount of opposing player's checkers that are alive on the board.
;
; PARAMETERS:
; teamAsking        is the team that's asking to find how many of their enemy remain on the board.
;   boardADDR         is the address of the board (BOARD).
;
; RESULTS:
; AL = amount of enemy pieces remaining
; --------------------------------------------------------------------------------------

GetOpposingCount PROC USES SI CX BX, teamAsking:BYTE, boardADDR:WORD

    PUSH AX             ; Store original AX to restore AH later

    ; AL will store amount of pieces found
    MOV AL, 0

    ; AH will store team to search for
    MOV AH, teamAsking  ; Store teamAsking in AH
    XOR AH, 3           ; XOR it with 3; result is 1 -> 2, 2 -> 1

    MOV CL, 32      ; Set loop condition for all 32 pieces
    CountCheckersLoop:
        DEC CL                              ; Lower CL (loop condition) by one
        PUSH AX                             ; Temporarily push AX
        INVOKE GetIndexTeam, CL, boardADDR  ; Get team value of board[CL] and store it in AL
        MOV BH, AL                          ; Move AL into BH
        POP AX                              ; Restore AX
        CMP AH, BH                          ; Check if AH (opposite team) is equal to BH (team on this index)
            JNE CountCheckersEndLoop            ; If not, progress onto next indes
            INC AL                              ; If so, add 1 to pieces found
        CountCheckersEndLoop:
            CMP CL, 0                           ; Check if loop condition has reached 0
                JNE CountCheckersLoop               ; If not, loop again

    MOV CL, AL  ; Temporarily store AL in CL
    POP AX      ; Restore original AX
    MOV AL, CL  ; Replace AL with opposing checkers count

    RET

GetOpposingCount ENDP

END