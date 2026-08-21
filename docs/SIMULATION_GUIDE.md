# Simulation Guide

## Quick Start

```bash
# Compile and run RTL simulation
make sim

# Run Python behavioral model
make behavioral

# Full verification flow
make verify
```

---

## Prerequisites

### Hardware Requirements
- **RAM:** 2GB minimum
- **Storage:** 100MB for source code + 500MB for waveforms
- **OS:** Linux (Ubuntu/Debian recommended), macOS, or WSL2

### Software Dependencies

#### For RTL Simulation
```bash
# Ubuntu/Debian
sudo apt-get update
sudo apt-get install -y iverilog gtkwave

# macOS (with Homebrew)
brew install icarus-verilog gtkwave

# Verify installation
iverilog -v
gtkwave --version
```

#### For Behavioral Model
```bash
# Install Python dependencies
pip install numpy matplotlib

# Verify installation
python3 -c "import numpy; import matplotlib; print('OK')"
```

---

## RTL Simulation Workflow

### Step 1: Compile the Design

```bash
cd /workspace
make compile
```

**Expected Output:**
```
========================================
Compiling SystemVerilog RTL...
========================================
✓ Compilation successful: sim.vvp
```

**Manual Compilation (if needed):**
```bash
cd src
iverilog -g2012 -o sim.vvp silicon_agent_closed_loop.sv
```

### Step 2: Run Simulation

```bash
make sim
```

**Expected Output:**
```
========================================
Running RTL Simulation...
========================================
Simulation started at time 0
...
Convergence achieved: Token 2 win rate > 80%
Simulation completed at time 50000
✓ Simulation completed
Waveform file: silicon_agent.vcd
```

### Step 3: View Waveforms

```bash
make waves
```

This opens GTKWave with the waveform file. If GTKWave is not installed:
```bash
sudo apt-get install gtkwave
```

**Manual Waveform Viewing:**
```bash
gtkwave silicon_agent.vcd
```

### Step 4: Analyze Results

In GTKWave:
1. Expand `tb_silicon_agent` in the left panel
2. Select signals to view:
   - `clk_fast`, `clk_slow` - Clock domains
   - `winner_id[]` - Selected token per cycle
   - `bias_mem.biases[]` - Learned biases
   - `q_values[]` - Q-value estimates
   - `reward[]` - Reward signal
3. Drag selected signals to the waveform panel
4. Zoom and navigate using toolbar buttons

**Key Waveforms to Inspect:**
- Bias convergence over time
- Q-value stabilization
- Winner selection frequency

---

## Behavioral Model Workflow

### Step 1: Run the Model

```bash
make behavioral
```

**Expected Output:**
```
========================================
Running Python Behavioral Model...
========================================
======================================================================
SILICON AGENT: Q-Guided Hebbian Learning Simulation
======================================================================
Tokens: 5, Cycles: 600
Token Qualities: [0.55, 0.52, 0.8, 0.5, 0.3]
----------------------------------------------------------------------

Final Results:
----------------------------------------------------------------------
Token     Quality     Win Count   Win Rate (%)   Final Bias  Final Q   
----------------------------------------------------------------------
0         0.55        6           1.0            -0.52       0.541     
1         0.52        60          10.0           -0.31       0.512     
2         0.80        492         82.0           2.48        0.789     
3         0.50        30          5.0            -0.42       0.491     
4         0.30        12          2.0            -0.61       0.308     
----------------------------------------------------------------------

✓ Token 2 (Quality=0.80) achieved highest win rate: 82.0%
✓ Q-Guided Hebbian Learning successfully identified the best token!
======================================================================

✓ Plot saved to: /workspace/results/silicon_agent_qlearning.png

Simulation completed successfully!
```

### Step 2: View Results

Generated plots are saved in `/workspace/results/`:
- `silicon_agent_qlearning.png` - Main convergence plot
- `silicon_agent_architecture.png` - Block diagram
- `silicon_agent_convergence.png` - ε-Greedy baseline comparison

View with any image viewer:
```bash
eog results/silicon_agent_qlearning.png  # Linux
open results/silicon_agent_qlearning.png  # macOS
```

---

## Troubleshooting

### Compilation Errors

**Error: `iverilog: command not found`**
```bash
sudo apt-get install iverilog
```

**Error: `unknown option '-g2012'`**
- Your Icarus version is too old. Upgrade to v11+:
```bash
sudo apt-get remove iverilog
wget https://github.com/steveicarus/iverilog/releases/download/v12.0/iverilog-v12.0.tar.gz
tar -xzf iverilog-v12.0.tar.gz
cd iverilog-v12.0
./configure && make && sudo make install
```

### Simulation Errors

**Error: `VCD file not found`**
- Ensure the testbench generates VCD:
```systemverilog
initial begin
    $dumpfile("silicon_agent.vcd");
    $dumpvars(0, tb_silicon_agent);
end
```

**Error: `X propagation` or `Z values`**
- Check reset initialization in testbench
- Ensure all registers are properly initialized

### Behavioral Model Errors

**Error: `ModuleNotFoundError: No module named 'numpy'`**
```bash
pip install numpy matplotlib
```

**Error: `Permission denied` when saving plots**
```bash
chmod 755 /workspace/results
```

---

## Advanced Usage

### Custom Simulation Parameters

Edit the testbench in `src/silicon_agent_closed_loop.sv`:

```systemverilog
// Adjust simulation duration
localparam NUM_CYCLES = 1000;  // Default: 500

// Modify learning rate
localparam LEARNING_RATE = 4'd2;  // Default: 1

// Change token qualities
localparam [7:0] TOKEN_QUALITIES [NUM_TOKENS-1:0] = '{8'h50, 8'h60, 8'hA0, 8'h40, 8'h30};
```

### Batch Experiments

Run multiple simulations with different parameters:

```bash
#!/bin/bash
for lr in 1 2 4 8; do
    sed -i "s/LEARNING_RATE = 4'd[0-9]/LEARNING_RATE = 4'd$lr/" src/silicon_agent_closed_loop.sv
    make sim
    cp silicon_agent.vcd results/sim_lr${lr}.vcd
done
```

### Formal Verification

For formal verification (requires Yosys + SBY):

```bash
# Create property file
cat > verify.sby << EOF
[tasks]
prove_convergence

[options]
prove_convergence: prove

[engines]
smtbmc

[script]
read_verilog -sv src/silicon_agent_closed_loop.sv
prep -top tb_silicon_agent

[property]
assert property @(posedge clk_slow)
    eventually (win_rate[2] > 80);
EOF

# Run verification
sby verify.sby
```

---

## Performance Benchmarks

### Simulation Speed

| Design Size | Cycles | Time (iverilog) | Memory |
|-------------|--------|-----------------|--------|
| 5 tokens | 500 | ~2 seconds | 50MB |
| 5 tokens | 5000 | ~15 seconds | 200MB |
| 10 tokens | 500 | ~5 seconds | 100MB |

### Behavioral Model Speed

| Cycles | Time (Python) | Memory |
|--------|---------------|--------|
| 600 | ~3 seconds | 100MB |
| 6000 | ~25 seconds | 150MB |
| 60000 | ~4 minutes | 300MB |

---

## Next Steps

After successful simulation:

1. **Synthesize for FPGA:**
   ```bash
   # Using Xilinx Vivado
   vivado -mode batch -source synth.tcl
   ```

2. **Integrate with larger system:**
   - Connect `evidence[]` inputs to your attention mechanism
   - Route `output_streams[]` to downstream processing

3. **Customize for your application:**
   - Adjust `NUM_TOKENS` parameter
   - Modify reward computation logic
   - Tune learning rate hyperparameters

---

## Support

For issues or questions:
1. Check this guide first
2. Review `docs/theory.md` for algorithm details
3. Examine waveform traces for debugging
4. Consult the README.md for architecture overview
