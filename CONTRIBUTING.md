# Contributing to Silicon Agent

Thank you for your interest in contributing to Silicon Agent! This document provides guidelines and instructions for contributing.

## Table of Contents

1. [Code of Conduct](#code-of-conduct)
2. [Getting Started](#getting-started)
3. [How to Contribute](#how-to-contribute)
4. [Development Setup](#development-setup)
5. [Coding Standards](#coding-standards)
6. [Testing](#testing)
7. [Pull Request Process](#pull-request-process)
8. [Documentation](#documentation)

---

## Code of Conduct

- Be respectful and inclusive
- Focus on constructive feedback
- Welcome newcomers and help them learn
- Keep discussions professional and on-topic

---

## Getting Started

1. **Fork the repository** on GitHub
2. **Clone your fork** locally:
   ```bash
   git clone https://github.com/YOUR_USERNAME/silicon-agent.git
   cd silicon-agent
   ```
3. **Add the upstream remote**:
   ```bash
   git remote add upstream https://github.com/ORIGINAL_OWNER/silicon-agent.git
   ```
4. **Create a branch** for your feature:
   ```bash
   git checkout -b feature/your-feature-name
   ```

---

## How to Contribute

### Types of Contributions We Welcome

#### 1. Bug Fixes
- Report bugs using GitHub Issues
- Include steps to reproduce, expected vs actual behavior
- Submit PRs with fixes referencing the issue number

#### 2. New Features
- Propose features via GitHub Issues first
- Discuss implementation approach
- Implement with tests and documentation

#### 3. Documentation Improvements
- Fix typos or unclear explanations
- Add examples or tutorials
- Improve API documentation

#### 4. Performance Optimizations
- Profile code before optimizing
- Provide benchmarks showing improvement
- Ensure correctness is maintained

#### 5. Hardware Integration
- Test on FPGA boards
- Provide synthesis results
- Share timing reports and resource utilization

#### 6. PyTorch/TensorFlow Integration
- Improve co-simulation bridge
- Add new layer types
- Create example notebooks

---

## Development Setup

### Prerequisites

```bash
# SystemVerilog tools
sudo apt-get install iverilog verilator gtkwave

# Python dependencies
pip install -r requirements.txt

# Optional: Formal verification
pip install symbiyosys

# Optional: PyTorch integration
pip install torch cocotb pyverilator
```

### Running Tests

```bash
# Basic compilation
make compile

# Run simulation
make sim

# Run with coverage
make verify_modular

# Run formal verification (optional)
make formal_verify
```

---

## Coding Standards

### SystemVerilog Style Guide

#### File Organization
```systemverilog
// Copyright notice
// Module description
// Parameters
// Ports
// Internal signals
// Always blocks (comb then ff)
// Functions and tasks
// Assertions
```

#### Naming Conventions
- **Modules**: `snake_case` (e.g., `cdc_synchronizer`)
- **Parameters**: `UPPER_CASE` (e.g., `NUM_TOKENS`)
- **Signals**: `snake_case` (e.g., `clk_fast`, `rst_n`)
- **Types**: `snake_case_e` for enums (e.g., `agent_state_e`)
- **Interfaces**: `snake_case_if` (e.g., `agent_if`)

#### Example Module Template
```systemverilog
module my_module #(
    parameter int DATA_WIDTH = 16,
    parameter int ADDR_WIDTH = 8
) (
    input  logic                    clk,
    input  logic                    rst_n,
    input  logic [DATA_WIDTH-1:0]   data_in,
    output logic [DATA_WIDTH-1:0]   data_out
);

    // Local parameters
    localparam int MAX_COUNT = 2**ADDR_WIDTH;
    
    // Internal signals
    logic [ADDR_WIDTH-1:0] counter;
    
    // Combinational logic
    always_comb begin
        // Implementation
    end
    
    // Sequential logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset values
        end else begin
            // Normal operation
        end
    end
    
    // Assertions
    assert property (@(posedge clk) data_out <= MAX_VALUE);
    
endmodule
```

### Python Style Guide

- Follow [PEP 8](https://pep8.org/)
- Use type hints
- Include docstrings (Google style)
- Maximum line length: 100 characters

Example:
```python
def compute_reward(winner_id: int, target: int, max_reward: int = 255) -> int:
    """
    Compute reward signal based on winner selection.
    
    Args:
        winner_id: ID of selected token
        target: Target token ID
        max_reward: Maximum reward value
        
    Returns:
        Reward value between 0 and max_reward
    """
    if winner_id == target:
        return max_reward
    else:
        return max_reward // 2
```

---

## Testing

### Test Requirements

All contributions must include:

1. **Unit Tests** - Test individual modules
2. **Integration Tests** - Test module interactions
3. **Regression Tests** - Ensure existing functionality works

### Writing Tests

#### SystemVerilog Testbench
```systemverilog
`timescale 1ns/1ps

module my_module_tb;
    // Parameters
    localparam int NUM_TESTS = 10;
    
    // Signals
    logic clk, rst_n;
    logic [15:0] data_in, data_out;
    
    // DUT
    my_module dut (.*);
    
    // Clock generation
    initial clk = 0;
    always #5 clk = ~clk;
    
    // Test sequence
    initial begin
        reset_dut();
        run_tests();
        check_results();
        $finish;
    end
    
    task reset_dut();
        rst_n = 0;
        #20;
        rst_n = 1;
    endtask
    
    task run_tests();
        // Test cases
    endtask
    
    task check_results();
        // Verify outputs
    endtask
    
    // Assertions
    assert property (@(posedge clk) data_out >= 0);
    
endmodule
```

#### Python Test (PyTest)
```python
import pytest
import numpy as np
from silicon_agent_layer import SiliconAgentLayer

def test_agent_layer_forward():
    """Test forward pass through agent layer"""
    layer = SiliconAgentLayer(num_tokens=5)
    evidence = torch.randn(32, 5, 16)
    output, winners = layer(evidence)
    
    assert output.shape == (32, 5, 16)
    assert winners.shape == (32,)
    assert all(0 <= w < 5 for w in winners)

def test_agent_layer_learning():
    """Test Q-learning update"""
    layer = SiliconAgentLayer(learning_rate=0.1)
    # Test learning converges
    # ...
```

### Running Tests

```bash
# Run all tests
make test

# Run specific test
python -m pytest tests/test_agent_layer.py -v

# Run with coverage
coverage run -m pytest
coverage report
```

---

## Pull Request Process

### Before Submitting

1. **Update documentation** - README, API docs, etc.
2. **Add tests** - Ensure all new code is tested
3. **Run CI checks** - Make sure all tests pass
4. **Update changelog** - Document changes

### PR Template

```markdown
## Description
Brief description of changes

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation update

## Testing
- [ ] Unit tests added/updated
- [ ] Integration tests pass
- [ ] Manual testing performed

## Checklist
- [ ] Code follows style guidelines
- [ ] Self-review completed
- [ ] Documentation updated
- [ ] No merge conflicts
- [ ] All tests passing

## Related Issues
Fixes #123
```

### Review Process

1. **Automated Checks** - CI/CD pipeline must pass
2. **Code Review** - At least one maintainer review required
3. **Testing** - Maintainers may run additional tests
4. **Merge** - Squash and merge by maintainer

---

## Documentation

### Documentation Requirements

- **User-facing changes**: Update README and user guides
- **API changes**: Update docstrings and API reference
- **New features**: Add examples and tutorials

### Building Documentation

```bash
cd docs
make html
# Opens docs/_build/html/index.html
```

### Documentation Style

- Use clear, concise language
- Include code examples
- Add diagrams where helpful
- Link to related documentation

---

## Release Process

### Version Numbering

We follow [Semantic Versioning](https://semver.org/):
- **MAJOR**: Breaking changes
- **MINOR**: New features (backward compatible)
- **PATCH**: Bug fixes (backward compatible)

### Release Checklist

- [ ] Update version numbers
- [ ] Update CHANGELOG.md
- [ ] Run all tests
- [ ] Build documentation
- [ ] Create release tag
- [ ] Publish to GitHub Releases
- [ ] Announce on social media

---

## Questions?

- **General questions**: Open a GitHub Discussion
- **Bug reports**: Open a GitHub Issue
- **Feature requests**: Open a GitHub Issue with "enhancement" label
- **Security issues**: Email security@silicon-agent.org

---

Thank you for contributing to Silicon Agent! 🚀
