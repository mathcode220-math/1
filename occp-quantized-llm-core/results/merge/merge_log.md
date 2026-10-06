# Merge log

Date: 2026-09-22
Target: `/workspace/occp-quantized-llm-core/` (separate folder, self-contained)

1. Copied KEEP RTL into `rtl/` (systolic_array_param, relu, linear_relu*, gemv, tb).
2. Standalone `software/` (no Pocket-LLM import, no `external/`).
3. Tests: unit quantizer/pipeline, integration two-layer, regression LIMITATIONS.
4. Contracts: numeric_gates, rtl_interfaces, merge_keep_drop.
5. Docs: LIMITATIONS G001/G002, README, AGENTS, manifest, claims, LICENSE CERN-OHL-W.
6. Q24 analysis: DistilBERT q/v/ffn |y_int| max 81803 < 2^20; Q24 sufficient with margin.
7. Tiling GEMV (no per-tile ReLU): 16/32/64 bit-exact 11 cyc/tile; 32/32 sampled 768 tiles; full-layer estimate 116.9s.
8. `make all` rc=0: y_int [0,16821,11974,8049], 11 cycles, INT MAE=0, FP max_rel 1.38%; two-layer 24 cycles MAE=0.
9. pytest 7 passed; `tools/verify.py --check-claims` ok.
10. Wrote `MERGE_COMPLETE.md`.
