from __future__ import annotations

import numpy as np

from software.quantizer import get_compression_stats, quantize_symmetric, svd_full


def test_low_rank_near_100_percent():
    rng = np.random.RandomState(0)
    m = rng.randn(4, 2) @ rng.randn(2, 4)
    _, s, _ = svd_full(m)
    stats = get_compression_stats(s, k=2)
    assert stats["variance_retained"] > 0.99
    assert stats["n_singular"] == 4


def test_full_rank_not_always_100():
    rng = np.random.RandomState(1)
    m = rng.randn(8, 8)
    _, s, _ = svd_full(m)
    stats = get_compression_stats(s, k=2)
    assert stats["variance_retained"] < 0.99
    assert 0.15 < stats["variance_retained"] < 0.85


def test_int8_roundtrip_small():
    rng = np.random.RandomState(2)
    W = rng.randn(4, 4).astype(np.float32)
    q, scale = quantize_symmetric(W, 8)
    assert q.dtype == np.int8
    assert scale > 0
