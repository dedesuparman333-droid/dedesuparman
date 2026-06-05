-- ═══════════════════════════════════════════════════════════════
--  SUPABASE DATABASE SCHEMA
--  Dede Suparman — Google Apps Script Developer Portal
--  Run this in Supabase SQL Editor → New Query
-- ═══════════════════════════════════════════════════════════════

-- ─────────────────────────────────────────────
-- 1. ENABLE EXTENSIONS
-- ─────────────────────────────────────────────
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ─────────────────────────────────────────────
-- 2. TABLE: admin_users
--    Stores admin credentials (hashed password)
-- ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.admin_users (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  username    TEXT UNIQUE NOT NULL,
  email       TEXT UNIQUE NOT NULL,
  password_hash TEXT NOT NULL,          -- bcrypt hash, NEVER store plain text
  role        TEXT NOT NULL DEFAULT 'admin' CHECK (role IN ('superadmin','admin')),
  is_active   BOOLEAN NOT NULL DEFAULT TRUE,
  last_login  TIMESTAMPTZ,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ─────────────────────────────────────────────
-- 3. TABLE: admin_sessions
--    Tracks active sessions (token-based)
-- ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.admin_sessions (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  admin_id    UUID NOT NULL REFERENCES public.admin_users(id) ON DELETE CASCADE,
  token       TEXT UNIQUE NOT NULL DEFAULT encode(gen_random_bytes(32), 'hex'),
  ip_address  TEXT,
  user_agent  TEXT,
  expires_at  TIMESTAMPTZ NOT NULL DEFAULT (NOW() + INTERVAL '24 hours'),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ─────────────────────────────────────────────
-- 4. TABLE: link_categories
--    Categories for Link Hub
-- ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.link_categories (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  slug        TEXT UNIQUE NOT NULL,       -- e.g. 'social', 'project', 'contact'
  label       TEXT NOT NULL,              -- e.g. 'Social Media'
  icon        TEXT NOT NULL DEFAULT 'fa-solid fa-tag',
  color       TEXT NOT NULL DEFAULT '#BFFF00',
  sort_order  INT NOT NULL DEFAULT 0,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ─────────────────────────────────────────────
-- 5. TABLE: links
--    Main link hub entries
-- ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.links (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  title       TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  url         TEXT NOT NULL,
  icon        TEXT NOT NULL DEFAULT 'fa-solid fa-link',   -- Font Awesome class
  category_id UUID REFERENCES public.link_categories(id) ON DELETE SET NULL,
  is_active   BOOLEAN NOT NULL DEFAULT TRUE,
  is_pinned   BOOLEAN NOT NULL DEFAULT FALSE,
  sort_order  INT NOT NULL DEFAULT 0,
  click_count BIGINT NOT NULL DEFAULT 0,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ─────────────────────────────────────────────
-- 6. TABLE: projects
--    Portfolio projects (for reference from links)
-- ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.projects (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name        TEXT NOT NULL,
  slug        TEXT UNIQUE NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  category    TEXT NOT NULL DEFAULT 'Tool' CHECK (category IN ('Web App','Automation','Dashboard','API','Tool')),
  technology  TEXT[] NOT NULL DEFAULT '{}',  -- array: ['Google Apps Script','Sheets']
  demo_url    TEXT,
  repo_url    TEXT,
  image_url   TEXT,
  status      TEXT NOT NULL DEFAULT 'Live' CHECK (status IN ('Live','Beta','Development','Archived')),
  featured    BOOLEAN NOT NULL DEFAULT FALSE,
  views       BIGINT NOT NULL DEFAULT 0,
  sort_order  INT NOT NULL DEFAULT 0,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ─────────────────────────────────────────────
-- 7. TABLE: audit_log
--    Log all admin actions
-- ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.audit_log (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  admin_id    UUID REFERENCES public.admin_users(id) ON DELETE SET NULL,
  action      TEXT NOT NULL,          -- 'create_link', 'delete_link', 'login', etc.
  table_name  TEXT,
  record_id   UUID,
  old_data    JSONB,
  new_data    JSONB,
  ip_address  TEXT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ─────────────────────────────────────────────
-- 8. INDEXES (for performance)
-- ─────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_links_category     ON public.links(category_id);
CREATE INDEX IF NOT EXISTS idx_links_active       ON public.links(is_active);
CREATE INDEX IF NOT EXISTS idx_links_sort         ON public.links(sort_order);
CREATE INDEX IF NOT EXISTS idx_sessions_token     ON public.admin_sessions(token);
CREATE INDEX IF NOT EXISTS idx_sessions_admin     ON public.admin_sessions(admin_id);
CREATE INDEX IF NOT EXISTS idx_sessions_expires   ON public.admin_sessions(expires_at);
CREATE INDEX IF NOT EXISTS idx_projects_featured  ON public.projects(featured);
CREATE INDEX IF NOT EXISTS idx_projects_status    ON public.projects(status);
CREATE INDEX IF NOT EXISTS idx_audit_admin        ON public.audit_log(admin_id);
CREATE INDEX IF NOT EXISTS idx_audit_action       ON public.audit_log(action);

-- ─────────────────────────────────────────────
-- 9. UPDATED_AT TRIGGER (auto-update timestamps)
-- ─────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_links_updated_at
  BEFORE UPDATE ON public.links
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER trg_projects_updated_at
  BEFORE UPDATE ON public.projects
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER trg_admin_users_updated_at
  BEFORE UPDATE ON public.admin_users
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- ─────────────────────────────────────────────
-- 10. FUNCTION: increment click count
-- ─────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.increment_link_click(link_uuid UUID)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  UPDATE public.links SET click_count = click_count + 1 WHERE id = link_uuid;
END;
$$;

-- ─────────────────────────────────────────────
-- 11. ROW LEVEL SECURITY (RLS)
-- ─────────────────────────────────────────────
ALTER TABLE public.links          ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.link_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.projects        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_users     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_sessions  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_log       ENABLE ROW LEVEL SECURITY;

-- Public can read active links (for the portfolio website)
CREATE POLICY "public_read_active_links"
  ON public.links FOR SELECT
  USING (is_active = TRUE);

-- Public can read link categories
CREATE POLICY "public_read_categories"
  ON public.link_categories FOR SELECT
  USING (TRUE);

-- Public can read projects
CREATE POLICY "public_read_projects"
  ON public.projects FOR SELECT
  USING (TRUE);

-- Service role (admin portal) can do everything
-- (Use service_role key only in server/admin, never in public frontend)
CREATE POLICY "service_full_links"
  ON public.links FOR ALL
  TO service_role USING (TRUE);

CREATE POLICY "service_full_categories"
  ON public.link_categories FOR ALL
  TO service_role USING (TRUE);

CREATE POLICY "service_full_projects"
  ON public.projects FOR ALL
  TO service_role USING (TRUE);

CREATE POLICY "service_full_admin_users"
  ON public.admin_users FOR ALL
  TO service_role USING (TRUE);

CREATE POLICY "service_full_sessions"
  ON public.admin_sessions FOR ALL
  TO service_role USING (TRUE);

CREATE POLICY "service_full_audit"
  ON public.audit_log FOR ALL
  TO service_role USING (TRUE);

-- ─────────────────────────────────────────────
-- 12. SEED DATA — Link Categories
-- ─────────────────────────────────────────────
INSERT INTO public.link_categories (slug, label, icon, color, sort_order) VALUES
  ('personal',  'Personal',     'fa-solid fa-user',          '#BFFF00', 1),
  ('social',    'Social Media', 'fa-solid fa-share-nodes',   '#4f9eff', 2),
  ('contact',   'Contact',      'fa-solid fa-address-book',  '#00d68f', 3),
  ('project',   'Projects',     'fa-solid fa-folder-open',   '#b87aff', 4),
  ('content',   'Content',      'fa-solid fa-pen-nib',       '#ff8c42', 5)
ON CONFLICT (slug) DO NOTHING;

-- ─────────────────────────────────────────────
-- 13. SEED DATA — Sample Links
-- ─────────────────────────────────────────────
INSERT INTO public.links (title, description, url, icon, category_id, is_active, is_pinned, sort_order) VALUES
  ('Portfolio',     'Lihat portfolio lengkap & studi kasus proyek GAS saya',     'https://your-site.com',        'fa-solid fa-briefcase',    (SELECT id FROM public.link_categories WHERE slug='personal'), TRUE, TRUE,  1),
  ('GitHub',        'Repositori kode open-source dan script Google Apps Script',  'https://github.com',           'fa-brands fa-github',      (SELECT id FROM public.link_categories WHERE slug='social'),   TRUE, FALSE, 2),
  ('LinkedIn',      'Terhubung secara profesional dan lihat riwayat kerja',       'https://linkedin.com',         'fa-brands fa-linkedin',    (SELECT id FROM public.link_categories WHERE slug='social'),   TRUE, FALSE, 3),
  ('WhatsApp',      'Chat cepat untuk diskusi proyek & pertanyaan',               'https://wa.me/62xxxxxxxxxx',   'fa-brands fa-whatsapp',    (SELECT id FROM public.link_categories WHERE slug='contact'),  TRUE, TRUE,  4),
  ('Email',         'Kirim pesan detail atau brief proyek',                       'mailto:dede@example.com',      'fa-solid fa-envelope',     (SELECT id FROM public.link_categories WHERE slug='contact'),  TRUE, FALSE, 5),
  ('Resume / CV',   'Download CV dan profil profesional terbaru',                 '#',                            'fa-solid fa-file-pdf',     (SELECT id FROM public.link_categories WHERE slug='personal'), TRUE, FALSE, 6),
  ('Blog / Artikel','Artikel teknis, tutorial, dan insight Google Apps Script',   '#',                            'fa-solid fa-pen-nib',      (SELECT id FROM public.link_categories WHERE slug='content'),  TRUE, FALSE, 7),
  ('Dokumentasi',   'Dokumentasi teknis untuk tools dan add-on yang saya buat',   '#',                            'fa-solid fa-book',         (SELECT id FROM public.link_categories WHERE slug='content'),  TRUE, FALSE, 8)
ON CONFLICT DO NOTHING;

-- ─────────────────────────────────────────────
-- 14. SEED DATA — Default Admin User
--    Password: Admin@123 (CHANGE THIS IMMEDIATELY after first login!)
--    bcrypt hash generated for: Admin@123
-- ─────────────────────────────────────────────
INSERT INTO public.admin_users (username, email, password_hash, role) VALUES
  ('admin', 'admin@dedesuparman.com', '$2a$12$LQv3c1yqBWVHxkd0LHAkCOYz6TiGniubZIlDP5gAkUsLyEGiQ3a8i', 'superadmin')
ON CONFLICT (username) DO NOTHING;

-- ─────────────────────────────────────────────
-- 15. VIEW: active_links_with_category
--    Convenient view for the public website
-- ─────────────────────────────────────────────
CREATE OR REPLACE VIEW public.active_links_with_category AS
SELECT
  l.id,
  l.title,
  l.description,
  l.url,
  l.icon,
  l.is_pinned,
  l.sort_order,
  l.click_count,
  c.slug  AS category_slug,
  c.label AS category_label,
  c.icon  AS category_icon
FROM public.links l
LEFT JOIN public.link_categories c ON l.category_id = c.id
WHERE l.is_active = TRUE
ORDER BY l.is_pinned DESC, l.sort_order ASC, l.created_at ASC;

-- ─────────────────────────────────────────────
-- DONE ✓
-- Next steps:
-- 1. Copy your Supabase URL and anon key to admin.html
-- 2. Copy your service_role key to admin.html (server-side only!)
-- 3. Login with username: admin / password: Admin@123
-- 4. IMMEDIATELY change the password in Admin Portal → Settings
-- ─────────────────────────────────────────────
