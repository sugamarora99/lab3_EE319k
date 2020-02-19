;****************** main.s ***************
; Program written by: Sugam Arora and Joonha "James" Park
; Date Created: 2/4/2017
; Last Modified: 1/17/2020
; Brief description of the program
;   The LED toggles at 2 Hz and a varying duty-cycle
; Hardware connections (External: One button and one LED)
;  PE1 is Button input  (1 means pressed, 0 means not pressed)
;  PE2 is LED output (1 activates external LED on protoboard)
;  PF4 is builtin button SW1 on Launchpad (Internal) 
;        Negative Logic (0 means pressed, 1 means not pressed)
; Overall functionality of this system is to operate like this
;   1) Make PE2 an output and make PE1 and PF4 inputs.
;   2) The system starts with the the LED toggling at 2Hz,
;      which is 2 times per second with a duty-cycle of 30%.
;      Therefore, the LED is ON for 150ms and off for 350 ms.
;   3) When the button (PE1) is pressed-and-released increase
;      the duty cycle by 20% (modulo 100%). Therefore for each
;      press-and-release the duty cycle changes from 30% to 70% to 70%
;      to 90% to 10% to 30% so on
;   4) Implement a "breathing LED" when SW1 (PF4) on the Launchpad is pressed:
;      a) Be creative and play around with what "breathing" means.
;         An example of "breathing" is most computers power LED in sleep mode
;         (e.g., https://www.youtube.com/watch?v=ZT6siXyIjvQ).
;      b) When (PF4) is released while in breathing mode, resume blinking at 2Hz.
;         The duty cycle can either match the most recent duty-
;         cycle or reset to 30%.
;      TIP: debugging the breathing LED algorithm using the real board.
; PortE device registers
GPIO_PORTE_DATA_R  EQU 0x400243FC
GPIO_PORTE_DIR_R   EQU 0x40024400
GPIO_PORTE_AFSEL_R EQU 0x40024420
GPIO_PORTE_DEN_R   EQU 0x4002451C
; PortF device registers
GPIO_PORTF_DATA_R  EQU 0x400253FC
GPIO_PORTF_DIR_R   EQU 0x40025400
GPIO_PORTF_AFSEL_R EQU 0x40025420
GPIO_PORTF_PUR_R   EQU 0x40025510
GPIO_PORTF_DEN_R   EQU 0x4002551C
GPIO_PORTF_LOCK_R  EQU 0x40025520
GPIO_PORTF_CR_R    EQU 0x40025524
GPIO_LOCK_KEY      EQU 0x4C4F434B  ; Unlocks the GPIO_CR register
SYSCTL_RCGCGPIO_R  EQU 0x400FE608
	
initHighPulse 	EQU 0X002DC6C0 ; 3000000
initLowPulse	EQU 0x006ACFC0 ; 7000000
increment		EQU 0X001E8480 ; 2000000
total			EQU 0X00989680 ; 10000000
	
breathIncrement EQU 0X000007D0 ; 20000 	 (for incrementing duty cyle by 5%)
	
comparison 		EQU 0X000F4240

       IMPORT  TExaS_Init
       THUMB
       AREA    DATA, ALIGN=2
;global variables go here


       AREA    |.text|, CODE, READONLY, ALIGN=2
       THUMB
       EXPORT  Start
Start
 ; TExaS_Init sets bus clock at 80 MHz
     BL  TExaS_Init ; voltmeter, scope on PD3
 ; Initialization goes here
	LDR R0,=SYSCTL_RCGCGPIO_R  ; R0 points to SYSCTL_RCGCGPIO_R
    LDR R1,[R0]    ; read SYSCTL_RCGCGPIO_R into R1
    ORR R1,#0x30   ;turn on clock Bin: 00010000
    STR R1,[R0]    ; write back to SYSCTL_RCGCGPIO_R
    NOP            ; wait for clock to stabilize
    NOP
    LDR R0,=GPIO_PORTE_DIR_R
    MOV R1,#0x04   ; PE2 output, PE1 input
    STR R1,[R0]
    LDR R0,=GPIO_PORTE_DEN_R
    MOV R1,#0x06   ;enable PE2,PE1
    STR R1,[R0]
	
	LDR R0, =GPIO_PORTF_LOCK_R
	LDR R1, =GPIO_LOCK_KEY
	STR R1, [R0]
	LDR R0, =GPIO_PORTF_CR_R
	LDR R1, [R0]
	ORR R1, #0xFF
	STR R1, [R0]
	LDR R0, =GPIO_PORTF_DIR_R
	BIC R1, #0X10 ; PE4 input for switch
	STR R1, [R0]
	LDR R0, =GPIO_PORTF_DEN_R
	MOV R1, #0X10 ; enable only PF4
	STR R1, [R0]
	LDR R0, =GPIO_PORTF_PUR_R
	LDR R1, [R0]
	ORR R1, #0x10
	STR R1, [R0]
	
	LDR R7, =GPIO_PORTE_DATA_R ; R0 has location of port E vector
	LDR R8, =GPIO_PORTF_DATA_R ; R1 has location of Port F vector
	
	LDR R9, =initHighPulse
	LDR R5, =initLowPulse
	LDR R10, =increment
	LDR R11, =total
	AND R4, #0 ; R4 increments every time button is PRESSED
	MOV R12, #0
	MOV R3, #0

     CPSIE  I    ; TExaS voltmeter, scope runs on interrupts
loop  
; main engine goes here
		LDR R1, [R8] ; read PORT F data for SW1
		AND R1, #0X10
		CMP R1, #0X00
		BNE breatheReset
		BL beforeBreathe
		
readE	
		
		LDR R1, [R7] ; read PORT E data for switch
		AND R1, #0X02
		CMP R1, #0X02
		BNE skip
		BL change
		
			

afterSkip
		MOV R0, #0X04 ; 
		STR R0, [R7] ; set PE2 high
		MOV R0, R9 ; delay for LED high time 
		BL delay
		MOV R0, #0X00 ; clear PE2 to be low
		STR R0, [R7]
		MOV R0, R5
		BL delay
		B  loop
		
skip
		MOV R12, #0
		B afterSkip

change	
		
		MOV R6 , R14 ; save linkage
		CMP R12, #1 ; CHECK FLAG
		BNE continue
		BX LR
		
continue
		ADD R9, R10 
		CMP R9, R11
		
		BHS reset
		SUBS R5, R11, R9
		MOV R14, R6
		
		MOV R12, #1
		BX LR













reset 	SUBS R9, R11
		SUBS R5, R11, R9
		MOV R12, #1
		BX LR

beforeBreathe
		LDR R0, =comparison
		CMP R9, R0
		BLE breathe
		MOV R0, #100
		UDIV R9, R9, R0
		UDIV R5, R5, R0
		UDIV R11, R11, R0
		
breathe	
		
		
		CMP R6, #1		;R3 = flag for "is it decrementing" 1= yes , 0 = no
		BEQ decrement
		
		LDR R2, =breathIncrement ; increase duty cycle by only 20%
		ADD R9, R2
		SUBS R5, R11, R9
		CMP R9, R11
		BGE decrement	;If R9 becomes greater than or equal to total, then go to decrement
		

		B afterSkip


decrement
		
		SUBS R9, R9, R2
		SUBS R5, R11, R9
		CMP R9, #0				
		BGT decrementFlag		;If R9 is still greater than 0 after decrementing, continue breathing
		MOV R9, #1
		SUBS R5, R11, R9
		MOV R6, #0				;If R9 hits 0, set the flag off

		B afterSkip

decrementFlag
		MOV R6, #1				;set Flag R3 for "is it decrementing"
		B afterSkip


delay	
		
dloop	SUBS R0, #1
		BNE dloop
		BX LR
		


breatheReset	
		LDR R0, =comparison
		CMP R9, R0
		BGE go
		MOV R0, #100
		LDR R9, =initHighPulse
		LDR R5, =initLowPulse
		LDR R11, =total 
go		
		B readE


      
		ALIGN      ; make sure the end of this section is aligned
		END        ; end of file




