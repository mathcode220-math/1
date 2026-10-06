# Inventory to merge

KEEP RTL: systolic_array_param, relu_activation, linear_relu, linear_relu_4x4, linear_relu_2layer, gemv.

KEEP software: quantizer, hexio, compiler, pipeline, run_sim, compare, two_layer, sim_gemv.

KEEP experiments: tiling_test (GEMV no per-tile ReLU), q24_range_analysis.

DROP: hyperbolic, softmax, INT4 compute, open_cognitive_top, Pocket-LLM import, SqueezeNet-as-LLM.

HOLD: 768x768 full Verilator, host-computed Q24 ratio.

Evidence copied: onnx_test.json, rtl_scaling.json, multi_layer.json, int4_accumulation.json, PRE_MERGE_REPORT_v2.md.
