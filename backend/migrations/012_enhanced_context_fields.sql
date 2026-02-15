-- ============================================================================
-- Manifest Migration 012: Enhanced Context Fields for Better Embeddings
-- ============================================================================
-- Adds fields that were extracted by the VLM but previously lost:
--   - environmental_suitability: climate/conditions the item is designed for
--   - limitations_and_failure_modes: critical failure info for safety filtering
--
-- Adds new activity-context fields for embedding discrimination:
--   - activity_contexts: what activities/scenarios the item suits
--   - unsuitable_contexts: what activities the item does NOT suit
--
-- These fields are embedded into the vector via _build_context_text() and
-- dramatically improve search relevance by encoding both positive AND
-- negative suitability signals.
-- ============================================================================

-- Previously-extracted-but-lost VLM fields
alter table manifest_items
  add column if not exists environmental_suitability text,
  add column if not exists limitations_and_failure_modes text;

-- New activity context fields (JSONB arrays, same pattern as semantic_tags)
alter table manifest_items
  add column if not exists activity_contexts jsonb default '[]'::jsonb,
  add column if not exists unsuitable_contexts jsonb default '[]'::jsonb;

-- Add a comment explaining these columns
comment on column manifest_items.environmental_suitability is 'Climate/conditions the item is designed for (e.g. Sub-zero temperatures, Arid desert)';
comment on column manifest_items.limitations_and_failure_modes is 'Critical failure modes (e.g. Useless when wet, Requires batteries)';
comment on column manifest_items.activity_contexts is 'JSON array of activities this item suits: ["hiking", "clinical_medicine"]';
comment on column manifest_items.unsuitable_contexts is 'JSON array of activities this item does NOT suit: ["outdoor_recreation"]';
