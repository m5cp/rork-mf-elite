-- =============================================================================
--  2026-08-08  Scope coach reads to the coach's own roster
--
--  STATUS: APPLIED to production (project twzukrzcfquxfmrnffze) on 2026-08-08.
--  Verified before and after with role impersonation — results at the bottom.
--
--  This SUPERSEDES 2026-08-05-coach-roster-scoping.sql, which was never applied
--  and must not be. That version backfilled `coach_players` from claimed
--  `roster_invites` and keyed the link table on `profiles(id)`. Both
--  assumptions were wrong against the live database:
--
--    * `roster_invites` is EMPTY — 0 rows, ever. The backfill would have
--      created zero links, and every non-head coach would have lost access to
--      every player the moment it ran.
--    * 8 of the 11 coach rows have no `user_id` and no matching `profiles`
--      row, because those people have never signed in. A link table keyed on
--      `profiles(id)` cannot represent them at all.
--
--  So this version keys on email, which every coach row has, and which
--  `my_coach_role()` already uses to resolve a caller.
-- =============================================================================

create table if not exists coach_players (
  id          uuid primary key default gen_random_uuid(),
  coach_email text not null,
  player_id   text not null,
  created_at  timestamptz not null default now(),
  unique (coach_email, player_id)
);

create index if not exists coach_players_email_idx  on coach_players (lower(coach_email));
create index if not exists coach_players_player_idx on coach_players (player_id);

alter table coach_players enable row level security;

drop policy if exists "coach_players_select" on coach_players;
create policy "coach_players_select" on coach_players
  for select using (
    user_id() = player_id
    or lower(coach_email) = lower(coalesce(nullif(current_setting('request.jwt.claims', true)::json ->> 'email',''), ''))
    or is_head_coach()
  );

-- Only head coaches manage roster membership. A regular coach able to add
-- themselves to a player would defeat the whole boundary.
drop policy if exists "coach_players_write" on coach_players;
create policy "coach_players_write" on coach_players
  for all using (is_head_coach()) with check (is_head_coach());

create or replace function can_read_player(target_player_id text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
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
$$;

-- Grandfather what exists today so nobody loses access on the cutover. With no
-- invites to derive from, the relationship that exists today is "every coach
-- sees every player" — that gets frozen in place for the current four players.
-- New players are NOT visible to a regular coach until a head coach links them.
insert into coach_players (coach_email, player_id)
select c.email, pp.account_id
from coaches c
cross join player_profiles pp
where c.is_active = true
  and c.role is distinct from 'head_coach'
  and c.email is not null
  and pp.is_example = false
  and pp.account_id is not null
on conflict (coach_email, player_id) do nothing;

drop policy if exists "player_profiles_select" on player_profiles;
create policy "player_profiles_select" on player_profiles
  for select using (can_read_player(account_id));

drop policy if exists "player_state_select" on player_state;
create policy "player_state_select" on player_state
  for select using (can_read_player(player_id));

drop policy if exists "player_progress_select" on player_progress;
create policy "player_progress_select" on player_progress
  for select using (can_read_player(player_id));

drop policy if exists "player_profiles_update" on player_profiles;
create policy "player_profiles_update" on player_profiles
  for update using (can_read_player(account_id))
  with check (can_read_player(account_id));

-- =============================================================================
--  VERIFICATION RESULTS (run 2026-08-08, in a transaction, rolled back)
-- =============================================================================
--
--  24 links created — 6 active non-head coaches x 4 players.
--
--  appreview@mfelite.app (regular coach)      sees 4 profiles   <- unchanged
--  josephmcgee36@gmail.com (head coach)       sees 4 profiles   <- unchanged
--  carsondprice@icloud.com (plain player)     sees 1 profile    <- own only
--  appreview after unlinking one player       sees 3 profiles   <- boundary bites
--
--  Nobody lost access. Only three of the eleven coaches can currently
--  authenticate at all (Joe, Matteo, App Review); the other eight are
--  pre-provisioned rows with no auth user, and they will resolve by email when
--  those people first sign in.
--
--  NOTE while you are here: `player_state` has exactly ONE row for the whole
--  app (Joe's), while `player_progress` has six and `player_profiles` four.
--  That is consistent with player_state upserts failing and being quarantined
--  for everyone else — see backend/SCHEMA-GAP.md on `purchased_xp`. Worth
--  chasing separately; it is not caused by anything here.
--
-- =============================================================================
--  ROLLBACK — restores the previous permissive behaviour exactly
-- =============================================================================
--
-- begin;
-- drop policy if exists "player_profiles_select" on player_profiles;
-- create policy "player_profiles_select" on player_profiles
--   for select using (user_id() = account_id or user_id() in (select user_id from coaches where is_active = true));
-- drop policy if exists "player_state_select" on player_state;
-- create policy "player_state_select" on player_state
--   for select using (user_id() = player_id or user_id() in (select user_id from coaches where is_active = true));
-- drop policy if exists "player_progress_select" on player_progress;
-- create policy "player_progress_select" on player_progress
--   for select using (user_id() = player_id or user_id() in (select user_id from coaches where is_active = true));
-- drop policy if exists "player_profiles_update" on player_profiles;
-- create policy "player_profiles_update" on player_profiles
--   for update using (user_id() = account_id or user_id() in (select user_id from coaches where is_active = true))
--   with check (user_id() = account_id or user_id() in (select user_id from coaches where is_active = true));
-- commit;
