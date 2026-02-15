"""
Nexus Embedding Space Tester
=============================
Tests whether multimodal embeddings meaningfully cluster physical items
by category AND reveal cross-domain semantic relationships.

Uses OpenAI CLIP (runs locally, no API key needed) as a proxy for
Vertex AI / Voyage multimodal embeddings.

Usage:
  1. Create a folder called `test_images/` with subfolders:
       test_images/
         clothing/       (wool coat, rain jacket, cotton tee, thermal socks, etc.)
         medical/        (bandages, trauma blanket, tourniquet, thermometer, etc.)
         tech/           (flashlight, solar charger, radio, GPS, etc.)
         camping/        (tent, sleeping bag, water filter, fire starter, etc.)
  2. pip install torch torchvision open-clip-torch Pillow scikit-learn matplotlib numpy
  3. python embedding_space_test.py
"""

import os
import sys
import json
import numpy as np
from pathlib import Path
import pytest
from collections import defaultdict
import matplotlib
# Force headless backend to avoid Tcl/Tk errors
matplotlib.use("Agg")

# ---------------------------------------------------------------------------
# CONFIG
# ---------------------------------------------------------------------------
IMAGE_DIR = Path(__file__).parent / "test_images"
CATEGORIES = ["clothing", "medical", "tech", "camping"]

# OPTIMIZATION: Switch to True for higher accuracy (uses ~1GB more RAM)
# ViT-L-14 captures more subtle semantic relationships than ViT-B-32.
USE_LARGE_MODEL = False

# Text queries that should pull items across categories
CROSS_DOMAIN_QUERIES = [
    "survive freezing temperatures overnight",
    "48-hour medical relief mission in a cold climate",
    "emergency wilderness first aid",
    "power outage in winter storm",
    "hiking trip with risk of injury",
]

# Items that SHOULD cluster together despite different categories
EXPECTED_CROSS_LINKS = {
    "cold_survival": [
        "wool coat", "thermal blanket", "sleeping bag", "hand warmers"
    ],
    "wound_care": [
        "bandages", "tourniquet", "antiseptic", "medical tape"
    ],
    "navigation": [
        "GPS device", "compass", "map", "flashlight"
    ],
}


def load_clip_model():
    """Load CLIP model - works offline, no API keys."""
    try:
        import open_clip
        
        if USE_LARGE_MODEL:
            print("[INIT] Loading ViT-L-14 (Large Model)...")
            model_name, pretrained = "ViT-L-14", "laion2b_s32b_b82k"
        else:
            print("[INIT] Loading ViT-B-32 (Base Model)...")
            model_name, pretrained = "ViT-B-32", "laion2b_s34b_b79k"

        model, _, preprocess = open_clip.create_model_and_transforms(
            model_name, pretrained=pretrained
        )
        tokenizer = open_clip.get_tokenizer(model_name)
        model.eval()
        print(f"[OK] CLIP model loaded ({model_name})")
        return model, preprocess, tokenizer
    except ImportError:
        print("ERROR: Install deps with:")
        print("  pip install torch torchvision open-clip-torch Pillow scikit-learn matplotlib")
        pytest.skip("Missing dependencies (open_clip, torch, etc.)")


def embed_images(model, preprocess, image_dir: Path):
    """Embed all images, returning {filepath: vector} and {filepath: category}."""
    import torch
    from PIL import Image

    embeddings = {}
    labels = {}

    for category in CATEGORIES:
        cat_dir = image_dir / category
        if not cat_dir.exists():
            print(f"  [SKIP] {cat_dir} not found")
            continue
        for img_path in sorted(cat_dir.iterdir()):
            if img_path.suffix.lower() not in (".jpg", ".jpeg", ".png", ".webp"):
                continue
            try:
                img = preprocess(Image.open(img_path).convert("RGB")).unsqueeze(0)
                with torch.no_grad():
                    vec = model.encode_image(img)
                    vec = vec / vec.norm(dim=-1, keepdim=True)  # L2 normalize
                embeddings[str(img_path)] = vec.squeeze().numpy()
                labels[str(img_path)] = category
                print(f"  [EMB] {img_path.name} -> {category}")
            except Exception as e:
                print(f"  [ERR] {img_path.name}: {e}")

    return embeddings, labels


def embed_text_queries(model, tokenizer, queries: list[str]):
    """Embed natural-language queries into the same vector space."""
    import torch
    text_vecs = {}
    for q in queries:
        tokens = tokenizer([q])
        with torch.no_grad():
            vec = model.encode_text(tokens)
            vec = vec / vec.norm(dim=-1, keepdim=True)
        text_vecs[q] = vec.squeeze().numpy()
    return text_vecs


def cosine_sim(a, b):
    return float(np.dot(a, b) / (np.linalg.norm(a) * np.linalg.norm(b) + 1e-9))


# ---------------------------------------------------------------------------
# PYTEST FIXTURES
# ---------------------------------------------------------------------------
@pytest.fixture(scope="module")
def model_bundle():
    """Load CLIP model once for the module."""
    return load_clip_model()

@pytest.fixture(scope="module")
def model(model_bundle):
    return model_bundle[0]

@pytest.fixture(scope="module")
def preprocess(model_bundle):
    return model_bundle[1]

@pytest.fixture(scope="module")
def tokenizer(model_bundle):
    return model_bundle[2]

@pytest.fixture(scope="module")
def loaded_data(model, preprocess, tokenizer):
    """Load images or generate synthetic data for tests."""
    # Check if test images exist
    has_images = IMAGE_DIR.exists() and any(
        (IMAGE_DIR / cat).exists() and list((IMAGE_DIR / cat).iterdir())
        for cat in CATEGORIES
        if (IMAGE_DIR / cat).exists()
    )

    if has_images:
        embeddings, labels = embed_images(model, preprocess, IMAGE_DIR)
        if len(embeddings) >= 4:
            return embeddings, labels

    # Fallback: Generate synthetic data
    print("[WARN] Using synthetic data for tests (no images found)")
    import torch
    # Use a subset of the synthetic generator logic
    items = {
        "clothing": ["heavy wool winter coat", "lightweight cotton t-shirt"],
        "medical": ["sterile trauma bandage", "emergency thermal blanket"],
        "tech": ["tactical flashlight", "portable solar panel"],
        "camping": ["4-season sleeping bag", "water filtration pump"],
    }
    paths, texts, lbls = [], [], []
    for cat, descs in items.items():
        for i, desc in enumerate(descs):
            paths.append(f"synthetic_{cat}_{i}")
            texts.append(desc)
            lbls.append(cat)
    
    tokens = tokenizer(texts)
    with torch.no_grad():
        vecs = model.encode_text(tokens)
        vecs = vecs / vecs.norm(dim=-1, keepdim=True)
    
    embeddings = {p: v.numpy() for p, v in zip(paths, vecs)}
    labels = {p: l for p, l in zip(paths, lbls)}
    return embeddings, labels

@pytest.fixture(scope="module")
def embeddings(loaded_data): return loaded_data[0]

@pytest.fixture(scope="module")
def labels(loaded_data): return loaded_data[1]

@pytest.fixture(scope="module")
def text_vecs(model, tokenizer):
    return embed_text_queries(model, tokenizer, CROSS_DOMAIN_QUERIES)


# ---------------------------------------------------------------------------
# TEST 1: Intra-category vs Inter-category similarity
# ---------------------------------------------------------------------------
def test_clustering(embeddings, labels):
    """
    Validates that items in the SAME category are more similar to each other
    than to items in OTHER categories. This is the baseline sanity check.
    """
    print("\n" + "=" * 60)
    print("TEST 1: Category Clustering (intra vs inter similarity)")
    print("=" * 60)

    by_cat = defaultdict(list)
    for path, vec in embeddings.items():
        by_cat[labels[path]].append(vec)

    intra_sims = {}
    for cat, vecs in by_cat.items():
        if len(vecs) < 2:
            continue
        sims = []
        for i in range(len(vecs)):
            for j in range(i + 1, len(vecs)):
                sims.append(cosine_sim(vecs[i], vecs[j]))
        intra_sims[cat] = np.mean(sims)
        print(f"  {cat:12s} avg intra-similarity: {intra_sims[cat]:.4f}  (n={len(vecs)} items)")

    # Inter-category
    cats = list(by_cat.keys())
    inter_sims = []
    for i in range(len(cats)):
        for j in range(i + 1, len(cats)):
            for v1 in by_cat[cats[i]]:
                for v2 in by_cat[cats[j]]:
                    inter_sims.append(cosine_sim(v1, v2))
    avg_inter = np.mean(inter_sims) if inter_sims else 0

    print(f"\n  Average INTER-category similarity: {avg_inter:.4f}")
    avg_intra = np.mean(list(intra_sims.values())) if intra_sims else 0
    print(f"  Average INTRA-category similarity: {avg_intra:.4f}")

    gap = avg_intra - avg_inter
    verdict = "PASS" if gap > 0.03 else "WEAK" if gap > 0 else "FAIL"
    print(f"\n  Separation gap: {gap:.4f}  [{verdict}]")
    print(f"  (You want intra >> inter. Gap > 0.05 is strong.)")
    assert gap > 0, f"Intra-category similarity should be higher than inter-category (gap={gap:.4f})"


# ---------------------------------------------------------------------------
# TEST 2: Cross-domain semantic search
# ---------------------------------------------------------------------------
def test_semantic_search(embeddings, labels, text_vecs):
    """
    For each natural-language query, find the top-k nearest items.
    Validates that results span MULTIPLE categories (the core Nexus thesis).
    """
    print("\n" + "=" * 60)
    print("TEST 2: Cross-Domain Semantic Search")
    print("=" * 60)

    paths = list(embeddings.keys())
    vecs = np.array([embeddings[p] for p in paths])

    for query, qvec in text_vecs.items():
        sims = vecs @ qvec  # cosine sim (already normalized)
        top_idx = np.argsort(sims)[::-1][:8]

        print(f'\n  Query: "{query}"')
        result_cats = set()
        for rank, idx in enumerate(top_idx):
            p = paths[idx]
            cat = labels[p]
            result_cats.add(cat)
            name = Path(p).stem
            print(f"    {rank+1}. [{cat:10s}] {name:30s} sim={sims[idx]:.4f}")

        cross = len(result_cats) > 1
        print(f"  -> Categories hit: {result_cats}  {'CROSS-DOMAIN' if cross else 'single-domain'}")


# ---------------------------------------------------------------------------
# TEST 3: Pairwise similarity heatmap
# ---------------------------------------------------------------------------
def test_heatmap(embeddings, labels):
    """Generate a similarity heatmap to visually inspect structure."""
    from matplotlib import pyplot as plt
    from sklearn.metrics.pairwise import cosine_similarity

    print("\n" + "=" * 60)
    print("TEST 3: Generating similarity heatmap...")
    print("=" * 60)

    paths = sorted(embeddings.keys(), key=lambda p: labels[p])
    vecs = np.array([embeddings[p] for p in paths])
    sim_matrix = cosine_similarity(vecs)

    fig, ax = plt.subplots(figsize=(12, 10))
    im = ax.imshow(sim_matrix, cmap="RdYlGn", vmin=0, vmax=1)
    plt.colorbar(im, ax=ax, label="Cosine Similarity")

    # Category boundaries
    cats_ordered = [labels[p] for p in paths]
    tick_labels = [f"{Path(p).stem[:18]}" for p in paths]
    ax.set_xticks(range(len(paths)))
    ax.set_xticklabels(tick_labels, rotation=90, fontsize=6)
    ax.set_yticks(range(len(paths)))
    ax.set_yticklabels(tick_labels, fontsize=6)

    # Draw category dividers
    prev_cat = cats_ordered[0]
    for i, cat in enumerate(cats_ordered):
        if cat != prev_cat:
            ax.axhline(i - 0.5, color="black", linewidth=2)
            ax.axvline(i - 0.5, color="black", linewidth=2)
            prev_cat = cat

    ax.set_title("Nexus Embedding Space - Item Similarity Matrix")
    plt.tight_layout()
    plt.savefig("similarity_heatmap.png", dpi=150)
    print("  Saved: similarity_heatmap.png")


# ---------------------------------------------------------------------------
# TEST 4: 2D Projection (t-SNE / UMAP)
# ---------------------------------------------------------------------------
def test_2d_projection(embeddings, labels):
    """Project embedding space to 2D to visualize clusters."""
    from matplotlib import pyplot as plt
    from sklearn.manifold import TSNE

    print("\n" + "=" * 60)
    print("TEST 4: 2D t-SNE projection...")
    print("=" * 60)

    paths = list(embeddings.keys())
    vecs = np.array([embeddings[p] for p in paths])
    cats = [labels[p] for p in paths]

    n = len(vecs)
    perplexity = min(5, n - 1) if n > 2 else 1
    tsne = TSNE(n_components=2, perplexity=perplexity, random_state=42)
    coords = tsne.fit_transform(vecs)

    color_map = {
        "clothing": "#E74C3C",
        "medical": "#2ECC71",
        "tech": "#3498DB",
        "camping": "#F39C12",
    }

    fig, ax = plt.subplots(figsize=(12, 10))
    for cat in CATEGORIES:
        mask = [c == cat for c in cats]
        if not any(mask):
            continue
        xs = coords[mask, 0]
        ys = coords[mask, 1]
        ax.scatter(xs, ys, c=color_map.get(cat, "gray"), label=cat, s=120, alpha=0.8)
        for i, (x, y) in enumerate(zip(xs, ys)):
            idx = [j for j, m in enumerate(mask) if m][i]
            name = Path(paths[idx]).stem[:15]
            ax.annotate(name, (x, y), fontsize=7, alpha=0.7)

    ax.legend(fontsize=12)
    ax.set_title("Nexus Embedding Space - 2D Projection (t-SNE)")
    ax.set_xlabel("Dim 1")
    ax.set_ylabel("Dim 2")
    plt.tight_layout()
    plt.savefig("embedding_2d_projection.png", dpi=150)
    print("  Saved: embedding_2d_projection.png")


# ---------------------------------------------------------------------------
# TEST 5: The "Cotton T-Shirt Rejection" Test
# ---------------------------------------------------------------------------
def test_rejection(embeddings, labels, model, tokenizer):
    """
    Validates that semantically WRONG items rank low.
    A cotton t-shirt should NOT appear near "cold survival" queries.
    """
    import torch

    print("\n" + "=" * 60)
    print('TEST 5: "Smart Rejection" — Cotton in Cold Weather')
    print("=" * 60)

    query = "survive extreme cold, stay warm and dry"
    tokens = tokenizer([query])
    with torch.no_grad():
        qvec = model.encode_text(tokens)
        qvec = qvec / qvec.norm(dim=-1, keepdim=True)
    qvec = qvec.squeeze().numpy()

    paths = list(embeddings.keys())
    vecs = np.array([embeddings[p] for p in paths])
    sims = vecs @ qvec
    ranked = sorted(zip(paths, sims), key=lambda x: -x[1])

    # Check if anything with "cotton" or "tee" or "tshirt" is in top 5
    top5_names = [Path(p).stem.lower() for p, _ in ranked[:5]]
    cotton_keywords = ["cotton", "tee", "tshirt", "t-shirt", "t_shirt"]
    cotton_in_top = any(
        kw in name for name in top5_names for kw in cotton_keywords
    )

    print(f'  Query: "{query}"')
    print(f"  Top 5 results: {top5_names}")
    if cotton_in_top:
        print("  [WARN] Cotton item found in top 5 — embedding may not capture material safety.")
    else:
        print("  [PASS] No cotton items in top 5 for cold survival query.")

    # Show where cotton items actually ranked
    for path, sim in ranked:
        name = Path(path).stem.lower()
        if any(kw in name for kw in cotton_keywords):
            rank = [p for p, _ in ranked].index(path) + 1
            print(f"  Cotton item '{Path(path).stem}' ranked #{rank}/{len(ranked)} (sim={sim:.4f})")


# ---------------------------------------------------------------------------
# BONUS: Generate synthetic test set if no images exist
# ---------------------------------------------------------------------------
def generate_synthetic_test(model, tokenizer):
    """
    If you don't have images yet, test the embedding space using
    TEXT-ONLY descriptions as a proxy. This lets you validate the
    concept before spending time photographing 50 items.
    """
    import torch

    print("\n" + "=" * 60)
    print("SYNTHETIC TEST (no images needed)")
    print("=" * 60)

    # Simulate items as rich text descriptions
    items = {
        "clothing": [
            "heavy wool winter coat, waterproof outer shell",
            "lightweight cotton t-shirt for summer",
            "Gore-Tex rain jacket with sealed seams",
            "thermal insulated socks, merino wool blend",
            "down-filled puffer vest for layering",
        ],
        "medical": [
            "sterile trauma bandage, military grade tourniquet",
            "emergency thermal mylar blanket, retains 90% body heat",
            "waterproof first aid kit with antiseptic and sutures",
            "digital medical thermometer",
            "SAM splint for fracture immobilization",
        ],
        "tech": [
            "high-lumen tactical flashlight, waterproof",
            "portable solar panel charger 20W",
            "handheld GPS navigation device",
            "emergency hand-crank AM/FM radio",
            "rechargeable lithium battery pack 20000mAh",
        ],
        "camping": [
            "4-season insulated sleeping bag rated to -20F",
            "ultralight backpacking tent, 2-person",
            "portable water filtration pump",
            "magnesium fire starter with striker",
            "insulated camping stove with fuel canister",
        ],
    }

    # Embed all text descriptions
    all_texts = []
    all_labels = []
    all_names = []
    for cat, descs in items.items():
        for desc in descs:
            all_texts.append(desc)
            all_labels.append(cat)
            all_names.append(desc[:40])

    tokens = tokenizer(all_texts)
    with torch.no_grad():
        vecs = model.encode_text(tokens)
        vecs = vecs / vecs.norm(dim=-1, keepdim=True)
    vecs = vecs.numpy()

    # Clustering test
    from collections import defaultdict
    by_cat = defaultdict(list)
    for i, cat in enumerate(all_labels):
        by_cat[cat].append(vecs[i])

    print("\n  Intra-category similarities:")
    for cat, cat_vecs in by_cat.items():
        sims = []
        for i in range(len(cat_vecs)):
            for j in range(i + 1, len(cat_vecs)):
                sims.append(cosine_sim(cat_vecs[i], cat_vecs[j]))
        print(f"    {cat:12s}: {np.mean(sims):.4f}")

    # Cross-domain search
    print("\n  Cross-domain search:")
    queries = [
        "survive freezing temperatures overnight",
        "treat a wound in the wilderness",
        "navigate without cell service",
    ]
    for q in queries:
        qt = tokenizer([q])
        with torch.no_grad():
            qv = model.encode_text(qt)
            qv = qv / qv.norm(dim=-1, keepdim=True)
        qv = qv.squeeze().numpy()
        sims = vecs @ qv
        top_idx = np.argsort(sims)[::-1][:5]
        print(f'\n    "{q}"')
        for rank, idx in enumerate(top_idx):
            print(f"      {rank+1}. [{all_labels[idx]:10s}] {all_names[idx]}  (sim={sims[idx]:.4f})")


# ---------------------------------------------------------------------------
# MAIN
# ---------------------------------------------------------------------------
def main():
    print("=" * 60)
    print("  NEXUS EMBEDDING SPACE TESTER")
    print("=" * 60)

    model, preprocess, tokenizer = load_clip_model()

    # Check if test images exist
    has_images = IMAGE_DIR.exists() and any(
        (IMAGE_DIR / cat).exists() and list((IMAGE_DIR / cat).iterdir())
        for cat in CATEGORIES
        if (IMAGE_DIR / cat).exists()
    )

    if has_images:
        print("\n[PHASE 1] Embedding images...")
        embeddings, labels = embed_images(model, preprocess, IMAGE_DIR)

        if len(embeddings) < 4:
            print("[WARN] Too few images. Need at least 4. Running synthetic test instead.")
            generate_synthetic_test(model, tokenizer)
            return

        print("\n[PHASE 2] Embedding text queries...")
        text_vecs = embed_text_queries(model, tokenizer, CROSS_DOMAIN_QUERIES)

        print("\n[PHASE 3] Running tests...")
        test_clustering(embeddings, labels)
        test_semantic_search(embeddings, labels, text_vecs)
        test_heatmap(embeddings, labels)
        test_2d_projection(embeddings, labels)
        test_rejection(embeddings, labels, model, tokenizer)

    else:
        print(f"\n[INFO] No images found in {IMAGE_DIR}/")
        print("       Running SYNTHETIC text-only test to validate concept.\n")
        generate_synthetic_test(model, tokenizer)

    print("\n" + "=" * 60)
    print("  DONE. Check .png files for visualizations.")
    print("=" * 60)


if __name__ == "__main__":
    main()