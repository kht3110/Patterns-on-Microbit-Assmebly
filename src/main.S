.syntax unified
.global main

@ the address for the registers and offsets in the microbits are referenced from library 

.type main, %function
main:
  @ unitlizing the library to initialize the LEDs
  bl init_leds

  @ configure GPIOTE_CONFIG[0] for the button A
  ldr r0, =ADR_GPIOTE
  ldr r1, =OFS_GPIOTE_CONFIG0
  ldr r2, =(1 | 14 << 8 | 0 << 13 | 1 << 16) @ enable the button, pin 14, port 0, triggered when changed from Low to High
  str r2, [r0, r1]

  @ configure GPIOTE_CONFIG[1] for button B
  ldr r0, =ADR_GPIOTE
  ldr r1, =OFS_GPIOTE_CONFIG1
  ldr r2, =(1 | 23 << 8 | 0 << 13 | 1 << 16) @ enable the button, pin 23, port 0, triggered when changed from Low to High
  str r2, [r0, r1]

  @ configure GPIOTE_CONFIG[2] for the face_touch
  ldr r0, =ADR_GPIOTE
  ldr r1, =OFS_GPIOTE_CONFIG2
  ldr r2, =(1 | 4 << 8 | 1 << 13 | 1 << 16) @ enable the button, pin 4, port 1, triggered when changed from Low to High (one touch)
  str r2, [r0, r1]

  @ enable interrupt for GPIOTE[0] (id = 6)
  ldr r0, =ADR_GPIOTE
  ldr r1, =OFS_GPIOTE_INTENSET    
  ldr r2, =0b111      @ for config 0 to 2
  str r2, [r0, r1]

  @ enable GPIOTE in NVIC_ISER0
  ldr r0, =ADR_NVIC
  ldr r1, =OFS_NVIC_ISER0
  ldr r2, =(1 << 6)   @ id = 6 
  str r2, [r0, r1] 

  @ enable the SysTick Timer 
  ldr r0, =ADR_SYST_CSR 
  ldr r1, [r0]
  mov r2, 0b111     @ enable, allows SysTick exception status, processor clock
  orr r1, r2
  str r1, [r0]

  @ set the reload value at the maximum of the value (the reload value is from 0 - 23 bits)
  ldr r0, =ADR_SYST_RVR
  ldr r1, =reload_value_SysTick
  ldr r1, [r1]
  str r1, [r0]

  @ this is where the program actually starts. previous are for setup.
  start: 

  @ read from word_show_mode to see if the program is current running the word show. if yes, go to the branch of word show
  ldr r0, =word_show_mode
  ldr r0, [r0]
  cmp r0, #1
  beq b_word_show

  @ read from mode to see if the program is current running the pwm mode. if not, go to the branch of scanning
  ldr r0, =mode
  ldr r0, [r0]
  cmp r0, #0
  bne b_scanning

  @ branch of pwm mode, default
  b_pwm:

    @ jump to the pwm branch for execution
    bl pwm

    @ to mark if the show is finished for at least one time. this will be used as an indicator for switching the pattern in the SysTick handler
    ldr r12, =finished_loop
    mov r11, #1
    str r11, [r12]

    b start

  @ branch of scanning (mode value = 1)
  b_scanning:

    @ jump to the scanning branch for execution
    bl scanning

    @ to mark if the show is finished for at least one time. this will be used as an indicator for switching the pattern in the SysTick handler
    ldr r12, =finished_loop
    mov r11, #1
    str r11, [r12]

    b start

  @ branch of word show (word show mode value = 1)
  b_word_show:

    @ jump to the word show branch for execution
    bl word_show

  @ go back to the start for the loop (not back to main to avoid setups)
  b start
.size main, .-main


.type pwm, %function
@ execution of pwm
@ no arguments required
pwm:

  @ store the link to the stack
  push {lr}

  @ get the on and off interval of the LEDs from the address pointed by the light_pointer
  ldr r2, =light_pointer
  ldr r1, [r2]
  ldr r0, [r1]

  @ put the address to stack as this is needed again later
  push {r1}

  @ move the values in r0 to r2 as the set_pins functions needs r2 as the on interval/delay
  mov r2, r0
  
  @ turn the pins on with the argument
  bl set_pins

  @ turn the pins off
  mov r0, 0b00000
  bl write_column_pins
  mov r0, 0b00000
  bl write_row_pins

  @ pop r1 form the stack and add the interval/delay value for turning the LEDs off
  pop {r1}
  ldr r0, [r1, 4]!  
  bl delay

  @ get the link from the stack and exit the branch
  pop {lr}
  bx lr
.size pwm, .-pwm


.type scanning, %function
@ execution of scanning
@ no arguments required
scanning:

  @ store the link to the stack
  push {lr}

  @ load the repeated_times address to r0 and the timer address to r1, so that we can compute the counter/the number of loops that we need to perform
  ldr r0, =repeated_times
  ldr r1, =timer
  sub r0, r1
  mov r2, #4
  udiv r0, r2

  @ jump to the loop to loop through the counter that we compute in r0
  @ arguments: r0 = the counter, r1 = the timer address
  bl  set_timer_loop

  @ get the link from the stack and exit the branch
  pop {lr}
  bx lr
.size scanning, .-scanning


.global GPIOTE_IRQHandler
.type GPIOTE_IRQHandler, %function
@ the handler for the interrupts arise form the GPIO. this is used as a switch for differnet modes as well
GPIOTE_IRQHandler:

  @ store the link to the stack
  push {lr}

  @ store the value of word show mode for later use
  ldr r0, =word_show_mode
  ldr r0, [r0]

  @ check if button A is pressed. if yes, jump to the branch A
  ldr r1, =ADR_GPIOTE
  ldr r2, =OFS_GPIOTE_EVENTS_IN0
  ldr r3, [r1, r2]
  cmp r3, #1
  beq b_branch_A

  @ check if button B is pressed. if yes, jump to the branch B
  ldr r1, =ADR_GPIOTE
  ldr r2, =OFS_GPIOTE_EVENTS_IN1
  ldr r3, [r1, r2]
  cmp r3, #1
  beq b_branch_B

  @ check if face_touch is pressed. if yes, jump to the branch for switching the word show mode
  ldr r1, =ADR_GPIOTE
  ldr r2, =OFS_GPIOTE_EVENTS_IN2
  ldr r3, [r1, r2]
  cmp r3, #1
  beq b_word_show_change

  b_branch_A:
    
    @ go the branch_A
    @ argument: r0 = word show mode value
    bl branch_A

    b end

  b_branch_B:

    @ go the branch_B
    @ argument: r0 = word show mode value
    bl branch_B

    b end

  b_word_show_change:
    
    @ go the word_show_change branch
    @ argument: r0 = word show mode value
    bl word_show_change

  end:

  pop {lr}

  bx lr
.size GPIOTE_IRQHandler, .-GPIOTE_IRQHandler


.type branch_A, %function
@ r0: word_show_mode value
branch_A:

  @ store the link to the stack
  push {lr}

  @ check if we are in the word_show_mode
  cmp r0, #1

  @ if not, go to the branch to change the pwm pace
  bne pwm_pace_change
  
  @ if yes, go to the branch to shift the words to the left
  bl left_shift

  @ go to the end of this function
  b end_branch_A

    pwm_pace_change:
      @ go to the branch to change the pwm pace
      bl pace_change

    @ go to the end of this function
    b end_branch_A

  end_branch_A:
  @ get the link from the stack and exit the branch
  pop {lr}
  bx lr
.size branch_A, .-branch_A


.type branch_B, %function
@ r0: word_show_mode value
branch_B:

  @ store the link to the stack
  push {lr}

  @ check if we are in the word_show_mode
  cmp r0, #1

  @ if not, go to the branch to change the mode
  bne pwm_mode_change

  @ if yes, go to the branch to shift the words to the right
  bl right_shift

  @ go to the end of this function
  b end_branch_B

    pwm_mode_change:
      @ go to the branch to change the mode
      bl mode_change

    @ go to the end of this function
    b end_branch_B

  end_branch_B:
  @ get the link from the stack and exit the branch
  pop {lr}
  bx lr
.size branch_B, .-branch_B


.type mode_change, %function
@ to switch the mode from pwm to scanning or vice versa
mode_change:

  @ store the link to the stack
  push {lr}

  @ clear interrupt
  ldr r1, =ADR_GPIOTE
  ldr r2, =OFS_GPIOTE_EVENTS_IN1
  ldr r3, =0
  str r3, [r1, r2]

  @ set the change interrupt hit value to 1 for later use in the delay function
  ldr r0, =change_interrupt_hit
  mov r1, #1
  str r1, [r0]

  @ check if we are in the pwm mode
  ldr r0, =mode
  ldr r1, [r0]
  cmp r1, #0    @ 0 means PWM, 1 means scanning

  @ if yes, change to scanning mode
  beq change_scanning

  @ if not, chagne to pwm mode
  change_pwm:
    
    @ set the value of pwm mode to 0 and store that back
    mov r1, #0
    str r1, [r0]

    @ go to the end of this function
    b end_mode_change

  @ change to scanning mode
  change_scanning:

    @ set the value of pwm mode to 1 and store that back
    mov r1, #1
    str r1, [r0]

  end_mode_change:
  @ get the link from the stack and exit the branch
  pop {lr}
  bx lr
.size mode_change, .-mode_change


.type word_show_change, %function
@ to switch the mode from pwm/scanning to word show or vice versa
word_show_change:

  @ store the link to the stack
  push {lr}

  @ clear interrupt
  ldr r1, =ADR_GPIOTE
  ldr r2, =OFS_GPIOTE_EVENTS_IN2
  ldr r3, =0
  str r3, [r1, r2]

  @ set the change interrupt hit value to 1 for later use in the delay function
  ldr r0, =change_interrupt_hit
  mov r1, #1
  str r1, [r0]

  @ check if we are in the word show mode. the r0 that stores the address of word show mode and the r1 that stores the value of the word show mode will be used later as arguments
  ldr r0, =word_show_mode
  ldr r1, [r0]
  cmp r1, #0

  @ if not, change to word show mode
  beq b_word_show_on

  @ if yes, chagne to pwm/scanning mode
  b_word_show_off:

    @ go to the word show off branch for execution
    bl word_show_off

    @ go to the end of this function
    b end_word_show_change

  @ change to word show mode
  b_word_show_on:

    @ go to the word show off branch for execution
    bl word_show_on

  end_word_show_change:
  @ get the link from the stack and exit the branch
  pop {lr}
  bx lr
.size word_show_change, .-word_show_change


.type word_show_off, %function
@ to turn off the word show mode and switch back to pwm/scanning mode
@ r0: address of the word_show_mode
@ r1: word_show_mode value
word_show_off:

  @ store the link to the stack
  push {lr}

  @ change the value of the word show mode to 0 and store that back
  mov r1, #0
  str r1, [r0]

  @ clear interrupt
  ldr r1, =ADR_GPIOTE
  ldr r2, =OFS_GPIOTE_EVENTS_IN2
  ldr r3, =0
  str r3, [r1, r2]  

  ldr r0, =pattern_pointer
  ldr r1, =pattern_start
  str r1, [r0]

  @ get the link from the stack and exit the branch
  pop {lr}
  bx lr
.size word_show_off, .-word_show_off


.type word_show_on, %function
@ to turn on the word show mode and switch from pwm/scanning mode
@ r0: address of the word_show_mode
@ r1: word_show_mode value
word_show_on:

  @ store the link to the stack
  push {lr}

  @ change the value of the word show mode to 1 and store that back
  mov r1, #1
  str r1, [r0]

  @ clear interrupt
  ldr r0, =ADR_GPIOTE
  ldr r1, =OFS_GPIOTE_EVENTS_IN2
  ldr r2, =0
  str r2, [r0, r1]

  @ get the link from the stack and exit the branch
  pop {lr}
  bx lr
.size word_show_on, .-word_show_on


.type left_shift, %function
@ shift the words that are showing one column left
@ r0: address of the word_show_mode
@ r1: word_show_mode value
left_shift:

  @ store the link to the stack
  push {lr}

  @ clear interrupt
  ldr r1, =ADR_GPIOTE
  ldr r2, =OFS_GPIOTE_EVENTS_IN0
  ldr r3, =0
  str r3, [r1, r2]

  @ check if the current display is at the left end
  ldr r0, =word_show_offset
  ldr r1, [r0]
  cmp r1, #0

  @ if yes, we do nothing
  beq end_left_shift

  @ if not, we subtract one from the offset value and store that back, so that the program knows where to start next
  sub r1, 1
  str r1, [r0]

  end_left_shift:
  @ get the link from the stack and exit the branch
  pop {lr}
  bx lr
.size left_shift, .-left_shift


.type right_shift, %function
@ shift the words that are showing one column right
@ r0: address of the word_show_mode
@ r1: word_show_mode value
right_shift:

  @ store the link to the stack
  push {lr}

  @ clear interrupt
  ldr r1, =ADR_GPIOTE
  ldr r2, =OFS_GPIOTE_EVENTS_IN1
  ldr r3, =0
  str r3, [r1, r2]

  @ check if the current display is at the right end
  ldr r0, =word_show_offset
  ldr r1, [r0]
  ldr r2, =word_show_pattern
  sub r2, r0, r2
  lsr r2, #2
  sub r2, #5
  cmp r1, r2

  @ if yes, we do nothing
  beq end_right_shift

  @ if not, we add one to the offset value and store that back, so that the program knows where to start next
  add r1, 1
  str r1, [r0]
  
  end_right_shift:
  @ get the link from the stack and exit the branch
  pop {lr}
  bx lr
.size right_shift, .-right_shift

.type pace_change, %function
@ change the time interval for turning on and off the LEDs
pace_change:

  @ get the link from the stack and exit the branch
  push {lr}

    @ clear interrupt
    ldr r0, =ADR_GPIOTE
    ldr r1, =OFS_GPIOTE_EVENTS_IN0
    ldr r2, =0
    str r2, [r0, r1]

    @ shift to the next set of on and off interval
    ldr r0, =light_pointer
    ldr r1, [r0]
    add r1, #8
    
    @ if the light_pointer is already back to itself, go back to the first one
    cmp r1, r0
    bpl light_back_to_start

    @ to change the light frequency
    dimmer:
      str r1, [r0]

      @ go to the end of this function
      b end_change

    @ set the light pointer back to the light start
    light_back_to_start:
      ldr r1, [r0, 4]
      ldr r0, =light_pointer
      str r1, [r0]

  end_change:
  @ get the link from the stack and exit the branch
  pop {lr}
  bx lr
.size pace_change, .-pace_change


.type set_timer_loop, %function
@ to repeat the display according to the repeated times
@ r0: countdown until the timer change
@ r1: the address of the timer
set_timer_loop:

  @ store the link to the stack
  push {lr}

  @ loop through the timer counter
  timer_loop:

    @ load from the timer address for the desired delay timer
    ldr r2, [r1], 4
    
    @ store the registers to the stack
    push {r0 - r2}

    @ load the times to be repeated using the same delay timer to r3, which will be used in the set_repeat_loop function
    ldr r0, =repeated_times
    ldr r3, [r0]

    @ loop thought the number of times that we want the display to be repeated shown with the correct arguments
    bl set_repeat_loop      

    @ get the values for the registers back from the stack
    pop {r0 - r2}

    @ subtract 1 from r0, which is out counter in this loop to see if we reach the end of the loop
    sub r0, #1
    cmp r0, #0

    @ if not, loop again
    bne timer_loop

  @ if yes,get the link from the stack and exit the branch
  pop {lr}
  bx lr
.size set_timer_loop, .-set_timer_loop


.type set_repeat_loop, %function
@ to repeat the display according to delay timer and the repeated times counter
@ r0: repeated_time address
@ r1: new timer address
@ r2: timer
@ r3: repeated_times counter
set_repeat_loop:

  @ store the link to the stack
  push {lr}

      @ loop through the repeated_times counter
      repeat_loop:

        @ store the registers to the stack
        push {r0 - r2}
        push {r3}

        @ jump to the function to set the pins on or off with the correct arguments
        bl set_pins

        @ get the values for the registers back from the stack
        pop {r3}
        pop {r0- r2}

        @ subtract 1 from r3, which is out counter in this loop to see if we reach the end of the loop
        sub r3, #1
        cmp r3, #0

        @ if not, loop again
        bne repeat_loop

  @ if yes, get the link from the stack and exit the branch
  pop {lr}
  bx lr
.size set_repeat_loop, .-set_repeat_loop


.type set_pins, %function
@ to repeat the display according to delay timer to set the pins
@ r0: repeated_time address
@ r1: new timer address
@ r2: timer
@ r3: repeated_times counter
set_pins:

  @ store the link to the stack
  push {lr}
  
  @ move the values in r2 to r4 to avoid the value be messed up
  mov r4, r2

  @ load the address where values to be assigned to the bits in the row are stored from the address stored in the pattern_pointer
  ldr r0, =pattern_pointer
  ldr r0, [r0]

  @ set r1 to 5 and loop through this as our display has a 5x5 layout
  mov r1, #5

  @ load the address from the column list, which will be used later
  ldr r3, =column_list

  @ loop through the columns/rows
  set:
    @ get the values to be assignmed to the bits
    ldr r2, [r0], 4

    @ store the registers to the stack
    push {r1}
    push {r0}
    push {r3}

    @ move the values in r2 to r0 as the function write_row_pin needs to values of the bits to be set stored in r0
    mov r0, r2
    bl write_row_pins

    @ get the values to be set in the columns from the information that we stored in the stack with a post-offset and store that to r0 as requried by write_row_pin
    pop {r1}
    ldr r0, [r1], 4
    push {r1}
    bl write_column_pins

    @ move the value in r4, the desired time to be delayed, to r0, as required by the delay function
    mov r0, r4
    bl delay

    @ get the values for the registers back from the stack
    pop {r3}
    pop {r0}
    pop {r1}

    @ subtract 1 from r1, which is out counter in this loop to see if we reach the end of the loop
    sub r1, #1
    cmp r1, #0

    @ if not, loop again
    bne set

  @ if yes,get the link from the stack and exit the branch
  pop {lr}
  bx lr
.size set_pins, .-set_pins


.type delay, %function
@ to delay the display, a revised version form the util.S
@ r0: delay amount
delay:
  
  @ check if we hit the interrupt
  ldr r2, =change_interrupt_hit
  ldr r1, [r2]
  cmp r1, #1

  @ if yes, force the program to go back to the start label
  beq back_to_start

  @ if not, subtract one and remain in the loop
  subs r0, 1

  @ the result of the subtraction is negative, jump out of the loop
  bmi delay_return
  
  b delay

  @ to get back to the start
  back_to_start:

    @ set the change_interrupt_hit back to 0
    mov r1, #0
    str r1, [r2]

    @ go back to the start
    b start

  delay_return:
  @ exit the branch
  bx lr
.size delay, .-delay


.global SysTick_Handler
.type SysTick_Handler, %function
@ use the SysTick Handler to automatically change the display
SysTick_Handler:
  
  @ SysTick will do nothing if we are in word show mode
  ldr r12, =word_show_mode
  ldr r11, [r12]
  cmp r11, #1
  beq end_SysTick
  
  @ if we have not finished loop the display once, SysTick will do nothing as well
  ldr r12, =finished_loop
  ldr r11, [r12]
  cmp r11, #1
  bne end_SysTick
  
  @ change the display pattern
  pattern_changed:

    @ set the finished loop indicator back to 0
    mov r11, #0
    str r11, [r12]

    @ get the pattern pointer and its value, add that by 20 (which is from 5 entries * 4 bytes) 
    ldr r12, =pattern_pointer
    ldr r11, [r12]
    add r11, #20

    @ if the light_pointer is already back to itself, go back to the first one
    cmp r11, r12
    bpl pattern_back_to_start

    @ to switch to the next pattern
    next_pattern:
      str r11, [r12]

      @ go to the end of this function
      b end_change_pattern

    @ chagne the next pattern back to the first one
    pattern_back_to_start:
      ldr r11, [r12, 4]
      ldr r12, =pattern_pointer
      str r11, [r12]

  end_change_pattern:
  end_SysTick:
  @ exit the branch
  bx lr
.size SysTick_Handler, .-SysTick_Handler


.type word_show, %function
@ to execute the word show
word_show:
  @ store the link to the stack
  push {lr}

  @ store the correct address of the display to be shown to pattern_pointer using the word_show_pattern and offset 
  ldr r0, =pattern_pointer
  ldr r1, =word_show_pattern
  ldr r2, =word_show_offset
  ldr r2, [r2]
  lsl r2, #2
  add r1, r2
  str r1, [r0]

  @ load the delay timer to r2 as required by the set_pins functions
  ldr r2, =word_show_timer
  ldr r2, [r2]

  @ set the pins' values with the correct arguments
  bl set_pins

  @ get the link from the stack and exit the branch
  pop {lr}
  bx lr
.size word_show, .-word_show

@ following is the data store for executing the program
.data

@ mark the start of the data for on and off interval for pwm
light_start:

light_1:
  .word 0x5000
  .word 0x10000

light_2:
  .word 0x2500
  .word 0x10000

light_3:
  .word 0x1000
  .word 0x10000

light_4:
  .word 0x500
  .word 0x10000

light_5:
  .word 0x250
  .word 0x10000

@ the light_pointer to show which light version is in use now in pwm mode
light_pointer:
  .word light_start
  .word light_start

@ the delay timers for scanning mode
timer:
  .word 0x20000
  .word 0xffff
  .word 0x8000
  .word 0xfff
  .word 0x800
  .word 0xff
  .word 0x80
  .word 0xf
  .word 0x8
  .word 0x8
  .word 0x8
  .word 0x8
  .word 0x8
  .word 0x8
  .word 0x8
  .word 0x8
  .word 0x8
  .word 0x8
  .word 0xf
  .word 0x80
  .word 0xff
  .word 0x800
  .word 0xfff
  .word 0x8000
  .word 0xffff
  .word 0x20000

@ designate the number of times to be repeated
repeated_times:
  .word 0x10

@ mark the start of the data for the display patterns, these are 5*5 matric like entries 
pattern_start:

smiley_pattern_1:
  .word 0b10000
  .word 0b01011
  .word 0b01000
  .word 0b01011
  .word 0b10000

smiley_pattern_2:
  .word 0b01001
  .word 0b01011
  .word 0b01000
  .word 0b01001
  .word 0b01011

sun_pattern_1:
  .word 0b10101
  .word 0b01110
  .word 0b11011
  .word 0b01110
  .word 0b10101

sun_pattern_2:
  .word 0b01010
  .word 0b11111
  .word 0b01010
  .word 0b11111
  .word 0b01010

sun_pattern_3:
  .word 0b10101
  .word 0b01110
  .word 0b11011
  .word 0b01110
  .word 0b10101

sun_pattern_4:
  .word 0b01010
  .word 0b11111
  .word 0b01010
  .word 0b11111
  .word 0b01010

sun_pattern_5:
  .word 0b10101
  .word 0b01110
  .word 0b11011
  .word 0b01110
  .word 0b10101

smiley_pattern_3:
  .word 0b10000
  .word 0b01011
  .word 0b01000
  .word 0b01011
  .word 0b10000

smiley_pattern_4:
  .word 0b01000
  .word 0b01011
  .word 0b01000
  .word 0b01011
  .word 0b01000

smiley_pattern_5:
  .word 0b01000
  .word 0b10011
  .word 0b10000
  .word 0b10011
  .word 0b01000

smiley_pattern_6:
  .word 0b01000
  .word 0b11011
  .word 0b11000
  .word 0b11011
  .word 0b01000

smiley_pattern_7:
  .word 0b01100
  .word 0b10101
  .word 0b10100
  .word 0b10101
  .word 0b01100

interlude:
  .word 0b00000
  .word 0b00000
  .word 0b00100
  .word 0b00000
  .word 0b00000

heart_pattern_1:
  .word 0b00000
  .word 0b00110
  .word 0b01100
  .word 0b00110
  .word 0b00000

heart_pattern_2:
  .word 0b00110
  .word 0b01111
  .word 0b11110
  .word 0b01111
  .word 0b00110

Y:
  .word 0b00001
  .word 0b00010
  .word 0b11100
  .word 0b00010
  .word 0b00001

Y_to_E_transit_1:
  .word 0b00010
  .word 0b11100
  .word 0b00010
  .word 0b00001
  .word 0b00000

Y_to_E_transit_2:
  .word 0b11100
  .word 0b00010
  .word 0b00001
  .word 0b00000
  .word 0b11111

Y_to_E_transit_3:
  .word 0b00010
  .word 0b00001
  .word 0b00000
  .word 0b11111
  .word 0b10101

Y_to_E_transit_4:
  .word 0b00001
  .word 0b00000
  .word 0b11111
  .word 0b10101
  .word 0b10101

Y_to_E_transit_5:
  .word 0b00000
  .word 0b11111
  .word 0b10101
  .word 0b10101
  .word 0b10101

E:
  .word 0b11111
  .word 0b10101
  .word 0b10101
  .word 0b10101
  .word 0b10101

E_to_A_transit_1:
  .word 0b10101
  .word 0b10101
  .word 0b10101
  .word 0b10101
  .word 0b00000

E_to_A_transit_2:
  .word 0b10101
  .word 0b10101
  .word 0b10101
  .word 0b00000
  .word 0b11111

E_to_A_transit_3:
  .word 0b10101
  .word 0b10101
  .word 0b00000
  .word 0b11111
  .word 0b00101

E_to_A_transit_4:
  .word 0b10101
  .word 0b00000
  .word 0b11111
  .word 0b00101
  .word 0b00101

E_to_A_transit_5:
  .word 0b00000
  .word 0b11111
  .word 0b00101
  .word 0b00101
  .word 0b00101

A:
  .word 0b11111
  .word 0b00101
  .word 0b00101
  .word 0b00101
  .word 0b11111

A_to_H_transit_1:
  .word 0b00101
  .word 0b00101
  .word 0b00101
  .word 0b11111
  .word 0b00000

A_to_H_transit_2:
  .word 0b00101
  .word 0b00101
  .word 0b11111
  .word 0b00000
  .word 0b11111

A_to_H_transit_3:
  .word 0b00101
  .word 0b11111
  .word 0b00000
  .word 0b11111
  .word 0b00100

A_to_H_transit_4:
  .word 0b11111
  .word 0b00000
  .word 0b11111
  .word 0b00100
  .word 0b00100

A_to_H_transit_5:
  .word 0b00000
  .word 0b11111
  .word 0b00100
  .word 0b00100
  .word 0b00100

H:
  .word 0b11111
  .word 0b00100
  .word 0b00100
  .word 0b00100
  .word 0b11111

H_to_exclaimation_transit_1:
  .word 0b00100
  .word 0b00100
  .word 0b00100
  .word 0b11111
  .word 0b00000

H_to_exclaimation_transit_2:
  .word 0b00100
  .word 0b00100
  .word 0b11111
  .word 0b00000
  .word 0b10111

H_to_exclaimation_transit_3:
  .word 0b00100
  .word 0b11111
  .word 0b00000
  .word 0b10111
  .word 0b00000

H_to_exclaimation_transit_4:
  .word 0b11111
  .word 0b00000
  .word 0b10111
  .word 0b00000
  .word 0b00000

exclaimation:
  .word 0b00000
  .word 0b10111
  .word 0b00000
  .word 0b00000
  .word 0b00000

@ the pattern_pointer to show which parttern is in use now in pwm/sacnning mode
pattern_pointer:
  .word pattern_start
  .word pattern_start

@ record the current mode
mode:
  .word 0     @ 0 means PWM, 1 means scanning

@ record if the interrupt is hit and required to go back to the start
change_interrupt_hit:
  .word 0     @ 0 means no hit, 1 means hit

@ record if the loop of the current display is finished
finished_loop:
  .word 0     @ 0 means the current loop of pattern is not finished, 1 means finished

@ record if we are in word show mode
word_show_mode:
  .word 0     @ 0 means not in word show mode (depends on mode's value for pwm or scanning), 1 means word show mode

@ the pattern of the word show display
word_show_pattern:
  .word 0b11111
  .word 0b00100
  .word 0b00100
  .word 0b00100
  .word 0b11111
  .word 0
  .word 0b11111
  .word 0b00101
  .word 0b00101
  .word 0b00101
  .word 0b11111
  .word 0
  .word 0b00011
  .word 0b01100
  .word 0b10000
  .word 0b01100
  .word 0b00011
  .word 0
  .word 0b11111
  .word 0b10101
  .word 0b10101
  .word 0b10101
  .word 0b10101
  .word 0
  .word 0
  .word 0
  .word 0b11111
  .word 0b00101
  .word 0b00101
  .word 0b00101
  .word 0b11111
  .word 0
  .word 0
  .word 0
  .word 0b11111
  .word 0b00010
  .word 0b00100
  .word 0b01000
  .word 0b11111
  .word 0
  .word 0b10001
  .word 0b10001
  .word 0b11111
  .word 0b10001
  .word 0b10001
  .word 0
  .word 0b11111
  .word 0b10001
  .word 0b10001
  .word 0b10001
  .word 0b10001
  .word 0
  .word 0b11111
  .word 0b10101
  .word 0b10101
  .word 0b10101
  .word 0b10101
  .word 0
  .word 0
  .word 0
  .word 0b11111
  .word 0b10001
  .word 0b10001
  .word 0b01010
  .word 0b00100
  .word 0
  .word 0b11111
  .word 0b00101
  .word 0b00101
  .word 0b00101
  .word 0b11111
  .word 0
  .word 0b00001
  .word 0b00010
  .word 0b11100
  .word 0b00010
  .word 0b00001
  .word 0
  .word 0b10111

@ record the amount of offset
word_show_offset:
  .word 0

@ the timer set for word show mode
word_show_timer:
  .word 0xFFFF

@ the reload value of SysTick Timer
reload_value_SysTick:
  .word 0xFFFFFF

@ list of column to be used in the set_pins function
column_list:
  .word 0b00001
  .word 0b00010
  .word 0b00100
  .word 0b01000
  .word 0b10000