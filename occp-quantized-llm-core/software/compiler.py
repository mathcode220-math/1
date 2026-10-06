"""HEX export for $readmemh. One signed byte or word per line, row-major."""

from __future__ import annotations

from pathlib import Path

import numpy as np

from software.hexio import write_hex_int8, write_hex_int32


def export_hex_int8(values: np.ndarray, path: Path) -> None:
    write_hex_int8(values, path)


def export_hex_int32(values: np.ndarray, path: Path) -> None:
    write_hex_int32(values, path)
