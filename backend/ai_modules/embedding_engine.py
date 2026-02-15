"""
nexus_ai/embedding_engine.py
=============================
Step 2 of the 2-step AI pipeline.

Takes the raw image + the extracted ItemContext from Step 1 and produces
a unified multimodal embedding vector. This vector is what gets stored
in Supabase and searched against.

Supports 2 providers:
  - Voyage AI (voyage-multimodal-3.5) — state-of-the-art multimodal embeddings
    with interleaved text+image support and Matryoshka flexible dimensions
  - Local CLIP (ViT-B-32) — offline fallback for dev/bad wifi

Called by: pipeline.py
"""

import base64
import json
import logging
from abc import ABC, abstractmethod
from pathlib import Path

import numpy as np

from .config import (
    EMBEDDING_PROVIDER,
    EmbeddingProvider,
    VOYAGE_API_KEY,
    VOYAGE_MODEL,
    get_embedding_dim,
)
from .models import ItemContext

logger = logging.getLogger("nexus.embeddings")


# ---------------------------------------------------------------------------
# Abstract base — all providers implement this interface
# ---------------------------------------------------------------------------
class BaseEmbedder(ABC):
    """Interface for embedding providers."""

    @abstractmethod
    async def embed_item(self, image_source: str | bytes, context: ItemContext) -> list[float]:
        """Generate a multimodal embedding from image + semantic context."""
        ...

    @abstractmethod
    async def embed_text(self, text: str) -> list[float]:
        """Embed a text-only query (for search)."""
        ...

    @property
    @abstractmethod
    def dimension(self) -> int:
        ...


# ---------------------------------------------------------------------------
# Provider 1: Voyage AI (Recommended)
# ---------------------------------------------------------------------------
class VoyageEmbedder(BaseEmbedder):
    """
    Uses Voyage AI's voyage-multimodal-3.5 model.

    Key advantages over the previous multimodal-3:
      - Higher retrieval accuracy (4.56% over Cohere Embed v4)
      - Matryoshka embeddings: flexible dimensions (2048, 1024, 512, 256)
      - Video frame support (not used here, but future-proof)
      - Single unified transformer backbone (no modality gap like CLIP)

    Docs: https://docs.voyageai.com/docs/multimodal-embeddings
    """

    def __init__(self, api_key: str = VOYAGE_API_KEY, output_dimension: int = 1024):
        if not api_key:
            raise ValueError("VOYAGE_API_KEY required")
        import voyageai
        self.client = voyageai.AsyncClient(api_key=api_key)
        self._dimension = output_dimension

    @property
    def dimension(self) -> int:
        return self._dimension

    async def embed_item(self, image_source: str | bytes, context: ItemContext) -> list[float]:
        """
        Voyage multimodal-3.5 accepts interleaved content through a
        single transformer backbone. We pass both the image AND the
        extracted text profile so the embedding captures visual +
        semantic information without modality gap.
        """
        # Build the rich text context that supplements the image
        context_text = self._build_context_text(context)

        # Prepare image
        if isinstance(image_source, str) and not image_source.startswith("http"):
            image_source = Path(image_source)

        # Voyage multimodal accepts a list of mixed content
        inputs = [[image_source, context_text]]

        result = await self.client.multimodal_embed(
            inputs=inputs,
            model=VOYAGE_MODEL,
            input_type="document",           # "document" for items being stored
            output_dimension=self._dimension, # Matryoshka: 2048, 1024, 512, or 256
        )
        return result.embeddings[0]

    async def embed_text(self, text: str) -> list[float]:
        """Embed a search query as text-only."""
        result = await self.client.multimodal_embed(
            inputs=[[text]],
            model=VOYAGE_MODEL,
            input_type="query",              # "query" for search queries
            output_dimension=self._dimension,
        )
        return result.embeddings[0]

    @staticmethod
    def _build_context_text(ctx: ItemContext) -> str:
        """Serialize the extracted context into an embedding-friendly text block."""
        parts = [
            f"Item: {ctx.name}",
            f"Category: {ctx.inferred_category}",
            f"Utility: {ctx.utility_summary}",
        ]
        if ctx.primary_material:
            parts.append(f"Material: {ctx.primary_material}")
        if ctx.thermal_rating:
            parts.append(f"Thermal: {ctx.thermal_rating}")
        if ctx.water_resistance:
            parts.append(f"Water resistance: {ctx.water_resistance}")
        if ctx.medical_application:
            parts.append(f"Medical use: {ctx.medical_application}")
        if ctx.semantic_tags:
            parts.append(f"Tags: {', '.join(ctx.semantic_tags)}")
        return ". ".join(parts)


# ---------------------------------------------------------------------------
# Provider 2: Local CLIP (offline fallback)
# ---------------------------------------------------------------------------
class CLIPEmbedder(BaseEmbedder):
    """
    Local CLIP ViT-B-32 fallback. No API keys needed.
    Quality is significantly lower than Voyage but works without internet.
    Use only for local dev or if hackathon wifi dies.
    """

    def __init__(self):
        import open_clip
        import torch
        self.device = "cuda" if torch.cuda.is_available() else "cpu"
        self.model, _, self.preprocess = open_clip.create_model_and_transforms(
            "ViT-B-32", pretrained="laion2b_s34b_b79k"
        )
        self.tokenizer = open_clip.get_tokenizer("ViT-B-32")
        self.model.to(self.device).eval()
        logger.info(f"CLIP loaded on {self.device}")

    @property
    def dimension(self) -> int:
        return 512

    async def embed_item(self, image_source: str | bytes, context: ItemContext) -> list[float]:
        """
        CLIP doesn't natively do multimodal fusion, so we embed the image
        and text separately and average them (a simple but effective trick).
        """
        import torch
        from PIL import Image as PILImage
        import io

        # Embed image
        if isinstance(image_source, bytes):
            img = PILImage.open(io.BytesIO(image_source)).convert("RGB")
        elif isinstance(image_source, str) and image_source.startswith("http"):
            import httpx
            async with httpx.AsyncClient() as client:
                resp = await client.get(image_source)
                img = PILImage.open(io.BytesIO(resp.content)).convert("RGB")
        else:
            img = PILImage.open(image_source).convert("RGB")

        img_tensor = self.preprocess(img).unsqueeze(0).to(self.device)
        with torch.no_grad():
            img_vec = self.model.encode_image(img_tensor)
            img_vec = img_vec / img_vec.norm(dim=-1, keepdim=True)

        # Embed context text
        context_text = VoyageEmbedder._build_context_text(context)
        tokens = self.tokenizer([context_text]).to(self.device)
        with torch.no_grad():
            txt_vec = self.model.encode_text(tokens)
            txt_vec = txt_vec / txt_vec.norm(dim=-1, keepdim=True)

        # Fuse: weighted average (image 60%, text 40%)
        fused = 0.6 * img_vec + 0.4 * txt_vec
        fused = fused / fused.norm(dim=-1, keepdim=True)

        return fused.squeeze().cpu().tolist()

    async def embed_text(self, text: str) -> list[float]:
        import torch
        tokens = self.tokenizer([text]).to(self.device)
        with torch.no_grad():
            vec = self.model.encode_text(tokens)
            vec = vec / vec.norm(dim=-1, keepdim=True)
        return vec.squeeze().cpu().tolist()


# ---------------------------------------------------------------------------
# Factory — returns the right embedder based on config
# ---------------------------------------------------------------------------
def create_embedder(provider: EmbeddingProvider = EMBEDDING_PROVIDER) -> BaseEmbedder:
    """
    Factory function. Zihan's backend calls this once at startup.
    Usage:
        embedder = create_embedder()
        vector = await embedder.embed_item(image, context)
    """
    match provider:
        case EmbeddingProvider.VOYAGE:
            logger.info("Using Voyage AI embeddings (voyage-multimodal-3.5)")
            return VoyageEmbedder()
        case EmbeddingProvider.CLIP_LOCAL:
            logger.info("Using local CLIP embeddings (ViT-B-32) — offline fallback")
            return CLIPEmbedder()
        case _:
            raise ValueError(f"Unknown embedding provider: {provider}")
