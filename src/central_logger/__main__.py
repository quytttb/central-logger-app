"""Allow ``python -m central_logger`` (same as ``python -m central_logger.main``)."""
from central_logger.main import main

if __name__ == "__main__":
    raise SystemExit(main())
