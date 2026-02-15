"""
Manifest API — Items CRUD Routes
GET    /api/v1/items          — List items (with optional filters)
GET    /api/v1/items/{id}     — Get a single item
DELETE /api/v1/items/{id}     — Delete an item
GET    /api/v1/items/count    — Count items in database

These bypass the AI pipeline and go directly to Supabase for
basic inventory management operations.
"""

import logging
from fastapi import APIRouter, Depends, HTTPException, Query
from typing import Optional

from ..dependencies import get_supabase, get_pipeline
from ..schemas import ItemResponse, ItemListResponse
from supabase import Client
from ai_modules.pipeline import NexusPipeline

logger = logging.getLogger("manifest.routes.items")

router = APIRouter()


@router.get("/items", response_model=ItemListResponse)
async def list_items(
    domain: Optional[str] = Query(None, description="Filter by domain"),
    status: Optional[str] = Query(None, description="Filter by status"),
    user_id: Optional[str] = Query(None, description="Filter by user"),
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    supabase: Client = Depends(get_supabase),
):
    """List items from the manifest with optional filtering."""
    try:
        query = supabase.table("manifest_items").select("*")

        if domain:
            query = query.eq("domain", domain)
        if status:
            query = query.eq("status", status)
        if user_id:
            query = query.eq("user_id", user_id)

        query = query.order("created_at", desc=True)
        query = query.range(offset, offset + limit - 1)

        response = query.execute()

        items = []
        for row in response.data:
            items.append(ItemResponse(
                id=str(row["id"]),
                name=row.get("name", ""),
                image_url=row.get("image_url"),
                domain=row.get("domain", "general"),
                category=row.get("category"),
                status=row.get("status", "available"),
                quantity=row.get("quantity", 1),
                utility_summary=row.get("utility_summary"),
                semantic_tags=row.get("semantic_tags", []),
                weight_grams=row.get("weight_grams"),
                created_at=str(row.get("created_at", "")),
            ))

        return ItemListResponse(items=items, count=len(items))

    except Exception as e:
        logger.error(f"List items failed: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/items/count")
async def item_count(
    pipeline: NexusPipeline = Depends(get_pipeline),
):
    """Return the total number of items in the database."""
    try:
        count = await pipeline.item_count()
        return {"count": count}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/items/{item_id}", response_model=ItemResponse)
async def get_item(
    item_id: str,
    supabase: Client = Depends(get_supabase),
):
    """Get a single item by ID."""
    try:
        response = supabase.table("manifest_items").select("*").eq("id", item_id).single().execute()
        row = response.data

        return ItemResponse(
            id=str(row["id"]),
            name=row.get("name", ""),
            image_url=row.get("image_url"),
            domain=row.get("domain", "general"),
            category=row.get("category"),
            status=row.get("status", "available"),
            quantity=row.get("quantity", 1),
            utility_summary=row.get("utility_summary"),
            semantic_tags=row.get("semantic_tags", []),
            weight_grams=row.get("weight_grams"),
            created_at=str(row.get("created_at", "")),
        )

    except Exception as e:
        logger.error(f"Get item failed: {e}", exc_info=True)
        raise HTTPException(status_code=404, detail=f"Item not found: {item_id}")


@router.delete("/items/{item_id}")
async def delete_item(
    item_id: str,
    supabase: Client = Depends(get_supabase),
):
    """Delete an item from the manifest."""
    try:
        supabase.table("manifest_items").delete().eq("id", item_id).execute()
        return {"deleted": True, "item_id": item_id}

    except Exception as e:
        logger.error(f"Delete item failed: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))
