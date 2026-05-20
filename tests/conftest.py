"""Cấu hình chung cho pytest - đảm bảo Qt chạy headless trên CI."""

from __future__ import annotations

import os
import sys
from pathlib import Path

# Bật offscreen trước khi import bất cứ module Qt nào.
os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")

# Đảm bảo `src/` nằm trên sys.path khi chạy `pytest` từ repo root mà chưa
# install package.
ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "src"
if str(SRC) not in sys.path:
    sys.path.insert(0, str(SRC))
