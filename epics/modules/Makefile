# default target, must come first
all:    alldummy

asyn:   asyndummy

ethercatmc: ethercatmcdummy

motor:   motordummy

clean:  cleandummy

distclean: distcleandummy

gitclean:
	./makewrapper.sh gitclean

help:
	@echo make
	@echo make asyn
	@echo make clean
	@echo make distclean
	@echo make gitclean

alldummy:
	./makewrapper.sh all

asyndummy:
	./makewrapper.sh asyn

distcleandummy:
	./makewrapper.sh distclean

cleandummy:
	./makewrapper.sh clean

ethercatmcdummy:
	./makewrapper.sh ethercatmc

motordummy:
	./makewrapper.sh motor
