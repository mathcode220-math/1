# AGENTS

Standalone quantized Linear+ReLU core. No Pocket-LLM import. No `external/` submodules.

## Do

- Keep INT8 W/x and INT32 accumulator-scale bias.
- GEMV on systolic row 0. ReLU DATA_WIDTH=32.
- Tiling: GEMV without per-tile ReLU; host-sum INT32; then bias+ReLU.
- Two-layer requantize is Q24 integer shift, not `$bitstoshortreal`.
- DistilBERT safetensors is the LLM INT8 evidence, not SqueezeNet.
- CERN-OHL-W. Do not lower numeric gates.

## Do not

- Modify proof-repo `external/` submodules from this tree.
- Claim a 4-bit MAC.
- Claim a full LLM (tokenizer / KV / attention / LM head).
- Mix proof-repo generated hex/npz into this tree unless regenerated here.
- Fake tiling by applying ReLU on each 4x4 tile.

## Commands

- `make all` — generate, INT8 compress, 4x4 RTL, compare, report
- `make two-layer` — Q24 two-layer RTL pytest
- `make verify` — claims.yaml evidence paths
- `python3 experiments/tiling_test.py`
- `python3 experiments/q24_range_analysis.py`
