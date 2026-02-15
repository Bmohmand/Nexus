"""
nexus_ai/pipeline.py
=====================
Main orchestrator. This is the module Zihan imports into his FastAPI app.

Two core flows:
  1. INGEST:  image -> context extraction -> embedding -> upsert to Supabase
  2. SEARCH:  query text -> query embedding -> Supabase pgvector search -> synthesis

Usage in Zihan's FastAPI:
    from nexus_ai.pipeline import NexusPipeline

    pipeline = NexusPipeline()

    # In POST /api/ingest
    item_id = await pipeline.ingest(image_bytes, image_url="https://s3...")

    # In POST /api/search/semantic  (one call does everything now)
    plan = await pipeline.search("48-hour cold climate medical mission")

Env vars needed:
    OPENAI_API_KEY, VOYAGE_API_KEY,
    SUPABASE_URL, SUPABASE_SERVICE_KEY
"""

import logging
import time
from typing import Optional

from .config import EMBEDDING_PROVIDER, validate_config
from .models import ItemContext, EmbeddingResult, RetrievedItem, MissionPlan, SearchQuery
from .context_extractor import ContextExtractor
from .embedding_engine import create_embedder, BaseEmbedder
from .mission_synthesizer import MissionSynthesizer
from .vector_store import SupabaseVectorStore
from .knapsack_optimizer import (
    KnapsackOptimizer,
    PackingConstraints,
    PackingResult,
    PackableItem,
    CONSTRAINT_PRESETS,
)

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
        self.store = SupabaseVectorStore()
        self.optimizer = KnapsackOptimizer()

        logger.info(
            f"NexusPipeline initialized | "
            f"embedder={EMBEDDING_PROVIDER.value} "
            f"dim={self.embedder.dimension}"
        )

    # -------------------------------------------------------------------
    # FLOW 1: INGEST  --  Called by Zihan's POST /api/ingest
    # -------------------------------------------------------------------
    async def ingest(
        self,
        image_source: str | bytes,
        image_url: str = "",
        user_id: Optional[str] = None,
    ) -> str:
        """
        Full ingest pipeline: image -> context -> embedding -> store in Supabase.

        Args:
            image_source: File path, URL, or raw bytes of the image.
            image_url: The public S3/R2 URL after Zihan uploads the image.
            user_id: Optional owner user UUID (for multi-tenant; if omitted, DB must allow null).

        Returns:
            Tuple of (item_id, context) for the API response.
        """
        t0 = time.time()

        # Step 1: Extract semantic context via Vision LLM
        logger.info("Step 1/3: Extracting context via GPT-5 Vision...")
        context: ItemContext = await self.extractor.extract(image_source)
        t1 = time.time()
        logger.info(f"  Context extracted in {t1 - t0:.1f}s: {context.name} [{context.inferred_category}]")

        # Step 2: Generate multimodal embedding
        logger.info("Step 2/3: Generating multimodal embedding...")
        vector: list[float] = await self.embedder.embed_item(image_source, context)
        t2 = time.time()
        logger.info(f"  Embedding generated in {t2 - t1:.1f}s: dim={len(vector)}")

        result = EmbeddingResult(
            vector=vector,
            dimension=len(vector),
            context=context,
            image_url=image_url,
        )

        # Step 3: Upsert into Supabase
        logger.info("Step 3/3: Upserting into Supabase...")
        item_id = await self.store.upsert(result, image_url=image_url, user_id=user_id)
        t3 = time.time()

        logger.info(f"Ingest complete in {t3 - t0:.1f}s | id={item_id}")
        return item_id, context

    async def ingest_batch(self, image_sources: list[tuple[str | bytes, str]]) -> list[str]:
        """
        Batch ingest for the demo seed phase (Hour 24-30).
        Processes items sequentially to avoid rate limits.

        Args:
            image_sources: List of (image_source, image_url) tuples.

        Returns:
            List of item UUIDs.
        """
        import asyncio
        ids = []
        for i, (src, url) in enumerate(image_sources):
            logger.info(f"Batch ingest [{i + 1}/{len(image_sources)}]")
            try:
                item_id, _ = await self.ingest(src, image_url=url)
                ids.append(item_id)
            except Exception as e:
                logger.error(f"Failed to ingest item {i + 1}: {e}")
            # Small delay to avoid rate limits
            await asyncio.sleep(0.5)
        return ids

    # -------------------------------------------------------------------
    # FLOW 2: SEARCH  --  Called by Zihan's POST /api/search/semantic
    # -------------------------------------------------------------------
    async def search(
        self,
        query: str,
        top_k: int = 15,
        category_filter: Optional[str] = None,
        synthesize: bool = True,
        user_id: Optional[str] = None,
    ) -> MissionPlan | list[RetrievedItem]:
        """
        Full search pipeline: query -> embed -> Supabase vector search -> synthesize.

        This is now a SINGLE call that does everything. Zihan's route handler
        just needs:
            plan = await pipeline.search("cold weather medical mission")

        Args:
            query: Natural language search text from Noah's UI.
            top_k: Number of nearest neighbors.
            category_filter: Optional category to restrict search.
            synthesize: If True, run LLM synthesis. If False, return raw results.
            user_id: Optional user UUID to scope search to a specific user's items.

        Returns:
            MissionPlan (if synthesize=True) or list of RetrievedItem (if False).
        """
        t0 = time.time()

        # Step 1: Embed the query
        logger.info(f"Embedding query: '{query[:80]}'...")
        query_vector = await self.embedder.embed_text(query)

        # Step 2: Search Supabase pgvector
        logger.info(f"Searching Supabase (top_k={top_k})...")
        retrieved = await self.store.search(
            query_vector=query_vector,
            top_k=top_k,
            category_filter=category_filter,
            user_id=user_id,
        )
        t1 = time.time()
        logger.info(f"Retrieved {len(retrieved)} items in {t1 - t0:.1f}s")

        if not synthesize:
            return retrieved

        # Step 3: LLM synthesis into a mission plan
        logger.info("Synthesizing mission plan...")
        plan = await self.synthesizer.synthesize(query, retrieved)
        t2 = time.time()
        logger.info(
            f"Search complete in {t2 - t0:.1f}s | "
            f"{len(plan.selected_items)} selected, "
            f"{len(plan.rejected_items)} rejected"
        )
        return plan

    async def embed_query(self, query: str) -> list[float]:
        """
        Just embed a query without searching. Useful if Zihan wants
        to do custom queries against Supabase directly.
        """
        return await self.embedder.embed_text(query)

    # -------------------------------------------------------------------
    # FLOW 3: PACK  --  Search + Knapsack Optimization
    # -------------------------------------------------------------------
    async def pack(
        self,
        query: str,
        constraints: PackingConstraints | str,
        top_k: int = 30,
        category_filter: Optional[str] = None,
        inventory: Optional[dict[str, int]] = None,
        weight_overrides: Optional[dict[str, float]] = None,
    ) -> PackingResult:
        """
        The full Nexus pipeline: semantic search → knapsack optimization.

        1. Embeds the query and searches Supabase for top_k candidates
        2. Converts results to PackableItems with weights/quantities
        3. Solves the bounded knapsack with diversity constraints

        Args:
            query: Natural language mission description.
            constraints: Either a PackingConstraints object or a preset name
                         ("drone_delivery", "medical_relief", "carry_on_luggage", etc.)
            top_k: Candidate pool size. Solver picks the best subset from these.
                   Use 30+ so the solver has enough to work with.
            category_filter: Optional category pre-filter on the vector search.
            inventory: {item_id: quantity_owned} map. Default: 1 of each.
            weight_overrides: {item_id: weight_grams} for items with known weights.

        Returns:
            PackingResult with optimally selected items, weights, and score.
        """
        t0 = time.time()

        # Resolve constraint preset if string
        if isinstance(constraints, str):
            if constraints not in CONSTRAINT_PRESETS:
                raise ValueError(
                    f"Unknown preset '{constraints}'. "
                    f"Available: {list(CONSTRAINT_PRESETS.keys())}"
                )
            constraints = CONSTRAINT_PRESETS[constraints]

        # Step 1: Vector search for candidates
        logger.info(f"Pack: searching for {top_k} candidates...")
        retrieved = await self.search(
            query=query,
            top_k=top_k,
            category_filter=category_filter,
            synthesize=False,  # Raw results, no LLM yet
        )

        # Step 2: Convert to packable items
        packable = KnapsackOptimizer.retrieved_to_packable(
            items=retrieved,
            inventory=inventory,
            weight_overrides=weight_overrides,
        )

        # Step 3: Solve
        logger.info(
            f"Pack: solving knapsack | "
            f"{len(packable)} candidates | "
            f"max_weight={constraints.max_weight_grams}g | "
            f"category_mins={constraints.category_minimums} | "
            f"tag_mins={constraints.tag_minimums}"
        )
        result = self.optimizer.solve(packable, constraints)

        t1 = time.time()
        logger.info(f"Pack complete in {(t1 - t0) * 1000:.0f}ms total")
        return result

    async def pack_and_explain(
        self,
        query: str,
        constraints: PackingConstraints | str,
        top_k: int = 30,
        inventory: Optional[dict[str, int]] = None,
        weight_overrides: Optional[dict[str, float]] = None,
    ) -> tuple[PackingResult, MissionPlan]:
        """
        The full demo flow: search → optimize → LLM explanation.

        Runs the knapsack solver first, then passes the selected AND rejected
        items to the LLM synthesizer for a natural language explanation.
        This is what you show the judges.

        Returns:
            (PackingResult, MissionPlan) — the math AND the story.
        """
        # Run the optimizer
        result = await self.pack(
            query=query,
            constraints=constraints,
            top_k=top_k,
            inventory=inventory,
            weight_overrides=weight_overrides,
        )

        if result.status == "infeasible":
            # Still explain why it failed
            plan = MissionPlan(
                mission_summary=f"Unable to satisfy constraints for: {query}",
                selected_items=[],
                reasoning={},
                warnings=result.relaxed_constraints + [
                    "The optimizer could not find a feasible solution. "
                    "Try increasing the weight limit or relaxing diversity requirements."
                ],
                rejected_items=[],
            )
            return result, plan

        # Build RetrievedItems for the synthesizer from packed items
        from .models import RetrievedItem, ItemContext
        selected_retrieved = []
        for item, qty in result.packed_items:
            # Find the original RetrievedItem context
            selected_retrieved.append(RetrievedItem(
                item_id=item.item_id,
                score=item.similarity_score,
                context=ItemContext(
                    name=f"{item.name} (x{qty})" if qty > 1 else item.name,
                    inferred_category=item.category,
                    utility_summary=f"Packed {qty} unit(s), {item.weight_grams * qty:.0f}g total",
                    semantic_tags=item.semantic_tags,
                ),
            ))

        rejected_retrieved = []
        for item in result.unpacked_items[:10]:  # Cap at 10 for the prompt
            rejected_retrieved.append(RetrievedItem(
                item_id=item.item_id,
                score=item.similarity_score,
                context=ItemContext(
                    name=item.name,
                    inferred_category=item.category,
                    utility_summary="Not selected by optimizer",
                    semantic_tags=item.semantic_tags,
                ),
            ))

        # Augment the query with constraint context for the LLM
        constraint_desc = (
            f"{query}\n\n"
            f"CONSTRAINTS APPLIED:\n"
            f"- Weight limit: {constraints.max_weight_grams / 1000:.1f} kg\n"
            f"- Result: {result.total_weight_grams / 1000:.1f} kg used "
            f"({result.weight_utilization:.0%} utilization)\n"
        )
        if isinstance(constraints, PackingConstraints) and constraints.category_minimums:
            constraint_desc += f"- Category minimums: {constraints.category_minimums}\n"
        if isinstance(constraints, PackingConstraints) and constraints.tag_minimums:
            constraint_desc += f"- Tag minimums: {constraints.tag_minimums}\n"
        if result.relaxed_constraints:
            constraint_desc += f"- Relaxed: {result.relaxed_constraints}\n"

        # Let the LLM explain the optimizer's decisions
        plan = await self.synthesizer.synthesize(
            constraint_desc,
            selected_retrieved + rejected_retrieved,
        )

        return result, plan

    # -------------------------------------------------------------------
    # UTILITY: Get setup SQL for Supabase
    # -------------------------------------------------------------------
    def get_setup_sql(self) -> str:
        """
        Returns the SQL Zihan needs to run once in Supabase SQL Editor.
        Automatically uses the correct vector dimension.
        """
        return self.store.get_setup_sql(dim=self.embedder.dimension)

    async def item_count(self) -> int:
        """How many items are in the database."""
        return await self.store.count()
