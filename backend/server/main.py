"""
Manifest API — FastAPI Application
====================================
The HTTP middleware that connects the Flutter frontend to the AI pipeline.

Start with:
    uvicorn backend.server.main:app --reload --port 8000

Or from the backend/ directory:
    uvicorn server.main:app --reload --port 8000
"""

import logging
from pathlib import Path
from contextlib import asynccontextmanager

from dotenv import load_dotenv

# Load backend/.env before any component reads os.environ
_env_path = Path(__file__).resolve().parent.parent / ".env"
load_dotenv(_env_path)

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from .dependencies import get_pipeline
from .routes import ingest, search, pack, items, containers

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(name)-20s | %(levelname)-7s | %(message)s",
    datefmt="%H:%M:%S",
)
logger = logging.getLogger("manifest.server")


# ---------------------------------------------------------------------------
# Lifespan: warm up the pipeline at startup
# ---------------------------------------------------------------------------
@asynccontextmanager
async def lifespan(app: FastAPI):
    """Initialize the AI pipeline once at server startup."""
    logger.info("Starting Manifest API server...")
    pipeline = get_pipeline()
    count = await pipeline.item_count()
    logger.info(f"Pipeline ready. {count} items in database.")
    yield
    logger.info("Manifest API server shutting down.")


# ---------------------------------------------------------------------------
# App
# ---------------------------------------------------------------------------
app = FastAPI(
    title="Manifest API",
    description="AI-powered search engine for physical assets",
    version="1.0.0",
    lifespan=lifespan,
)

# CORS — allow Flutter web & mobile to connect
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Tighten in production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ---------------------------------------------------------------------------
# Routes
# ---------------------------------------------------------------------------
app.include_router(ingest.router, prefix="/api/v1", tags=["Ingest"])
app.include_router(search.router, prefix="/api/v1", tags=["Search"])
app.include_router(pack.router, prefix="/api/v1", tags=["Pack"])
app.include_router(items.router, prefix="/api/v1", tags=["Items"])
app.include_router(containers.router, prefix="/api/v1", tags=["Containers"])


@app.get("/health")
async def health():
    return {"status": "ok", "service": "manifest-api"}
