/*
This file is part of gamelib-x64.

Copyright (C) 2014 Tim Hegeman

gamelib-x64 is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

gamelib-x64 is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with gamelib-x64. If not, see <http://www.gnu.org/licenses/>.

i'm gonna be honest, i don't know what any of that means. 
just gonna leave it here
*/

.file "src/game/game.s"

.global gameInit
.global gameLoop

.section .game.data
                .skip 12                #guaranteeing a buffer 12 bytes before the board is initialized as 0 for later program logic
tetrisBoard:	.byte 0x7C 
                .skip 10 
                .byte 0x7C              #one initial row of the tetris board. it will be 21 bytes by 12 bytes.
                
                .byte 0x7C 
                .skip 10 
                .byte 0x7C              #a byte > 0 will represent a filled square and a byte of 0 will represent an empty one.
                
                .byte 0x7C 
                .skip 10 
                .byte 0x7C              #this will be important for later program logic
                
                .byte 0x7C 
                .skip 10 
                .byte 0x7C              #a byte of 0x7c or 0x3d will represent the board boundaries. the actual playable area is 20 by 10.
                
                .byte 0x7C 
                .skip 10 
                .byte 0x7C
                
                .byte 0x7C 
                .skip 10 
                .byte 0x7C
                
                .byte 0x7C 
                .skip 10 
                .byte 0x7C
                
                .byte 0x7C 
                .skip 10 
                .byte 0x7C
                
                .byte 0x7C 
                .skip 10 
                .byte 0x7C
                
                .byte 0x7C 
                .skip 10 
                .byte 0x7C
                
                .byte 0x7C 
                .skip 10 
                .byte 0x7C
                
                .byte 0x7C 
                .skip 10 
                .byte 0x7C
                
                .byte 0x7C 
                .skip 10 
                .byte 0x7C
                
                .byte 0x7C 
                .skip 10 
                .byte 0x7C
                
                .byte 0x7C 
                .skip 10 
                .byte 0x7C
                
                .byte 0x7C 
                .skip 10 
                .byte 0x7C
                
                .byte 0x7C 
                .skip 10 
                .byte 0x7C
                
                .byte 0x7C 
                .skip 10 
                .byte 0x7C
                
                .byte 0x7C 
                .skip 10 
                .byte 0x7C
                
                .byte 0x7C 
                .skip 10
                .byte 0x7C
                
                .long 0x3D3D3D3D
                .long 0x3D3D3D3D 
                .long 0x3D3D3D3D        #this represents the floor of the board.

colorTable:     .skip 128               #this will be loaded later with the colors for each relevant character
                                        #but i still want it initialized with zeros.
                                        #it will act as a lookup table to remove the need for branching when selecting a color
                                        #and help keep the data board small

score:          .quad 0x0               #initialize a score in memory to 0.
highest:        .quad 0x0               #add a place to save the highest achieved score.

centerx:        .byte 0x0               #first of four declarations that represent the current block.
centery:        .byte 0x0               #each will consist of two bytes that contain x and y coordinates
b2x:            .byte 0x0               #number 2. 2, 3, and 4 will be rotated around the center when asked to.
b2y:            .byte 0x0               #2, 3, and 4 are defined as offsets from the center for easier transformation
b3x:            .byte 0x0               #number 3
b3y:            .byte 0x0               
b4x:            .byte 0x0               #number 4
b4y:            .byte 0x0

gameover:       .byte 0x0               #this byte will be set nonzero when the game is lost.

current:        .byte 0x0               #this will be randomized in gameInit
saved:          .byte 0x0               #start the player off with a saved I piece to be nice
next:           .byte 0x0               #this will be also be randomized in gameInit
swapped:        .byte 0x0               #this will store if the current piece has been swapped out yet to control when the player can save.
pieceChars:     .byte 0x23              #these are the characters that comprise each piece, arranged in a table for easy access.
                .byte 0x24
                .byte 0x25
                .byte 0x26
                .byte 0x40      
                .byte 0x48
                .byte 0x4D
cycles:         .quad 0x0               #this will store the number of times gameLoop has been called.
counter:        .quad 0x0               #this will serve as a counter.

.section .game.text
.equ    vgaStart, 0xB8000               #start and end of graphics memory
.equ    vgaEnd, 0xB8FA0                 #vgaStart + 4000
.equ    boardStart, 0xB8184             #start of the tetris board, vgaStart + 388

.equ    iblock, 0x23                    #define shortcuts for each block so i don't have to remember the hex code
.equ    jblock, 0x24
.equ    lblock, 0x25
.equ    oblock, 0x26
.equ    sblock, 0x40
.equ    tblock, 0x48
.equ    zblock, 0x4D

.equ    left, 0x4B                      #left arrow scan code
.equ    right, 0x4D                     #right arrow scan code
.equ    down, 0x50                      #down arrow scan code
.equ    akey, 0x1E                      #"a" key scan code
.equ    dkey, 0x20                      #"d" key scan code
.equ    rkey, 0x13                      #"r" key scan code
.equ    space, 0x39                     #space key scan code

gameInit:
        movq    $19886, %rdi            #reloadValue for 60 Hz since this game's logic is frame-dependent
        call    setTimer                #call setTimer to load it to 60 Hz

        movq    $vgaStart, %rdi         #start of graphics memory

initLoop: 
        movw    $0, (%rdi)              #erase the initial character
        addq    $2, %rdi                #increment the memory address
        cmpq    $vgaEnd, %rdi           #compare the address to the end of VGA text memory
        jl      initLoop                #if less than, continue erasing

initCTable:
        movq    $colorTable, %rax       #move the address of the color table to %rax
        movb    $0x0F, 0x7C(%rax)       #color is white on black
        movb    $0x0F, 0x3D(%rax)       #color is white on black
        movb    $0x03, 0x23(%rax)       #color is cyan on black
        movb    $0x01, 0x24(%rax)       #color is blue on black
        movb    $0x06, 0x25(%rax)       #color is brown on black
        movb    $0x0E, 0x26(%rax)       #color is yellow on black
        movb    $0x0A, 0x40(%rax)       #color is light green on black
        movb    $0x05, 0x48(%rax)       #color is magenta on black
        movb    $0x04, 0x4D(%rax)       #color is red on black

initBlocks:
        rdtsc                           #read the time stamp counter, it's random enough
        movq    $0, %rdx                #erase %rdx
        movq    $7, %rcx                #move 7 into %rcx
        divq    %rcx                    #divide %rax by 7
        movb    %dl, current            #rdx contains the remainder, 0-6. move it into current.
        movq    $0, %rdx                #erase %rdx
        divq    %rcx                    #divide again
        movb    %dl, next               #move the number into next.

        movq    $boardStart, %rdi       #move $boardStart into %rdi
        movw    $0x0F3D, -12(%rdi)      #these next lines display the "SAVE" and "NEXT" boxes
        movw    $0x0F53, -10(%rdi)
        movw    $0x0F41, -8(%rdi)
        movw    $0x0F56, -6(%rdi)
        movw    $0x0F45, -4(%rdi)
        movw    $0x0F3D, -2(%rdi)

        addq    $160, %rdi              #each of these lines shifts the pointer by a row
        movw    $0x0F7C, -12(%rdi)
        movw    $0x0F7C, -2(%rdi)

        addq    $160, %rdi
        movw    $0x0F7C, -12(%rdi)
        movw    $0x0F7C, -2(%rdi)

        addq    $160, %rdi
        movw    $0x0F7C, -12(%rdi)
        movw    $0x0F7C, -2(%rdi)

        addq    $160, %rdi
        movw    $0x0F7C, -12(%rdi)
        movw    $0x0F7C, -2(%rdi)

        addq    $160, %rdi
        movw    $0x0F3D, -12(%rdi)
        movw    $0x0F3D, -10(%rdi)
        movw    $0x0F3D, -8(%rdi)
        movw    $0x0F3D, -6(%rdi)
        movw    $0x0F3D, -4(%rdi)
        movw    $0x0F3D, -2(%rdi)

        addq    $160, %rdi
        movw    $0x0F3D, -12(%rdi)
        movw    $0x0F4E, -10(%rdi)
        movw    $0x0F45, -8(%rdi)
        movw    $0x0F58, -6(%rdi)
        movw    $0x0F54, -4(%rdi)
        movw    $0x0F3D, -2(%rdi)

        addq    $160, %rdi
        movw    $0x0F7C, -12(%rdi)
        movw    $0x0F7C, -2(%rdi)

        addq    $160, %rdi
        movw    $0x0F7C, -12(%rdi)
        movw    $0x0F7C, -2(%rdi)

        addq    $160, %rdi
        movw    $0x0F7C, -12(%rdi)
        movw    $0x0F7C, -2(%rdi)

        addq    $160, %rdi
        movw    $0x0F7C, -12(%rdi)
        movw    $0x0F7C, -2(%rdi)

        addq    $160, %rdi
        movw    $0x0F3D, -12(%rdi)
        movw    $0x0F3D, -10(%rdi)
        movw    $0x0F3D, -8(%rdi)
        movw    $0x0F3D, -6(%rdi)
        movw    $0x0F3D, -4(%rdi)
        movw    $0x0F3D, -2(%rdi)

        call    updateSave

        call    updateNext

        call    initializeBlock

initScore:
        movq    $boardStart, %rdi       #reset the pointer for easier use
        addq    $26, %rdi               #add 26 to offset
        movw    $0x0F53, 4(%rdi)        #the next 5 lines write "SCORE" in white text on black background centered with respect to the score
        movw    $0x0F43, 6(%rdi)
        movw    $0x0F4F, 8(%rdi)
        movw    $0x0F52, 10(%rdi)
        movw    $0x0F45, 12(%rdi)

        addq    $480, %rdi              #move the pointer down 3 lines
        movw    $0x0F48, 2(%rdi)        #the next 7 lines write "HIGHEST" in white text on black background centered with respect to the highest achieved score
        movw    $0x0F49, 4(%rdi)
        movw    $0x0F47, 6(%rdi)
        movw    $0x0F48, 8(%rdi)
        movw    $0x0F45, 10(%rdi)
        movw    $0x0F53, 12(%rdi)
        movw    $0x0F54, 14(%rdi)

        call    updateScore

        call    updateHighest

	ret

gameLoop:
	# Check if a key has been pressed
	call	readKeyCode            
	cmpq    $0, %rax
        je      loopEnd
        cmpq	$rkey, %rax             #if a key has been pressed, jump to the branch that supports the key press if there is one.
        je      loopProcessR
        cmpb    $0, gameover            #if gameover is nonzero, reject all input other than r for restart.
        jne     gameLoopOver         
        cmpq    $left, %rax
        je      loopProcessLeft
        cmpq	$right, %rax
        je      loopProcessRight
        cmpq    $down, %rax
        je      loopProcessDown
        cmpq	$space, %rax
        je      loopProcessSpace
        cmpq    $akey, %rax
        je      loopProcessA
        cmpq    $dkey, %rax
        je      loopProcessD
        
        jmp     loopEnd

loopProcessR:
        call    reset
        jmp     loopEnd

loopProcessLeft:
        movq    $0, %rdi                #set %rdi to 0
        call    addBlock                #erase the current block

        movq    $0, %rdi                #set %rdi to -1
        subq    $1, %rdi                

        call    checkBoard              #check to see the board is empty on the left
        subq    %rax, centerx           #if it did, move the center left 1

        movq    $pieceChars, %rsi       #move the address of the piece character table to %rsi
        movzbq  current, %rdx           #move current into %rdx, zero extending it
        addq    %rdx, %rsi              #add %rdx to %rsi
        movb    (%rsi), %dil            #move the character into %dil
        call    addBlock

        jmp     loopEnd

loopProcessRight:
        movq    $0, %rdi                #set %rdi to 0
        call    addBlock                #erase the current block

        movq    $1, %rdi                #set %rdi to 1

        call    checkBoard              #check to see the board is empty on the right
        addq    %rax, centerx            #if it did, move the center right 1

        movq    $pieceChars, %rsi       #move the address of the piece character table to %rsi
        movzbq  current, %rdx           #move current into %rdx, zero extending it
        addq    %rdx, %rsi              #add %rdx to %rsi
        movb    (%rsi), %dil            #move the character into %dil
        call    addBlock

        jmp     loopEnd

loopProcessDown:
        movq    $0, counter             #reset the counter on manual movement down
        call    downOrNew               #call the function that handles moving down or generating a new piece
        jmp     loopEnd

loopProcessSpace:
        cmpb    $0, swapped             #if already swapped with this piece, cannot swap again
        jne     loopEnd
        
        movq    $0, %rdi                #set %rdi to 0
        call    addBlock                #erase the current block

        movb    saved, %dl              #move saved to %dl to prepare for swap
        movb    current, %dh            #move current to %dh to prepare for swap
        movb    %dl, current            #move the previously saved block to current
        movb    %dh, saved              #move the previously current block to saved
        movb    $1, swapped             #set the swapped flag
        
        call    updateSave              #update the saved block graphic
        call    initializeBlock         #initialize the new block

        jmp     loopEnd

loopProcessA:   #formula for counterclockwise rotation (x, y) => (y, -x)
        movq    $0, %rdi                #set %rdi to 0
        call    addBlock                #erase the current block

        movq    $tetrisBoard, %r10      #save the tetrisBoard base pointer in %r10
        
        movzbq  centerx, %rdi           #calculate the center offset
        movzbq  centery, %rsi
        call    coordToBoardOff
        
        addq    %rax, %r10              #add the center offset to the board pointer

        movb    b2x, %dl                #move b2x to %dl
        negb    %dl                     #negate %dl
        movb    b2y, %dh                #move b2y to %dh

        movb    b3x, %cl                #move b3x to %cl
        negb    %cl                     #negate %cl
        movb    b3y, %ch                #move b3y to %ch

        movb    b4x, %r8b               #move b4x to %r8b
        negb    %r8b
        movb    b4y, %r9b               #move b4y to %r9b

        movsxb  %dl, %rsi               #move the new y offset to %rsi, sign extended
        movsxb  b2y, %rdi               #move the new x offset to %rdi, sign extended
        call    coordToBoardOff

        cmpb    $0, (%r10, %rax)        #compare the new position of block 2 to $0
        jne     loopProcessAPl          #if it's full, place the block back down and end

        movsxb  %cl, %rdi               #move the new y offset to %rdi, sign extended
        movsxb  b3y, %rsi               #move the new x offset to %rsi, sign extended
        call    coordToBoardOff

        cmpb    $0, (%r10, %rax)        #compare the new position of block 3 to $0
        jne     loopProcessAPl          #if it's full, place the block back down and end

        movsxb  %r8b, %rsi              #move the new y offset to %rsi, sign extended
        movsxb  %r9b, %rdi              #move the new x offset to %rdi, sign extended
        call    coordToBoardOff

        cmpb    $0, (%r10, %rax)        #compare the new position of block 2 to $0
        jne     loopProcessAPl          #if it's full, place the block back down and end

        movb    %dl, b2y                #move -b2x to b2y
        movb    %dh, b2x                #move b2y to b2x

        movb    %cl, b3y                #move -b3x to b3y
        movb    %ch, b3x                #move b3y to b3x

        movb    %r8b, b4y               #move -b4x to b4x
        movb    %r9b, b4x               #move b4y to b4x

loopProcessAPl:
        movq    $pieceChars, %rsi       #move the address of the piece character table to %rsi
        movzbq  current, %rdx           #move current into %rdx, zero extending it
        addq    %rdx, %rsi              #add %rdx to %rsi
        movb    (%rsi), %dil            #move the character into %dil
        call    addBlock

        jmp     loopEnd

loopProcessD:   #formula for clockwise rotation (x, y) => (-y, x)
        movq    $0, %rdi                #set %rdi to 0
        call    addBlock                #erase the current block

        movq    $tetrisBoard, %r10      #save the tetrisBoard base pointer in %r10
        
        movzbq  centerx, %rdi           #calculate the center offset
        movzbq  centery, %rsi
        call    coordToBoardOff
        
        addq    %rax, %r10              #add the center offset to the board pointer

        movb    b2y, %dl                #move b2y to %dl
        negb    %dl                     #negate %dl
        movb    b2x, %dh                #move b2x to %dh

        movb    b3y, %cl                #move b3y to %cl
        negb    %cl                     #negate %cl
        movb    b3x, %ch                #move b3x to %ch

        movb    b4y, %r8b               #move b4y to %r8b
        negb    %r8b
        movb    b4x, %r9b               #move b4x to %r9b

        movsxb  %dl, %rdi               #move the new x offset to %rdi, sign extended
        movsxb  b2x, %rsi               #move the new y offset to %rsi, sign extended
        call    coordToBoardOff

        cmpb    $0, (%r10, %rax)        #compare the new position of block 2 to $0
        jne     loopProcessDPl          #if it's full, place the block back down and end

        movsxb  %cl, %rdi               #move the new x offset to %rdi, sign extended
        movsxb  b3x, %rsi               #move the new y offset to %rsi, sign extended
        call    coordToBoardOff

        cmpb    $0, (%r10, %rax)        #compare the new position of block 3 to $0
        jne     loopProcessDPl          #if it's full, place the block back down and end

        movsxb  %r8b, %rdi              #move the new x offset to %rdi, sign extended
        movsxb  %r9b, %rsi              #move the new y offset to %rsi, sign extended
        call    coordToBoardOff

        cmpb    $0, (%r10, %rax)        #compare the new position of block 2 to $0
        jne     loopProcessDPl          #if it's full, place the block back down and end

        movb    %dl, b2x                #move -b2y to b2x
        movb    %dh, b2y                #move b2x to b2y

        movb    %cl, b3x                #move -b3y to b3x
        movb    %ch, b3y                #move b3x to b3y

        movb    %r8b, b4x               #move -b4y to b4x
        movb    %r9b, b4y               #move b4x to b4y

loopProcessDPl:
        movq    $pieceChars, %rsi       #move the address of the piece character table to %rsi
        movzbq  current, %rdx           #move current into %rdx, zero extending it
        addq    %rdx, %rsi              #add %rdx to %rsi
        movb    (%rsi), %dil            #move the character into %dil
        call    addBlock

        jmp     loopEnd

loopEnd:
        cmpb    $0, gameover            #if the game is over
        jne     gameLoopOver            #return

        incq    counter                 #increment the counter
        incq    cycles                  #increment the cycles counter

        cmpq    $53100, cycles          #15 * 60 * 59, because the game speeds up by 1 frame every 15 seconds with a minimum of 1 and max of 60
        jge     loopDrop                #if the number of cycles is greater than or equal to 30 * 60 * 59, it drops the block every frame

        movq    $0, %rdx                #wipe %rdx
        movq    cycles, %rax            #move cycles to %rax
        movq    $900, %rdi              #move 1800 to %rdi, cycles per 15 seconds
        divq    %rdi                    #divide cycles by %rdi
        movq    $60, %rdi               #move 60 to %rdi
        subq    %rax, %rdi              #subtract %rax from %rdi
        cmpq    %rdi, counter           #compare counter to %rax
        jl      loopRefresh             #if counter < %rax, refresh the board and continue looping

loopDrop:
        call    downOrNew               #otherwise, move the block down or place it and get a new block
        movq    $0, counter             #reset the counter

loopRefresh:
        call    refreshBoard
        ret

gameLoopOver:
        movq    $boardStart, %rdi       #move the board starting address to %rdi
        addq    $1448, %rdi
        movw    $0x0F47, (%rdi)         #display "GAME"
        movw    $0x0F41, 2(%rdi)
        movw    $0x0F4D, 4(%rdi)
        movw    $0x0F45, 6(%rdi)

        movw    $0x0F4F, 160(%rdi)      #display "OVER"
        movw    $0x0F56, 162(%rdi)
        movw    $0x0F45, 164(%rdi)
        movw    $0x0F52, 166(%rdi)
	ret

downOrNew:
        movq    $0, %rdi                #set %rdi to 0
        call    addBlock                #erase the current block

        movq    $12, %rdi               #set %rdi to 12

        call    checkBoard              #check to see the board is empty on the right
        pushq   %rax                    #push the result because we will need it later
        addq    %rax, centery           #if it is, move the center down 1.

        movq    $pieceChars, %rsi       #move the address of the piece character table to %rsi
        movzbq  current, %rdx           #move current into %rdx, zero extending it
        addq    %rdx, %rsi              #add %rdx to %rsi
        movb    (%rsi), %dil            #move the character into %dil
        call    addBlock                

        popq    %rax
        cmpq    $0, %rax                #if the check failed, the block must be placed
        je      place
        ret

place:
        movb    next, %dl               #move the next block to %dl
        movb    %dl, current            #move the block in %dl to current

        rdtsc                           #read the time stamp counter, it's random enough
        movq    $0, %rdx                #erase %rdx
        movq    $7, %rcx                #move 7 into %rcx
        divq    %rcx                    #divide %rax by 7
        movb    %dl, next               #rdx contains the remainder, 0-6. move it into next.

clearLines:
        movq    $0, %rcx                #set a counter to 0
        movq    $0, %rdx                #set a row counter to 0
        movq    $tetrisBoard, %rdi      #set a pointer to the tetris board
        movq    $0, %r8                 #initialize a total cleared rows counter
        incq    %rdi                    #shift to the first playable byte

clearLoop:
        cmpb    $0, (%rdi, %rcx)        #check if the byte is clear
        je      clearLend               #jump to the loop end if so

        incq    %rcx                    #increment the counter
        cmpq    $10, %rcx               #compare rcx to 10
        jl      clearLoop               #if less than, continue looping

        movq    $0, %rcx                #reset %rcx
        movq    %rdx, %rax              #move the row counter into %rax
        movq    %rdi, %r9               #make a temporary pointer
        incq    %rax                    #add 1 to %rax
        incq    %r8                     #increment the total rows cleared counter

clearLine:
        movb    -12(%r9, %rcx), %sil    #move the above block down
        movb    %sil, (%r9, %rcx)      
        incq    %rcx                    #increment %rcx
        cmpq    $10, %rcx               #compare %rcx to 10
        jl      clearLine               #continue clearing the line if %rcx < 10
        
        subq    $12, %r9                #move the pointer up 1 row
        movq    $0, %rcx                #reset %rcx
        decq    %rax                    #decrement %rax
        cmpq    $0, %rax                #compare %rax to $0
        jg      clearLine               #if %rax > 0, continue shifting lines down

clearLend:
        addq    $12, %rdi               #add 12 to %rdi to shift to the next row
        incq    %rdx                    #increment %rdx
        movq    $0, %rcx                #reset %rcx
        cmpq    $20, %rdx               #compare %rdx to 20
        jl      clearLoop               #continue looping if %rdx < 20
        cmpq    $0, %r8                 #compare the number of lines cleared to 0                 
        je      newBlock                #jump directly to the new block generation if equal
        cmpq    $1, %r8                 #compare number of lines cleared to 1
        je      clearSingle             #jump to the single handler
        cmpq    $2, %r8                 #compare number of lines cleared to 2
        je      clearDouble             #jump to the double handler
        cmpq    $3, %r8                 #compare number of lines cleared to 3
        je      clearTriple             #jump to the triple handler
        jmp     clearTetris             #jump to the tetris handler
clearSingle:
        addq    $10, score              #add 10 to the score
        call    updateScore
        jmp     newBlock                #jump to block generation

clearDouble:
        addq    $25, score              #add 25 to the score
        call    updateScore
        jmp     newBlock                #jump to block generation

clearTriple:
        addq    $75, score              #add 75 to the score
        call    updateScore
        jmp     newBlock                #jump to block generation

clearTetris:
        addq    $300, score             #add 300 to the score
        call    updateScore
                                        #no need to jump
newBlock:
        call    initializeBlock         #initialize the new block, which fixes the old block in place
        cmpq    $0, %rax                #compare %rax to 0
        je      placeEnd                #if no errors, skip the next instructions


        movb    $1, gameover            #the game is lost, set gameover to 1
        
        movq    $boardStart, %rdi       #move the board starting address to %rdi
        addq    $1448, %rdi
        movw    $0x0F47, (%rdi)         #display "GAME"
        movw    $0x0F41, 2(%rdi)
        movw    $0x0F4D, 4(%rdi)
        movw    $0x0F45, 6(%rdi)

        movw    $0x0F4F, 160(%rdi)      #display "OVER"
        movw    $0x0F56, 162(%rdi)
        movw    $0x0F45, 164(%rdi)
        movw    $0x0F52, 166(%rdi)

        movq    score, %rdi             #move the current score to %rdi
        cmpq    highest, %rdi           #compare the highest score to current score
        jle     placeEnd                #if current score <= highest, jump to the end
        
        movq    %rdi, highest           #set the highest score to the current score
        call    updateHighest

placeEnd:
        movb    $0, swapped             #let the player swap again
        call    updateNext              #update the display of the next block
        ret

reset:
        movq    $0, counter             #reset counter
        movq    $0, cycles              #reset cycles
        movb    $0, gameover            #reset gameover
        movb    $0, swapped             #reset swapped
        movq    score, %rdi             #move the current score to %rdi
        cmpq    highest, %rdi           #compare the highest score to current score
        jle     resetScore              #if current score <= highest, jump past the next instructions

        movq    %rdi, highest           #set the highest score to the current score
        call    updateHighest

resetScore:
        movq    $0, score               #reset the score to 0
        call    updateScore

        rdtsc                           #read the time stamp counter, it's random enough
        movq    $0, %rdx                #erase %rdx
        movq    $7, %rcx                #move 7 into %rcx
        divq    %rcx                    #divide %rax by 7
        movb    %dl, current            #rdx contains the remainder, 0-6. move it into current.
        movq    $0, %rdx                #erase %rdx
        divq    %rcx                    #divide again
        movb    %dl, next               #move the number into next.

        movb    $0, saved               #reset the saved piece
        call    updateSave

        call    updateNext

        movq    $0, %rcx                #initialize a counter to 0
        movq    $0, %rdx                #initialize a row counter to 0
        movq    $tetrisBoard, %rdi      #move the board start index to %rdi
        addq    $1, %rdi                #shift to the first byte of the playable area

resetBoardLoop:
        movb    $0x00, (%rdi, %rcx)     #move 0 to (%rdi + %rcx)
        
        incq    %rcx                    #increment %rcx
        cmpq    $10, %rcx               #compare %rcx to 10
        jl      resetBoardLoop          #if less than, continue looping

        movq    $0, %rcx                #reset %rcx
        incq    %rdx                    #increment the row counter
        addq    $12, %rdi               #shift to the next row
        cmpq    $20, %rdx               #compare %rdx to 20
        jl      resetBoardLoop          #if less than, continue looping

        call    initializeBlock

        ret

checkBoard:     #this method, for the current center and blocks, checks if there are any blocks in the corresponding parts of the board with offset %rdi
        movq    %rdi, %rdx              #move the input to %rdx to free %rdi
        
        movzbq  centerx, %rdi           #move and extend the center x value to %rdi
        movzbq  centery, %rsi           #move and extend the center y value to %rsi
        call    coordToBoardOff         #get the offset for the center with respect to the board start

        addq    $tetrisBoard, %rax      #add the board starting address to the offset to get the address of the center
        addq    %rax, %rdx              #add the address of the center to the movement offset to get the location of the center of the moved block.

        cmpb    $0, (%rdx)              #check the location
        jne     checkBoardFailed        #if there's something there, it failed

        movsxb  b2x, %rdi               #move and sign-extend b2x to %rdi
        movsxb  b2y, %rsi               #move and sign-extend b2y to %rsi
        call    coordToBoardOff
        
        cmpb    $0, (%rdx, %rax)        #check the location
        jne     checkBoardFailed        #if there's something there, it failed

        movsxb  b3x, %rdi               #move and sign-extend b3x to %rdi
        movsxb  b3y, %rsi               #move and sign-extend b3y to %rsi
        call    coordToBoardOff
        
        cmpb    $0, (%rdx, %rax)        #check the location
        jne     checkBoardFailed        #if there's something there, it failed

        movsxb  b4x, %rdi               #move and sign-extend b4x to %rdi
        movsxb  b4y, %rsi               #move and sign-extend b4y to %rsi
        call    coordToBoardOff
        
        cmpb    $0, (%rdx, %rax)        #check the location
        jne     checkBoardFailed        #if there's something there, it failed

        movq    $1, %rax                #return success
        ret

checkBoardFailed:
        movq    $0, %rax                #return failure
        ret


initializeBlock:        #returns 1 upon failure (if something is found where it wants to place the block)
        cmpb    $0, current             #jump to the branch that initializes the correct block in the block data section.
        je      initializeI
        
        cmpb    $1, current
        je      initializeJ
        
        cmpb    $2, current
        je      initializeL
        
        cmpb    $3, current
        je      initializeO
        
        cmpb    $4, current
        je      initializeS
        
        cmpb    $5, current
        je      initializeT

        cmpb    $6, current
        je      initializeZ
        jmp     initializeBlEnd


initializeI:
        movb    $5, centerx             #move the I block shape into center and block offset variables
        movb    $2, centery             #the block is centered at (5, 2) on the tetris board
        movb    $0, b2x                 #b2 is at center x, center y-1
        movb    $0xFF, b2y
        movb    $0, b3x                 #b3 is at center x, center y-2
        movb    $0xFE, b3y
        movb    $0, b4x                 #b4 is at center x, center y+1
        movb    $1, b4y

        jmp     initializeBlEnd

initializeJ:
        movb    $5, centerx             #move the J block shape into center and block offset variables
        movb    $1, centery             #the block is centered at (5, 1) on the tetris board
        movb    $0, b2x                 #b2 is at center x, center y-1
        movb    $0xFF, b2y
        movb    $1, b3x                 #b3 is at center x+1, center y-1
        movb    $0xFF, b3y
        movb    $0, b4x                 #b4 is at center x, center y+1
        movb    $1, b4y

        jmp     initializeBlEnd

initializeL:
        movb    $6, centerx             #move the L block shape into center and block offset variables
        movb    $1, centery             #the block is centered at (6, 1) on the tetris board
        movb    $0, b2x                 #b2 is at center x, center y-1
        movb    $0xFF, b2y
        movb    $0xFF, b3x              #b3 is at center x-1, center y-1
        movb    $0xFF, b3y
        movb    $0, b4x                 #b4 is at center x, center y+1
        movb    $1, b4y
        jmp     initializeBlEnd

initializeO:
        movb    $5, centerx             #move the O block shape into center and block offset variables
        movb    $1, centery             #the block is centered at (5, 1) on the tetris board
        movb    $1, b2x                 #b2 is at center x+1, center y
        movb    $0, b2y
        movb    $1, b3x                 #b3 is at center x+1, center y-1
        movb    $0xFF, b3y
        movb    $0, b4x                 #b4 is at center x, center y-1
        movb    $0xFF, b4y

        jmp     initializeBlEnd

initializeS:
        movb    $5, centerx             #move the S block shape into center and block offset variables
        movb    $1, centery             #the block is centered at (5, 1) on the tetris board
        movb    $1, b2x                 #b2 is at center x+1, center y
        movb    $0, b2y
        movb    $1, b3x                 #b3 is at center x+1, center y+1
        movb    $1, b3y
        movb    $0, b4x                 #b4 is at center x, center y-1
        movb    $0xFF, b4y

        jmp     initializeBlEnd

initializeT:
        movb    $5, centerx             #move the T block shape into center and block offset variables
        movb    $0, centery             #the block is centered at (5, 0) on the tetris board
        movb    $0xFF, b2x              #b2 is at center x-1, center y
        movb    $0, b2y
        movb    $0, b3x                 #b3 is at center x, center y+1
        movb    $1, b3y
        movb    $1, b4x                 #b4 is at center x+1, center y
        movb    $0, b4y

        jmp     initializeBlEnd

initializeZ:
        movb    $5, centerx             #move the Z block shape into center and block offset variables
        movb    $1, centery             #the block is centered at (5, 1) on the tetris board
        movb    $1, b2x                 #b2 is at center x+1, center y
        movb    $0, b2y
        movb    $1, b3x                 #b3 is at center x+1, center y-1
        movb    $0xFF, b3y
        movb    $0, b4x                 #b4 is at center x, center y+1
        movb    $1, b4y

initializeBlEnd:
        movq    $0, %rdi                #move 0 to %rdi
        call    checkBoard              #check the board before placing
        cmpq    $1, %rax                #
        jne     initializeBlFai         #if it is full, return a failure

        movq    $pieceChars, %rsi       #move the address of the piece character table to %rsi
        movzbq  current, %rdx           #move current into %rdx, zero extending it
        addq    %rdx, %rsi              #add %rdx to %rsi
        movb    (%rsi), %dil            #move the character into %dil
        call    addBlock

        movq    $0, %rax                #load successful
	ret

initializeBlFai:
        movq    $1, %rax                #load failure
        ret

addBlock:       #this subroutine adds the current block centered at (centerx, centery) to the board, filled with the given character.
                #the given character functionality is added so i can remove it by passing 0 instead of the actual character.
        movb    %dil, %dl               #move from %dil to %dl
        movb    %dl, %dh                #use dh to check if the desired block is a deletion or an addition later
        movq    $tetrisBoard, %rcx      #move the tetris board pointer to %rcx
        
        movzbq  centery, %rsi           #move centery to %rsi
        movzbq  centerx, %rdi           #move centerx to %rsi
        call    coordToBoardOff         #get the board offset for (centerx, centery)

        addq    %rax, %rcx              #add the offset to the board pointer to get a pointer to the center block
        movb    %dl, (%rcx)             #move the character to tetrisBoard + centery * 12 + centerx

        movsxb  b2y, %rsi               #move b2y, sign extended, to %rsi
        movsxb  b2x, %rdi               #move b2x, sign extended, to %rdi
        call    coordToBoardOff         #get the board offset for (b2x, b2y)

        movb    %dl, (%rcx, %rax)       #move the character to the center address + b2 offset

        movsxb  b3y, %rsi               #move b3y, sign extended, to %rsi
        movsxb  b3x, %rdi               #move b3x, sign extended, to %rdi
        call    coordToBoardOff         #get the board offset for (b3x, b3y)
        movb    %dl, (%rcx, %rax)       #move the character to the center address + b3 offset

        movsxb  b4y, %rsi               #move b4y, sign extended, to %rsi
        movsxb  b4x, %rdi               #move b4x, sign extended, to %rdi
        call    coordToBoardOff         #get the board offset for (b4x, b4y)

        movb    %dl, (%rcx, %rax)       #move the character to the center address + b4 offset

        movq    $0, %rax
	ret

coordToBoardOff:        #this subroutine takes coordinates/offsets in %rdi and %rsi and returns the board offset in %rax, specifically only using those three registers
        shlq    $2, %rsi                #%rsi = 4 * y
        movq    %rsi, %rax              #%rax = 4 * y
        shlq    $1, %rax                #%rax = 8 * y
        addq    %rsi, %rax              #%rax = 12 * y
        addq    %rdi, %rax              #%rax = 12 * y + x
        ret

refreshBoard:
        movq    $0, %rcx                #initialize counter
        movq    $0, %r8                 #initialize row counter
        movq    $tetrisBoard, %rdx      #move the board address into %rdx
        movq    $boardStart, %rdi       #move the graphical start of the board into %rdi
        movq    $colorTable, %rsi       #move the base address of the color table to %rsi

refreshLoop:
        movq    $0, %rax
        movb    (%rdx), %al             #move the character into %al
        movb    (%rsi, %rax), %ah       #get the character's color and move it into %ah
        movw    %ax, (%rdi)             #move the character word into graphical memory
        
        incq    %rdx                    #add 1 to the board address
        addq    $2, %rdi                #add 2 to the graphics memory address
        incq    %rcx                    #add 1 to the counter
        cmpq    $12, %rcx               #compare rcx to 12
        jl      refreshLoop             #if less than, continue looping

        movq    $0, %rcx                #reset %rcx
        incq    %r8                     #increment r8
        addq    $136, %rdi              #move to the start of the next row
        cmpq    $21, %r8                #compare the number of rows to 21
        jl      refreshLoop             #if less than, continue looping
	ret

drawBlock:      #takes an address and draws the block in a 4x4 cell with the top-left corner being that address
        movq    $0, (%rdi)              #this will zero out the entire box
        movq    $0, 160(%rdi)
        movq    $0, 320(%rdi)
        movq    $0, 480(%rdi)

        cmpb    $0, %sil                #jump to the branch that shows the correct shape
        je      drawBlockI
        cmpb    $1, %sil
        je      drawBlockJ
        cmpb    $2, %sil
        je      drawBlockL
        cmpb    $3, %sil
        je      drawBlockO
        cmpb    $4, %sil
        je      drawBlockS
        cmpb    $5, %sil
        je      drawBlockT
        cmpb    $6, %sil
        je      drawBlockZ
        jmp     drawBlockEnd
        
drawBlockI:
        movw    $0x0323, 2(%rdi)        #display an I block
        movw    $0x0323, 162(%rdi)
        movw    $0x0323, 322(%rdi)
        movw    $0x0323, 482(%rdi)
        jmp     drawBlockEnd            #jump to the end

drawBlockJ:
        movw    $0x0124, 2(%rdi)        #display a J block
        movw    $0x0124, 4(%rdi)
        movw    $0x0124, 162(%rdi)
        movw    $0x0124, 322(%rdi)
        jmp     drawBlockEnd            #jump to the end

drawBlockL:
        movw    $0x0625, 2(%rdi)        #display an L block
        movw    $0x0625, 4(%rdi)
        movw    $0x0625, 164(%rdi)
        movw    $0x0625, 324(%rdi)
        jmp     drawBlockEnd            #jump to the end

drawBlockO:
        movw    $0x0E26, 162(%rdi)      #display an O block
        movw    $0x0E26, 164(%rdi)
        movw    $0x0E26, 322(%rdi)
        movw    $0x0E26, 324(%rdi)
        jmp     drawBlockEnd            #jump to the end

drawBlockS:
        movw    $0x0A40, 2(%rdi)        #display an S block
        movw    $0x0A40, 162(%rdi)
        movw    $0x0A40, 164(%rdi)
        movw    $0x0A40, 324(%rdi)
        jmp     drawBlockEnd            #jump to the end

drawBlockT:
        movw    $0x0548, 160(%rdi)      #display a T block
        movw    $0x0548, 162(%rdi)      
        movw    $0x0548, 164(%rdi)
        movw    $0x0548, 322(%rdi)
        jmp     drawBlockEnd            #jump to the end

drawBlockZ:
        movw    $0x044D, 4(%rdi)        #display a Z block
        movw    $0x044D, 162(%rdi)      
        movw    $0x044D, 164(%rdi)
        movw    $0x044D, 322(%rdi)      #no jump is needed.

drawBlockEnd:
        ret

updateSave:
        movb    saved, %sil             #move the saved value to %sil
        movq    $boardStart, %rdi       #calculate a pointer to the "SAVE" display box in graphics memory
        addq    $150, %rdi              
        call    drawBlock               #draw the block
        ret

updateNext:
        movb    next, %sil              #move the next block value to %sil
        movq    $boardStart, %rdi       #calculate a pointer to the "NEXT" display box in graphics memory
        addq    $1110, %rdi             
        call    drawBlock               #draw the block
        ret

displayNumber:  #this subroutine displays a number of %rsi digits, zero-extended ahead, starting at location %rdi in VGA memory. the number is stored in %rdx
        movq    %rdx, %rax              #move the number into %rax to prepare for division
        movq    $0, %rdx                #zero out %rdx
        movq    $10, %r8                #move the divisor into a register
        decq    %rsi                    #decrement %rsi to get the first character index

displayLoop:
        divq    %r8                     #divide by 10
        addb    $0x30, %dl              #add 0x30 to get the ascii code for the digit
        movb    $0x0F, %dh              #move the color byte for white text on black background into %dh
        movw    %dx, (%rdi, %rsi, 2)    #move the remainder byte and the color byte to VGA memory

        movq    $0, %rdx                #zero out %rdx again
        decq    %rsi                    #decrement %rsi

        cmpb    $0xFF, %sil             #compare %rsi to -1. it also can't be greater than 80, so the byte comparison works
        jg      displayLoop             #if greater than, continue looping

        ret

updateScore:
        movq    score, %rdx             #move the score into %rdx
        movq    $9, %rsi                #move the desired length of 9 into %rsi
        movq    $boardStart, %rdi       #set the address to below the score display with this line and the next
        addq    $186, %rdi        

        call    displayNumber
        ret

updateHighest:
        movq    highest, %rdx           #move the highest score into %rdx
        movq    $9, %rsi                #move the length of 9 into %rsi
        movq    $boardStart, %rdi       #set the address to below the highest score display with this line and the next
        addq    $666, %rdi

        call    displayNumber

        ret
        