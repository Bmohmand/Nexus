-- ============================================================================
-- Manifest: Run All Migrations (single script for Supabase SQL Editor)
-- ============================================================================
-- Copy this entire file into Supabase Dashboard → SQL Editor → New Query → Run
-- This creates the manifest_items table and all related schema.
--
-- After running this, also create the Storage bucket for item images:
--   Dashboard → Storage → New bucket → Name: manifest-assets → Public: ON
-- See README_STORAGE.md for details.
-- ============================================================================

-- 1. Extensions
create extension if not exists "uuid-ossp";
create extension if not exists vector;

-- 2. Enums (drop legacy first)
drop type if exists item_category cascade;
drop type if exists laundry_status cascade;
create type item_domain as enum (
  'general', 'clothing', 'medical', 'tech', 'camping', 'food', 'misc'
);
create type item_status as enum (
  'available', 'in_use', 'needs_repair', 'retired'
);

-- 3. Profiles
create table if not exists profiles (
  id          uuid default uuid_generate_v4() primary key,
  user_id     uuid references auth.users(id) on delete cascade not null,
  name        text not null,
  is_child    boolean default false,
  preferences jsonb default '{}'::jsonb,
  created_at  timestamp with time zone default now(),
  updated_at  timestamp with time zone default now()
);
create index if not exists idx_profiles_user_id on profiles(user_id);

-- 4. manifest_items (THE TABLE THAT WAS MISSING)
create table if not exists manifest_items (
  id                  uuid default uuid_generate_v4() primary key,
  user_id             uuid references auth.users(id) on delete cascade not null,
  profile_id          uuid references profiles(id) on delete set null,
  name                text not null,
  image_url           text,
  domain              item_domain not null default 'general',
  category            text,
  status              item_status default 'available',
  quantity            int default 1 check (quantity >= 0),
  environmental_rating int check (environmental_rating between 0 and 10),
  volume_score        float default 1.0,
  weight_grams        float,
  primary_material    text,
  weight_estimate     text,
  thermal_rating      text,
  water_resistance    text,
  medical_application text,
  utility_summary     text,
  semantic_tags       jsonb default '[]'::jsonb,
  durability          text,
  compressibility     text,
  embedding           vector(1024),
  last_used           timestamp with time zone,
  created_at          timestamp with time zone default now(),
  updated_at          timestamp with time zone default now()
);
create index if not exists idx_manifest_items_user_id on manifest_items(user_id);
create index if not exists idx_manifest_items_domain on manifest_items(domain);
create index if not exists idx_manifest_items_embedding
  on manifest_items using hnsw (embedding vector_cosine_ops)
  with (m = 16, ef_construction = 64);

-- 5. Missions
create table if not exists missions (
  id                    uuid default uuid_generate_v4() primary key,
  user_id               uuid references auth.users(id) on delete cascade not null,
  title                 text not null,
  mission_type          text,
  description           text,
  start_date            date,
  end_date              date,
  destination           text,
  min_temperature       int,
  max_temperature       int,
  max_weight_grams      float default 20000,
  max_volume            float default 100.0,
  is_resupply_available  boolean default false,
  constraint_preset     text,
  plan_summary          text,
  plan_warnings         jsonb default '[]'::jsonb,
  created_at            timestamp with time zone default now(),
  updated_at            timestamp with time zone default now()
);
create index if not exists idx_missions_user_id on missions(user_id);

-- 6. Mission items
create table if not exists mission_items (
  id                  uuid default uuid_generate_v4() primary key,
  mission_id          uuid references missions(id) on delete cascade not null,
  item_id             uuid references manifest_items(id) on delete cascade not null,
  status              text check (status in ('suggested', 'packed', 'rejected')) not null default 'suggested',
  quantity_packed     int default 1 check (quantity_packed >= 0),
  similarity_score    float,
  score_contribution  float,
  rejection_reason    text,
  unique(mission_id, item_id)
);
create index if not exists idx_mission_items_mission_id on mission_items(mission_id);
create index if not exists idx_mission_items_item_id on mission_items(item_id);

-- 7. RLS
alter table profiles       enable row level security;
alter table manifest_items enable row level security;
alter table missions       enable row level security;
alter table mission_items  enable row level security;

drop policy if exists "Users manage own profiles" on profiles;
create policy "Users manage own profiles" on profiles for all
  using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "Users manage own items" on manifest_items;
create policy "Users manage own items" on manifest_items for all
  using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "Users manage own missions" on missions;
create policy "Users manage own missions" on missions for all
  using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "Users can read own mission items" on mission_items;
create policy "Users can read own mission items" on mission_items for select
  using (exists (select 1 from missions where missions.id = mission_items.mission_id and missions.user_id = auth.uid()));

drop policy if exists "Users can insert own mission items" on mission_items;
create policy "Users can insert own mission items" on mission_items for insert
  with check (exists (select 1 from missions where missions.id = mission_items.mission_id and missions.user_id = auth.uid()));

drop policy if exists "Users can update own mission items" on mission_items;
create policy "Users can update own mission items" on mission_items for update
  using (exists (select 1 from missions where missions.id = mission_items.mission_id and missions.user_id = auth.uid()));

drop policy if exists "Users can delete own mission items" on mission_items;
create policy "Users can delete own mission items" on mission_items for delete
  using (exists (select 1 from missions where missions.id = mission_items.mission_id and missions.user_id = auth.uid()));

-- 8. Vector search RPC
drop function if exists search_assets(vector, float, int);
drop function if exists match_nexus_items(vector, int, text);
create or replace function match_manifest_items(
  query_embedding   vector(1024),
  match_count       int default 15,
  filter_domain     text default null,
  filter_category   text default null,
  filter_user_id    uuid default null
)
returns table (
  id uuid, similarity float, image_url text, name text, domain text, category text,
  primary_material text, weight_estimate text, thermal_rating text, water_resistance text,
  medical_application text, utility_summary text, semantic_tags jsonb,
  durability text, compressibility text, quantity int, weight_grams float
)
language plpgsql as $$
begin
  return query
  select
    mi.id, 1 - (mi.embedding <=> query_embedding) as similarity,
    mi.image_url, mi.name, mi.domain::text, mi.category,
    mi.primary_material, mi.weight_estimate, mi.thermal_rating, mi.water_resistance,
    mi.medical_application, mi.utility_summary, mi.semantic_tags,
    mi.durability, mi.compressibility, mi.quantity, mi.weight_grams
  from manifest_items mi
  where mi.embedding is not null
    and (filter_domain is null or mi.domain::text = filter_domain)
    and (filter_category is null or mi.category = filter_category)
    and (filter_user_id is null or mi.user_id = filter_user_id)
  order by mi.embedding <=> query_embedding
  limit match_count;
end;
$$;

-- ============================================================================
-- 9. Storage bucket policies (fixes "new row violates row-level security policy")
-- ============================================================================
-- Run after creating the manifest-assets bucket in Dashboard → Storage.
drop policy if exists "Allow uploads to manifest-assets" on storage.objects;
create policy "Allow uploads to manifest-assets" on storage.objects for insert to public with check (bucket_id = 'manifest-assets');

drop policy if exists "Allow public read manifest-assets" on storage.objects;
create policy "Allow public read manifest-assets" on storage.objects for select to public using (bucket_id = 'manifest-assets');

drop policy if exists "Allow updates to manifest-assets" on storage.objects;
create policy "Allow updates to manifest-assets" on storage.objects for update to public using (bucket_id = 'manifest-assets');

drop policy if exists "Allow deletes from manifest-assets" on storage.objects;
create policy "Allow deletes from manifest-assets" on storage.objects for delete to public using (bucket_id = 'manifest-assets');

-- ============================================================================
-- 10. Allow nullable user_id (so ingest works without sending user_id)
-- ============================================================================
alter table manifest_items alter column user_id drop not null;

-- ============================================================================
-- 11. Storage Containers (transport vessels for multi-container bin-packing)
-- ============================================================================
create table if not exists storage_containers (
  id                  uuid default uuid_generate_v4() primary key,
  user_id             uuid references auth.users(id) on delete cascade,
  name                text not null,
  description         text,
  container_type      text default 'bag',
  max_weight_grams    float not null default 20000,
  max_volume_liters   float,
  tare_weight_grams   float default 0,
  quantity            int default 1 check (quantity >= 1),
  is_default          boolean default false,
  icon                text,
  color               text,
  created_at          timestamp with time zone default now(),
  updated_at          timestamp with time zone default now()
);
create index if not exists idx_storage_containers_user_id on storage_containers(user_id);

alter table mission_items
  add column if not exists container_id uuid references storage_containers(id) on delete set null;
create index if not exists idx_mission_items_container_id on mission_items(container_id);

alter table storage_containers enable row level security;
drop policy if exists "Users manage own containers" on storage_containers;
create policy "Users manage own containers" on storage_containers for all
  using (auth.uid() = user_id) with check (auth.uid() = user_id);
