# Makefile for Silicon Agent Project
# Automates compilation, simulation, and cleanup

.PHONY: all clean sim waves behavioral help verify_modular docs

#=============================================================================
# Configuration
#=============================================================================
SRC_DIR = src
TB_DIR = testbench
RESULTS_DIR = results
SCRIPTS_DIR = scripts
DOCS_DIR = docs

RTL_FILE = $(SRC_DIR)/silicon_agent_closed_loop.sv
SIM_OUTPUT = sim.vvp
SIM_MODULAR = sim_modular.vvp
WAVEFORM_FILE = silicon_agent.vcd
BEHAVIORAL_SCRIPT = $(SCRIPTS_DIR)/behavioral_model.py

# Source files for modular testbench
SRCS = $(SRC_DIR)/agent_types.svh \
       $(SRC_DIR)/agent_interfaces.sv \
       $(SRC_DIR)/cdc_synchronizers.sv \
       $(SRC_DIR)/saturation_arithmetic.sv \
       $(SRC_DIR)/config_registers.sv \
       $(SRC_DIR)/performance_counters.sv \
       $(SRC_DIR)/agent_sva.sv \
       $(SRC_DIR)/silicon_agent_closed_loop.sv \
       $(TB_DIR)/silicon_agent_tb.sv

#=============================================================================
# Default Target
#=============================================================================
all: help

#=============================================================================
# Compilation (Original Testbench)
#=============================================================================
compile: $(RTL_FILE)
@echo "========================================"
@echo "Compiling SystemVerilog RTL..."
@echo "========================================"
iverilog -g2012 -o $(SIM_OUTPUT) $(RTL_FILE)
@echo "✓ Compilation successful: $(SIM_OUTPUT)"

#=============================================================================
# Simulation (Original Testbench)
#=============================================================================
sim: compile
@echo "========================================"
@echo "Running RTL Simulation..."
@echo "========================================"
vvp $(SIM_OUTPUT)
@echo "✓ Simulation completed"
@echo "Waveform file: $(WAVEFORM_FILE)"

#=============================================================================
# Compilation (Modular Testbench with Coverage)
#=============================================================================
compile_modular: $(SRCS)
@echo "========================================"
@echo "Compiling Modular Testbench..."
@echo "========================================"
iverilog -g2012 \
-DSIMULATION \
-o $(SIM_MODULAR) \
$(SRC_DIR)/agent_types.svh \
$(SRC_DIR)/agent_interfaces.sv \
$(SRC_DIR)/cdc_synchronizers.sv \
$(SRC_DIR)/saturation_arithmetic.sv \
$(SRC_DIR)/config_registers.sv \
$(SRC_DIR)/performance_counters.sv \
$(SRC_DIR)/agent_sva.sv \
$(SRC_DIR)/silicon_agent_closed_loop.sv \
$(TB_DIR)/silicon_agent_tb.sv
@echo "✓ Compilation successful: $(SIM_MODULAR)"

#=============================================================================
# Simulation (Modular Testbench with Coverage)
#=============================================================================
sim_modular: compile_modular
@echo "========================================"
@echo "Running Modular Testbench with Coverage..."
@echo "========================================"
vvp $(SIM_MODULAR)
@echo "✓ Simulation completed"
@echo "Waveform file: $(WAVEFORM_FILE)"

#=============================================================================
# Waveform Viewer
#=============================================================================
waves:
@echo "========================================"
@echo "Opening GTKWave..."
@echo "========================================"
gtkwave $(WAVEFORM_FILE) 2>/dev/null || echo "GTKWave not found. Install with: sudo apt-get install gtkwave"

#=============================================================================
# Behavioral Model
#=============================================================================
behavioral:
@echo "========================================"
@echo "Running Python Behavioral Model..."
@echo "========================================"
cd $(SCRIPTS_DIR) && python3 $(BEHAVIORAL_SCRIPT)
@echo "✓ Behavioral model completed"
@echo "Plots saved to: $(RESULTS_DIR)/"

#=============================================================================
# Full Verification Flow (Original)
#=============================================================================
verify: behavioral sim
@echo "========================================"
@echo "Full verification flow completed!"
@echo "========================================"
@echo "Check results in: $(RESULTS_DIR)/"
@echo "Check waveforms in: $(WAVEFORM_FILE)"

#=============================================================================
# Full Verification Flow (Modular with Coverage)
#=============================================================================
verify_modular: behavioral sim_modular
@echo "========================================"
@echo "Modular verification flow completed!"
@echo "========================================"
@echo "Check coverage report above"
@echo "Check waveforms in: $(WAVEFORM_FILE)"

#=============================================================================
# Documentation
#=============================================================================
docs:
@echo "========================================"
@echo "Documentation Files:"
@echo "========================================"
@ls -la $(DOCS_DIR)/
@echo ""
@echo "Main README: ./README.md"

#=============================================================================
# Cleanup
#=============================================================================
clean:
@echo "========================================"
@echo "Cleaning up temporary files..."
@echo "========================================"
rm -f $(SIM_OUTPUT)
rm -f $(SIM_MODULAR)
rm -f $(WAVEFORM_FILE)
rm -f *.vcd
rm -f __pycache__/*.pyc
rm -rf __pycache__
@echo "✓ Cleanup completed"

#=============================================================================
# Help
#=============================================================================
help:
@echo "========================================"
@echo "Silicon Agent Build System"
@echo "========================================"
@echo ""
@echo "Available targets:"
@echo "  make compile       - Compile SystemVerilog RTL (original)"
@echo "  make sim           - Compile and run simulation (original)"
@echo "  make compile_modular - Compile modular testbench with coverage"
@echo "  make sim_modular   - Run modular testbench with coverage"
@echo "  make waves         - Open GTKWave waveform viewer"
@echo "  make behavioral    - Run Python behavioral model"
@echo "  make verify        - Run full verification (behavioral + sim)"
@echo "  make verify_modular- Run modular verification with coverage"
@echo "  make docs          - List documentation files"
@echo "  make clean         - Remove temporary files"
@echo "  make help          - Show this help message"
@echo ""
@echo "Quick Start:"
@echo "  make verify        - Run complete verification flow (original)"
@echo "  make verify_modular- Run modular verification with coverage"
@echo "  make sim           - Run RTL simulation only"
@echo "  make sim_modular   - Run modular testbench with coverage"
@echo ""
