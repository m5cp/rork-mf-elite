# backend/schema.sql — closed, 2026-08-08

**Superseded.** This file used to document a 13-table gap between `schema.sql`
and the live database. `schema.sql` is now generated directly from production
and matches it, and every follow-on item is closed. This page is kept for the
reasoning, for the evidence behind two findings that looked like bugs and
weren't, and so nobody re-opens either.

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

## The "one `player_state` row" scare — chased down, nothing wrong

Recorded here because it looked exactly like a bug twice, and the next person
to glance at the row counts will think the same thing.

**The observation.** `player_profiles` has 4 rows, `player_progress` has 6,
`player_state` has **1**. Three players with a profile and no XP/streak/freeze
row is the classic shape of upserts failing and being quarantined — a 4xx is a
permanent failure here, so a rejected write vanishes without an error anywhere.

**It isn't that.** Two checks, both run 2026-08-08:

1. *Does the write work for a non-Joe account?* Ran the app's exact upsert —
   `insert … on conflict (player_id) do update` — as role `authenticated` with
   Carson's JWT, in a transaction, rolled back. It succeeded and returned the
   row. The INSERT policy (`with check (user_id() = player_id)`), the UNIQUE on
   `player_id` backing the conflict target, and every column the client sends
   are all correct.

2. *Who owns the data that does exist?* Counted every user-scoped table by
   owner. `player_progress` 6, `session_logs` 6, `user_badges` 1,
   `player_state` 1 — and **all of it is Joe's**. `combine_results`,
   `drill_results`, `xp_transactions`, `workout_records` and
   `gameiq_completions` are empty for everyone.

So there is no missing `player_state` row. Joe is the only person who has ever
trained while signed in; the other three profiles are accounts that were
created and never used. Every logging path (`QuickLog`, `DrillPlayerViewModel`,
`WorkoutStore`, `GameIQStore`, `XPStoreService`, `ShareXPService`,
`SupportAdjustments`, the backfill and the restore) calls
`enqueuePlayerState`, so the first real session from any of them will create
one.

**What this means for reading these counts in future:** a player with no
`player_state` row has not trained. It is not evidence of a sync failure. To
actually detect quarantined writes you need the client side — `SyncEngine`'s
`quarantinedCount` and the `PendingOp` rows with `isQuarantined = true` — not
the server row counts.

## Nothing open

Both remaining items are closed. Details under "Fixed" below.

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
- **Media upload and curriculum editing narrowed to head coaches** —
  2026-08-08, owner's decision. They were gated on `is_active_coach()`, which
  is all 11 rows in the `coaches` table: five head-coach addresses belonging to
  two people, plus six regular coaches (family accounts and the Apple
  reviewer). Now `is_head_coach()` on `storage.objects` for both drill buckets
  and on `drills`, `disciplines`, `categories`, `levels`, `curriculum_edits`,
  `daily_quotes` and `progression_rules`. Both generations of every policy were
  dropped — they are OR'd, so leaving the older `user_id`-based twin would have
  kept the old permission alive underneath. Regular coaches keep the dashboard,
  player detail, teams, rosters, invites, announcements, coach workouts,
  schedule events, notes, evaluations and progress reports. See
  `2026-08-08-head-coach-only-media-and-curriculum.sql` for the verification
  table. App side: the Drill Editor entry point and the two Coach Guide
  sections that describe it are hidden unless the role is `head_coach`, so
  nobody is offered a control that would 403.

- **Coach access can be revoked from the database again** — the built-in
  `CoachAllowlist` used to override an explicit "no role" answer from
  `my_coach_role()`, so removing someone from `coaches` did nothing and
  revoking anyone needed an App Store release. Now only a *failed* RPC falls
  back to the list; an explicit null revokes. Two supporting fixes went with
  it, because turning the fallback off exposed them: the RPC is not called
  without a live bearer token (PostgREST runs it happily as `anon` and answers
  200 `null`, which would read as "removed"), and an unrecognised role string
  grants the regular role rather than revoking — `coaches.role` is plain text
  with no CHECK constraint, so one typo in the dashboard would otherwise have
  locked the owner out of his own app.

  Related, and long-standing: `refreshCoachStatus()` was only ever called
  immediately after a sign-in, and coach state is in-memory only. A coach who
  relaunched the app had no Coach tab until they signed out and back in. It now
  runs at launch and on foreground.

- **`player_state.drills_completed` was dead** — the column existed from the
  start, the app never wrote it and nothing read it, so it was permanently 0
  while looking like real data on the coach's screen. Now written on every
  state sync as the count of distinct drills with at least one logged pass
  (derived from `DrillProgress` rather than stored locally, so there is no
  second source of truth to keep in step), and read back into the coach's
  player detail, AI briefing and exported report. "3 mastered" reads the same
  for a player who has tried four drills and one who has tried ninety; it now
  says "3 of 41 started" — drills *started*, not the size of the curriculum.

  Two things the display sites have to allow for. A `player_state` row written
  before this shipped reports 0, which is every player until their device next
  syncs, so each site falls back to the old wording rather than printing "12 of
  0". And the numerator and denominator come from different machines — mastery
  from server `player_progress` rows that are never deleted, the denominator
  recounted from local `DrillProgress` and overwritten wholesale — so a player
  who reinstalls, declines the restore prompt and logs one drill would report
  "40 of 1". `CoachPlayerDetail.drillsStarted` clamps it; display sites read
  that, never the raw column.

- **Coach drill-media uploads DO have a server-side role check** — audit item
  #38 was already closed by `2026-08-05-storage-and-coach-access.sql` and this
  page was stale. Verified 2026-08-08 by impersonation against
  `storage.objects`, in a transaction, rolled back:

  | Caller | INSERT into `drill-videos` |
  |---|---|
  | plain player (not a coach) | **blocked**, 42501 |
  | active coach with a `user_id` | allowed |
  | active coach with email only, no `user_id` | allowed |

  Both coach identity forms work because the `_v2` policies test
  `is_active_coach()`, which resolves by JWT email or `user_id`. The older
  `drill media coach write/update/delete` policies test `user_id` only; they
  are redundant rather than harmful, since policies are OR'd, and were left
  alone rather than risk the upload path that took three fixes to get working.

- **Every coach could read every child** — audit item #36.
  `2026-08-08-coach-roster-scoping-APPLIED.sql`, applied and verified by
  impersonation. Note that the earlier staged version of this
  (`2026-08-05-coach-roster-scoping.sql`) is **superseded and must not be run**:
  it backfilled from `roster_invites`, which is empty, so it would have linked
  nobody and cut every non-head coach off from every player.
