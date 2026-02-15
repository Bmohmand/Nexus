"""
Manifest API — Search Route
POST /api/v1/search

Takes a natural language query and returns semantically similar items
from the vector store, optionally synthesized into a mission plan by the LLM.
"""

import logging
from fastapi import APIRouter, Depends, HTTPException

from ..dependencies import get_pipeline
from ..schemas import SearchRequest, SearchResponse, SearchResultItem
from ai_modules.pipeline import NexusPipeline
from ai_modules.models import MissionPlan, RetrievedItem

logger = logging.getLogger("manifest.routes.search")

router = APIRouter()


def _retrieved_to_result(item: RetrievedItem, reason: str = None) -> SearchResultItem:
    """Convert internal RetrievedItem to API response model."""
    return SearchResultItem(
        item_id=item.item_id,
        name=item.context.name,
        score=item.score,
        image_url=item.image_url,
        category=item.context.inferred_category,
        utility_summary=item.context.utility_summary,
        semantic_tags=item.context.semantic_tags,
        reason=reason,
    )


@router.post("/search", response_model=SearchResponse)
async def search_items(
    request: SearchRequest,
    pipeline: NexusPipeline = Depends(get_pipeline),
):
    """
    Semantic search across the manifest item database.

    With synthesize=True (default): returns an LLM-curated mission plan
    with selected items, rejected items, and reasoning.

    With synthesize=False: returns raw vector search results ranked by similarity.
    """
    try:
        logger.info(f"Search: '{request.query[:80]}' | top_k={request.top_k} | synthesize={request.synthesize}")

        result = await pipeline.search(
            query=request.query,
            top_k=request.top_k,
            category_filter=request.category_filter,
            synthesize=request.synthesize,
        )

        if request.synthesize and isinstance(result, MissionPlan):
            plan: MissionPlan = result
            return SearchResponse(
                mission_summary=plan.mission_summary,
                selected_items=[
                    _retrieved_to_result(item, plan.reasoning.get(item.item_id))
                    for item in plan.selected_items
                ],
                rejected_items=[
                    _retrieved_to_result(item, plan.reasoning.get(item.item_id))
                    for item in plan.rejected_items
                ],
                warnings=plan.warnings,
            )
        else:
            # Raw results (list of RetrievedItem)
            items = result if isinstance(result, list) else []
            return SearchResponse(
                raw_results=[_retrieved_to_result(item) for item in items],
            )

    except Exception as e:
        logger.error(f"Search failed: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Search failed: {str(e)}")
