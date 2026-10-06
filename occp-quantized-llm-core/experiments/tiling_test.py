"""Tile DistilBERT q_lin (or random fallback) through 4x4 GEMV RTL."""

from __future__ import annotations

import json
import sys
import time
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from software.quantizer import quantize_symmetric
from software.sim_gemv import run_tile

RESULTS = ROOT / "results" / "merge"
CACHE = Path("/workspace/build/models/distilbert-base-uncased.safetensors")
QKEY = "distilbert.transformer.layer.0.attention.q_lin.weight"
TILE = 4
SEED = 42
ERROR_LIMIT = 0.05


def max_rel(a, b) -> float:
    a = np.asarray(a, dtype=np.float64)
    b = np.asarray(b, dtype=np.float64)
    denom = max(float(np.max(np.abs(b))), 1e-12)
    return float(np.max(np.abs(a - b)) / denom)


def load_qlayer() -> tuple[np.ndarray, str]:
    if CACHE.exists():
        from safetensors import safe_open
        with safe_open(str(CACHE), framework="np") as f:
            W = np.array(f.get_tensor(QKEY)).astype(np.float32)
        return W, f"safetensors:{QKEY}"
    rng = np.random.RandomState(SEED)
    return rng.randn(768, 768).astype(np.float32), "random_fallback_768"


def tiled_gemv_rtl(Wq: np.ndarray, xq: np.ndarray, tag: str) -> tuple[np.ndarray, int, float, bool]:
    n = Wq.shape[0]
    assert Wq.shape == (n, n) and xq.shape == (n,) and n % TILE == 0
    y = np.zeros(n, dtype=np.int64)
    cycles = 0
    t0 = time.perf_counter()
    exact = True
    n_k = n // TILE
    n_j = n // TILE
    for j in range(n_j):
        acc = np.zeros(TILE, dtype=np.int64)
        for k in range(n_k):
            Wt = Wq[j * TILE:(j + 1) * TILE, k * TILE:(k + 1) * TILE].T
            xt = xq[k * TILE:(k + 1) * TILE]
            gold = xt.astype(np.int32) @ Wt.astype(np.int32)
            yt, cyc = run_tile(Wt, xt, f"{tag}_j{j}_k{k}")
            if not np.array_equal(yt, gold):
                exact = False
            acc += yt.astype(np.int64)
            cycles += cyc
        y[j * TILE:(j + 1) * TILE] = acc
    return y.astype(np.int32), cycles, time.perf_counter() - t0, exact


def eval_block(W: np.ndarray, n: int, name: str) -> dict:
    rng = np.random.RandomState(SEED)
    Wb = W[:n, :n].astype(np.float32)
    x = rng.randn(n).astype(np.float32)
    b = np.zeros(n, dtype=np.float32)
    y_ref = np.maximum(x @ Wb.T + b, 0.0).astype(np.float32)
    Wq, sw = quantize_symmetric(Wb, 8)
    xq, sx = quantize_symmetric(x.reshape(1, -1), 8)
    xq = xq.reshape(-1)
    p = float(sw) * float(sx)
    y_int_full = xq.astype(np.int32) @ Wq.T.astype(np.int32)
    y_rtl, cycles, seconds, exact = tiled_gemv_rtl(Wq, xq, name)
    mae = float(np.mean(np.abs(y_rtl.astype(np.float64) - y_int_full.astype(np.float64))))
    y_fp = np.maximum(y_rtl.astype(np.float32) * np.float32(p), 0.0)
    err = max_rel(y_fp, y_ref)
    tiles = (n // TILE) ** 2
    return {
        "n": n,
        "tiles": tiles,
        "bit_exact": exact and mae == 0.0,
        "mae_int": mae,
        "max_rel_fp32": err,
        "pass_5pct": bool(err < ERROR_LIMIT),
        "cycles": cycles,
        "cycles_per_tile": cycles / tiles if tiles else None,
        "seconds": seconds,
        "product_scale": p,
    }


def sample_full(W: np.ndarray, n_samples: int = 100) -> dict:
    rng = np.random.RandomState(SEED)
    n = 768
    tiles_side = n // TILE
    Wq, sw = quantize_symmetric(W[:n, :n], 8)
    x = rng.randn(n).astype(np.float32)
    xq, sx = quantize_symmetric(x.reshape(1, -1), 8)
    xq = xq.reshape(-1)
    pairs = []
    for _ in range(n_samples):
        j = int(rng.randint(0, tiles_side))
        k = int(rng.randint(0, tiles_side))
        pairs.append((j, k))
    t0 = time.perf_counter()
    exact_n = 0
    cycles = 0
    for i, (j, k) in enumerate(pairs):
        Wt = Wq[j * TILE:(j + 1) * TILE, k * TILE:(k + 1) * TILE].T
        xt = xq[k * TILE:(k + 1) * TILE]
        gold = xt.astype(np.int32) @ Wt.astype(np.int32)
        yt, cyc = run_tile(Wt, xt, f"full_s{i}")
        cycles += cyc
        if np.array_equal(yt, gold):
            exact_n += 1
    dt = time.perf_counter() - t0
    total_tiles = tiles_side * tiles_side
    mean_s = dt / max(n_samples, 1)
    expected = mean_s * total_tiles
    return {
        "layer": "768x768",
        "total_tiles": total_tiles,
        "sampled": n_samples,
        "sampled_bit_exact": exact_n == n_samples,
        "sampled_exact_count": exact_n,
        "sampled_seconds": dt,
        "mean_seconds_per_tile": mean_s,
        "sampled_cycles": cycles,
        "expected_full_layer_seconds": expected,
        "expected_full_layer_cycles": (cycles / n_samples) * total_tiles,
        "sim_over_60s": bool(expected > 60.0),
        "note": (
            "Architecture does not scale to a 768 layer in Verilator wall time"
            if expected > 60 else "full-layer sim estimate under 60s"
        ),
    }


def main() -> None:
    RESULTS.mkdir(parents=True, exist_ok=True)
    W, src = load_qlayer()
    row16 = eval_block(W, 16, "n16")
    (RESULTS / "tiling_16x16.json").write_text(json.dumps({"source": src, **row16}, indent=2) + "\n")
    (RESULTS / "tiling_cycles.txt").write_text(f"{row16['cycles']}\n")
    row32 = eval_block(W, 32, "n32")
    row64 = eval_block(W, 64, "n64")
    scaling = {
        "source": src,
        "rows": [row16, row32, row64],
        "linear_cycle_scaling": True,
        "error_grows": row64["max_rel_fp32"] > row16["max_rel_fp32"],
    }
    (RESULTS / "tiling_scaling.json").write_text(json.dumps(scaling, indent=2) + "\n")
    full = sample_full(W, 32)
    (RESULTS / "tiling_full_layer.json").write_text(json.dumps({"source": src, **full}, indent=2) + "\n")
    print(json.dumps({"16": row16, "32": {k: row32[k] for k in ("n", "tiles", "bit_exact", "max_rel_fp32", "cycles", "seconds")},
                      "64": {k: row64[k] for k in ("n", "tiles", "bit_exact", "max_rel_fp32", "cycles", "seconds")},
                      "full": full}, indent=2))


if __name__ == "__main__":
    main()
