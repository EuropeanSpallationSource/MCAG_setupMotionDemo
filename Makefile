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

EthercatMC:
	./checkws.sh
	/bin/sh -e -x ./compile-epics.sh -m EthercatMC

Streamdevice:
	./checkws.sh
	/bin/sh -e -x ./compile-epics.sh -m StreamDevice

clean:
	./makeclean.sh

help:
	@echo make
	@echo make asyn
	@echo make base
	@echo make calc
	@echo make motor
	@echo make EthercatMC
	@echo make Streamdevice


