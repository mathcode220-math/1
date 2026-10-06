from __future__ import annotations

import json
from pathlib import Path

from software.two_layer import run

ERROR_LIMIT = 0.05
ROOT = Path(__file__).resolve().parents[2]


def test_two_layer_rtl_bit_exact_and_under_5pct():
    payload = run()
    path = ROOT / "results" / "multi_layer.json"
    assert path.exists()
    dumped = json.loads(path.read_text())
    assert dumped["verified_on_rtl"] is True
    assert dumped["bit_exact_vs_int_golden"] is True
    assert dumped["mae_int"] == 0.0
    assert dumped["max_relative_error"] < ERROR_LIMIT
    hex_path = ROOT / "results" / "rtl_output_2layer.hex"
    assert hex_path.exists()
    lines = [ln for ln in hex_path.read_text().splitlines() if ln.strip()]
    assert len(lines) == 4
    assert payload["result"] == "verified"
