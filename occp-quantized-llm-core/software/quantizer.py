"""Standalone symmetric integer quantizer. No Pocket-LLM import."""

from __future__ import annotations

import numpy as np


def quantize_symmetric(matrix: np.ndarray, bits: int = 8):
    bits = int(bits)
    qmin = -(1 << (bits - 1))
    qmax = (1 << (bits - 1)) - 1
    x = np.asarray(matrix, dtype=np.float32)
    max_val = float(np.max(np.abs(x))) if x.size else 0.0
    if max_val == 0.0:
        q = np.zeros_like(x, dtype=np.int8 if bits <= 8 else np.int16)
        return q, 1.0
    scale = max_val / float(qmax)
    q = np.clip(np.round(x / scale), qmin, qmax)
    if bits <= 8:
        q = q.astype(np.int8)
    else:
        q = q.astype(np.int16)
    return q, float(scale)


def dequantize(q: np.ndarray, scale: float) -> np.ndarray:
    return q.astype(np.float32) * np.float32(scale)


def get_compression_stats(singular_values: np.ndarray, k: int) -> dict:
    s = np.asarray(singular_values, dtype=np.float64).reshape(-1)
    if s.size == 0:
        raise ValueError("empty singular values")
    k = int(max(0, min(k, s.size)))
    total_var = float(np.sum(s ** 2))
    retained = 1.0 if (total_var <= 0 and k > 0) else (
        0.0 if total_var <= 0 else float(np.sum(s[:k] ** 2) / total_var)
    )
    return {
        "k": k,
        "n_singular": int(s.size),
        "total_var": total_var,
        "retained_var": float(np.sum(s[:k] ** 2)),
        "variance_retained": retained,
        "variance_retained_percent": retained * 100.0,
        "naive_rank_fraction": (k / s.size) if s.size else 0.0,
    }


def svd_full(matrix: np.ndarray):
    u, s, vt = np.linalg.svd(np.asarray(matrix, dtype=np.float64), full_matrices=False)
    return u, s, vt
