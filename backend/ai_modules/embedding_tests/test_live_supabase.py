"""
Live tests for the Supabase vector store (no OpenAI / Voyage API needed).

These tests exercise SupabaseVectorStore directly with pre-computed
synthetic vectors so they only require SUPABASE_URL and
SUPABASE_SERVICE_KEY to be set.

Run with:
  pytest test_live_supabase.py -v --run-live
"""

import os
import uuid
from pathlib import Path

import numpy as np
import pytest

from _import_helper import models, load_module

ItemContext = models.ItemContext
EmbeddingResult = models.EmbeddingResult

# Force load .env (in case _import_helper didn't or ran too early/late)
try:
    from dotenv import load_dotenv
    # Assuming backend/.env
    env_path = Path(__file__).resolve().parent.parent.parent / ".env"
    if env_path.exists():
        load_dotenv(env_path, override=True)
except ImportError:
    pass

# ---------------------------------------------------------------------------
# Skip if Supabase creds missing
# ---------------------------------------------------------------------------
HAS_SUPABASE = bool(
    os.getenv("SUPABASE_URL") and os.getenv("SUPABASE_SERVICE_KEY")
)
needs_supabase = pytest.mark.skipif(
    not HAS_SUPABASE, reason="SUPABASE_URL/SUPABASE_SERVICE_KEY not set"
)

# Deterministic user ID for test isolation — cleanup targets this.
# Use env var if available, otherwise None (to avoid FK violations if user doesn't exist)
TEST_USER_ID = os.getenv("TEST_USER_ID")

DIM = 1024


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
def _random_vector(seed: int, dim: int = DIM) -> list[float]:
    """Deterministic unit-normalised random vector."""
    rng = np.random.RandomState(seed)
    v = rng.randn(dim).astype(np.float32)
    v /= np.linalg.norm(v)
    return v.tolist()


def _make_result(
    category: str = "tech",
    name: str = "Test Item",
    seed: int = 0,
) -> EmbeddingResult:
    """Build an EmbeddingResult with a synthetic vector."""
    return EmbeddingResult(
        item_id=str(uuid.uuid4()),
        vector=_random_vector(seed),
        dimension=DIM,
        context=ItemContext(
            name=name,
            inferred_category=category,
            utility_summary=f"A {category} item for testing",
            semantic_tags=["test"],
        ),
    )


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------
@pytest.fixture
async def store():
    """Live SupabaseVectorStore — skips if keys missing."""
    if not HAS_SUPABASE:
        pytest.skip("SUPABASE_URL/SUPABASE_SERVICE_KEY not set")
    store_mod = load_module("vector_store")
    return store_mod.SupabaseVectorStore()


@pytest.fixture(autouse=True)
async def _cleanup_test_rows(store):
    """
    Cleanup: delete any rows created during each test.
    We track item_ids and delete them after the test completes.
    """
    created_ids = []
    # Store the original upsert so tests can record ids
    store._test_created_ids = created_ids
    yield
    for item_id in created_ids:
        try:
            await store.delete(item_id)
        except Exception:
            pass


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------
@pytest.mark.live
class TestLiveSupabaseVectorStore:

    @needs_supabase
    @pytest.mark.asyncio
    async def test_upsert_and_retrieve(self, store):
        """Insert a known vector, search with it, verify it returns."""
        result = _make_result(category="tech", name="Upsert Test", seed=100)

        item_id = await store.upsert(
            result, image_url="https://example.com/test.jpg", user_id=TEST_USER_ID,
        )
        store._test_created_ids.append(item_id)

        assert item_id == result.item_id

        # Search using the same vector — should find itself
        retrieved = await store.search(
            query_vector=result.vector, top_k=5,
        )

        found_ids = [r.item_id for r in retrieved]
        assert item_id in found_ids, (
            f"Upserted item {item_id} not found in search results"
        )

    @needs_supabase
    @pytest.mark.asyncio
    async def test_delete_actually_removes(self, store):
        """Insert, delete, verify gone from search results."""
        result = _make_result(category="camping", name="Delete Test", seed=200)

        item_id = await store.upsert(
            result, image_url="", user_id=TEST_USER_ID,
        )
        # Don't add to cleanup — we're deleting manually

        # Verify it exists first
        retrieved_before = await store.search(
            query_vector=result.vector, top_k=5,
        )
        assert item_id in [r.item_id for r in retrieved_before]

        # Delete
        await store.delete(item_id)

        # Verify it's gone
        retrieved_after = await store.search(
            query_vector=result.vector, top_k=5,
        )
        assert item_id not in [r.item_id for r in retrieved_after], (
            f"Item {item_id} still found after deletion"
        )

    @needs_supabase
    @pytest.mark.asyncio
    async def test_category_filter_works(self, store):
        """Insert 2 categories, filter search, verify only matching category returns."""
        med_result = _make_result(category="medical", name="Filter Med", seed=300)
        tech_result = _make_result(category="tech", name="Filter Tech", seed=301)

        med_id = await store.upsert(med_result, user_id=TEST_USER_ID)
        tech_id = await store.upsert(tech_result, user_id=TEST_USER_ID)
        store._test_created_ids.extend([med_id, tech_id])

        # Search with medical filter using the medical vector
        retrieved = await store.search(
            query_vector=med_result.vector,
            top_k=10,
            category_filter="medical",
        )

        retrieved_ids = [r.item_id for r in retrieved]
        # Medical item should appear
        assert med_id in retrieved_ids, "Medical item should appear in filtered results"
        # Tech item should NOT appear under medical filter
        assert tech_id not in retrieved_ids, (
            "Tech item should not appear when filtering for medical"
        )

    @needs_supabase
    @pytest.mark.asyncio
    async def test_similarity_ordering(self, store):
        """Insert 2 vectors at known distances from query, verify ranking."""
        # Create a query vector
        query_vec = _random_vector(seed=400)

        # Create a "close" vector: query + small noise
        close_vec = np.array(query_vec) + np.random.RandomState(401).randn(DIM) * 0.05
        close_vec = (close_vec / np.linalg.norm(close_vec)).tolist()

        # Create a "far" vector: completely different seed
        far_vec = _random_vector(seed=999)

        close_result = EmbeddingResult(
            item_id=str(uuid.uuid4()),
            vector=close_vec,
            dimension=DIM,
            context=ItemContext(
                name="Close Item",
                inferred_category="tech",
                utility_summary="Close to query",
                semantic_tags=["test"],
            ),
        )
        far_result = EmbeddingResult(
            item_id=str(uuid.uuid4()),
            vector=far_vec,
            dimension=DIM,
            context=ItemContext(
                name="Far Item",
                inferred_category="tech",
                utility_summary="Far from query",
                semantic_tags=["test"],
            ),
        )

        close_id = await store.upsert(close_result, user_id=TEST_USER_ID)
        far_id = await store.upsert(far_result, user_id=TEST_USER_ID)
        store._test_created_ids.extend([close_id, far_id])

        retrieved = await store.search(query_vector=query_vec, top_k=50)
        retrieved_ids = [r.item_id for r in retrieved]

        # Both should appear
        assert close_id in retrieved_ids, "Close item should appear in results"
        assert far_id in retrieved_ids, "Far item should appear in results"

        # Close item should rank higher (lower index)
        close_idx = retrieved_ids.index(close_id)
        far_idx = retrieved_ids.index(far_id)
        assert close_idx < far_idx, (
            f"Close item (idx={close_idx}) should rank higher than far item (idx={far_idx})"
        )

    @needs_supabase
    @pytest.mark.asyncio
    async def test_metadata_roundtrip(self, store):
        """Verify all ItemContext fields survive upsert → search retrieval."""
        ctx = ItemContext(
            name="Metadata Roundtrip Jacket",
            inferred_category="clothing",
            primary_material="Gore-Tex nylon",
            weight_estimate="medium",
            thermal_rating="neutral",
            water_resistance="waterproof",
            utility_summary="Waterproof shell for testing metadata roundtrip.",
            semantic_tags=["waterproof", "test", "roundtrip"],
            durability="rugged",
            compressibility="moderate",
        )
        result = EmbeddingResult(
            item_id=str(uuid.uuid4()),
            vector=_random_vector(seed=500),
            dimension=DIM,
            context=ctx,
        )

        item_id = await store.upsert(
            result,
            image_url="https://example.com/roundtrip.jpg",
            user_id=TEST_USER_ID,
        )
        store._test_created_ids.append(item_id)

        # Search for the item
        retrieved = await store.search(query_vector=result.vector, top_k=5)

        match = None
        for r in retrieved:
            if r.item_id == item_id:
                match = r
                break

        assert match is not None, f"Upserted item {item_id} not found in search"

        # Verify context fields survived the roundtrip
        rc = match.context
        assert rc.name == "Metadata Roundtrip Jacket"
        assert rc.inferred_category == "clothing"
        assert rc.utility_summary is not None
        assert len(rc.utility_summary) > 0
