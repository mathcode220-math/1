from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def main() -> None:
    target = sys.argv[1] if len(sys.argv) > 1 else ""
    print(f"impact for {target}: run make verify after edits; see contracts/ and evidence/claims.yaml")


if __name__ == "__main__":
    main()
