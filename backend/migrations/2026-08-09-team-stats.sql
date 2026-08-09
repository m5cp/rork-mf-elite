-- =============================================================================
--  2026-08-09  Per-game team stat reports (the coach's season stat sheet)
--
--  STATUS: APPLIED to production on 2026-08-09.
--  The write rule here was superseded the same day by
--  2026-08-09-team-stats-coach-of-team.sql — see that file for the current
--  definition of can_manage_team_stats. Written to be applied and verified centrally.
--
--  WHY
--  ---
--  Coaches keep their season stats in a spreadsheet today. The owner wants that
--  sheet in the app — "for each game, and it auto rolls up" — visible to the
--  coach and to that coach's own team, and to nobody else in the app.
--
--  So this stores the ONE thing that is actually a fact: what happened in a
--  given game. Every cumulative number the app shows (goals, assists, points,
--  saves, shutouts, and all the per-game averages) is derived from these rows
--  on the client. Nothing aggregated is persisted anywhere, which is the point:
--  when a coach corrects game 4, the season corrects itself. A stored season
--  total has to be recomputed on every edit, and the first recompute that gets
--  missed turns the sheet into a confident lie.
--
--  WHAT IT DOES
--  ------------
--  1. Adds `team_stat_reports` — one row per game per team, with the per-player
--     lines as JSON on the row.
--  2. Adds two helpers, `can_manage_team_stats` / `can_read_team_stats`, in the
--     same shape as the existing `can_read_player`.
--  3. Enables RLS: writes for the coach who owns the team (and head coaches),
--     reads for that team's own members as well.
--
--  Additive only. No existing table, policy or function is modified, and
--  nothing is deleted.
--
--  WHY THE PLAYER LINES ARE JSON, NOT A CHILD TABLE
--  ------------------------------------------------
--  The rollup happens on device, as every other Coach Mode aggregate already
--  does, so nothing here needs to GROUP BY. A season is ~25 rows per team, and
--  `progress_reports.sections` and `coach_evaluations.ratings` already store
--  structured coach documents exactly this way. The practical reason is the
--  client: `SupabaseClient` posts a single row per request, so a child table
--  would make saving one game twenty-five sequential HTTP writes — twenty-five
--  chances for a half-saved game report on a phone in a car park.
--
--  Shape of `lines` (an array; players with nothing recorded are omitted):
--    [{"player_id":"<profiles.id>","played":true,"goals":1,"assists":0,
--      "saves":0,"goals_allowed":0,"shutout":false}]
--
--  A NOTE ON WHO CAN WRITE
--  -----------------------
--  Write access is "the coach who created the team, or a head coach". That is
--  the boundary the owner described and it is unambiguous, but it has one
--  consequence worth knowing before this goes out: a REGULAR coach cannot file
--  stats for a team a HEAD coach created for them. If that turns out to be how
--  the club actually works, the fix is an explicit coach-to-team link table
--  rather than loosening this policy — see the sketch at the bottom of the
--  file. `teams` itself is unchanged; every active coach can still SELECT every
--  team, exactly as they can today.
--
--  A NOTE ON "MISSING STAT REPORTS"
--  --------------------------------
--  That count is games-scheduled minus reports-filed, and the app derives the
--  scheduled side from `team_events` where `kind = 'game'` and the event is
--  addressed to the team (either `team_id`, or the team appearing in
--  `target_team_ids`). A game published to the `everyone` audience is NOT
--  attributed to any team: it cannot be, and guessing would inflate every
--  team's missing count at once. Coaches who want the missing-report figure to
--  mean anything need to target their games at a team, which the schedule
--  composer already lets them do.
-- =============================================================================

begin;

-- -----------------------------------------------------------------------------
-- 1. The table
-- -----------------------------------------------------------------------------
create table if not exists team_stat_reports (
  id            uuid primary key default gen_random_uuid(),
  team_id       uuid not null references teams(id) on delete cascade,
  -- The scheduled game this covers, when there was one. Nullable on purpose:
  -- a game that was played but never put on the schedule still gets a report,
  -- it just can never be "missing".
  event_id      uuid references team_events(id) on delete set null,
  -- Calendar year of the game, e.g. '2025'. Denormalized from `game_date` by
  -- the client so the season picker is a plain equality filter.
  season        text        not null default '',
  game_date     date        not null default current_date,
  opponent      text        not null default '',
  result        text        not null default 'D',
  goals_for     integer     not null default 0,
  goals_against integer     not null default 0,
  lines         jsonb       not null default '[]'::jsonb,
  -- Defaulted rather than sent by the client: PostgREST's merge-duplicates
  -- upsert only touches the columns in the payload, so a default keeps this as
  -- "who filed it first" while `updated_by` tracks who last edited it.
  created_by    text        default public.user_id(),
  updated_by    text,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'team_stat_reports_result_check'
  ) then
    alter table team_stat_reports
      add constraint team_stat_reports_result_check
      check (result in ('W', 'L', 'D'));
  end if;
end
$$;

-- One report per scheduled game per team. Keyed on the pair, not on `event_id`
-- alone, because one published game can be addressed to more than one team and
-- each of those teams files its own report. Unscheduled games (event_id null)
-- are unconstrained — Postgres does not collide NULLs, which is what we want.
create unique index if not exists team_stat_reports_team_event_unique
  on team_stat_reports (team_id, event_id)
  where event_id is not null;

-- The only query the app makes: one team, one season, newest game first.
create index if not exists team_stat_reports_team_season
  on team_stat_reports (team_id, season, game_date desc);

-- -----------------------------------------------------------------------------
-- 2. Who may touch a team's stats
--
--    Same shape as the existing `can_read_player`: SECURITY DEFINER so the
--    policy can look at `teams` and `team_members` without the caller needing
--    their own read access to those rows, and a pinned search_path so the
--    function cannot be redirected by a caller-set one.
-- -----------------------------------------------------------------------------
create or replace function public.can_manage_team_stats(p_team_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    public.is_head_coach()
    or (
      public.is_active_coach()
      and exists (
        select 1 from public.teams t
        where t.id = p_team_id
          and t.created_by = public.user_id()
      )
    );
$$;

create or replace function public.can_read_team_stats(p_team_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    public.can_manage_team_stats(p_team_id)
    or exists (
      select 1 from public.team_members tm
      where tm.team_id = p_team_id
        and tm.player_id = public.user_id()
    );
$$;

-- -----------------------------------------------------------------------------
-- 3. Row level security
--
--    Reads: the team's own athletes, plus the coaches who can manage the team.
--    Writes: managing coaches only.
--
--    Note there is no "any active coach" clause anywhere here. That clause is
--    what let a coach added for one U11 team read the whole customer base
--    before 2026-08-08, and a stat sheet is exactly the kind of thing the owner
--    said is "not for total app sharing".
-- -----------------------------------------------------------------------------
alter table team_stat_reports enable row level security;

drop policy if exists team_stat_reports_read on team_stat_reports;
create policy team_stat_reports_read on team_stat_reports
  for select to authenticated
  using (public.can_read_team_stats(team_id));

drop policy if exists team_stat_reports_coach_write on team_stat_reports;
create policy team_stat_reports_coach_write on team_stat_reports
  for all to authenticated
  using (public.can_manage_team_stats(team_id))
  with check (public.can_manage_team_stats(team_id));

-- Belt and braces. Supabase's default privileges already grant new public
-- tables to these roles (`coach_players` was created without this and works),
-- but an explicit grant costs nothing and makes the file self-contained.
grant select, insert, update, delete on table public.team_stat_reports to authenticated;

commit;

-- =============================================================================
--  VERIFICATION — run in a transaction and roll back
-- =============================================================================
--
-- 1. THE OWNER BOUNDARY HOLDS. A coach can write for a team they created and
--    not for one they didn't.
--
--    begin;
--    set local role authenticated;
--    set local request.jwt.claims = '{"sub":"<coach-user-id>","email":"<coach-email>"}';
--    select id, name, created_by, public.can_manage_team_stats(id) as can_write,
--           public.can_read_team_stats(id) as can_read
--      from teams order by created_at;
--    reset role;
--    rollback;
--
--    Expect can_write true only where created_by = the impersonated sub — and
--    true everywhere for a head coach.
--
-- 2. A PLAYER SEES THEIR OWN TEAM AND NOTHING ELSE.
--
--    begin;
--    set local role authenticated;
--    set local request.jwt.claims = '{"sub":"<player-user-id>","email":"<player-email>"}';
--    select count(*) from team_stat_reports;          -- only their team's rows
--    reset role;
--    rollback;
--
-- 3. A SIGNED-IN NON-MEMBER SEES NOTHING. Same as (2) with an account that is
--    neither a coach nor on the team; expect 0.
--
-- 4. INSERT IS REFUSED FOR A NON-OWNING COACH (expect 42501).
--
--    begin;
--    set local role authenticated;
--    set local request.jwt.claims = '{"sub":"<other-coach-user-id>","email":"<other-coach-email>"}';
--    insert into team_stat_reports (team_id, season, game_date, opponent, result)
--      values ('<team-they-do-not-own>', '2026', current_date, 'Test', 'W');
--    rollback;
--
-- 5. THE UPSERT PATH THE APP USES actually merges rather than duplicating.
--    Run the same insert twice with an explicit id and
--    `on conflict (id) do update`; expect one row, and `created_by` unchanged
--    on the second pass while `updated_by` moves.
--
-- 6. `public.user_id()` IS RESOLVABLE AS A COLUMN DEFAULT. Insert as an
--    impersonated coach with `created_by` omitted and confirm it lands
--    populated rather than null.

-- =============================================================================
--  IF REGULAR COACHES NEED TEAMS THEY DIDN'T CREATE
-- =============================================================================
--
--  Do NOT widen the policy to `is_active_coach()` — that is app-wide access
--  again. Add the link explicitly instead, and change the one clause:
--
--  create table if not exists coach_teams (
--    coach_email text not null,
--    team_id     uuid not null references teams(id) on delete cascade,
--    created_at  timestamptz not null default now(),
--    primary key (coach_email, team_id)
--  );
--  -- then, inside can_manage_team_stats, alongside the created_by test:
--  --   or exists (
--  --     select 1 from public.coach_teams ct
--  --     where ct.team_id = p_team_id
--  --       and lower(ct.coach_email) = lower(coalesce(nullif(
--  --         current_setting('request.jwt.claims', true)::json ->> 'email',''), ''))
--  --   )
--  Keyed on email for the same reason `coach_players` is: 8 of the 11 coach
--  rows have no `user_id` because those people have never signed in.

-- =============================================================================
--  ROLLBACK — removes everything this file added
-- =============================================================================
--
-- begin;
-- drop policy if exists team_stat_reports_read        on team_stat_reports;
-- drop policy if exists team_stat_reports_coach_write on team_stat_reports;
-- drop table if exists team_stat_reports;
-- drop function if exists public.can_read_team_stats(uuid);
-- drop function if exists public.can_manage_team_stats(uuid);
-- commit;
--
-- Dropping the table takes the filed reports with it. If the intent is only to
-- back the feature out of the app, drop the two policies' write half and leave
-- the data in place instead.
