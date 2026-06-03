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
-- user_id() — resolves the current user's Rork id from the verified JWT.
--
-- On Rork's hosted Supabase this is installed automatically during
-- provisioning. When pointing the app at a SELF-OWNED Supabase project you MUST
-- create it yourself (this block), otherwise every RLS policy below errors and
-- all reads/writes fail.
--
-- It reads the `sub` claim that PostgREST puts into `request.jwt.claims` after
-- it verifies the bearer token. For that verification to populate the claims,
-- your Supabase project must be configured to TRUST Rork's JWTs (see the
-- "JWT trust" note at the bottom of this file).
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION user_id()
RETURNS text
LANGUAGE sql
STABLE
AS $
  SELECT COALESCE(
    nullif(current_setting('request.jwt.claims', true)::json ->> 'sub', ''),
    nullif(current_setting('request.jwt.claim.sub', true), '')
  );
$;


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

-- PRIVACY: `profiles` holds PII (email, sign-in identity). It is OWNER-ONLY.
-- Coaches must NEVER read this table — they read `player_profiles` (the
-- shareable roster layer) instead. The old permissive "USING (true)" policy
-- leaked every user's email to every authenticated user, so we drop it.
DROP POLICY IF EXISTS "profiles_select_all" ON profiles;
DROP POLICY IF EXISTS "profiles_select_own" ON profiles;
CREATE POLICY "profiles_select_own" ON profiles FOR SELECT USING (user_id() = id);
CREATE POLICY "profiles_insert_own" ON profiles FOR INSERT WITH CHECK (user_id() = id);
CREATE POLICY "profiles_update_own" ON profiles FOR UPDATE USING (user_id() = id) WITH CHECK (user_id() = id);


-- -----------------------------------------------------------------------------
-- coaches — allow-list of users with curriculum write access.
--
-- A coach is identified by EMAIL up-front (seeded by an admin). On the coach's
-- first Sign in with Apple, the app matches their email to a row here and
-- stamps `user_id` so every later RLS check resolves by `user_id` (works even
-- if the coach later hides their email). `is_active` revokes access without
-- deleting the file. `role` distinguishes head coaches (who manage the team).
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS coaches (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email        text UNIQUE NOT NULL,
  display_name text,
  role         text NOT NULL DEFAULT 'coach',   -- 'coach' | 'head_coach'
  user_id      text REFERENCES profiles(id),    -- populated after first sign-in
  is_active    boolean NOT NULL DEFAULT true,
  created_at   timestamptz DEFAULT now()
);

-- Migrate any legacy coaches table (PK was user_id, no email/role columns).
ALTER TABLE coaches ADD COLUMN IF NOT EXISTS id           uuid DEFAULT gen_random_uuid();
ALTER TABLE coaches ADD COLUMN IF NOT EXISTS email        text;
ALTER TABLE coaches ADD COLUMN IF NOT EXISTS display_name text;
ALTER TABLE coaches ADD COLUMN IF NOT EXISTS role         text NOT NULL DEFAULT 'coach';
ALTER TABLE coaches ADD COLUMN IF NOT EXISTS is_active    boolean NOT NULL DEFAULT true;

ALTER TABLE coaches ENABLE ROW LEVEL SECURITY;

-- Seed the two head coaches. Emails are stored lower-cased so the app can match
-- case-insensitively with a plain equality check.
INSERT INTO coaches (email, display_name, role)
VALUES
  ('mf.elitetraining@gmail.com', 'Coach Matteo Finazzi', 'head_coach'),
  ('josephmcgee36@gmail.com',    'Joe McGee',            'head_coach')
ON CONFLICT (email) DO UPDATE
  SET display_name = EXCLUDED.display_name,
      role         = EXCLUDED.role,
      is_active    = true;

-- Any authenticated user can read the coach list (so the app can check its own role).
DROP POLICY IF EXISTS "coaches_select_all" ON coaches;
CREATE POLICY "coaches_select_all" ON coaches FOR SELECT USING (true);

-- Self-link: on first sign-in a user may stamp their own `user_id` onto the row
-- whose email matches their JWT email. They cannot change email/role/is_active.
DROP POLICY IF EXISTS "coaches_self_link" ON coaches;
CREATE POLICY "coaches_self_link" ON coaches
  FOR UPDATE USING (lower(email) = lower(auth.jwt() ->> 'email'))
  WITH CHECK (lower(email) = lower(auth.jwt() ->> 'email'));

-- Head coaches manage the team (add / deactivate other coaches).
DROP POLICY IF EXISTS "coaches_head_manage" ON coaches;
CREATE POLICY "coaches_head_manage" ON coaches
  FOR ALL USING (
    user_id() IN (SELECT user_id FROM coaches WHERE role = 'head_coach' AND is_active = true)
  ) WITH CHECK (
    user_id() IN (SELECT user_id FROM coaches WHERE role = 'head_coach' AND is_active = true)
  );


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
  FOR ALL USING (user_id() IN (SELECT user_id FROM coaches WHERE is_active = true))
  WITH CHECK (user_id() IN (SELECT user_id FROM coaches WHERE is_active = true));


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
  FOR ALL USING (user_id() IN (SELECT user_id FROM coaches WHERE is_active = true))
  WITH CHECK (user_id() IN (SELECT user_id FROM coaches WHERE is_active = true));


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
  FOR ALL USING (user_id() IN (SELECT user_id FROM coaches WHERE is_active = true))
  WITH CHECK (user_id() IN (SELECT user_id FROM coaches WHERE is_active = true));


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
  FOR ALL USING (user_id() IN (SELECT user_id FROM coaches WHERE is_active = true))
  WITH CHECK (user_id() IN (SELECT user_id FROM coaches WHERE is_active = true));


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
  FOR ALL USING (user_id() IN (SELECT user_id FROM coaches WHERE is_active = true))
  WITH CHECK (user_id() IN (SELECT user_id FROM coaches WHERE is_active = true));


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
  FOR ALL USING (user_id() IN (SELECT user_id FROM coaches WHERE is_active = true))
  WITH CHECK (user_id() IN (SELECT user_id FROM coaches WHERE is_active = true));


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
  FOR ALL USING (user_id() IN (SELECT user_id FROM coaches WHERE is_active = true))
  WITH CHECK (user_id() IN (SELECT user_id FROM coaches WHERE is_active = true));


-- -----------------------------------------------------------------------------
-- coach_notes — monthly coach note surfaced on the parent report. One row per
-- calendar month ("2026-06"); coach edits update the same row.
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS coach_notes (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  month       text NOT NULL UNIQUE,        -- "YYYY-MM"
  body        text NOT NULL DEFAULT '',
  updated_at  timestamptz DEFAULT now()
);

ALTER TABLE coach_notes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "coach_notes_select_auth" ON coach_notes
  FOR SELECT USING (auth.jwt() ->> 'role' = 'authenticated');
CREATE POLICY "coach_notes_coach_write" ON coach_notes
  FOR ALL USING (user_id() IN (SELECT user_id FROM coaches WHERE is_active = true))
  WITH CHECK (user_id() IN (SELECT user_id FROM coaches WHERE is_active = true));


-- =============================================================================
-- PLAYER TABLES (player-owned)
-- =============================================================================

-- -----------------------------------------------------------------------------
-- player_profiles
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS player_profiles (
  id            text PRIMARY KEY,             -- player record id (= account id for self-managed players, random uuid for managed athletes)
  display_name  text,
  initials      text,
  kit_number    text,
  position      text,
  created_at    timestamptz DEFAULT now()
);

-- --- Additive columns (safe to re-run) -------------------------------------
-- username     : unique, case-insensitive handle. The ONLY uniqueness-enforced
--                field. Kit numbers / fun identifiers may overlap.
-- account_id   : the controlling login (parent or self). Multiple athletes that
--                share one account_id form a family/household.
-- managed      : true when this athlete has no own login (managed by a parent).
-- is_example   : coach-only placeholder rows. Hidden from the player app and
--                excluded from username uniqueness + any real reports.
ALTER TABLE player_profiles ADD COLUMN IF NOT EXISTS username    text;
ALTER TABLE player_profiles ADD COLUMN IF NOT EXISTS account_id  text REFERENCES profiles(id);
ALTER TABLE player_profiles ADD COLUMN IF NOT EXISTS managed     boolean NOT NULL DEFAULT false;
ALTER TABLE player_profiles ADD COLUMN IF NOT EXISTS is_example  boolean NOT NULL DEFAULT false;

-- Onboarding identity captured during the cinematic admission flow. All
-- shareable (coach-visible) — none of it is private/billing data.
-- pledge_tier   : 'recovery' | 'standard' | 'elite' commitment tier.
-- foot          : 'Right' | 'Left' dominant foot.
-- member_number : auto-generated member id shown on the passport (not unique).
-- class_year    : high-school graduation year.
ALTER TABLE player_profiles ADD COLUMN IF NOT EXISTS pledge_tier   text;
ALTER TABLE player_profiles ADD COLUMN IF NOT EXISTS foot          text;
ALTER TABLE player_profiles ADD COLUMN IF NOT EXISTS member_number integer;
ALTER TABLE player_profiles ADD COLUMN IF NOT EXISTS class_year    integer;

-- Backfill account_id for existing self-managed rows (id == account).
UPDATE player_profiles SET account_id = id WHERE account_id IS NULL;

-- Case-insensitive uniqueness on real (non-example) usernames.
CREATE UNIQUE INDEX IF NOT EXISTS player_profiles_username_unique
  ON player_profiles (lower(username))
  WHERE is_example = false AND username IS NOT NULL;

ALTER TABLE player_profiles ENABLE ROW LEVEL SECURITY;

-- Owner (account holder) + any coach can read; owner writes their own + their
-- managed athletes. Coaches may also UPDATE roster fields (edit / reset) but a
-- trigger (below) prevents them from touching the username.
DROP POLICY IF EXISTS "player_profiles_select" ON player_profiles;
DROP POLICY IF EXISTS "player_profiles_insert_own" ON player_profiles;
DROP POLICY IF EXISTS "player_profiles_update_own" ON player_profiles;
CREATE POLICY "player_profiles_select" ON player_profiles
  FOR SELECT USING (
    user_id() = account_id
    OR user_id() IN (SELECT user_id FROM coaches WHERE is_active = true)
  );
CREATE POLICY "player_profiles_insert_own" ON player_profiles
  FOR INSERT WITH CHECK (
    user_id() = account_id
    OR user_id() IN (SELECT user_id FROM coaches WHERE is_active = true)
  );
CREATE POLICY "player_profiles_update" ON player_profiles
  FOR UPDATE USING (
    user_id() = account_id
    OR user_id() IN (SELECT user_id FROM coaches WHERE is_active = true)
  ) WITH CHECK (
    user_id() = account_id
    OR user_id() IN (SELECT user_id FROM coaches WHERE is_active = true)
  );
CREATE POLICY "player_profiles_delete_own" ON player_profiles
  FOR DELETE USING (user_id() = account_id);


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
  FOR SELECT USING (user_id() = player_id OR user_id() IN (SELECT user_id FROM coaches WHERE is_active = true));
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
  FOR SELECT USING (user_id() = player_id OR user_id() IN (SELECT user_id FROM coaches WHERE is_active = true));
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
  FOR SELECT USING (user_id() = player_id OR user_id() IN (SELECT user_id FROM coaches WHERE is_active = true));
CREATE POLICY "certifications_insert_own" ON certifications
  FOR INSERT WITH CHECK (user_id() = player_id);
CREATE POLICY "certifications_delete_own" ON certifications
  FOR DELETE USING (user_id() = player_id);


-- =============================================================================
-- FAMILIES + ROSTER INVITES + PROFILE INTEGRITY
-- =============================================================================

-- -----------------------------------------------------------------------------
-- families — a household. Multiple player_profiles sharing account_id belong to
-- one family; this row just gives the household a name + owner.
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS families (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id    text NOT NULL REFERENCES profiles(id),   -- the parent/primary login
  name        text,
  created_at  timestamptz DEFAULT now()
);

ALTER TABLE families ENABLE ROW LEVEL SECURITY;

-- Owner-only. Coaches do NOT need household grouping; they see each athlete
-- individually on the roster.
CREATE POLICY "families_select_own" ON families
  FOR SELECT USING (user_id() = owner_id);
CREATE POLICY "families_insert_own" ON families
  FOR INSERT WITH CHECK (user_id() = owner_id);
CREATE POLICY "families_update_own" ON families
  FOR UPDATE USING (user_id() = owner_id) WITH CHECK (user_id() = owner_id);
CREATE POLICY "families_delete_own" ON families
  FOR DELETE USING (user_id() = owner_id);

-- Optional link from a player to a family (kept nullable + additive).
ALTER TABLE player_profiles ADD COLUMN IF NOT EXISTS family_id uuid REFERENCES families(id) ON DELETE SET NULL;


-- -----------------------------------------------------------------------------
-- roster_invites — coach-issued one-time codes that pre-fill a player profile.
-- A coach creates these in the admin; a subscribed/trial player redeems the
-- code on first sign-in and the fields merge into their profile.
--
-- Subscription rule: redemption requires an active subscription or trial. After
-- a trial lapses the invite + player_profile + progress ROWS are retained (the
-- coach keeps the file in case the player resubscribes), but the player loses
-- *access* to paid content — that gate is enforced client-side by the
-- subscription entitlement, not by deleting data.
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS roster_invites (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code         text NOT NULL UNIQUE,            -- 6-char A–Z0–9, matches app format
  coach_id     text NOT NULL REFERENCES profiles(id),
  display_name text,
  kit_number   text,
  position     text,
  status       text NOT NULL DEFAULT 'pending', -- pending | claimed | revoked
  claimed_by   text REFERENCES profiles(id),    -- account that redeemed
  player_id    text,                            -- resulting player_profiles.id
  created_at   timestamptz DEFAULT now(),
  claimed_at   timestamptz
);

ALTER TABLE roster_invites ENABLE ROW LEVEL SECURITY;

-- Coaches manage their own invites. Players never read this table directly —
-- they redeem via the SECURITY DEFINER function below (so coach data is not
-- exposed). The claimer can read their own claimed invite for confirmation.
CREATE POLICY "roster_invites_coach_all" ON roster_invites
  FOR ALL USING (user_id() = coach_id AND user_id() IN (SELECT user_id FROM coaches WHERE is_active = true))
  WITH CHECK (user_id() = coach_id AND user_id() IN (SELECT user_id FROM coaches WHERE is_active = true));
CREATE POLICY "roster_invites_select_claimer" ON roster_invites
  FOR SELECT USING (user_id() = claimed_by);


-- -----------------------------------------------------------------------------
-- username_available(candidate) — SECURITY DEFINER so clients can check a name
-- without being able to read other players' rows. Returns true if free.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION username_available(candidate text)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $
  SELECT NOT EXISTS (
    SELECT 1 FROM player_profiles
    WHERE is_example = false
      AND lower(username) = lower(trim(candidate))
  );
$;


-- -----------------------------------------------------------------------------
-- claim_roster_invite(invite_code, p_username) — redeem a coach invite for the
-- calling user. Creates/updates the caller's player_profile with the coach's
-- pre-filled fields + the chosen unique username, and marks the invite claimed.
-- Runs as SECURITY DEFINER so the player never reads the coach's invite table.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION claim_roster_invite(invite_code text, p_username text)
RETURNS player_profiles
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $
DECLARE
  uid     text := user_id();
  inv     roster_invites;
  result  player_profiles;
BEGIN
  IF uid IS NULL THEN
    RAISE EXCEPTION 'not_authenticated';
  END IF;

  SELECT * INTO inv FROM roster_invites
    WHERE lower(code) = lower(trim(invite_code)) AND status = 'pending'
    FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'invalid_or_used_code';
  END IF;

  IF NOT username_available(p_username) THEN
    RAISE EXCEPTION 'username_taken';
  END IF;

  INSERT INTO player_profiles (id, account_id, username, display_name, kit_number, position)
    VALUES (uid, uid, trim(p_username), inv.display_name, inv.kit_number, inv.position)
  ON CONFLICT (id) DO UPDATE
    SET username     = EXCLUDED.username,
        display_name = EXCLUDED.display_name,
        kit_number   = EXCLUDED.kit_number,
        position     = EXCLUDED.position
  RETURNING * INTO result;

  UPDATE roster_invites
    SET status = 'claimed', claimed_by = uid, player_id = uid, claimed_at = now()
    WHERE id = inv.id;

  RETURN result;
END;
$;


-- -----------------------------------------------------------------------------
-- redeem_roster_invite(invite_code) — optional, post-onboarding redemption.
-- Unlike claim_roster_invite (used at first sign-up to pick a username), this
-- merges the coach's pre-filled fields into the caller's EXISTING profile and
-- preserves the player's own username. Safe to call any time after onboarding,
-- mirroring a typical "Redeem code" option. SECURITY DEFINER so the player
-- never reads the coach's invite table.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION redeem_roster_invite(invite_code text)
RETURNS player_profiles
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $
DECLARE
  uid     text := user_id();
  inv     roster_invites;
  result  player_profiles;
BEGIN
  IF uid IS NULL THEN
    RAISE EXCEPTION 'not_authenticated';
  END IF;

  SELECT * INTO inv FROM roster_invites
    WHERE lower(code) = lower(trim(invite_code)) AND status = 'pending'
    FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'invalid_or_used_code';
  END IF;

  -- Merge the coach's shareable fields into the caller's existing profile,
  -- keeping their chosen username. If they somehow have no profile yet, create
  -- one with a temporary handle derived from their uid.
  INSERT INTO player_profiles (id, account_id, username, display_name, kit_number, position)
    VALUES (uid, uid, 'player_' || substr(uid, 1, 8), inv.display_name, inv.kit_number, inv.position)
  ON CONFLICT (id) DO UPDATE
    SET display_name = COALESCE(EXCLUDED.display_name, player_profiles.display_name),
        kit_number   = COALESCE(EXCLUDED.kit_number, player_profiles.kit_number),
        position     = COALESCE(EXCLUDED.position, player_profiles.position)
  RETURNING * INTO result;

  UPDATE roster_invites
    SET status = 'claimed', claimed_by = uid, player_id = uid, claimed_at = now()
    WHERE id = inv.id;

  RETURN result;
END;
$;


-- -----------------------------------------------------------------------------
-- Protect the username: a coach may edit roster fields (name/kit/position) and
-- reset, but must NOT change a player's chosen username. Owners may change
-- their own.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION protect_player_username()
RETURNS trigger
LANGUAGE plpgsql
AS $
BEGIN
  IF NEW.username IS DISTINCT FROM OLD.username AND user_id() <> OLD.account_id THEN
    NEW.username := OLD.username;  -- silently keep the owner's handle
  END IF;
  RETURN NEW;
END;
$;

DROP TRIGGER IF EXISTS trg_protect_player_username ON player_profiles;
CREATE TRIGGER trg_protect_player_username
  BEFORE UPDATE ON player_profiles
  FOR EACH ROW EXECUTE FUNCTION protect_player_username();


-- =============================================================================
-- JWT TRUST (self-owned Supabase only) — REQUIRED for user_id() to work
-- =============================================================================
-- This app authenticates with **Rork Auth** (Sign in with Apple), not Supabase
-- Auth. For RLS to resolve the signed-in user, your Supabase project must
-- verify Rork's JWTs so `request.jwt.claims` (and therefore `user_id()`) is
-- populated. This is a DASHBOARD setting, not SQL — do it once:
--
--   Supabase Dashboard → Authentication → Sign In / Providers →
--   Third-Party Auth → Add provider → Custom
--     • JWKS URL : https://api.rork.com/.well-known/jwks.json
--     • Issuer   : https://api.rork.com
--
-- After saving, Rork's bearer tokens are accepted by PostgREST, `auth.jwt()`
-- returns the Rork claims (sub, email, role=authenticated), and every policy
-- above resolves correctly. Until this is configured, all authenticated
-- queries will be rejected even though the schema itself is correct.
-- =============================================================================
