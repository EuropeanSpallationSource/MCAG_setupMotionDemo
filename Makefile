# Makefile to be able to install everything by simply using make

all:
	./checkws.sh
	/bin/sh -e -x ./compile-epics.sh -i y

asyn:
	./checkws.sh
	/bin/sh -e -x ./compile-epics.sh -m asyn

base:
	./checkws.sh
	/bin/sh -e -x ./compile-epics.sh -m base

calc:
	./checkws.sh
	/bin/sh -e -x ./compile-epics.sh -m calc

motor:
	./checkws.sh
	/bin/sh -e -x ./compile-epics.sh -m motor

clean:
	./makeclean.sh
