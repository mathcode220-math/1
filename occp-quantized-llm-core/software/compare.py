from __future__ import annotations

import json
import time
from pathlib import Path

import numpy as np

from software.hexio import read_hex_signed

ROOT = Path(__file__).resolve().parents[1]
RESULTS = ROOT / "results"
N = 4


def metrics(actual, expected) -> dict:
    diff = np.asarray(actual, dtype=np.float64) - np.asarray(expected, dtype=np.float64)
    denom = np.maximum(np.abs(np.asarray(expected, dtype=np.float64)), 1e-12)
    return {
        "mae": float(np.mean(np.abs(diff))),
        "rmse": float(np.sqrt(np.mean(diff ** 2))),
        "max_abs": float(np.max(np.abs(diff))),
        "max_rel": float(np.max(np.abs(diff) / denom)),
    }


def compare() -> dict:
    y_ref = np.load(RESULTS / "reference.npy").astype(np.float32).reshape(-1)
    data = np.load(RESULTS / "weights_compressed.npz")
    y_int = data["y_int"].astype(np.int64).reshape(-1)
    product_scale = float(data["product_scale"])
    y_rtl_int = read_hex_signed(RESULTS / "rtl_output.hex", 32)[:N]
    y_rtl_fp = y_rtl_int.astype(np.float32) * np.float32(product_scale)
    m_int = metrics(y_rtl_int, y_int)
    m_fp = metrics(y_rtl_fp, y_ref)
    cycles = 11
    cyc = RESULTS / "rtl_cycles.txt"
    if cyc.exists():
        cycles = int(cyc.read_text().strip().split()[0])
    payload = {
        "y_ref_fp32": y_ref.tolist(),
        "y_int_expected": y_int.tolist(),
        "y_rtl_int": y_rtl_int.tolist(),
        "y_rtl_dequant": y_rtl_fp.tolist(),
        "product_scale": product_scale,
        "metrics_rtl_vs_int_golden": m_int,
        "metrics_rtl_vs_fp32": m_fp,
        "cycles": cycles,
        "timestamp": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "n": N,
    }
    (RESULTS / "compare.json").write_text(json.dumps(payload, indent=2) + "\n")
    (RESULTS / "report.md").write_text(
        f"""# تقرير المقارنة الرقمية

تاريخ: {payload['timestamp']}

- N={N} Linear+ReLU INT8
- دورات: {cycles}
- MAE INT: {m_int['mae']}
- max_rel FP32: {m_fp['max_rel']:.4%}

مطابقة INT: {'نجاح' if m_int['max_abs'] < 0.5 else 'فشل'}
"""
    )
    return payload


def main() -> None:
    payload = compare()
    print(json.dumps({
        "metrics_rtl_vs_int_golden": payload["metrics_rtl_vs_int_golden"],
        "metrics_rtl_vs_fp32": payload["metrics_rtl_vs_fp32"],
        "cycles": payload["cycles"],
    }, indent=2))


if __name__ == "__main__":
    main()
