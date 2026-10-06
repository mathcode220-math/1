"""Reusable GEMV-4x4 RTL simulator (no ReLU). Compiled once, reused per tile."""

from __future__ import annotations

import shutil
import subprocess
from pathlib import Path

import numpy as np

from software.hexio import read_hex_signed, write_hex_int8

ROOT = Path(__file__).resolve().parents[1]
RTL = ROOT / "rtl"
BUILD = ROOT / "build" / "gemv"
N = 4
_EXE = None


def compile_once() -> Path:
    global _EXE
    if _EXE and _EXE.exists():
        return _EXE
    if not shutil.which("verilator"):
        raise RuntimeError("verilator not found")
    BUILD.mkdir(parents=True, exist_ok=True)
    obj = BUILD / "obj"
    sources = [
        str(RTL / "systolic_array_param.sv"),
        str(RTL / "gemv.sv"),
        str(RTL / "tb" / "tb_gemv.sv"),
    ]
    cmd = [
        "verilator", "--binary", "--timing",
        "--top-module", "tb_gemv",
        "-Mdir", str(obj),
        "-Wno-fatal", "-Wno-DECLFILENAME", "-Wno-UNUSEDSIGNAL", "-Wno-WIDTH",
        "--timescale", "1ns/1ps",
        *sources,
    ]
    proc = subprocess.run(cmd, cwd=ROOT, text=True, capture_output=True)
    (BUILD / "compile.log").write_text(proc.stdout + "\n" + proc.stderr)
    if proc.returncode != 0:
        raise RuntimeError(proc.stderr[-2000:])
    _EXE = obj / "Vtb_gemv"
    return _EXE


def run_tile(W: np.ndarray, x: np.ndarray, tag: str) -> tuple[np.ndarray, int]:
    exe = compile_once()
    tdir = BUILD / "tiles" / tag
    tdir.mkdir(parents=True, exist_ok=True)
    w_hex = tdir / "w.hex"
    x_hex = tdir / "x.hex"
    out_hex = tdir / "y.hex"
    out_cyc = tdir / "c.txt"
    write_hex_int8(W, w_hex)
    write_hex_int8(x, x_hex)
    plus = [
        f"+weights={w_hex}",
        f"+input={x_hex}",
        f"+out_hex={out_hex}",
        f"+out_cyc={out_cyc}",
    ]
    runp = subprocess.run([str(exe), *plus], cwd=ROOT, text=True, capture_output=True)
    if not out_hex.exists():
        raise RuntimeError(runp.stdout + runp.stderr)
    y = read_hex_signed(out_hex, 32)[:N].astype(np.int32)
    cycles = int(out_cyc.read_text().strip()) if out_cyc.exists() else 11
    return y, cycles
