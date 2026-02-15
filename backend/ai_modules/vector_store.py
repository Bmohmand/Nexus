"""
manifest/vector_store.py
=========================
Supabase pgvector integration. The vector database for Manifest.

Uses the unified `manifest_items` table and `match_manifest_items` RPC
function defined in backend/migrations/004_manifest_items.sql and
backend/migrations/008_vector_search.sql.

SETUP: Run the migration files in order (001-008) in the Supabase SQL Editor.
"""

import json
import logging
from typing import Optional

from supabase import create_client, AsyncClient

from .config import SUPABASE_URL, SUPABASE_SERVICE_KEY, get_embedding_dim
from .models import ItemContext, EmbeddingResult, RetrievedItem

logger = logging.getLogger("manifest.vectorstore")

# Table and RPC names (aligned with backend/migrations/)
TABLE_NAME = "manifest_items"
RPC_NAME = "match_manifest_items"

# Same mapping as knapsack_optimizer.WEIGHT_ESTIMATES_GRAMS for populating weight_grams on ingest
_WEIGHT_ESTIMATE_TO_GRAMS = {
    "ultralight": 100,
    "light": 300,
    "medium": 700,
    "heavy": 1500,
}


class SupabaseVectorStore:
    """
    Handles all vector storage and retrieval via Supabase pgvector.

    Uses the `manifest_items` table and `match_manifest_items` RPC function.

    Usage:
        store = SupabaseVectorStore()
        await store.upsert(embedding_result, image_url="https://...")
        items = await store.search(query_vector, top_k=15)
    """

    def __init__(self, url: str = SUPABASE_URL, key: str = SUPABASE_SERVICE_KEY):
        if not url or not key:
            raise ValueError("SUPABASE_URL and SUPABASE_SERVICE_KEY are required")
        self.client = create_client(url, key)
        logger.info("Supabase vector store initialized (table: %s)", TABLE_NAME)

    async def upsert(
        self,
        result: EmbeddingResult,
        image_url: str = "",
        user_id: Optional[str] = None,
    ) -> str:
        """
        Insert or update an item in the manifest_items table.

        Args:
            result: EmbeddingResult from pipeline.ingest()
            image_url: Public URL after uploading the image
            user_id: Optional owner user UUID (required if table has user_id NOT NULL)

        Returns:
            The item's UUID
        """
        ctx = result.context
        weight_grams = None
        if ctx.weight_estimate:
            weight_grams = _WEIGHT_ESTIMATE_TO_GRAMS.get(
                ctx.weight_estimate.strip().lower(),
                500,
            )
        row = {
            "id": result.item_id,
            "embedding": result.vector,
            "image_url": image_url,
            "name": ctx.name,
            "domain": self._infer_domain(ctx.inferred_category),
            "category": ctx.inferred_category,
            "primary_material": ctx.primary_material,
            "weight_estimate": ctx.weight_estimate,
            "weight_grams": weight_grams,
            "thermal_rating": ctx.thermal_rating,
            "water_resistance": ctx.water_resistance,
            "medical_application": ctx.medical_application,
            "utility_summary": ctx.utility_summary,
            "semantic_tags": ctx.semantic_tags,
            "durability": ctx.durability,
            "compressibility": ctx.compressibility,
        }
        if user_id:
            row["user_id"] = user_id

        self.client.table(TABLE_NAME).upsert(row).execute()
        logger.info(f"Upserted item: {ctx.name} ({result.item_id})")
        return result.item_id

    async def search(
        self,
        query_vector: list[float],
        top_k: int = 15,
        category_filter: Optional[str] = None,
        user_id: Optional[str] = None,
    ) -> list[RetrievedItem]:
        """
        Perform cosine similarity search via the match_manifest_items RPC function.

        Args:
            query_vector: The embedded query
            top_k: Number of nearest neighbors to return
            category_filter: Optional category to restrict search
            user_id: Optional user UUID to scope search to a specific user's items

        Returns:
            List of RetrievedItem sorted by similarity (highest first)
        """
        params = {
            "query_embedding": query_vector,
            "match_count": top_k,
            "filter_category": category_filter,
        }
        if user_id is not None:
            params["filter_user_id"] = user_id

        response = self.client.rpc(RPC_NAME, params).execute()

        items = []
        for row in response.data:
            items.append(RetrievedItem(
                item_id=str(row["id"]),
                score=float(row["similarity"]),
                image_url=row.get("image_url"),
                weight_grams=row.get("weight_grams"),
                context=ItemContext(
                    name=row["name"],
                    inferred_category=row.get("category", "misc"),
                    primary_material=row.get("primary_material"),
                    weight_estimate=row.get("weight_estimate"),
                    thermal_rating=row.get("thermal_rating"),
                    water_resistance=row.get("water_resistance"),
                    medical_application=row.get("medical_application"),
                    utility_summary=row.get("utility_summary", ""),
                    semantic_tags=row.get("semantic_tags", []),
                    durability=row.get("durability"),
                    compressibility=row.get("compressibility"),
                ),
            ))

        logger.info(
            f"Search returned {len(items)} items"
            + (f" (top score: {items[0].score:.4f})" if items else "")
        )
        return items

    async def delete(self, item_id: str) -> None:
        """Remove an item from the store."""
        self.client.table(TABLE_NAME).delete().eq("id", item_id).execute()
        logger.info(f"Deleted item: {item_id}")

    async def count(self) -> int:
        """Get total number of items in the store."""
        response = self.client.table(TABLE_NAME).select("id", count="exact").execute()
        return response.count or 0

    @staticmethod
    def _infer_domain(category: str) -> str:
        """Map an AI-assigned category string to a manifest domain enum value."""
        category_lower = (category or "").lower()
        domain_map = {
            "clothing": "clothing",
            "medical": "medical",
            "tech": "tech",
            "camping": "camping",
            "food": "food",
        }
        for keyword, domain in domain_map.items():
            if keyword in category_lower:
                return domain
        return "general"
