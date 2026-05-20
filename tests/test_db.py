"""Test DB models bằng SQLite in-memory."""

from __future__ import annotations

import pytest
from sqlmodel import Session, SQLModel, create_engine, select

from central_logger.db import models


@pytest.fixture
def engine():
    eng = create_engine("sqlite:///:memory:", connect_args={"check_same_thread": False})
    SQLModel.metadata.create_all(eng)
    return eng


def test_insert_logger_and_reading(engine):
    with Session(engine) as session:
        logger = models.LoggerInfo(name="A", host="10.0.0.1")
        session.add(logger)
        session.commit()
        session.refresh(logger)
        assert logger.id is not None

        session.add(models.SensorReading(logger_id=logger.id, sensor_id=1, value=12.3, valid=True))
        session.commit()

        rows = session.exec(select(models.SensorReading)).all()
        assert len(rows) == 1
        assert rows[0].value == pytest.approx(12.3)
        assert rows[0].logger_id == logger.id
