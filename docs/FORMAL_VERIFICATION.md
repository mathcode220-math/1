# Formal Verification Properties for Silicon Agent

## Overview
This document describes the formal verification properties for the Silicon Agent project.
These properties can be verified using tools like SymbiYosys, JasperGold, or Cadence VC Formal.

## 1. Safety Properties

### 1.1 Bias Bounds Property
**Property:** Bias values must always remain within defined bounds to prevent overflow.

```systemverilog
// Assertion: Bias must stay within min/max limits
property p_bias_bounds;
    @(posedge clk_slow) disable iff (!rst_slow_n)
    forall (int i = 0; i < NUM_TOKENS; i++)
        (bias[i] >= BIAS_MIN) && (bias[i] <= BIAS_MAX);
endproperty

assert property (p_bias_bounds)
    else $error("Bias out of bounds at time %0t", $time);
```

**Formal Verification Command (SymbiYosys):**
```bash
sby -f sby_bias_bounds.sby
```

### 1.2 One-Hot Winner Property
**Property:** Only one token can be selected as the winner at any given time.

```systemverilog
property p_one_hot_winner;
    @(posedge clk_fast) disable iff (!rst_n)
    winner_valid |-> $onehot0(winner_id);
endproperty

assert property (p_one_hot_winner);
```

### 1.3 No Overflow in Q-Value Updates
**Property:** Q-value updates must not cause arithmetic overflow.

```systemverilog
property p_q_no_overflow;
    @(posedge clk_slow) disable iff (!rst_slow_n)
    !q_update_active || (q_value_next inside {[Q_MIN:Q_MAX]});
endproperty

assert property (p_q_no_overflow);
```

## 2. Liveness Properties

### 2.1 Learning Convergence
**Property:** The Q-values must eventually converge after sufficient iterations.

```systemverilog
property p_q_convergence;
    @(posedge clk_slow) disable iff (!rst_slow_n)
    strong (
        (learning_active) |=> 
        eventually ##[1:MAX_ITERATIONS] $stable(q_values[best_token])
    );
endproperty

assert property (p_q_convergence)
    else $warning("Q-values did not converge within expected iterations");
```

**Note:** This is a liveness property requiring bounded model checking.

### 2.2 Eventual Reward Processing
**Property:** Every valid reward signal must eventually be processed.

```systemverilog
property p_reward_processed;
    @(posedge clk_slow) disable iff (!rst_slow_n)
    reward_valid |=> ##[1:10] reward_processed;
endproperty

assert property (p_reward_processed);
```

## 3. Sequential Properties

### 3.1 CDC Handshake Completion
**Property:** Every CDC handshake request must eventually complete.

```systemverilog
property p_cdc_handshake_complete;
    @(posedge clk_dst) disable iff (!rst_dst_n)
    src_req |=> ##[1:CDC_TIMEOUT] dst_ack;
endproperty

assert property (p_cdc_handshake_complete)
    else $error("CDC handshake timeout");
```

### 3.2 FSM State Progression
**Property:** The agent FSM must not get stuck in any state indefinitely.

```systemverilog
property p_fsm_progress;
    @(posedge clk_slow) disable iff (!rst_slow_n)
    (current_state != ST_IDLE) |=> 
    eventually ##[1:MAX_STATE_CYCLES] (current_state != $past(current_state));
endproperty

assert property (p_fsm_progress);
```

## 4. Coverage Properties for Formal Verification

### 4.1 State Coverage
```systemverilog
cover property (@(posedge clk_slow) current_state == ST_IDLE);
cover property (@(posedge clk_slow) current_state == ST_SAMPLE);
cover property (@(posedge clk_slow) current_state == ST_COMPUTE_Q);
cover property (@(posedge clk_slow) current_state == ST_UPDATE);
cover property (@(posedge clk_slow) current_state == ST_CONVERGED);
```

### 4.2 Boundary Coverage
```systemverilog
cover property (@(posedge clk_slow) bias[0] == BIAS_MIN);
cover property (@(posedge clk_slow) bias[0] == BIAS_MAX);
cover property (@(posedge clk_slow) reward == 8'h00);
cover property (@(posedge clk_slow) reward == 8'hFF);
```

## 5. SymbiYosys Configuration File

Create `sby_config.sby`:

```ini
[tasks]
prove_bias_bounds
prove_one_hot
prove_cdc_handshake
cover_fsm_states

[options]
prove_bias_bounds
mode prove
depth 100
timeout 600

prove_one_hot
mode prove
depth 50
timeout 300

prove_cdc_handshake
mode prove
depth 200
timeout 900

cover_fsm_states
mode cover
depth 150
timeout 600

[engines]
smtbmc yosys-smtbmc

[script]
read_verilog -sv src/agent_types.svh
read_verilog -sv src/agent_interfaces.sv
read_verilog -sv src/cdc_synchronizers.sv
read_verilog -sv src/saturation_arithmetic.sv
read_verilog -sv src/config_registers.sv
read_verilog -sv src/performance_counters.sv
read_verilog -sv src/agent_sva.sv
read_verilog -sv src/silicon_agent_closed_loop.sv
read_verilog -sv testbench/silicon_agent_tb.sv
prep -top silicon_agent_tb

[file rules]
src/*.sv
src/*.svh
testbench/*.sv

[assume]
# Assume reset is asserted initially
assume (!rst_n) @ 0
assume (rst_n) @ 1

[assert]
# Import assertions from agent_sva.sv
# Additional formal-specific assertions can be added here

[cover]
# Coverage points for formal verification
```

## 6. Running Formal Verification

### Step 1: Install SymbiYosys
```bash
pip install symbiyosys
# Or use package manager
sudo apt install python3-pip
pip3 install symbiyosys
```

### Step 2: Run Verification
```bash
cd /workspace
sby -f sby_config.sby
```

### Step 3: Review Results
```bash
# Check proof status
cat sby_config.prove_bias_bounds/STATUS
cat sby_config.prove_one_hot/STATUS
cat sby_config.prove_cdc_handshake/STATUS

# View coverage report
cat sby_config.cover_fsm_states/coverage.txt
```

## 7. Expected Results

| Property | Type | Expected Result | Priority |
|----------|------|-----------------|----------|
| p_bias_bounds | Safety | PASS | Critical |
| p_one_hot_winner | Safety | PASS | High |
| p_q_no_overflow | Safety | PASS | Critical |
| p_q_convergence | Liveness | PASS (bounded) | High |
| p_reward_processed | Liveness | PASS | Medium |
| p_cdc_handshake_complete | Sequential | PASS | Critical |
| p_fsm_progress | Sequential | PASS | Medium |

## 8. Debugging Failed Proofs

If a property fails:

1. **Check the counterexample trace:**
   ```bash
   cat sby_config.property_name/trace.vcd
   gtkwave sby_config.property_name/trace.vcd
   ```

2. **Add constraints to narrow the state space:**
   ```systemverilog
   assume property (@(posedge clk) learning_rate < 8'h80);
   ```

3. **Increase proof depth if needed:**
   ```ini
   [options]
   depth 500  # Increase from default
   ```

## 9. Integration with CI/CD

Add formal verification to GitHub Actions:

```yaml
formal-verification:
  name: Formal Verification with SymbiYosys
  runs-on: ubuntu-latest
  
  steps:
  - uses: actions/checkout@v4
  
  - name: Install SymbiYosys
    run: pip install symbiyosys
    
  - name: Install Yosys
    run: sudo apt-get install -y yosys
    
  - name: Run formal verification
    run: make formal_verify
    
  - name: Upload proof results
    uses: actions/upload-artifact@v4
    with:
      name: formal-proof-results
      path: sby_*/
```

## 10. References

- [SymbiYosys Documentation](https://symbiyosys.readthedocs.io/)
- [SystemVerilog Assertions for Formal Verification](https://www.accellera.org/images/downloads/standards/vpi/SVA-LRM.pdf)
- [Formal Verification Best Practices](https://www.chipsalliance.org/formal-verification/)
