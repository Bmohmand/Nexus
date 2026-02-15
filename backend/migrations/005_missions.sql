-- ============================================================================
-- Manifest Migration 005: Missions (Generalized Trips)
-- ============================================================================
-- Replaces the "trips" table. A "mission" is any scenario that requires
-- an optimized packing plan: a camping trip, medical relief deployment,
-- travel, bug-out preparation, etc.
-- ============================================================================

create table if not exists missions (
  id                    uuid default uuid_generate_v4() primary key,
  user_id               uuid references auth.users(id) on delete cascade not null,

  -- ---- Mission definition ----
  title                 text not null,                   -- "Weekend camping at Yosemite"
  mission_type          text,                            -- Free-text: "travel", "relief", "bug_out", "day_trip"
  description           text,                            -- Natural language mission briefing

  -- ---- Temporal constraints ----
  start_date            date,
  end_date              date,

  -- ---- Environmental constraints ----
  destination           text,
  min_temperature       int,                             -- Fahrenheit
  max_temperature       int,

  -- ---- Packing constraints (for the knapsack optimizer) ----
  max_weight_grams      float default 20000,             -- Default 20kg
  max_volume            float default 100.0,             -- Abstract volume units
  is_resupply_available boolean default false,            -- Can restock consumables?
  constraint_preset     text,                            -- Optional: "carry_on", "drone_delivery", etc.

  -- ---- Results (cached after optimization) ----
  plan_summary          text,                            -- LLM-generated mission summary
  plan_warnings         jsonb default '[]'::jsonb,       -- Safety warnings from synthesizer

  -- ---- Timestamps ----
  created_at            timestamp with time zone default now(),
  updated_at            timestamp with time zone default now()
);

create index if not exists idx_missions_user_id on missions(user_id);
