-- ============================================================================
-- Manifest Migration 011: Storage Containers
-- ============================================================================
-- Transport vessels (luggage, backpacks, drone payloads, relief crates)
-- that define weight capacity constraints for multi-container bin-packing.
--
-- Users define their available containers in the app. When issuing a packing
-- query, they select which containers to use. The optimizer distributes items
-- across containers respecting each container's individual weight limit.
-- ============================================================================

create table if not exists storage_containers (
  id                  uuid default uuid_generate_v4() primary key,
  user_id             uuid references auth.users(id) on delete cascade,

  -- Identity
  name                text not null,
  description         text,
  container_type      text default 'bag',   -- bag, case, crate, drone_payload, vehicle, other

  -- Physical constraints
  max_weight_grams    float not null default 20000,
  max_volume_liters   float,
  tare_weight_grams   float default 0,      -- weight of the empty container itself

  -- Inventory
  quantity            int default 1 check (quantity >= 1),

  -- Preferences
  is_default          boolean default false, -- auto-selected for quick pack queries
  icon                text,
  color               text,

  -- Timestamps
  created_at          timestamp with time zone default now(),
  updated_at          timestamp with time zone default now()
);

create index if not exists idx_storage_containers_user_id
  on storage_containers(user_id);

-- Add container assignment to mission_items so we can track
-- which container each item was packed into.
alter table mission_items
  add column if not exists container_id uuid references storage_containers(id) on delete set null;

create index if not exists idx_mission_items_container_id
  on mission_items(container_id);

-- RLS: users can only manage their own containers
alter table storage_containers enable row level security;

drop policy if exists "Users manage own containers" on storage_containers;
create policy "Users manage own containers" on storage_containers for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);
