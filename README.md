#x86-checkers
My final project for Computer Architecture during May 2022.
This game implements an 8 and 16-bit sprite renderer with 2-bit color palettes to simulate a game of checkers.

Controls:
 - Move the selected tile using WASD.
 - While hovered over a piece, press E to select it.
 - While a checker is selected, rotate between possible moves using A and D.
 - Press E to move the checker and Q to cancel.

To compile using DOSBox and MASM, use the following commands:

MASM PRJCTGAM.ASM
MASM PRJCTCHK.ASM
MASM PRJCTDRW.ASM
MASM PRJCTGFX.ASM
MASM PRJCTUI.ASM
LINK PRJCTGAM.ASM PRJCTCHK.ASM PRJCTDRW.ASM PRJCTGFX.ASM PRJCTUI.ASM
PRJCTGAM
