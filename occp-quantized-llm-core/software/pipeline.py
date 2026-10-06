"""INT8 Linear+ReLU proof pipeline. No hyperbolic / Pocket-LLM dependency."""

from __future__ import annotations

import argparse
import json
import time
from pathlib import Path

import numpy as np

from software.hexio import write_hex_int8, write_hex_int32
from software.quantizer import dequantize, quantize_symmetric

ROOT = Path(__file__).resolve().parents[1]
RESULTS = ROOT / "results"
N = 4
SEED = 42
ERROR_LIMIT = 0.05
WEIGHTS_NPZ = RESULTS / "weights.npz"
COMPRESSED_NPZ = RESULTS / "weights_compressed.npz"
REFERENCE_NPY = RESULTS / "reference.npy"


def generate(seed: int = SEED, n: int = N) -> dict:
    np.random.seed(seed)
    W = np.random.randn(n, n).astype(np.float32)
    b = np.random.randn(n).astype(np.float32)
    x = np.random.randn(n).astype(np.float32)
    RESULTS.mkdir(parents=True, exist_ok=True)
    np.savez(WEIGHTS_NPZ, W=W, b=b, x=x, n=np.int32(n), seed=np.int32(seed))
    return {"W": W, "b": b, "x": x}


def reference() -> np.ndarray:
    data = np.load(WEIGHTS_NPZ)
    y_ref = np.maximum(data["x"] @ data["W"] + data["b"], 0.0).astype(np.float32)
    np.save(REFERENCE_NPY, y_ref)
    return y_ref


def _rel(a, b) -> float:
    denom = max(float(np.max(np.abs(b))), 1e-12)
    return float(np.max(np.abs(np.asarray(a) - np.asarray(b))) / denom)


def compress() -> dict:
    data = np.load(WEIGHTS_NPZ)
    W = data["W"].astype(np.float32)
    b = data["b"].astype(np.float32)
    x = data["x"].astype(np.float32)
    W_q, scale_w = quantize_symmetric(W, 8)
    x_q, scale_x = quantize_symmetric(x.reshape(1, -1), 8)
    x_q = x_q.reshape(-1)
    product_scale = float(scale_w) * float(scale_x)
    b_acc = np.round(b / product_scale).astype(np.int32)
    y_ref = np.maximum(x @ W + b, 0.0).astype(np.float32)
    y_w_only = np.maximum(x @ dequantize(W_q, scale_w) + b, 0.0).astype(np.float32)
    y_int = np.maximum(x_q.astype(np.int32) @ W_q.astype(np.int32) + b_acc, 0).astype(np.int32)
    y_full_q = y_int.astype(np.float32) * np.float32(product_scale)
    err_w = _rel(y_w_only, y_ref)
    err_full = _rel(y_full_q, y_ref)
    np.savez(
        COMPRESSED_NPZ,
        W=W, b=b, x=x, W_q=W_q, x_q=x_q, b_q=b_acc, b_acc=b_acc,
        scale_w=np.float32(scale_w), scale_x=np.float32(scale_x),
        product_scale=np.float32(product_scale),
        y_ref=y_ref, y_w_only=y_w_only, y_full_q=y_full_q, y_int=y_int,
    )
    stats = {
        "scale_w": float(scale_w),
        "scale_x": float(scale_x),
        "product_scale": product_scale,
        "err_weight_only_max_rel": err_w,
        "err_full_quant_max_rel": err_full,
        "error_limit": ERROR_LIMIT,
        "weight_only_pass": bool(err_w <= ERROR_LIMIT),
        "full_quant_pass": bool(err_full <= ERROR_LIMIT),
        "bias_storage": "int32_accumulator_scale",
    }
    (RESULTS / "compress_stats.json").write_text(json.dumps(stats, indent=2) + "\n")
    if err_w > ERROR_LIMIT:
        raise SystemExit(f"compression error {err_w:.4%} > 5%")
    return stats


def export() -> None:
    data = np.load(COMPRESSED_NPZ)
    write_hex_int8(data["W_q"], RESULTS / "weights.hex")
    write_hex_int8(data["x_q"], RESULTS / "input.hex")
    write_hex_int32(data["b_q"], RESULTS / "bias.hex")


def report() -> None:
    path = RESULTS / "report.md"
    if not path.exists():
        raise SystemExit("missing results/report.md; run compare first")


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("cmd", choices=["generate", "reference", "compress", "export", "report"])
    args = p.parse_args()
    if args.cmd == "generate":
        generate()
        print(f"Wrote {WEIGHTS_NPZ}")
    elif args.cmd == "reference":
        y = reference()
        print("y_ref =", y)
    elif args.cmd == "compress":
        print(json.dumps(compress(), indent=2))
    elif args.cmd == "export":
        export()
        print("Wrote HEX")
    else:
        report()


if __name__ == "__main__":
    main()
