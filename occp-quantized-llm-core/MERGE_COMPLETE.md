# MERGE COMPLETE

Date: 2026-09-22
Tree: `/workspace/occp-quantized-llm-core/`
License: CERN-OHL-W v2 (`LICENSE`)
Self-contained: yes (no `external/`, no Pocket-LLM import)

## KEEP (merged)

- `rtl/systolic_array_param.sv` (local OCCP math_core copy)
- `rtl/relu_activation.sv` (DATA_WIDTH=32 in wrappers)
- `rtl/linear_relu.sv`, `rtl/linear_relu_4x4.sv`, `rtl/linear_relu_2layer.sv`
- `rtl/gemv.sv` (no ReLU; tiling host-sum)
- `software/{quantizer,hexio,compiler,pipeline,run_sim,compare,two_layer,sim_gemv}.py`
- DistilBERT INT8 Linear evidence (`results/onnx_test.json`)

## DROP (not merged as compute)

- hyperbolic SVD+Mobius (`deprecated/hyperbolic_projection.md`)
- softmax_core (`deprecated/softmax_core.md`)
- INT4 compute (`deprecated/int4_rtl/`, 3-layer accum 26.86%)
- `open_cognitive_top`
- SqueezeNet as LLM proof

## Gates (not lowered)

| Gate | Limit | Measured |
|---|---|---|
| INT8 vs FP32 | 5% | DistilBERT max_rel 3.31%; N=4 RTL 1.38% |
| two-layer vs FP32 | 5% | 0.2501% |
| RTL vs INT golden | MAE=0 | MAE=0, y_int `[0,16821,11974,8049]`, 11 cycles |
| INT4 kill | >=15% | 26.86% dropped |

## Closed gaps

### G001 tiling (GEMV, no per-tile ReLU)

Source: DistilBERT `q_lin.weight`

| n | tiles | bit-exact | max_rel | cycles | cyc/tile |
|---|---|---|---|---|---|
| 16 | 16 | yes | 0.97% | 176 | 11 |
| 32 | 64 | yes | 1.16% | 704 | 11 |
| 64 | 256 | yes | 0.99% | 2816 | 11 |
| 768 | 36864 | 32/32 sampled | n/a | est. 405504 | 11 |

Full 768 Verilator wall time estimate **116.9s > 60s**. Not claimed as a full-layer on-chip run.

Evidence: `results/merge/tiling_scaling.json`, `results/merge/tiling_full_layer.json`

### G002 Q24

DistilBERT q/v/ffn, 32 inputs, seed=42: max `|y_int|` = **81803 < 2^20**. Q24 sufficient with margin.

Two-layer RTL: INT MAE=0, max_rel 0.2501%, **24 cycles**. Formula `hq=clip((acc*ratio+/-2^23)>>>24,-127,127)`. No `$bitstoshortreal`.

Evidence: `results/merge/q24_analysis.json`, `results/multi_layer.json`

## `make all` in this tree

- unit+regression: 6 passed
- 4x4 RTL: y `[0, 16821, 11974, 8049]`, 11 cycles, INT MAE=0, FP max_rel 1.38%
- two-layer included in `rtl-sim`: verified
- integration+claims: 7 passed; `tools/verify.py --check-claims` ok

## How to reproduce

```bash
cd occp-quantized-llm-core
pip install -r requirements.txt
make all
make two-layer
make verify
python3 experiments/tiling_test.py
python3 experiments/q24_range_analysis.py
```

## What this folder is not

A complete LLM (no tokenizer, KV, attention, softmax head). No 4-bit MAC. No 768x768 single-shot array.
