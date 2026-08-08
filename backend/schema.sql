-- =============================================================================
--  MF Elite — public schema, dumped from production 2026-08-08
--
--  This file is generated from the live database (project twzukrzcfquxfmrnffze),
--  not hand-maintained. Regenerate it rather than editing it by hand.
--
--  The version this replaces declared 17 tables. The app reads or writes 41.
--  That gap was not cosmetic: the sync engine treats a 4xx as a PERMANENT
--  failure and quarantines the operation, so a write to a column that does not
--  exist never crashes, never retries, and never arrives — the player's data
--  just silently stops syncing. Anyone provisioning a new project from the old
--  file got an app that looked fine and lost most of what a player did.
--
--  Ordering note: this is emitted table-by-table (columns, constraints,
--  indexes, RLS, policies), alphabetically, so foreign keys can reference a
--  table defined later in the file. It is a faithful record of what is live,
--  not a script that will run top-to-bottom on an empty database. To rebuild
--  from scratch, create all the tables first, then apply the constraints.
--
--  Auth: `profiles.id` mirrors `auth.users.id`. `user_id()` reads the JWT
--  `sub` claim; `my_coach_role()` resolves a coach by JWT email OR user_id,
--  which is why several policies exist in both a legacy and a `_v2` form —
--  8 of the 11 coach rows have no `user_id` because those people have never
--  signed in.
-- =============================================================================

create table if not exists admin_audit (
  id uuid default gen_random_uuid() not null,
  actor text not null,
  action text not null,
  detail jsonb default '{}'::jsonb not null,
  created_at timestamp with time zone default now() not null
);
alter table admin_audit add constraint admin_audit_pkey PRIMARY KEY (id);
alter table admin_audit enable row level security;
create policy admin_audit_head_all on admin_audit for all to public using ((user_id() IN ( SELECT coaches.user_id
   FROM coaches
  WHERE ((coaches.is_active = true) AND (coaches.role = 'head_coach'::text))))) with check ((user_id() IN ( SELECT coaches.user_id
   FROM coaches
  WHERE ((coaches.is_active = true) AND (coaches.role = 'head_coach'::text)))));
create policy admin_audit_head_all_v2 on admin_audit for all to authenticated using (is_head_coach()) with check (is_head_coach());

create table if not exists announcements (
  id uuid default gen_random_uuid() not null,
  title text not null,
  body text,
  active boolean default true not null,
  created_at timestamp with time zone default now(),
  audience text default 'everyone'::text not null,
  target_team_ids text[] default '{}'::text[] not null,
  target_player_ids text[] default '{}'::text[] not null
);
alter table announcements add constraint announcements_pkey PRIMARY KEY (id);
alter table announcements enable row level security;
create policy announcements_coach_write on announcements for all to public using ((user_id() IN ( SELECT coaches.user_id
   FROM coaches
  WHERE (coaches.is_active = true)))) with check ((user_id() IN ( SELECT coaches.user_id
   FROM coaches
  WHERE (coaches.is_active = true))));
create policy announcements_coach_write_v2 on announcements for all to authenticated using (is_active_coach()) with check (is_active_coach());
create policy announcements_select_auth on announcements for select to public using (((auth.jwt() ->> 'role'::text) = 'authenticated'::text));

create table if not exists app_config (
  key text not null,
  value jsonb not null,
  updated_by text,
  updated_at timestamp with time zone default now() not null
);
alter table app_config add constraint app_config_pkey PRIMARY KEY (key);
alter table app_config enable row level security;
create policy app_config_head_write on app_config for all to public using ((user_id() IN ( SELECT coaches.user_id
   FROM coaches
  WHERE ((coaches.is_active = true) AND (coaches.role = 'head_coach'::text))))) with check ((user_id() IN ( SELECT coaches.user_id
   FROM coaches
  WHERE ((coaches.is_active = true) AND (coaches.role = 'head_coach'::text)))));
create policy app_config_head_write_v2 on app_config for all to authenticated using (is_head_coach()) with check (is_head_coach());
create policy app_config_read on app_config for select to public using (true);

create table if not exists categories (
  id uuid default gen_random_uuid() not null,
  discipline_id uuid not null,
  letter text not null,
  name text not null,
  focus text,
  cert_name text,
  sort_index integer default 0 not null
);
alter table categories add constraint categories_discipline_id_fkey FOREIGN KEY (discipline_id) REFERENCES disciplines(id) ON DELETE CASCADE;
alter table categories add constraint categories_pkey PRIMARY KEY (id);
alter table categories enable row level security;
create policy categories_coach_write on categories for all to public using ((user_id() IN ( SELECT coaches.user_id
   FROM coaches
  WHERE (coaches.is_active = true)))) with check ((user_id() IN ( SELECT coaches.user_id
   FROM coaches
  WHERE (coaches.is_active = true))));
create policy categories_select_auth on categories for select to public using (((auth.jwt() ->> 'role'::text) = 'authenticated'::text));

create table if not exists certifications (
  id uuid default gen_random_uuid() not null,
  player_id text not null,
  category_id uuid not null,
  earned_at timestamp with time zone default now(),
  coach_signed boolean default false not null
);
alter table certifications add constraint certifications_category_id_fkey FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE CASCADE;
alter table certifications add constraint certifications_pkey PRIMARY KEY (id);
alter table certifications add constraint certifications_player_id_category_id_key UNIQUE (player_id, category_id);
alter table certifications add constraint certifications_player_id_fkey FOREIGN KEY (player_id) REFERENCES profiles(id);
alter table certifications enable row level security;
create policy certifications_delete_own on certifications for delete to public using ((user_id() = player_id));
create policy certifications_insert_own on certifications for insert to public with check ((user_id() = player_id));
create policy certifications_select on certifications for select to public using (((user_id() = player_id) OR (user_id() IN ( SELECT coaches.user_id
   FROM coaches
  WHERE (coaches.is_active = true)))));

create table if not exists coach_evaluations (
  id uuid default gen_random_uuid() not null,
  player_id text not null,
  coach_id text not null,
  coach_name text,
  eval_date date default CURRENT_DATE not null,
  setting text default 'in_person'::text not null,
  position_played text,
  ratings jsonb default '{}'::jsonb not null,
  strengths text,
  improvements text,
  focus_drill_ids jsonb default '[]'::jsonb not null,
  notes text,
  shared_with_player boolean default false not null,
  created_at timestamp with time zone default now(),
  updated_at timestamp with time zone default now()
);
alter table coach_evaluations add constraint coach_evaluations_pkey PRIMARY KEY (id);
CREATE INDEX coach_evaluations_player ON public.coach_evaluations USING btree (player_id, eval_date DESC);
alter table coach_evaluations enable row level security;
create policy coach_evaluations_coach_all on coach_evaluations for all to public using ((user_id() IN ( SELECT coaches.user_id
   FROM coaches
  WHERE (coaches.is_active = true)))) with check ((user_id() IN ( SELECT coaches.user_id
   FROM coaches
  WHERE (coaches.is_active = true))));
create policy coach_evaluations_coach_all_v2 on coach_evaluations for all to authenticated using (is_active_coach()) with check (is_active_coach());
create policy coach_evaluations_player_read on coach_evaluations for select to public using (((shared_with_player = true) AND (player_id IN ( SELECT player_profiles.id
   FROM player_profiles
  WHERE (player_profiles.account_id = user_id())))));

create table if not exists coach_notes (
  id uuid default gen_random_uuid() not null,
  month text not null,
  body text default ''::text not null,
  updated_at timestamp with time zone default now()
);
alter table coach_notes add constraint coach_notes_month_key UNIQUE (month);
alter table coach_notes add constraint coach_notes_pkey PRIMARY KEY (id);
alter table coach_notes enable row level security;
create policy coach_notes_coach_write on coach_notes for all to public using ((user_id() IN ( SELECT coaches.user_id
   FROM coaches
  WHERE (coaches.is_active = true)))) with check ((user_id() IN ( SELECT coaches.user_id
   FROM coaches
  WHERE (coaches.is_active = true))));
create policy coach_notes_coach_write_v2 on coach_notes for all to authenticated using (is_active_coach()) with check (is_active_coach());
create policy coach_notes_select_auth on coach_notes for select to public using (((auth.jwt() ->> 'role'::text) = 'authenticated'::text));

create table if not exists coach_players (
  id uuid default gen_random_uuid() not null,
  coach_email text not null,
  player_id text not null,
  created_at timestamp with time zone default now() not null
);
alter table coach_players add constraint coach_players_coach_email_player_id_key UNIQUE (coach_email, player_id);
alter table coach_players add constraint coach_players_pkey PRIMARY KEY (id);
CREATE INDEX coach_players_email_idx ON public.coach_players USING btree (lower(coach_email));
CREATE INDEX coach_players_player_idx ON public.coach_players USING btree (player_id);
alter table coach_players enable row level security;
create policy coach_players_select on coach_players for select to public using (((user_id() = player_id) OR (lower(coach_email) = lower(COALESCE(NULLIF(((current_setting('request.jwt.claims'::text, true))::json ->> 'email'::text), ''::text), ''::text))) OR is_head_coach()));
create policy coach_players_write on coach_players for all to public using (is_head_coach()) with check (is_head_coach());

create table if not exists coach_workouts (
  id uuid default gen_random_uuid() not null,
  title text not null,
  coach_name text default 'Coach Finazzi'::text not null,
  note text,
  drill_ids jsonb default '[]'::jsonb not null,
  posted_at timestamp with time zone default now() not null,
  active boolean default true not null,
  created_by text,
  created_at timestamp with time zone default now() not null,
  audience text default 'everyone'::text not null,
  target_team_ids text[] default '{}'::text[] not null,
  target_player_ids text[] default '{}'::text[] not null
);
alter table coach_workouts add constraint coach_workouts_pkey PRIMARY KEY (id);
CREATE INDEX coach_workouts_recent ON public.coach_workouts USING btree (active, posted_at DESC);
alter table coach_workouts enable row level security;
create policy coach_workouts_coach_write on coach_workouts for all to public using ((user_id() IN ( SELECT coaches.user_id
   FROM coaches
  WHERE (coaches.is_active = true)))) with check ((user_id() IN ( SELECT coaches.user_id
   FROM coaches
  WHERE (coaches.is_active = true))));
create policy coach_workouts_coach_write_v2 on coach_workouts for all to authenticated using (is_active_coach()) with check (is_active_coach());
create policy coach_workouts_select_auth on coach_workouts for select to public using (((auth.jwt() ->> 'role'::text) = 'authenticated'::text));

create table if not exists coaches (
  id uuid default gen_random_uuid() not null,
  email text not null,
  display_name text,
  role text default 'coach'::text not null,
  user_id text,
  is_active boolean default true not null,
  created_at timestamp with time zone default now()
);
alter table coaches add constraint coaches_email_key UNIQUE (email);
alter table coaches add constraint coaches_pkey PRIMARY KEY (id);
alter table coaches add constraint coaches_user_id_fkey FOREIGN KEY (user_id) REFERENCES profiles(id);
alter table coaches enable row level security;
create policy coaches_head_manage on coaches for all to authenticated using (is_head_coach()) with check (is_head_coach());
create policy coaches_select_authenticated on coaches for select to authenticated using (true);
create policy coaches_self_link on coaches for update to public using ((lower(email) = lower((auth.jwt() ->> 'email'::text)))) with check ((lower(email) = lower((auth.jwt() ->> 'email'::text))));

create table if not exists combine_results (
  id uuid not null,
  user_id text not null,
  test_id text not null,
  value double precision not null,
  recorded_at timestamp with time zone not null,
  created_at timestamp with time zone default now()
);
alter table combine_results add constraint combine_results_pkey PRIMARY KEY (id);
CREATE INDEX combine_results_user_test ON public.combine_results USING btree (user_id, test_id, recorded_at DESC);
alter table combine_results enable row level security;
create policy combine_results_own on combine_results for all to public using ((user_id() = user_id)) with check ((user_id() = user_id));
create policy combine_results_select_coach on combine_results for select to public using ((user_id() IN ( SELECT coaches.user_id
   FROM coaches
  WHERE (coaches.is_active = true))));

create table if not exists content_overrides (
  kind text not null,
  target_id text not null,
  name text not null,
  updated_by text,
  updated_at timestamp with time zone default now() not null
);
alter table content_overrides add constraint content_overrides_kind_check CHECK ((kind = ANY (ARRAY['discipline'::text, 'category'::text, 'level'::text, 'drill'::text, 'rank'::text, 'certification'::text, 'combine_test'::text])));
alter table content_overrides add constraint content_overrides_pkey PRIMARY KEY (kind, target_id);
alter table content_overrides enable row level security;
create policy content_overrides_head_write on content_overrides for all to public using ((user_id() IN ( SELECT coaches.user_id
   FROM coaches
  WHERE ((coaches.is_active = true) AND (coaches.role = 'head_coach'::text))))) with check ((user_id() IN ( SELECT coaches.user_id
   FROM coaches
  WHERE ((coaches.is_active = true) AND (coaches.role = 'head_coach'::text)))));
create policy content_overrides_head_write_v2 on content_overrides for all to authenticated using (is_head_coach()) with check (is_head_coach());
create policy content_overrides_read on content_overrides for select to public using (true);

create table if not exists curriculum_edits (
  drill_id text not null,
  kind text default 'edit'::text not null,
  payload jsonb default '{}'::jsonb not null,
  category_id text,
  level_number integer,
  active boolean default true not null,
  updated_at timestamp with time zone default now() not null,
  updated_by text
);
alter table curriculum_edits add constraint curriculum_edits_pkey PRIMARY KEY (drill_id);
alter table curriculum_edits enable row level security;
create policy curriculum_edits_coach_write on curriculum_edits for all to public using ((user_id() IN ( SELECT coaches.user_id
   FROM coaches
  WHERE (coaches.is_active = true)))) with check ((user_id() IN ( SELECT coaches.user_id
   FROM coaches
  WHERE (coaches.is_active = true))));
create policy curriculum_edits_coach_write_v2 on curriculum_edits for all to authenticated using (is_active_coach()) with check (is_active_coach());
create policy curriculum_edits_select_auth on curriculum_edits for select to public using (((auth.jwt() ->> 'role'::text) = 'authenticated'::text));

create table if not exists custom_workouts (
  id uuid not null,
  user_id text not null,
  name text not null,
  drill_ids jsonb default '[]'::jsonb not null,
  is_shared_import boolean default false not null,
  created_at timestamp with time zone default now(),
  updated_at timestamp with time zone default now()
);
alter table custom_workouts add constraint custom_workouts_pkey PRIMARY KEY (id);
alter table custom_workouts enable row level security;
create policy custom_workouts_own on custom_workouts for all to public using ((user_id() = user_id)) with check ((user_id() = user_id));

create table if not exists daily_quotes (
  id uuid default gen_random_uuid() not null,
  quote text not null,
  sort_index integer default 0 not null,
  active boolean default true not null
);
alter table daily_quotes add constraint daily_quotes_pkey PRIMARY KEY (id);
alter table daily_quotes enable row level security;
create policy quotes_coach_write on daily_quotes for all to public using ((user_id() IN ( SELECT coaches.user_id
   FROM coaches
  WHERE (coaches.is_active = true)))) with check ((user_id() IN ( SELECT coaches.user_id
   FROM coaches
  WHERE (coaches.is_active = true))));
create policy quotes_select_auth on daily_quotes for select to public using (((auth.jwt() ->> 'role'::text) = 'authenticated'::text));

create table if not exists disciplines (
  id uuid default gen_random_uuid() not null,
  number text not null,
  name text not null,
  mark text not null,
  tagline text,
  blurb text,
  media text,
  sort_index integer default 0 not null,
  created_at timestamp with time zone default now()
);
alter table disciplines add constraint disciplines_pkey PRIMARY KEY (id);
alter table disciplines enable row level security;
create policy disciplines_coach_write on disciplines for all to public using ((user_id() IN ( SELECT coaches.user_id
   FROM coaches
  WHERE (coaches.is_active = true)))) with check ((user_id() IN ( SELECT coaches.user_id
   FROM coaches
  WHERE (coaches.is_active = true))));
create policy disciplines_select_auth on disciplines for select to public using (((auth.jwt() ->> 'role'::text) = 'authenticated'::text));

create table if not exists drill_notes (
  user_id text not null,
  drill_id text not null,
  text text not null,
  updated_at timestamp with time zone not null
);
alter table drill_notes add constraint drill_notes_pkey PRIMARY KEY (user_id, drill_id);
alter table drill_notes enable row level security;
create policy drill_notes_own on drill_notes for all to public using ((user_id() = user_id)) with check ((user_id() = user_id));

create table if not exists drill_results (
  id uuid not null,
  user_id text not null,
  drill_id text not null,
  value double precision not null,
  unit text default ''::text not null,
  recorded_at timestamp with time zone default now() not null
);
alter table drill_results add constraint drill_results_pkey PRIMARY KEY (id);
CREATE INDEX drill_results_user_drill ON public.drill_results USING btree (user_id, drill_id);
alter table drill_results enable row level security;
create policy drill_results_own on drill_results for all to public using ((user_id = user_id())) with check ((user_id = user_id()));

create table if not exists drills (
  id uuid default gen_random_uuid() not null,
  level_id uuid not null,
  title text not null,
  focus text,
  how text,
  video_url text,
  duration_sec integer default 0 not null,
  sets integer default 1 not null,
  coaching_points jsonb default '[]'::jsonb not null,
  sort_index integer default 0 not null
);
alter table drills add constraint drills_level_id_fkey FOREIGN KEY (level_id) REFERENCES levels(id) ON DELETE CASCADE;
alter table drills add constraint drills_pkey PRIMARY KEY (id);
alter table drills enable row level security;
create policy drills_coach_write on drills for all to public using ((user_id() IN ( SELECT coaches.user_id
   FROM coaches
  WHERE (coaches.is_active = true)))) with check ((user_id() IN ( SELECT coaches.user_id
   FROM coaches
  WHERE (coaches.is_active = true))));
create policy drills_select_auth on drills for select to public using (((auth.jwt() ->> 'role'::text) = 'authenticated'::text));

create table if not exists families (
  id uuid default gen_random_uuid() not null,
  owner_id text not null,
  name text,
  created_at timestamp with time zone default now()
);
alter table families add constraint families_owner_id_fkey FOREIGN KEY (owner_id) REFERENCES profiles(id);
alter table families add constraint families_pkey PRIMARY KEY (id);
alter table families enable row level security;
create policy families_delete_own on families for delete to public using ((user_id() = owner_id));
create policy families_insert_own on families for insert to public with check ((user_id() = owner_id));
create policy families_select_own on families for select to public using ((user_id() = owner_id));
create policy families_update_own on families for update to public using ((user_id() = owner_id)) with check ((user_id() = owner_id));

create table if not exists game_entries (
  id uuid not null,
  user_id text not null,
  game_date timestamp with time zone not null,
  opponent text default ''::text not null,
  created_at timestamp with time zone default now() not null
);
alter table game_entries add constraint game_entries_pkey PRIMARY KEY (id);
alter table game_entries enable row level security;
create policy game_entries_own on game_entries for all to public using ((user_id = user_id())) with check ((user_id = user_id()));

create table if not exists gameiq_completions (
  user_id text not null,
  lesson_id text not null,
  completed_at timestamp with time zone not null
);
alter table gameiq_completions add constraint gameiq_completions_pkey PRIMARY KEY (user_id, lesson_id);
alter table gameiq_completions enable row level security;
create policy gameiq_completions_own on gameiq_completions for all to public using ((user_id() = user_id)) with check ((user_id() = user_id));
create policy gameiq_completions_select_coach on gameiq_completions for select to public using ((user_id() IN ( SELECT coaches.user_id
   FROM coaches
  WHERE (coaches.is_active = true))));

create table if not exists levels (
  id uuid default gen_random_uuid() not null,
  category_id uuid not null,
  number integer not null,
  name text not null,
  theme text,
  sort_index integer default 0 not null
);
alter table levels add constraint levels_category_id_fkey FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE CASCADE;
alter table levels add constraint levels_pkey PRIMARY KEY (id);
alter table levels enable row level security;
create policy levels_coach_write on levels for all to public using ((user_id() IN ( SELECT coaches.user_id
   FROM coaches
  WHERE (coaches.is_active = true)))) with check ((user_id() IN ( SELECT coaches.user_id
   FROM coaches
  WHERE (coaches.is_active = true))));
create policy levels_select_auth on levels for select to public using (((auth.jwt() ->> 'role'::text) = 'authenticated'::text));

create table if not exists member_counter (
  id boolean default true not null,
  value integer default 0 not null
);
alter table member_counter add constraint member_counter_pkey PRIMARY KEY (id);
alter table member_counter add constraint member_counter_singleton CHECK (id);
alter table member_counter enable row level security;

create table if not exists player_profiles (
  id text not null,
  display_name text,
  initials text,
  kit_number text,
  "position" text,
  created_at timestamp with time zone default now(),
  username text,
  account_id text,
  managed boolean default false not null,
  is_example boolean default false not null,
  pledge_tier text,
  foot text,
  member_number integer,
  class_year integer,
  family_id uuid,
  ballon_dor_requested_at timestamp with time zone,
  ballon_dor_approved boolean default false not null,
  ballon_dor_approved_at timestamp with time zone,
  ballon_dor_approved_by text,
  training_level text,
  gender text,
  position_code text,
  birth_year integer,
  avatar_kind text,
  avatar_builtin text,
  avatar_url text,
  card_design jsonb,
  card_bg_url text,
  coach_focus text
);
alter table player_profiles add constraint player_profiles_account_id_fkey FOREIGN KEY (account_id) REFERENCES profiles(id);
alter table player_profiles add constraint player_profiles_family_id_fkey FOREIGN KEY (family_id) REFERENCES families(id) ON DELETE SET NULL;
alter table player_profiles add constraint player_profiles_pkey PRIMARY KEY (id);
CREATE UNIQUE INDEX player_profiles_username_unique ON public.player_profiles USING btree (lower(username)) WHERE ((is_example = false) AND (username IS NOT NULL));
alter table player_profiles enable row level security;
create policy player_profiles_delete_own on player_profiles for delete to public using ((user_id() = account_id));
create policy player_profiles_insert_own on player_profiles for insert to public with check (((user_id() = account_id) OR (user_id() IN ( SELECT coaches.user_id
   FROM coaches
  WHERE (coaches.is_active = true)))));
create policy player_profiles_select on player_profiles for select to public using (can_read_player(account_id));
create policy player_profiles_update on player_profiles for update to public using (can_read_player(account_id)) with check (can_read_player(account_id));

create table if not exists player_progress (
  id uuid default gen_random_uuid() not null,
  player_id text not null,
  drill_id uuid not null,
  passes_logged integer default 0 not null,
  is_mastered boolean default false not null,
  last_logged_at timestamp with time zone
);
alter table player_progress add constraint player_progress_pkey PRIMARY KEY (id);
alter table player_progress add constraint player_progress_player_id_drill_id_key UNIQUE (player_id, drill_id);
alter table player_progress add constraint player_progress_player_id_fkey FOREIGN KEY (player_id) REFERENCES profiles(id);
alter table player_progress enable row level security;
create policy player_progress_delete_own on player_progress for delete to public using ((user_id() = player_id));
create policy player_progress_insert_own on player_progress for insert to public with check ((user_id() = player_id));
create policy player_progress_select on player_progress for select to public using (can_read_player(player_id));
create policy player_progress_update_own on player_progress for update to public using ((user_id() = player_id)) with check ((user_id() = player_id));

create table if not exists player_state (
  id uuid default gen_random_uuid() not null,
  player_id text not null,
  xp integer default 0 not null,
  streak integer default 0 not null,
  freezes_remaining integer default 0 not null,
  last_trained_date date,
  streak_pb integer default 0 not null,
  purchased_xp bigint default 0 not null,
  drills_completed integer default 0 not null
);
alter table player_state add constraint player_state_pkey PRIMARY KEY (id);
alter table player_state add constraint player_state_player_id_fkey FOREIGN KEY (player_id) REFERENCES profiles(id);
alter table player_state add constraint player_state_player_id_key UNIQUE (player_id);
alter table player_state enable row level security;
create policy player_state_delete_own on player_state for delete to public using ((user_id() = player_id));
create policy player_state_insert_own on player_state for insert to public with check ((user_id() = player_id));
create policy player_state_select on player_state for select to public using (can_read_player(player_id));
create policy player_state_update_own on player_state for update to public using ((user_id() = player_id)) with check ((user_id() = player_id));

create table if not exists profiles (
  id text not null,
  email text,
  name text,
  avatar_url text,
  created_at timestamp with time zone default now(),
  updated_at timestamp with time zone default now()
);
alter table profiles add constraint profiles_pkey PRIMARY KEY (id);
alter table profiles enable row level security;
create policy profiles_insert_own on profiles for insert to public with check ((user_id() = id));
create policy profiles_select_coach on profiles for select to public using ((user_id() IN ( SELECT coaches.user_id
   FROM coaches
  WHERE (coaches.is_active = true))));
create policy profiles_select_own on profiles for select to public using ((user_id() = id));
create policy profiles_update_own on profiles for update to public using ((user_id() = id)) with check ((user_id() = id));

create table if not exists progress_reports (
  id uuid default gen_random_uuid() not null,
  player_user_id text not null,
  coach_user_id text not null,
  period text not null,
  status text default 'draft'::text not null,
  sections jsonb default '[]'::jsonb not null,
  updated_at timestamp with time zone default now() not null,
  created_at timestamp with time zone default now() not null
);
alter table progress_reports add constraint progress_reports_pkey PRIMARY KEY (id);
alter table progress_reports add constraint progress_reports_status_check CHECK ((status = ANY (ARRAY['draft'::text, 'final'::text])));
alter table progress_reports enable row level security;
create policy progress_reports_coach_all on progress_reports for all to public using ((user_id() IN ( SELECT coaches.user_id
   FROM coaches
  WHERE (coaches.is_active = true)))) with check ((user_id() IN ( SELECT coaches.user_id
   FROM coaches
  WHERE (coaches.is_active = true))));
create policy progress_reports_coach_all_v2 on progress_reports for all to authenticated using (is_active_coach()) with check (is_active_coach());
create policy progress_reports_player_read on progress_reports for select to public using (((player_user_id = user_id()) AND (status = 'final'::text)));

create table if not exists progression_rules (
  id uuid default gen_random_uuid() not null,
  xp_per_drill integer default 25 not null,
  xp_level_bonus integer default 120 not null,
  xp_category_cert integer default 400 not null,
  xp_discipline_diploma integer default 1500 not null,
  free_levels integer default 1 not null,
  mastery_passes integer default 3 not null
);
alter table progression_rules add constraint progression_rules_pkey PRIMARY KEY (id);
alter table progression_rules enable row level security;
create policy rules_coach_write on progression_rules for all to public using ((user_id() IN ( SELECT coaches.user_id
   FROM coaches
  WHERE (coaches.is_active = true)))) with check ((user_id() IN ( SELECT coaches.user_id
   FROM coaches
  WHERE (coaches.is_active = true))));
create policy rules_select_auth on progression_rules for select to public using (((auth.jwt() ->> 'role'::text) = 'authenticated'::text));

create table if not exists roster_invites (
  id uuid default gen_random_uuid() not null,
  code text not null,
  coach_id text not null,
  display_name text,
  kit_number text,
  "position" text,
  status text default 'pending'::text not null,
  claimed_by text,
  player_id text,
  created_at timestamp with time zone default now(),
  claimed_at timestamp with time zone
);
alter table roster_invites add constraint roster_invites_claimed_by_fkey FOREIGN KEY (claimed_by) REFERENCES profiles(id);
alter table roster_invites add constraint roster_invites_coach_id_fkey FOREIGN KEY (coach_id) REFERENCES profiles(id);
alter table roster_invites add constraint roster_invites_code_key UNIQUE (code);
alter table roster_invites add constraint roster_invites_pkey PRIMARY KEY (id);
alter table roster_invites enable row level security;
create policy roster_invites_coach_all on roster_invites for all to public using (((user_id() = coach_id) AND (user_id() IN ( SELECT coaches.user_id
   FROM coaches
  WHERE (coaches.is_active = true))))) with check (((user_id() = coach_id) AND (user_id() IN ( SELECT coaches.user_id
   FROM coaches
  WHERE (coaches.is_active = true)))));
create policy roster_invites_select_claimer on roster_invites for select to public using ((user_id() = claimed_by));

create table if not exists session_logs (
  id uuid not null,
  user_id text not null,
  completed_at timestamp with time zone not null,
  drill_id text not null,
  drill_title text not null,
  discipline_id text not null,
  discipline_name text not null,
  category_id text not null,
  category_name text not null,
  level_number integer not null,
  duration_sec integer not null,
  sets_completed integer not null,
  sets_skipped integer default 0 not null,
  completed_fully boolean default true not null,
  source text default 'single'::text not null,
  source_name text,
  xp_earned integer default 0 not null,
  felt_rating integer,
  reflection text,
  journal_response text,
  created_at timestamp with time zone default now(),
  steps integer,
  movement_intensity double precision
);
alter table session_logs add constraint session_logs_pkey PRIMARY KEY (id);
CREATE INDEX session_logs_user_time ON public.session_logs USING btree (user_id, completed_at DESC);
alter table session_logs enable row level security;
create policy session_logs_own on session_logs for all to public using ((user_id() = user_id)) with check ((user_id() = user_id));
create policy session_logs_select_coach on session_logs for select to public using ((user_id() IN ( SELECT coaches.user_id
   FROM coaches
  WHERE (coaches.is_active = true))));

create table if not exists share_xp_events (
  user_id text not null,
  day date not null,
  platform text not null,
  card_kind text not null,
  xp integer default 5 not null,
  created_at timestamp with time zone default now() not null
);
alter table share_xp_events add constraint share_xp_events_pkey PRIMARY KEY (user_id, day, platform);
alter table share_xp_events enable row level security;
create policy share_xp_events_own on share_xp_events for all to public using ((user_id = user_id())) with check ((user_id = user_id()));

create table if not exists support_adjustments (
  id uuid default gen_random_uuid() not null,
  user_id text not null,
  kind text not null,
  amount integer default 0 not null,
  badge_id text,
  note text not null,
  created_by text not null,
  created_at timestamp with time zone default now() not null,
  consumed_at timestamp with time zone
);
alter table support_adjustments add constraint support_adjustments_kind_check CHECK ((kind = ANY (ARRAY['xp'::text, 'purchased_xp'::text, 'streak_freeze'::text, 'streak_set'::text, 'booster_hours'::text, 'badge'::text, 'force_resync'::text])));
alter table support_adjustments add constraint support_adjustments_pkey PRIMARY KEY (id);
CREATE INDEX support_adjustments_user ON public.support_adjustments USING btree (user_id, consumed_at);
alter table support_adjustments enable row level security;
create policy support_adjustments_head_all on support_adjustments for all to public using ((user_id() IN ( SELECT coaches.user_id
   FROM coaches
  WHERE ((coaches.is_active = true) AND (coaches.role = 'head_coach'::text))))) with check ((user_id() IN ( SELECT coaches.user_id
   FROM coaches
  WHERE ((coaches.is_active = true) AND (coaches.role = 'head_coach'::text)))));
create policy support_adjustments_head_all_v2 on support_adjustments for all to authenticated using (is_head_coach()) with check (is_head_coach());
create policy support_adjustments_player_consume on support_adjustments for update to public using ((user_id = user_id())) with check ((user_id = user_id()));
create policy support_adjustments_player_read on support_adjustments for select to public using ((user_id = user_id()));

create table if not exists team_events (
  id uuid default gen_random_uuid() not null,
  kind text not null,
  title text not null,
  starts_at timestamp with time zone not null,
  ends_at timestamp with time zone,
  location text,
  notes text,
  team_id text,
  active boolean default true not null,
  created_by text,
  created_at timestamp with time zone default now() not null,
  audience text default 'everyone'::text not null,
  target_team_ids text[] default '{}'::text[] not null,
  target_player_ids text[] default '{}'::text[] not null
);
alter table team_events add constraint team_events_kind_check CHECK ((kind = ANY (ARRAY['practice'::text, 'game'::text, 'session'::text, 'other'::text])));
alter table team_events add constraint team_events_pkey PRIMARY KEY (id);
alter table team_events enable row level security;
create policy team_events_coach_write on team_events for all to public using ((user_id() IN ( SELECT coaches.user_id
   FROM coaches
  WHERE (coaches.is_active = true)))) with check ((user_id() IN ( SELECT coaches.user_id
   FROM coaches
  WHERE (coaches.is_active = true))));
create policy team_events_coach_write_v2 on team_events for all to authenticated using (is_active_coach()) with check (is_active_coach());
create policy team_events_read on team_events for select to public using ((active = true));

create table if not exists team_members (
  team_id uuid not null,
  player_id text not null,
  added_at timestamp with time zone default now() not null
);
alter table team_members add constraint team_members_pkey PRIMARY KEY (team_id, player_id);
alter table team_members enable row level security;
create policy team_members_coach_all on team_members for all to public using ((user_id() IN ( SELECT coaches.user_id
   FROM coaches
  WHERE (coaches.is_active = true)))) with check ((user_id() IN ( SELECT coaches.user_id
   FROM coaches
  WHERE (coaches.is_active = true))));
create policy team_members_coach_all_v2 on team_members for all to authenticated using (is_active_coach()) with check (is_active_coach());
create policy team_members_player_read_own on team_members for select to public using ((player_id = user_id()));

create table if not exists teams (
  id uuid default gen_random_uuid() not null,
  name text not null,
  label text default ''::text not null,
  created_by text,
  created_at timestamp with time zone default now() not null
);
alter table teams add constraint teams_pkey PRIMARY KEY (id);
alter table teams enable row level security;
create policy teams_coach_insert on teams for insert to public with check (((user_id() IN ( SELECT coaches.user_id
   FROM coaches
  WHERE (coaches.is_active = true))) AND (created_by = user_id())));
create policy teams_coach_insert_v2 on teams for insert to authenticated with check ((is_active_coach() AND (created_by = user_id())));
create policy teams_coach_select on teams for select to public using ((user_id() IN ( SELECT coaches.user_id
   FROM coaches
  WHERE (coaches.is_active = true))));
create policy teams_coach_select_v2 on teams for select to authenticated using (is_active_coach());
create policy teams_owner_or_head_delete on teams for delete to public using (((created_by = user_id()) OR (user_id() IN ( SELECT coaches.user_id
   FROM coaches
  WHERE ((coaches.is_active = true) AND (coaches.role = 'head_coach'::text))))));
create policy teams_owner_or_head_delete_v2 on teams for delete to authenticated using (((created_by = user_id()) OR is_head_coach()));
create policy teams_owner_or_head_update on teams for update to public using (((created_by = user_id()) OR (user_id() IN ( SELECT coaches.user_id
   FROM coaches
  WHERE ((coaches.is_active = true) AND (coaches.role = 'head_coach'::text))))));
create policy teams_owner_or_head_update_v2 on teams for update to authenticated using (((created_by = user_id()) OR is_head_coach())) with check (((created_by = user_id()) OR is_head_coach()));

create table if not exists user_badges (
  user_id text not null,
  badge_id text not null,
  earned_at timestamp with time zone default now() not null
);
alter table user_badges add constraint user_badges_pkey PRIMARY KEY (user_id, badge_id);
alter table user_badges enable row level security;
create policy user_badges_own on user_badges for all to public using ((user_id = user_id())) with check ((user_id = user_id()));

create table if not exists user_favorites (
  user_id text not null,
  kind text not null,
  item_id text not null,
  created_at timestamp with time zone default now() not null
);
alter table user_favorites add constraint user_favorites_kind_check CHECK ((kind = ANY (ARRAY['drill'::text, 'routine'::text, 'workout'::text])));
alter table user_favorites add constraint user_favorites_pkey PRIMARY KEY (user_id, kind, item_id);
alter table user_favorites enable row level security;
create policy user_favorites_own on user_favorites for all to public using ((user_id = user_id())) with check ((user_id = user_id()));

create table if not exists workout_records (
  id text not null,
  user_id text not null,
  mode text default ''::text not null,
  started_at timestamp with time zone not null,
  duration_sec integer default 0 not null,
  distance_meters double precision default 0 not null,
  active_calories double precision default 0 not null,
  avg_heart_rate integer default 0 not null,
  max_heart_rate integer default 0 not null,
  created_at timestamp with time zone default now() not null
);
alter table workout_records add constraint workout_records_pkey PRIMARY KEY (id);
CREATE INDEX workout_records_user ON public.workout_records USING btree (user_id, started_at);
alter table workout_records enable row level security;
create policy workout_records_own on workout_records for all to public using ((user_id = user_id())) with check ((user_id = user_id()));

create table if not exists xp_transactions (
  id uuid default gen_random_uuid() not null,
  user_id text not null,
  product_id text not null,
  xp_amount integer not null,
  store_transaction_id text,
  created_at timestamp with time zone default now() not null
);
alter table xp_transactions add constraint xp_transactions_pkey PRIMARY KEY (id);
alter table xp_transactions enable row level security;
create policy xp_transactions_own on xp_transactions for all to public using ((user_id = user_id())) with check ((user_id = user_id()));

-- ============ FUNCTIONS ============

CREATE OR REPLACE FUNCTION public.can_read_player(target_player_id text)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select
    public.user_id() = target_player_id
    or public.is_head_coach()
    or (
      public.is_active_coach()
      and exists (
        select 1 from public.coach_players cp
        where cp.player_id = target_player_id
          and lower(cp.coach_email) = lower(
            coalesce(nullif(current_setting('request.jwt.claims', true)::json ->> 'email',''), '')
          )
      )
    );
$function$
;

CREATE OR REPLACE FUNCTION public.claim_member_number()
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  next_value integer;
BEGIN
  UPDATE member_counter
    SET value = value + 1
    WHERE id = true
    RETURNING value INTO next_value;
  RETURN next_value;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.claim_roster_invite(invite_code text, p_username text)
 RETURNS player_profiles
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
$function$
;

CREATE OR REPLACE FUNCTION public.delete_account()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare uid text := auth.uid()::text;
begin
  if uid is null then raise exception 'not authenticated'; end if;

  -- user-data tables (keyed by user_id)
  delete from session_logs        where user_id = uid;
  delete from combine_results     where user_id = uid;
  delete from drill_notes         where user_id = uid;
  delete from custom_workouts     where user_id = uid;
  delete from gameiq_completions  where user_id = uid;

  -- progression tables (keyed by player_id -> profiles.id)
  delete from player_progress     where player_id = uid;
  delete from player_state        where player_id = uid;
  delete from certifications      where player_id = uid;

  -- coach / roster references
  delete from roster_invites      where claimed_by = uid or coach_id = uid;
  delete from coaches             where user_id = uid;

  -- profiles + families (detach family members first so the delete can't be blocked)
  update player_profiles set family_id = null
    where family_id in (select id from families where owner_id = uid);
  delete from player_profiles     where id = uid or account_id = uid;
  delete from families            where owner_id = uid;

  -- the account profile, then the auth login record
  delete from profiles            where id = uid;
  delete from auth.users          where id = auth.uid();
end;
$function$
;

CREATE OR REPLACE FUNCTION public.is_active_coach()
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select public.my_coach_role() is not null;
$function$
;

CREATE OR REPLACE FUNCTION public.is_head_coach()
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select public.my_coach_role() = 'head_coach';
$function$
;

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
$function$
;

CREATE OR REPLACE FUNCTION public.protect_player_username()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NEW.username IS DISTINCT FROM OLD.username AND user_id() <> OLD.account_id THEN
    NEW.username := OLD.username;
  END IF;
  RETURN NEW;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.redeem_roster_invite(invite_code text)
 RETURNS player_profiles
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
$function$
;

CREATE OR REPLACE FUNCTION public.rls_auto_enable()
 RETURNS event_trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog'
AS $function$
DECLARE
  cmd record;
BEGIN
  FOR cmd IN
    SELECT *
    FROM pg_event_trigger_ddl_commands()
    WHERE command_tag IN ('CREATE TABLE', 'CREATE TABLE AS', 'SELECT INTO')
      AND object_type IN ('table','partitioned table')
  LOOP
     IF cmd.schema_name IS NOT NULL AND cmd.schema_name IN ('public') AND cmd.schema_name NOT IN ('pg_catalog','information_schema') AND cmd.schema_name NOT LIKE 'pg_toast%' AND cmd.schema_name NOT LIKE 'pg_temp%' THEN
      BEGIN
        EXECUTE format('alter table if exists %s enable row level security', cmd.object_identity);
        RAISE LOG 'rls_auto_enable: enabled RLS on %', cmd.object_identity;
      EXCEPTION
        WHEN OTHERS THEN
          RAISE LOG 'rls_auto_enable: failed to enable RLS on %', cmd.object_identity;
      END;
     ELSE
        RAISE LOG 'rls_auto_enable: skip % (either system schema or not in enforced list: %.)', cmd.object_identity, cmd.schema_name;
     END IF;
  END LOOP;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.user_id()
 RETURNS text
 LANGUAGE sql
 STABLE
 SET search_path TO 'public'
AS $function$
  SELECT COALESCE(
    nullif(current_setting('request.jwt.claims', true)::json ->> 'sub', ''),
    nullif(current_setting('request.jwt.claim.sub', true), '')
  );
$function$
;

CREATE OR REPLACE FUNCTION public.username_available(candidate text)
 RETURNS boolean
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT NOT EXISTS (
    SELECT 1 FROM player_profiles
    WHERE is_example = false
      AND lower(username) = lower(trim(candidate))
  );
$function$
;


-- ============ TRIGGERS ============

CREATE TRIGGER trg_protect_player_username BEFORE UPDATE ON public.player_profiles FOR EACH ROW EXECUTE FUNCTION protect_player_username();
