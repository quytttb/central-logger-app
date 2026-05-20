"""Keep pysidedeploy.spec portable across machines (no absolute dev paths)."""

from __future__ import annotations

from pathlib import Path

_SPEC = Path(__file__).resolve().parents[1] / "pysidedeploy.spec"


def test_pysidedeploy_spec_has_no_machine_specific_paths():
    text = _SPEC.read_text(encoding="utf-8")
    assert "/home/" not in text
    assert "haiquy" not in text.lower()
    assert "icon =" in text
    assert "python_path =" in text


def test_pysidedeploy_spec_targets_deploy_output():
    text = _SPEC.read_text(encoding="utf-8")
    assert "exec_directory = deploy" in text
    assert "title = CentralLogger" in text
