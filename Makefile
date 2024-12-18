# Makefile to be able to install everything by simply using make

all:
	./checkws.sh
	/bin/sh -e -x ./compile-epics.sh -i y

ads:
	./checkws.sh
	/bin/sh -e -x ./compile-epics.sh -m ads

asyn:
	./checkws.sh
	/bin/sh -e -x ./compile-epics.sh -m asyn

base:
	./checkws.sh
	/bin/sh -e -x ./compile-epics.sh -m base

calc:
	./checkws.sh
	/bin/sh -e -x ./compile-epics.sh -m calc

cacm:
	./checkws.sh
	/bin/sh -e -x ./compile-epics.sh -m cacm

ethercatmc:
	./checkws.sh
	/bin/sh -e -x ./compile-epics.sh -m ethercatmc

motor:
	./checkws.sh
	/bin/sh -e -x ./compile-epics.sh -m motor

pcas:
	./checkws.sh
	/bin/sh -e -x ./compile-epics.sh -m pcas

pvxs:
	./checkws.sh
	/bin/sh -e -x ./compile-epics.sh -m pvxs

re2c:
	./checkws.sh
	/bin/sh -e -x ./compile-epics.sh -m re2c


Streamdevice:
	./checkws.sh
	/bin/sh -e -x ./compile-epics.sh -m StreamDevice

clean:
	./makeclean.sh clean

distclean:
	./makeclean.sh distclean

gitclean:
	./makeclean.sh gitclean

help:
	@echo make
	@echo make asyn
	@echo make base
	@echo make calc
	@echo make cacm
	@echo make motor
	@echo make ethercatmc
	@echo make pcas
	@echo make pvxs
	@echo make re2c
	@echo make Streamdevice


