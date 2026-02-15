-- ============================================================================
-- Manifest Migration 013: Enhanced Vector Search Function
-- ============================================================================
-- Updates match_manifest_items to return the new context fields:
--   - environmental_suitability
--   - limitations_and_failure_modes
--   - activity_contexts
--   - unsuitable_contexts
--
-- Also adds a minimum similarity threshold parameter to filter irrelevant
-- results at the database level (defense in depth with the Python-side filter).
-- ============================================================================

-- Drop and recreate with enhanced return type
create or replace function match_manifest_items(
  query_embedding       vector(1024),
  match_count           int default 15,
  filter_domain         text default null,
  filter_category       text default null,
  filter_user_id        uuid default null,
  min_similarity        float default 0.0
)
returns table (
  id                          uuid,
  similarity                  float,
  image_url                   text,
  name                        text,
  domain                      text,
  category                    text,
  primary_material            text,
  weight_estimate             text,
  thermal_rating              text,
  water_resistance            text,
  medical_application         text,
  utility_summary             text,
  semantic_tags               jsonb,
  durability                  text,
  compressibility             text,
  quantity                    int,
  weight_grams                float,
  environmental_suitability   text,
  limitations_and_failure_modes text,
  activity_contexts           jsonb,
  unsuitable_contexts         jsonb
)
language plpgsql
as $$
begin
  return query
  select
    mi.id,
    1 - (mi.embedding <=> query_embedding) as similarity,
    mi.image_url,
    mi.name,
    mi.domain::text,
    mi.category,
    mi.primary_material,
    mi.weight_estimate,
    mi.thermal_rating,
    mi.water_resistance,
    mi.medical_application,
    mi.utility_summary,
    mi.semantic_tags,
    mi.durability,
    mi.compressibility,
    mi.quantity,
    mi.weight_grams,
    mi.environmental_suitability,
    mi.limitations_and_failure_modes,
    mi.activity_contexts,
    mi.unsuitable_contexts
  from manifest_items mi
  where mi.embedding is not null
    and (filter_domain is null or mi.domain::text = filter_domain)
    and (filter_category is null or mi.category = filter_category)
    and (filter_user_id is null or mi.user_id = filter_user_id)
    and (1 - (mi.embedding <=> query_embedding)) >= min_similarity
  order by mi.embedding <=> query_embedding
  limit match_count;
end;
$$;
