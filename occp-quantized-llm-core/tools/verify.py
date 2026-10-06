from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[1]


def check_claims() -> int:
    claims_path = ROOT / "evidence" / "claims.yaml"
    data = yaml.safe_load(claims_path.read_text())
    claims = data.get("claims", data)
    missing = []
    unverified = []
    for name, rec in claims.items():
        if not isinstance(rec, dict):
            continue
        ev = rec.get("evidence")
        result = rec.get("result")
        if result == "verified":
            if not ev:
                missing.append((name, "verified without evidence"))
            else:
                p = ROOT / str(ev).split("#")[0]
                if not p.exists():
                    missing.append((name, str(ev)))
        if result == "refuted":
            pass
        if result == "verified" and rec.get("value") is None and rec.get("metric") not in {"bit_exact", None}:
            unverified.append(name)
    if missing:
        print("missing evidence:", missing)
        return 1
    print("claims ok", list(claims))
    return 0


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--all", action="store_true")
    p.add_argument("--check-claims", action="store_true")
    args = p.parse_args()
    if args.check_claims or args.all:
        return check_claims()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
