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
    explain: bool = Field(default=False, description="If true, run LLM synthesis for mission summary and warnings")


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


# ---------------------------------------------------------------------------
# Storage Containers
# ---------------------------------------------------------------------------
class ContainerCreate(BaseModel):
    """POST /api/v1/containers — create a new storage container."""
    name: str = Field(description="Human-readable container name")
    description: Optional[str] = None
    container_type: str = Field(default="bag")
    max_weight_grams: float = Field(default=20000, gt=0)
    max_volume_liters: Optional[float] = None
    tare_weight_grams: float = Field(default=0, ge=0)
    quantity: int = Field(default=1, ge=1)
    is_default: bool = False
    icon: Optional[str] = None
    color: Optional[str] = None
    user_id: Optional[str] = None


class ContainerUpdate(BaseModel):
    """PATCH /api/v1/containers/{id}"""
    name: Optional[str] = None
    description: Optional[str] = None
    container_type: Optional[str] = None
    max_weight_grams: Optional[float] = Field(default=None, gt=0)
    max_volume_liters: Optional[float] = None
    tare_weight_grams: Optional[float] = Field(default=None, ge=0)
    quantity: Optional[int] = Field(default=None, ge=1)
    is_default: Optional[bool] = None
    icon: Optional[str] = None
    color: Optional[str] = None


class ContainerResponse(BaseModel):
    id: str
    name: str
    description: Optional[str] = None
    container_type: str = "bag"
    max_weight_grams: float
    max_volume_liters: Optional[float] = None
    tare_weight_grams: float = 0
    quantity: int = 1
    is_default: bool = False
    icon: Optional[str] = None
    color: Optional[str] = None
    created_at: Optional[str] = None
    updated_at: Optional[str] = None


class ContainerListResponse(BaseModel):
    containers: list[ContainerResponse]
    count: int


# ---------------------------------------------------------------------------
# Multi-Container Pack
# ---------------------------------------------------------------------------
class MultiPackRequest(BaseModel):
    """POST /api/v1/pack/multi — pack across multiple containers."""
    query: str = Field(description="Mission description")
    container_ids: list[str] = Field(description="Container UUIDs to pack into")
    constraints: Optional[PackConstraints] = Field(
        default=None,
        description="Optional diversity constraints (category_minimums, etc.)"
    )
    top_k: int = Field(default=30, ge=1, le=100)
    category_filter: Optional[str] = None
    user_id: Optional[str] = None
    explain: bool = Field(default=False, description="If true, run LLM synthesis for mission summary and warnings")


class ContainerPackedItems(BaseModel):
    """Items assigned to a single container."""
    container_id: str
    container_name: str
    max_weight_grams: float
    packed_items: list[PackedItem]
    total_weight_grams: float
    weight_utilization: float


class MultiPackResponse(BaseModel):
    status: str  # "optimal", "feasible", "infeasible"
    containers: list[ContainerPackedItems]
    total_weight_grams: float
    total_similarity_score: float
    solver_time_ms: float
    relaxed_constraints: list[str] = []
    unpacked_items: list[PackedItem] = []
    mission_summary: Optional[str] = None
    warnings: list[str] = []
