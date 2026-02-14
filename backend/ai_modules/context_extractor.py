"""
nexus_ai/context_extractor.py
==============================
Step 1 of the 2-step AI pipeline.

Takes a raw image and passes it to GPT-4o Vision to extract a rich
semantic profile (ItemContext). This is critical because raw pixel
embeddings alone don't capture things like thermal limits, medical
applications, or material safety — a Vision LLM does.

Called by: pipeline.py (ingest flow)
Depends on: OPENAI_API_KEY
"""

import base64
import json
import logging
from pathlib import Path

from openai import AsyncOpenAI

from .config import OPENAI_API_KEY, VISION_MODEL
from .models import ItemContext

logger = logging.getLogger("nexus.extractor")

# ---------------------------------------------------------------------------
# System prompt — this is the "brain" of context extraction.
# Tune this heavily during the hackathon to improve embedding quality.
# ---------------------------------------------------------------------------
EXTRACTION_PROMPT = """You are an expert gear analyst for a cross-domain packing intelligence system called Nexus.

Your goal is to analyze an image of a physical object and extract highly accurate, semantically dense metadata. This data will be ingested into a vector database for natural language similarity searches in extreme logistics and disaster relief scenarios.

Analyze the image thoroughly and return ONLY a valid JSON object matching the exact schema below. Do not use markdown blocks (e.g., ```json) or add conversational filler.

{
  "analysis_scratchpad": "Think step-by-step here. What visual clues do you see? What is the texture, branding, or shape? Deduce the material and use-case before filling out the rest of the fields.",
  "name": "Human-readable name of the item",
  "inferred_category": "One of: clothing, medical, tech, camping, food, misc",
  "primary_material": "Dominant material (e.g., 'Gore-Tex nylon', 'stainless steel', 'cotton')",
  "weight_estimate": "One of: ultralight, light, medium, heavy",
  "thermal_rating": "One of: cold-rated, warm-weather, neutral, insulated",
  "environmental_suitability": "What climates or conditions is this designed for? (e.g., 'Sub-zero temperatures', 'Arid desert', 'Sterile clinical').",
  "limitations_and_failure_modes": "CRITICAL. What are the limits of this item? (e.g., 'Useless when wet', 'Requires batteries', 'Melts at high heat').",
  "water_resistance": "One of: waterproof, water-resistant, not water-resistant",
  "medical_application": "If applicable: wound_care, thermal_regulation, immobilization, medication, diagnostics, or null",
  "utility_summary": "1-2 sentences: what is this item useful for? In what scenarios?",
  "semantic_tags": ["tag1", "tag2", "tag3"],
  "durability": "One of: disposable, reusable, rugged",
  "compressibility": "One of: highly_compressible, moderate, rigid"
}

IMPORTANT RULES:
- Be specific about materials. "Cotton" vs "merino wool" vs "synthetic fleece" matters enormously for survival contexts.
- For medical items, always note whether they are sterile and single-use.
- semantic_tags should include cross-domain utility hints. A mylar blanket is BOTH medical AND survival.
- If you can identify the brand, include it in the name (e.g., "Patagonia Down Sweater Jacket").
- Return ONLY valid JSON. No markdown, no explanation."""


class ContextExtractor:
    """Extracts structured semantic context from item images via GPT-4o Vision."""

    def __init__(self, api_key: str = OPENAI_API_KEY):
        if not api_key:
            raise ValueError("OPENAI_API_KEY is required for context extraction")
        self.client = AsyncOpenAI(api_key=api_key)

    async def extract(self, image_source: str | bytes) -> ItemContext:
        """
        Extract semantic context from an image.

        Args:
            image_source: Either a file path (str), a URL (str starting with http),
                          or raw bytes of the image.

        Returns:
            ItemContext with all inferred fields populated.
        """
        image_content = self._prepare_image(image_source)

        response = await self.client.chat.completions.create(
            model=VISION_MODEL,
            messages=[
                {"role": "system", "content": EXTRACTION_PROMPT},
                {
                    "role": "user",
                    "content": [
                        {"type": "text", "text": "Analyze this item:"},
                        image_content,
                    ],
                },
            ],
            max_tokens=800,
            temperature=0.1,  # Low temp for consistent structured output
            response_format={"type": "json_object"},
        )

        raw = response.choices[0].message.content
        logger.info(f"Raw extraction: {raw[:200]}...")

        try:
            data = json.loads(raw)
            return ItemContext(**data)
        except (json.JSONDecodeError, Exception) as e:
            logger.error(f"Failed to parse extraction output: {e}\nRaw: {raw}")
            raise ValueError(f"Context extraction returned invalid JSON: {e}")

    async def extract_batch(self, image_sources: list[str | bytes]) -> list[ItemContext]:
        """
        Extract context from multiple images concurrently.
        Use this during the 'Demo Seed' phase (Hour 24-30) to process
        all 50 items quickly.
        """
        import asyncio
        tasks = [self.extract(src) for src in image_sources]
        return await asyncio.gather(*tasks)

    @staticmethod
    def _prepare_image(source: str | bytes) -> dict:
        """Convert various image inputs into OpenAI API format."""
        if isinstance(source, bytes):
            b64 = base64.b64encode(source).decode("utf-8")
            return {
                "type": "image_url",
                "image_url": {
                    "url": f"data:image/jpeg;base64,{b64}",
                    "detail": "high",
                },
            }
        elif isinstance(source, str) and source.startswith(("http://", "https://")):
            return {
                "type": "image_url",
                "image_url": {"url": source, "detail": "high"},
            }
        elif isinstance(source, str):
            # Local file path
            path = Path(source)
            if not path.exists():
                raise FileNotFoundError(f"Image not found: {source}")
            suffix = path.suffix.lower()
            mime = {
                ".jpg": "image/jpeg",
                ".jpeg": "image/jpeg",
                ".png": "image/png",
                ".webp": "image/webp",
                ".gif": "image/gif",
            }.get(suffix, "image/jpeg")
            b64 = base64.b64encode(path.read_bytes()).decode("utf-8")
            return {
                "type": "image_url",
                "image_url": {
                    "url": f"data:{mime};base64,{b64}",
                    "detail": "high",
                },
            }
        else:
            raise TypeError(f"Unsupported image source type: {type(source)}")
