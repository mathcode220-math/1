# occp-quantized-llm-core

Standalone INT8 Linear+ReLU core copied from OCCP math_core. CERN-OHL-W.

It is **not** a full LLM on silicon. It runs `N=4 Linear+ReLU` (and two sequential layers with Q24 requantize) on `systolic_array_param`.

## What it proves

- INT8 W/x + INT32 accumulator-scale bias; GEMV on systolic row 0; ReLU DATA_WIDTH=32.
- DistilBERT Linear (q_lin / v_lin / ffn.lin1) INT8 vs FP32 max_rel **3.31%** < 5%.
- RTL N=4/8/16 bit-exact vs integer golden; cycles 11/19/35.
- Two-layer RTL Q24: INT MAE=0, max_rel **0.2501%**, 24 cycles.

## What it does not prove (ما لا يثبته)

- A complete LLM (no tokenizer, no KV cache, no attention, no softmax head).
- 768x768 on one 4x4 array without host tiling.
- 4-bit MAC. INT4 was storage-only and was dropped (3-layer 26.86%).
- IEEE float requantize on chip (`$bitstoshortreal` is invalid here).

See `docs/LIMITATIONS.md` and `MERGE_COMPLETE.md`.

## How to run

```bash
pip install -r requirements.txt
make all
```

```bash
# tiling DistilBERT q_lin through 4x4 GEMV (no per-tile ReLU)
python3 experiments/tiling_test.py

# Q24 range vs DistilBERT Linear layers
python3 experiments/q24_range_analysis.py
```

Requires Python 3.10+, numpy, pytest, Verilator.

## Layout

```
rtl/           KEEP INT8 Linear+ReLU + GEMV (no ReLU for tiling)
software/      standalone quantizer / pipeline / two_layer / sim_gemv
experiments/   tiling_test.py, q24_range_analysis.py
contracts/     numeric gates and KEEP/DROP
docs/          LIMITATIONS
tests/         unit, integration, regression
deprecated/    INT4 / hyperbolic / softmax notes
```

License: CERN-OHL-W v2 (`LICENSE`).
