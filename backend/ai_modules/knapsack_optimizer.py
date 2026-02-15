"""
nexus_ai/knapsack_optimizer.py
===============================
The Intelligent Packing Engine.

Takes vector search results (scored by semantic similarity) and solves a
Bounded Knapsack Problem with Categorical Diversity Constraints using
Google OR-Tools CP-SAT solver.

Why this matters:
  - Greedy by similarity alone → 50 bottles of aspirin, zero blankets
  - This solver MAXIMIZES total mission relevance (similarity score)
    while GUARANTEEING weight limits and category diversity

The 3 constraint layers:
  1. Inventory Bounds:  0 <= x_i <= owned_quantity_i
  2. Weight Constraint:  sum(x_i * weight_i) <= max_weight
  3. Diversity Constraints:  sum(items_in_category_j) >= min_required_j

Called by: pipeline.py (after vector search, before/instead of LLM synthesis)
"""

import logging
from dataclasses import dataclass, field
from typing import Optional

from ortools.sat.python import cp_model

from .models import RetrievedItem

logger = logging.getLogger("nexus.optimizer")


# ---------------------------------------------------------------------------
# Data structures for the optimization problem
# ---------------------------------------------------------------------------
@dataclass
class PackableItem:
    """
    An item that can be packed, with physical properties.
    Built from a RetrievedItem + inventory/weight data.
    """
    item_id: str
    name: str
    similarity_score: float       # From Supabase vector search (0-1)
    weight_grams: float           # Physical weight per unit
    quantity_owned: int = 1       # How many the user actually has
    category: str = "misc"        # From AI context extraction
    semantic_tags: list[str] = field(default_factory=list)


@dataclass
class PackingConstraints:
    """
    The physical and logical constraints for a packing mission.
    Noah's UI collects these from the user.
    """
    max_weight_grams: float = 20_000  # Default 20kg (standard carry-on)

    # Category diversity minimums: {"medical": 2, "clothing": 3, ...}
    # "At least 2 medical items, at least 3 clothing items"
    category_minimums: dict[str, int] = field(default_factory=dict)

    # Category maximums: {"tech": 2, "food": 5}
    # "No more than 2 tech items" (prevents filling space with clutter)
    category_maximums: dict[str, int] = field(default_factory=dict)

    # Tag diversity minimums: {"wound_care": 1, "warmth": 2, ...}
    # More granular than categories — uses the semantic_tags from AI extraction
    tag_minimums: dict[str, int] = field(default_factory=dict)

    # Max items of any single type (prevents 50 aspirins)
    max_per_item: Optional[int] = None  # None = use quantity_owned as limit

    # Items that MUST be packed (by ID)
    pinned_items: list[str] = field(default_factory=list)


@dataclass
class PackingResult:
    """Output of the optimizer."""
    packed_items: list[tuple[PackableItem, int]]  # (item, quantity_to_pack)
    total_weight_grams: float
    total_similarity_score: float
    weight_utilization: float  # 0-1, how much of the weight budget is used
    status: str  # "optimal", "feasible", "infeasible"
    solver_time_ms: float

    # For the demo: items that were available but not selected
    unpacked_items: list[PackableItem] = field(default_factory=list)

    # Constraint violations that forced relaxation (if any)
    relaxed_constraints: list[str] = field(default_factory=list)


# ---------------------------------------------------------------------------
# Preset constraint profiles (for Noah's UI dropdown)
# ---------------------------------------------------------------------------
CONSTRAINT_PRESETS: dict[str, PackingConstraints] = {
    "carry_on_luggage": PackingConstraints(
        max_weight_grams=7_000,  # 7kg airline carry-on
        category_minimums={"clothing": 2},
    ),
    "checked_bag": PackingConstraints(
        max_weight_grams=23_000,  # 23kg standard checked bag
        category_minimums={"clothing": 3},
    ),
    "drone_delivery": PackingConstraints(
        max_weight_grams=5_000,  # 5kg typical drone payload
        category_minimums={"medical": 2},
        tag_minimums={"wound_care": 1, "warmth": 1},
        max_per_item=2,  # Drones need diversity, not bulk
    ),
    "medical_relief": PackingConstraints(
        max_weight_grams=30_000,  # 30kg relief crate
        category_minimums={"medical": 5, "camping": 2, "clothing": 2},
        tag_minimums={"wound_care": 2, "warmth": 2, "sterile": 1},
    ),
    "hiking_day_trip": PackingConstraints(
        max_weight_grams=10_000,  # 10kg daypack
        category_minimums={"medical": 1},
        tag_minimums={"first_aid": 1},
    ),
    "bug_out_bag": PackingConstraints(
        max_weight_grams=15_000,  # 15kg grab-and-go
        category_minimums={"medical": 2, "tech": 1, "camping": 2, "clothing": 1},
        tag_minimums={"warmth": 1, "wound_care": 1, "navigation": 1},
    ),
}


# ---------------------------------------------------------------------------
# Weight estimation from AI-extracted metadata
# ---------------------------------------------------------------------------
WEIGHT_ESTIMATES_GRAMS: dict[str, float] = {
    "ultralight": 100,
    "light": 300,
    "medium": 700,
    "heavy": 1500,
}


def estimate_weight(item: RetrievedItem) -> float:
    """
    Estimate weight from the AI's weight_estimate field.
    In production, you'd store actual weights. For the hackathon,
    the AI's estimate is good enough.
    """
    estimate = (item.context.weight_estimate or "medium").lower()
    return WEIGHT_ESTIMATES_GRAMS.get(estimate, 500)


# ---------------------------------------------------------------------------
# The Solver
# ---------------------------------------------------------------------------
class KnapsackOptimizer:
    """
    Solves the Bounded Knapsack Problem with diversity constraints
    using Google OR-Tools CP-SAT solver.

    Usage:
        optimizer = KnapsackOptimizer()
        result = optimizer.solve(packable_items, constraints)
    """

    def __init__(self, time_limit_seconds: float = 5.0):
        self.time_limit_seconds = time_limit_seconds

    def solve(
        self,
        items: list[PackableItem],
        constraints: PackingConstraints,
    ) -> PackingResult:
        """
        Solve the constrained packing optimization.

        Objective: MAXIMIZE sum(x_i * similarity_score_i)
        Subject to:
          - 0 <= x_i <= quantity_owned_i  (inventory bounds)
          - sum(x_i * weight_i) <= max_weight  (physical constraint)
          - sum(x_i for i in category_j) >= min_j  (diversity)

        Args:
            items: List of PackableItem from vector search results + inventory
            constraints: The mission's physical and diversity constraints

        Returns:
            PackingResult with optimal item selection
        """
        import time
        t0 = time.time()

        if not items:
            return PackingResult(
                packed_items=[], unpacked_items=[],
                total_weight_grams=0, total_similarity_score=0,
                weight_utilization=0, status="infeasible",
                solver_time_ms=0,
            )

        model = cp_model.CpModel()

        # ----- Decision variables -----
        # x_i = how many of item i to pack (integer)
        x = {}
        for i, item in enumerate(items):
            upper = item.quantity_owned
            if constraints.max_per_item is not None:
                upper = min(upper, constraints.max_per_item)
            x[i] = model.NewIntVar(0, upper, f"x_{i}")

        # ----- Constraint 1: Weight limit -----
        # Scale to integers for CP-SAT (it only does integer arithmetic)
        # Multiply weights and limit by 10 to preserve 1 decimal place
        SCALE = 10
        scaled_weights = [int(item.weight_grams * SCALE) for item in items]
        scaled_max = int(constraints.max_weight_grams * SCALE)

        model.Add(
            sum(x[i] * scaled_weights[i] for i in range(len(items)))
            <= scaled_max
        )

        # ----- Constraint 2: Category diversity minimums -----
        relaxed = []
        for cat, minimum in constraints.category_minimums.items():
            indices = [i for i, item in enumerate(items) if item.category == cat]
            if not indices:
                relaxed.append(f"No items available for category '{cat}' (need >={minimum})")
                continue
            # Can we even satisfy this? Check total available
            total_available = sum(items[i].quantity_owned for i in indices)
            effective_min = min(minimum, total_available)
            if effective_min < minimum:
                relaxed.append(
                    f"Category '{cat}': relaxed from >={minimum} to >={effective_min} "
                    f"(only {total_available} available)"
                )
            model.Add(sum(x[i] for i in indices) >= effective_min)

        # ----- Constraint 2b: Category maximums -----
        for cat, maximum in constraints.category_maximums.items():
            indices = [i for i, item in enumerate(items) if item.category == cat]
            if indices:
                # No need to relax maximums; just enforce them
                model.Add(sum(x[i] for i in indices) <= maximum)

        # ----- Constraint 3: Tag diversity minimums -----
        for tag, minimum in constraints.tag_minimums.items():
            indices = [
                i for i, item in enumerate(items)
                if tag in item.semantic_tags
            ]
            if not indices:
                relaxed.append(f"No items available for tag '{tag}' (need >={minimum})")
                continue
            total_available = sum(items[i].quantity_owned for i in indices)
            effective_min = min(minimum, total_available)
            if effective_min < minimum:
                relaxed.append(
                    f"Tag '{tag}': relaxed from >={minimum} to >={effective_min} "
                    f"(only {total_available} available)"
                )
            model.Add(sum(x[i] for i in indices) >= effective_min)

        # ----- Constraint 5: Pinned items (Must Haves) -----
        for pinned_id in constraints.pinned_items:
            indices = [i for i, item in enumerate(items) if item.item_id == pinned_id]
            if indices:
                model.Add(sum(x[i] for i in indices) >= 1)
            else:
                relaxed.append(f"Pinned item {pinned_id} not found in candidates")

        # ----- Objective: Maximize total similarity score; favor more items when similar -----
        # Small per-item bonus (epsilon) so that under the same weight cap, more items can beat fewer
        SCORE_SCALE = 10000
        EPSILON = 0.001  # Relevance still dominates; count breaks ties
        scaled_scores = [
            int((item.similarity_score + EPSILON) * SCORE_SCALE) for item in items
        ]
        model.Maximize(
            sum(x[i] * scaled_scores[i] for i in range(len(items)))
        )

        # ----- Solve -----
        solver = cp_model.CpSolver()
        solver.parameters.max_time_in_seconds = self.time_limit_seconds
        status = solver.Solve(model)

        solve_time = (time.time() - t0) * 1000  # ms

        # ----- Extract results -----
        if status in (cp_model.OPTIMAL, cp_model.FEASIBLE):
            packed = []
            unpacked = []
            total_weight = 0
            total_score = 0

            for i, item in enumerate(items):
                qty = solver.Value(x[i])
                if qty > 0:
                    packed.append((item, qty))
                    total_weight += item.weight_grams * qty
                    total_score += item.similarity_score * qty
                else:
                    unpacked.append(item)

            status_str = "optimal" if status == cp_model.OPTIMAL else "feasible"
            utilization = total_weight / constraints.max_weight_grams if constraints.max_weight_grams > 0 else 0

            logger.info(
                f"Solver: {status_str} | "
                f"{len(packed)} items packed | "
                f"{total_weight:.0f}g / {constraints.max_weight_grams:.0f}g "
                f"({utilization:.0%}) | "
                f"score={total_score:.3f} | "
                f"{solve_time:.1f}ms"
            )

            return PackingResult(
                packed_items=packed,
                unpacked_items=unpacked,
                total_weight_grams=total_weight,
                total_similarity_score=total_score,
                weight_utilization=utilization,
                status=status_str,
                solver_time_ms=solve_time,
                relaxed_constraints=relaxed,
            )
        else:
            logger.warning(f"Solver: INFEASIBLE after {solve_time:.1f}ms")
            return PackingResult(
                packed_items=[],
                unpacked_items=items,
                total_weight_grams=0,
                total_similarity_score=0,
                weight_utilization=0,
                status="infeasible",
                solver_time_ms=solve_time,
                relaxed_constraints=relaxed + ["Problem is infeasible — try relaxing weight or diversity constraints"],
            )

    @staticmethod
    def retrieved_to_packable(
        items: list[RetrievedItem],
        inventory: Optional[dict[str, int]] = None,
        weight_overrides: Optional[dict[str, float]] = None,
    ) -> list[PackableItem]:
        """
        Convert RetrievedItems from vector search into PackableItems
        for the optimizer.

        Args:
            items: Results from Supabase vector search
            inventory: Optional {item_id: quantity_owned} map.
                       If None, assumes 1 of each (typical for personal items).
            weight_overrides: Optional {item_id: weight_grams} for known weights.
                              Falls back to AI estimate if not provided.
        """
        packable = []
        for item in items:
            weight = (
                (weight_overrides.get(item.item_id) if weight_overrides else None)
                or getattr(item, "weight_grams", None)
            ) or estimate_weight(item)
            
            qty = (
                inventory.get(item.item_id, 1)
                if inventory else 1
            )

            packable.append(PackableItem(
                item_id=item.item_id,
                name=item.context.name,
                similarity_score=item.score,
                weight_grams=weight,
                quantity_owned=qty,
                category=item.context.inferred_category,
                semantic_tags=item.context.semantic_tags,
            ))
        return packable
