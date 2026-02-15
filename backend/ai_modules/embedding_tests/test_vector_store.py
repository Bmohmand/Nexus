"""
Tests for ai_modules.vector_store — Supabase pgvector integration.

All Supabase calls are mocked. Tests cover:
  1. upsert() — correct row shape, domain inference, field mapping
  2. search() — RPC call format, result parsing, score ordering
  3. delete() / count()
  4. _infer_domain() — category-to-domain mapping
"""

import uuid
from unittest.mock import MagicMock, patch, AsyncMock

import numpy as np
import pytest

from _import_helper import models, load_module

ItemContext = models.ItemContext
EmbeddingResult = models.EmbeddingResult
RetrievedItem = models.RetrievedItem

vector_store = load_module("vector_store")
SupabaseVectorStore = vector_store.SupabaseVectorStore
TABLE_NAME = vector_store.TABLE_NAME
RPC_NAME = vector_store.RPC_NAME


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
def _make_mock_supabase():
    """Build a mock Supabase client with chained method support."""
    client = MagicMock()

    # .table(name).upsert(row).execute()
    table_mock = MagicMock()
    upsert_mock = MagicMock()
    exec_mock = MagicMock()
    exec_mock.execute = MagicMock(return_value=MagicMock(data=[{"id": "test-id"}]))
    upsert_mock.upsert = MagicMock(return_value=exec_mock)
    table_mock.return_value = upsert_mock
    client.table = table_mock

    # .rpc(name, params).execute()
    rpc_mock = MagicMock()
    client.rpc = MagicMock(return_value=rpc_mock)

    return client


def _make_store(mock_client=None):
    """Create a SupabaseVectorStore with a mocked Supabase client."""
    with patch("ai_modules.vector_store.create_client") as mock_create:
        mock_create.return_value = mock_client or _make_mock_supabase()
        store = SupabaseVectorStore(url="https://fake.supabase.co", key="fake-key")
    return store


# ---------------------------------------------------------------------------
# Domain inference (static method, no mock needed)
# ---------------------------------------------------------------------------
class TestInferDomain:
    def test_known_categories(self):
        assert SupabaseVectorStore._infer_domain("clothing") == "clothing"
        assert SupabaseVectorStore._infer_domain("medical") == "medical"
        assert SupabaseVectorStore._infer_domain("tech") == "tech"
        assert SupabaseVectorStore._infer_domain("camping") == "camping"
        assert SupabaseVectorStore._infer_domain("food") == "food"

    def test_case_insensitive(self):
        assert SupabaseVectorStore._infer_domain("CLOTHING") == "clothing"
        assert SupabaseVectorStore._infer_domain("Medical") == "medical"

    def test_unknown_falls_to_general(self):
        assert SupabaseVectorStore._infer_domain("random") == "general"
        assert SupabaseVectorStore._infer_domain("") == "general"

    def test_none_input(self):
        assert SupabaseVectorStore._infer_domain(None) == "general"


# ---------------------------------------------------------------------------
# Upsert
# ---------------------------------------------------------------------------
class TestUpsert:
    @pytest.mark.asyncio
    async def test_upsert_builds_correct_row(self, sample_embedding_result):
        mock_client = _make_mock_supabase()
        store = _make_store(mock_client)

        item_id = await store.upsert(
            sample_embedding_result,
            image_url="https://example.com/img.jpg",
            user_id="user-123",
        )

        assert item_id == sample_embedding_result.item_id

        # Verify .table(TABLE_NAME) was called
        mock_client.table.assert_called_with(TABLE_NAME)

        # Verify the row passed to upsert
        upsert_call = mock_client.table.return_value.upsert
        upsert_call.assert_called_once()
        row = upsert_call.call_args[0][0]

        assert row["id"] == sample_embedding_result.item_id
        assert row["name"] == "Gore-Tex Rain Jacket"
        assert row["category"] == "clothing"
        assert row["domain"] == "clothing"
        assert row["image_url"] == "https://example.com/img.jpg"
        assert row["user_id"] == "user-123"
        assert row["embedding"] == sample_embedding_result.vector

    @pytest.mark.asyncio
    async def test_upsert_without_user_id(self, sample_embedding_result):
        mock_client = _make_mock_supabase()
        store = _make_store(mock_client)

        await store.upsert(sample_embedding_result)

        row = mock_client.table.return_value.upsert.call_args[0][0]
        assert "user_id" not in row

    @pytest.mark.asyncio
    async def test_upsert_maps_all_context_fields(self, medical_context):
        result = EmbeddingResult(
            vector=[0.0] * 1024,
            dimension=1024,
            context=medical_context,
        )
        mock_client = _make_mock_supabase()
        store = _make_store(mock_client)

        await store.upsert(result)

        row = mock_client.table.return_value.upsert.call_args[0][0]
        assert row["primary_material"] == "cotton gauze"
        assert row["weight_estimate"] == "ultralight"
        assert row["thermal_rating"] == "neutral"
        assert row["water_resistance"] == "not water-resistant"
        assert row["medical_application"] == "wound_care"
        assert row["durability"] == "disposable"
        assert row["compressibility"] == "highly_compressible"
        assert "wound_care" in row["semantic_tags"]


# ---------------------------------------------------------------------------
# Search
# ---------------------------------------------------------------------------
class TestSearch:
    def _setup_search_response(self, mock_client, rows):
        """Configure the mock to return specific rows from RPC."""
        rpc_result = MagicMock()
        rpc_result.execute.return_value = MagicMock(data=rows)
        mock_client.rpc.return_value = rpc_result

    @pytest.mark.asyncio
    async def test_search_calls_rpc_correctly(self):
        mock_client = _make_mock_supabase()
        store = _make_store(mock_client)

        self._setup_search_response(mock_client, [])

        query_vec = [0.1] * 1024
        await store.search(query_vec, top_k=10, category_filter="medical")

        mock_client.rpc.assert_called_once_with(
            RPC_NAME,
            {
                "query_embedding": query_vec,
                "match_count": 10,
                "filter_category": "medical",
            },
        )

    @pytest.mark.asyncio
    async def test_search_parses_results(self):
        mock_client = _make_mock_supabase()
        store = _make_store(mock_client)

        fake_rows = [
            {
                "id": str(uuid.uuid4()),
                "similarity": 0.92,
                "image_url": "https://example.com/jacket.jpg",
                "name": "Rain Jacket",
                "category": "clothing",
                "primary_material": "nylon",
                "weight_estimate": "medium",
                "thermal_rating": "neutral",
                "water_resistance": "waterproof",
                "medical_application": None,
                "utility_summary": "Keeps you dry",
                "semantic_tags": ["waterproof", "rain"],
                "durability": "rugged",
                "compressibility": "moderate",
            },
            {
                "id": str(uuid.uuid4()),
                "similarity": 0.85,
                "image_url": None,
                "name": "Bandage",
                "category": "medical",
                "primary_material": None,
                "weight_estimate": None,
                "thermal_rating": None,
                "water_resistance": None,
                "medical_application": "wound_care",
                "utility_summary": "First aid",
                "semantic_tags": [],
                "durability": None,
                "compressibility": None,
            },
        ]
        self._setup_search_response(mock_client, fake_rows)

        results = await store.search([0.1] * 1024, top_k=5)

        assert len(results) == 2
        assert results[0].score == 0.92
        assert results[0].context.name == "Rain Jacket"
        assert results[0].context.water_resistance == "waterproof"
        assert results[1].score == 0.85
        assert results[1].context.medical_application == "wound_care"

    @pytest.mark.asyncio
    async def test_search_empty_results(self):
        mock_client = _make_mock_supabase()
        store = _make_store(mock_client)
        self._setup_search_response(mock_client, [])

        results = await store.search([0.1] * 1024)
        assert results == []


# ---------------------------------------------------------------------------
# Delete & Count
# ---------------------------------------------------------------------------
class TestDeleteAndCount:
    @pytest.mark.asyncio
    async def test_delete_calls_correct_table(self):
        mock_client = _make_mock_supabase()
        store = _make_store(mock_client)

        # Chain: .table(TABLE_NAME).delete().eq("id", item_id).execute()
        delete_chain = MagicMock()
        eq_chain = MagicMock()
        eq_chain.execute = MagicMock()
        delete_chain.eq = MagicMock(return_value=eq_chain)
        mock_client.table.return_value.delete = MagicMock(return_value=delete_chain)

        await store.delete("test-id-123")

        mock_client.table.assert_called_with(TABLE_NAME)
        delete_chain.eq.assert_called_with("id", "test-id-123")

    @pytest.mark.asyncio
    async def test_count(self):
        mock_client = _make_mock_supabase()
        store = _make_store(mock_client)

        select_chain = MagicMock()
        exec_result = MagicMock(count=42)
        select_chain.execute = MagicMock(return_value=exec_result)
        mock_client.table.return_value.select = MagicMock(return_value=select_chain)

        result = await store.count()
        assert result == 42
