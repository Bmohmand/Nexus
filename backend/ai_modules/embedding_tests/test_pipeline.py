"""
Tests for ai_modules.pipeline — NexusPipeline orchestrator.

All external services (OpenAI, Voyage, Supabase) are mocked.
Tests cover:
  1. Ingest flow: image → context → embedding → store
  2. Search flow: query → embed → vector search → (optional) synthesis
  3. Component wiring — correct data flows between stages
  4. Batch ingest
"""

import uuid
from unittest.mock import AsyncMock, MagicMock, patch, PropertyMock

import numpy as np
import pytest

from _import_helper import models, load_module

ItemContext = models.ItemContext
EmbeddingResult = models.EmbeddingResult
RetrievedItem = models.RetrievedItem
MissionPlan = models.MissionPlan


# ---------------------------------------------------------------------------
# Helper: build a NexusPipeline with all components mocked
# ---------------------------------------------------------------------------
def _make_pipeline(
    extractor=None,
    embedder=None,
    store=None,
    synthesizer=None,
    optimizer=None,
):
    """
    Construct a NexusPipeline without calling __init__ (which needs real
    API keys). Inject mock components directly.
    """
    pipeline_mod = load_module("pipeline")
    NexusPipeline = pipeline_mod.NexusPipeline

    pipeline = NexusPipeline.__new__(NexusPipeline)
    pipeline.extractor = extractor or AsyncMock()
    pipeline.embedder = embedder or AsyncMock()
    pipeline.store = store or AsyncMock()
    pipeline.synthesizer = synthesizer or AsyncMock()

    # Use a real KnapsackOptimizer if not provided
    if optimizer is None:
        knapsack_mod = load_module("knapsack_optimizer")
        pipeline.optimizer = knapsack_mod.KnapsackOptimizer()
    else:
        pipeline.optimizer = optimizer

    return pipeline


# ---------------------------------------------------------------------------
# Ingest flow
# ---------------------------------------------------------------------------
class TestIngestFlow:
    @pytest.mark.asyncio
    async def test_ingest_calls_all_three_stages(
        self, clothing_context, mock_embedder, mock_vector_store
    ):
        extractor = AsyncMock()
        extractor.extract = AsyncMock(return_value=clothing_context)

        pipeline = _make_pipeline(
            extractor=extractor,
            embedder=mock_embedder,
            store=mock_vector_store,
        )

        item_id, context = await pipeline.ingest(
            image_source=b"fake_image_bytes",
            image_url="https://example.com/jacket.jpg",
            user_id="user-42",
        )

        # Stage 1: context extraction called
        extractor.extract.assert_called_once_with(b"fake_image_bytes")

        # Stage 2: embedding called with image + context
        mock_embedder.embed_item.assert_called_once()
        embed_args = mock_embedder.embed_item.call_args[0]
        assert embed_args[0] == b"fake_image_bytes"
        assert embed_args[1] == clothing_context

        # Stage 3: vector store upsert called
        mock_vector_store.upsert.assert_called_once()
        upsert_kwargs = mock_vector_store.upsert.call_args[1]
        assert upsert_kwargs["image_url"] == "https://example.com/jacket.jpg"
        assert upsert_kwargs["user_id"] == "user-42"

        # Return values
        assert context == clothing_context
        assert item_id is not None

    @pytest.mark.asyncio
    async def test_ingest_returns_context_from_extractor(self, medical_context):
        extractor = AsyncMock()
        extractor.extract = AsyncMock(return_value=medical_context)

        embedder = AsyncMock()
        embedder.embed_item = AsyncMock(return_value=[0.0] * 1024)

        store = AsyncMock()
        store.upsert = AsyncMock(return_value="item-id-123")

        pipeline = _make_pipeline(extractor=extractor, embedder=embedder, store=store)

        item_id, context = await pipeline.ingest(b"img")

        assert context.name == "Sterile Trauma Bandage"
        assert context.inferred_category == "medical"

    @pytest.mark.asyncio
    async def test_ingest_embedding_result_has_correct_dimension(self, clothing_context):
        extractor = AsyncMock()
        extractor.extract = AsyncMock(return_value=clothing_context)

        fake_vector = np.random.randn(1024).tolist()
        embedder = AsyncMock()
        embedder.embed_item = AsyncMock(return_value=fake_vector)

        store = AsyncMock()
        store.upsert = AsyncMock(return_value="id")

        pipeline = _make_pipeline(extractor=extractor, embedder=embedder, store=store)
        await pipeline.ingest(b"img")

        # Check the EmbeddingResult passed to store.upsert
        upsert_call = store.upsert.call_args
        result = upsert_call[0][0]  # first positional arg
        assert isinstance(result, EmbeddingResult)
        assert result.dimension == 1024
        assert len(result.vector) == 1024


# ---------------------------------------------------------------------------
# Search flow
# ---------------------------------------------------------------------------
class TestSearchFlow:
    @pytest.mark.asyncio
    async def test_search_without_synthesis(self, sample_retrieved_items):
        embedder = AsyncMock()
        embedder.embed_text = AsyncMock(return_value=[0.1] * 1024)

        store = AsyncMock()
        store.search = AsyncMock(return_value=sample_retrieved_items)

        synthesizer = AsyncMock()

        pipeline = _make_pipeline(embedder=embedder, store=store, synthesizer=synthesizer)

        results = await pipeline.search("cold weather gear", top_k=10, synthesize=False)

        # Embedder called
        embedder.embed_text.assert_called_once_with("cold weather gear")

        # Store searched
        store.search.assert_called_once()
        search_kwargs = store.search.call_args[1]
        assert search_kwargs["top_k"] == 10

        # Synthesizer NOT called
        synthesizer.synthesize.assert_not_called()

        # Returns raw list
        assert isinstance(results, list)
        assert len(results) == 4

    @pytest.mark.asyncio
    async def test_search_with_synthesis(self, sample_retrieved_items):
        embedder = AsyncMock()
        embedder.embed_text = AsyncMock(return_value=[0.1] * 1024)

        store = AsyncMock()
        store.search = AsyncMock(return_value=sample_retrieved_items)

        fake_plan = MissionPlan(
            mission_summary="Winter survival kit",
            selected_items=sample_retrieved_items[:2],
            rejected_items=sample_retrieved_items[2:],
        )
        synthesizer = AsyncMock()
        synthesizer.synthesize = AsyncMock(return_value=fake_plan)

        pipeline = _make_pipeline(embedder=embedder, store=store, synthesizer=synthesizer)

        result = await pipeline.search("cold weather gear", synthesize=True)

        # Synthesizer called with query + items
        synthesizer.synthesize.assert_called_once()
        assert isinstance(result, MissionPlan)
        assert len(result.selected_items) == 2

    @pytest.mark.asyncio
    async def test_search_with_category_filter(self):
        embedder = AsyncMock()
        embedder.embed_text = AsyncMock(return_value=[0.1] * 1024)

        store = AsyncMock()
        store.search = AsyncMock(return_value=[])

        pipeline = _make_pipeline(embedder=embedder, store=store)

        await pipeline.search("bandages", category_filter="medical", synthesize=False)

        search_kwargs = store.search.call_args[1]
        assert search_kwargs["category_filter"] == "medical"


# ---------------------------------------------------------------------------
# embed_query helper
# ---------------------------------------------------------------------------
class TestEmbedQuery:
    @pytest.mark.asyncio
    async def test_embed_query_delegates_to_embedder(self, mock_embedder):
        pipeline = _make_pipeline(embedder=mock_embedder)

        vec = await pipeline.embed_query("test query")

        mock_embedder.embed_text.assert_called_once_with("test query")
        assert len(vec) == 1024


# ---------------------------------------------------------------------------
# Data flow integrity
# ---------------------------------------------------------------------------
class TestDataFlowIntegrity:
    @pytest.mark.asyncio
    async def test_context_flows_from_extractor_to_embedder_to_store(self):
        """Verify the same ItemContext object flows through the full pipeline."""
        ctx = ItemContext(
            name="Tracking Test",
            inferred_category="tech",
            utility_summary="Used for tracking data flow",
            semantic_tags=["test"],
        )
        captured_contexts = []

        extractor = AsyncMock()
        extractor.extract = AsyncMock(return_value=ctx)

        async def capture_embed(img, context):
            captured_contexts.append(("embedder", context))
            return [0.0] * 1024

        embedder = AsyncMock()
        embedder.embed_item = AsyncMock(side_effect=capture_embed)

        captured_results = []

        async def capture_upsert(result, image_url="", user_id=None):
            captured_results.append(result)
            return result.item_id

        store = AsyncMock()
        store.upsert = AsyncMock(side_effect=capture_upsert)

        pipeline = _make_pipeline(extractor=extractor, embedder=embedder, store=store)
        await pipeline.ingest(b"img")

        # Embedder received the same context
        assert captured_contexts[0][1] is ctx

        # Store received an EmbeddingResult with that context
        assert captured_results[0].context is ctx
        assert captured_results[0].context.name == "Tracking Test"
