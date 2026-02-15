-- ============================================================================
-- Manifest Migration 002: Enums
-- ============================================================================
-- Domain-agnostic enums that replace the old fashion-specific item_category.
-- ============================================================================

-- Drop legacy fashion enum if it exists
drop type if exists item_category cascade;
drop type if exists laundry_status cascade;

-- Broad asset domains (extensible via 'misc' catch-all)
create type item_domain as enum (
  'general',
  'clothing',
  'medical',
  'tech',
  'camping',
  'food',
  'misc'
);

-- General item lifecycle status (replaces laundry_status)
create type item_status as enum (
  'available',     -- Ready for use / packing
  'in_use',        -- Currently deployed on a mission
  'needs_repair',  -- Damaged, flagged for maintenance
  'retired'        -- No longer in active inventory
);
