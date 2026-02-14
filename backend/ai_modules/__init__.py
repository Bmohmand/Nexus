"""
nexus_ai
========
The AI/ML pipeline for Nexus — The Physical World API.

Quick start (for Zihan's FastAPI):

    from nexus_ai import NexusPipeline

    pipeline = NexusPipeline()

    # Ingest an item
    result = await pipeline.ingest("photo.jpg")

    # Search
    query_vec = await pipeline.embed_query("cold weather survival gear")

    # Synthesize (after Pinecone returns results)
    plan = await pipeline.synthesize_results(query, retrieved_items)

Env vars needed:
    OPENAI_API_KEY, VOYAGE_API_KEY (or GOOGLE_PROJECT_ID), PINECONE_API_KEY
"""

from .pipeline import NexusPipeline
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
    "ItemContext",
    "EmbeddingResult",
    "SearchQuery",
    "RetrievedItem",
    "MissionPlan",
    "EmbeddingProvider",
    "validate_config",
]
