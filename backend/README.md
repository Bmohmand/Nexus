# Manifest Backend

Python FastAPI server + AI pipeline. **Uvicorn is a Python package** — install with `pip`, not `npm`.

## 1. Create a virtual environment (recommended)

Using a venv avoids clashes with other Python projects (e.g. whisperx, label-studio) that want different versions of torch/numpy/protobuf.

```powershell
cd backend
python -m venv .venv
.\.venv\Scripts\Activate.ps1
```

(If you get an execution policy error, run `Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser` once.)

Then install and run from this shell; only this project's deps will be used.

## 2. Install dependencies

From the `backend` folder (with the venv activated):

```powershell
pip install -r ai_modules/requirements.txt -r server/requirements.txt
```

Or install only what you need to run the API (no local CLIP):

```powershell
pip install pydantic openai supabase fastapi "uvicorn[standard]" python-multipart voyageai httpx
```

## 3. Set environment variables

Copy `server/.env.example` to `.env` in `backend` (or set in your shell) and fill in:

- `OPENAI_API_KEY`
- `VOYAGE_API_KEY`
- `SUPABASE_URL`
- `SUPABASE_SERVICE_KEY`

## 4. Run the API server

From the `backend` folder:

```powershell
python -m uvicorn server.main:app --reload --port 8000
```

Or use the script:

```powershell
.\run_server.bat
```

Then open the Flutter app; it will call `http://localhost:8000` by default.
