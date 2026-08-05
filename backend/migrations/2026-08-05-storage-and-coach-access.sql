-- =============================================================================
--  2026-08-05  Coach media uploads + coach authorization
--
--  STATUS: **ALREADY APPLIED** to project twzukrzcfquxfmrnffze on 2026-08-05.
--  Recorded here so the repo reflects the live database. Applied as two
--  migrations: `fix_storage_upload_policies_and_coach_identity` and
--  `coach_access_resolve_by_email_or_user_id`.
--
--  THE BUG
--  -------
--  Coach media upload had never worked. Not "worked and regressed" — there
--  were zero objects in every storage bucket since the project was created.
--
--  Three causes, in the order they bite:
--
--  1. THE BLOCKER. The app uploads with `x-upsert: true`
--     (SupabaseClient.uploadStorage). A Supabase storage upsert needs SELECT +
--     UPDATE + INSERT on storage.objects, and there was NO SELECT policy on
--     storage.objects at all. RLS is on, so every upload was rejected before
--     any coach check mattered. This also silently broke player avatar uploads
--     to `player-media`, which is why avatars never restored on a new device.
--
--  2. `drill-images` had only the user_id-based coach policy, while
--     `drill-videos` had both a user_id-based and an email-based one.
--
--  3. Coach identity was resolved two different ways that disagreed:
--       my_coach_role() / is_active_coach()  -> JWT email
--       is_head_coach() + EVERY table write  -> coaches.user_id
--     `coaches.user_id` is only populated by linkCoachUserID() after sign-in,
--     and 8 of 11 coach rows had it null. So a coach could be recognised for
--     role display and simultaneously rejected on every write: publishing
--     workouts, announcements, drill edits, coach notes, progress reports,
--     team events, XP grants and Control Center actions.
--
--  APPROACH: additive. No policy was dropped. Permissive policies are OR'd, so
--  the pre-existing user_id-based policies still apply and nobody lost access.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. One identity rule: match a coach on the JWT email OR coaches.user_id.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.my_coach_role()
RETURNS text
LANGUAGE sql
STABLE SECURITY DEFINER
SET search_path TO 'public'
AS $function$
  select c.role
  from public.coaches c
  where c.is_active = true
    and (
      lower(c.email) = lower(
        coalesce(nullif(current_setting('request.jwt.claims', true)::json ->> 'email',''), '')
      )
      or (c.user_id is not null and c.user_id = public.user_id())
    )
  order by case c.role when 'head_coach' then 0 else 1 end
  limit 1;
$function$;

-- is_head_coach() was user_id-only; align it with my_coach_role().
CREATE OR REPLACE FUNCTION public.is_head_coach()
RETURNS boolean
LANGUAGE sql
STABLE SECURITY DEFINER
SET search_path TO 'public'
AS $function$
  select public.my_coach_role() = 'head_coach';
$function$;

-- -----------------------------------------------------------------------------
-- 2. THE BLOCKER: SELECT policies so upsert can resolve.
-- -----------------------------------------------------------------------------
DROP POLICY IF EXISTS "drill_media_authenticated_select" ON storage.objects;
CREATE POLICY "drill_media_authenticated_select" ON storage.objects
  FOR SELECT TO authenticated
  USING (bucket_id = ANY (ARRAY['drill-videos'::text, 'drill-images'::text]));

DROP POLICY IF EXISTS "player_media_owner_select" ON storage.objects;
CREATE POLICY "player_media_owner_select" ON storage.objects
  FOR SELECT TO authenticated
  USING (bucket_id = 'player-media' AND (storage.foldername(name))[1] = public.user_id());

DROP POLICY IF EXISTS "avatars_authenticated_select" ON storage.objects;
CREATE POLICY "avatars_authenticated_select" ON storage.objects
  FOR SELECT TO authenticated USING (bucket_id = 'avatars');

DROP POLICY IF EXISTS "avatars_owner_write" ON storage.objects;
CREATE POLICY "avatars_owner_write" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'avatars' AND (storage.foldername(name))[1] = public.user_id());

DROP POLICY IF EXISTS "avatars_owner_update" ON storage.objects;
CREATE POLICY "avatars_owner_update" ON storage.objects
  FOR UPDATE TO authenticated
  USING (bucket_id = 'avatars' AND (storage.foldername(name))[1] = public.user_id())
  WITH CHECK (bucket_id = 'avatars' AND (storage.foldername(name))[1] = public.user_id());

-- -----------------------------------------------------------------------------
-- 3. drill-images gets the same email-based coach policies drill-videos had.
-- -----------------------------------------------------------------------------
DROP POLICY IF EXISTS "drill_images_coach_insert" ON storage.objects;
CREATE POLICY "drill_images_coach_insert" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'drill-images' AND public.is_active_coach());

DROP POLICY IF EXISTS "drill_images_coach_update" ON storage.objects;
CREATE POLICY "drill_images_coach_update" ON storage.objects
  FOR UPDATE TO authenticated
  USING (bucket_id = 'drill-images' AND public.is_active_coach())
  WITH CHECK (bucket_id = 'drill-images' AND public.is_active_coach());

DROP POLICY IF EXISTS "drill_images_coach_delete" ON storage.objects;
CREATE POLICY "drill_images_coach_delete" ON storage.objects
  FOR DELETE TO authenticated
  USING (bucket_id = 'drill-images' AND public.is_active_coach());

-- -----------------------------------------------------------------------------
-- 4. Coach + head-coach write policies that work on either identity.
-- -----------------------------------------------------------------------------
DROP POLICY IF EXISTS "announcements_coach_write_v2" ON announcements;
CREATE POLICY "announcements_coach_write_v2" ON announcements
  FOR ALL TO authenticated USING (public.is_active_coach()) WITH CHECK (public.is_active_coach());

DROP POLICY IF EXISTS "coach_workouts_coach_write_v2" ON coach_workouts;
CREATE POLICY "coach_workouts_coach_write_v2" ON coach_workouts
  FOR ALL TO authenticated USING (public.is_active_coach()) WITH CHECK (public.is_active_coach());

DROP POLICY IF EXISTS "curriculum_edits_coach_write_v2" ON curriculum_edits;
CREATE POLICY "curriculum_edits_coach_write_v2" ON curriculum_edits
  FOR ALL TO authenticated USING (public.is_active_coach()) WITH CHECK (public.is_active_coach());

DROP POLICY IF EXISTS "coach_notes_coach_write_v2" ON coach_notes;
CREATE POLICY "coach_notes_coach_write_v2" ON coach_notes
  FOR ALL TO authenticated USING (public.is_active_coach()) WITH CHECK (public.is_active_coach());

DROP POLICY IF EXISTS "progress_reports_coach_all_v2" ON progress_reports;
CREATE POLICY "progress_reports_coach_all_v2" ON progress_reports
  FOR ALL TO authenticated USING (public.is_active_coach()) WITH CHECK (public.is_active_coach());

DROP POLICY IF EXISTS "team_events_coach_write_v2" ON team_events;
CREATE POLICY "team_events_coach_write_v2" ON team_events
  FOR ALL TO authenticated USING (public.is_active_coach()) WITH CHECK (public.is_active_coach());

DROP POLICY IF EXISTS "team_members_coach_all_v2" ON team_members;
CREATE POLICY "team_members_coach_all_v2" ON team_members
  FOR ALL TO authenticated USING (public.is_active_coach()) WITH CHECK (public.is_active_coach());

DROP POLICY IF EXISTS "coach_evaluations_coach_all_v2" ON coach_evaluations;
CREATE POLICY "coach_evaluations_coach_all_v2" ON coach_evaluations
  FOR ALL TO authenticated USING (public.is_active_coach()) WITH CHECK (public.is_active_coach());

DROP POLICY IF EXISTS "teams_coach_select_v2" ON teams;
CREATE POLICY "teams_coach_select_v2" ON teams
  FOR SELECT TO authenticated USING (public.is_active_coach());

DROP POLICY IF EXISTS "teams_coach_insert_v2" ON teams;
CREATE POLICY "teams_coach_insert_v2" ON teams
  FOR INSERT TO authenticated
  WITH CHECK (public.is_active_coach() AND created_by = public.user_id());

DROP POLICY IF EXISTS "teams_owner_or_head_update_v2" ON teams;
CREATE POLICY "teams_owner_or_head_update_v2" ON teams
  FOR UPDATE TO authenticated
  USING (created_by = public.user_id() OR public.is_head_coach())
  WITH CHECK (created_by = public.user_id() OR public.is_head_coach());

DROP POLICY IF EXISTS "teams_owner_or_head_delete_v2" ON teams;
CREATE POLICY "teams_owner_or_head_delete_v2" ON teams
  FOR DELETE TO authenticated
  USING (created_by = public.user_id() OR public.is_head_coach());

-- Head-coach only: XP grants / streak fixes, app config, audit log, content.
DROP POLICY IF EXISTS "support_adjustments_head_all_v2" ON support_adjustments;
CREATE POLICY "support_adjustments_head_all_v2" ON support_adjustments
  FOR ALL TO authenticated USING (public.is_head_coach()) WITH CHECK (public.is_head_coach());

DROP POLICY IF EXISTS "app_config_head_write_v2" ON app_config;
CREATE POLICY "app_config_head_write_v2" ON app_config
  FOR ALL TO authenticated USING (public.is_head_coach()) WITH CHECK (public.is_head_coach());

DROP POLICY IF EXISTS "admin_audit_head_all_v2" ON admin_audit;
CREATE POLICY "admin_audit_head_all_v2" ON admin_audit
  FOR ALL TO authenticated USING (public.is_head_coach()) WITH CHECK (public.is_head_coach());

DROP POLICY IF EXISTS "content_overrides_head_write_v2" ON content_overrides;
CREATE POLICY "content_overrides_head_write_v2" ON content_overrides
  FOR ALL TO authenticated USING (public.is_head_coach()) WITH CHECK (public.is_head_coach());

-- -----------------------------------------------------------------------------
-- 5. Keep coaches.user_id populated so both identity paths agree going forward.
-- -----------------------------------------------------------------------------
UPDATE coaches c
SET user_id = u.id::text
FROM auth.users u
WHERE c.user_id IS NULL AND lower(u.email) = lower(c.email);

-- =============================================================================
--  VERIFIED AFTER APPLYING
--
--  Every coach resolves, including those with no auth account yet:
--    josephmcgee36@gmail.com     head_coach  coach:t  head:t
--    matteo.m.finazzi@gmail.com  head_coach  coach:t  head:t
--    mf.elitetraining@gmail.com  head_coach  coach:t  head:t
--    appreview@mfelite.app       coach       coach:t  head:f
--    suemcgee83@gmail.com        coach       coach:t  head:f
--
--  A real INSERT into storage.objects ('drill-images') and into
--  curriculum_edits, executed as role `authenticated` with Joe's JWT claims,
--  both passed RLS. Rolled back; zero rows left behind.
--
--  OPTIONAL CLEANUP (not done — would drop policies):
--  the original user_id-based policies are now redundant. They can be dropped
--  once the v2 policies have been exercised in production for a while:
--    "drill media coach write" / "drill media coach update" / "drill media coach delete"
--    announcements_coach_write, coach_workouts_coach_write, curriculum_edits_coach_write,
--    coach_notes_coach_write, progress_reports_coach_all, team_events_coach_write,
--    team_members_coach_all, support_adjustments_head_all, app_config_head_write,
--    admin_audit_head_all, teams_coach_select/insert, teams_owner_or_head_update/delete
-- =============================================================================
