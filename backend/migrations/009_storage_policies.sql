-- ============================================================================
-- Manifest: Storage bucket RLS policies
-- ============================================================================
-- The "new row violates row-level security policy" error happens on Storage
-- uploads, not the database. Supabase applies RLS to storage.objects;
-- without these policies, uploads to manifest-assets return 403.
--
-- Run this in Supabase SQL Editor after creating the manifest-assets bucket.
-- ============================================================================

-- Allow anyone (anon or authenticated) to upload to manifest-assets
drop policy if exists "Allow uploads to manifest-assets" on storage.objects;
create policy "Allow uploads to manifest-assets"
on storage.objects for insert
to public
with check (bucket_id = 'manifest-assets');

-- Allow anyone to read (so public image URLs work)
drop policy if exists "Allow public read manifest-assets" on storage.objects;
create policy "Allow public read manifest-assets"
on storage.objects for select
to public
using (bucket_id = 'manifest-assets');

-- Allow anyone to update/delete their uploads (optional; for "Choose Different Image" / replace)
drop policy if exists "Allow updates to manifest-assets" on storage.objects;
create policy "Allow updates to manifest-assets"
on storage.objects for update
to public
using (bucket_id = 'manifest-assets');

drop policy if exists "Allow deletes from manifest-assets" on storage.objects;
create policy "Allow deletes from manifest-assets"
on storage.objects for delete
to public
using (bucket_id = 'manifest-assets');
