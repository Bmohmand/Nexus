# Manifest — Storage bucket setup

The app uploads item images to Supabase Storage. The **bucket must be created manually** in the Supabase Dashboard (Storage is not created by SQL migrations).

## Steps

1. Open your project in **Supabase Dashboard**: https://supabase.com/dashboard
2. Go to **Storage** in the left sidebar.
3. Click **New bucket**.
4. **Name:** `manifest-assets` (must match exactly).
5. **Public bucket:** turn **ON** so the app and the AI backend can use the image URLs.
6. Click **Create bucket**.

After this, "Analyze & Add to Vault" will be able to upload images and the bucket-not-found error will stop.
