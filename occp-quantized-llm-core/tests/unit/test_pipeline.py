from __future__ import annotations

import json
from pathlib import Path

import numpy as np

from software.pipeline import COMPRESSED_NPZ, ERROR_LIMIT, RESULTS, WEIGHTS_NPZ, compress, export, generate, reference


def test_generate_reference_compress_export():
    generate()
    assert WEIGHTS_NPZ.exists()
    y_ref = reference()
    assert y_ref.shape == (4,)
    stats = compress()
    assert COMPRESSED_NPZ.exists()
    data = np.load(COMPRESSED_NPZ)
    err = float(np.max(np.abs(data["y_w_only"] - y_ref)) / max(float(np.max(np.abs(y_ref))), 1e-12))
    assert err <= ERROR_LIMIT
    export()
    assert (RESULTS / "weights.hex").exists()
    dumped = json.loads((RESULTS / "compress_stats.json").read_text())
    assert dumped["weight_only_pass"] is True
    assert stats["err_weight_only_max_rel"] <= ERROR_LIMIT
