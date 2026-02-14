"""
nexus_ai/pipeline.py
=====================
Main orchestrator. This is the module Zihan imports into his FastAPI app.

Two core flows:
  1. INGEST:  image → context extraction → embedding → return for Pinecone upsert
  2. SEARCH:  query text → query embedding → (Pinecone search handled by Zihan) → synthesis

Usage in Zihan's FastAPI:
    from nexus_ai.pipeline import NexusPipeline

    pipeline = NexusPipeline()

    # In POST /api/ingest
    result = await pipeline.ingest(image_bytes)

    # In POST /api/search/semantic (after Pinecone returns results)
    plan = await pipeline.synthesize_results(query, retrieved_items)
"""

import logging
import time

from .config import EMBEDDING_PROVIDER, validate_config
from .models import ItemContext, EmbeddingResult, RetrievedItem, MissionPlan, SearchQuery
from .context_extractor import ContextExtractor
from .embedding_engine import create_embedder, BaseEmbedder
from .mission_synthesizer import MissionSynthesizer

logger = logging.getLogger("nexus.pipeline")


class NexusPipeline:
    """
    Top-level orchestrator for all AI operations in Nexus.

    Zihan: instantiate this ONCE at FastAPI startup, then call its methods
    from your route handlers.
    """

    def __init__(self):
        # Validate environment
        warnings = validate_config()
        for w in warnings:
            logger.warning(f"CONFIG: {w}")

        # Initialize components
        self.extractor = ContextExtractor()
        self.embedder: BaseEmbedder = create_embedder()
        self.synthesizer = MissionSynthesizer()

        logger.info(
            f"NexusPipeline initialized | "
            f"embedder={EMBEDDING_PROVIDER.value} "
            f"dim={self.embedder.dimension}"
        )

    # -------------------------------------------------------------------
    # FLOW 1: INGEST — Called by Zihan's POST /api/ingest
    # -------------------------------------------------------------------
    async def ingest(self, image_source: str | bytes) -> EmbeddingResult:
        """
        Full ingest pipeline: image → context → embedding.

        Args:
            image_source: File path, URL, or raw bytes of the image.

        Returns:
            EmbeddingResult containing the vector, metadata, and item_id
            ready for Zihan to upsert into Pinecone.
        """
        t0 = time.time()

        # Step 1: Extract semantic context via Vision LLM
        logger.info("Step 1/2: Extracting context via GPT-4o Vision...")
        context: ItemContext = await self.extractor.extract(image_source)
        t1 = time.time()
        logger.info(f"  Context extracted in {t1 - t0:.1f}s: {context.name} [{context.inferred_category}]")

        # Step 2: Generate multimodal embedding
        logger.info("Step 2/2: Generating multimodal embedding...")
        vector: list[float] = await self.embedder.embed_item(image_source, context)
        t2 = time.time()
        logger.info(f"  Embedding generated in {t2 - t1:.1f}s: dim={len(vector)}")

        result = EmbeddingResult(
            vector=vector,
            dimension=len(vector),
            context=context,
        )

        logger.info(f"Ingest complete in {t2 - t0:.1f}s | id={result.item_id}")
        return result

    async def ingest_batch(self, image_sources: list[str | bytes]) -> list[EmbeddingResult]:
        """
        Batch ingest for the demo seed phase (Hour 24-30).
        Processes items sequentially to avoid rate limits.
        """
        import asyncio
        results = []
        for i, src in enumerate(image_sources):
            logger.info(f"Batch ingest [{i + 1}/{len(image_sources)}]")
            try:
                result = await self.ingest(src)
                results.append(result)
            except Exception as e:
                logger.error(f"Failed to ingest item {i + 1}: {e}")
            # Small delay to avoid rate limits
            await asyncio.sleep(0.5)
        return results

    # -------------------------------------------------------------------
    # FLOW 2: SEARCH — Called by Zihan's POST /api/search/semantic
    # -------------------------------------------------------------------
    async def embed_query(self, query: str) -> list[float]:
        """
        Convert a natural language search query into a vector.

        Zihan: call this, then use the vector to query Pinecone:
            vector = await pipeline.embed_query("cold weather medical mission")
            results = pinecone_index.query(vector=vector, top_k=15)

        Args:
            query: Natural language search text from Noah's UI.

        Returns:
            Query embedding vector (same dimension as item embeddings).
        """
        logger.info(f"Embedding query: '{query[:80]}...'")
        vector = await self.embedder.embed_text(query)
        logger.info(f"Query embedded: dim={len(vector)}")
        return vector

    async def synthesize_results(
        self, query: str, retrieved_items: list[RetrievedItem]
    ) -> MissionPlan:
        """
        Post-retrieval synthesis: curate Pinecone results into a mission plan.

        Zihan: call this AFTER your Pinecone query returns results:
            # 1. Query Pinecone
            raw_results = pinecone_index.query(vector=qvec, top_k=15, include_metadata=True)
            # 2. Convert to RetrievedItem objects
            items = [RetrievedItem(...) for match in raw_results.matches]
            # 3. Synthesize
            plan = await pipeline.synthesize_results(query, items)

        Returns:
            MissionPlan with selected items, rejected items, reasoning, and warnings.
        """
        logger.info(f"Synthesizing plan for {len(retrieved_items)} items...")
        plan = await self.synthesizer.synthesize(query, retrieved_items)
        logger.info(
            f"Plan complete: {len(plan.selected_items)} selected, "
            f"{len(plan.rejected_items)} rejected, "
            f"{len(plan.warnings)} warnings"
        )
        return plan

    # -------------------------------------------------------------------
    # UTILITY: Convert Pinecone match → RetrievedItem
    # -------------------------------------------------------------------
    @staticmethod
    def pinecone_match_to_item(match: dict) -> RetrievedItem:
        """
        Helper for Zihan: convert a raw Pinecone query match into a
        RetrievedItem that the synthesizer can consume.

        Usage:
            results = index.query(vector=qvec, top_k=15, include_metadata=True)
            items = [NexusPipeline.pinecone_match_to_item(m) for m in results.matches]
        """
        meta = match.get("metadata", {})
        return RetrievedItem(
            item_id=match["id"],
            score=match["score"],
            image_url=meta.get("image_url"),
            context=ItemContext(
                name=meta.get("name", "Unknown"),
                inferred_category=meta.get("inferred_category", "misc"),
                primary_material=meta.get("primary_material"),
                weight_estimate=meta.get("weight_estimate"),
                thermal_rating=meta.get("thermal_rating"),
                water_resistance=meta.get("water_resistance"),
                medical_application=meta.get("medical_application"),
                utility_summary=meta.get("utility_summary", ""),
                semantic_tags=meta.get("semantic_tags", []),
                durability=meta.get("durability"),
                compressibility=meta.get("compressibility"),
            ),
        )

    # -------------------------------------------------------------------
    # UTILITY: Build Pinecone-ready metadata from EmbeddingResult
    # -------------------------------------------------------------------
    @staticmethod
    def to_pinecone_payload(result: EmbeddingResult, image_url: str = "") -> dict:
        """
        Helper for Zihan: format an EmbeddingResult for Pinecone upsert.

        Usage:
            result = await pipeline.ingest(image_bytes)
            image_url = upload_to_s3(image_bytes)
            payload = NexusPipeline.to_pinecone_payload(result, image_url)
            index.upsert(vectors=[payload])
        """
        ctx = result.context
        return {
            "id": result.item_id,
            "values": result.vector,
            "metadata": {
                "image_url": image_url,
                "name": ctx.name,
                "inferred_category": ctx.inferred_category,
                "primary_material": ctx.primary_material,
                "weight_estimate": ctx.weight_estimate,
                "thermal_rating": ctx.thermal_rating,
                "water_resistance": ctx.water_resistance,
                "medical_application": ctx.medical_application,
                "utility_summary": ctx.utility_summary,
                "semantic_tags": ctx.semantic_tags,
                "durability": ctx.durability,
                "compressibility": ctx.compressibility,
            },
        }
