"""
Manifest API — Request / Response schemas.

These are the Pydantic models that define the HTTP contract between
the Flutter frontend and the FastAPI middleware. They are separate from
the internal ai_modules models to allow the API surface to evolve
independently of the pipeline internals.
"""

from pydantic import BaseModel, Field
from typing import Optional


# ---------------------------------------------------------------------------
# Ingest
# ---------------------------------------------------------------------------
class IngestRequest(BaseModel):
    """POST /api/v1/ingest — body when sending an image URL."""
    image_url: str = Field(description="Public URL of the image (e.g. Supabase Storage)")
    user_id: Optional[str] = Field(default=None, description="Owner user ID (from Supabase Auth)")
    profile_id: Optional[str] = Field(default=None, description="Optional profile the item belongs to")


class IngestResponse(BaseModel):
    item_id: str
    name: str
    domain: str
    category: str
    utility_summary: str
    semantic_tags: list[str]


# ---------------------------------------------------------------------------
# Search
# ---------------------------------------------------------------------------
class SearchRequest(BaseModel):
    """POST /api/v1/search"""
    query: str = Field(description="Natural language search query")
    top_k: int = Field(default=15, ge=1, le=50)
    domain_filter: Optional[str] = Field(default=None, description="Restrict to a domain")
    category_filter: Optional[str] = Field(default=None, description="Restrict to a category")
    synthesize: bool = Field(default=True, description="If true, run LLM synthesis on results")
    user_id: Optional[str] = Field(default=None, description="Scope search to this user's items")


class SearchResultItem(BaseModel):
    item_id: str
    name: str
    score: float
    image_url: Optional[str] = None
    category: Optional[str] = None
    domain: Optional[str] = None
    utility_summary: Optional[str] = None
    semantic_tags: list[str] = []
    reason: Optional[str] = None  # From LLM synthesis


class SearchResponse(BaseModel):
    mission_summary: Optional[str] = None
    selected_items: list[SearchResultItem] = []
    rejected_items: list[SearchResultItem] = []
    warnings: list[str] = []
    raw_results: list[SearchResultItem] = []  # Populated when synthesize=False


# ---------------------------------------------------------------------------
# Pack
# ---------------------------------------------------------------------------
class PackConstraints(BaseModel):
    max_weight_grams: float = Field(default=20000)
    category_minimums: dict[str, int] = Field(default_factory=dict)
    tag_minimums: dict[str, int] = Field(default_factory=dict)
    max_per_item: Optional[int] = None


class PackRequest(BaseModel):
    """POST /api/v1/pack"""
    query: str = Field(description="Mission description")
    constraints: PackConstraints | str = Field(
        description="Either a PackConstraints object or a preset name string"
    )
    top_k: int = Field(default=30, ge=1, le=100)
    category_filter: Optional[str] = None
    user_id: Optional[str] = None


class PackedItem(BaseModel):
    item_id: str
    name: str
    category: str
    quantity: int
    weight_grams: float
    similarity_score: float
    semantic_tags: list[str] = []


class PackResponse(BaseModel):
    status: str  # "optimal", "feasible", "infeasible"
    packed_items: list[PackedItem]
    total_weight_grams: float
    total_similarity_score: float
    weight_utilization: float
    solver_time_ms: float
    relaxed_constraints: list[str] = []
    # Optional LLM explanation (from pack_and_explain)
    mission_summary: Optional[str] = None
    warnings: list[str] = []


# ---------------------------------------------------------------------------
# Items CRUD
# ---------------------------------------------------------------------------
class ItemResponse(BaseModel):
    id: str
    name: str
    image_url: Optional[str] = None
    domain: str
    category: Optional[str] = None
    status: str
    quantity: int
    utility_summary: Optional[str] = None
    semantic_tags: list[str] = []
    weight_grams: Optional[float] = None
    created_at: Optional[str] = None


class ItemListResponse(BaseModel):
    items: list[ItemResponse]
    count: int
