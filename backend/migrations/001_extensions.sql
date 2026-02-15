-- ============================================================================
-- Manifest Migration 001: Extensions
-- ============================================================================
-- Enable required PostgreSQL extensions for Manifest.
-- Run this FIRST in the Supabase SQL Editor.
-- ============================================================================

-- UUID generation for primary keys
create extension if not exists "uuid-ossp";

-- pgvector for AI embedding similarity search
create extension if not exists vector;
