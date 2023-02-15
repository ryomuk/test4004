PRG=calc

BIN=$(PRG).bin
PFILE=$(PRG).p
LFILE=$(PRG).lst

SRC=$(PRG).asm uart.inc 9600bps.inc config.inc aliases.inc

# INCDIR=../include
#ASM=asl -L -i $(INCDIR)
ASM=asl -L

P2BIN=p2bin

.SUFFIXES: .asm .p .bin .lst

all: $(PFILE) $(BIN)

.asm.p:
	$(ASM) $<

.p.bin:
	$(P2BIN) $<

$(BIN): $(PFILE)

$(PFILE): $(SRC)

clean:
	rm $(BIN) $(PFILE) $(LFILE)
