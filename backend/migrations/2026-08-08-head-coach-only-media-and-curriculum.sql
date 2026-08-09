-- =============================================================================
--  2026-08-08  Media upload + curriculum editing become head-coach-only
--
--  STATUS: APPLIED to production (twzukrzcfquxfmrnffze) on 2026-08-08.
--  Verified by impersonation, in a transaction, rolled back — results below.
--
--  WHY
--  ---
--  These writes were gated on `is_active_coach()`, which is all 11 rows in the
--  `coaches` table — five head-coach addresses belonging to two people, plus
--  six regular coaches (family accounts and the Apple reviewer). Owner's
--  decision: only the two head-coach people should be able to change what
--  every player in the app sees.
--
--  Regular coaches keep everything else: the dashboard, player detail, teams,
--  rosters, invites, announcements, coach workouts, schedule events, notes,
--  evaluations and progress reports.
--
--  NOTE ON THE DROPS
--  -----------------
--  Both generations of every policy are dropped. Policies are OR'd together,
--  so leaving the older `user_id`-based twin in place would have quietly kept
--  the old permission alive underneath the new one.
-- =============================================================================

begin;

-- 1. Storage: drill demo videos and reference images -------------------------
drop policy if exists "drill media coach write"  on storage.objects;
drop policy if exists "drill media coach update" on storage.objects;
drop policy if exists "drill media coach delete" on storage.objects;
drop policy if exists "drill_videos_coach_insert" on storage.objects;
drop policy if exists "drill_videos_coach_update" on storage.objects;
drop policy if exists "drill_videos_coach_delete" on storage.objects;
drop policy if exists "drill_images_coach_insert" on storage.objects;
drop policy if exists "drill_images_coach_update" on storage.objects;
drop policy if exists "drill_images_coach_delete" on storage.objects;

drop policy if exists "drill_media_head_insert" on storage.objects;
create policy "drill_media_head_insert" on storage.objects
  for insert to authenticated
  with check (bucket_id in ('drill-videos','drill-images') and public.is_head_coach());

-- UPDATE is required alongside INSERT for an upsert (x-upsert) to work — the
-- missing half of that pair is why no upload succeeded for the app's first two
-- months. Reads stay open to every signed-in user via
-- `drill_media_authenticated_select`; this is only the write half.
drop policy if exists "drill_media_head_update" on storage.objects;
create policy "drill_media_head_update" on storage.objects
  for update to authenticated
  using (bucket_id in ('drill-videos','drill-images') and public.is_head_coach())
  with check (bucket_id in ('drill-videos','drill-images') and public.is_head_coach());

drop policy if exists "drill_media_head_delete" on storage.objects;
create policy "drill_media_head_delete" on storage.objects
  for delete to authenticated
  using (bucket_id in ('drill-videos','drill-images') and public.is_head_coach());

-- 2. Curriculum content ------------------------------------------------------
drop policy if exists "drills_coach_write"              on drills;
drop policy if exists "disciplines_coach_write"         on disciplines;
drop policy if exists "categories_coach_write"          on categories;
drop policy if exists "levels_coach_write"              on levels;
drop policy if exists "curriculum_edits_coach_write"    on curriculum_edits;
drop policy if exists "curriculum_edits_coach_write_v2" on curriculum_edits;
drop policy if exists "quotes_coach_write"              on daily_quotes;
drop policy if exists "rules_coach_write"               on progression_rules;

drop policy if exists "drills_head_write" on drills;
create policy "drills_head_write" on drills
  for all to authenticated using (public.is_head_coach()) with check (public.is_head_coach());
drop policy if exists "disciplines_head_write" on disciplines;
create policy "disciplines_head_write" on disciplines
  for all to authenticated using (public.is_head_coach()) with check (public.is_head_coach());
drop policy if exists "categories_head_write" on categories;
create policy "categories_head_write" on categories
  for all to authenticated using (public.is_head_coach()) with check (public.is_head_coach());
drop policy if exists "levels_head_write" on levels;
create policy "levels_head_write" on levels
  for all to authenticated using (public.is_head_coach()) with check (public.is_head_coach());
drop policy if exists "curriculum_edits_head_write" on curriculum_edits;
create policy "curriculum_edits_head_write" on curriculum_edits
  for all to authenticated using (public.is_head_coach()) with check (public.is_head_coach());
drop policy if exists "quotes_head_write" on daily_quotes;
create policy "quotes_head_write" on daily_quotes
  for all to authenticated using (public.is_head_coach()) with check (public.is_head_coach());
drop policy if exists "rules_head_write" on progression_rules;
create policy "rules_head_write" on progression_rules
  for all to authenticated using (public.is_head_coach()) with check (public.is_head_coach());

commit;

-- =============================================================================
--  VERIFICATION (2026-08-08, transaction, rolled back)
-- =============================================================================
--
--  head coach (Joe, has user_id)          upload video      ALLOWED
--  head coach (Joe)                       edit curriculum   ALLOWED
--  head coach by email only, never signed in
--    (mf.elitetraining@gmail.com)         upload video      ALLOWED
--  regular coach (suemcgee83@gmail.com)   upload video      blocked 42501
--  regular coach                          edit curriculum   blocked 42501
--  regular coach                          create team       ALLOWED  (kept)
--  regular coach                          post announcement ALLOWED  (kept)
--  plain player (not a coach)             upload video      blocked 42501
--
--  Both head-coach identity forms work because `is_head_coach()` builds on
--  `my_coach_role()`, which resolves by JWT email OR `coaches.user_id` — and
--  three of the five head-coach addresses have never signed in, so they have
--  no user_id to match on.
--
--  APP SIDE: `CoachView.drillEditorSection` is hidden unless
--  `coachRole == "head_coach"`, so a regular coach is never offered a screen
--  where every save would come back "not allowed".
--
--  APP REVIEW: appreview@mfelite.app is a regular coach, so it can no longer
--  upload drill media. It keeps the whole coach dashboard, teams, rosters and
--  announcements. If a future review needs the upload flow exercised, promote
--  that row to head_coach for the duration.
--
-- =============================================================================
--  ROLLBACK — back to any active coach
-- =============================================================================
--
-- begin;
-- drop policy if exists "drill_media_head_insert" on storage.objects;
-- drop policy if exists "drill_media_head_update" on storage.objects;
-- drop policy if exists "drill_media_head_delete" on storage.objects;
-- create policy "drill_videos_coach_insert" on storage.objects for insert to authenticated
--   with check (bucket_id = 'drill-videos' and is_active_coach());
-- create policy "drill_videos_coach_update" on storage.objects for update to authenticated
--   using (bucket_id = 'drill-videos' and is_active_coach())
--   with check (bucket_id = 'drill-videos' and is_active_coach());
-- create policy "drill_videos_coach_delete" on storage.objects for delete to authenticated
--   using (bucket_id = 'drill-videos' and is_active_coach());
-- create policy "drill_images_coach_insert" on storage.objects for insert to authenticated
--   with check (bucket_id = 'drill-images' and is_active_coach());
-- create policy "drill_images_coach_update" on storage.objects for update to authenticated
--   using (bucket_id = 'drill-images' and is_active_coach())
--   with check (bucket_id = 'drill-images' and is_active_coach());
-- create policy "drill_images_coach_delete" on storage.objects for delete to authenticated
--   using (bucket_id = 'drill-images' and is_active_coach());
-- drop policy if exists "drills_head_write" on drills;
-- create policy "drills_coach_write" on drills for all to authenticated
--   using (is_active_coach()) with check (is_active_coach());
-- -- (and the same shape for disciplines, categories, levels, curriculum_edits,
-- --  daily_quotes, progression_rules)
-- commit;
