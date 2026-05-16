"""Shim: chạy `python main.py` từ thư mục gốc repo (sau khi `pip install -e .` hoặc `uv pip install -e .`)."""
from central_logger.main import main

if __name__ == "__main__":
    raise SystemExit(main())
