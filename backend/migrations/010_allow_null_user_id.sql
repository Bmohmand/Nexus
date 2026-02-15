-- ============================================================================
-- Manifest: Allow nullable user_id for development / unauthenticated ingest
-- ============================================================================
-- The backend ingest flow may not have a user context. Making user_id nullable
-- lets ingest work without requiring the client to send user_id.
-- For production, have the client send user_id and enforce NOT NULL again.
-- ============================================================================

alter table manifest_items alter column user_id drop not null;
