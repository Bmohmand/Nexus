-- ============================================================================
-- Manifest Migration 007: Row-Level Security Policies
-- ============================================================================
-- Every table must have RLS enabled for Supabase frontend access.
-- Policy: users can only read/write their own data.
-- ============================================================================

-- ---- Enable RLS on all tables ----
alter table profiles       enable row level security;
alter table manifest_items enable row level security;
alter table missions       enable row level security;
alter table mission_items  enable row level security;

-- ---- Profiles ----
create policy "Users manage own profiles"
  on profiles for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- ---- Manifest Items ----
create policy "Users manage own items"
  on manifest_items for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- ---- Missions ----
create policy "Users manage own missions"
  on missions for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- ---- Mission Items (access via mission ownership) ----
create policy "Users can read own mission items"
  on mission_items for select
  using (
    exists (
      select 1 from missions
      where missions.id = mission_items.mission_id
        and missions.user_id = auth.uid()
    )
  );

create policy "Users can insert own mission items"
  on mission_items for insert
  with check (
    exists (
      select 1 from missions
      where missions.id = mission_items.mission_id
        and missions.user_id = auth.uid()
    )
  );

create policy "Users can update own mission items"
  on mission_items for update
  using (
    exists (
      select 1 from missions
      where missions.id = mission_items.mission_id
        and missions.user_id = auth.uid()
    )
  );

create policy "Users can delete own mission items"
  on mission_items for delete
  using (
    exists (
      select 1 from missions
      where missions.id = mission_items.mission_id
        and missions.user_id = auth.uid()
    )
  );
