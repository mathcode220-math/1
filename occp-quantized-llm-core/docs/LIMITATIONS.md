# LIMITATIONS

This tree proves INT8 Linear+ReLU on a 4x4 systolic array. It does not prove an on-chip LLM.

## G001 — DistilBERT 768 tiling

A 768x768 Linear on 4x4 GEMV needs `(768/4)^2 = 36864` tiles.

- Tiling MUST use GEMV without per-tile ReLU.
- Host sums INT32 partials, then applies bias+ReLU once.
- Applying ReLU per tile is incorrect and is not claimed.
- Measured: 16/32/64 tiles bit-exact, 11 cycles/tile, max_rel 0.97%/1.16%/0.99%.
- 32 sampled 768 tiles bit-exact; expected full-layer Verilator ~117s (>60s). Sampled tiles are the RTL evidence.

## G002 — Q24 requantize range

Two-layer on-chip requantize is integer Q24:

`hq = clip((acc * ratio_q24 +/- 2^23) >>> 24, -127, 127)`

- `$bitstoshortreal` is forbidden (Verilator 5.006 promotes shortreal and produced ~22.5% error).
- Ratio = scale1/scale2 is computed in Python and loaded as Q24.
- MAC accumulator is INT32, not Q24.
- Two-layer RTL is proven at N=4 only.

## Not in this repo

- tokenizer, KV cache, attention, decoder softmax, language-model head
- DMA / AXI weight load / compiled SRAM
- INT4 MAC (storage-only nibble unpack was dropped after 26.86% 3-layer error)
- hyperbolic / Mobius SVD as a Linear operator
- SqueezeNet as LLM evidence

## Numeric gates (not lowered)

- INT8 vs FP32: 5%
- two-layer vs FP32: 5% (warn 10%)
- RTL vs integer golden: MAE = 0
