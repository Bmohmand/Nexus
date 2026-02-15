"""
nexus_ai/config.py
==================
Centralized configuration. All API keys and model choices live here.
Uses environment variables so nothing is hardcoded.

Required env vars:
  OPENAI_API_KEY        - For GPT-5 Vision context extraction
  VOYAGE_API_KEY        - For Voyage multimodal embeddings
  SUPABASE_URL          - Supabase project URL
  SUPABASE_SERVICE_KEY  - Supabase service role key (NOT the anon key)
"""

import os
from enum import Enum


class EmbeddingProvider(str, Enum):
    VOYAGE = "voyage"
    CLIP_LOCAL = "clip_local"  # Fallback for offline dev / hackathon wifi issues


# ---------------------------------------------------------------------------
# API Keys (loaded from environment)
# ---------------------------------------------------------------------------
# Accept common alternate names (e.g. frontend uses OPEN_AI_KEY, backend uses OPENAI_API_KEY)
OPENAI_API_KEY: str = os.getenv("OPENAI_API_KEY") or os.getenv("OPEN_AI_KEY") or ""
VOYAGE_API_KEY: str = os.getenv("VOYAGE_API_KEY", "")
SUPABASE_URL: str = os.getenv("SUPABASE_URL", "")
# Service role key required for server-side DB/vector writes; anon key can be used for dev but may hit RLS
SUPABASE_SERVICE_KEY: str = os.getenv("SUPABASE_SERVICE_KEY") or os.getenv("SUPABASE_ANON_KEY") or ""

# ---------------------------------------------------------------------------
# Model Configuration
# ---------------------------------------------------------------------------
# Vision model for context extraction
VISION_MODEL: str = "gpt-5"

# Which embedding provider to use
EMBEDDING_PROVIDER: EmbeddingProvider = EmbeddingProvider(
    os.getenv("NEXUS_EMBEDDING_PROVIDER", "voyage")
)

# Embedding dimensions (must match Supabase vector column dimension)
EMBEDDING_DIMENSIONS: dict[EmbeddingProvider, int] = {
    EmbeddingProvider.VOYAGE: 1024,      # voyage-multimodal-3.5 (default dim)
    EmbeddingProvider.CLIP_LOCAL: 512,    # ViT-B-32
}

# Voyage model name
VOYAGE_MODEL: str = "voyage-multimodal-3.5"

# ---------------------------------------------------------------------------
# LLM Settings
# ---------------------------------------------------------------------------
# Synthesis model (for final mission plan generation)
SYNTHESIS_MODEL: str = "gpt-5"
SYNTHESIS_MAX_TOKENS: int = 4000

# GPT-5 reasoning effort per pipeline stage (minimal, low, medium, high)
# Higher effort = better accuracy, more tokens, higher cost
REASONING_EFFORT_EXTRACTION: str = "medium"   # Context extraction: worth thinking about materials/safety
REASONING_EFFORT_SYNTHESIS: str = "high"      # Mission plan: needs careful cross-domain reasoning

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
    if not SUPABASE_URL:
        warnings.append("SUPABASE_URL not set — database ops will fail")
    if not SUPABASE_SERVICE_KEY:
        warnings.append("SUPABASE_SERVICE_KEY not set — database ops will fail")
    return warnings
