# Xilinx FPGA Constraints File for Silicon Agent
# Target: Xilinx Alveo U200 or similar
# Clock: 100 MHz (fast), 10 MHz (slow)

## Clock Definitions
create_clock -period 10.000 -name clk_fast [get_ports clk_fast]
create_clock -period 100.000 -name clk_slow [get_ports clk_slow]

## Clock Uncertainty
set_clock_uncertainty -setup 0.500 [get_clocks clk_fast]
set_clock_uncertainty -hold 0.500 [get_clocks clk_fast]
set_clock_uncertainty -setup 1.000 [get_clocks clk_slow]
set_clock_uncertainty -hold 1.000 [get_clocks clk_slow]

## Input/Output Delays
set_input_delay -clock clk_fast -max 2.000 [get_ports evidence_*]
set_input_delay -clock clk_fast -min 0.500 [get_ports evidence_*]
set_input_delay -clock clk_slow -max 5.000 [get_ports reward*]
set_input_delay -clock clk_slow -min 1.000 [get_ports reward*]

set_output_delay -clock clk_fast -max 2.500 [get_ports winner_id*]
set_output_delay -clock clk_fast -min 0.500 [get_ports winner_id*]
set_output_delay -clock clk_slow -max 5.000 [get_ports bias*]
set_output_delay -clock clk_slow -min 1.000 [get_ports bias*]

## Reset Constraints
set_reset_type ASYNC_LOW [get_ports rst_n]
set_reset_type ASYNC_LOW [get_ports rst_slow_n]

## False Paths
# CDC paths are handled by synchronizers, exclude from timing analysis
set_false_path -from [get_cells */cdc_sync_inst*] -to [get_cells */decision_core*]
set_false_path -from [get_cells */q_agent*] -to [get_cells */bias_memory*]

## Multi-Cycle Paths
# Learning rate updates can take multiple cycles
set_multicycle_path -setup 5 -from [get_cells */q_agent*/q_update*] -to [get_cells */bias_memory*/bias_reg*]
set_multicycle_path -hold 4 -from [get_cells */q_agent*/q_update*] -to [get_cells */bias_memory*/bias_reg*]

## I/O Standards (adjust based on board)
set_property IOSTANDARD LVCMOS18 [get_ports clk_fast]
set_property IOSTANDARD LVCMOS18 [get_ports clk_slow]
set_property IOSTANDARD LVCMOS18 [get_ports rst_n]
set_property IOSTANDARD LVCMOS18 [get_ports rst_slow_n]

set_property IOSTANDARD LVCMOS18 [get_ports evidence_*]
set_property IOSTANDARD LVCMOS18 [get_ports bias_*]
set_property IOSTANDARD LVCMOS18 [get_ports winner_id*]
set_property IOSTANDARD LVCMOS18 [get_ports reward*]

## Drive Strength
set_property DRIVE 8 [get_ports clk_fast]
set_property DRIVE 8 [get_ports clk_slow]

## Slew Rate
set_property SLEW FAST [get_ports clk_fast]
set_property SLEW FAST [get_ports clk_slow]

## Pin Locations (example for Alveo U200 - adjust for your board)
# set_property PACKAGE_PIN <pin_number> [get_ports clk_fast]
# set_property PACKAGE_PIN <pin_number> [get_ports clk_slow]
# set_property PACKAGE_PIN <pin_number> [get_ports rst_n]

## Power Optimization
set_property CLOCK_ENABLE TRUE [get_clocks clk_fast]
set_property CLOCK_ENABLE TRUE [get_clocks clk_slow]

## Area Group Constraints (optional, for better placement)
create_pblock pblock_decision_core
resize_pblock pblock_decision_core {SLICE_X0Y0 SLICE_X50Y50}
add_cells_to_pblock [get_pblocks pblock_decision_core] [get_cells decision_core]

create_pblock pblock_q_agent
resize_pblock pblock_q_agent {SLICE_X51Y0 SLICE_X100Y50}
add_cells_to_pblock [get_pblocks pblock_q_agent] [get_cells q_agent]

create_pblock pblock_bias_memory
resize_pblock pblock_bias_memory {BRAM_X0Y0 BRAM_X10Y20}
add_cells_to_pblock [get_pblocks pblock_bias_memory] [get_cells bias_memory]

## Timing Exceptions for Configuration Interface
set_false_path -from [get_cells */config_regs*] -to [get_cells */agent_core*]

## Maximum Fanout
set_max_fanout 16 [get_cells */clk_gate*]

## Keep Hierarchy for Debugging
set_property KEEP_HIERARCHY TRUE [get_cells silicon_agent_top]
set_property KEEP_HIERARCHY TRUE [get_cells decision_core]
set_property KEEP_HIERARCHY TRUE [get_cells q_agent]
set_property KEEP_HIERARCHY TRUE [get_cells bias_memory]
