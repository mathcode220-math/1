"""Compile and run Linear+ReLU 4x4, then two-layer RTL."""

from __future__ import annotations

import shutil
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RTL = ROOT / "rtl"
RESULTS = ROOT / "results"
BUILD = ROOT / "build" / "rtl"


def _run(cmd: list[str]) -> subprocess.CompletedProcess:
    print("+", " ".join(cmd))
    return subprocess.run(cmd, cwd=ROOT, check=False, text=True, capture_output=True)


def run_one(top: str, sources: list[str], extra_plus: list[str] | None = None) -> bool:
    if not shutil.which("verilator"):
        return False
    BUILD.mkdir(parents=True, exist_ok=True)
    obj = BUILD / f"obj_{top}"
    cmd = [
        "verilator", "--binary", "--timing",
        "--top-module", top,
        "-Mdir", str(obj),
        "-Wno-fatal", "-Wno-DECLFILENAME", "-Wno-UNUSEDSIGNAL", "-Wno-WIDTH",
        "--timescale", "1ns/1ps",
        *sources,
    ]
    proc = _run(cmd)
    (obj.parent / f"{top}_compile.log").write_text(proc.stdout + "\n" + proc.stderr)
    if proc.returncode != 0:
        print(proc.stderr[-2000:])
        return False
    exe = obj / f"V{top}"
    t0 = time.time()
    runp = _run([str(exe), *(extra_plus or [])])
    (RESULTS / "sim_seconds.txt").write_text(f"{time.time() - t0:.6f}\n")
    (obj.parent / f"{top}_run.log").write_text(runp.stdout + "\n" + runp.stderr)
    print(runp.stdout)
    return runp.returncode == 0


def main() -> int:
    RESULTS.mkdir(parents=True, exist_ok=True)
    src4 = [
        str(RTL / "systolic_array_param.sv"),
        str(RTL / "relu_activation.sv"),
        str(RTL / "linear_relu_4x4.sv"),
        str(RTL / "tb" / "tb_linear_relu_4x4.sv"),
    ]
    if not run_one("tb_linear_relu", src4):
        print("4x4 RTL sim failed", file=sys.stderr)
        return 1
    print("RTL sim: 4x4 OK")
    from software.two_layer import run as run_two
    two = run_two()
    if not two.get("verified_on_rtl"):
        print("two-layer RTL failed", file=sys.stderr)
        return 1
    print("RTL sim: two-layer OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
