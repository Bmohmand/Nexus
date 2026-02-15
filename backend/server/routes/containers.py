"""
Manifest API — Storage Containers CRUD
GET    /api/v1/containers          -- List user's containers
POST   /api/v1/containers          -- Create a container
GET    /api/v1/containers/{id}     -- Get a single container
PATCH  /api/v1/containers/{id}     -- Update a container
DELETE /api/v1/containers/{id}     -- Delete a container
"""

import logging
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query
from supabase import Client

from ..dependencies import get_supabase
from ..schemas import (
    ContainerCreate,
    ContainerUpdate,
    ContainerResponse,
    ContainerListResponse,
)

logger = logging.getLogger("manifest.routes.containers")
router = APIRouter()

TABLE = "storage_containers"


def _row_to_response(row: dict) -> ContainerResponse:
    return ContainerResponse(
        id=str(row["id"]),
        name=row["name"],
        description=row.get("description"),
        container_type=row.get("container_type", "bag"),
        max_weight_grams=row["max_weight_grams"],
        max_volume_liters=row.get("max_volume_liters"),
        tare_weight_grams=row.get("tare_weight_grams", 0),
        quantity=row.get("quantity", 1),
        is_default=row.get("is_default", False),
        icon=row.get("icon"),
        color=row.get("color"),
        created_at=str(row.get("created_at", "")),
        updated_at=str(row.get("updated_at", "")),
    )


@router.get("/containers", response_model=ContainerListResponse)
async def list_containers(
    user_id: Optional[str] = Query(None),
    supabase: Client = Depends(get_supabase),
):
    """List all storage containers, optionally filtered by user."""
    try:
        query = supabase.table(TABLE).select("*")
        if user_id:
            query = query.eq("user_id", user_id)
        query = query.order("created_at", desc=True)
        response = query.execute()
        containers = [_row_to_response(r) for r in response.data]
        return ContainerListResponse(containers=containers, count=len(containers))
    except Exception as e:
        logger.error(f"List containers failed: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/containers", response_model=ContainerResponse, status_code=201)
async def create_container(
    body: ContainerCreate,
    supabase: Client = Depends(get_supabase),
):
    """Create a new storage container."""
    try:
        row = body.model_dump(exclude_none=True)
        response = supabase.table(TABLE).insert(row).execute()
        return _row_to_response(response.data[0])
    except Exception as e:
        logger.error(f"Create container failed: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/containers/{container_id}", response_model=ContainerResponse)
async def get_container(
    container_id: str,
    supabase: Client = Depends(get_supabase),
):
    """Get a single storage container by ID."""
    try:
        response = (
            supabase.table(TABLE)
            .select("*")
            .eq("id", container_id)
            .single()
            .execute()
        )
        return _row_to_response(response.data)
    except Exception:
        raise HTTPException(status_code=404, detail=f"Container not found: {container_id}")


@router.patch("/containers/{container_id}", response_model=ContainerResponse)
async def update_container(
    container_id: str,
    body: ContainerUpdate,
    supabase: Client = Depends(get_supabase),
):
    """Update fields on an existing storage container."""
    try:
        updates = body.model_dump(exclude_none=True)
        if not updates:
            raise HTTPException(status_code=400, detail="No fields to update")
        response = (
            supabase.table(TABLE)
            .update(updates)
            .eq("id", container_id)
            .execute()
        )
        if not response.data:
            raise HTTPException(status_code=404, detail="Container not found")
        return _row_to_response(response.data[0])
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Update container failed: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.delete("/containers/{container_id}")
async def delete_container(
    container_id: str,
    supabase: Client = Depends(get_supabase),
):
    """Delete a storage container."""
    try:
        supabase.table(TABLE).delete().eq("id", container_id).execute()
        return {"deleted": True, "container_id": container_id}
    except Exception as e:
        logger.error(f"Delete container failed: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))
