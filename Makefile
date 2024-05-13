#
#  Makefile
#  Choplifter Reverse Engineer
#
#  Created by Quinn Dunki on May 5, 2024
#  https://blondihacks.com
#


CL65=cl65
CAD=./cadius
ADDR=800
LOADERADDR=300
VOLNAME=CHOPLIFTER
IMG=DiskImageParts
PGM=choplifter
EXECNAME=CHOP.SYSTEM\#FF2000

all: clean diskimage loader $(PGM) emulate

$(PGM):
	@PATH=$(PATH):/usr/local/bin; $(CL65) -C linkerConfig -t apple2 --start-addr $(ADDR) -l$(PGM).lst $(PGM).s
	$(CAD) ADDFILE $(VOLNAME).po /$(VOLNAME) CHOP0
	$(CAD) ADDFILE $(VOLNAME).po /$(VOLNAME) CHOP1
	$(CAD) ADDFILE $(VOLNAME).po /$(VOLNAME) CHOPGFX
	$(CAD) ADDFILE $(VOLNAME).po /$(VOLNAME) CHOPGFXHI
	rm -f $(PGM).o

diskimage:
	$(CAD) CREATEVOLUME $(VOLNAME).po $(VOLNAME) 143KB
	$(CAD) ADDFILE $(VOLNAME).po /$(VOLNAME) $(IMG)/PRODOS/PRODOS#FF0000
	
clean:
	rm -f $(PGM)
	rm -f $(PGM).o

emulate:
		osascript V2Make.scpt $(PROJECT_DIR) $(VOLNAME)
	
loader:
	@PATH=$(PATH):/usr/local/bin; $(CL65) -t apple2 --start-addr $(LOADERADDR) -lloader.lst loader.s -o $(EXECNAME)
	$(CAD) ADDFILE $(VOLNAME).po /$(VOLNAME) $(EXECNAME)
	rm -f $(LOADEREXEC)
	rm -f loader.o
