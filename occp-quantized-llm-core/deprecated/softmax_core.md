# deprecated: softmax_core

Status: **refuted** (test 7)

Evidence: `results/softmax_test.json`

OCCP `softmax_core.sv` is not a usable language-model softmax:

- LUT `EXP_ROM` hard-codes 16-bit constants for indices 0-15 only; all other indices default to `16'h0001`.
- Domain is integer `x - max` in `[-256, 0]`, not a Q-format logit.
- EXP_ROM only fills indices 0-15; default is 16'h0001. Output is not numpy-softmax (max L1=1.626, mean sum=1.000).

Do not merge `softmax_core` into the unified Linear+ReLU repo. Attention / decoder head remain out of scope.
