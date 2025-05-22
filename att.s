.data

@ ================================================================
@ Characters to fill each player's tile's with

.equ TILE_P0, 'x'
.equ TILE_P1, 'o'

@ ================================================================

@ Other Global Constants
.equ NUM_TILES,     9
.equ NUM_WINS,      8
.equ MAX_READ,      16
.equ SYS_NANOSLEEP, 162
.equ SYS_STDIN,     0
.equ SYS_STDOUT,    1
.equ SYS_READ,      3
.equ SYS_WRITE,     4

@ Title Card & Sleep Data
title_card: .asciz "    ___    ____   __  __        ______ ___    ______        _____  _____ ______\n   /   |  / __ | / / / /       /_  __//   |  / ____/       /_  __/ _   / ____/\n  / /| | / /_/ / /|_/ /  _____   / / / /| | / /     ______  / / / / / / __/   \n / ___ |/ _, _/ /  / /  /_____/ / / / ___ |/ /__   /_____/ / / / /_/ / /___   \n/_/  |_/_/ |_/_/  /_/          /_/ /_/  |______/          /_/ /____ /_____/  \n"

timespecsec:  .word 5
timespecnano: .word 0

@ ================================================================
@ Board state ascii representation:
@ * Print by loading board_state with printf(board_frmt)
@ * board_frmt is replaced with 'x' and 'o' chars as
@ * Default State example:
@   _0_|_1_|_2_
@   _3_|_4_|_5_
@    6 | 7 | 8

board_frmt:  .asciz "\n_%c_|_%c_|_%c_\n_%c_|_%c_|_%c_\n %c | %c | %c \n\n"
board_state: .byte '0','1','2','3','4','5','6','7','8'

msg_tie:    .string "Tie!\n"
msg_win_p1: .string "x's Win!\n"
msg_win_p2: .string "o's Win!\n"

@ ================================================================
@ Player tile bitmasks
@ tile_bitmask_p0[3] = 1 means tile 3 is filled by player 0
@ if tile_bitmask_p0[3] = 1 then always tile_bitmask_p1[3] = 0

tile_bitmask_p0: .word 0
tile_bitmask_p1: .word 0

@ ================================================================
@ Local variable for sub_player_turn
@ Track activePlayer bit in case of retry
.equ APB, -4
.equ APB_SIZE, 4
  
@ ================================================================
@ Win bitmasks
@ Represent all combinations of tile_bitmask for any given player
@ A win is found if ((wb_<x> & tile_bitmask_p<y>) == wb_<x>)

wb_0: .word 0b111000000
wb_1: .word 0b000111000
wb_2: .word 0b000000111
wb_3: .word 0b100100100
wb_4: .word 0b010010010
wb_5: .word 0b001001001
wb_6: .word 0b100010001
wb_7: .word 0b001010100

@ ================================================================
@ Player input
@ Inputs equal the integer index of the tile the player is putting an 'x' or 'o' into
@ Hence only one byte is ever required (.space 1)

pmt:        .string "%c's Turn. Please input a number corresponding to an open spot on the grid.\n"
input_frmt: .asciz "%d %s"
input_buff: .space MAX_READ
input_num:  .space MAX_READ
input_dump: .space MAX_READ

.balign 4
@ ================================================================

.text
.global main
.func main
main:
    push {r4-r12, lr}  @ ctx switch save state

print_title_card:
    ldr r0, =title_card @ r0 = *title_card
    bl printf           @ r0 = bytes written

sleep_ns:
    ldr r0, =timespecsec   @ r0 = *timespecsec
    ldr r1, =timespecnano  @ r1 = *timespecnano
    mov r7, #SYS_NANOSLEEP @ nanosleep syscall
    svc 0

game_init:
    mov r4, #1         @ r4 = turnNum
    mov r5, #0         @ r5 = (bool) activePlayer

game_loop:
    bl sub_print_ascii_board

    cmp r4, #NUM_TILES @ if (turnNum >= NUM_TILES)
    bgt game_tie_endP  @ True, end game with tie

    mov r0, r5		   @ r0 = activePlayer
    bl sub_player_turn

    cmp r4, #5         @ if turnNum < 5 (win is impossible)
    blt game_cont      @ true, goto game_cont 
    mov r0, r5         @ r0 = activePlayer
    bl sub_test_win    @ r0 = (bool) win

    cmp r0, #1         @ if win = 1
    beq game_win_endP  @ true, goto win_endP

game_cont:
    add r4, #1     @ turnNum++
    eor r5, r5, #1 @ activePlayer = !activePlayer

    b game_loop

game_tie_endP:
    ldr r0, =msg_tie @ r0 = *msg_tie
    b endP           @ goto endP

game_win_endP:
    bl sub_print_ascii_board

    cmp r5, #0            @ if activePlayer == 0
    ldreq r0, =msg_win_p1 @ true, r0 = *msg_win_p1
    ldrne r0, =msg_win_p2 @ false, r0 = *msg_win_p2
    
endP:
    bl printf          @ print win/tie msg
    pop {r4-r12, lr}   @ ctx switch load state
    bx lr              @ return to glibc

@ ================================================================
@ Print ASCII Board - Subroutine
@ No args
@ No return

sub_print_ascii_board:
    push {r4-r12, lr} @ ctx switch save state

    ldr r0, =board_frmt     @ r0 = format string
    ldr r10, =board_state   @ r10 = *board_state

    @ Each character from board_state is loaded into registers r1-r9
    ldrb r1, [r10]          @ r1 = board_state[0]
    ldrb r2, [r10, #1]      @ r2 = board_state[1]
    ldrb r3, [r10, #2]      @ r3 = board_state[2]
    ldrb r4, [r10, #3]      @ r4 = board_state[3]
    ldrb r5, [r10, #4]      @ r5 = board_state[4]
    ldrb r6, [r10, #5]      @ r6 = board_state[5]
    ldrb r7, [r10, #6]      @ r7 = board_state[6]
    ldrb r8, [r10, #7]      @ r8 = board_state[7]
    ldrb r9, [r10, #8]      @ r9 = board_state[8]

    push {r4-r9}

    bl printf               @ Printing board_frmt r1-r9
    add sp, sp, #24         @ free stack memory

sub_print_ascii_board_endP:
    pop {r4-r12, lr}  @ ctx switch load state
    bx lr             @ exit subroutine

@ ================================================================
@ Player Turn - Subroutine
@ r0 = activePlayer
@ No return

sub_player_turn:
    push {r4-r12, lr}  @ ctx switch save state
    mov fp, sp         @ fp = space
    sub sp, #APB_SIZE  @ alloc for APB
    str r0, [fp, #APB] @ store APB in case of retry

    b sub_player_turn_prompt

sub_player_turn_retry:
    ldr r0, [fp, #APB] @ restore original APB

sub_player_turn_prompt:
    mov r4, r0         @ r4 = activePlayer
    cmp r4, #0         @ if player 0
    moveq r1, #TILE_P0 @ r1 = TILE_P0 (true)
    movne r1, #TILE_P1 @ r1 = TILE_P1 (false) 
    mov r5, r1         @ r5 = TILE_P<x> (save for later)
    ldr r0, =pmt       @ r0 = *pmt
    bl printf          @ r0 = bytes written

sub_player_turn_input:
    mov r0, #SYS_STDIN  @ r0 = 0 (stdin)
    ldr r1, =input_buff	@ r1 = *input_buff
    mov r2, #MAX_READ	@ r2 = MAX_READ
    mov r7, #SYS_READ   @ read syscall
    svc 0               @ r0 = bytes read

sub_player_turn_parse:
    ldr r0, =input_buff        @ r0 = *input_buff
    ldr r1, =input_frmt        @ r1 = *input_frmt
    ldr r2, =input_num         @ r2 = *input_num
    bl sscanf                  @ r0 = items parsed

    cmp r0, #0                 @ if (items parsed) <= 0
    ble sub_player_turn_retry  @ true, get new input 

    ldr r0, =input_num         @ r0 = *input_num
    ldr r0, [r0]               @ r0 = input_num

    @ Check for index out of range
    cmp r0, #0                 @ if input_num < 0
    blt sub_player_turn_retry  @ true, get new input
    cmp r0, #8                 @ if input_num > 8
    bgt sub_player_turn_retry  @ true, get new input

    @ Get activePlayer bitmask
    cmp r4, #0                 @ if activePlayer == 0
    ldreq r9, =tile_bitmask_p0 @ r9 = *(activePlayer bitmask) (p0)
    ldreq r2, =tile_bitmask_p1 @ r2 = *(inactivePlayer bitmask) (p1)
    ldrne r9, =tile_bitmask_p1 @ r9 = *(activePlayer bitmask) (p1)
    ldrne r2, =tile_bitmask_p0 @ r2 = *(inactivePlayer bitmask) (p0)
    ldr r1, [r9]               @ r1 = (activePlayer bitmask)
    ldr r2, [r2]               @ r2 = (inactivePlayer bitmask)

    mov r6, #1                 @ prepare player move bit
    rsb r10, r0, #8            @ r10 = i
    lsl r6, r10                @ r6 = player new move

    @ if ((r1 & r6) == r6) || ((r2 & r6) == r6) tile already filled, branch back to prompt
    and r8, r1, r6             @ r8 = r1 & r6
    cmp r8, r6                 @ if r8 == r6
    beq sub_player_turn_retry  @ get new input
    and r8, r2, r6             @ r8 = r2 & r6
    cmp r8, r6                 @ if r8 == r6
    beq sub_player_turn_retry  @ get new input

    @ Update board_state
    ldr r3, =board_state       @ r3 = *board_state
    strb r5, [r3, r0]          @ board_state[input_num] = TILE_P<X>

    orr r1, r6                 @ r1 |= r6
    str r1, [r9]               @ store new bitmask

sub_player_turn_endP:
    mov sp, fp        @ free APB mem
    pop {r4-r12, lr}  @ ctx switch load state
    bx lr             @ exit subroutine

@ ================================================================
@ Test For Win - Subroutine
@ r0 = active player bit (0 or 1)
@ Return true (1) if activePlayer has won

sub_test_win:
    push {r4-r12, lr}          @ ctx switch save state

    cmp r0, #0                 @ if p0 is active player  
    ldreq r0, =tile_bitmask_p0 @ r0 = *tile_bitmask_p0 (true)
    ldrne r0, =tile_bitmask_p1 @ r0 = *tile_bitmask_p1 (false)

    ldr r1, [r0]               @ r1 = tile_bitmask_p<x>
    mov r0, #0                 @ win = false
    ldr r2, =wb_0              @ r2 = *wb_0
    mov r3, #0                 @ i = 0

sub_test_win_loop:
    cmp r3, #NUM_WINS         @ if i >= NUM_WINS (NUM_WINS = ways to win)
    beq sub_test_win_endP     @ true, goto end (all masks have been checked)

    ldr r4, [r2, r3, lsl #2]  @ r4 = wb_<i>
    and r5, r1, r4            @ r5 = (tile_bitmask_p<x> & wb_<i>)
    cmp r4, r5                @ if (tile_bitmask_p<x> & wb_<i>) == wb_<i>
    beq sub_test_win_true     @ active player has won

    add r3, #1                @ i++
    b sub_test_win_loop       @ goto next itr

sub_test_win_true:
    mov r0, #1 @ win = true

sub_test_win_endP:
    pop {r4-r12, lr}  @ ctx switch load state
    bx lr             @ exit subroutine

