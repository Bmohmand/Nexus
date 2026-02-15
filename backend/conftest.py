"""
Root-level conftest for backend tests.

Loads .env for API keys and adds the --run-live CLI flag for live
integration tests.
"""

from pathlib import Path

try:
    from dotenv import load_dotenv

    _env_path = Path(__file__).resolve().parent / ".env"
    _root_env_path = Path(__file__).resolve().parent.parent / ".env"

    if _env_path.exists():
        load_dotenv(_env_path, override=False)
    elif _root_env_path.exists():
        load_dotenv(_root_env_path, override=False)

except ImportError:
    print("Warning: python-dotenv not installed. .env files will not be loaded.")


def pytest_addoption(parser):
    parser.addoption(
        "--run-live",
        action="store_true",
        default=False,
        help="Run live integration tests that hit real APIs (requires API keys)",
    )


def pytest_collection_modifyitems(config, items):
    if not config.getoption("--run-live"):
        skip_live = __import__("pytest").mark.skip(
            reason="Pass --run-live to run live integration tests"
        )
        for item in items:
            if "live" in item.keywords:
                item.add_marker(skip_live)
