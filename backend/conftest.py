"""
Root-level conftest for backend tests.

Adds the --run-live CLI flag for live integration tests.
"""


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
