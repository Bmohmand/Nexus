"""
nexus_ai/mission_synthesizer.py
================================
Step 3: Post-retrieval intelligence.

After Supabase returns the top-k nearest items, this module passes them
to an LLM to curate the final packing manifest. The LLM:
  - Filters out dangerous/inappropriate items (the "cotton in cold" rejection)
  - Explains WHY each item was selected (for the demo)
  - Groups items by function, not category
  - Flags warnings (e.g., missing critical supplies)

Called by: pipeline.py (search flow)
"""

import json
import logging
from openai import AsyncOpenAI

from .config import OPENAI_API_KEY, SYNTHESIS_MODEL, SYNTHESIS_MAX_TOKENS, REASONING_EFFORT_SYNTHESIS
from .models import RetrievedItem, MissionPlan

logger = logging.getLogger("nexus.synthesizer")

# ---------------------------------------------------------------------------
# Synthesis prompt — this creates the "wow factor" output for demos
# ---------------------------------------------------------------------------
SYNTHESIS_PROMPT = """You are Nexus, a cross-domain packing intelligence system. You have just performed a semantic vector search across a user's physical inventory and retrieved the most relevant items.

Your job is to curate these into an intelligent mission-specific packing plan.

USER'S MISSION QUERY:
{query}

RETRIEVED ITEMS (ranked by semantic similarity):
{items_json}

INSTRUCTIONS:
1. Interpret the user's mission. What environment, duration, and risks are implied?
2. Select the items that genuinely belong on this mission. Not everything retrieved is appropriate.
3. CRITICAL: Actively REJECT items that are dangerous or inappropriate for the mission context:
   - Cotton clothing in cold/wet environments (cotton kills — it loses all insulation when wet)
   - Summer-only gear for winter missions
   - Expired medical supplies (if detectable)
   - Redundant items (don't pack 5 flashlights)
4. For each selected item, provide a 1-sentence reason it was chosen that demonstrates cross-domain understanding.
5. Flag any critical gaps (e.g., "No water purification detected — critical for remote missions").

Respond with ONLY this JSON structure:
{{
  "mission_summary": "Brief interpretation of the mission context",
  "selected_items": [
    {{
      "item_id": "...",
      "name": "...",
      "reason": "Why this item is essential for this specific mission"
    }}
  ],
  "rejected_items": [
    {{
      "item_id": "...",
      "name": "...",
      "reason": "Why this item was excluded despite being semantically similar"
    }}
  ],
  "warnings": ["List of critical gaps or safety concerns"],
  "cross_domain_insights": [
    "Observations about unexpected item connections, e.g., 'The mylar emergency blanket serves both medical (shock prevention) and survival (thermal retention) roles'"
  ]
}}"""


class MissionSynthesizer:
    """Curates retrieved search results into an intelligent packing manifest."""

    def __init__(self, api_key: str = OPENAI_API_KEY):
        if not api_key:
            raise ValueError("OPENAI_API_KEY is required for synthesis")
        self.client = AsyncOpenAI(api_key=api_key)

    async def synthesize(self, query: str, retrieved_items: list[RetrievedItem]) -> MissionPlan:
        """
        Take a user query + retrieved items and produce a curated plan.

        Args:
            query: The original natural language mission query
            retrieved_items: Items returned by Supabase, already ranked by similarity

        Returns:
            MissionPlan with selections, rejections, and reasoning
        """
        # Serialize retrieved items for the prompt
        items_for_prompt = []
        for item in retrieved_items:
            items_for_prompt.append({
                "item_id": item.item_id,
                "name": item.context.name,
                "category": item.context.inferred_category,
                "similarity_score": round(item.score, 4),
                "material": item.context.primary_material,
                "thermal_rating": item.context.thermal_rating,
                "water_resistance": item.context.water_resistance,
                "medical_application": item.context.medical_application,
                "utility": item.context.utility_summary,
                "tags": item.context.semantic_tags,
            })

        prompt = SYNTHESIS_PROMPT.format(
            query=query,
            items_json=json.dumps(items_for_prompt, indent=2),
        )

        response = await self.client.chat.completions.create(
            model=SYNTHESIS_MODEL,
            messages=[{"role": "user", "content": prompt}],
            max_completion_tokens=SYNTHESIS_MAX_TOKENS,
            reasoning_effort=REASONING_EFFORT_SYNTHESIS,
            response_format={"type": "json_object"},
        )

        msg = response.choices[0].message
        raw = msg.content if msg.content is not None else ""
        if not raw.strip():
            refusal = getattr(msg, "refusal", None) or ""
            logger.error(
                "Synthesis returned empty content (reasoning models may exhaust tokens on thinking). "
                "Refusal: %s",
                refusal or "(none)",
            )
            raise ValueError(
                "Synthesis returned empty response. "
                "Try increasing max_completion_tokens or lowering reasoning_effort."
            )
        logger.info(f"Synthesis output: {raw[:300]}...")

        try:
            data = json.loads(raw)
        except json.JSONDecodeError as e:
            logger.error(f"Synthesis returned invalid JSON: {e}\nRaw: {raw[:500]}")
            raise ValueError(f"Synthesis failed: {e}")

        return self._parse_plan(data, retrieved_items)

    def _parse_plan(self, data: dict, all_items: list[RetrievedItem]) -> MissionPlan:
        """Convert raw LLM JSON into a structured MissionPlan."""
        # Build lookup
        item_map = {item.item_id: item for item in all_items}

        # Selected items
        selected = []
        reasoning = {}
        for sel in data.get("selected_items", []):
            item_id = sel.get("item_id", "")
            if item_id in item_map:
                selected.append(item_map[item_id])
                reasoning[item_id] = sel.get("reason", "")

        # Rejected items
        rejected = []
        for rej in data.get("rejected_items", []):
            item_id = rej.get("item_id", "")
            if item_id in item_map:
                rejected.append(item_map[item_id])
                reasoning[item_id] = f"REJECTED: {rej.get('reason', '')}"

        # Warnings
        warnings = data.get("warnings", [])

        # Add cross-domain insights to warnings for visibility
        insights = data.get("cross_domain_insights", [])
        for insight in insights:
            warnings.append(f"[INSIGHT] {insight}")

        return MissionPlan(
            mission_summary=data.get("mission_summary", ""),
            selected_items=selected,
            reasoning=reasoning,
            warnings=warnings,
            rejected_items=rejected,
        )
