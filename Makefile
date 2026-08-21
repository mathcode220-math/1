# Makefile for Silicon Agent Project
.PHONY: all clean sim sim_modular waves behavioral help verify_modular docs lint formal_verify compile compile_modular

SRC_DIR = src
TB_DIR = testbench
SIM_MODULAR = sim_modular.vvp

compile_modular:
	iverilog -g2012 -DSIMULATION -I $(SRC_DIR) -o $(SIM_MODULAR) $(SRC_DIR)/agent_types.svh $(SRC_DIR)/agent_interfaces.sv $(SRC_DIR)/cdc_synchronizers.sv $(SRC_DIR)/saturation_arithmetic.sv $(SRC_DIR)/config_registers.sv $(SRC_DIR)/performance_counters.sv $(SRC_DIR)/agent_sva.sv $(SRC_DIR)/silicon_agent_closed_loop.sv $(TB_DIR)/silicon_agent_tb.sv

sim_modular: compile_modular
	vvp $(SIM_MODULAR)

clean:
	rm -f $(SIM_MODULAR) *.vcd

help:
	@echo "Usage: make [target]"
	@echo "Targets: compile_modular, sim_modular, clean, help"
