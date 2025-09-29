#Define variables
TESTNAME ?= apb_slave_tb
TB_NAME  ?= apb_slave_tb
RADIX    ?= hex

#==========================================
all: clean build run

all_wave: build run wave

drc:
	verilator --lint-only -Wall -f rtl.f

build:
	vlib work
	vmap work work
	vlog -f compile.f | tee compile.log

run:
	vsim -c -quiet -onfinish stop \
	     -voptargs=+acc \
	     -l $(TESTNAME).log \
	     work.$(TB_NAME) \
	     -do "log -r /*; run -all; quit -f"

wave:
	vsim -i -view vsim.wlf -do "add wave vsim:/$(TB_NAME)/*; radix $(RADIX)" &

clean:
	rm -rf work
	rm -rf vsim.dbg
	rm -rf *.ini
	rm -rf *.log
	rm -rf *.wlf
	rm -rf transcript

help:
	@echo ""
	@echo "*****************************************"
	@echo "** make clean : clean all compiled data**"
	@echo "** make build : build the design**"
	@echo "** make run   : run simulation**"
	@echo "** make all   : build and run simulation**"
	@echo "** make wave  : open waveform**"
	@echo "*****************************************"
	@echo ""
