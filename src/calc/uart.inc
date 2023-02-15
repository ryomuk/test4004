;;;---------------------------------------------------------------------------
;;; uart.inc
;;; Software UART Routine
;;; by Ryo Mukai
;;;---------------------------------------------------------------------------

;;;---------------------------------------------------------------------------
;;; GETCHAR_P1
;;; receive a character from serial port (TEST) and put into P1(R2, R3)
;;;
;;; Input: none
;;; Output: P1(R2,R3), ACC=0(OK), ACC=1(error)
;;; Working: P6, P7
;;; This subroutine destroys P6, P7.
;;;---------------------------------------------------------------------------
;;; PUTCHAR_P1
;;; send the character in P1(R2, R3) to OUTPORT
;;; 
;;; Input: P1(R2,R3)
;;; Output: ACC=0
;;; Working: P6(R12R13), P7
;;; This subroutine destroys P6, P7.
;;; P1 is not affected
;;;---------------------------------------------------------------------------

	switch BAUDRATE
	case 4800
	include "4800bps.inc"
	case 9600
	include "9600bps.inc"
	endcase

;;;---------------------------------------------------------------------------
;;; PRINT_ACC
;;; print contents of ACC('0'...'F') as a character
;;; destroy: P1, P6, P7, ACC
;;;---------------------------------------------------------------------------

PRINT_ACC:
	FIM R2R3, 30H		;'0'
	CLC			; clear carry
	DAA			; ACC=ACC+6 if ACC>9 and set carry
	JCN CN, PRINTACC_L1
	INC R2
	IAC
PRINTACC_L1:	
	XCH R3			; R3<-ACC
	JUN PUTCHAR_P1		; not JMS but JUN (Jump to PUTCHAR and return)



;;;---------------------------------------------------------------------------
;;; PRINT_CRLF
;;; print "\n\r"
;;; destroy: P1, ACC
;;;---------------------------------------------------------------------------
PRINT_CRLF:
	FIM P1, '\r'
	JMS PUTCHAR_P1
	FIM P1, '\n'
	JMS PUTCHAR_P1
	BBL 0

;;;---------------------------------------------------------------------------
;;; INIT_SERIAL
;;; Initialize serial port
;;;---------------------------------------------------------------------------

INIT_SERIAL:
	if (BANK_SERIAL != BANK_DEFAULT)
	LDM BANK_SERIAL     ; bank of output port
        DCL                 ; set port bank
	endif
	
        FIM P7, CHIP_SERIAL ; chip# of output port
	SRC P7              ; set port address
	LDM 1
        WMP                 ; set serial port to 1 (TTL->H)

	if (BANK_SERIAL != BANK_DEFAULT)
	LDM BANK_DEFAULT    
        DCL                 ; restore bank to default
	endif

        BBL 0

