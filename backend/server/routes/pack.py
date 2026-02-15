"""
Manifest API — Pack Routes
POST /api/v1/pack        — Single-knapsack packing
POST /api/v1/pack/multi  — Multi-container bin-packing

Runs the full pipeline: semantic search -> knapsack optimization -> LLM explanation.
Returns the optimal packing manifest for a given mission and constraints.
"""

import logging
from fastapi import APIRouter, Depends, HTTPException
from supabase import Client

from ..dependencies import get_pipeline, get_supabase
from ..schemas import (
    PackRequest, PackResponse, PackedItem, PackConstraints,
    MultiPackRequest, MultiPackResponse, ContainerPackedItems,
)
from ai_modules.pipeline import NexusPipeline
from ai_modules.knapsack_optimizer import PackingConstraints, ContainerSpec

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

        # Run optimization, optionally with LLM explanation
        mission_summary = None
        warnings = []
        if request.explain:
            packing_result, plan = await pipeline.pack_and_explain(
                query=request.query,
                constraints=constraints,
                top_k=request.top_k,
            )
            mission_summary = plan.mission_summary
            warnings = plan.warnings
        else:
            packing_result = await pipeline.pack(
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
            mission_summary=mission_summary,
            warnings=warnings,
        )

    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        logger.error(f"Pack failed: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Pack failed: {str(e)}")


@router.post("/pack/multi", response_model=MultiPackResponse)
async def pack_multi_container(
    request: MultiPackRequest,
    pipeline: NexusPipeline = Depends(get_pipeline),
    supabase: Client = Depends(get_supabase),
):
    """
    Multi-container bin-packing: distribute items across user-selected containers.

    Fetches container details from Supabase, builds per-container weight limits,
    then runs the multi-knapsack optimizer to assign items to containers.
    """
    try:
        logger.info(
            f"PackMulti: '{request.query[:80]}' | "
            f"{len(request.container_ids)} containers | top_k={request.top_k}"
        )

        # 1. Fetch container details from Supabase
        containers_resp = (
            supabase.table("storage_containers")
            .select("*")
            .in_("id", request.container_ids)
            .execute()
        )
        if not containers_resp.data:
            raise HTTPException(status_code=404, detail="No containers found for the given IDs")

        # 2. Build ContainerSpec list, expanding quantity > 1 and applying tare weight
        container_specs = []
        for c in containers_resp.data:
            qty = c.get("quantity", 1)
            effective_capacity = c["max_weight_grams"] - c.get("tare_weight_grams", 0)
            if effective_capacity <= 0:
                continue
            for unit in range(qty):
                name = c["name"] if qty == 1 else f"{c['name']} #{unit + 1}"
                container_specs.append(ContainerSpec(
                    container_id=str(c["id"]),
                    name=name,
                    max_weight_grams=effective_capacity,
                ))

        if not container_specs:
            raise HTTPException(
                status_code=400,
                detail="All containers have zero or negative effective capacity (tare >= max)"
            )

        # 3. Resolve optional diversity constraints
        diversity_constraints = None
        if request.constraints:
            diversity_constraints = _to_packing_constraints(request.constraints)

        # 4. Run the multi-container pack pipeline
        mission_summary = None
        warnings = []
        if request.explain:
            result, plan = await pipeline.pack_multi_and_explain(
                query=request.query,
                container_specs=container_specs,
                diversity_constraints=diversity_constraints,
                top_k=request.top_k,
                category_filter=request.category_filter,
            )
            mission_summary = plan.mission_summary
            warnings = plan.warnings
        else:
            result = await pipeline.pack_multi(
                query=request.query,
                container_specs=container_specs,
                diversity_constraints=diversity_constraints,
                top_k=request.top_k,
                category_filter=request.category_filter,
            )

        # 5. Build response
        container_results = []
        for cr in result.container_results:
            packed = []
            for item, qty in cr.packed_items:
                packed.append(PackedItem(
                    item_id=item.item_id,
                    name=item.name,
                    category=item.category,
                    quantity=qty,
                    weight_grams=item.weight_grams,
                    similarity_score=item.similarity_score,
                    semantic_tags=item.semantic_tags,
                ))
            container_results.append(ContainerPackedItems(
                container_id=cr.container_id,
                container_name=cr.container_name,
                max_weight_grams=cr.max_weight_grams,
                packed_items=packed,
                total_weight_grams=cr.total_weight_grams,
                weight_utilization=cr.weight_utilization,
            ))

        unpacked = [
            PackedItem(
                item_id=item.item_id,
                name=item.name,
                category=item.category,
                quantity=1,
                weight_grams=item.weight_grams,
                similarity_score=item.similarity_score,
                semantic_tags=item.semantic_tags,
            )
            for item in result.unpacked_items
        ]

        return MultiPackResponse(
            status=result.status,
            containers=container_results,
            total_weight_grams=result.total_weight_grams,
            total_similarity_score=result.total_similarity_score,
            solver_time_ms=result.solver_time_ms,
            relaxed_constraints=result.relaxed_constraints,
            unpacked_items=unpacked,
            mission_summary=mission_summary,
            warnings=warnings,
        )

    except HTTPException:
        raise
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        logger.error(f"PackMulti failed: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Multi-pack failed: {str(e)}")
