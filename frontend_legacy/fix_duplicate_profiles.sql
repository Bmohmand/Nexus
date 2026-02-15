-- This SQL script fixes duplicate profiles and adds a unique constraint
-- Run this in your Supabase SQL Editor

-- Step 1: Remove duplicate profiles (keep the oldest one for each user)
DELETE FROM profiles
WHERE id NOT IN (
  SELECT MIN(id)
  FROM profiles
  GROUP BY user_id
);

-- Step 2: Add unique constraint on user_id to prevent future duplicates
ALTER TABLE profiles
ADD CONSTRAINT profiles_user_id_unique UNIQUE (user_id);

-- Step 3: Verify no duplicates remain
SELECT user_id, COUNT(*) as count
FROM profiles
GROUP BY user_id
HAVING COUNT(*) > 1;

-- If the above query returns no rows, you're good!
