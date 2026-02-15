"""
Import helper for test modules.

Imports ai_modules submodules directly by file path, avoiding the
ai_modules/__init__.py which triggers the full dependency chain
(openai, supabase, voyageai, etc.) that may not be available in
all test environments.

Usage in test files:
    from _import_helper import models, config
    # For modules with heavy deps, use load_module():
    from _import_helper import load_module
    embedding_engine = load_module("embedding_engine")
"""

import importlib.util
import sys
from pathlib import Path

BACKEND_DIR = Path(__file__).resolve().parent.parent.parent
AI_MODULES_DIR = BACKEND_DIR / "ai_modules"

if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

# Also add the tests dir itself so _import_helper is importable by name
TESTS_DIR = Path(__file__).resolve().parent
if str(TESTS_DIR) not in sys.path:
    sys.path.insert(0, str(TESTS_DIR))


def load_module(name: str):
    """
    Load an ai_modules submodule by name without triggering __init__.py.

    Usage:
        embedding_engine = load_module("embedding_engine")
        VoyageEmbedder = embedding_engine.VoyageEmbedder
    """
    full_name = f"ai_modules.{name}"
    if full_name in sys.modules:
        return sys.modules[full_name]

    filepath = AI_MODULES_DIR / f"{name}.py"
    spec = importlib.util.spec_from_file_location(full_name, filepath)
    mod = importlib.util.module_from_spec(spec)
    sys.modules[full_name] = mod
    spec.loader.exec_module(mod)
    return mod


# Pre-register a minimal ai_modules package so submodule relative imports
# (e.g. from .config import ...) resolve correctly
if "ai_modules" not in sys.modules:
    _pkg_spec = importlib.util.spec_from_file_location(
        "ai_modules",
        AI_MODULES_DIR / "__init__.py",
        submodule_search_locations=[str(AI_MODULES_DIR)],
    )
    _pkg_mod = importlib.util.module_from_spec(_pkg_spec)
    sys.modules["ai_modules"] = _pkg_mod
    # Do NOT exec the __init__.py — that's the whole point

# Pre-load lightweight modules that have no heavy deps
config = load_module("config")
models = load_module("models")
