"""
manifest/models.py
==================
Shared data models used across all Manifest pipeline modules.
"""

from pydantic import BaseModel, Field
from typing import Optional
import uuid


class ItemContext(BaseModel):
    """
    Structured output from the Vision LLM (Step 1 of the pipeline).
    This is the semantic profile GPT-5 extracts from a raw image.
    """
    name: str = Field(description="Human-readable item name, e.g. 'Gore-Tex Rain Jacket'")
    inferred_category: str = Field(description="Primary category: clothing, medical, tech, camping, food, misc")
    primary_material: Optional[str] = Field(default=None, description="Dominant material, e.g. 'Gore-Tex nylon', 'stainless steel'")
    weight_estimate: Optional[str] = Field(default=None, description="Rough weight: 'ultralight', 'light', 'medium', 'heavy'")
    thermal_rating: Optional[str] = Field(default=None, description="Thermal context: 'cold-rated', 'warm-weather', 'neutral', 'insulated'")
    water_resistance: Optional[str] = Field(default=None, description="'waterproof', 'water-resistant', 'not water-resistant'")
    medical_application: Optional[str] = Field(default=None, description="If medical: 'wound_care', 'thermal_regulation', 'immobilization', etc.")
    utility_summary: str = Field(description="1-2 sentence plain-English description of what this item is good for")
    semantic_tags: list[str] = Field(default_factory=list, description="Freeform tags: ['first_aid', 'sterile', 'survival', 'cold-weather']")
    durability: Optional[str] = Field(default=None, description="'disposable', 'reusable', 'rugged'")
    compressibility: Optional[str] = Field(default=None, description="'highly_compressible', 'moderate', 'rigid'")
    quantity: int = Field(default=1, description="Number of this item available (for consumables like bandages, batteries)")


class EmbeddingResult(BaseModel):
    """
    Output of the embedding engine (Step 2). This is what gets
    sent to Zihan to upsert into Supabase.
    """
    item_id: str = Field(default_factory=lambda: str(uuid.uuid4()))
    vector: list[float] = Field(description="The high-dimensional embedding vector")
    dimension: int = Field(description="Length of the vector (for validation)")
    context: ItemContext = Field(description="The extracted semantic profile")
    image_url: Optional[str] = Field(default=None, description="S3/R2 URL after Zihan uploads the image")


class SearchQuery(BaseModel):
    """Incoming search request from the Manifest UI."""
    query_text: str = Field(description="Natural language, e.g. '48-hour cold climate medical mission'")
    top_k: int = Field(default=15, ge=1, le=50)
    category_filter: Optional[str] = Field(default=None, description="Optional: restrict to one category")


class RetrievedItem(BaseModel):
    """A single item returned from Supabase vector search."""
    item_id: str
    score: float = Field(description="Cosine similarity score (0-1)")
    image_url: Optional[str] = None
    weight_grams: Optional[float] = None  # From DB when present; else optimizer estimates from weight_estimate
    context: ItemContext


class MissionPlan(BaseModel):
    """
    The final synthesized output — an AI-curated manifest
    with reasoning for each item selection.
    """
    mission_summary: str = Field(description="1-2 sentence interpretation of the user's mission")
    selected_items: list[RetrievedItem] = Field(description="Curated subset of retrieved items")
    reasoning: dict[str, str] = Field(
        default_factory=dict,
        description="item_id -> explanation of why this item was selected"
    )
    warnings: list[str] = Field(
        default_factory=list,
        description="Safety warnings, e.g. 'Cotton clothing detected — dangerous in cold/wet conditions'"
    )
    rejected_items: list[RetrievedItem] = Field(
        default_factory=list,
        description="Items the AI intentionally excluded, with reasons"
    )
