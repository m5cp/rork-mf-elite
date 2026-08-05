-- =============================================================================
--  Coach roster seed — head coaches and coaches
--
--  STATUS: applied to project twzukrzcfquxfmrnffze on 2026-08-05 as migration
--  `ensure_head_coach_roster`. Kept here so the roster is reproducible if the
--  database is ever rebuilt from this repo, and so the source of truth for
--  "who is an admin" is reviewable in version control rather than living only
--  in the dashboard.
--
--  Idempotent. Safe to re-run: it inserts what's missing, promotes anyone not
--  already at the right role, and reactivates anyone deactivated. It never
--  touches accounts outside these lists and never deletes.
--
--  KEEP IN SYNC with `ios-mf-elite/MFElite/Services/Sync/CoachAllowlist.swift`,
--  which is the offline / pre-server-check fallback. If an address is added
--  here it should be added there too, otherwise that coach gets no access
--  until the `my_coach_role()` RPC returns — which fails offline and during
--  App Review.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Head coaches — full admin. Media upload, publishing, announcements, coach
-- notes, progress reports, team management, XP grants / streak fixes
-- (support_adjustments), app config, audit log, and global player visibility.
-- -----------------------------------------------------------------------------
INSERT INTO coaches (email, role, is_active, display_name)
VALUES
  ('josephmcgee36@gmail.com',          'head_coach', true, 'Joe McGee'),
  ('joe@m5cairio.com',                 'head_coach', true, 'Joe McGee'),
  ('matteo.m.finazzi@gmail.com',       'head_coach', true, 'Matteo Finazzi'),
  ('matteofinazzi.official@gmail.com', 'head_coach', true, 'Matteo Finazzi'),
  ('mf.elitetraining@gmail.com',       'head_coach', true, 'MF Elite Training')
ON CONFLICT (email) DO UPDATE
  SET role = 'head_coach',
      is_active = true,
      display_name = COALESCE(coaches.display_name, EXCLUDED.display_name);

-- -----------------------------------------------------------------------------
-- Coaches — everything above EXCEPT the head-coach-only surfaces
-- (support_adjustments / XP grants, app_config, admin_audit, content_overrides,
-- and deleting another coach's team).
-- -----------------------------------------------------------------------------
INSERT INTO coaches (email, role, is_active, display_name)
VALUES
  ('suemcgee83@gmail.com',      'coach', true, 'Susan McGee'),
  ('avamcgee2476@gmail.com',    'coach', true, 'Ava McGee'),
  ('avam221611@icloud.com',     'coach', true, 'Ava McGee'),
  ('audrey.mcgee1524@gmail.com','coach', true, 'Audrey McGee'),
  ('audmcgee@icloud.com',       'coach', true, 'Audrey McGee'),
  ('appreview@mfelite.app',     'coach', true, 'App Review')
ON CONFLICT (email) DO UPDATE
  SET is_active = true,
      display_name = COALESCE(coaches.display_name, EXCLUDED.display_name);
-- NB: deliberately does NOT force `role` for this group, so a coach who was
-- promoted to head_coach in the dashboard isn't silently demoted by a re-run.

-- -----------------------------------------------------------------------------
-- Link any account that already exists in auth, so both authorization paths
-- (JWT email and coaches.user_id) resolve. Rows stay unlinked until that
-- person signs in for the first time, which is expected and harmless —
-- my_coach_role() matches on email as well.
-- -----------------------------------------------------------------------------
UPDATE coaches c
SET user_id = u.id::text
FROM auth.users u
WHERE c.user_id IS NULL AND lower(u.email) = lower(c.email);

-- -----------------------------------------------------------------------------
-- Verify
-- -----------------------------------------------------------------------------
-- select c.email, c.role, c.is_active,
--        case when c.user_id is null then 'not signed in yet' else 'linked' end as auth_link
-- from coaches c order by c.role, c.email;
