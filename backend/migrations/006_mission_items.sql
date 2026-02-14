-- ============================================================================
-- Manifest Migration 006: Mission Items (Packing Solutions)
-- ============================================================================
-- Stores the output of the knapsack optimizer: which items were selected,
-- rejected, or suggested for a given mission.
-- ============================================================================

create table if not exists mission_items (
  id                  uuid default uuid_generate_v4() primary key,
  mission_id          uuid references missions(id) on delete cascade not null,
  item_id             uuid references manifest_items(id) on delete cascade not null,

  -- ---- Packing decision ----
  status              text check (status in ('suggested', 'packed', 'rejected')) not null default 'suggested',
  quantity_packed     int default 1 check (quantity_packed >= 0),

  -- ---- Optimizer metadata ----
  similarity_score    float,                           -- Cosine similarity from vector search
  score_contribution  float,                           -- How much this item helped the objective
  rejection_reason    text,                            -- Why the optimizer / LLM excluded it

  -- ---- Constraint ----
  unique(mission_id, item_id)                          -- No duplicate items per mission
);

create index if not exists idx_mission_items_mission_id on mission_items(mission_id);
create index if not exists idx_mission_items_item_id on mission_items(item_id);
