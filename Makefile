SIM ?= verilator
ARCH ?= sequential

export PYTHONPATH := $(PWD)/cocotb
COMPILE_ARGS += -GINPUT_ROWS=2 -GINPUT_COLS=2 -GWEIGHT_COLS=3

ifeq ($(ARCH),sequential)
	VERILOG_SOURCES += $(PWD)/rtl/matrix_layer.sv
	VERILOG_SOURCES += $(PWD)/rtl/dot_product.sv
	VERILOG_SOURCES += $(PWD)/rtl/multiplier.sv

	TOPLEVEL := matrix_layer
	COCOTB_TEST_MODULES := test_matrix_layer

else ifeq ($(ARCH),parallel)
	VERILOG_SOURCES += $(PWD)/rtl/parallel_matrix_layer.sv
	VERILOG_SOURCES += $(PWD)/rtl/dot_product.sv
	VERILOG_SOURCES += $(PWD)/rtl/multiplier.sv

	TOPLEVEL := parallel_matrix_layer
	COCOTB_TEST_MODULES := test_parallel_matrix_layer

	COMPILE_ARGS += -GPARALLEL_MACS=2
endif

include $(shell cocotb-config --makefiles)/Makefile.sim

sequential:
	$(MAKE) clean
	$(MAKE) ARCH=sequential

parallel:
	$(MAKE) clean
	$(MAKE) ARCH=parallel

clean::
	rm -rf obj_dir/ sim_build/ __pycache__/ ./matrix_layer.vcd results.xml

synth-sequential:
	yosys -Q -p "read_verilog -sv synthesis/matrix_layer_yosys.sv; hierarchy -top matrix_layer_yosys; proc; opt; memory; opt; techmap; opt; write_verilog synthesis/matrix_layer_netlist.v; stat"

synth-parallel:
	yosys -Q -p "read_verilog -sv synthesis/parallel_matrix_layer_yosys.sv; hierarchy -top parallel_matrix_layer_yosys; proc; opt; memory; opt; techmap; opt; write_verilog synthesis/parallel_matrix_layer_netlist.v; stat"

synth:
	$(MAKE) synth-sequential
	$(MAKE) synth-parallel

fpga-sim:
	$(MAKE) clean
	$(MAKE) \
		TOPLEVEL=top \
		COCOTB_TEST_MODULES=test_fpga_uart \
		VERILOG_SOURCES="$(PWD)/rtl/matrix_layer.sv $(PWD)/rtl/dot_product.sv $(PWD)/rtl/multiplier.sv $(PWD)/rtl/uart_tx.sv $(PWD)/fpga/ice40/top.sv"

fpga:
	mkdir -p fpga/ice40
	yosys -Q -p "read_verilog -sv rtl/uart_tx.sv rtl/multiplier.sv synthesis/dot_product_yosys.sv synthesis/matrix_layer_yosys.sv synthesis/fpga_top_yosys.sv; hierarchy -top fpga_top_yosys; synth_ice40 -top fpga_top_yosys -json fpga/ice40/fpga_top.json"
	nextpnr-ice40 --up5k --package sg48 --json fpga/ice40/fpga_top.json --asc fpga/ice40/fpga_top.asc --pcf-allow-unconstrained --freq 12
	icepack fpga/ice40/fpga_top.asc fpga/ice40/fpga_top.bin

.PHONY: sequential parallel clean synth synth-sequential synth-parallel fpga-sim fpga