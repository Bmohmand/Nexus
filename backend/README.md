# Nexus Backend

Python FastAPI server + AI pipeline. See the [root README](../README.md) for full project documentation.

## Quick Start

```powershell
cd backend

# 1. Create virtual environment
python -m venv .venv
.\.venv\Scripts\Activate.ps1    # Windows
# source .venv/bin/activate     # macOS/Linux

# 2. Install all dependencies (single consolidated file)
pip install -r requirements.txt

# 3. Configure environment variables
copy .env.example .env          # Then edit with your API keys

# 4. Run the server
python -m uvicorn server.main:app --reload --port 8000
```

API docs: `http://localhost:8000/docs`

## Environment Variables

The server loads `backend/.env` at startup. Required keys:

| Variable | Source |
|---|---|
| `OPENAI_API_KEY` | [OpenAI](https://platform.openai.com) |
| `VOYAGE_API_KEY` | [Voyage AI](https://voyageai.com) |
| `SUPABASE_URL` | Supabase Dashboard → Project Settings → API |
| `SUPABASE_SERVICE_KEY` | Supabase **service_role** key (not the anon key) |

## Minimal Install (no local CLIP fallback)

If you don't need offline CLIP embeddings, skip the heavy PyTorch dependencies:

```powershell
pip install pydantic openai supabase fastapi "uvicorn[standard]" python-multipart voyageai httpx python-dotenv numpy Pillow ortools requests
```

## Seed Scripts

Populate the database with sample items:

```powershell
python seed_test_images.py    # 34 local test images
python seed_dummyjson.py      # 100 products from DummyJSON API
```
