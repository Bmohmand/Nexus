-- ============================================================================
-- Manifest Migration 003: Profiles
-- ============================================================================
-- Multi-user / family mode. One auth.users account can manage multiple
-- profiles (e.g. personal gear, kids' gear, team members).
-- Preserved from the original FitCheck schema with minor additions.
-- ============================================================================

create table if not exists profiles (
  id          uuid default uuid_generate_v4() primary key,
  user_id     uuid references auth.users(id) on delete cascade not null,
  name        text not null,
  is_child    boolean default false,

  -- Flexible preferences blob (size prefs, default constraints, etc.)
  preferences jsonb default '{}'::jsonb,

  created_at  timestamp with time zone default now(),
  updated_at  timestamp with time zone default now()
);

-- Index for fast lookup by owning user
create index if not exists idx_profiles_user_id on profiles(user_id);
