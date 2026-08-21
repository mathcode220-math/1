# Silicon Agent: Closed-Loop Neuromorphic Attention System

> A self-learning attention mechanism implemented in synthesizable SystemVerilog.
> The agent discovers which token produces the best output quality through real-time Q-guided reinforcement learning.

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Key Innovation: Q-Guided Hebbian Learning](#key-innovation-q-guided-hebbian-learning)
3. [Module Hierarchy](#module-hierarchy)
4. [Simulation Results](#simulation-results)
5. [How to Run](#how-to-run)
6. [File Structure](#file-structure)
7. [Future Roadmap](#future-roadmap)
8. [References](#references)

---

## Architecture Overview

This design implements a **closed-loop silicon agent** that learns to attend to the best token autonomously. It separates:

| Domain | Speed | State | Components |
|--------|-------|-------|------------|
| **Execution** | High clock (fast) | Stateless | Decision Core, Stochastic Router |
| **Policy** | Low clock (slow) | Stateful | Bias Memory, Q-Guided Agent |

This separation enables:
- **Clean Clock Domain Crossing (CDC)** between fast execution and slow learning
- **IP Reusability** — the `decision_core` can be dropped into Vision Transformers, Routing Networks, or Branch Predictors
- **Easier Verification** — the stateless execution path is trivial to verify formally

### The Closed Loop

```
Evidence (Q.K) ──> Decision Core ──> Stochastic Router ──> Output
       ^                                      |              |
       |                                      v              v
   Bias Memory <── Q-Guided Agent <── Reward Monitor <── Observed Quality
```

1. **Decision Core** computes `Score = Evidence + Bias` and picks a winner (WTA)
2. **Stochastic Router** routes the winner's bitstream to the output
3. **Reward Monitor** counts set bits (popcount) and compares against target
4. **Q-Guided Agent** updates the Q-table and adjusts the winner's bias
5. **Bias Memory** stores the learned policy for the next cycle

---

## Key Innovation: Q-Guided Hebbian Learning

### The Problem with Naive Hebbian Learning

Standard Hebbian rule: *"If reward is positive, boost the winner's bias."*

**Trap:** If Token 0 wins by random chance in cycle 1, its bias grows → it wins again → bias grows more. Even if Token 2 is objectively better, Token 0 dominates forever. This is the **Matthew Effect**.

### The Solution: Q-Value Estimation

The Q-Guided Agent maintains a **running average reward (Q-value)** per token:

```
Q[winner] = Q[winner] + (reward - Q[winner]) >> 3   // EMA with alpha = 1/8
```

Then compares the winner's Q against the **average Q across all tokens**:

```
if Q[winner] > Q_average:
    bias[winner] += LEARNING_RATE    // This token is genuinely good
else:
    bias[winner] -= LEARNING_RATE    // This token is worse than average
```

**Result:** The agent learns *which token is best*, not just *who won last*.

---

## Module Hierarchy

```
silicon_agent_top
├── bias_memory              # Dual-port register file (5 x 16-bit)
│   ├── learn_write_en       # From Q-Guided Agent
│   ├── agent_read_addr      # From Q-Guided Agent
│   └── bias_out[]           # To Decision Cores
│
├── decision_core [x5]       # One per query
│   ├── evidence[]           # From Systolic Array
│   ├── bias[]               # From Bias Memory
│   ├── one_hot_weights      # To Stochastic Router
│   └── winner_id            # To Q-Guided Agent
│
├── stochastic_weighted_sum [x5]  # One per query
│   ├── weights              # One-hot from Decision Core
│   ├── V_streams[][]        # From Environment
│   └── output_streams[]     # To Reward Monitor & Output
│
├── stochastic_reward_monitor [x5]  # One per query
│   ├── observed[]           # From Stochastic Router
│   ├── target[]             # From Configuration
│   └── reward[]             # To Q-Guided Agent
│
└── q_guided_agent           # Learning engine
    ├── winner_id[]          # From Decision Cores
    ├── reward[]             # From Reward Monitors
    ├── clk_slow             # Slow clock domain
    └── write_en, addr, data # To Bias Memory
```

---

## Simulation Results

### Behavioral Model (Python)

Running 600 cycles with token qualities `[0.55, 0.52, 0.80, 0.50, 0.30]`:

| Token | Quality | Win Count | Win Rate (%) | Final Bias | Final Q |
|-------|---------|-----------|--------------|------------|---------|
| 0     | 0.55    | ~6        | ~1%          | ~-0.5      | ~0.54   |
| 1     | 0.52    | ~60       | ~10%         | ~-0.3      | ~0.51   |
| **2** | **0.80**| **~492**  | **~82%**     | **~+2.5**  | **~0.79**|
| 3     | 0.50    | ~30       | ~5%          | ~-0.4      | ~0.49   |
| 4     | 0.30    | ~12       | ~2%          | ~-0.6      | ~0.31   |

**✓ Token 2 (best quality) correctly achieves 82% win rate!**

### RTL Simulation (Icarus Verilog)

The testbench in `silicon_agent_closed_loop.sv` replicates this scenario:
- Self-checking assertions verify convergence
- VCD waveform generation for debugging
- Convergence monitor tracks win rates over time

---

## How to Run

### Prerequisites

```bash
# Install Icarus Verilog
sudo apt-get install iverilog gtkwave

# Install Python dependencies for behavioral model
pip install numpy matplotlib
```

### Compile & Run RTL Simulation

```bash
cd src

# Compile
iverilog -g2012 -o sim.vvp silicon_agent_closed_loop.sv

# Run simulation
vvp sim.vvp

# View waveforms
gtkwave silicon_agent.vcd
```

### Run Behavioral Model

```bash
cd scripts
python3 behavioral_model.py

# Output plots saved to ../results/
```

---

## File Structure

```
silicon-agent/
├── README.md                              # This documentation
├── Makefile                               # Build automation
├── src/
│   └── silicon_agent_closed_loop.sv       # Complete RTL + testbench
├── docs/
│   ├── theory.md                          # Mathematical foundations
│   └── SIMULATION_GUIDE.md                # Detailed simulation instructions
├── scripts/
│   └── behavioral_model.py                # Python validation model
└── results/
    ├── silicon_agent_qlearning.png        # Convergence proof
    ├── silicon_agent_architecture.png     # Block diagram
    └── silicon_agent_convergence.png      # ε-Greedy baseline
```

---

## Future Roadmap

### V1 (Current)
- ✓ Basic Q-Guided Hebbian Learning
- ✓ Single-layer attention
- ✓ Fixed-point arithmetic

### V2
- [ ] Multi-head attention support
- [ ] Configurable number of tokens
- [ ] Adaptive learning rate

### V3
- [ ] Sparse attention patterns
- [ ] Quantization-aware training
- [ ] Pipeline integration with systolic arrays

### V4
- [ ] On-chip reward computation (end-to-end learning)
- [ ] Multi-agent coordination
- [ ] Formal verification proofs

### V5
- [ ] ASIC synthesis (TSMC 28nm)
- [ ] FPGA deployment (Xilinx Alveo)
- [ ] Real-world NLP/Vision benchmarks

---

## References

1. Hebb, D.O. (1949). *The Organization of Behavior*. McGraw-Hill.
2. Watkins, C.J.C.H. (1989). *Learning from Delayed Rewards*. PhD Thesis.
3. Mnih, V. et al. (2015). "Human-level control through deep reinforcement learning". *Nature*.
4. Vaswani, A. et al. (2017). "Attention Is All You Need". *NeurIPS*.

---

## Badges

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![CI/CD Pipeline](https://github.com/silicon-agent/silicon-agent/actions/workflows/ci.yml/badge.svg)](.github/workflows/ci.yml)
[![Formal Verification](https://img.shields.io/badge/Verification-Formal-blue.svg)](docs/FORMAL_VERIFICATION.md)
[![PyTorch Integration](https://img.shields.io/badge/Integration-PyTorch-red.svg)](scripts/pytorch_bridge/README.md)

---

## Quick Links

- [📚 Documentation](docs/) - Simulation guide, theory, and improvements
- [🔬 Formal Verification](docs/FORMAL_VERIFICATION.md) - SVA assertions and formal proofs
- [🧠 PyTorch Bridge](scripts/pytorch_bridge/README.md) - Use as custom layer in neural networks
- [⚙️ FPGA Constraints](constraints/) - Xilinx and Synopsys constraint files
- [📊 Results](results/) - Convergence plots and architecture diagrams

---

## Contributing

We welcome contributions! Please see our [Contributing Guide](CONTRIBUTING.md) for details.

### Areas for Contribution

1. **PyTorch/TensorFlow Integration** - Improve the co-simulation bridge
2. **Formal Verification** - Add more SVA properties and formal proofs
3. **FPGA Implementation** - Test on real hardware and report results
4. **Performance Optimization** - Improve timing, area, or power efficiency
5. **Documentation** - Add tutorials, examples, or API documentation

---

## Citation

If you use Silicon Agent in your research, please cite:

```bibtex
@misc{silicon_agent_2024,
  title={Silicon Agent: Closed-Loop Neuromorphic Attention System},
  author={Silicon Agent Contributors},
  year={2024},
  publisher={GitHub},
  url={https://github.com/silicon-agent/silicon-agent}
}
```

---

**License:** MIT - See [LICENSE](LICENSE) file for details  
**Author:** Silicon Agent Architecture Team  
**Version:** 1.0.0
