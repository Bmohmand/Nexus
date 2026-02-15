"""
Tests for ai_modules.embedding_engine — embedding providers and factory.

Tests cover:
  1. VoyageEmbedder (mocked API calls)
  2. create_embedder factory
  3. Embedding vector properties (dimension, normalization, determinism)
  4. Context text serialization
"""

import uuid
from unittest.mock import AsyncMock, MagicMock, patch, PropertyMock

import numpy as np
import pytest

from _import_helper import models, config, load_module

ItemContext = models.ItemContext
EmbeddingProvider = config.EmbeddingProvider

# Load embedding_engine (depends on voyageai being installed)
embedding_engine = load_module("embedding_engine")
VoyageEmbedder = embedding_engine.VoyageEmbedder
create_embedder = embedding_engine.create_embedder


# ---------------------------------------------------------------------------
# VoyageEmbedder — context text builder
# ---------------------------------------------------------------------------
class TestVoyageContextText:
    """Test the static _build_context_text method (no API call)."""

    def test_basic_fields(self, clothing_context):
        text = VoyageEmbedder._build_context_text(clothing_context)
        assert "Gore-Tex Rain Jacket" in text
        assert "clothing" in text
        assert "waterproof" in text.lower()

    def test_optional_fields_included(self, medical_context):
        text = VoyageEmbedder._build_context_text(medical_context)
        assert "wound_care" in text
        assert "cotton gauze" in text

    def test_optional_fields_omitted(self):
        ctx = ItemContext(
            name="Generic",
            inferred_category="misc",
            utility_summary="A thing.",
        )
        text = VoyageEmbedder._build_context_text(ctx)
        assert "Generic" in text
        assert "Material" not in text  # primary_material is None
        assert "Thermal" not in text
        assert "Medical" not in text

    def test_tags_joined(self, camping_context):
        text = VoyageEmbedder._build_context_text(camping_context)
        assert "warmth" in text
        assert "cold-weather" in text


# ---------------------------------------------------------------------------
# VoyageEmbedder — mocked API
# ---------------------------------------------------------------------------
class TestVoyageEmbedder:
    @pytest.fixture
    def mock_voyage_client(self):
        """Mock the voyageai.AsyncClient."""
        client = AsyncMock()
        fake_result = MagicMock()
        fake_result.embeddings = [np.random.randn(1024).tolist()]
        client.multimodal_embed = AsyncMock(return_value=fake_result)
        return client

    @pytest.mark.asyncio
    async def test_embed_item_calls_api(self, mock_voyage_client, clothing_context):
        embedder = VoyageEmbedder.__new__(VoyageEmbedder)
        embedder.client = mock_voyage_client
        embedder._dimension = 1024

        vector = await embedder.embed_item("https://example.com/img.jpg", clothing_context)

        assert len(vector) == 1024
        mock_voyage_client.multimodal_embed.assert_called_once()
        call_kwargs = mock_voyage_client.multimodal_embed.call_args
        assert call_kwargs.kwargs["input_type"] == "document"

    @pytest.mark.asyncio
    async def test_embed_text_calls_api_as_query(self, mock_voyage_client):
        embedder = VoyageEmbedder.__new__(VoyageEmbedder)
        embedder.client = mock_voyage_client
        embedder._dimension = 1024

        vector = await embedder.embed_text("cold survival gear")

        assert len(vector) == 1024
        call_kwargs = mock_voyage_client.multimodal_embed.call_args
        assert call_kwargs.kwargs["input_type"] == "query"

    def test_dimension_property(self):
        embedder = VoyageEmbedder.__new__(VoyageEmbedder)
        embedder._dimension = 1024
        assert embedder.dimension == 1024

        embedder._dimension = 512
        assert embedder.dimension == 512


# ---------------------------------------------------------------------------
# create_embedder factory
# ---------------------------------------------------------------------------
class TestCreateEmbedder:
    @patch("ai_modules.embedding_engine.VoyageEmbedder")
    def test_voyage_provider(self, mock_cls):
        mock_cls.return_value = MagicMock()
        embedder = create_embedder(EmbeddingProvider.VOYAGE)
        mock_cls.assert_called_once()

    @patch("ai_modules.embedding_engine.CLIPEmbedder")
    def test_clip_provider(self, mock_cls):
        mock_cls.return_value = MagicMock()
        embedder = create_embedder(EmbeddingProvider.CLIP_LOCAL)
        mock_cls.assert_called_once()

    def test_unknown_provider_raises(self):
        with pytest.raises(ValueError, match="Unknown embedding provider"):
            create_embedder("nonexistent_provider")


# ---------------------------------------------------------------------------
# Embedding vector quality (using the mock embedder fixture)
# ---------------------------------------------------------------------------
class TestEmbeddingVectorProperties:
    @pytest.mark.asyncio
    async def test_vector_dimension(self, mock_embedder, clothing_context):
        vec = await mock_embedder.embed_item(b"fake_image", clothing_context)
        assert len(vec) == 1024

    @pytest.mark.asyncio
    async def test_vector_is_normalized(self, mock_embedder, clothing_context):
        vec = await mock_embedder.embed_item(b"fake_image", clothing_context)
        norm = np.linalg.norm(vec)
        assert abs(norm - 1.0) < 1e-5, f"Expected unit vector, got norm={norm}"

    @pytest.mark.asyncio
    async def test_deterministic_for_same_input(self, mock_embedder, clothing_context):
        vec1 = await mock_embedder.embed_item(b"img", clothing_context)
        vec2 = await mock_embedder.embed_item(b"img", clothing_context)
        np.testing.assert_array_almost_equal(vec1, vec2)

    @pytest.mark.asyncio
    async def test_different_inputs_differ(self, mock_embedder, clothing_context, medical_context):
        vec1 = await mock_embedder.embed_item(b"img", clothing_context)
        vec2 = await mock_embedder.embed_item(b"img", medical_context)
        sim = np.dot(vec1, vec2)
        assert sim < 0.99, "Different contexts should produce different embeddings"

    @pytest.mark.asyncio
    async def test_text_embedding_dimension(self, mock_embedder):
        vec = await mock_embedder.embed_text("warm winter jacket")
        assert len(vec) == 1024
