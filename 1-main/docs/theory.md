# Theory of Q-Guided Hebbian Learning

## Mathematical Foundations

### 1. Problem Statement

Given $N$ tokens with unknown qualities $q_0, q_1, ..., q_{N-1}$, we want to learn a policy that maximizes the expected quality of selected tokens.

**Naive Approach (Hebbian Learning):**
$$\text{bias}_i^{(t+1)} = \text{bias}_i^{(t)} + \eta \cdot r^{(t)} \cdot \mathbb{I}(i = \text{winner})$$

where:
- $\eta$ is the learning rate
- $r^{(t)}$ is the reward at time $t$
- $\mathbb{I}(\cdot)$ is the indicator function

**Problem:** This leads to the "Matthew Effect" - early winners accumulate bias regardless of true quality.

---

### 2. Q-Learning Foundation

We maintain a Q-value for each token representing its estimated quality:

$$Q_i^{(t+1)} = Q_i^{(t)} + \alpha \cdot (r^{(t)} - Q_i^{(t)}) \cdot \mathbb{I}(i = \text{winner})$$

where:
- $\alpha$ is the learning rate (typically $0.125 = 1/8$ for efficient bit-shift implementation)
- $r^{(t)}$ is the observed reward
- $Q_i^{(t)}$ converges to the true quality $q_i$ over time

**Key Insight:** Q-values provide an unbiased estimate of token quality, independent of selection frequency.

---

### 3. Q-Guided Hebbian Update

Our novel contribution combines Q-learning with Hebbian plasticity:

$$\text{bias}_i^{(t+1)} = \text{bias}_i^{(t)} + \eta \cdot \text{sign}(Q_i^{(t)} - \bar{Q}^{(t)}) \cdot \mathbb{I}(i = \text{winner})$$

where:
- $\bar{Q}^{(t)} = \frac{1}{N}\sum_{j=0}^{N-1} Q_j^{(t)}$ is the average Q-value
- $\text{sign}(x) = +1$ if $x > 0$, else $-1$

**Interpretation:**
- If $Q_i > \bar{Q}$: Token $i$ is better than average → increase bias
- If $Q_i < \bar{Q}$: Token $i$ is worse than average → decrease bias

---

### 4. Convergence Analysis

#### Theorem: Asymptotic Optimality

Under Q-Guided Hebbian Learning, the policy converges to selecting the optimal token with probability approaching 1 as $t \to \infty$.

**Proof Sketch:**

1. **Q-value convergence:** By standard stochastic approximation theory, $Q_i^{(t)} \to q_i$ almost surely.

2. **Bias dynamics:** Once Q-values converge, the bias update becomes:
   $$\Delta \text{bias}_i = \eta \cdot \text{sign}(q_i - \bar{q})$$

3. **Stable fixed point:** The system reaches equilibrium when:
   - Optimal token ($q_{\text{max}}$): bias grows until it dominates selection
   - Suboptimal tokens: bias decreases, reducing their selection probability

4. **Exploration-exploitation balance:** Random evidence ensures continued exploration during learning.

---

### 5. Implementation Details

#### Fixed-Point Arithmetic

All computations use fixed-point arithmetic for efficient hardware implementation:

| Signal | Width | Format | Range |
|--------|-------|--------|-------|
| Q-value | 16 bits | Q8.8 | [0, 255] |
| Bias | 16 bits | Q4.12 | [-8, +8] |
| Evidence | 16 bits | Q8.8 | [0, 255] |
| Reward | 8 bits | Q0.8 | [0, 1] |

#### Bit-Shift Optimization

The Q-value update uses $\alpha = 1/8$ for efficient implementation:

```systemverilog
// Q[winner] = Q[winner] + (reward - Q[winner]) / 8
wire signed [15:0] delta = (reward - Q[winner]) >>> 3;
Q[winner] <= Q[winner] + delta;
```

This eliminates the need for a multiplier, reducing area and power.

---

### 6. Hyperparameter Selection

| Parameter | Symbol | Value | Rationale |
|-----------|--------|-------|-----------|
| Q learning rate | $\alpha$ | 0.125 | Power-of-2 for bit-shift |
| Bias learning rate | $\eta$ | 0.1 | Slow enough for stable convergence |
| Exploration noise | $\sigma$ | 0.2 | Ensures adequate exploration |

**Tuning Guidelines:**
- Increase $\eta$ for faster convergence (risk: instability)
- Decrease $\eta$ for more stable learning (risk: slower convergence)
- Adjust $\sigma$ based on evidence variance in your application

---

### 7. Comparison with Alternative Methods

| Method | Convergence Speed | Stability | Hardware Cost |
|--------|------------------|-----------|---------------|
| Naive Hebbian | Fast | Poor (Matthew Effect) | Low |
| ε-Greedy | Medium | Good | Medium |
| **Q-Guided Hebbian** | **Fast** | **Excellent** | **Low** |
| Full Q-Learning | Slow | Excellent | High |
| Policy Gradient | Medium | Good | High |

**Advantage:** Q-Guided Hebbian achieves near-optimal performance with minimal hardware overhead.

---

### 8. Extensions

#### Adaptive Learning Rate

$$\eta^{(t)} = \frac{\eta_0}{1 + \beta \cdot t}$$

Gradually reduces learning rate for finer convergence.

#### Multi-Head Attention

Extend to multiple independent agents, one per attention head:

$$\text{bias}_{h,i}^{(t+1)} = \text{bias}_{h,i}^{(t)} + \eta \cdot \text{sign}(Q_{h,i}^{(t)} - \bar{Q}_h^{(t)}) \cdot \mathbb{I}(i = \text{winner}_h)$$

Each head learns independently, enabling diverse attention patterns.

#### Shared Reward Signal

For tasks with global rewards (e.g., sentence-level loss):

$$r^{(t)} = \text{global\_reward} \cdot \text{local\_contribution}_i$$

Enables credit assignment across tokens.

---

## References

1. Sutton, R.S. & Barto, A.G. (2018). *Reinforcement Learning: An Introduction*. MIT Press.
2. Hebb, D.O. (1949). *The Organization of Behavior*. McGraw-Hill.
3. Watkins, C.J.C.H. (1989). *Learning from Delayed Rewards*. PhD Thesis, Cambridge.
4. Mnih, V. et al. (2015). "Human-level control through deep reinforcement learning". *Nature*, 518(7540), 529-533.
