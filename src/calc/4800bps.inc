;;;---------------------------------------------------------------------------
;;; getchar and putchar functions
;;; baud rate = 4800bps
;;; 8bit, no parity, stop 1
;;;---------------------------------------------------------------------------

;;;---------------------------------------------------------------------------
;;; GETCHAR_P1
;;; receive a character from serial port (TEST) and put into P1(R2, R3)
;;;
;;; Input: none
;;; Output: P1(R2,R3), ACC=0(OK), ACC=1(error)
;;; Working: P6, P7
;;; This subroutine destroys P6, P7.
;;; 
;;; baud rate: 4800bps (208.33us/bit, 19.29cycle/bit)
;;; 
;;;          |--27--|-19-|-19-|-19-|-19-|-19-|-19-|-19-|-19-|
;;; ~~~~~~~~|____|~~~~|____|~~~~|____|~~~~|____|~~~~|____|~~~~~ 19.29cycle/bit
;;;          ^      ^    ^    ^    ^    ^    ^    ^    ^    ^
;;;        start    0    1    2    3    4    5    6    7   stop
;;;               |->phase delay
;;; - In order to check data bits in the middle of the signal,
;;;   a "phase delay" should be added between the start bit and data bits.
;;;   (7 to 10 cycles may be moderate for 19.29cycle/bit)
;;; - Detection of the start bit may cause delay of 2 cycles due to polling.
;;;---------------------------------------------------------------------------
	
GETCHAR_P1:
	FIM R12R13, loops(2,4)  ; loop count "2" is lower and upper
                                        ; "4" is each 4 bit
        JCN TN, $               ;(2) wait for start bit (TEST="0")
	
        FIM R14R15, loop(7)     ;(2)
        ISZ R15, $              ;(14) add 10cycle wait for the first bit

GETCHAR_L1:
	NOP                     ;(1)
        FIM R14R15, loop(4)     ;(2)
GETCHAR_L4:
	ISZ R15, $              ;(8) (or (2) entering from L4)

        JCN TN, GETCHAR_L2      ;(2) get bit
        CLC                     ;<1> TEST="0" then CY=0
        JUN GETCHAR_L3          ;<2>
GETCHAR_L2:
	STC                     ;[1]TEST="1" then CY=1
        NOP                     ;[1]
        NOP                     ;[1]
GETCHAR_L3:
	RAR                     ;(1)
        ISZ R13, GETCHAR_L1     ;(2) repeat until 4 bit received
	
        ISZ R12, GETCHAR_SETR3  ;(2) lower/upper branch
        XCH R2                  ;(1) store upper 4bit to R2

        ;; check stop bit aftar waiting for 8 cycles
        FIM R14R15, loop(3)     ;(2) 
        ISZ R15, $              ;(6)

        JCN TN, GETCHAR_OK      ; stop bit == "1"
        BBL 1                   ; stop bit != "1"
GETCHAR_OK:
	BBL 0
GETCHAR_SETR3:
	XCH R3                  ;(1) store lower 4 bit to R3
        FIM R12R13, loops(1,4)  ;(2) set loop count "1" for upper
                                ;    and reset bit counter to "4"
        FIM R14R15, loop(1)     ;(2) set loop count for timing adjust
        JUN GETCHAR_L4          ;(2)
                
;;;---------------------------------------------------------------------------
;;; PUTCHAR_P1
;;; send the character in P1(R2, R3) to OUTPORT
;;; 
;;; Input: P1(R2,R3)
;;; Output: ACC=0
;;; Working: P6(R12R13), P7
;;; This subroutine destroys P6, P7.
;;; P1 is not affected
;;; 
;;; baud rate: 4800bps (208.33us/bit, 19.29cycle/bit)
;;; 
;;;         |-19-|-19-|-19|-19-|-20--|-20-|-20-|-20-|-20--|(ave.19.55cycle/bit)
;;; ~~~~~~~~|____|~~~~|____|~~~~|____|~~~~|____|~~~~|____|~~~~~ 19.29cycle/bit
;;;         ^    ^    ^   ^    ^     ^    ^    ^    ^     ^
;;;       start  0    1   2    3     4    5    6    7     stop
;;;---------------------------------------------------------------------------

PUTCHAR_P1:
	if (BANK_SERIAL != BANK_DEFAULT)
	LDM BANK_SERIAL     ; bank of output port
        DCL                 ; set port bank
	endif

        FIM P7, CHIP_SERIAL ; chip# of output port
	SRC P7              ; set port address

        FIM R12R13, loop(5) ; start bit and lower 4bit(R3)
        LD R3
        CLC                 ; start bit is 0
        RAL
                
PUTCHAR_L1:
	NOP                 ;(1)
        NOP                 ;(1)
        NOP                 ;(1)
        WMP                 ;(1)
        FIM R14R15,loop(5)  ;(2)
        ISZ R15, $          ;(10)
        RAR                 ;(1)
        ISZ R13, PUTCHAR_L1 ;(2) 19cycles/bit

        FIM R12R13, loop(5) ;(2) upper 4bit(R2) and stop bit
        LD R2               ;(1)
        STC                 ;(1) stop bit is 1
                            ;    20 cycles between bit3 and bit4
PUTCHAR_L2:
	WMP                 ;(1)
        FIM R14R15, loop(7) ;(2)
        ISZ R15, $          ;(14)
        RAR                 ;(1)
        ISZ R13, PUTCHAR_L2 ;(2) 20cycles/bit
	
	if (BANK_SERIAL != BANK_DEFAULT)
	LDM BANK_DEFAULT    
        DCL                 ; restore bank to default
	endif
        BBL 0

