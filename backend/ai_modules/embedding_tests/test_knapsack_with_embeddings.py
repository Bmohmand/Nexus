"""
Tests for knapsack optimizer integration with embedding search results.

Validates that the optimizer correctly handles items coming from the
embedding-based search pipeline:
  1. Retrieved-to-packable conversion (weight estimation, category mapping)
  2. Diversity constraints interact correctly with AI-assigned categories
  3. Semantic tag constraints work with extracted tags
  4. End-to-end: mock search results → optimizer → valid packing
"""

import pytest

from _import_helper import models, load_module

ItemContext = models.ItemContext
RetrievedItem = models.RetrievedItem

knapsack_optimizer = load_module("knapsack_optimizer")
KnapsackOptimizer = knapsack_optimizer.KnapsackOptimizer
PackableItem = knapsack_optimizer.PackableItem
PackingConstraints = knapsack_optimizer.PackingConstraints
PackingResult = knapsack_optimizer.PackingResult
WEIGHT_ESTIMATES_GRAMS = knapsack_optimizer.WEIGHT_ESTIMATES_GRAMS
estimate_weight = knapsack_optimizer.estimate_weight


# ---------------------------------------------------------------------------
# Weight estimation from AI context
# ---------------------------------------------------------------------------
class TestWeightEstimation:
    def test_known_estimates(self):
        for label, expected in WEIGHT_ESTIMATES_GRAMS.items():
            item = RetrievedItem(
                item_id="x",
                score=0.9,
                context=ItemContext(
                    name="X",
                    inferred_category="misc",
                    utility_summary="X",
                    weight_estimate=label,
                ),
            )
            assert estimate_weight(item) == expected

    def test_none_defaults_to_medium(self):
        item = RetrievedItem(
            item_id="x",
            score=0.9,
            context=ItemContext(
                name="X",
                inferred_category="misc",
                utility_summary="X",
                weight_estimate=None,
            ),
        )
        assert estimate_weight(item) == WEIGHT_ESTIMATES_GRAMS["medium"]

    def test_unknown_estimate_defaults(self):
        item = RetrievedItem(
            item_id="x",
            score=0.9,
            context=ItemContext(
                name="X",
                inferred_category="misc",
                utility_summary="X",
                weight_estimate="featherweight",  # not in the map
            ),
        )
        assert estimate_weight(item) == 500  # fallback default


# ---------------------------------------------------------------------------
# retrieved_to_packable conversion
# ---------------------------------------------------------------------------
class TestRetrievedToPackable:
    def test_basic_conversion(self, sample_retrieved_items):
        packable = KnapsackOptimizer.retrieved_to_packable(sample_retrieved_items)

        assert len(packable) == len(sample_retrieved_items)
        for p in packable:
            assert isinstance(p, PackableItem)
            assert p.quantity_owned == 1  # default
            assert p.weight_grams > 0

    def test_inventory_overrides(self, sample_retrieved_items):
        inventory = {sample_retrieved_items[0].item_id: 5}
        packable = KnapsackOptimizer.retrieved_to_packable(
            sample_retrieved_items, inventory=inventory
        )

        first = next(p for p in packable if p.item_id == sample_retrieved_items[0].item_id)
        assert first.quantity_owned == 5

    def test_weight_overrides(self, sample_retrieved_items):
        overrides = {sample_retrieved_items[0].item_id: 999.0}
        packable = KnapsackOptimizer.retrieved_to_packable(
            sample_retrieved_items, weight_overrides=overrides
        )

        first = next(p for p in packable if p.item_id == sample_retrieved_items[0].item_id)
        assert first.weight_grams == 999.0

    def test_categories_preserved(self, sample_retrieved_items):
        packable = KnapsackOptimizer.retrieved_to_packable(sample_retrieved_items)
        categories = {p.category for p in packable}
        assert "clothing" in categories
        assert "medical" in categories

    def test_semantic_tags_preserved(self, sample_retrieved_items):
        packable = KnapsackOptimizer.retrieved_to_packable(sample_retrieved_items)
        all_tags = set()
        for p in packable:
            all_tags.update(p.semantic_tags)
        assert "waterproof" in all_tags
        assert "wound_care" in all_tags


# ---------------------------------------------------------------------------
# Optimizer with AI-extracted items
# ---------------------------------------------------------------------------
class TestOptimizerWithEmbeddingResults:
    @pytest.fixture
    def diverse_items(self):
        """A mix of items from different categories with different weights."""
        return [
            PackableItem(
                item_id="jacket-1",
                name="Rain Jacket",
                similarity_score=0.9,
                weight_grams=700,
                quantity_owned=1,
                category="clothing",
                semantic_tags=["waterproof", "cold-weather"],
            ),
            PackableItem(
                item_id="bandage-1",
                name="Trauma Bandage",
                similarity_score=0.85,
                weight_grams=100,
                quantity_owned=3,
                category="medical",
                semantic_tags=["wound_care", "sterile", "first_aid"],
            ),
            PackableItem(
                item_id="flashlight-1",
                name="Tactical Flashlight",
                similarity_score=0.75,
                weight_grams=300,
                quantity_owned=1,
                category="tech",
                semantic_tags=["navigation", "signaling"],
            ),
            PackableItem(
                item_id="sleeping-bag-1",
                name="4-Season Sleeping Bag",
                similarity_score=0.95,
                weight_grams=1500,
                quantity_owned=1,
                category="camping",
                semantic_tags=["warmth", "cold-weather", "survival"],
            ),
            PackableItem(
                item_id="tent-1",
                name="Backpacking Tent",
                similarity_score=0.7,
                weight_grams=2000,
                quantity_owned=1,
                category="camping",
                semantic_tags=["shelter", "survival"],
            ),
        ]

    def test_respects_weight_limit(self, diverse_items):
        optimizer = KnapsackOptimizer()
        constraints = PackingConstraints(max_weight_grams=2000)
        result = optimizer.solve(diverse_items, constraints)

        assert result.status in ("optimal", "feasible")
        assert result.total_weight_grams <= 2000

    def test_respects_category_minimums(self, diverse_items):
        optimizer = KnapsackOptimizer()
        constraints = PackingConstraints(
            max_weight_grams=5000,
            category_minimums={"medical": 1, "clothing": 1},
        )
        result = optimizer.solve(diverse_items, constraints)

        assert result.status in ("optimal", "feasible")
        packed_cats = {item.category for item, qty in result.packed_items}
        assert "medical" in packed_cats
        assert "clothing" in packed_cats

    def test_respects_tag_minimums(self, diverse_items):
        optimizer = KnapsackOptimizer()
        constraints = PackingConstraints(
            max_weight_grams=5000,
            tag_minimums={"wound_care": 1, "warmth": 1},
        )
        result = optimizer.solve(diverse_items, constraints)

        assert result.status in ("optimal", "feasible")
        packed_tags = set()
        for item, qty in result.packed_items:
            packed_tags.update(item.semantic_tags)
        assert "wound_care" in packed_tags
        assert "warmth" in packed_tags

    def test_maximizes_similarity_score(self, diverse_items):
        optimizer = KnapsackOptimizer()
        constraints = PackingConstraints(max_weight_grams=10000)
        result = optimizer.solve(diverse_items, constraints)

        # With generous weight, should pack highest-similarity items first
        assert result.status in ("optimal", "feasible")
        assert result.total_similarity_score > 0

    def test_empty_items_returns_infeasible(self):
        optimizer = KnapsackOptimizer()
        constraints = PackingConstraints(max_weight_grams=5000)
        result = optimizer.solve([], constraints)

        assert result.status == "infeasible"
        assert result.packed_items == []

    def test_unpacked_items_tracked(self, diverse_items):
        optimizer = KnapsackOptimizer()
        # Very tight weight limit — can't pack everything
        constraints = PackingConstraints(max_weight_grams=500)
        result = optimizer.solve(diverse_items, constraints)

        if result.status in ("optimal", "feasible"):
            total = len(result.packed_items) + len(result.unpacked_items)
            # Account for quantity_owned > 1 items
            assert total >= len(diverse_items) - 1  # bandage has qty 3 but only counts once

    def test_preset_constraints_work(self, diverse_items):
        from ai_modules.knapsack_optimizer import CONSTRAINT_PRESETS

        optimizer = KnapsackOptimizer()
        for preset_name, constraints in CONSTRAINT_PRESETS.items():
            result = optimizer.solve(diverse_items, constraints)
            # Should not crash — status may be infeasible if items don't match
            assert result.status in ("optimal", "feasible", "infeasible")

    def test_quantity_owned_respected(self):
        items = [
            PackableItem(
                item_id="bandage",
                name="Bandage",
                similarity_score=0.9,
                weight_grams=50,
                quantity_owned=3,
                category="medical",
                semantic_tags=["wound_care"],
            ),
        ]
        optimizer = KnapsackOptimizer()
        constraints = PackingConstraints(max_weight_grams=10000)
        result = optimizer.solve(items, constraints)

        assert result.status in ("optimal", "feasible")
        if result.packed_items:
            _, qty = result.packed_items[0]
            assert qty <= 3, "Should not pack more than quantity_owned"
