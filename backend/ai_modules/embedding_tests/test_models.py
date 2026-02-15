"""
Tests for ai_modules.models — Pydantic data models.

Validates serialization, defaults, field constraints, and round-trip
JSON encoding of ItemContext, EmbeddingResult, RetrievedItem, etc.
"""

import uuid
import json

import numpy as np
import pytest

from _import_helper import models

ItemContext = models.ItemContext
EmbeddingResult = models.EmbeddingResult
RetrievedItem = models.RetrievedItem
SearchQuery = models.SearchQuery
MissionPlan = models.MissionPlan


# ---------------------------------------------------------------------------
# ItemContext
# ---------------------------------------------------------------------------
class TestItemContext:
    def test_minimal_fields(self):
        """Only required fields — defaults should fill the rest."""
        ctx = ItemContext(
            name="Test Item",
            inferred_category="misc",
            utility_summary="A generic test item.",
        )
        assert ctx.name == "Test Item"
        assert ctx.primary_material is None
        assert ctx.weight_estimate is None
        assert ctx.thermal_rating is None
        assert ctx.water_resistance is None
        assert ctx.medical_application is None
        assert ctx.semantic_tags == []
        assert ctx.durability is None
        assert ctx.compressibility is None
        assert ctx.quantity == 1

    def test_full_fields(self, clothing_context):
        """All fields populated — should match fixture data."""
        ctx = clothing_context
        assert ctx.name == "Gore-Tex Rain Jacket"
        assert ctx.inferred_category == "clothing"
        assert ctx.primary_material == "Gore-Tex nylon"
        assert ctx.water_resistance == "waterproof"
        assert "waterproof" in ctx.semantic_tags

    def test_json_round_trip(self, medical_context):
        """Serialize to JSON and back — no data loss."""
        data = medical_context.model_dump()
        json_str = json.dumps(data)
        restored = ItemContext(**json.loads(json_str))
        assert restored == medical_context

    def test_semantic_tags_are_list(self):
        ctx = ItemContext(
            name="X",
            inferred_category="misc",
            utility_summary="X",
            semantic_tags=["a", "b"],
        )
        assert isinstance(ctx.semantic_tags, list)
        assert len(ctx.semantic_tags) == 2


# ---------------------------------------------------------------------------
# EmbeddingResult
# ---------------------------------------------------------------------------
class TestEmbeddingResult:
    def test_auto_uuid(self):
        """item_id should be auto-generated if not provided."""
        result = EmbeddingResult(
            vector=[0.0] * 512,
            dimension=512,
            context=ItemContext(
                name="X", inferred_category="misc", utility_summary="X"
            ),
        )
        assert result.item_id  # non-empty
        uuid.UUID(result.item_id)  # valid UUID

    def test_explicit_uuid(self):
        uid = str(uuid.uuid4())
        result = EmbeddingResult(
            item_id=uid,
            vector=[0.1] * 1024,
            dimension=1024,
            context=ItemContext(
                name="X", inferred_category="misc", utility_summary="X"
            ),
        )
        assert result.item_id == uid

    def test_vector_dimension_matches(self, sample_embedding_result):
        r = sample_embedding_result
        assert len(r.vector) == r.dimension


# ---------------------------------------------------------------------------
# SearchQuery
# ---------------------------------------------------------------------------
class TestSearchQuery:
    def test_defaults(self):
        q = SearchQuery(query_text="cold weather gear")
        assert q.top_k == 15
        assert q.category_filter is None

    def test_top_k_range(self):
        q = SearchQuery(query_text="test", top_k=50)
        assert q.top_k == 50

        with pytest.raises(Exception):
            SearchQuery(query_text="test", top_k=0)

        with pytest.raises(Exception):
            SearchQuery(query_text="test", top_k=51)


# ---------------------------------------------------------------------------
# RetrievedItem
# ---------------------------------------------------------------------------
class TestRetrievedItem:
    def test_score_field(self, sample_retrieved_items):
        for item in sample_retrieved_items:
            assert 0.0 <= item.score <= 1.0
            assert item.context is not None


# ---------------------------------------------------------------------------
# MissionPlan
# ---------------------------------------------------------------------------
class TestMissionPlan:
    def test_empty_plan(self):
        plan = MissionPlan(
            mission_summary="No items matched.",
            selected_items=[],
        )
        assert plan.warnings == []
        assert plan.rejected_items == []
        assert plan.reasoning == {}

    def test_plan_with_items(self, sample_retrieved_items):
        plan = MissionPlan(
            mission_summary="Cold weather kit",
            selected_items=sample_retrieved_items[:2],
            rejected_items=sample_retrieved_items[2:],
            reasoning={
                sample_retrieved_items[0].item_id: "Waterproof protection",
                sample_retrieved_items[1].item_id: "First aid requirement",
            },
            warnings=["No insulated footwear found"],
        )
        assert len(plan.selected_items) == 2
        assert len(plan.rejected_items) == 2
        assert len(plan.warnings) == 1
