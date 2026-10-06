"""Q24 range vs DistilBERT Linear layers."""

from __future__ import annotations

import json
import sys
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from software.quantizer import quantize_symmetric

RESULTS = ROOT / "results" / "merge"
CACHE = Path("/workspace/build/models/distilbert-base-uncased.safetensors")
SEED = 42
N_INPUTS = 32
KEYS = [
    ("attention.query_proj", "distilbert.transformer.layer.0.attention.q_lin.weight"),
    ("attention.value_proj", "distilbert.transformer.layer.0.attention.v_lin.weight"),
    ("mlp.dense", "distilbert.transformer.layer.0.ffn.lin1.weight"),
]


def load_layers():
    if not CACHE.exists():
        rng = np.random.RandomState(SEED)
        return [
            ("query_random", rng.randn(768, 768).astype(np.float32)),
            ("value_random", rng.randn(768, 768).astype(np.float32)),
            ("mlp_random", rng.randn(3072, 768).astype(np.float32)),
        ], "random_fallback"
    from safetensors import safe_open
    out = []
    with safe_open(str(CACHE), framework="np") as f:
        for alias, key in KEYS:
            out.append((alias, np.array(f.get_tensor(key)).astype(np.float32)))
    return out, "distilbert-base-uncased"


def analyze(name: str, W: np.ndarray, rng: np.random.RandomState) -> dict:
    rows, cols = W.shape
    x = rng.randn(N_INPUTS, cols).astype(np.float32)
    Wq, sw = quantize_symmetric(W, 8)
    xq, sx = quantize_symmetric(x, 8)
    y_int = xq.astype(np.int32) @ Wq.T.astype(np.int32)
    abs_y = int(np.max(np.abs(y_int)))
    bits = int(np.ceil(np.log2(max(abs_y, 1) + 1))) + 1
    return {
        "name": name,
        "shape": [int(rows), int(cols)],
        "max_abs_W": float(np.max(np.abs(W))),
        "scale_w": float(sw),
        "max_abs_x": float(np.max(np.abs(x))),
        "scale_x": float(sx),
        "product_scale": float(sw) * float(sx),
        "max_abs_y_int": abs_y,
        "signed_bits_needed": bits,
        "fits_q24": abs_y < (1 << 24),
        "fits_2_20": abs_y < (1 << 20),
        "q24_headroom_bits": 24 - bits,
    }


def main() -> None:
    RESULTS.mkdir(parents=True, exist_ok=True)
    layers, src = load_layers()
    rng = np.random.RandomState(SEED)
    rows = [analyze(n, W, rng) for n, W in layers]
    max_y = max(r["max_abs_y_int"] for r in rows)
    if all(r["fits_2_20"] for r in rows):
        verdict = "Q24 sufficient with margin (all |y_int| < 2^20)"
        q24_ok = True
    elif all(r["fits_q24"] for r in rows):
        verdict = "Q24 sufficient at the limit (some |y_int| in [2^20, 2^24))"
        q24_ok = True
    else:
        verdict = "Q24 insufficient for at least one layer"
        q24_ok = False
    payload = {
        "source": src,
        "n_inputs": N_INPUTS,
        "rows": rows,
        "max_abs_y_int": max_y,
        "q24_ok": q24_ok,
        "verdict": verdict,
        "note": (
            "Q24 here is the inter-layer requantize ratio, not the MAC accumulator. "
            "MAC uses INT32. Ratio = scale1/scale2 packed as Q24."
        ),
    }
    (RESULTS / "q24_analysis.json").write_text(json.dumps(payload, indent=2) + "\n")
    print(json.dumps({"verdict": verdict, "max_abs_y_int": max_y, "q24_ok": q24_ok, "rows": [
        {k: r[k] for k in ("name", "shape", "max_abs_y_int", "fits_q24", "fits_2_20", "signed_bits_needed")}
        for r in rows
    ]}, indent=2))


if __name__ == "__main__":
    main()
