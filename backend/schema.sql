-- =============================================================================
-- MF Elite — Supabase schema + Row Level Security
-- =============================================================================
-- Source of truth for the remote curriculum + player progress.
--
-- Auth model: this project uses **Rork Auth** (Sign in with Apple) — NOT native
-- Supabase Auth. Supabase's auth.users table is therefore empty. Use the
-- installed user_id() function (reads the Rork JWT `sub` claim) in every RLS
-- policy. **Do NOT use auth.uid().**
--
-- Run these statements in the Supabase SQL editor (or via Rork migrations) in
-- order. Every statement uses IF NOT EXISTS so re-running is safe. All changes
-- are additive.
-- =============================================================================


-- -----------------------------------------------------------------------------
-- profiles — canonical user table (referenced by all player-owned tables)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS profiles (
  id          text PRIMARY KEY,            -- Rork user id (usr_xxx)
  email       text,
  name        text,
  avatar_url  text,
  created_at  timestamptz DEFAULT now(),
  updated_at  timestamptz DEFAULT now()
);

ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "profiles_select_all" ON profiles FOR SELECT USING (true);
CREATE POLICY "profiles_insert_own" ON profiles FOR INSERT WITH CHECK (user_id() = id);
CREATE POLICY "profiles_update_own" ON profiles FOR UPDATE USING (user_id() = id) WITH CHECK (user_id() = id);


-- -----------------------------------------------------------------------------
-- coaches — allow-list of users with curriculum write access
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS coaches (
  user_id     text PRIMARY KEY REFERENCES profiles(id),
  created_at  timestamptz DEFAULT now()
);

ALTER TABLE coaches ENABLE ROW LEVEL SECURITY;

-- Any authenticated user can read the coach list (so the app can check its own role).
CREATE POLICY "coaches_select_all" ON coaches FOR SELECT USING (true);
-- Inserts/updates to coaches are done by an admin via the service role only (no client policy).


-- =============================================================================
-- CURRICULUM TABLES (coach-owned, read by all authenticated users)
-- =============================================================================

-- -----------------------------------------------------------------------------
-- disciplines
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS disciplines (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  number      text NOT NULL,               -- "01".."04"
  name        text NOT NULL,
  mark        text NOT NULL,               -- square|triangle|diamond|circle
  tagline     text,
  blurb       text,
  media       text,                        -- drill|video
  sort_index  int  NOT NULL DEFAULT 0,
  created_at  timestamptz DEFAULT now()
);

ALTER TABLE disciplines ENABLE ROW LEVEL SECURITY;

CREATE POLICY "disciplines_select_auth" ON disciplines
  FOR SELECT USING (auth.jwt() ->> 'role' = 'authenticated');
CREATE POLICY "disciplines_coach_write" ON disciplines
  FOR ALL USING (user_id() IN (SELECT user_id FROM coaches))
  WITH CHECK (user_id() IN (SELECT user_id FROM coaches));


-- -----------------------------------------------------------------------------
-- categories
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS categories (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  discipline_id uuid NOT NULL REFERENCES disciplines(id) ON DELETE CASCADE,
  letter        text NOT NULL,             -- "A".."E"
  name          text NOT NULL,
  focus         text,
  cert_name     text,
  sort_index    int NOT NULL DEFAULT 0
);

ALTER TABLE categories ENABLE ROW LEVEL SECURITY;

CREATE POLICY "categories_select_auth" ON categories
  FOR SELECT USING (auth.jwt() ->> 'role' = 'authenticated');
CREATE POLICY "categories_coach_write" ON categories
  FOR ALL USING (user_id() IN (SELECT user_id FROM coaches))
  WITH CHECK (user_id() IN (SELECT user_id FROM coaches));


-- -----------------------------------------------------------------------------
-- levels
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS levels (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  category_id  uuid NOT NULL REFERENCES categories(id) ON DELETE CASCADE,
  number       int NOT NULL,
  name         text NOT NULL,
  theme        text,
  sort_index   int NOT NULL DEFAULT 0
);

ALTER TABLE levels ENABLE ROW LEVEL SECURITY;

CREATE POLICY "levels_select_auth" ON levels
  FOR SELECT USING (auth.jwt() ->> 'role' = 'authenticated');
CREATE POLICY "levels_coach_write" ON levels
  FOR ALL USING (user_id() IN (SELECT user_id FROM coaches))
  WITH CHECK (user_id() IN (SELECT user_id FROM coaches));


-- -----------------------------------------------------------------------------
-- drills
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS drills (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  level_id         uuid NOT NULL REFERENCES levels(id) ON DELETE CASCADE,
  title            text NOT NULL,
  focus            text,
  how              text,
  video_url        text,
  duration_sec     int NOT NULL DEFAULT 0,
  sets             int NOT NULL DEFAULT 1,
  coaching_points  jsonb NOT NULL DEFAULT '[]'::jsonb,   -- string array
  sort_index       int NOT NULL DEFAULT 0
);

ALTER TABLE drills ENABLE ROW LEVEL SECURITY;

CREATE POLICY "drills_select_auth" ON drills
  FOR SELECT USING (auth.jwt() ->> 'role' = 'authenticated');
CREATE POLICY "drills_coach_write" ON drills
  FOR ALL USING (user_id() IN (SELECT user_id FROM coaches))
  WITH CHECK (user_id() IN (SELECT user_id FROM coaches));


-- -----------------------------------------------------------------------------
-- progression_rules (single row, coach-editable)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS progression_rules (
  id                     uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  xp_per_drill           int NOT NULL DEFAULT 25,
  xp_level_bonus         int NOT NULL DEFAULT 120,
  xp_category_cert       int NOT NULL DEFAULT 400,
  xp_discipline_diploma  int NOT NULL DEFAULT 1500,
  free_levels            int NOT NULL DEFAULT 1,
  mastery_passes         int NOT NULL DEFAULT 3
);

ALTER TABLE progression_rules ENABLE ROW LEVEL SECURITY;

CREATE POLICY "rules_select_auth" ON progression_rules
  FOR SELECT USING (auth.jwt() ->> 'role' = 'authenticated');
CREATE POLICY "rules_coach_write" ON progression_rules
  FOR ALL USING (user_id() IN (SELECT user_id FROM coaches))
  WITH CHECK (user_id() IN (SELECT user_id FROM coaches));


-- -----------------------------------------------------------------------------
-- daily_quotes
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS daily_quotes (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  quote       text NOT NULL,
  sort_index  int NOT NULL DEFAULT 0,
  active      bool NOT NULL DEFAULT true
);

ALTER TABLE daily_quotes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "quotes_select_auth" ON daily_quotes
  FOR SELECT USING (auth.jwt() ->> 'role' = 'authenticated');
CREATE POLICY "quotes_coach_write" ON daily_quotes
  FOR ALL USING (user_id() IN (SELECT user_id FROM coaches))
  WITH CHECK (user_id() IN (SELECT user_id FROM coaches));


-- -----------------------------------------------------------------------------
-- announcements
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS announcements (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title       text NOT NULL,
  body        text,
  active      bool NOT NULL DEFAULT true,
  created_at  timestamptz DEFAULT now()
);

ALTER TABLE announcements ENABLE ROW LEVEL SECURITY;

CREATE POLICY "announcements_select_auth" ON announcements
  FOR SELECT USING (auth.jwt() ->> 'role' = 'authenticated');
CREATE POLICY "announcements_coach_write" ON announcements
  FOR ALL USING (user_id() IN (SELECT user_id FROM coaches))
  WITH CHECK (user_id() IN (SELECT user_id FROM coaches));


-- =============================================================================
-- PLAYER TABLES (player-owned)
-- =============================================================================

-- -----------------------------------------------------------------------------
-- player_profiles
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS player_profiles (
  id            text PRIMARY KEY REFERENCES profiles(id),   -- = user_id()
  display_name  text,
  initials      text,
  kit_number    text,
  position      text,
  created_at    timestamptz DEFAULT now()
);

ALTER TABLE player_profiles ENABLE ROW LEVEL SECURITY;

-- Owner + any coach can read; owner can write.
CREATE POLICY "player_profiles_select" ON player_profiles
  FOR SELECT USING (user_id() = id OR user_id() IN (SELECT user_id FROM coaches));
CREATE POLICY "player_profiles_insert_own" ON player_profiles
  FOR INSERT WITH CHECK (user_id() = id);
CREATE POLICY "player_profiles_update_own" ON player_profiles
  FOR UPDATE USING (user_id() = id) WITH CHECK (user_id() = id);


-- -----------------------------------------------------------------------------
-- player_state
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS player_state (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  player_id          text NOT NULL REFERENCES profiles(id),
  xp                 int NOT NULL DEFAULT 0,
  streak             int NOT NULL DEFAULT 0,
  freezes_remaining  int NOT NULL DEFAULT 0,
  last_trained_date  date,
  streak_pb          int NOT NULL DEFAULT 0,
  UNIQUE (player_id)
);

ALTER TABLE player_state ENABLE ROW LEVEL SECURITY;

CREATE POLICY "player_state_select" ON player_state
  FOR SELECT USING (user_id() = player_id OR user_id() IN (SELECT user_id FROM coaches));
CREATE POLICY "player_state_insert_own" ON player_state
  FOR INSERT WITH CHECK (user_id() = player_id);
CREATE POLICY "player_state_update_own" ON player_state
  FOR UPDATE USING (user_id() = player_id) WITH CHECK (user_id() = player_id);
CREATE POLICY "player_state_delete_own" ON player_state
  FOR DELETE USING (user_id() = player_id);


-- -----------------------------------------------------------------------------
-- player_progress (one row per drill per player)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS player_progress (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  player_id      text NOT NULL REFERENCES profiles(id),
  drill_id       uuid NOT NULL REFERENCES drills(id) ON DELETE CASCADE,
  passes_logged  int NOT NULL DEFAULT 0,
  is_mastered    bool NOT NULL DEFAULT false,
  last_logged_at timestamptz,
  UNIQUE (player_id, drill_id)
);

ALTER TABLE player_progress ENABLE ROW LEVEL SECURITY;

CREATE POLICY "player_progress_select" ON player_progress
  FOR SELECT USING (user_id() = player_id OR user_id() IN (SELECT user_id FROM coaches));
CREATE POLICY "player_progress_insert_own" ON player_progress
  FOR INSERT WITH CHECK (user_id() = player_id);
CREATE POLICY "player_progress_update_own" ON player_progress
  FOR UPDATE USING (user_id() = player_id) WITH CHECK (user_id() = player_id);
CREATE POLICY "player_progress_delete_own" ON player_progress
  FOR DELETE USING (user_id() = player_id);


-- -----------------------------------------------------------------------------
-- certifications (earned certs)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS certifications (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  player_id    text NOT NULL REFERENCES profiles(id),
  category_id  uuid NOT NULL REFERENCES categories(id) ON DELETE CASCADE,
  earned_at    timestamptz DEFAULT now(),
  coach_signed bool NOT NULL DEFAULT false,
  UNIQUE (player_id, category_id)
);

ALTER TABLE certifications ENABLE ROW LEVEL SECURITY;

CREATE POLICY "certifications_select" ON certifications
  FOR SELECT USING (user_id() = player_id OR user_id() IN (SELECT user_id FROM coaches));
CREATE POLICY "certifications_insert_own" ON certifications
  FOR INSERT WITH CHECK (user_id() = player_id);
CREATE POLICY "certifications_delete_own" ON certifications
  FOR DELETE USING (user_id() = player_id);
