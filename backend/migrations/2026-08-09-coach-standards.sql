-- =============================================================================
--  2026-08-09  Head-coach combine baseline + targets by age group
--
--  STATUS: APPLIED to production on 2026-08-09. Written for central review and application.
--
--  WHY
--  ---
--  The MF Combine ships 8 tests and grades every result against the bundled
--  male/female scales in `combine-benchmarks.json`. Those scales are fixed and
--  the same for everyone. The owner wants two things on top of that:
--
--    1. "the base line test to be editable for the coach ... he can select
--       which ones he wants to use"
--    2. "allow the coach to have his own measurable standards based on the
--       athletes he trains by age group"
--
--  and explicitly wants BOTH numbers to survive: "coach picks tests, sets
--  targets by age group, but also has the national standards by age group or
--  skills level."
--
--  So this adds two small tables that LAYER OVER the bundled scales. Nothing
--  here replaces or edits the published standards — the app still reads those
--  from the app bundle, still shows both the boys and girls tier bars, and
--  falls back to them for any test/age group the coach has not spoken about.
--
--  WHAT IT DOES
--  ------------
--  `coach_baseline_tests`  which of the seeded combine tests count as "the
--                          baseline". Absence means included, so an empty table
--                          behaves exactly like today.
--  `coach_standards`       one target number per (test, age group). Overrides
--                          the published standard for players in that band.
--
--  SCOPE: ACADEMY-WIDE, NOT PER-COACH
--  ----------------------------------
--  Neither table carries a coach id, and reads are open to every client. That
--  is deliberate, and it is the same shape as `app_config` and
--  `content_overrides`:
--
--    * MF Elite is one academy. The two head-coach people set the standards
--      that every player in the app is measured against — the same decision
--      already made for content renames and the award title.
--    * Scoping reads through `coach_players` would break the feature outright.
--      That table deliberately contains only NON-head coaches (see
--      2026-08-08-coach-roster-scoping-APPLIED.sql, which excludes
--      `role = 'head_coach'` from the grandfather insert), while only head
--      coaches may write standards. A player linked to no head coach would
--      read zero rows and silently get default standards forever.
--    * Reads are `to public` rather than `to authenticated` because the app is
--      local-first: a player who has never signed in still opens the Combine
--      tab, and must still see the coach's baseline. `app_config_read` and
--      `content_overrides_read` already work exactly this way. The rows are
--      target numbers for a youth soccer test — no personal data.
--
--  A per-coach variant is left commented at the bottom for the day MF Elite
--  hosts more than one academy. It needs a head-coach entry in `coach_players`
--  (or an academy id on the player) before it can work.
--
--  WRITES are head-coach-only via `public.is_head_coach()`, matching every
--  other surface that changes what all players see (drills, disciplines,
--  levels, quotes, progression rules, renames, the award title).
--
--  This file is additive. No existing table, policy or row is touched.
-- =============================================================================

begin;

-- -----------------------------------------------------------------------------
-- 1. Which tests make up the baseline
--
--    Keyed on the combine test id seeded by `CombineSeed` ("juggle",
--    "coneweave", "wallpass", "figure8", "toetap30", "shuttle", "sprint20",
--    "broadjump"). Not a foreign key: combine tests live in the app bundle and
--    in each device's SwiftData store, not in Postgres.
--
--    NO ROW MEANS INCLUDED. A coach excluding a test writes `included = false`;
--    putting it back writes `included = true` rather than deleting, so the
--    audit log reads as a sequence of decisions rather than gaps.
-- -----------------------------------------------------------------------------
create table if not exists coach_baseline_tests (
  test_id    text primary key,
  included   boolean not null default true,
  updated_by text,
  updated_at timestamptz not null default now()
);

alter table coach_baseline_tests enable row level security;

drop policy if exists "coach_baseline_tests_read" on coach_baseline_tests;
create policy "coach_baseline_tests_read" on coach_baseline_tests
  for select to public using (true);

drop policy if exists "coach_baseline_tests_head_write" on coach_baseline_tests;
create policy "coach_baseline_tests_head_write" on coach_baseline_tests
  for all to authenticated
  using (public.is_head_coach())
  with check (public.is_head_coach());

-- -----------------------------------------------------------------------------
-- 2. The coach's own target per test, per age group
--
--    `age_band` holds a band id from the bundled benchmark file — U8, U10, U12,
--    U14, U16, U18, ADULT. Storing the SAME ids the published scales use is the
--    whole point: a coach target and the standard it overrides are addressed by
--    the identical key, so resolution is a straight substitution with no
--    mapping table and no chance of the two drifting apart.
--
--    There is deliberately no CHECK constraining `age_band` to that list. The
--    list ships inside the iOS app; a future release that adds a band would
--    start failing every insert against a constraint the database could not be
--    updated for in the same breath. An unknown band id simply never resolves
--    for anybody, which is a harmless no-op.
--
--    `target` is double precision, not numeric: PostgREST returns it as a bare
--    JSON number, which is what the client's JSONSerialization path expects.
--    Combine values are 2-decimal times and whole counts — no precision to lose.
-- -----------------------------------------------------------------------------
create table if not exists coach_standards (
  test_id    text not null,
  age_band   text not null,
  target     double precision not null,
  updated_by text,
  updated_at timestamptz not null default now(),
  primary key (test_id, age_band)
);

alter table coach_standards
  drop constraint if exists coach_standards_target_positive;
alter table coach_standards
  add constraint coach_standards_target_positive
  check (target > 0 and target < 1000000);

alter table coach_standards
  drop constraint if exists coach_standards_age_band_present;
alter table coach_standards
  add constraint coach_standards_age_band_present
  check (age_band <> '');

create index if not exists coach_standards_band_idx on coach_standards (age_band);

alter table coach_standards enable row level security;

drop policy if exists "coach_standards_read" on coach_standards;
create policy "coach_standards_read" on coach_standards
  for select to public using (true);

drop policy if exists "coach_standards_head_write" on coach_standards;
create policy "coach_standards_head_write" on coach_standards
  for all to authenticated
  using (public.is_head_coach())
  with check (public.is_head_coach());

-- -----------------------------------------------------------------------------
-- 3. Keep `updated_at` honest
--
--    The client upserts with `resolution=merge-duplicates` and never sends a
--    timestamp, so without this an edited row keeps the moment it was first
--    created — the same quiet flaw `app_config.updated_at` has today. These
--    rows are the thing every player is measured against; when one changed
--    needs to be answerable.
-- -----------------------------------------------------------------------------
-- `search_path` is pinned for the same reason every other function here pins
-- it: an unqualified name inside a SECURITY-sensitive path is a hijack waiting
-- to happen, and Supabase's linter flags the omission.
create or replace function public.touch_coach_standards_updated_at()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_coach_baseline_tests_touch on coach_baseline_tests;
create trigger trg_coach_baseline_tests_touch
  before update on coach_baseline_tests
  for each row execute function public.touch_coach_standards_updated_at();

drop trigger if exists trg_coach_standards_touch on coach_standards;
create trigger trg_coach_standards_touch
  before update on coach_standards
  for each row execute function public.touch_coach_standards_updated_at();

commit;

-- =============================================================================
--  VERIFICATION — suggested, run in a transaction and roll back
-- =============================================================================
--
--  begin;
--
--  -- head coach can write
--  set local role authenticated;
--  set local request.jwt.claims = '{"email":"josephmcgee36@gmail.com","role":"authenticated"}';
--  insert into coach_standards (test_id, age_band, target)
--    values ('sprint20','U14',3.60)
--    on conflict (test_id, age_band) do update set target = excluded.target;
--  insert into coach_baseline_tests (test_id, included) values ('toetap30', false)
--    on conflict (test_id) do update set included = excluded.included;
--
--  -- regular coach cannot  (expect 42501)
--  set local request.jwt.claims = '{"email":"appreview@mfelite.app","role":"authenticated"}';
--  insert into coach_standards (test_id, age_band, target) values ('juggle','U12',60);
--
--  -- a plain player can read both tables, and write to neither
--  set local request.jwt.claims = '{"email":"carsondprice@icloud.com","role":"authenticated"}';
--  select count(*) from coach_standards;        -- expect 1
--  select count(*) from coach_baseline_tests;   -- expect 1
--  update coach_standards set target = 9 where test_id = 'sprint20';  -- expect 0 rows
--
--  -- signed-out (anon) reads still work, because the app is local-first
--  set local role anon;
--  select count(*) from coach_standards;        -- expect 1
--
--  rollback;
--
--  APP SIDE: `CoachStandardsEditorView` is only reachable, and only renders its
--  controls, when `SubscriptionService.coachRole == "head_coach"`, so a regular
--  coach is never shown a screen where every save comes back "not allowed".
--  With both tables empty the app behaves exactly as it does today: all 8 tests
--  are the baseline and every target is the published standard.
--
-- =============================================================================
--  ROLLBACK — removes the feature entirely
-- =============================================================================
--
-- begin;
-- drop trigger if exists trg_coach_standards_touch on coach_standards;
-- drop trigger if exists trg_coach_baseline_tests_touch on coach_baseline_tests;
-- drop function if exists public.touch_coach_standards_updated_at();
-- drop policy if exists "coach_standards_read" on coach_standards;
-- drop policy if exists "coach_standards_head_write" on coach_standards;
-- drop policy if exists "coach_baseline_tests_read" on coach_baseline_tests;
-- drop policy if exists "coach_baseline_tests_head_write" on coach_baseline_tests;
-- drop table if exists coach_standards;
-- drop table if exists coach_baseline_tests;
-- commit;
--
-- The app degrades cleanly without these tables: both reads fail soft in
-- `SupabaseClient` (log + nil), the store keeps its UserDefaults cache, and a
-- device that never saw a row treats every test as baseline with published
-- targets.
--
-- =============================================================================
--  FUTURE — per-coach scoping, for when MF Elite is more than one academy
-- =============================================================================
--
--  Add `coach_email text not null` to both tables, move it into the primary
--  key, and replace the read policies with something like:
--
--  create policy "coach_standards_read" on coach_standards
--    for select to authenticated using (
--      public.is_head_coach()
--      or lower(coach_email) = lower(coalesce(nullif(
--           current_setting('request.jwt.claims', true)::json ->> 'email',''), ''))
--      or exists (
--        select 1 from public.coach_players cp
--        where cp.player_id = public.user_id()
--          and lower(cp.coach_email) = lower(coach_standards.coach_email)
--      )
--    );
--
--  This CANNOT ship as-is today: `coach_players` holds only non-head coaches,
--  and only head coaches can write standards, so the `exists` clause matches
--  nothing and every player falls back to defaults. Linking head coaches into
--  `coach_players` is the prerequisite.
-- =============================================================================
