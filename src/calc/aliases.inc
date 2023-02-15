;;; function for label to address for FIM&FIN
lo              function x, ((x)&255)

;;; functuon for setting counter for ISZ loop
loop            function x, (16-(x))
loops     	function x,y, ((16-(x))<<4 + (16-(y)))

;;; Conditional jumps syntax for Macroassembler AS:
;;; JCN T     jump if TEST = 0 - most positive voltage or +5V
;;; JCN TN    jump if TEST = 1 - most negative voltage or -10V
;;; JCN C     jump if carry = 1
;;; JCN CN    jump if carry = 0
;;; JCN Z     jump if accumulator = 0
;;; JCN ZN    jump if accumulator != 0

;;; Alias for Register Pairs
P0               reg R0R1
P1               reg R2R3
P2               reg R4R5
P3               reg R6R7
P4               reg R8R9
P5               reg RARB
P6               reg RCRD
P7               reg RERF
R10R11           reg RARB
R12R13           reg RCRD
R14R15           reg RERF

;;; Alias for Registers
R10              reg RA
R11              reg RB
R12              reg RC
R13              reg RD
R14              reg RE
R15              reg RF
	
