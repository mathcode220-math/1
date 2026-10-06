"""Two-layer Linear+ReLU on one systolic array with on-chip Q24 requantize."""

from __future__ import annotations

import json
import shutil
import struct
import subprocess
import time
from pathlib import Path

import numpy as np

from software.hexio import read_hex_signed, write_hex_int32, write_hex_int8
from software.quantizer import quantize_symmetric

ROOT = Path(__file__).resolve().parents[1]
RTL = ROOT / "rtl"
BUILD = ROOT / "build" / "two_layer"
GOLD = ROOT / "tests" / "golden" / "two_layer_4x4"
RESULTS = ROOT / "results"
N = 4
SEED = 42
ERROR_LIMIT = 0.05
WARN_LIMIT = 0.10


def max_rel(a, b) -> float:
    a = np.asarray(a, dtype=np.float64)
    b = np.asarray(b, dtype=np.float64)
    denom = max(float(np.max(np.abs(b))), 1e-12)
    return float(np.max(np.abs(a - b)) / denom)


def write_f32_hex(value: float, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    bits = struct.unpack(">I", struct.pack(">f", np.float32(value)))[0]
    path.write_text(f"{bits:08X}\n")


def requant_q24(acc: np.ndarray, ratio_q24: int) -> np.ndarray:
    prod = acc.astype(np.int64) * np.int64(ratio_q24)
    half = np.int64(1 << 23)
    rr = np.where(prod >= 0, (prod + half) >> 24, (prod - half) >> 24)
    return np.clip(rr, -127, 127).astype(np.int8)


def prepare(seed: int = SEED, n: int = N) -> dict:
    rng = np.random.RandomState(seed)
    W1 = rng.randn(n, n).astype(np.float32)
    b1 = rng.randn(n).astype(np.float32)
    W2 = rng.randn(n, n).astype(np.float32)
    b2 = rng.randn(n).astype(np.float32)
    x = rng.randn(n).astype(np.float32)
    h_ref = np.maximum(x @ W1 + b1, 0.0).astype(np.float32)
    y_ref = np.maximum(h_ref @ W2 + b2, 0.0).astype(np.float32)

    W1q, s1 = quantize_symmetric(W1, 8)
    xq, sx = quantize_symmetric(x.reshape(1, -1), 8)
    xq = xq.reshape(-1)
    p1 = float(s1) * float(sx)
    b1_acc = np.round(b1 / p1).astype(np.int32)
    h_int = np.maximum(xq.astype(np.int32) @ W1q.astype(np.int32) + b1_acc, 0).astype(np.int32)
    h_fp = h_int.astype(np.float32) * np.float32(p1)

    W2q, s2w = quantize_symmetric(W2, 8)
    _, sh = quantize_symmetric(h_fp.reshape(1, -1), 8)
    ratio = 0.0 if float(sh) == 0 else (p1 / float(sh))
    ratio_q24 = np.int32(np.round(ratio * (1 << 24)))
    hq = requant_q24(h_int, int(ratio_q24))
    p2 = float(s2w) * float(sh)
    b2_acc = np.round(b2 / p2).astype(np.int32)
    y_int = np.maximum(hq.astype(np.int32) @ W2q.astype(np.int32) + b2_acc, 0).astype(np.int32)
    y_hat = y_int.astype(np.float32) * np.float32(p2)

    GOLD.mkdir(parents=True, exist_ok=True)
    RESULTS.mkdir(parents=True, exist_ok=True)
    write_hex_int8(W1q, GOLD / "weights1.hex")
    write_hex_int8(W2q, GOLD / "weights2.hex")
    write_hex_int8(xq, GOLD / "input.hex")
    write_hex_int32(b1_acc, GOLD / "bias1.hex")
    write_hex_int32(b2_acc, GOLD / "bias2.hex")
    write_f32_hex(p1, GOLD / "scale1.hex")
    write_f32_hex(sh, GOLD / "scale2.hex")
    write_hex_int32(np.array([ratio_q24], dtype=np.int32), GOLD / "ratio_q24.hex")
    return {
        "y_ref": y_ref,
        "y_int": y_int,
        "y_hat": y_hat,
        "p2": p2,
        "sw_max_rel": max_rel(y_hat, y_ref),
    }


def simulate(out_hex: Path, out_cyc: Path) -> dict:
    BUILD.mkdir(parents=True, exist_ok=True)
    sources = [
        str(RTL / "systolic_array_param.sv"),
        str(RTL / "relu_activation.sv"),
        str(RTL / "linear_relu_2layer.sv"),
        str(RTL / "tb" / "tb_linear_relu_2layer.sv"),
    ]
    plus = [
        f"+weights1={GOLD / 'weights1.hex'}",
        f"+weights2={GOLD / 'weights2.hex'}",
        f"+input={GOLD / 'input.hex'}",
        f"+bias1={GOLD / 'bias1.hex'}",
        f"+bias2={GOLD / 'bias2.hex'}",
        f"+scale1={GOLD / 'scale1.hex'}",
        f"+scale2={GOLD / 'scale2.hex'}",
        f"+ratio={GOLD / 'ratio_q24.hex'}",
        f"+out_hex={out_hex}",
        f"+out_cyc={out_cyc}",
    ]
    if not shutil.which("verilator"):
        return {"ok": False, "log": "no verilator"}
    obj = BUILD / "obj"
    cmd = [
        "verilator", "--binary", "--timing",
        "--top-module", "tb_linear_relu_2layer",
        "-Mdir", str(obj),
        "-Wno-fatal", "-Wno-DECLFILENAME", "-Wno-UNUSEDSIGNAL", "-Wno-WIDTH",
        "--timescale", "1ns/1ps",
        *sources,
    ]
    t0 = time.perf_counter()
    proc = subprocess.run(cmd, cwd=ROOT, text=True, capture_output=True)
    (BUILD / "compile.log").write_text(proc.stdout + "\n" + proc.stderr)
    if proc.returncode != 0:
        return {"ok": False, "log": proc.stderr[-2500:]}
    runp = subprocess.run([str(obj / "Vtb_linear_relu_2layer"), *plus], cwd=ROOT, text=True, capture_output=True)
    dt = time.perf_counter() - t0
    (BUILD / "run.log").write_text(runp.stdout + "\n" + runp.stderr)
    if not out_hex.exists():
        return {"ok": False, "log": runp.stdout + runp.stderr, "seconds": dt}
    cycles = int(out_cyc.read_text().strip()) if out_cyc.exists() else None
    return {"ok": True, "cycles": cycles, "seconds": dt, "y": read_hex_signed(out_hex, 32).tolist()}


def run() -> dict:
    prep = prepare()
    out_hex = RESULTS / "rtl_output_2layer.hex"
    out_cyc = RESULTS / "rtl_cycles_2layer.txt"
    sim = simulate(out_hex, out_cyc)
    if not sim.get("ok"):
        payload = {
            "result": "refuted",
            "verified_on_rtl": False,
            "reason": "two-layer RTL sim failed",
            "sim": sim,
        }
        (RESULTS / "multi_layer.json").write_text(json.dumps(payload, indent=2) + "\n")
        return payload
    y_rtl = np.array(sim["y"], dtype=np.int32)
    exact = bool(np.array_equal(y_rtl, prep["y_int"]))
    y_rtl_fp = y_rtl.astype(np.float32) * np.float32(prep["p2"])
    err = max_rel(y_rtl_fp, prep["y_ref"])
    mae = float(np.mean(np.abs(y_rtl.astype(np.float64) - prep["y_int"].astype(np.float64))))
    result = "verified" if exact and err < ERROR_LIMIT else ("partial" if err < WARN_LIMIT else "refuted")
    payload = {
        "result": result,
        "verified_on_rtl": bool(exact and err < ERROR_LIMIT),
        "bit_exact_vs_int_golden": exact,
        "mae_int": mae,
        "max_relative_error": err,
        "sw_max_rel": prep["sw_max_rel"],
        "cycles": sim.get("cycles"),
        "y_ref": prep["y_ref"].tolist(),
        "y_int": prep["y_int"].tolist(),
        "y_rtl_int": y_rtl.tolist(),
    }
    (RESULTS / "multi_layer.json").write_text(json.dumps(payload, indent=2) + "\n")
    return payload
