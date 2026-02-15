"""
Live integration tests — run against real APIs with real test images.

These tests require:
  - OPENAI_API_KEY  (GPT-5 Vision context extraction)
  - VOYAGE_API_KEY  (Voyage multimodal-3.5 embeddings)
  - Optionally SUPABASE_URL + SUPABASE_SERVICE_KEY (for storage tests)
  - Test images in test_images/ directory (or uses synthetic fallback)

Run with:
  pytest test_live_integration.py -v --run-live

Skip if no API keys:
  pytest test_live_integration.py -v  (all tests skip automatically)

Environment setup:
  export OPENAI_API_KEY="sk-..."
  export VOYAGE_API_KEY="pa-..."
  # Optional for storage tests:
  export SUPABASE_URL="https://xxx.supabase.co"
  export SUPABASE_SERVICE_KEY="eyJ..."
"""

import os
import sys
from pathlib import Path

import numpy as np
import pytest

BACKEND_DIR = Path(__file__).resolve().parent.parent.parent
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))


# ---------------------------------------------------------------------------
# Skip conditions
# ---------------------------------------------------------------------------
HAS_OPENAI_KEY = bool(os.getenv("OPENAI_API_KEY") or os.getenv("OPEN_AI_KEY"))
HAS_VOYAGE_KEY = bool(os.getenv("VOYAGE_API_KEY"))
HAS_SUPABASE = bool(os.getenv("SUPABASE_URL") and os.getenv("SUPABASE_SERVICE_KEY"))

needs_openai = pytest.mark.skipif(
    not HAS_OPENAI_KEY, reason="OPENAI_API_KEY not set"
)
needs_voyage = pytest.mark.skipif(
    not HAS_VOYAGE_KEY, reason="VOYAGE_API_KEY not set"
)
needs_supabase = pytest.mark.skipif(
    not HAS_SUPABASE, reason="SUPABASE_URL/SUPABASE_SERVICE_KEY not set"
)

# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------
TEST_IMAGES_DIR = Path(__file__).parent / "test_images"

# Minimal 1x1 red PNG for when no real images are available
TINY_PNG = (
    b"\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01"
    b"\x00\x00\x00\x01\x08\x02\x00\x00\x00\x90wS\xde\x00"
    b"\x00\x00\x0cIDATx\x9cc\xf8\x0f\x00\x00\x01\x01\x00"
    b"\x05\x18\xd8N\x00\x00\x00\x00IEND\xaeB`\x82"
)


@pytest.fixture
def test_image_path():
    """Return path to a test image, or None if no images exist."""
    if not TEST_IMAGES_DIR.exists():
        return None
    for category in ["clothing", "medical", "tech", "camping"]:
        cat_dir = TEST_IMAGES_DIR / category
        if cat_dir.exists():
            for img in cat_dir.iterdir():
                if img.suffix.lower() in (".jpg", ".jpeg", ".png", ".webp"):
                    return str(img)
    return None


@pytest.fixture
def test_image_bytes(test_image_path):
    """Return bytes of a test image, or TINY_PNG fallback."""
    if test_image_path:
        return Path(test_image_path).read_bytes()
    return TINY_PNG


@pytest.fixture
def categorized_images():
    """
    Return {category: [path, ...]} for all test images.
    Empty dict if no test_images/ directory exists.
    """
    if not TEST_IMAGES_DIR.exists():
        return {}
    result = {}
    for category in ["clothing", "medical", "tech", "camping"]:
        cat_dir = TEST_IMAGES_DIR / category
        if cat_dir.exists():
            imgs = [
                str(p)
                for p in sorted(cat_dir.iterdir())
                if p.suffix.lower() in (".jpg", ".jpeg", ".png", ".webp")
            ]
            if imgs:
                result[category] = imgs
    return result


# ---------------------------------------------------------------------------
# TEST GROUP 1: Context extraction (GPT-5 Vision)
# ---------------------------------------------------------------------------
@pytest.mark.live
class TestLiveContextExtraction:
    @needs_openai
    @pytest.mark.asyncio
    async def test_extract_returns_valid_context(self, test_image_bytes):
        """GPT-5 Vision should return a parseable ItemContext."""
        from ai_modules.context_extractor import ContextExtractor

        extractor = ContextExtractor()
        ctx = await extractor.extract(test_image_bytes)

        assert ctx.name, "name should not be empty"
        assert ctx.inferred_category in [
            "clothing", "medical", "tech", "camping", "food", "misc"
        ]
        assert ctx.utility_summary, "utility_summary should not be empty"

    @needs_openai
    @pytest.mark.asyncio
    async def test_extract_from_file_path(self, test_image_path):
        """Context extraction from a file path (if test images exist)."""
        if test_image_path is None:
            pytest.skip("No test images available")

        from ai_modules.context_extractor import ContextExtractor

        extractor = ContextExtractor()
        ctx = await extractor.extract(test_image_path)

        assert ctx.name
        assert ctx.inferred_category

    @needs_openai
    @pytest.mark.asyncio
    async def test_clothing_extraction_quality(self, categorized_images):
        """If clothing images exist, verify GPT-5 categorizes them correctly."""
        if "clothing" not in categorized_images:
            pytest.skip("No clothing test images")

        from ai_modules.context_extractor import ContextExtractor

        extractor = ContextExtractor()
        img_path = categorized_images["clothing"][0]
        ctx = await extractor.extract(img_path)

        assert ctx.inferred_category == "clothing", (
            f"Expected 'clothing', got '{ctx.inferred_category}' for {img_path}"
        )

    @needs_openai
    @pytest.mark.asyncio
    async def test_medical_extraction_has_application(self, categorized_images):
        """Medical items should have a medical_application field."""
        if "medical" not in categorized_images:
            pytest.skip("No medical test images")

        from ai_modules.context_extractor import ContextExtractor

        extractor = ContextExtractor()
        img_path = categorized_images["medical"][0]
        ctx = await extractor.extract(img_path)

        assert ctx.inferred_category == "medical"
        assert ctx.medical_application is not None, (
            "Medical items should have a medical_application"
        )


# ---------------------------------------------------------------------------
# TEST GROUP 2: Embedding generation (Voyage multimodal-3.5)
# ---------------------------------------------------------------------------
@pytest.mark.live
class TestLiveEmbedding:
    @needs_voyage
    @pytest.mark.asyncio
    async def test_voyage_embed_text(self):
        """Voyage should return a 1024-dim vector for text queries."""
        from ai_modules.embedding_engine import VoyageEmbedder

        embedder = VoyageEmbedder()
        vec = await embedder.embed_text("cold weather survival gear")

        assert len(vec) == 1024
        norm = np.linalg.norm(vec)
        # Voyage vectors should be roughly unit-normalized
        assert 0.5 < norm < 2.0, f"Unexpected norm: {norm}"

    @needs_voyage
    @pytest.mark.asyncio
    async def test_voyage_embed_item(self, test_image_bytes):
        """Voyage should embed an image + context into 1024 dims."""
        from ai_modules.embedding_engine import VoyageEmbedder
        from ai_modules.models import ItemContext

        embedder = VoyageEmbedder()
        ctx = ItemContext(
            name="Test Jacket",
            inferred_category="clothing",
            utility_summary="A test jacket",
            semantic_tags=["test"],
        )
        vec = await embedder.embed_item(test_image_bytes, ctx)

        assert len(vec) == 1024

    @needs_voyage
    @pytest.mark.asyncio
    async def test_similar_queries_have_high_similarity(self):
        """Semantically similar queries should have cosine sim > 0.5."""
        from ai_modules.embedding_engine import VoyageEmbedder

        embedder = VoyageEmbedder()
        vec1 = await embedder.embed_text("warm winter jacket for cold weather")
        vec2 = await embedder.embed_text("insulated coat for freezing temperatures")

        sim = np.dot(vec1, vec2) / (np.linalg.norm(vec1) * np.linalg.norm(vec2))
        assert sim > 0.5, f"Expected similar queries to have sim > 0.5, got {sim:.4f}"

    @needs_voyage
    @pytest.mark.asyncio
    async def test_dissimilar_queries_have_lower_similarity(self):
        """Semantically different queries should have lower similarity."""
        from ai_modules.embedding_engine import VoyageEmbedder

        embedder = VoyageEmbedder()
        vec1 = await embedder.embed_text("warm winter jacket")
        vec2 = await embedder.embed_text("sterile surgical scalpel")

        sim = np.dot(vec1, vec2) / (np.linalg.norm(vec1) * np.linalg.norm(vec2))
        assert sim < 0.8, f"Expected dissimilar queries to have sim < 0.8, got {sim:.4f}"


# ---------------------------------------------------------------------------
# TEST GROUP 3: Embedding space clustering (with real images)
# ---------------------------------------------------------------------------
@pytest.mark.live
class TestLiveEmbeddingClustering:
    @needs_voyage
    @pytest.mark.asyncio
    async def test_intra_vs_inter_category_similarity(self, categorized_images):
        """
        Items in the same category should have higher avg similarity than
        items across categories. This is the core quality metric.
        """
        if len(categorized_images) < 2:
            pytest.skip("Need at least 2 categories of test images")

        from ai_modules.embedding_engine import VoyageEmbedder
        from ai_modules.context_extractor import ContextExtractor
        from ai_modules.models import ItemContext

        embedder = VoyageEmbedder()
        extractor = ContextExtractor() if HAS_OPENAI_KEY else None

        # Embed up to 2 items per category (to keep API costs down)
        cat_vectors = {}
        for cat, paths in categorized_images.items():
            vecs = []
            for path in paths[:2]:
                if extractor:
                    ctx = await extractor.extract(path)
                else:
                    ctx = ItemContext(
                        name=Path(path).stem,
                        inferred_category=cat,
                        utility_summary=f"A {cat} item",
                    )
                vec = await embedder.embed_item(path, ctx)
                vecs.append(np.array(vec))
            cat_vectors[cat] = vecs

        # Calculate intra-category average similarity
        intra_sims = []
        for cat, vecs in cat_vectors.items():
            if len(vecs) < 2:
                continue
            for i in range(len(vecs)):
                for j in range(i + 1, len(vecs)):
                    sim = np.dot(vecs[i], vecs[j]) / (
                        np.linalg.norm(vecs[i]) * np.linalg.norm(vecs[j])
                    )
                    intra_sims.append(sim)

        # Calculate inter-category average similarity
        inter_sims = []
        cats = list(cat_vectors.keys())
        for i in range(len(cats)):
            for j in range(i + 1, len(cats)):
                for v1 in cat_vectors[cats[i]]:
                    for v2 in cat_vectors[cats[j]]:
                        sim = np.dot(v1, v2) / (
                            np.linalg.norm(v1) * np.linalg.norm(v2)
                        )
                        inter_sims.append(sim)

        if intra_sims and inter_sims:
            avg_intra = np.mean(intra_sims)
            avg_inter = np.mean(inter_sims)
            assert avg_intra > avg_inter, (
                f"Intra-category sim ({avg_intra:.4f}) should be > "
                f"inter-category sim ({avg_inter:.4f})"
            )


# ---------------------------------------------------------------------------
# TEST GROUP 4: Full ingest + search round-trip (needs all services)
# ---------------------------------------------------------------------------
@pytest.mark.live
class TestLiveFullRoundTrip:
    @needs_openai
    @needs_voyage
    @needs_supabase
    @pytest.mark.asyncio
    async def test_ingest_then_search(self, test_image_bytes):
        """
        Ingest an image, then search for it and verify it appears in results.
        This is the ultimate integration test.
        """
        from ai_modules.pipeline import NexusPipeline

        pipeline = NexusPipeline()

        # Ingest
        item_id, context = await pipeline.ingest(
            image_source=test_image_bytes,
            image_url="https://example.com/test-integration.jpg",
        )

        assert item_id is not None
        assert context.name

        # Search using the item's own name — should find itself
        results = await pipeline.search(
            query=context.name,
            top_k=5,
            synthesize=False,
        )

        found_ids = [r.item_id for r in results]
        assert item_id in found_ids, (
            f"Ingested item {item_id} ({context.name}) not found in search results"
        )

        # Cleanup
        await pipeline.store.delete(item_id)

    @needs_openai
    @needs_voyage
    @needs_supabase
    @pytest.mark.asyncio
    async def test_search_relevance(self, categorized_images):
        """
        Ingest items from multiple categories, then verify search returns
        relevant items for a category-specific query.
        """
        if len(categorized_images) < 2:
            pytest.skip("Need at least 2 categories of test images")

        from ai_modules.pipeline import NexusPipeline

        pipeline = NexusPipeline()
        ingested_ids = []

        try:
            # Ingest 1 item per category
            for cat, paths in categorized_images.items():
                item_id, ctx = await pipeline.ingest(paths[0])
                ingested_ids.append(item_id)

            # Search for medical items
            results = await pipeline.search(
                query="emergency medical first aid supplies",
                top_k=5,
                synthesize=False,
            )

            if results:
                # Top result should be a medical item (if one was ingested)
                top_categories = [r.context.inferred_category for r in results[:3]]
                if "medical" in categorized_images:
                    assert "medical" in top_categories, (
                        f"Expected 'medical' in top 3, got {top_categories}"
                    )
        finally:
            # Cleanup all ingested test items
            for item_id in ingested_ids:
                try:
                    await pipeline.store.delete(item_id)
                except Exception:
                    pass
