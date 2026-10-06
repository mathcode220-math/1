# deprecated: INT4 compute

Status: **dropped from hardware path** (repair task 2)

Evidence: `results/int4_accumulation.json`

What existed was **INT4 storage, INT8 compute**: nibble load, sign-extend to INT8, then `systolic_array_param` at DATA_WIDTH=8. There is no 4-bit MAC.

Three sequential Linear+ReLU layers with per-layer INT4 requantize, 5 seeds, N=4:

- worst max_rel vs FP32: **26.86%** (>= 15% kill gate)
- mean max_rel: 14.50%
- same stack in INT8: worst **2.42%**

Decision: do not merge INT4 into the unified repo. RTL sources moved to `deprecated/int4_rtl/`.
