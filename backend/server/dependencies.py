"""
Manifest API — Shared dependencies.

Provides the singleton NexusPipeline instance and Supabase client
that are injected into route handlers via FastAPI's Depends().
"""

import logging
from functools import lru_cache

from supabase import create_client, Client

import sys
import os

# Ensure ai_modules is importable
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from ai_modules.pipeline import NexusPipeline
from ai_modules.config import SUPABASE_URL, SUPABASE_SERVICE_KEY

logger = logging.getLogger("manifest.deps")


@lru_cache(maxsize=1)
def get_pipeline() -> NexusPipeline:
    """
    Singleton pipeline instance. Initialized once, reused across requests.
    lru_cache ensures __init__ (which loads models + validates config) runs only once.
    """
    logger.info("Initializing NexusPipeline (singleton)...")
    return NexusPipeline()


@lru_cache(maxsize=1)
def get_supabase() -> Client:
    """Singleton Supabase admin client for CRUD operations."""
    if not SUPABASE_URL or not SUPABASE_SERVICE_KEY:
        raise RuntimeError("SUPABASE_URL and SUPABASE_SERVICE_KEY must be set")
    return create_client(SUPABASE_URL, SUPABASE_SERVICE_KEY)
