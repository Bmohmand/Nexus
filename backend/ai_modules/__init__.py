"""
manifest_ai
============
The AI/ML pipeline for Manifest — AI search engine for physical assets.

Quick start:

    from ai_modules import NexusPipeline

    pipeline = NexusPipeline()

    # Ingest an item
    item_id = await pipeline.ingest("photo.jpg", image_url="https://...")

    # Search
    plan = await pipeline.search("cold weather survival gear")

    # Pack (search + knapsack optimization)
    result, plan = await pipeline.pack_and_explain("medical relief", "drone_delivery")

Env vars needed:
    OPENAI_API_KEY, VOYAGE_API_KEY, SUPABASE_URL, SUPABASE_SERVICE_KEY
"""

from .pipeline import NexusPipeline
from .vector_store import SupabaseVectorStore
from .knapsack_optimizer import (
    KnapsackOptimizer,
    PackingConstraints,
    PackingResult,
    PackableItem,
    CONSTRAINT_PRESETS,
    ContainerSpec,
    ContainerResult,
    MultiPackingResult,
)
from .models import (
    ItemContext,
    EmbeddingResult,
    SearchQuery,
    RetrievedItem,
    MissionPlan,
)
from .config import EmbeddingProvider, validate_config

__all__ = [
    "NexusPipeline",
    "SupabaseVectorStore",
    "KnapsackOptimizer",
    "PackingConstraints",
    "PackingResult",
    "PackableItem",
    "CONSTRAINT_PRESETS",
    "ContainerSpec",
    "ContainerResult",
    "MultiPackingResult",
    "ItemContext",
    "EmbeddingResult",
    "SearchQuery",
    "RetrievedItem",
    "MissionPlan",
    "EmbeddingProvider",
    "validate_config",
]
