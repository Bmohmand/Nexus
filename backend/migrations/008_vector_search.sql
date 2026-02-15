-- ============================================================================
-- Manifest Migration 008: Vector Similarity Search Function
-- ============================================================================
-- RPC function called by the Python backend via Supabase client.
-- Performs cosine similarity search on the manifest_items embedding column.
-- Dimension: 1024 (Voyage multimodal-3.5)
-- ============================================================================

-- Drop legacy functions if they exist
drop function if exists search_assets;
drop function if exists match_nexus_items;

-- Create the unified search function
create or replace function match_manifest_items(
  query_embedding   vector(1024),
  match_count       int default 15,
  filter_domain     text default null,
  filter_category   text default null,
  filter_user_id    uuid default null
)
returns table (
  id                  uuid,
  similarity          float,
  image_url           text,
  name                text,
  domain              text,
  category            text,
  primary_material    text,
  weight_estimate     text,
  thermal_rating      text,
  water_resistance    text,
  medical_application text,
  utility_summary     text,
  semantic_tags       jsonb,
  durability          text,
  compressibility     text,
  quantity            int,
  weight_grams        float
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
    mi.weight_grams
  from manifest_items mi
  where mi.embedding is not null
    and (filter_domain is null or mi.domain::text = filter_domain)
    and (filter_category is null or mi.category = filter_category)
    and (filter_user_id is null or mi.user_id = filter_user_id)
  order by mi.embedding <=> query_embedding
  limit match_count;
end;
$$;
