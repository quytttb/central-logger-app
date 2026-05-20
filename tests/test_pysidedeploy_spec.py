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
    assert "project_file = pyproject.toml" in text


def test_pyproject_has_pyside6_project_tool():
    pyproject = Path(__file__).resolve().parents[1] / "pyproject.toml"
    text = pyproject.read_text(encoding="utf-8")
    assert "[tool.pyside6-project]" in text
    assert "src/central_logger/main.py" in text
