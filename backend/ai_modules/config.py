"""
nexus_ai/config.py
==================
Centralized configuration. All API keys and model choices live here.
Uses environment variables so nothing is hardcoded.

Required env vars:
  OPENAI_API_KEY        - For GPT-4o Vision context extraction
  VOYAGE_API_KEY        - For Voyage multimodal embeddings (option A)
  GOOGLE_PROJECT_ID     - For Vertex AI embeddings (option B)
  PINECONE_API_KEY      - Zihan's Pinecone index (used in pipeline)
  PINECONE_INDEX_NAME   - Name of the Pinecone serverless index
"""

import os
from enum import Enum


class EmbeddingProvider(str, Enum):
    VOYAGE = "voyage"
    VERTEX = "vertex"
    CLIP_LOCAL = "clip_local"  # Fallback for offline dev / hackathon wifi issues


# ---------------------------------------------------------------------------
# API Keys (loaded from environment)
# ---------------------------------------------------------------------------
OPENAI_API_KEY: str = os.getenv("OPENAI_API_KEY", "")
VOYAGE_API_KEY: str = os.getenv("VOYAGE_API_KEY", "")
GOOGLE_PROJECT_ID: str = os.getenv("GOOGLE_PROJECT_ID", "")
PINECONE_API_KEY: str = os.getenv("PINECONE_API_KEY", "")
PINECONE_INDEX_NAME: str = os.getenv("PINECONE_INDEX_NAME", "nexus-items")

# ---------------------------------------------------------------------------
# Model Configuration
# ---------------------------------------------------------------------------
# Vision model for context extraction
VISION_MODEL: str = "gpt-4o"

# Which embedding provider to use
EMBEDDING_PROVIDER: EmbeddingProvider = EmbeddingProvider(
    os.getenv("NEXUS_EMBEDDING_PROVIDER", "voyage")
)

# Embedding dimensions (must match Pinecone index dimension)
EMBEDDING_DIMENSIONS: dict[EmbeddingProvider, int] = {
    EmbeddingProvider.VOYAGE: 1024,    # voyage-multimodal-3
    EmbeddingProvider.VERTEX: 1408,    # multimodalembedding@001
    EmbeddingProvider.CLIP_LOCAL: 512, # ViT-B-32
}

# Voyage model name
VOYAGE_MODEL: str = "voyage-multimodal-3"

# Vertex AI model name
VERTEX_MODEL: str = "multimodalembedding@001"
VERTEX_LOCATION: str = "us-central1"

# ---------------------------------------------------------------------------
# LLM Settings
# ---------------------------------------------------------------------------
# Synthesis model (for final mission plan generation)
SYNTHESIS_MODEL: str = "gpt-4o"
SYNTHESIS_MAX_TOKENS: int = 2000
SYNTHESIS_TEMPERATURE: float = 0.4  # Lower = more deterministic packing advice

# ---------------------------------------------------------------------------
# Search Defaults
# ---------------------------------------------------------------------------
DEFAULT_TOP_K: int = 15  # Number of nearest neighbors to retrieve
SIMILARITY_THRESHOLD: float = 0.25  # Min score to include in results


def get_embedding_dim() -> int:
    """Return the embedding dimension for the active provider."""
    return EMBEDDING_DIMENSIONS[EMBEDDING_PROVIDER]


def validate_config() -> list[str]:
    """Check that required keys are set. Returns list of warnings."""
    warnings = []
    if not OPENAI_API_KEY:
        warnings.append("OPENAI_API_KEY not set — context extraction will fail")
    if EMBEDDING_PROVIDER == EmbeddingProvider.VOYAGE and not VOYAGE_API_KEY:
        warnings.append("VOYAGE_API_KEY not set — switch provider or set key")
    if EMBEDDING_PROVIDER == EmbeddingProvider.VERTEX and not GOOGLE_PROJECT_ID:
        warnings.append("GOOGLE_PROJECT_ID not set — Vertex AI will fail")
    if not PINECONE_API_KEY:
        warnings.append("PINECONE_API_KEY not set — database ops will fail")
    return warnings
