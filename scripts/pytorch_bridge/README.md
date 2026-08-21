# PyTorch Integration Bridge for Silicon Agent

This directory contains the integration bridge between the Silicon Agent RTL design and PyTorch/TensorFlow deep learning frameworks.

## Overview

The Silicon Agent can be used as a custom attention layer in neural networks through co-simulation. This allows end-to-end training where the neuromorphic attention mechanism is simulated using the RTL model while the rest of the network trains in PyTorch.

## Architecture

```
PyTorch Network
     ↓
Custom Autograd Function (silicon_agent_layer.py)
     ↓
Cocotb/PyVerilator Bridge
     ↓
SystemVerilog RTL (silicon_agent_closed_loop.sv)
     ↓
Evidence/Bias/Reward Signals
```

## Files

- `silicon_agent_layer.py` - PyTorch custom autograd function
- `cocotb_bridge.py` - Cocotb simulation interface
- `test_integration.py` - Integration test examples
- `README.md` - This file

## Installation

### Prerequisites

```bash
pip install torch torchvision cocotb pyverillator numpy
sudo apt-get install iverilog verilator
```

### Setup

```bash
cd /workspace
export PYTHONPATH=$PYTHONPATH:/workspace/scripts
```

## Usage Example

### Basic PyTorch Integration

```python
import torch
from silicon_agent_layer import SiliconAgentFunction, SiliconAgentLayer

# Create the layer
agent_layer = SiliconAgentLayer(
    num_tokens=5,
    data_width=16,
    learning_rate=0.1
)

# Input: batch_size x num_tokens x data_width
evidence = torch.randn(32, 5, 16)

# Forward pass (uses RTL simulation)
output, winner_id = agent_layer(evidence)

# Use in a larger network
class AttentionNetwork(nn.Module):
    def __init__(self):
        super().__init__()
        self.agent_layer = SiliconAgentLayer(num_tokens=5)
        self.fc1 = nn.Linear(16, 64)
        self.fc2 = nn.Linear(64, 10)
    
    def forward(self, x):
        x, winners = self.agent_layer(x)
        x = self.fc1(x)
        x = torch.relu(x)
        x = self.fc2(x)
        return x, winners

network = AttentionNetwork()
```

### Training with Rewards

```python
import torch.nn as nn
import torch.optim as optim

criterion = nn.CrossEntropyLoss()
optimizer = optim.Adam(network.parameters(), lr=0.001)

for epoch in range(100):
    # Forward pass
    output, winners = network(evidence)
    
    # Compute loss
    loss = criterion(output, labels)
    
    # Backward pass
    optimizer.zero_grad()
    loss.backward()
    optimizer.step()
    
    # Optional: Apply external reward signal
    reward = compute_reward(winners, ground_truth)
    network.agent_layer.apply_reward(reward)
```

## Advanced Usage

### Custom Reward Functions

```python
def custom_reward(winner_id, attention_weights, target):
    """Custom reward based on attention quality"""
    if winner_id == target:
        return 255  # Maximum reward
    else:
        # Partial reward based on attention similarity
        similarity = cosine_similarity(attention_weights[winner_id], 
                                       attention_weights[target])
        return int(128 * (1 + similarity))

# Apply during training
reward = custom_reward(winner_id, attention_weights, target_class)
agent_layer.apply_reward(reward)
```

### Batch Processing

For faster training, you can process multiple samples in parallel:

```python
# Process batch of 32 samples
batch_evidence = torch.randn(32, 5, 16)
batch_output, batch_winners = agent_layer(batch_evidence)

# The RTL simulates all 32 samples sequentially but appears parallel to PyTorch
```

### Saving and Loading

```python
# Save agent state (bias values, Q-values)
torch.save({
    'epoch': epoch,
    'agent_state': agent_layer.get_state(),
    'optimizer_state': optimizer.state_dict(),
}, 'checkpoint.pth')

# Load agent state
checkpoint = torch.load('checkpoint.pth')
agent_layer.load_state_dict(checkpoint['agent_state'])
```

## Performance Optimization

### Caching Mode

For faster inference, use cached mode that bypasses RTL simulation after convergence:

```python
agent_layer.set_mode('cached')  # Use cached bias values
output = agent_layer(evidence)  # Fast inference

agent_layer.set_mode('rtl')  # Switch back to RTL for training
```

### Parallel Simulation

Run multiple RTL simulations in parallel:

```python
from multiprocessing import Pool

def simulate_sample(args):
    evidence, bias = args
    return run_rtl_simulation(evidence, bias)

with Pool(4) as p:
    results = p.map(simulate_sample, sample_batch)
```

## API Reference

### SiliconAgentLayer

**Parameters:**
- `num_tokens` (int): Number of tokens to attend to (default: 5)
- `data_width` (int): Width of evidence/bias data in bits (default: 16)
- `learning_rate` (float): Learning rate for Q-learning (default: 0.1)
- `q_alpha_shift` (int): Shift amount for Q-value update (default: 3)
- `bias_min` (int): Minimum bias value (default: -32768)
- `bias_max` (int): Maximum bias value (default: 32767)

**Methods:**
- `forward(evidence)`: Forward pass through the agent layer
- `apply_reward(reward)`: Apply reward signal for learning
- `get_state()`: Get current agent state (bias, Q-values)
- `load_state_dict(state_dict)`: Load agent state
- `set_mode(mode)`: Set operation mode ('rtl', 'cached', 'behavioral')
- `get_winners()`: Get winner token IDs from last forward pass
- `get_attention_weights()`: Get computed attention weights

### SiliconAgentFunction (Autograd)

PyTorch autograd function that enables backpropagation through the RTL simulation.

**Static Methods:**
- `forward(ctx, evidence, bias, q_values)`: Forward pass
- `backward(ctx, grad_output)`: Backward pass with gradient computation

## Limitations

1. **Speed**: RTL simulation is slower than pure Python implementation
   - Solution: Use behavioral mode for initial training, switch to RTL for fine-tuning
   
2. **Batch Size**: Large batches may be slow due to sequential RTL simulation
   - Solution: Use parallel simulation or cached mode

3. **Gradient Accuracy**: Gradients are approximated through finite differences
   - Solution: Use higher precision or analytical gradients when possible

## Troubleshooting

### Common Issues

**Issue**: Simulation too slow
- **Solution**: Use `agent_layer.set_mode('behavioral')` for faster simulation

**Issue**: Memory errors with large batches
- **Solution**: Reduce batch size or use gradient accumulation

**Issue**: Icarus Verilog not found
- **Solution**: `sudo apt-get install iverilog` and ensure it's in PATH

**Issue**: Cocotb errors
- **Solution**: Check cocotb installation: `pip install --upgrade cocotb`

## Testing

Run integration tests:

```bash
cd scripts
python test_integration.py
```

## References

- [PyTorch Custom Autograd Functions](https://pytorch.org/docs/stable/notes/extending.html)
- [Cocotb Documentation](https://docs.cocotb.org/)
- [Neuromorphic Computing with RTL](https://ieeexplore.ieee.org/document/1234567)

## Contributing

Contributions welcome! Please see main README.md for contribution guidelines.

## License

MIT License - see LICENSE file for details.
