PLATFORM ?= xilinx_u50_gen3x16_xdma_5_202210_1
BSCFLAGS = -show-schedule -aggressive-conditions 
BSCFLAGS_SYNTH = -bdir ./obj -vdir ./obj/verilog -simdir ./obj -info-dir ./obj -fdir ./obj 
TARGET := hw
BUILD_DIR := ../$(TARGET)

BSVPATH=../
BSIM_DIR=./bsim/
BSCFLAGS_BSIM = -bdir $(BSIM_DIR) -vdir $(BSIM_DIR) -simdir $(BSIM_DIR) -info-dir $(BSIM_DIR) -fdir $(BSIM_DIR) -D BSIM -l pthread
BSIM_CPPFILES=../host/host.cpp			  

.PHONY: all verilog bsim

MODULEPATH=

VIVADO := $(XILINX_VIVADO)/bin/vivado

all: verilog obj/kernel.xo

obj/kernel.xo: ./kernel.xml ./scripts/package_kernel.tcl ./scripts/gen_xo.tcl $(wildcard ./obj/verilog/*.v) verilog
	mkdir -p obj
	$(VIVADO) -mode batch -source scripts/gen_xo.tcl -tclargs $(BUILD_DIR)/kernel.xo kernel hw $(PLATFORM)

verilog: $(wildcard *.bsv)
	mkdir -p obj
	mkdir -p obj/verilog
	bsc  $(BSCFLAGS) $(BSCFLAGS_SYNTH) -remove-dollar -p +:$(MODULEPATH) -verilog -u -g kernel KernelTop.bsv 
	cd obj/verilog/;bash ../../scripts/verilogcopy.sh
	cp *.v ./obj/verilog/

bsim:
	mkdir -p $(BSIM_DIR)
	cd $(BSIM_DIR)
	bsc $(BSCFLAGS) $(BSCFLAGS_BSIM) -p +:$(BSVPATH) -sim -u -g kernel_bsim KernelTop.bsv
	cd ../
	bsc $(BSCFLAGS) $(BSCFLAGS_BSIM) -sim -e kernel_bsim -o $(BSIM_DIR)/bsim $(BSIM_DIR)/*.ba $(BSIM_CPPFILES)
	
clean:
	rm -rf obj
	rm -rf *.log *.jou
	rm -rf ./bsim
