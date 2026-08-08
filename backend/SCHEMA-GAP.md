# backend/schema.sql — closed, 2026-08-08

**Superseded.** This file used to document a 13-table gap between `schema.sql`
and the live database. `schema.sql` is now generated directly from production
and matches it. This page is kept for the reasoning and for the two things the
audit turned up that are *not* schema problems and are still open.

## What was wrong, and how it was closed

`schema.sql` declared **17 tables**. The app reads or writes **41**. Missing
were the ones carrying nearly everything a player does — `session_logs`,
`combine_results`, `drill_results`, `xp_transactions`, `game_entries`,
`user_badges`, `team_events`, `workout_records`, and more — plus several
columns and two functions.

It mattered more than a documentation gap. The sync engine classifies a 4xx as
a **permanent** failure and quarantines the operation, so a write to a column
that does not exist doesn't crash and doesn't retry. It silently never arrives,
and that player's data stops syncing with no error anywhere.

`schema.sql` is now a dump of the live schema: 41 tables, 101 RLS policies, 12
functions, every index and trigger. Regenerate it rather than editing it.

Every column the audit listed as suspect is present in production and always
was:

| Table | Column | Status |
|---|---|---|
| `player_state` | `purchased_xp` | present (bigint, default 0) |
| `player_profiles` | `ballon_dor_requested_at` | present |
| `player_profiles` | `position_code`, `birth_year` | present |
| `player_profiles` | `avatar_kind`, `avatar_builtin`, `avatar_url` | present |
| `player_profiles` | `coach_focus` | present |
| `announcements` | `audience`, `target_team_ids`, `target_player_ids` | present |

Both functions the app calls — `delete_account()` and `my_coach_role()` — are
defined and now in the file, alongside `can_read_player()`,
`claim_roster_invite()`, `redeem_roster_invite()`, `username_available()`,
`claim_member_number()`, `is_head_coach()`, `is_active_coach()`, `user_id()`,
`protect_player_username()` and `rls_auto_enable()`.

**So the `purchased_xp` theory was wrong.** The column exists. Whatever is
stopping `player_state` from syncing is something else — see below.

---

## Still open

### 1. `player_state` has exactly one row for the entire app

Counted 2026-08-08: `player_profiles` has 4 rows, `player_progress` has 6,
`player_state` has **1** — Joe's. Every other player has a profile and logged
progress but no state row, which is where XP, streak, freezes and
`purchased_xp` live. That is the shape you would expect if `player_state`
upserts are failing and being quarantined for everyone else.

It is not a missing column, so the next place to look is the RLS insert policy
and the upsert's conflict target. Worth reproducing with a real upsert as
`authenticated` for a non-Joe account, in a transaction, rolled back — the same
method that found the storage bug.

### 2. Coach drill-video uploads have no server-side restriction

Audit item #38. Coach-only is enforced in the UI only; the storage policy does
not check the caller's role. Unchanged.

---

## Fixed since the original audit

- **Uploads never worked, ever** — 0 objects in every bucket since June. Three
  stacked causes: no SELECT policy on `storage.objects` (which blocks upsert,
  since `x-upsert` needs SELECT + UPDATE + INSERT), `drill-images` missing its
  email-based policy, and two contradictory coach-identity systems.
  `2026-08-05-storage-and-coach-access.sql`, applied.
- **Coach identity split** — `my_coach_role()` resolved by JWT email while
  `is_head_coach()` and every write policy resolved by `coaches.user_id`, which
  is null for 8 of 11 coaches. Aligned; `_v2` email-based policies added
  alongside the originals.
- **Every coach could read every child** — audit item #36.
  `2026-08-08-coach-roster-scoping-APPLIED.sql`, applied and verified by
  impersonation. Note that the earlier staged version of this
  (`2026-08-05-coach-roster-scoping.sql`) is **superseded and must not be run**:
  it backfilled from `roster_invites`, which is empty, so it would have linked
  nobody and cut every non-head coach off from every player.
