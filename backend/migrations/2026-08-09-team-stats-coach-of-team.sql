-- =============================================================================
--  2026-08-09  Team stats: "coach of the team", not just "coach who made it"
--
--  STATUS: APPLIED to production (twzukrzcfquxfmrnffze) on 2026-08-09.
--  Verified by impersonation, in a transaction, rolled back — results below.
--
--  Supersedes the creator-only rule shipped in
--  2026-08-09-team-stats.sql. That was a faithful reading of "the teams they
--  control", but in practice a head coach sets the teams up and the assistant
--  coaches run them, so nobody who actually watches the games could file a
--  report. Owner's decision: "I am ok with head coach or coach of a team
--  adding stats."
--
--  "Coach of a team" is DERIVED from `coach_players` rather than stored in a
--  new link table. A coach is a coach of a team when a player they are linked
--  to is on it. That means there is no second thing to maintain: assigning a
--  coach their players — which the roster scoping already requires — grants
--  stats access to exactly those players' teams and nothing else, and it
--  narrows on its own as real rosters are assigned rather than drifting the way
--  a parallel table would.
--
--  THE ID JOIN IS DELIBERATE. `coach_players.player_id` stores
--  `player_profiles.account_id`; `team_members.player_id` stores
--  `player_profiles.id`. Those are the same value for every row in production
--  today, so a naive join works — and would quietly break the first time a
--  family profile joins a team, because one account owns several player rows
--  there. Going through `player_profiles` and matching either column is what
--  stops that being a silent failure a year from now.
--
--  `can_read_team_stats` delegates to this function, so widening it also widens
--  who can READ the sheet — which is the intent: a coach who can file for a
--  team should obviously be able to see it.
-- =============================================================================

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
      and (
        exists (
          select 1 from public.teams t
          where t.id = p_team_id and t.created_by = public.user_id()
        )
        or exists (
          select 1
          from public.team_members tm
          join public.player_profiles pp on pp.id = tm.player_id
          join public.coach_players cp
            on cp.player_id = pp.account_id or cp.player_id = pp.id
          where tm.team_id = p_team_id
            and lower(cp.coach_email) = lower(
              coalesce(nullif(current_setting('request.jwt.claims', true)::json ->> 'email',''), '')
            )
        )
      )
    );
$$;

-- =============================================================================
--  VERIFICATION (2026-08-09, transaction, rolled back)
-- =============================================================================
--
--  A player was added to the one existing team, then:
--
--    coach of the team (suemcgee83@gmail.com, linked to that player)
--                                     file stat report   ALLOWED
--    head coach (josephmcgee36@gmail.com)
--                                     file stat report   ALLOWED
--    player on the team (carsondprice@icloud.com)
--                                     file stat report   blocked 42501
--    player on the team               read the sheet     2 visible
--    unrelated player                 read the sheet     0 visible
--
--  NOTE on today's data: the 2026-08-08 grandfather insert linked every active
--  non-head coach to every existing player, so right now this resolves to
--  "every coach can file for every team". That is the pre-existing access being
--  carried forward rather than new exposure, and it narrows on its own as real
--  rosters are assigned.
--
--  CLIENT SIDE: `TeamStatsStore.manageableTeams` mirrors this rule using a
--  `coachedPlayerIDs` set read from RLS-scoped `player_profiles`. The two must
--  stay in step — listing a team the database will refuse gives the coach a
--  Save button that looks like it worked and reached nobody.
--
-- =============================================================================
--  ROLLBACK — back to creator-only
-- =============================================================================
--
-- create or replace function public.can_manage_team_stats(p_team_id uuid)
-- returns boolean language sql stable security definer set search_path = public as $$
--   select public.is_head_coach()
--     or (public.is_active_coach()
--         and exists (select 1 from public.teams t
--                     where t.id = p_team_id and t.created_by = public.user_id()));
-- $$;
