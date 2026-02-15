"""
Manifest API — Pack Route
POST /api/v1/pack

Runs the full pipeline: semantic search -> knapsack optimization -> LLM explanation.
Returns the optimal packing manifest for a given mission and constraints.
"""

import logging
from fastapi import APIRouter, Depends, HTTPException

from ..dependencies import get_pipeline
from ..schemas import PackRequest, PackResponse, PackedItem, PackConstraints
from ai_modules.pipeline import NexusPipeline
from ai_modules.knapsack_optimizer import PackingConstraints

logger = logging.getLogger("manifest.routes.pack")

router = APIRouter()


def _to_packing_constraints(c: PackConstraints) -> PackingConstraints:
    """Convert API schema to internal knapsack constraints."""
    return PackingConstraints(
        max_weight_grams=c.max_weight_grams,
        category_minimums=c.category_minimums,
        tag_minimums=c.tag_minimums,
        max_per_item=c.max_per_item,
    )


@router.post("/pack", response_model=PackResponse)
async def pack_mission(
    request: PackRequest,
    pipeline: NexusPipeline = Depends(get_pipeline),
):
    """
    Run the full Manifest pipeline: semantic search + knapsack optimization + LLM explanation.

    Accepts either:
    - A constraint preset name (string): "carry_on_luggage", "drone_delivery", etc.
    - A custom PackConstraints object with specific limits.
    """
    try:
        logger.info(f"Pack: '{request.query[:80]}' | top_k={request.top_k}")

        # Resolve constraints
        if isinstance(request.constraints, str):
            constraints = request.constraints  # Pipeline resolves presets
        else:
            constraints = _to_packing_constraints(request.constraints)

        # Run optimization + LLM explanation
        packing_result, plan = await pipeline.pack_and_explain(
            query=request.query,
            constraints=constraints,
            top_k=request.top_k,
        )

        # Build response
        packed_items = []
        for item, qty in packing_result.packed_items:
            packed_items.append(PackedItem(
                item_id=item.item_id,
                name=item.name,
                category=item.category,
                quantity=qty,
                weight_grams=item.weight_grams,
                similarity_score=item.similarity_score,
                semantic_tags=item.semantic_tags,
            ))

        return PackResponse(
            status=packing_result.status,
            packed_items=packed_items,
            total_weight_grams=packing_result.total_weight_grams,
            total_similarity_score=packing_result.total_similarity_score,
            weight_utilization=packing_result.weight_utilization,
            solver_time_ms=packing_result.solver_time_ms,
            relaxed_constraints=packing_result.relaxed_constraints,
            mission_summary=plan.mission_summary,
            warnings=plan.warnings,
        )

    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        logger.error(f"Pack failed: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Pack failed: {str(e)}")
