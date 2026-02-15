"""
scripts/reembed_all_items.py
=============================
One-time migration script: re-ingests every item in manifest_items with the
enhanced embedding pipeline (activity_contexts, unsuitable_contexts,
environmental_suitability, limitations, etc.).

For each item:
  1. Fetches the row from Supabase (id, image_url, user_id)
  2. Re-runs GPT-5 Vision context extraction on the image
  3. Generates a new embedding with the full context text
  4. Deletes the old row
  5. Inserts the new row with the same ID

Usage:
    # Dry run (just prints what would happen, no changes)
    python scripts/reembed_all_items.py --dry-run

    # Full run
    python scripts/reembed_all_items.py

    # Only re-embed items missing the new fields
    python scripts/reembed_all_items.py --only-missing

Env vars required:
    OPENAI_API_KEY, VOYAGE_API_KEY, SUPABASE_URL, SUPABASE_SERVICE_KEY
"""

import argparse
import asyncio
import logging
import sys
import time
from pathlib import Path
from dotenv import load_dotenv

# Allow running from repo root: `python scripts/reembed_all_items.py`
backend_path = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(backend_path))

# Load environment variables
load_dotenv(backend_path / ".env")

from ai_modules.config import SUPABASE_URL, SUPABASE_SERVICE_KEY
from ai_modules.context_extractor import ContextExtractor
from ai_modules.embedding_engine import create_embedder
from ai_modules.models import EmbeddingResult
from ai_modules.vector_store import SupabaseVectorStore

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)
logger = logging.getLogger("reembed")

TABLE = "manifest_items"


def fetch_all_items(store: SupabaseVectorStore, only_missing: bool) -> list[dict]:
    """Fetch all items from Supabase that need re-embedding."""
    # First try with new columns; if they don't exist yet fall back to base columns
    try:
        query = store.client.table(TABLE).select(
            "id, image_url, user_id, name, activity_contexts, unsuitable_contexts"
        )
        response = query.execute()
        has_new_cols = True
    except Exception:
        logger.warning("New columns not found — run migration 012 first for --only-missing support")
        query = store.client.table(TABLE).select("id, image_url, user_id, name")
        response = query.execute()
        has_new_cols = False

    items = response.data or []

    if only_missing and has_new_cols:
        # Only re-embed items that don't have the new fields populated
        items = [
            item for item in items
            if not item.get("activity_contexts")
            or not item.get("unsuitable_contexts")
        ]
    elif only_missing and not has_new_cols:
        # Columns don't exist yet, so every item is "missing"
        logger.info("New columns missing from table — all items need re-embedding")

    return items


async def reembed_item(
    item: dict,
    extractor: ContextExtractor,
    embedder,
    store: SupabaseVectorStore,
    dry_run: bool,
) -> bool:
    """
    Re-extract context, re-embed, delete old row, insert new row.
    Returns True on success, False on failure.
    """
    item_id = item["id"]
    image_url = item.get("image_url")
    user_id = item.get("user_id")
    old_name = item.get("name", "unknown")

    if not image_url:
        logger.warning(f"  SKIP {item_id} ({old_name}): no image_url")
        return False

    if dry_run:
        logger.info(f"  [DRY RUN] Would re-embed: {item_id} ({old_name})")
        return True

    # Step 1: Re-extract context from image via VLM
    context = await extractor.extract(image_url)
    logger.info(f"    Extracted: {context.name} | activities={context.activity_contexts}")

    # Step 2: Generate new embedding with full context
    vector = await embedder.embed_item(image_url, context)
    logger.info(f"    Embedded: dim={len(vector)}")

    # Step 3: Build result with the ORIGINAL item ID (preserves references)
    result = EmbeddingResult(
        item_id=item_id,
        vector=vector,
        dimension=len(vector),
        context=context,
        image_url=image_url,
    )

    # Step 4: Delete old row
    await store.delete(item_id)
    logger.info(f"    Deleted old row: {item_id}")

    # Step 5: Insert new row (upsert with same ID)
    await store.upsert(result, image_url=image_url, user_id=user_id)
    logger.info(f"    Inserted new row: {item_id}")

    return True


async def main():
    parser = argparse.ArgumentParser(description="Re-embed all items with enhanced context")
    parser.add_argument("--dry-run", action="store_true", help="Print what would happen without making changes")
    parser.add_argument("--only-missing", action="store_true", help="Only re-embed items missing the new fields")
    parser.add_argument("--delay", type=float, default=1.0, help="Delay between items in seconds (rate limiting)")
    args = parser.parse_args()

    logger.info("=== Re-Embed All Items ===")
    logger.info(f"Mode: {'DRY RUN' if args.dry_run else 'LIVE'}")
    logger.info(f"Filter: {'only missing fields' if args.only_missing else 'all items'}")

    # Initialize components
    store = SupabaseVectorStore()
    extractor = ContextExtractor()
    embedder = create_embedder()

    # Fetch items
    logger.info("Fetching items from Supabase...")
    items = fetch_all_items(store, only_missing=args.only_missing)
    logger.info(f"Found {len(items)} items to re-embed")

    if not items:
        logger.info("Nothing to do!")
        return

    # Process each item
    t0 = time.time()
    success = 0
    failed = 0

    for i, item in enumerate(items):
        logger.info(f"[{i + 1}/{len(items)}] Processing {item['id']} ({item.get('name', '?')})...")
        try:
            ok = await reembed_item(item, extractor, embedder, store, dry_run=args.dry_run)
            if ok:
                success += 1
            else:
                failed += 1
        except Exception as e:
            logger.error(f"  FAILED: {e}")
            failed += 1

        # Rate limiting delay (VLM + embedding API calls)
        if not args.dry_run and i < len(items) - 1:
            await asyncio.sleep(args.delay)

    elapsed = time.time() - t0
    logger.info(f"\n=== Complete ===")
    logger.info(f"Total: {len(items)} | Success: {success} | Failed: {failed}")
    logger.info(f"Time: {elapsed:.1f}s ({elapsed / max(len(items), 1):.1f}s per item)")


if __name__ == "__main__":
    asyncio.run(main())
