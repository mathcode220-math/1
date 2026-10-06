from __future__ import annotations

from pathlib import Path

import numpy as np


def write_hex_int8(values: np.ndarray, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "w") as f:
        for v in np.asarray(values).reshape(-1).astype(np.int8):
            f.write(f"{int(v) & 0xFF:02X}\n")


def write_hex_int32(values: np.ndarray, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "w") as f:
        for v in np.asarray(values).reshape(-1).astype(np.int32):
            f.write(f"{int(v) & 0xFFFFFFFF:08X}\n")


def read_hex_signed(path: Path, bits: int) -> np.ndarray:
    mask = (1 << bits) - 1
    sign = 1 << (bits - 1)
    out = []
    with open(path) as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("//") or line.startswith("#"):
                continue
            raw = int(line, 16) & mask
            if raw & sign:
                raw -= 1 << bits
            out.append(raw)
    return np.array(out, dtype=np.int64)
