# Manifest — Storage bucket setup

The app uploads item images to Supabase Storage. You need to (1) create the bucket and (2) add Storage RLS policies so uploads are allowed. Otherwise you get **"new row violates row-level security policy"** (403).

## 1. Create the bucket

1. Open your project in **Supabase Dashboard**: https://supabase.com/dashboard
2. Go to **Storage** in the left sidebar.
3. Click **New bucket**.
4. **Name:** `manifest-assets` (must match exactly).
5. **Public bucket:** turn **ON** so the app and the AI backend can use the image URLs.
6. Click **Create bucket**.

## 2. Allow uploads (Storage RLS)

Supabase applies RLS to `storage.objects`. By default, no one can insert, so uploads return 403 until you add policies.

**Option A — SQL (recommended)**  
In **SQL Editor** → New query, paste and run the contents of **`009_storage_policies.sql`**. That adds policies so `manifest-assets` allows public insert/select/update/delete.

**Option B — Dashboard**  
Storage → **manifest-assets** → **Policies** → New policy. Add an **Insert** policy for "All users" (or "Authenticated users" if you only want logged-in uploads) with condition `bucket_id = 'manifest-assets'`. Add a **Select** policy the same way so reads work.

After both steps, "Analyze & Add to Vault" should work without the RLS error.
