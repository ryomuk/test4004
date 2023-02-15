;;; BANK# for DCL
BANK_RAM0      equ 0
BANK_RAM1      equ 0
BANK_RAM2      equ 1
BANK_RAM3      equ 1

;;; CHIP#=(D7.D6.000000)
CHIP_RAM0      equ 00H
CHIP_RAM1      equ 40H
CHIP_RAM2      equ 00H
CHIP_RAM3      equ 40H

;;; Serial Port (BANK# and CHIP#)
BANK_SERIAL     equ BANK_RAM0
CHIP_SERIAL     equ CHIP_RAM0

;;; Program Memory
PM_TOP          equ 0F00H
PM_READ_P0_P2   equ 0FFEH

;;; Default Bank
BANK_DEFAULT	equ BANK_RAM0
		
