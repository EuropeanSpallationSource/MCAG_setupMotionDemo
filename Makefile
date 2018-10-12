# Makefile to be able to install everything by simply using make

all:
	./checkws.sh
	/bin/sh -e -x ./compile-epics.sh -i y

asyn:
	./checkws.sh
	/bin/sh -e -x ./compile-epics.sh -m asyn

calc:
	./checkws.sh
	/bin/sh -e -x ./compile-epics.sh -m calc

motor:
	./checkws.sh
	/bin/sh -e -x ./compile-epics.sh -m motor

clean:
	make -C epics/base clean
	/bin/sh $(for m in epics/modules/*; do make -C $m clean; done)
