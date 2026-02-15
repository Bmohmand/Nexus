"""
Shared fixtures for embedding and AI model tests.

Provides:
  - Synthetic ItemContext objects for each category
  - Fake embedding vectors with controlled similarity properties
  - Mock embedder, vector store, and context extractor
  - Sample test image bytes (1x1 pixel PNG)
"""

import sys
import uuid
from pathlib import Path
from unittest.mock import AsyncMock, MagicMock, patch

import numpy as np
import pytest

# ---------------------------------------------------------------------------
# Bootstrap: add test dir to sys.path, then import ai_modules submodules
# without triggering __init__.py's heavy dependency chain
# ---------------------------------------------------------------------------
_THIS_DIR = Path(__file__).resolve().parent
if str(_THIS_DIR) not in sys.path:
    sys.path.insert(0, str(_THIS_DIR))

from _import_helper import models

ItemContext = models.ItemContext
EmbeddingResult = models.EmbeddingResult
RetrievedItem = models.RetrievedItem


# ---------------------------------------------------------------------------
# Tiny valid PNG (1x1 red pixel) — used wherever a test needs image bytes
# ---------------------------------------------------------------------------
TINY_PNG = (
    b"\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01"
    b"\x00\x00\x00\x01\x08\x02\x00\x00\x00\x90wS\xde\x00"
    b"\x00\x00\x0cIDATx\x9cc\xf8\x0f\x00\x00\x01\x01\x00"
    b"\x05\x18\xd8N\x00\x00\x00\x00IEND\xaeB`\x82"
)


# ===================================================================
# Item context fixtures — one per category, with realistic metadata
# ===================================================================
@pytest.fixture
def clothing_context():
    return ItemContext(
        name="Gore-Tex Rain Jacket",
        inferred_category="clothing",
        primary_material="Gore-Tex nylon",
        weight_estimate="medium",
        thermal_rating="neutral",
        water_resistance="waterproof",
        utility_summary="Waterproof shell jacket for rain and wind protection.",
        semantic_tags=["waterproof", "rain", "layering", "cold-weather"],
        durability="rugged",
        compressibility="moderate",
    )


@pytest.fixture
def medical_context():
    return ItemContext(
        name="Sterile Trauma Bandage",
        inferred_category="medical",
        primary_material="cotton gauze",
        weight_estimate="ultralight",
        thermal_rating="neutral",
        water_resistance="not water-resistant",
        medical_application="wound_care",
        utility_summary="Sterile bandage for emergency wound care and bleeding control.",
        semantic_tags=["wound_care", "sterile", "first_aid", "disposable"],
        durability="disposable",
        compressibility="highly_compressible",
    )


@pytest.fixture
def tech_context():
    return ItemContext(
        name="Tactical Flashlight",
        inferred_category="tech",
        primary_material="anodized aluminum",
        weight_estimate="light",
        thermal_rating="neutral",
        water_resistance="waterproof",
        utility_summary="High-lumen waterproof flashlight for navigation and signaling.",
        semantic_tags=["navigation", "light", "signaling", "waterproof"],
        durability="rugged",
        compressibility="rigid",
    )


@pytest.fixture
def camping_context():
    return ItemContext(
        name="4-Season Sleeping Bag",
        inferred_category="camping",
        primary_material="down fill, ripstop nylon shell",
        weight_estimate="heavy",
        thermal_rating="cold-rated",
        water_resistance="water-resistant",
        utility_summary="Insulated sleeping bag rated to -20F for cold-weather camping.",
        semantic_tags=["warmth", "cold-weather", "sleeping", "insulated", "survival"],
        durability="rugged",
        compressibility="highly_compressible",
    )


@pytest.fixture
def all_contexts(clothing_context, medical_context, tech_context, camping_context):
    """All four category contexts as a dict keyed by category name."""
    return {
        "clothing": clothing_context,
        "medical": medical_context,
        "tech": tech_context,
        "camping": camping_context,
    }


# ===================================================================
# Embedding vector fixtures — deterministic, with controlled similarity
# ===================================================================
def _make_category_vectors(dim: int = 1024, n_per_cat: int = 3, seed: int = 42):
    """
    Generate embedding vectors where items in the SAME category are
    closer together than items across categories.

    Strategy: each category gets a random centroid, and items are
    centroid + small noise.  This guarantees intra > inter similarity.
    """
    rng = np.random.RandomState(seed)
    categories = ["clothing", "medical", "tech", "camping"]
    vectors = {}
    centroids = {}

    for cat in categories:
        centroid = rng.randn(dim).astype(np.float32)
        centroid /= np.linalg.norm(centroid)
        centroids[cat] = centroid
        for i in range(n_per_cat):
            noise = rng.randn(dim).astype(np.float32) * 0.05
            v = centroid + noise
            v /= np.linalg.norm(v)
            vectors[f"{cat}_{i}"] = v

    return vectors, centroids


@pytest.fixture
def category_vectors():
    """Dict of {name: vector} with 3 items per category, 1024-dim."""
    vecs, _ = _make_category_vectors()
    return vecs


@pytest.fixture
def category_centroids():
    """Dict of {category: centroid_vector}, 1024-dim."""
    _, centroids = _make_category_vectors()
    return centroids


@pytest.fixture
def sample_embedding_result(clothing_context):
    return EmbeddingResult(
        item_id=str(uuid.uuid4()),
        vector=[0.1] * 1024,
        dimension=1024,
        context=clothing_context,
        image_url="https://example.com/jacket.jpg",
    )


@pytest.fixture
def sample_retrieved_items(all_contexts):
    """A list of RetrievedItem objects (one per category) for search tests."""
    items = []
    scores = {"clothing": 0.85, "medical": 0.78, "tech": 0.72, "camping": 0.91}
    for cat, ctx in all_contexts.items():
        items.append(
            RetrievedItem(
                item_id=str(uuid.uuid4()),
                score=scores[cat],
                image_url=f"https://example.com/{cat}.jpg",
                context=ctx,
            )
        )
    return items


# ===================================================================
# Mock embedder fixture
# ===================================================================
@pytest.fixture
def mock_embedder():
    """
    A mock BaseEmbedder that returns deterministic vectors.
    embed_item returns a vector seeded by the context name.
    embed_text returns a vector seeded by the query text.
    """
    embedder = AsyncMock()
    embedder.dimension = 1024

    async def _embed_item(image_source, context):
        seed = hash(context.name) % (2**31)
        rng = np.random.RandomState(seed)
        vec = rng.randn(1024).astype(np.float32)
        vec /= np.linalg.norm(vec)
        return vec.tolist()

    async def _embed_text(text):
        seed = hash(text) % (2**31)
        rng = np.random.RandomState(seed)
        vec = rng.randn(1024).astype(np.float32)
        vec /= np.linalg.norm(vec)
        return vec.tolist()

    embedder.embed_item = AsyncMock(side_effect=_embed_item)
    embedder.embed_text = AsyncMock(side_effect=_embed_text)
    return embedder


# ===================================================================
# Mock vector store fixture
# ===================================================================
@pytest.fixture
def mock_vector_store():
    """A mock SupabaseVectorStore with in-memory storage."""
    store = AsyncMock()
    _storage = {}

    async def _upsert(result, image_url="", user_id=None):
        _storage[result.item_id] = {
            "result": result,
            "image_url": image_url,
            "user_id": user_id,
        }
        return result.item_id

    async def _count():
        return len(_storage)

    async def _delete(item_id):
        _storage.pop(item_id, None)

    store.upsert = AsyncMock(side_effect=_upsert)
    store.count = AsyncMock(side_effect=_count)
    store.delete = AsyncMock(side_effect=_delete)
    store._storage = _storage
    return store


# ===================================================================
# Mock context extractor fixture
# ===================================================================
@pytest.fixture
def mock_extractor(clothing_context):
    """A mock ContextExtractor that always returns the clothing context."""
    extractor = AsyncMock()
    extractor.extract = AsyncMock(return_value=clothing_context)
    return extractor


@pytest.fixture
def test_image_bytes():
    """Minimal valid PNG bytes for use in tests."""
    return TINY_PNG
