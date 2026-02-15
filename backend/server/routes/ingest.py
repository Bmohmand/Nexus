"""
Manifest API — Ingest Route
POST /api/v1/ingest

Takes an image URL, runs the full AI pipeline (context extraction ->
embedding -> Supabase upsert), and returns the created item.
"""

import logging
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Form
from typing import Optional

from ..dependencies import get_pipeline
from ..schemas import IngestRequest, IngestResponse
from ai_modules.pipeline import NexusPipeline

logger = logging.getLogger("manifest.routes.ingest")

router = APIRouter()


@router.post("/ingest", response_model=IngestResponse)
async def ingest_item(
    request: IngestRequest,
    pipeline: NexusPipeline = Depends(get_pipeline),
):
    """
    Ingest an item by image URL.

    Flow: image_url -> GPT-5 Vision context extraction -> Voyage embedding -> Supabase upsert
    """
    try:
        logger.info(f"Ingesting item from URL: {request.image_url[:80]}...")

        # Run the full pipeline (extract + embed + upsert)
        item_id, context = await pipeline.ingest(
            image_source=request.image_url,
            image_url=request.image_url,
            user_id=request.user_id,
        )

        return IngestResponse(
            item_id=item_id,
            name=context.name,
            domain=context.inferred_category,
            category=context.inferred_category,
            utility_summary=context.utility_summary,
            semantic_tags=context.semantic_tags,
        )

    except Exception as e:
        logger.error(f"Ingest failed: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Ingest failed: {str(e)}")


@router.post("/ingest/upload", response_model=IngestResponse)
async def ingest_upload(
    file: UploadFile = File(...),
    user_id: Optional[str] = Form(None),
    pipeline: NexusPipeline = Depends(get_pipeline),
):
    """
    Ingest an item by direct file upload (multipart/form-data).

    The image bytes are sent directly to the pipeline. In production,
    the Flutter client should upload to Supabase Storage first and
    use the URL-based endpoint instead.
    """
    try:
        image_bytes = await file.read()
        logger.info(f"Ingesting uploaded file: {file.filename} ({len(image_bytes)} bytes)")

        item_id, context = await pipeline.ingest(
            image_source=image_bytes,
            image_url="",  # No public URL for direct uploads
        )

        return IngestResponse(
            item_id=item_id,
            name=context.name,
            domain=context.inferred_category,
            category=context.inferred_category,
            utility_summary=context.utility_summary,
            semantic_tags=context.semantic_tags,
        )

    except Exception as e:
        logger.error(f"Upload ingest failed: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Upload ingest failed: {str(e)}")
