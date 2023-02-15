;;; Tiny Monitor Program for 4004 evaluation board
;;; Ryo Mukai
;;; 2023/02/15

;;; DEBUG equ 1			; for ifdef DEBUG

;;; This source can be assembled with the Macroassembler AS
;;; (http://john.ccac.rwth-aachen.de:8000/as/)
        cpu 4004        ; AS's command to specify CPU

        include "aliases.inc" ; Aliases for register name
        include "config.inc"  ; Configuration of memory/port chips
                
;;;---------------------------------------------------------------------------
;;; CPU Resisters
;;;---------------------------------------------------------------------------
;;; P0( R0,  R1): argument of PRINT_P0, and many functions
;;; P1( R2,  R3): argument of PUTCHAR_P1, DISPLED_P1
;;;               result of GETCHAR_P1
;;;               PM_WRITE_P0_P1, and many functions
;;; P2( R4,  R5): CTOI_P1_R5, PM_READ_P0_P2
;;; P3( R6,  R7): working reg. for calculator input (error flag, digit counter)
;;; P4( R8,  R9):
;;; P5(R10, R11): 
;;; P6(R12, R13): working regs. for loop (wait , UART, etc.), and for SRC
;;; P7(R14, R15): working regs. for loop (wait , UART, etc.), and for SRC
;;;---------------------------------------------------------------------------

;;;---------------------------------------------------------------------------
;;; Memory Resisters
;;;---------------------------------------------------------------------------
;;; Bank0, Chip 0
;;; Reg 0(D0-F, S0-3): REG_X
;;; Reg 1(D0-F, S0-3): REG_Y
;;; Reg 2(D0-F, S0-3): REG_Z (not implemented yet)
;;; Reg 3(D0-F, S0-3): REG_T (not implemented yet)
;;;---------------------------------------------------------------------------
;;; Bank0, Chip 1
;;; Reg 0(D0-F, S0-3): REG_M (working for multiplication/division)
;;; Reg 1(D0-F, S0-3): REG_A (working for square root) (not implemented yet)
;;; Reg 2(D0-F, S0-3): REG_XI (working for square root) (not implemented yet)
;;; Reg 3(D0-F, S0-3): REG_H (working for square root) (not implemented yet)
;;;---------------------------------------------------------------------------
;;; Bank1, Chip 0
;;;---------------------------------------------------------------------------
;;; Bank1, Chip 1
;;;---------------------------------------------------------------------------

;;;---------------------------------------------------------------------------
;;; Number expression (simple floating point)
;;;       1 11111
;;; char# 5 432109876543210
;;;  (+/-)D.DDDDDDDDDDDDDDD*(10^E)
;;; D0-15: Fraction (D15=most significant digit, D0=least significant digit)
;;; D15 denotes an integer part, but it shuld be zero except
;;; while calculating addition or multiplication.
;;; It is used for avoiding overflow.
;;; The number is normalized so that D15 is zero and minimize exponent
;;; S0: Exponent (0 to 14)
;;; S1: Sign of the fraction (0=positive, 15=negative)
;;; S2: Error (0:no_error, 1:overflow, 2:divide_by_zero)
;;;---------------------------------------------------------------------------
REG_ERROR_OVERFLOW  equ 1
REG_ERROR_DIVBYZERO equ 2
	
;;;---------------------------------------------------------------------------
;;; Program Start
;;;---------------------------------------------------------------------------

	org 0000H		; beginning of Program Memory

MAIN:
        CLB

	if (BANK_DEFAULT != 0)
	;; initialize DL to bank 0
	;; DL is assumed to be set back to BANK_DEFAULT (normally 0)
	;; except when in use for another banks.
	LDM BANK_DEFAULT
	DCL
	endif
	
	JMS INIT_SERIAL ; Initialize Serial Port
	JMS PM_WRITE_READROUTINE ; write PM_READ code on program memory

;       JCN TN, $		wait for TEST="0" (button pressed)
        LDM 2
        JMS BLINK_LED   ; blink LED 2 times
	FIM P0, lo(STR_VFD_INIT) ; init VFD
        JMS PRINT_P0;
	FIM P0, lo(STR_OMSG) ; opening message in the Page 7
        JMS PRINT_P0;

CMD_LOOP:
        FIM P1, ']'		; prompt
        JMS PUTCHAR_P1

L_CR:
	JMS GETCHAR_P1
        JMS DISPLED_ACC
        JMS DISPLED_P1
	FIM P0, '\r'
	JMS CMP_P0P1
	JCN Z, L_CR		; skip CR

	JMS PUTCHAR_P1		; echo input

	FIM P0, '\n'
	JMS CMP_P0P1
	JCN ZN, L0
	FIM P1, '\r'
	JMS PUTCHAR_P1		; put CR
	JUN CMD_LOOP

L0:
	FIM P0, 'r'		; Read data memory
	JMS CMP_P0P1
	JCN ZN, L1
	JMS SETBANKCHIP_P5
	JUN COMMAND_R
L1:
	FIM P0, 'w'		; Write to data memory
	JMS CMP_P0P1
	JCN ZN, L2
	JMS SETBANKCHIP_P5
	JUN COMMAND_W
L2:
	FIM P0, 'p'		; write Program memory
	JMS CMP_P0P1
	JCN ZN, L3
	JUN COMMAND_P
L3:
	FIM P0, 'd'		; Dump program memory
	JMS CMP_P0P1
	JCN ZN, L4
	JUN COMMAND_D
L4:
	FIM P0, 'l'		; cLear program memory
	JMS CMP_P0P1
	JCN ZN, L5
	JUN COMMAND_L
L5:
	FIM P0, 'g'		; Go to PM_TOP (0F00H)
	JMS CMP_P0P1
	JCN ZN, L6
	JUN COMMAND_G
L6:
	FIM P0, 'c'		; Calculator
	JMS CMP_P0P1
	JCN ZN, L9
	JUN COMMAND_C
L9:
	FIM P0, lo(STR_CMDERR)
	JMS PRINT_P0
	JUN CMD_LOOP

;;;---------------------------------------------------------------------------
;;; SETBANKCHIP_P5
;;; Set #bank and #chip to R10 and R11
;;;---------------------------------------------------------------------------
SETBANKCHIP_P5:
	FIM P0, lo(STR_BANK)	; print " BANK="
	JMS PRINT_P0
	JMS GETCHAR_P1
	JMS PUTCHAR_P1
	JMS CTOI_P1_R5
	LD R5
	XCH R10			; save BANK to R10

	FIM P0, lo(STR_CHIP)	; print " CHIP="
	JMS PRINT_P0
	JMS GETCHAR_P1
	JMS PUTCHAR_P1
	JMS CTOI_P1_R5
	JMS PRINT_CRLF
	CLB
	LD R5		; R5 is #chip(0.0.D3.D2)
	RAL
	RAL
	XCH R11 	;set D3D2.00@X2 to R11 (0000 or 0100 or 1000 or 1100)
	BBL 0
	
;;;---------------------------------------------------------------------------
;;; CMP_P0P1
;;; compare P0(R0R1) and P1(R2R3)
;;; input: P0, P1
;;; output: ACC=1,CY=0 if P0<P1
;;;         ACC=0,CY=1 if P0==P1 
;;;         ACC=1,CY=1 if P0>P1
;;; P0 - P1 (the carry bit is a complement of the borrow)
;;;---------------------------------------------------------------------------
CMP_P0P1:
	CLB
	LD R0			
	SUB R2			;R0-R2
	JCN Z, CMP_L1
	JCN C, CMP_EXIT11
	BBL 1			;P0<P1,  ACC=1, CY=0
CMP_L1:	
	CLB
	LD R1
	SUB R3			;R1-R3
	JCN Z, CMP_EXIT01
	JCN C, CMP_EXIT11
	BBL 1			;P0<P1,  ACC=1, CY=0
CMP_EXIT01:
	BBL 0			;P0==P1, ACC=0, CY=1
CMP_EXIT11
	BBL 1			;P0>P1,  ACC=1, CY=1
	
;;;---------------------------------------------------------------------------
;;; PM_WRITE_PO_P1
;;; Write to program memory located at Page 15 (0F00H-0FFFH)
;;; (0F00H+P0) = P1
;;; input: P0, P1
;;; output: none
;;;---------------------------------------------------------------------------
	
PM_WRITE_P0_P1:
	SRC P0
	LD R2
	WPM
	LD R3
	WPM
	BBL 0

;;;---------------------------------------------------------------------------
;;; PM_WRITE_READROUTINE
;;; preparation for reading program memory
;;;---------------------------------------------------------------------------
PM_WRITE_READROUTINE:	
	FIM P0, lo(PM_READ_P0_P2)
	FIM P1, 34H		; FIN P2
	JMS PM_WRITE_P0_P1
	INC R1
	FIM P1, 0C0H		; BBL 0
	JMS PM_WRITE_P0_P1
	BBL 0

	org 0100H
;;;---------------------------------------------------------------------------
;;;COMMAND_C
;;; 	Calculator
;;; P0(R0, R1): working for PRINT
;;; P1(R2, R3): working for PRINT, GETCHAR, PUTCHAR
;;; P2(R4, R5): working for CTOI
;;; P3(R6, R7):   
;;; 		  R6.bit0 = input start flag (0:not started, 1:started)
;;;               R6.bit1 = input full flag (0:not full, 1:full)
;;; 	          R6.bit3 = digit point flag(0:no dp, 1:dp set)
;;; 	          R7=digit counter for key input
;;; P4(R8,  R9):  register address and character index(mainly REG_X)
;;; P5(R10, R11): register address and character index(mainly REG_Y)
;;; P6(R12, R13): working for register operation
;;; P7(R14, R15): working for register operation
;;;---------------------------------------------------------------------------
COMMAND_C:
	FIM P0, lo(STR_CALC)
	JMS PRINT_P0

	JUN CMDC_CLEAR		; clear registers
CMDC_LOOP_START:
	FIM P3, 01H		; clear start, full, point flags
				; and set digit counter R7 1
	JUN PRINT_RESULT_AND_ENTER_TO_Y ; this may be modified
					; when REG_Z or REG_T exists
CMDC_LOOP_NUMIN:
	JMS GETCHAR_P1
        JMS DISPLED_ACC
        JMS DISPLED_P1
	FIM P0, '\r'
	JMS CMP_P0P1
	JCN Z, CMDC_LOOP_NUMIN	; skip CR

	FIM P0, '\n'
	JMS CMP_P0P1
	JCN ZN, CMDC_L1
	JMS PRINT_CRLF
	JUN CMDC_ENTER
CMDC_L1:
	FIM P0, 'q'		; quit
	JMS CMP_P0P1
	JCN ZN, CMDC_L2
	JMS PRINT_CRLF
	JUN CMD_LOOP		; return to command loop
CMDC_L2:	
	FIM P0, '+'
	JMS CMP_P0P1
	JCN ZN, CMDC_L3
	JMS PUTCHAR_P1
	JUN CMDC_ADD
CMDC_L3:
	FIM P0, '-'
	JMS CMP_P0P1
	JCN ZN, CMDC_L4
	JMS PUTCHAR_P1
	JUN CMDC_SUB
CMDC_L4:
	FIM P0, '*'
	JMS CMP_P0P1
	JCN ZN, CMDC_L5
	JMS PUTCHAR_P1
	JUN CMDC_MUL
CMDC_L5:
	FIM P0, '/'
	JMS CMP_P0P1
	JCN ZN, CMDC_L6
	JMS PUTCHAR_P1
	JUN CMDC_DIV
CMDC_L6:
	FIM P0, 'c'
	JMS CMP_P0P1
	JCN ZN, CMDC_L7
	JMS PRINT_CRLF
	JUN CMDC_CLEAR
CMDC_L7:
	FIM P0, 's'
	JMS CMP_P0P1
	JCN ZN, CMDC_L8
	;; change sign of REG_X
	JMS CHANGE_SIGN_REG_X
	JMS PRINT_CRLF
	JUN CMDC_PRINT
CMDC_L8:
	FIM P0, 'p'
	JMS CMP_P0P1
	JCN ZN, CMDC_L9
	JMS PRINT_CRLF
	JUN CMDC_PRINT
CMDC_L9:
	LD R6			; check R6.bit1
	RAR			; no more '0-9' or '.' input
	RAR			; when register is full (has 16 digits)
	JCN C, CMDC_L11

	FIM P0, '.'
	JMS CMP_P0P1
	JCN ZN, CMDC_L10
	JMS CMDC_CLEAR_REGX_IF_FIRST_KEYIN
	JUN CMDC_DIGITPOINT
	
CMDC_L10:
	JMS ISNUM_P1
	JCN Z, CMDC_L11          ; not a number
	JMS CMDC_CLEAR_REGX_IF_FIRST_KEYIN
	JUN CMDC_NUM
CMDC_L11:
	JUN CMDC_LOOP_NUMIN

;;;---------------------------------------------------------------------------
;;; CMDC_CLEAR_REGX_IF_FIRST_KEYIN
;;;   clear REG_X for the first '0-9' or '.'
;;;---------------------------------------------------------------------------
CMDC_CLEAR_REGX_IF_FIRST_KEYIN:
	LD R6                   ; check input already started (R6.bit0)
	RAR
	JCN C, FKEY_EXIT
	STC
	RAL			; set input start flag
	XCH R6
	FIM P0, REG_X
	JMS CLEAR_REGISTER_P0	; clear X for the first keyin
FKEY_EXIT:
	BBL 0

;;;---------------------------------------------------------------------------
;;; CHIP#(=D7.D6), REG#(=D5.D4) of number registers 
;;;---------------------------------------------------------------------------
REG_X  	equ (CHIP_RAM0+(0<<4))	; CHIP#.00.0000
REG_Y	equ (CHIP_RAM0+(1<<4))	; CHIP#.01.0000
REG_Z  	equ (CHIP_RAM0+(2<<4))	; CHIP#.10.0000
REG_T	equ (CHIP_RAM0+(3<<4))	; CHIP#.11.0000

REG_M	equ (CHIP_RAM1+(0<<4))	; CHIP#.00.0000
REG_A	equ (CHIP_RAM1+(1<<4))	; CHIP#.01.0000
REG_XI	equ (CHIP_RAM1+(2<<4))	; CHIP#.10.0000
REG_H	equ (CHIP_RAM1+(3<<4))	; CHIP#.11.0000
	
;;;---------------------------------------------------------------------------
;;; CMDC_CLEAR
;;; clear registers and jump to main loop of the calculator
;;;---------------------------------------------------------------------------
CMDC_CLEAR:
	FIM P0, REG_X
	JMS CLEAR_REGISTER_P0
	FIM P0, REG_Y
	JMS CLEAR_REGISTER_P0
	JUN CMDC_LOOP_START
	
;;;---------------------------------------------------------------------------
;;; CMDC_ENTER
;;; LOAD Y <= X
;;;---------------------------------------------------------------------------
CMDC_ENTER:
 	FIM P0, REG_X
 	JMS NORMALIZE_REGISTER_P0
	FIM P6, REG_Y
	FIM P7, REG_X
	JMS LD_REGISTER_P6_P7	; Y<=X
 	JUN CMDC_LOOP_START

;;;---------------------------------------------------------------------------
;;; CMDC_DIGITPOINT
;;; set a digit point
;;;---------------------------------------------------------------------------
CMDC_DIGITPOINT
	LD R6
	RAL
	JCN C, CMDC_DP_EXIT	; skip if digit point flag (R6.bit3)
				; is already set
	STC			; else set digit point flag R6.bit3
	RAR
	XCH R6                  

	JMS PUTCHAR_P1		; put '.'
CMDC_DP_EXIT:	
	JUN CMDC_LOOP_NUMIN

;;;---------------------------------------------------------------------------
;;; CMDC_NUM
;;; enter a number to X
;;;---------------------------------------------------------------------------
CMDC_NUM:
	JMS CTOI_P1_R5
	LD R6			; check digit point flag (R6.bit3)
	RAL
	JCN C,CMDC_L0		; digit point flag is ture
	
	LD R5			; when digit point frag is false,
	JCN NZ, CMDC_L0		; ignore key in '0' if digit counter is 1
	LD R7		
	DAC
	JCN Z, CMDC_NUM_EXIT
CMDC_L0:
	;; operation is for R7-th digit of X
	FIM P7, REG_X
	LDM 15
	CLC
	SUB R7			
	XCH R15                 ; P7=(REG_X).(#char=15-R7)
	SRC P7

	LD R6
	RAL			; check R6.bit3 (dp flag)
	JCN C, CMDC_SETNUM	; not set exponent
	;; set exponent of X
	LD R7
	WR0
CMDC_SETNUM:
	LD R5
	WRM
	INC R7
	LDM 15			; maximum number of digits is 14,
	CLC			; so set digit full flag when R7 becomes 15
	SUB R7
	JCN ZN, CMDC_NUM_EXIT
	;; set digit full flag R6.bit1
	LD R6
	RAR
	RAR
	STC
	RAL
	RAL
	XCH R6
CMDC_NUM_EXIT:
	JMS PUTCHAR_P1		; echo input
	JUN CMDC_LOOP_NUMIN

;;;---------------------------------------------------------------------------
;;; SUB_FRACTION_P6_P7
;;; subtract fraction
;;; REG(P6) = REG(P6) - REG(P7)
;;; REG(P6) should be equal or larger than REG(P7)
;;; in order to avoid underflow
;;; destroy: R13, R15, (R12 and R14 are not affected)
;;;---------------------------------------------------------------------------
;;; Reference
;;; "Intel MCS-4 Assembly Language Programming Manual" Dec.1973,
;;; 4.8 Decimal Subtraction, pp.4-20--23
;;;---------------------------------------------------------------------------
SUB_FRACTION_P6_P7:
	CLB
	XCH R13
	CLB
	XCH R15
	CLB
	STC
SUB_FRA_LOOP:
	TCS
	SRC P7
	SBM

	CLC
	SRC P6
	ADM

	DAA
	WRM
	INC R13
	ISZ R15, SUB_FRA_LOOP
	BBL 0

	org 0200H
;;;---------------------------------------------------------------------------
;;; CMDC_ADD
;;; X = X + Y
;;;---------------------------------------------------------------------------
CMDC_ADD:
	JMS PRINT_CRLF
	JMS ALIGN_REGISTER_XY

	FIM P6, REG_X
	FIM P7, REG_Y
	SRC P6			; check sign of REG_X and REG_Y same or not
	RD1
	XCH R0			; R0 = sign of X
	SRC P7
	RD1
	CLC
	SUB R0
 	JCN Z, CMDC_ADD_SAMESIGN

	JMS CMP_FRACTION_P6_P7
	JCN Z, CMDC_ADD_ZERO_EXIT
	JCN C, CMD_SUB_X_Y	; P6 > P7
CMD_SUB_Y_X:
	FIM P6, REG_M		; swap X and Y
	FIM P7, REG_X
	JMS LD_REGISTER_P6_P7	; M<=X
	FIM P6, REG_X
	FIM P7, REG_Y
	JMS LD_REGISTER_P6_P7	; X<=Y
	FIM P6, REG_Y
	FIM P7, REG_M
	JMS LD_REGISTER_P6_P7	; Y<=M

CMD_SUB_X_Y:	
	FIM P6, REG_X
	FIM P7, REG_Y
	JMS SUB_FRACTION_P6_P7

	JUN CMDC_ADD_EXIT

CMDC_ADD_SAMESIGN:
	FIM P6, REG_X
	FIM P7, REG_Y
	JMS ADD_FRACTION_P6_P7
	
CMDC_ADD_EXIT:
	JUN CMDC_NORMALIZE_AND_EXIT

CMDC_ADD_ZERO_EXIT:
	FIM P0, REG_X
	JMS CLEAR_REGISTER_P0
	JUN CMDC_ADD_EXIT

;;;---------------------------------------------------------------------------
;;; CMDC_NORMALIZE_AND_EXIT
;;; Common routine for finish calculation
;;; Normalize REG_X
;;; Clear REG_Y
;;; Rotate registers is to be implemented (for REG_Z or REG_T)
;;;---------------------------------------------------------------------------
CMDC_NORMALIZE_AND_EXIT:
 	FIM P0, REG_X
 	JMS NORMALIZE_REGISTER_P0
	FIM P0, REG_Y
	JMS CLEAR_REGISTER_P0
	JUN CMDC_LOOP_START

;;;---------------------------------------------------------------------------
;;; ADD_FRACTION_P6_P7
;;; Add fraction of two registers
;;; REG(P6) = REG(P6) + REG(P7)
;;; register should be normalized so that D15 = 0
;;; in order to avoid overflow
;;; destroy: R13, R15, (R12 and R14 are not affected)
;;;---------------------------------------------------------------------------
ADD_FRACTION_P6_P7:
	CLB
	XCH R13
	CLB
	XCH R15
	CLB
ADD_FRA_LOOP:
	SRC P7
	RDM
	SRC P6
	ADM
	DAA
	WRM
	INC R13
	ISZ R15, ADD_FRA_LOOP
ADD_FRA_EXIT:	
	BBL 0
	
;;;---------------------------------------------------------------------------
;;; CMP_FRACTION_P6_P7
;;; compare fraction of REG(P6) and REG(P7)
;;; output: ACC=1,CY=0 if REG(P6) < REG(P7)
;;;         ACC=0,CY=1 if REG(P6)== REG(P7)
;;;         ACC=1,CY=1 if REG(P6) > REG(P7)
;;; REG(P6) - (P7) (the carry bit is a complement of the borrow)
;;; working: R0, R1
;;; destroy: P0, R13, R15, (R12 and R14 are not affected)
;;;---------------------------------------------------------------------------
CMP_FRACTION_P6_P7:	
	CLB
	XCH R0			; R0 = 0

CMP_FRACTION_LOOP:		; for i(R0)=0 to 15
	LD R0
	CMA
	XCH R13
	SRC P6
	RDM
	XCH R1			; R1=REG(P6)[15-i]

	LD R0
	CMA
	XCH R15
	SRC P7

	LD R1
	CLC
	SBM			; ACC=REG(P6)[15-i] - REG(P7)[15-i]

	JCN Z, CMP_FRACTION_NEXT
	JCN C, CMP_FRACTION_EXIT11
	JUN CMP_FRACTION_EXIT10

CMP_FRACTION_NEXT:
	ISZ R0, CMP_FRACTION_LOOP
	BBL 0			; REG(P6) == REG(P7)

CMP_FRACTION_EXIT10:
	BBL 1			; REG(P6) < REG(P7)

CMP_FRACTION_EXIT11:
	BBL 1			; REG(P6) > REG(P7)

;;;---------------------------------------------------------------------------
;;; NORMALIZE_REGISTER_P0
;;; minimize exponent
;;; example
;;; 0.0000001 E 9 ->shift L7->  1.0000000 E 2 -> shift R1 -> 0.10000000 E3
;;; 0.0000001 E 7 ->shift L7->  1.0000000 E 0 -> shift R1 -> 0.10000000 E1
;;; 0.0000001 E 5 ->shift L5->  0.0100000 E 0
;;; 
;;; working: P0, R2, R3
;;;---------------------------------------------------------------------------
NORMALIZE_REGISTER_P0:	
	SRC P0
	RD0			; exponent of REG(P0)
	CMA
	XCH R3			; R3 = 15 - exponent
	
	CLB
	XCH R2			; R2=0 (counter)
	JUN NM_LOOP_ENTRY
NM_LOOP:
	LD R2
	CMA
	XCH R1			; R1=15, 14,.., 0
	SRC P0
	RDM
	JCN ZN, NM_GO_SHIFT
	INC R2
NM_LOOP_ENTRY:
	ISZ R3, NM_LOOP
NM_GO_SHIFT:
	;  exponent = exponent - shift count
	RD0
	CLC
	SUB R2
	WR0
	LD R2			; ACC = shift count
	JMS SHIFT_FRACTION_LEFT_P0_ACC

	LDM 15			; check most significant digit
	XCH R1			; and shift to right if it is not zero
	SRC P0
	RDM
	JCN Z, NM_EXIT
	RD0			; increment exponent
	IAC
	WR0
	JCN CN, NM_NOERROR
	LDM REG_ERROR_OVERFLOW
	WR2	;; set overflow flag
NM_NOERROR:
	LDM 1
NM_EXIT:
	JUN SHIFT_FRACTION_RIGHT_P0_ACC
	
;;;---------------------------------------------------------------------------
;;; CMDC_MUL
;;; X = X * Y
;;;---------------------------------------------------------------------------
	
CMDC_MUL:
	JMS PRINT_CRLF

	FIM P0, REG_X
	JMS ISZERO_REGISTER_P0
	JCN ZN, CMDC_MUL_ZERO

	FIM P0, REG_Y
	JMS ISZERO_REGISTER_P0
	JCN ZN, CMDC_MUL_ZERO
	
	FIM P6, REG_X
	FIM P7, REG_Y

	JMS GET_SIGN_PRODUCT_P6_P7
	SRC P6
	WR1
	
	;;  calculate exponent of the result
	RD0
	XCH R0
	SRC P7
	RD0
	CLC
	ADD R0
	SRC P6
	WR0			; set exp X (tentative)
				; it may be adjusted by the normalization
	JCN CN, CMDC_MUL_L0	; check overflow
	LDM REG_ERROR_OVERFLOW
	WR2			; set overflow flag
CMDC_MUL_L0:
	;; 	LDM 0
	;; 	SRC P7
	;; 	WR0			; exp Y = 0 (can be omitted)

	; multiply fraction X = X * Y
	JMS MUL_FRACTION_XY

CMDC_MUL_EXIT:
	JUN CMDC_NORMALIZE_AND_EXIT
CMDC_MUL_ZERO:
	FIM P0, REG_X
	JMS CLEAR_REGISTER_P0
	JUN CMDC_MUL_EXIT

	org 0300H
;;;---------------------------------------------------------------------------
;;; MUL_FRACTION_XY
;;; multiply fraction of REG_X and REG_Y
;;; REG_X = REG_X* REG_Y
;;; working: P6, P7, P5, P0(for shift), P1(for shift), P4(R8, R9)
;;;---------------------------------------------------------------------------
;;; D15=0 (number is normalized)
;;; sum up folloings and store to FRA_X
;;; FRA_Y
;;; 0EDCBA9876543210 * 0 FRA_M(=FRA_X)
;;;  0EDCBA987654321 * E
;;;   0EDCBA98765432 * D
;;;    0EDCBA9876543 * C
;;;     0EDCBA987654 * B
;;;      0EDCBA98765 * A
;;;       0EDCBA9876 * 9
;;;        0EDCBA987 * 8
;;;         0EDCBA98 * 7
;;;          0EDCBA9 * 6
;;;           0EDCBA * 5
;;;            0EDCB * 4
;;;             0EDC * 3
;;;              0ED * 2
;;;               0E * 1
;;;                0 * 0
;;;---------------------------------------------------------------------------
MUL_FRACTION_XY:
	FIM P6, REG_M
	FIM P7, REG_X
	JMS LD_FRACTION_P6_P7	; FRA_M <= FRA_X

	FIM P0, REG_X
	JMS CLEAR_FRACTION_P0	; FRA_X = 0, status(sign, exp) is reserved
	
	FIM P5, REG_M		; for mult loop (copy of X)
	FIM P6, REG_X		; for ADD (total)
	FIM P7, REG_Y		; for ADD
	FIM P0, REG_Y		; for SHIFT (working reg. P1)

	CLB
	XCH R8
MUL_LOOP:			; for i(R8)=0 to 15
	LD R8
	CMA
	XCH R11			; R11 = 15, 14, ..., 0
	SRC P5
	RDM
	JCN Z, MUL_LOOP_NEXT	; next if (REG_Y)[15-i] == 0
	CMA
	IAC
	XCH R9			; R9 = 16-(REG_Y)[15-i]
MUL_ADD_LOOP:			; add FRA_M to FRA_X '(REG_Y)[15-i] times'
	JMS ADD_FRACTION_P6_P7
	ISZ R9, MUL_ADD_LOOP
MUL_LOOP_NEXT:
	LDM 1
	FIM P0, REG_Y
	JMS SHIFT_FRACTION_RIGHT_P0_ACC ; shift FRA_Y 1 digit right
	ISZ R8, MUL_LOOP

	BBL 0
	
;;;---------------------------------------------------------------------------
;;; CMDC_PRINT
;;; Print X and Y
;;;---------------------------------------------------------------------------
CMDC_PRINT:
	FIM P0, REG_X
	JMS PRINT_REGISTER_P0
	FIM P0, REG_Y
	JMS PRINT_REGISTER_P0
	JUN CMDC_LOOP_NUMIN

;;;---------------------------------------------------------------------------
;;; PRINT_RESULT_AND_ENTER_TO_Y
;;; Print REG_X as a result and ENTER to REG_Y
;;;---------------------------------------------------------------------------
PRINT_RESULT_AND_ENTER_TO_Y:
	FIM P0, REG_X
	FIM P6, REG_Y
	FIM P7, REG_X
	JMS LD_REGISTER_P6_P7	; Y<=X
	JMS PRINT_REGISTER_P0
	JUN CMDC_LOOP_NUMIN
	
;;;---------------------------------------------------------------------------
;;; CMDC_SUB
;;; X = Y - X
;;;---------------------------------------------------------------------------
CMDC_SUB:
	JMS CHANGE_SIGN_REG_X
	JUN CMDC_ADD
	
;;;---------------------------------------------------------------------------
;;; SHIFT_FRACTION_RIGHT_P0_ACC
;;; shift fraction of the register to right with filling 0
;;; input: P0(=D3D2D1D0.xxxx (D3D2=#CHIP, D1D0=#REG)
;;; 	   ACC=shift count
;;; working: P0(R0, R1), P1(R2, R3)
;;; destroy P1(R2, R3), R1 becomes 0 but R0 is not affected
;;;---------------------------------------------------------------------------
SHIFT_FRACTION_RIGHT_P0_ACC:
	JCN Z, SHIFTR_EXIT	; exit if ACC==0
	XCH R3			; R3 = ACC = shift
	LD R0
	XCH R2			; R2 = R0

	CLB			; clear ACC and CY
	XCH R1			; R1=0
SHIFTR_LOOP:			; for(i=0 to 15) P0(REG(i))=P1(REG(i+shift))
	LDM 0
	JCN C, SHIFTR_WRITE
SHIFTR_READ:	
	SRC P1
	RDM
SHIFTR_WRITE:
	SRC P0
	WRM
	INC R3
	LD R3
	JCN ZN, SHIFTR_NEXT      ; check if shift completed
	STC			; set flag to fill remaining bits with 0 
SHIFTR_NEXT:
	ISZ R1, SHIFTR_LOOP
SHIFTR_EXIT:
	BBL 0

;;;---------------------------------------------------------------------------
;;; ISNUM_P1
;;; check P1 '0' to '9' as a ascii character
;;; return: ACC=0 if P1 is not a number
;;;         ACC=1 if P1 is a number
;;; destroy: P0
;;;---------------------------------------------------------------------------
ISNUM_P1:
	FIM P0, '0'-1
	JMS CMP_P0P1
	JCN C, ISNUM_FALSE	; '0'-1 >= P1
	FIM P0, '9'
	JMS CMP_P0P1
	JCN CN, ISNUM_FALSE	; '9' < P1
	BBL 1			; P1 is a number
ISNUM_FALSE:
	BBL 0			; P1 is not a number
	
;;;---------------------------------------------------------------------------
;;; SHIFT_FRACTION_LEFT_P0_ACC
;;; shift fraction of the register to left with filling 0
;;; input: P0(=D3D2D1D0.xxxx (D3D2=#CHIP, D1D0=#REG)
;;; 	   ACC=shift count
;;; working: P0(R0, R1), P1(R2, R3), P2(R4, R5), R15
;;; destroy P1(R2, R3), P2, R15, R1 becomes 0 but R0 is not affected
;;;---------------------------------------------------------------------------
SHIFT_FRACTION_LEFT_P0_ACC:
	JCN Z, SHIFTL_EXIT	; exit if ACC==0
	XCH R5			; R5 = ACC = shift
	LD R0
	XCH R2			; R2 = R0

	CLB			; clear ACC and CY
	XCH R4			; R4=0 (R4=i, R5=i+shift)
SHIFTL_LOOP:			; for(i=0 to 15) P0(REG(~i))=P1(REG(~(i+shift))
	LDM 0
	XCH R15
	JCN C, SHIFTL_WRITE
SHIFTL_READ:	
	LD R5
	CMA
	XCH R3			; R3 = ~R5 =~(i+shift)
	SRC P1
	RDM
	XCH R15
SHIFTL_WRITE:
	LD R4
	CMA
	XCH R1			; R1 = ~R4 =~i
	SRC P0
	XCH R15
	WRM
	INC R5
	LD R5
	JCN ZN, SHIFTL_NEXT	; check if shift completed
	STC			; set flag to fill remaining bits with 0 
SHIFTL_NEXT:
	ISZ R4, SHIFTL_LOOP
SHIFTL_EXIT:
	BBL 0
	
;;;---------------------------------------------------------------------------
;;; ALIGN_REGISTER_XY
;;; align digit point to larger register
;;; input: P6(=D3D2D1D0.0000 (D3D2=#CHIP, D1D0=#REG)
;;;        P7(=D3D2D1D0.0000 (D3D2=#CHIP, D1D0=#REG)
;;; working: R10, R11
;;;---------------------------------------------------------------------------
ALIGN_REGISTER_XY:
	FIM P6, REG_X
	FIM P7, REG_Y
	SRC P6
	RD0
	XCH R10			; R10 = expoenent of REG_P6
	SRC P7
	RD0 
	XCH R11			; R11 = expoenent of REG_P7

	LD R11
	CLC
	SUB R10
	JCN C, EY_GE_EX		; R11 >= R10
	;; R11 < R10
	CMA
	IAC
	FIM P0, REG_Y
	JMS SHIFT_FRACTION_RIGHT_P0_ACC
	LD R10
	SRC P7
	WR0
	JUN ALIGN_EXIT
EY_GE_EX:
	FIM P0, REG_X
	JMS SHIFT_FRACTION_RIGHT_P0_ACC
	LD R11
	SRC P6
	WR0
ALIGN_EXIT:
	BBL 0
	
;;;---------------------------------------------------------------------------
;;; CLEAR_REGISTER_P0
;;; Clear register
;;; input: P7(=D3D2D1D0.0000 (D3D2=#CHIP, D1D0=#REG))
;;; output: ACC=0, R1=0, (R0 is not affected)
;;;---------------------------------------------------------------------------
CLEAR_REGISTER_P0:
	CLB
	SRC P0
	WR0
	WR1
	WR2
	WR3
;;;---------------------------------------------------------------------------
;;; CLEAR_FRACTION_P0
;;;---------------------------------------------------------------------------
CLEAR_FRACTION_P0:
	CLB
CLEAR_REGISTER_L0:
	SRC P0
	WRM
	ISZ R1, CLEAR_REGISTER_L0
	BBL 0

;;;---------------------------------------------------------------------------
;;; LD_REGISTER_P6_P7
;;; load register REG(P7) to REG(P6) (REG_P6 <= REG_P7)
;;; input: P6(=D3D2D1D0.0000 (D3D2=#CHIP, D1D0=#REG)) 
;;;        P7(=D3D2D1D0.0000 (D3D2=#CHIP, D1D0=#REG))
;;; output: ACC=0, R13=0, R15=0
;;; destroy R13, R15 (R12 and R14 are not affected)
;;;---------------------------------------------------------------------------
LD_REGISTER_P6_P7:
	;; copy status characters
	SRC P7
	RD0
	SRC P6
	WR0

	SRC P7
	RD1
	SRC P6
	WR1

	SRC P7
	RD2
	SRC P6
	WR2

	SRC P7
	RD3
	SRC P6
	WR3
;;;---------------------------------------------------------------------------
;;; LD_FRACTION_P6_P7
;;;---------------------------------------------------------------------------
LD_FRACTION_P6_P7
	; CLB
	; XCH R13			; clear R13
	; CLB
	; XCH R15			; clear R15
LD_FRACTION_L0:
	SRC P7
	RDM			; read a digit from the source register
	SRC P6
	WRM			; write the digit to memory
	INC R13
	ISZ R15, LD_FRACTION_L0

	BBL 0

;;;---------------------------------------------------------------------------
;;; ISZERO_REGISTER_P0
;;; check if REG(P0) == 0 or not
;;; return: ACC = (REG==0) ? 1 : 0;
;;; destroy: R1 (R0 is not affected)
;;;---------------------------------------------------------------------------
ISZERO_REGISTER_P0:
	CLB
	XCH R1
ISZERO_LOOP:
	SRC P0
	RDM
	JCN ZN, ISZERO_EXIT0
	ISZ R1, ISZERO_LOOP

	BBL 1
ISZERO_EXIT0:
	BBL 0
	
;;;---------------------------------------------------------------------------
;;; CHANGE_SIGN_REG_X
;;; X = -X
;;; destroy: P7
;;;---------------------------------------------------------------------------
CHANGE_SIGN_REG_X:
	FIM P7, REG_X
	SRC P7
	RD1
	CMA
	WR1
	BBL 0

	org 0400H
;;;---------------------------------------------------------------------------
;;; CMDC_DIV
;;; X = Y / X
;;;---------------------------------------------------------------------------
CMDC_DIV:
	JMS PRINT_CRLF

	FIM P0, REG_X
	JMS NORMALIZE_REGISTER_P0
	JMS ISZERO_REGISTER_P0
	JCN ZN, CMDC_DIV_BY_ZERO

	FIM P0, REG_Y
	JMS ISZERO_REGISTER_P0
	JCN ZN, CMDC_DIVIDEND_ZERO
	
	FIM P6, REG_X
	FIM P7, REG_Y

	JMS GET_SIGN_PRODUCT_P6_P7
	SRC P7
	WR1			; save sign to Y
	
	;; if devisor(REG_X) is less than 0.1,
	;; shift it left until it become equal or larger than 0.1
	;; and increment the exponent of devidend
	;; example
	;; X=0.0001 -> X=0.1000, exponent of Y += 3
	SRC P6
	RD0			; check exponent of REG_X(devisor)
	JCN ZN, DIV_FRAC_ADJ_EXP
DIV_LOOP_D14:
	;; increment exponent of Y
	SRC P7			; Y
	RD0
	IAC
	WR0			; EXP(Y)++
	JCN NC, DIV_LOOP_L0
	LDM REG_ERROR_OVERFLOW
	WR2			; set overflow flag, but continue calculation
DIV_LOOP_L0:
	LDM 14
	XCH R13
	SRC P6			; X
	RDM			; ACC = D14 of X
	JCN ZN, DIV_FRAC        ; exit loop and continue calculation
	LDM 1
	JMS SHIFT_FRACTION_LEFT_P0_ACC
	JUN DIV_LOOP_D14

	; adjust exponent of Y
DIV_FRAC_ADJ_EXP:
	SRC P6			; X
	RD0
 	DAC
	XCH R0			; R0 = (exponent of X)-1
	SRC P7
	RD0
	CLC
	SUB R0			; exp(Y) - exp(X)
	WR0
	JCN C, DIV_FRAC		; no borrow
	CMA
	IAC
	FIM P0, REG_Y
	JMS SHIFT_FRACTION_RIGHT_P0_ACC ; shift frac(Y) and set exp(Y)=0
	CLB
	WR0
DIV_FRAC:
	JMS DIV_FRACTION_XY
	;; 	JUN DIV_FRACTION_XY
	;; RETURN_DIV_FRACTION_XY:	
	; normalize REG_X and clear REG_Y
	JUN CMDC_NORMALIZE_AND_EXIT
	
CMDC_DIV_BY_ZERO:
	FIM P0, REG_X
	SRC P0
	LDM REG_ERROR_DIVBYZERO
	WR2			; set error flag
	JUN CMDC_LOOP_START
CMDC_DIVIDEND_ZERO:
	FIM P0, REG_X
	JMS CLEAR_REGISTER_P0
	JUN CMDC_LOOP_START
	
;;;---------------------------------------------------------------------------
;;; DIV_FRACTION_XY
;;; FRAC(X) = FRAC(Y) / FRAC(X)
;;; working: P6, P7, P5, P0(for shift), P1 (for shift), P4(R8, R9)
;;;---------------------------------------------------------------------------
;;;  compare and subtract and count, and shift
;;; 
;;;  0EDCBA9876543210
;;;  0edcba9876543210 -> E
;;;
;;;  0EDCBA9876543210
;;;   0edcba987654321 -> D
;;; 
;;;  0EDCBA9876543210
;;;    0edcba98765432 -> C
;;; ...
;;;  0EDCBA9876543210 -> 0
;;;                0e
;;;
;;; e!=0
;;;---------------------------------------------------------------------------
	
DIV_FRACTION_XY:
	FIM P6, REG_Y
	FIM P7, REG_X
	FIM P5, REG_M

	FIM P0, REG_M
	JMS CLEAR_FRACTION_P0

	LDM 1
	XCH R8			; for i(R8)= 1 to 15;
DIV_LOOP:	
	CLB
	XCH R9			; counter R9 = 0
DIV_SUB_COUNT:
	JMS CMP_FRACTION_P6_P7	   ; Compare Y with X
	JCN CN, DIV_SUB_COUNT_EXIT ; jump if REG_Y < REG_X

	;; check R9 is already 9
	;; it occurs when shifted divisor is truncated
	;; (ex. previous loop 100/109 -> this loop 100/10)
	LDM 9
	CLC
	SUB R9
	JCN Z, DIV_SUB_COUNT_EXIT
	
	JMS SUB_FRACTION_P6_P7	   ; Y = Y - X
	INC R9
	JUN DIV_SUB_COUNT
DIV_SUB_COUNT_EXIT:	
	LD R8
	CMA
	XCH R11			; R11 = 14, 13, ..., 0
	SRC P5			; REG_M
	LD R9
	WRM			; REG_M(R11) = R9
	LDM 1
	FIM P0, REG_X
	JMS SHIFT_FRACTION_RIGHT_P0_ACC ; X=X/10

	ISZ R8, DIV_LOOP

	FIM P6, REG_X
	FIM P7, REG_Y
	JMS LD_REGISTER_P6_P7	; copy exponent of Y to X
	FIM P7, REG_M
	JMS LD_FRACTION_P6_P7	; copy fraction of M to X
				; X need to be normalized
	BBL 0
	;; 	JUN RETURN_DIV_FRACTION_XY

;;;---------------------------------------------------------------------------
;;; GET_SIGN_PRODUCT_P6_P7
;;; calculate sign of the result for multiplication and division
;;; result: ACC=0 (+) if REG(P6) and REG(P7) have the same sign (++or--)
;;;            =15(-) if REG(P6) and REG(P7) have the different signs (+-or-+)
;;; destroy: R0
;;;---------------------------------------------------------------------------
GET_SIGN_PRODUCT_P6_P7:	
	;;  calculate sign of the result for multiplication and division
	SRC P6			; check sign of REG_X and REG_Y same or not
	RD1
	XCH R0			; R0 = sign of X
	SRC P7
	RD1			; sign of Y
	CLC
	SUB R0
 	JCN Z, GET_SIGN_EXIT
	BBL 15			; negative sign
GET_SIGN_EXIT:
	BBL 0

;;;---------------------------------------------------------------------------
;;; PRINT_REGISTER_P0
;;; Print the contents of the number register
;;; input: P0(R0=D3D2D1D0 (D3D2=#CHIP, D1D0=#REG))
;;; destroy P6, P7, P5(R10, R11), P1
;;; output: ACC=0
;;;---------------------------------------------------------------------------
PRINT_REGISTER_P0:
	;; 	FIM P1, 'X'
	;; 	JMS PUTCHAR_P1
	;; 	LD R0
	;; 	JMS PRINT_ACC
	;;
	FIM P1, '='
	SRC P0
	RD2
	JCN Z, PRINT_REGISTER_EQU_ERR
	FIM P1, 'E'
PRINT_REGISTER_EQU_ERR
	JMS PUTCHAR_P1

	FIM P1, '+'
	SRC P0
	RD1
	JCN Z, PRINT_REGISTER_SGN
	FIM P1, '-'
PRINT_REGISTER_SGN:
	JMS PUTCHAR_P1
	
	SRC P0
	RD0			
	XCH R10                 ; load R10=exponent

	;; print first digit(D15) if it is not zero
	;; (it should be '0' if the number is normalized) 
	LDM 15
	XCH R1
	SRC P0
	RDM
	JCN Z, PRINT_CHECK_EXP
	JMS PRINT_ACC

PRINT_CHECK_EXP:		; print digit point if exponent is 0
	LD R10
	JCN ZN, PRINT_REGISTER_LOOP_SETUP
	FIM P1, '.'
	JMS PUTCHAR_P1

PRINT_REGISTER_LOOP_SETUP:
	CLB
	LDM 1
	XCH R11			; R11 is loop counter start from 1
PRINT_REGISTER_LOOP:
	LDM 15
	CLC
	SUB R11			; (R11 =  1, 2,...,15) 
	JCN Z, PRINT_EXIT	; skip last digit
	XCH R1			; ( R1 = 14,13,..., 1)
	SRC P0
	RDM
	JMS PRINT_ACC

	CLB			; print digit point
	LD R10
	SUB R11
	JCN ZN, PRINT_REGISTER_L1
	FIM P1, '.'
	JMS PUTCHAR_P1
PRINT_REGISTER_L1:
	ISZ R11, PRINT_REGISTER_LOOP
PRINT_EXIT:	
	JMS PRINT_CRLF
	BBL 0

	
;;;---------------------------------------------------------------------------
;;; Monitor commands located in page 0500H
;;;---------------------------------------------------------------------------
	org 0500H
;;;---------------------------------------------------------------------------
;;; Read Data RAM
;;; input:
;;; 	R10: #bank
;;; 	R11: #chip (D3.D2.0.0)
;;; working memory:
;;;     P0(R0R1): working for PRINT_P0
;;;     P1(R2R3): working for PUTCHAR_P1, PRINT_ACC
;;;     R4: loop counter for #REG (0.0.D1.D0)
;;;     R5: working for input
;;;     R6: working for SCR (R6=R11+R4)
;;;     R7: working for SCR #CHARACTER (D3.D2.D1.D0)@X3 (loop counter)
;;;         SCR R6R7
;;;     R8: not used
;;; 	R9: not used
;;; 	R11: #CHIP (D3.D2.0.0)@X2
;;;     P6(R12R13): working for uart
;;;     P7(R14R15): working for uart
;;;---------------------------------------------------------------------------
COMMAND_R:
	;; PRINT 4 registers
	LDM loop(4)		; 4 regs
	XCH R4			; R4=loop(4)

	;; PRINT 16 characters
CMDR_L1:
	LDM loop(16)		; 16 characters
	XCH R7			; R7=D3D2D1D0@X3 (#character)
CMDR_L2:
	CLB
	LDM 4
	ADD R4		;ACC<-#reg (D1D0@X2)(00, 01, 10, 11 for each loop)
	CLC
	ADD R11
	XCH R6		;R6=D3D2D1D0@X2 (#chip.#reg)
	
	SRC R6R7	; set address
	RDM		; read data memory
	JMS PRINT_ACC
	ISZ R7,CMDR_L2

	;; PRINT STATUS 
	FIM P1, ':'
	JMS PUTCHAR_P1
	SRC R6R7	; set address
	RD0
	JMS PRINT_ACC
	SRC R6R7	; set address
	RD1
	JMS PRINT_ACC
	SRC R6R7	; set address
	RD2
	JMS PRINT_ACC
	SRC R6R7	; set address
	RD3
	JMS PRINT_ACC
	JMS PRINT_CRLF

	ISZ R4,CMDR_L1
	JUN CMD_LOOP		; return to command loop
	
;;;---------------------------------------------------------------------------
;;; Write Data RAM
;;; input:
;;; 	R10: #bank
;;; 	R11: #chip (D3.D2.0.0)
;;;---------------------------------------------------------------------------
COMMAND_W:
	;; PRINT 4 registers
	LDM loop(4)		; 4 regs
	XCH R4			; R4=loop(4)

	;; PRINT 16 characters
CMDW_L1:
	LDM loop(16)		; 16 characters
	XCH R7			; R7=D3D2D1D0@X3 (#character)
CMDW_L2:
	CLB
	LDM 4
	ADD R4		;ACC<-#reg (D1D0@X2)(00, 01, 10, 11 for each loop)
	CLC
	ADD R11
	XCH R6		;R6=D3D2D1D0@X2 (#chip.#reg)

	JMS GETCHAR_P1
	JMS CTOI_P1_R5

	SRC R6R7	; set address
	LD R5
	WRM			; write to memory
	JMS PRINT_ACC
	ISZ R7,CMDW_L2

	;; PRINT STATUS 
	FIM P1, ':'
	JMS PUTCHAR_P1

	JMS GETCHAR_P1
	JMS CTOI_P1_R5

	SRC R6R7	; set address
	LD R5
	WR0
	JMS PRINT_ACC

	JMS GETCHAR_P1
	JMS CTOI_P1_R5

	SRC R6R7	; set address
	LD R5
	WR1
	JMS PRINT_ACC

	JMS GETCHAR_P1
	JMS CTOI_P1_R5

	SRC R6R7	; set address
	LD R5
	WR2
	JMS PRINT_ACC

	JMS GETCHAR_P1
	JMS CTOI_P1_R5

	SRC R6R7	; set address
	LD R5
	WR3
	JMS PRINT_ACC
	JMS PRINT_CRLF

	ISZ R4,CMDW_L1
	
	JUN CMD_LOOP		; return to command loop

COMMAND_P:	;; write program Memory
	FIM P0, lo(STR_ADD)	; print " ADD="
	JMS PRINT_P0
	JMS GETCHAR_P1
	JMS PUTCHAR_P1
	JMS CTOI_P1_R5
	JMS PRINT_CRLF

	FIM P1,'F'
	JMS PUTCHAR_P1
	LD R5
	JMS PRINT_ACC
	FIM P1,'0'
	JMS PUTCHAR_P1
	FIM P1,':'
	JMS PUTCHAR_P1
	
	LD R5
	XCH R0

	LDM 0
	XCH R1
CMDP_L1:
	FIM P1, ' '
	JMS PUTCHAR_P1

	JMS GETCHAR_P1
	JMS PUTCHAR_P1
	JMS CTOI_P1_R5
	LD R5
	XCH R4

	JMS GETCHAR_P1
	JMS PUTCHAR_P1
	JMS CTOI_P1_R5
	LD R5
	XCH R3

	LD R4
	XCH R2

	JMS PM_WRITE_P0_P1
	ISZ R1, CMDP_L1

	JMS PRINT_CRLF

	JUN CMD_LOOP		; return to command loop

COMMAND_D:	;; Dump program Memory
	JMS PRINT_CRLF

	JMS PM_WRITE_READROUTINE

	FIM P0, 00H
CMDD_L0:
	FIM P1,'F'
	JMS PUTCHAR_P1
	LD R0
	JMS PRINT_ACC
	FIM P1,'0'
	JMS PUTCHAR_P1
	FIM P1,':'
	JMS PUTCHAR_P1
CMDD_L1:	
	FIM P1, ' '
	JMS PUTCHAR_P1

	JMS PM_READ_P0_P2	; Read program memory
	LD R4
	JMS PRINT_ACC
	LD R5
	JMS PRINT_ACC

	ISZ R1, CMDD_L1
	JMS PRINT_CRLF
        ISZ R0, CMDD_L0
	
	JUN CMD_LOOP		; return to command loop

	;; Clear Program Memory
COMMAND_L:
	JMS PRINT_CRLF

	FIM P0, 00H
	FIM P1, 00H
CMDL_L1:
	JMS PM_WRITE_P0_P1
	ISZ R1, CMDL_L1
	ISZ R0, CMDL_L1
	
	JUN CMD_LOOP		; return to command loop

	;; Go to PM_TOP(0x0F00)
COMMAND_G:
	JMS PRINT_CRLF
	JMS PM_TOP
	JUN CMD_LOOP		; return to command loop

;;;----------------------------------------------------------------------------
;;; I/O routines located in Page 0600H
;;;----------------------------------------------------------------------------
	org 0600H

;;;----------------------------------------------------------------------------
;;; GETCHAR_P1 and PUTCHAR_P1
;;; defined in separated file
;;;----------------------------------------------------------------------------

;;; supported baudrates are 4800bps or 9600bps
;; BAUDRATE equ 4800	; 4800 bps, 8 data bits, no parity, 1 stop bit
BAUDRATE equ 9600   ; 9600 bps, 8 data bits, no parity, 1 stop bit

        include "uart.inc"

;;;---------------------------------------------------------------------------
;;; CTOI_P1_R5
;;; convert character ('0'...'f') to value 0000 ... 1111
;;; input: P1(R2R3)
;;; output: R5
;;;---------------------------------------------------------------------------
CTOI_P1_R5:
	CLB
	LDM 3
	SUB R2
	JCN Z, CTOI_09		; check upper 4bit
	CLB
	LDM 9
	ADD R3
	XCH R3
CTOI_09:
	LD R3
	XCH R5
	BBL 0
	
;;;----------------------------------------------------------------------------
;;; DISPLED_P1
;;;   DISPLAY the contents of P1 on Port 2 and 3
;;; Input: P1(R2R3)
;;; Output:  ACC=0
;;; Working: P7
;;; Destroy: P7
;;;----------------------------------------------------------------------------

DISPLED_P1:
	LDM BANK_RAM2
        DCL
        FIM P7, CHIP_RAM2
        SRC P7
        LD R3
        WMP
	
        LDM BANK_RAM3
        DCL
        FIM P7, CHIP_RAM3
        SRC P7
        LD R2
        WMP

        LDM BANK_DEFAULT	; restore BANK to default
	DCL
	
        BBL 0

;;;----------------------------------------------------------------------------
;;; DISPLED_ACC
;;;   DISPLAY the contents of ACC on Port 1
;;; Input: ACC
;;; Output:  ACC=0
;;; Working: P7
;;; Destroy: P7
;;;----------------------------------------------------------------------------

DISPLED_ACC:
	if (BANK_RAM1 != BANK_DEFAULT)
        LDM BANK_RAM1
        DCL
	endif
	
        FIM P7, CHIP_RAM1
        XCH R14         ; save ACC

        XCH R14         ; restore ACC
        SRC P7          
        WMP

	if (BANK_RAM1 != BANK_DEFAULT)
	LDM BANK_DEFAULT	; restore BANK to default
	DCL
	endif
	
	BBL 0
                
;;;----------------------------------------------------------------------------
;;; BLINK_LED
;;;   Blink LED N times (N=ACC, N=16 if ACC==0)
;;; Input: ACC
;;; Output: ACC=0
;;; Working: R11
;;; Destroy: R11, P6, P7
;;;----------------------------------------------------------------------------

BLINK_LED:
	CMA
	IAC
	XCH R11         ; set counter=16-ACC
BLINK_L0	
        LDM BANK_RAM1
        FIM P7, CHIP_RAM1
        JMS BLINK_SUB

        LDM BANK_RAM2
        FIM P7, CHIP_RAM2
        JMS BLINK_SUB

        LDM BANK_RAM3
        FIM P7, CHIP_RAM3
        JMS BLINK_SUB
	
        ISZ R11, BLINK_L0

	LDM BANK_DEFAULT
	DCL

	BBL 0

BLINK_SUB:	
        DCL
        SRC P7
        LDM 8
        WMP             ; LED(MSB) on
        LDM 8
        JMS WAIT10MS    ; wait 80ms
        LDM 0
        WMP             ; LED off
        BBL 0

;;;----------------------------------------------------------------------------
;;; Wait Subroutines WAIT10MS and WAIT100MS
;;;
;;; Constants '45EF'(10ms) and '11FE'(100ms) are calculated
;;; by Jim's 4004 Delay Loop Calculator
;;; https://github.com/jim11662418/4004-delay-calculator
;;;
;;; 10.8003857uS/cycle (@5.185MHz clock)
;;;----------------------------------------------------------------------------
;;;----------------------------------------------------------------------------
;;; WAIT10MS
;;; Input: ACC
;;; Output: return with ACC=0
;;; Destroy: P6, P7, (R12, R13, R14, R15)
;;;   wait for 10 * N ms (N=ACC, N=16 if ACC==0)
;;;----------------------------------------------------------------------------
                
WAIT10MS:
	FIM R12R13, 045H  ; 9947us delay(921 cycles)
        FIM R14R15, 0EFH  ; 
W10_L1:
 	ISZ R12, W10_L1
        ISZ R13, W10_L1
        ISZ R14, W10_L1
        ISZ R15, W10_L1
        DAC
        JCN ZN, WAIT10MS  ; 9979us delay(924 cycles)/loop
W10_EXIT:
	BBL 0

;;;----------------------------------------------------------------------------
;;; WAIT100MS
;;; Input: ACC
;;; Output: return with ACC=0
;;; Destroy: P6, P7, (R12, R13, R14, R15)
;;;   wait for 100 * N ms (N=ACC, N=16 if ACC==0)
;;;----------------------------------------------------------------------------
                
WAIT100MS:
	FIM R12R13, 011H  ; 99958us delay(9255 cycles)
        FIM R14R15, 0FEH  ; 
W100_L1:
        ISZ R12, W100_L1
        ISZ R13, W100_L1
        ISZ R14, W100_L1
        ISZ R15, W100_L1
        DAC
        JCN ZN, WAIT100MS  ; 99990us delay(9258 cycles)/loop
W100_EXIT:
	BBL 0
                
;;;----------------------------------------------------------------------------
;;; Print subroutine and string data located in Page 7 (0700H-07FFH)
;;; 
;;; The string data sould be located in the same page as the print routine.
;;;----------------------------------------------------------------------------
        org 0700H
;;;----------------------------------------------------------------------------
;;; PRINT_P0
;;; Input: P0 (top of the string is 0700H+P0)
;;; Working: P1(R2, R3)
;;; Destroy: P1, P6, P7 (by PUTCHAR_P1), 
;;;----------------------------------------------------------------------------

PRINT_P0:
        FIN P1			; P1=(P0)
        LD R2
        JCN Z, P7_UPPER0	; R2==0
P7_PUT:
        JMS PUTCHAR_P1             ; putchar(P1)
        ISZ R1, PRINT_P0           ; P0=P0+1
        INC R0
        JUN PRINT_P0               ; print remaining string
P7_UPPER0:
	LD R3
        JCN ZN, P7_PUT     	; R3 != 0
P7_EXIT:
        BBL 0                   ; exit if P1(R2,R3) == 0
                
;;;----------------------------------------------------------------------------
;;; String data
;;;----------------------------------------------------------------------------

STR_OMSG:
	data "\rIntel MCS-4 (4004)\n\rTiny Monitor\n\r", 0
STR_VFD_INIT:		;reset VFD and set scroll mode
	data 1bH, 40H, 1fH, 02H, 0
STR_BANK:
	data " BANK=", 0
STR_CHIP:
	data " CHIP=", 0
STR_ADD:
	data " ADD(Fx0)=", 0
STR_CALC:
	data "\n\rCalculator Mode\n\r", 0
STR_CMDERR:
	data "\n\rr:Read ram, w:Write ram, p:write Pm, d:Dump pm, l:cLear, c:Calc\n\r", 0 ;
STR_CALCERR:
	data "**ERROR**\n",0

;;;----------------------------------------------------------------------------
;;; String data
;;;----------------------------------------------------------------------------
	
;;;---------------------------------------------------------------------------
;;; Subroutine for reading program memory located on page 15 (0F00H-0FFFH)
;;;---------------------------------------------------------------------------
;;; READPM_P0
;;; P1 = (P0)
;;; input: P0
;;; output: P1
;;;---------------------------------------------------------------------------
;;; 	org 0FF0H
;;; PM_READ_P0_P2:
	FIN P2
	BBL 0

	end
