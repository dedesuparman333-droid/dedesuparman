-- ============================================
-- Supabase Setup for Dede Suparman Link Portal
-- Run this in: Supabase → SQL Editor
-- ============================================

-- 1. Links table
CREATE TABLE IF NOT EXISTS links (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  title text NOT NULL,
  url text NOT NULL,
  category text NOT NULL DEFAULT 'other',
  icon text DEFAULT 'fa-solid fa-link',
  icon_color text DEFAULT '#7c4dff',
  tags text[] DEFAULT '{}',
  notes text DEFAULT '',
  created_at timestamptz DEFAULT now()
);

-- 2. Profiles table
CREATE TABLE IF NOT EXISTS profiles (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  name text DEFAULT 'Dede Suparman',
  bio text DEFAULT 'Digital workspace — all my important links, organized in one place.',
  initials text DEFAULT 'DS',
  updated_at timestamptz DEFAULT now()
);

-- 3. Insert default profile (run once)
INSERT INTO profiles (name, bio, initials)
VALUES ('Dede Suparman', 'Digital workspace — all my important links, organized in one place.', 'DS')
ON CONFLICT DO NOTHING;

-- 4. Insert sample links (optional)
INSERT INTO links (title, url, category, icon, icon_color, tags) VALUES
  ('GitHub Profile', 'https://github.com/dedesuparman', 'dev', 'fa-brands fa-github', '#10b981', ARRAY['code','portfolio']),
  ('LinkedIn', 'https://linkedin.com/in/dedesuparman', 'social', 'fa-brands fa-linkedin', '#3b82f6', ARRAY['professional']),
  ('Figma', 'https://figma.com', 'design', 'fa-brands fa-figma', '#f43f5e', ARRAY['ui','design']),
  ('Notion', 'https://notion.so', 'work', 'fa-solid fa-book', '#6366f1', ARRAY['notes','productivity'])
ON CONFLICT DO NOTHING;

-- 5. Enable Row Level Security (RLS) - allow public read, authenticated write
ALTER TABLE links ENABLE ROW LEVEL SECURITY;
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- Allow anyone to read (public portal)
CREATE POLICY "Public read links" ON links FOR SELECT USING (true);
CREATE POLICY "Public read profiles" ON profiles FOR SELECT USING (true);

-- Allow anon to insert/update/delete (since we use publishable key + admin password)
-- For production, restrict this with Supabase Auth
CREATE POLICY "Anon write links" ON links FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Anon write profiles" ON profiles FOR ALL USING (true) WITH CHECK (true);
