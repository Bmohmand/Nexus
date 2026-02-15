-- ============================================================================
-- Manifest Migration 004: manifest_items (Unified Items Table)
-- ============================================================================
-- This is the core table. It merges:
--   - closet_items  (fashion-specific structured fields)
--   - assets        (pgvector 1536-dim, OpenAI)
--   - nexus_items   (pgvector 1024-dim, Voyage)
--
-- Into ONE table with:
--   - Structured metadata (domain, category, environmental rating, etc.)
--   - AI-extracted context fields (from GPT-5 Vision)
--   - A 1024-dim embedding column (Voyage multimodal-3.5)
-- ============================================================================

create table if not exists manifest_items (
  id                  uuid default uuid_generate_v4() primary key,
  user_id             uuid references auth.users(id) on delete cascade not null,
  profile_id          uuid references profiles(id) on delete set null,

  -- ---- Core identity ----
  name                text not null,
  image_url           text,                          -- Supabase Storage / external URL
  domain              item_domain not null default 'general',
  category            text,                          -- Free-text, AI-assigned (e.g. "rain jacket", "tourniquet")
  status              item_status default 'available',
  quantity            int default 1 check (quantity >= 0),  -- For consumables (bandages, batteries)

  -- ---- Physical properties (user-editable + AI-estimated) ----
  environmental_rating int check (environmental_rating between 0 and 10),  -- 0 = hot-weather-only, 10 = extreme-cold
  volume_score        float default 1.0,             -- Packing volume weight for knapsack
  weight_grams        float,                         -- Actual or estimated weight

  -- ---- AI-extracted context (from GPT-5 Vision via ContextExtractor) ----
  primary_material    text,
  weight_estimate     text,                          -- 'ultralight', 'light', 'medium', 'heavy'
  thermal_rating      text,                          -- 'cold-rated', 'warm-weather', 'neutral', 'insulated'
  water_resistance    text,                          -- 'waterproof', 'water-resistant', 'not water-resistant'
  medical_application text,                          -- 'wound_care', 'thermal_regulation', etc.
  utility_summary     text,                          -- 1-2 sentence description
  semantic_tags       jsonb default '[]'::jsonb,     -- Freeform tags: ["first_aid", "sterile", "survival"]
  durability          text,                          -- 'disposable', 'reusable', 'rugged'
  compressibility     text,                          -- 'highly_compressible', 'moderate', 'rigid'

  -- ---- Vector embedding (Voyage multimodal-3.5, 1024 dimensions) ----
  embedding           vector(1024),

  -- ---- Timestamps ----
  last_used           timestamp with time zone,
  created_at          timestamp with time zone default now(),
  updated_at          timestamp with time zone default now()
);

-- Fast user-scoped queries
create index if not exists idx_manifest_items_user_id on manifest_items(user_id);

-- Domain filtering
create index if not exists idx_manifest_items_domain on manifest_items(domain);

-- HNSW index for fast cosine similarity search on embeddings
create index if not exists idx_manifest_items_embedding
  on manifest_items
  using hnsw (embedding vector_cosine_ops)
  with (m = 16, ef_construction = 64);
