"""Smoke integration: controller lifecycle + optional QML load (headless)."""
from __future__ import annotations

import json
from pathlib import Path

import pytest
from PySide6.QtCore import QUrl
from PySide6.QtQml import QQmlApplicationEngine

from central_logger.controllers.dashboard_controller import DashboardController
from central_logger.db import get_session, init_db
from central_logger.db import session as db_session
from central_logger.viewmodels.logger_list_model import LoggerListModel


@pytest.fixture
def fresh_db(tmp_path, monkeypatch):
    url = f"sqlite:///{tmp_path}/smoke.db"
    monkeypatch.setenv("CENTRAL_LOGGER_DB_URL", url)
    db_session._engine = None  # noqa: SLF001
    init_db()
    yield
    db_session._engine = None  # noqa: SLF001


def test_controller_start_stop_lifecycle(qtbot, fresh_db):
  """Dashboard start/stop without crash; modbus thread tears down."""
  model = LoggerListModel()
  ctrl = DashboardController()
  ctrl.model = model
  with qtbot.waitSignal(ctrl.started, timeout=5000):
    ctrl.start()
  assert ctrl._running  # noqa: SLF001
  with qtbot.waitSignal(ctrl.stopped, timeout=10000):
    ctrl.stop()
  assert not ctrl._running  # noqa: SLF001


def test_controller_crud_and_charts(qtbot, fresh_db):
  model = LoggerListModel()
  ctrl = DashboardController()
  ctrl.model = model
  ctrl.start()
  qtbot.wait(50)
  ctrl.addLogger("Smoke A", "127.0.0.1", 5020, 1, 2, 8080, "", True, 2.0, "", "")
  with get_session() as session:
    from sqlmodel import select

    from central_logger.db import LoggerInfo

    rows = list(session.exec(select(LoggerInfo)).all())
  assert len(rows) == 1
  lid = rows[0].id
  assert lid is not None
  ingest = json.loads(ctrl.getIngestionChart24h())
  buckets = ingest.get("buckets", ingest)
  assert len(buckets) == 288
  poll = json.loads(ctrl.getSensorTrendingPollChart(lid, 10))
  assert poll["mode"] == "poll"
  ctrl.removeLogger(lid)
  ctrl.stop()


def test_cache_sensors_rest_readings_hook(qtbot, fresh_db):
  """Regression: request_readings must use keyword force= (REST coordinator)."""
  model = LoggerListModel()
  ctrl = DashboardController()
  ctrl.model = model
  ctrl._sensors.sensor_catalog[1] = [  # noqa: SLF001
      {
          "sensor_id": 1,
          "name": "S1",
          "unit": "",
          "sensor_type": "AI",
          "active": True,
      }
  ]
  calls: list[tuple[int, bool]] = []

  def _hook(lid: int, *, force: bool = False) -> None:
    calls.append((lid, force))

  ctrl._sensors.set_rest_hooks(lambda _: None, _hook)  # noqa: SLF001

  class _Hdr:
    timestamp = 0
    polling = True
    rtu_connected = True
    any_alarm = False

  class _Snap:
    header = _Hdr()
    sensors = []

  ctrl._sensors.cache_sensors(1, _Snap())  # noqa: SLF001
  assert calls == [(1, False)]


@pytest.mark.skipif(
    not (Path(__file__).resolve().parents[1] / "src" / "central_logger" / "ui" / "main.qml").is_file(),
    reason="main.qml missing",
)
def test_qml_main_loads_headless(qtbot):
  """Load main.qml offscreen (QQC2 Material + UiLabel/UiIcon, no native deps)."""
  from central_logger.main import _load_application_fonts, _resolve_qml_root

  engine = QQmlApplicationEngine()
  _load_application_fonts()
  qml_root = _resolve_qml_root()
  engine.addImportPath(str(qml_root))
  engine.load(QUrl.fromLocalFile(str(qml_root / "main.qml")))
  qtbot.wait(200)
  assert engine.rootObjects(), "main.qml failed to load"
