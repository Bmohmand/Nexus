# Nexus Frontend

Flutter mobile app for scanning items and searching your inventory. See the [root README](../README.md) for full project documentation.

## Features

- **Items Grid** — Browse your full inventory with images and metadata
- **Camera Scan** — Photograph items to ingest into the AI pipeline
- **Semantic Search** — Natural language queries against your vector database
- **Storage Containers** — Manage bags, crates, and other containers with weight limits

## Quick Start

```bash
cd frontend

# Install dependencies
flutter pub get

# Run the app
flutter run
```

## Environment Variables

Create `frontend/.env`:

```env
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key
API_BASE_URL=http://localhost:8000
```

The `API_BASE_URL` should point to the running backend server. For local development, use `http://localhost:8000`. For physical devices, use your machine's local IP (e.g., `http://192.168.1.x:8000`).

## Dependencies

Key packages (see `pubspec.yaml` for full list):

- **dio** — HTTP client for FastAPI backend communication
- **supabase_flutter** — Supabase Storage uploads and optional auth
- **image_picker** — Camera and gallery access for item scanning
- **flutter_dotenv** — Environment variable loading
