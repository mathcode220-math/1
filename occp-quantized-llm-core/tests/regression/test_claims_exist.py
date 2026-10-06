from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def test_limitations_mentions_768_gap():
    text = (ROOT / "docs" / "LIMITATIONS.md").read_text()
    assert "768" in text
    assert "4" in text


def test_readme_states_what_is_not_proven():
    text = (ROOT / "README.md").read_text()
    assert "ما لا يثبته" in text or "does not" in text.lower() or "LLM" in text
