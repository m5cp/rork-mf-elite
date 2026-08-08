-- =============================================================================
--  2026-08-05  Scope coach reads to the coach's own roster
--
--  STATUS: SUPERSEDED — DO NOT RUN. Replaced by
--  2026-08-08-coach-roster-scoping-APPLIED.sql.
--
--  Two assumptions in this file are false against the live database: it
--  backfills from `roster_invites`, which is empty (0 rows, ever), so it would
--  link nobody and cut every non-head coach off from every player; and it keys
--  the link table on `profiles(id)`, which 8 of the 11 coaches do not have
--  because they have never signed in. Kept for the reasoning in the header.
--
--  WHY
--  ---
--  Today every active coach can read every child in the app. This is not a
--  missing client-side filter — it is the policy itself:
--
--      CREATE POLICY "player_profiles_select" ON player_profiles
--        FOR SELECT USING (
--          user_id() = account_id
--          OR user_id() IN (SELECT user_id FROM coaches WHERE is_active = true)
--        );
--
--  `player_state` and `player_progress` carry the same shape, and
--  `CoachViewModel.loadRoster()` fetches all of `player_profiles` with only
--  `is_example=eq.false`. So a coach added for one U11 team can open Coach Mode
--  and see the entire customer base: names, usernames, kit numbers, positions,
--  XP, streaks, mastery, and full training history for every child.
--
--  The invite flow already stamps `roster_invites.coach_id` when a player
--  redeems a code — nothing has ever read it back for authorization. This
--  migration turns that existing link into the actual access boundary.
--
--  WHAT IT DOES
--  ------------
--  1. Adds a `coach_players` link table (coach <-> player), the explicit
--     roster membership the app has been missing.
--  2. Backfills it from the roster invites that have already been claimed, so
--     existing coach/player relationships survive.
--  3. Replaces the "any active coach" policies on player_profiles,
--     player_state and player_progress with "the coach linked to this player".
--  4. Keeps head coaches global. `coaches.role = 'head_coach'` continues to
--     read everyone, which is the behaviour Joe confirmed on 2026-07-21.
--
--  BEFORE YOU RUN THIS — three things to check
--  -------------------------------------------
--  a) Does every coach who currently needs access have a claimed invite? Run
--     the FIRST verification query below. Any coach/player pair that isn't in
--     `roster_invites` will LOSE access the moment this applies. If Joe and
--     Matteo are both head coaches this is fine, but a third coach who added
--     players by another route would be cut off.
--  b) `session_logs`, `combine_results` and the other per-player tables are
--     not in schema.sql (see SCHEMA-GAP.md), so their live policies aren't
--     visible here. They almost certainly carry the same "any active coach"
--     clause and need the same treatment. Section 5 is a template, commented
--     out, because the real column names need confirming first.
--  c) This is additive except for the three DROP POLICY / CREATE POLICY pairs,
--     which are replacements. No data is deleted anywhere in this file.
-- =============================================================================

BEGIN;

-- -----------------------------------------------------------------------------
-- 1. Explicit coach <-> player roster membership
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS coach_players (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  coach_id   text NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  player_id  text NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (coach_id, player_id)
);

CREATE INDEX IF NOT EXISTS coach_players_coach_idx  ON coach_players (coach_id);
CREATE INDEX IF NOT EXISTS coach_players_player_idx ON coach_players (player_id);

ALTER TABLE coach_players ENABLE ROW LEVEL SECURITY;

-- A coach sees their own links; a player can see who coaches them.
DROP POLICY IF EXISTS "coach_players_select" ON coach_players;
CREATE POLICY "coach_players_select" ON coach_players
  FOR SELECT USING (user_id() = coach_id OR user_id() = player_id);

-- Only an active coach can create or remove their own links.
DROP POLICY IF EXISTS "coach_players_write" ON coach_players;
CREATE POLICY "coach_players_write" ON coach_players
  FOR ALL USING (
    user_id() = coach_id
    AND user_id() IN (SELECT user_id FROM coaches WHERE is_active = true)
  ) WITH CHECK (
    user_id() = coach_id
    AND user_id() IN (SELECT user_id FROM coaches WHERE is_active = true)
  );

-- -----------------------------------------------------------------------------
-- 2. Backfill from invites that were already redeemed
-- -----------------------------------------------------------------------------
INSERT INTO coach_players (coach_id, player_id)
SELECT DISTINCT ri.coach_id, ri.player_id
FROM roster_invites ri
WHERE ri.status = 'claimed'
  AND ri.player_id IS NOT NULL
  AND ri.coach_id IS NOT NULL
ON CONFLICT (coach_id, player_id) DO NOTHING;

-- -----------------------------------------------------------------------------
-- 3. Helper: is the caller allowed to read this player?
--
--    Own account, OR a head coach (global by design), OR a coach explicitly
--    linked to this player.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION can_read_player(target_player_id text)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    user_id() = target_player_id
    OR EXISTS (
      SELECT 1 FROM coaches
      WHERE user_id = user_id() AND is_active = true AND role = 'head_coach'
    )
    OR EXISTS (
      SELECT 1 FROM coach_players cp
      JOIN coaches c ON c.user_id = cp.coach_id AND c.is_active = true
      WHERE cp.coach_id = user_id() AND cp.player_id = target_player_id
    );
$$;

-- -----------------------------------------------------------------------------
-- 4. Replace the "any active coach" read policies
-- -----------------------------------------------------------------------------

-- player_profiles: keyed on account_id
DROP POLICY IF EXISTS "player_profiles_select" ON player_profiles;
CREATE POLICY "player_profiles_select" ON player_profiles
  FOR SELECT USING (can_read_player(account_id));

-- player_state
DROP POLICY IF EXISTS "player_state_select" ON player_state;
CREATE POLICY "player_state_select" ON player_state
  FOR SELECT USING (can_read_player(player_id));

-- player_progress
DROP POLICY IF EXISTS "player_progress_select" ON player_progress;
CREATE POLICY "player_progress_select" ON player_progress
  FOR SELECT USING (can_read_player(player_id));

-- Coach UPDATE on player_profiles stays coach-scoped too: a coach should only
-- be able to edit roster fields for their own players.
DROP POLICY IF EXISTS "player_profiles_update" ON player_profiles;
CREATE POLICY "player_profiles_update" ON player_profiles
  FOR UPDATE USING (
    user_id() = account_id OR can_read_player(account_id)
  ) WITH CHECK (
    user_id() = account_id OR can_read_player(account_id)
  );

-- -----------------------------------------------------------------------------
-- 5. TEMPLATE for the tables that aren't in schema.sql (see SCHEMA-GAP.md).
--    Confirm the owner column name on each before uncommenting.
-- -----------------------------------------------------------------------------
-- DROP POLICY IF EXISTS "session_logs_select" ON session_logs;
-- CREATE POLICY "session_logs_select" ON session_logs
--   FOR SELECT USING (can_read_player(user_id));
--
-- DROP POLICY IF EXISTS "combine_results_select" ON combine_results;
-- CREATE POLICY "combine_results_select" ON combine_results
--   FOR SELECT USING (can_read_player(user_id));
--
-- DROP POLICY IF EXISTS "gameiq_completions_select" ON gameiq_completions;
-- CREATE POLICY "gameiq_completions_select" ON gameiq_completions
--   FOR SELECT USING (can_read_player(user_id));

COMMIT;

-- =============================================================================
--  VERIFICATION — run these BEFORE committing, and again after
-- =============================================================================

-- 1. WHO WOULD LOSE ACCESS. Every coach/player pair the app currently serves
--    that has no claimed invite backing it. Expect this to be empty, or to
--    contain only head coaches (who keep global access anyway).
--
--    SELECT c.user_id AS coach, c.role, count(pp.*) AS players_visible_today
--    FROM coaches c
--    CROSS JOIN player_profiles pp
--    WHERE c.is_active = true
--      AND pp.is_example = false
--      AND c.role <> 'head_coach'
--      AND NOT EXISTS (
--        SELECT 1 FROM coach_players cp
--        WHERE cp.coach_id = c.user_id AND cp.player_id = pp.account_id
--      )
--    GROUP BY c.user_id, c.role;

-- 2. WHAT THE BACKFILL PRODUCED.
--
--    SELECT coach_id, count(*) AS linked_players
--    FROM coach_players GROUP BY coach_id ORDER BY linked_players DESC;

-- 3. PROVE THE BOUNDARY HOLDS. Impersonate a non-head coach and confirm the
--    roster query returns only their own players.
--
--    SET LOCAL role authenticated;
--    SET LOCAL request.jwt.claims = '{"sub":"<non-head-coach-user-id>"}';
--    SELECT count(*) FROM player_profiles WHERE is_example = false;
--    RESET role;

-- =============================================================================
--  ROLLBACK — restores the previous (permissive) behaviour exactly
-- =============================================================================
--
-- BEGIN;
-- DROP POLICY IF EXISTS "player_profiles_select" ON player_profiles;
-- CREATE POLICY "player_profiles_select" ON player_profiles
--   FOR SELECT USING (
--     user_id() = account_id
--     OR user_id() IN (SELECT user_id FROM coaches WHERE is_active = true)
--   );
-- DROP POLICY IF EXISTS "player_state_select" ON player_state;
-- CREATE POLICY "player_state_select" ON player_state
--   FOR SELECT USING (user_id() = player_id OR user_id() IN (SELECT user_id FROM coaches WHERE is_active = true));
-- DROP POLICY IF EXISTS "player_progress_select" ON player_progress;
-- CREATE POLICY "player_progress_select" ON player_progress
--   FOR SELECT USING (user_id() = player_id OR user_id() IN (SELECT user_id FROM coaches WHERE is_active = true));
-- DROP POLICY IF EXISTS "player_profiles_update" ON player_profiles;
-- CREATE POLICY "player_profiles_update" ON player_profiles
--   FOR UPDATE USING (
--     user_id() = account_id
--     OR user_id() IN (SELECT user_id FROM coaches WHERE is_active = true)
--   ) WITH CHECK (
--     user_id() = account_id
--     OR user_id() IN (SELECT user_id FROM coaches WHERE is_active = true)
--   );
-- COMMIT;
--
-- (`coach_players` and `can_read_player` can be left in place — they are inert
--  once the policies above no longer reference them.)
