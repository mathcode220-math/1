# Synopsys Design Constraints (SDC) for Silicon Agent
# Target: ASIC Implementation
# Clock: 100 MHz (fast), 10 MHz (slow)

## Clock Definitions
create_clock -name clk_fast -period 10.000 [get_ports clk_fast]
create_clock -name clk_slow -period 100.000 [get_ports clk_slow]

## Generated Clocks (if any)
# create_generated_clock -name clk_divided -source clk_fast -divide_by 2 [get_pins clk_div_reg/Q]

## Clock Uncertainty
set_clock_uncertainty -setup 0.500 [get_clocks clk_fast]
set_clock_uncertainty -hold 0.500 [get_clocks clk_fast]
set_clock_uncertainty -setup 1.000 [get_clocks clk_slow]
set_clock_uncertainty -hold 1.000 [get_clocks clk_slow]

## Input Transition Time
set_input_transition -max 0.500 [get_ports evidence_*]
set_input_transition -max 1.000 [get_ports reward*]
set_input_transition -min 0.100 [all_inputs]

## Output Load Capacitance (adjust based on target technology)
set_load -output -max 0.500 [get_ports bias_*]
set_load -output -max 0.500 [get_ports winner_id*]

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

## Don't Touch Constraints (for critical paths)
set_dont_touch [get_cells bias_memory]
set_dont_touch [get_cells cdc_synchronizers]

## False Paths
# CDC paths handled by synchronizers
set_false_path -from [get_cells */cdc_sync*] -to [get_cells */decision_core*]
set_false_path -from [get_cells */q_agent*] -to [get_cells */bias_memory*]
set_false_path -from [get_cells */config_regs*] -to [get_cells */agent_core*]

## Multi-Cycle Paths
# Learning updates can take multiple cycles
set_multicycle_path -setup 5 -from [get_cells */q_agent*/q_update*] -to [get_cells */bias_memory*/bias_reg*]
set_multicycle_path -hold 4 -from [get_cells */q_agent*/q_update*] -to [get_cells */bias_memory*/bias_reg*]

# Configuration register access
set_multicycle_path -setup 3 -from [get_cells */config_regs*/addr_decode*] -to [get_cells */config_regs*/data_mux*]
set_multicycle_path -hold 2 -from [get_cells */config_regs*/addr_decode*] -to [get_cells */config_regs*/data_mux*]

## Maximum Area Constraints (optional)
# set_max_area 50000

## Maximum Fanout Constraints
set_max_fanout 16 [current_design]
set_max_fanout 8 [get_cells */clk_gate*]
set_max_fanout 4 [get_cells */critical_path*]

## Maximum Capacitance
set_max_capacitance 1.000 [current_design]

## Drive Strength Constraints
set_drive 1.000 [get_ports clk_fast]
set_drive 1.000 [get_ports clk_slow]

## Timing Groups
group_path -name input_to_decision -from [get_ports evidence_*] -to [get_cells decision_core/*]
group_path -name q_learning_path -from [get_cells q_agent/*] -to [get_cells bias_memory/*]
group_path -name cdc_path -from [get_cells cdc_synchronizers/*] -to [get_cells decision_core/*]

## Case Analysis (for mode selection)
set_case_analysis 0 [get_ports test_mode]
set_case_analysis 1 [get_ports normal_operation]

## Operating Conditions
# Adjust based on target technology node
set_operating_conditions -analysis_type on_chip_variation \
    -library slow_library \
    -worst commercial \
    -best typical

## Wire Load Model (for older technologies)
# set_wire_load_model -name small_1 -library tech_library

## Physical Constraints (placement hints)
# set_placement_constraint -blockage -type hard -range {100 100 200 200}

## Keep Hierarchy for Debugging and Optimization
set_keep_hierarchy true [get_cells silicon_agent_top]
set_keep_hierarchy true [get_cells decision_core]
set_keep_hierarchy true [get_cells q_agent]
set_keep_hierarchy true [get_cells bias_memory]
set_keep_hierarchy true [get_cells cdc_synchronizers]

## Power Domain Constraints (if multi-voltage design)
# create_power_domain -name PD_CORE -voltage 1.0
# create_power_domain -name PD_IO -voltage 1.8
# assign_power_domain -domain PD_CORE [get_cells silicon_agent_top/core_*]
# assign_power_domain -domain PD_IO [get_ports *_io]

## Level Shifter Constraints (if multi-voltage)
# set_level_shifter -domain PD_CORE -to_domain PD_IO -cells level_shifter_inst_*

## Isolation Cell Constraints
# set_isolation -domain PD_CORE -isolation_cell iso_cell_* -clamp_value 0

## Retention Register Constraints
# set_retention -domain PD_CORE -retention_register ret_reg_*

## Update Constraints
update_constraints

## Report Settings
report_constraint -all_violators -verbose > timing_report.txt
report_timing -max_paths 100 -nworst 10 > timing_paths.txt
report_qor > qor_report.txt
