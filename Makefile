# Copyright 1998 Lars T Hansen.		 -*- fundamental -*- 
#
# $Id$
#
# Larceny -- top-level Makefile


###########################################################################
#
# User configuration

# This file name is relative to the Larceny home directory.

BDW_DIST=bdw-gc-4.12.tar.gz
BDW_UNZIP=gunzip
CC=gcc

# End user configuration
#
###########################################################################

default:
	@echo ""
	@echo "Make what?"
	@echo ""
	@echo "Your options are:"
	@echo "  setup_larceny  - setup build system for larceny host"
	@echo "  setup_chez     - setup build system for chez scheme and larceny hosts"
	@echo "  setup_gambit   - setup build system for gambit-c and larceny hosts"
	@echo "  bdw_setup      - unpack Boehm-Demers-Weiser collector"
	@echo "  larceny.bin    - build standard generational system"
	@echo "  bdwlarceny.bin - build conservative collector system"
	@echo "  libpetit       - build Rts/libpetit.so"
	@echo "  hsplit         - build heap splitter"
	@echo "  clean          - remove executables and objects"
	@echo "  lopclean       - remove all .LOP files"
	@echo "  libclean       - remove all .LAP and .LOP files"
	@echo "  soclean        - remove all .so files"
	@echo "  tildeclean     - remove all *~ files"
	@echo "  faslclean      - remove all .FASL files"
	@echo "  realclean      - remove all generated and backup files"

setup:
	@echo "'setup' is no longer a target.  Try one of:"
	@echo "   setup_chez     setup for chez scheme host system"
	@echo "   setup_gambit   setup for gambit-c host system"
	@echo "   setup_larceny  setup for larceny host system"

setup_larceny:
	rm -f bdwlarceny.bin hsplit larceny.bin
	ln -s Rts/larceny.bin
	ln -s Rts/bdwlarceny.bin
	ln -s Rts/hsplit
	mv build build.safe
	sed "s|^LARCENY=.* #@LARCENY_DEF@.*\$$|LARCENY=`pwd` #@LARCENY_DEF@|" < build.safe > build || \
	   ( echo "build hack failed!"; mv build.safe build; exit 1 )
	rm build.safe
	chmod a+x build
	(cd Rts ; $(MAKE) setup)

setup_chez:
	$(MAKE) setup_larceny
	$(MAKE) chezstuff

setup_gambit:
	$(MAKE) setup_larceny
	$(MAKE) gambitstuff

bdw_setup:
	( cd Rts ; $(BDW_UNZIP) < ../$(BDW_DIST) | tar xvf - ; mv gc bdw-gc );

larceny.bin: target_larceny
target_larceny:
	( cd Rts ; $(MAKE) larceny.bin )

bdwlarceny.bin: target_bdwlarceny
target_bdwlarceny:
	( cd Rts ; $(MAKE) bdwlarceny.bin )

libpetit: target_libpetit
target_libpetit:
	( cd Rts ; $(MAKE) libpetit.so )

hsplit: target_hsplit
target_hsplit:
	( cd Rts ; $(MAKE) hsplit )

petit.bin:
	$(MAKE) -f makefile.gcc petit.bin

clean: libclean rtsclean
	( cd Rts ; $(MAKE) clean )

lopclean: seedclean
	rm -f	Lib/Common/*.*lop Lib/Common/*.c Lib/Common/*.o \
		Lib/Sparc/*.*lop Lib/Sparc/*.c Lib/Sparc/*.o \
		Lib/Standard-C/*.*lop Lib/Standard-C/*.c Lib/Standard-C/*.o \
		Lib/*.*lop Lib/*.c Lib/*.o \
		Asm/Common/*.lop Asm/Common/*.c Asm/Common/*.o \
		Asm/Standard-C/*.lop Asm/Standard-C/*.c Asm/Standard-C/*.o \
		Interpreter/*.*lop Interpreter/*.c Interpreter/*.o \
		Repl/*.*lop Repl/*.c Repl/*.o \
		Auxlib/*.*lop Auxlib/*.c Auxlib/*.o \
		Util/*.*lop Util/*.c Util/*.o \
		Testsuite/Lib/*.*lop \
		Compiler/*.*lop Compiler/*.c Compiler/*.o \
		Compat/Larceny/*.c Compat/Larceny/*.o \
		Rts/Build/*.*lop

libclean: lopclean
	rm -f	Lib/Common/*.lap Lib/Sparc/*.lap Lib/Standard-C/*.lap \
		Lib/Common/ecodes.sch Lib/Common/globals.sch \
		Asm/Common/*.lap Asm/Standard-C/*.lap \
		Interpreter/*.lap \
		Repl/*.lap \
		Auxlib/*.lap \
		Testsuite/Lib/*.lap \
		Compiler/*.lap

soclean:
	rm -f Lib/*.so
	rm -f Compiler/*.so
	rm -f Asm/Common/*.so Asm/Sparc/*.so
	rm -f Compat/Chez/*.so

faslclean:
	rm -f Compiler/*.fasl
	rm -f Asm/Common/*.fasl Asm/Sparc/*.fasl Asm/Standard-C/*.fasl
	rm -f Experimental/*.fasl
	rm -f Compat/Larceny/*.fasl
	rm -f Util/*.fasl
	rm -f Lib/makefile.fasl
	rm -f Auxlib/*.fasl
	rm -f Debugger/*.fasl
	rm -f Testsuite/GC/*.fasl
	rm -f Testsuite/Lib/*.fasl
	rm -f Ffi/*.fasl

rtsclean:
	rm -f *.map
	rm -f Compat/Chez/*.o
	( cd Rts ; $(MAKE) rtsclean )

realclean: clean libclean tildeclean rejclean soclean tcovclean faslclean
	rm -f *.heap 
	rm -f Compat/Chez/*.o
	rm -f Testsuite/GC/bb.out*
	( cd Rts ; $(MAKE) realclean )

tcovclean:
	rm -f `find . -name '*\.tcov' -print`

tildeclean:
	rm -f `find . -name '*~' -print`

rejclean:
	rm -f `find . -name '*\.rej' -print`

seedclean:
	rm -f `find . -name '*\.seed' -print`

# For Chez-hosted system.

chezstuff: 
	( cd Compat/Chez ; $(CC) -c bitpattern.c mtime.c )

# For Gambit-hosted system.
# Tested with CC=gcc only.

gambitstuff:
	( cd Compat/Gambit-C ; \
	  rm -f gsi-ffs.o* ; \
	  gsc gsi-ffs.scm ; \
	  gcc -shared -fPIC -D___DYNAMIC gsi-ffs.c gsi-ffs_.c -lc -lgambc \
		-o gsi-ffs.o1 )

# eof
