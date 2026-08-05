# backend/schema.sql is not the source of truth

**Audited 2026-08-05 against the app at commit `9a0a932`.**

`schema.sql` opens by presenting itself as the schema for this project. It
declares **17 tables**. The iOS app reads or writes **30**. Anyone who
provisions a new Supabase project from this file gets an app that appears to
work and then fails, silently, on most of what a player does.

It is also the reason a whole class of bug is invisible: the sync engine
classifies a 4xx as a permanent failure and quarantines the operation, so a
write to a column that doesn't exist doesn't crash or retry — it just never
arrives, and the player's data stops syncing with no error anywhere.

## Tables the app uses that this file does not declare

```
admin_audit           drill_results        session_logs
app_config            game_entries         share_xp_events
coach_workouts        gameiq_completions   support_adjustments
combine_results       progress_reports     team_events
content_overrides     team_members         teams
curriculum_edits      user_badges          user_favorites
custom_workouts       workout_records      xp_transactions
drill_notes
```

That is 22 tables, including the ones carrying every session a player has ever
logged (`session_logs`), every combine score (`combine_results`), and every
purchase (`xp_transactions`).

## Columns missing from tables that ARE declared

Confirmed by reading the write sites in `Services/Sync/`:

| Table | Column the app writes | Written at |
|---|---|---|
| `player_state` | `purchased_xp` | `SyncEngine.enqueuePlayerState` |
| `player_profiles` | `ballon_dor_requested_at` | `SyncEngine` (Ballon d'Or request) |
| `player_profiles` | `position_code`, `birth_year` | `RemoteProfileSync` |
| `player_profiles` | `avatar_kind`, `avatar_builtin`, `avatar_url` | `RemoteProfileSync` |
| `player_profiles` | `coach_focus` | `CoachViewModel.saveCoachFocus` |
| `announcements` | `audience`, `target_team_ids`, `target_player_ids` | `MyTeamsStore` |

`player_state.purchased_xp` is the one to check first. If it is genuinely
absent in production, **every** `player_state` upsert returns 400 and gets
quarantined — meaning XP, streak and freeze counts never reach the server for
anyone, and the coach dashboard slowly drifts out of date with no visible
error.

## Functions the app calls that this file does not define

- `delete_account()` — called by `SupabaseAuth.deleteAccount`
- `my_coach_role()` — called by `SupabaseAuth.refreshCoachStatus`

(`username_available`, `claim_roster_invite` and `redeem_roster_invite` are
defined here and are fine.)

## Storage

The app uploads to a `player-media` bucket that isn't described anywhere in
this file, and coach drill-video uploads have no server-side restriction — the
coach-only rule is enforced in the UI only. Anyone with an authenticated
session can write to that bucket.

## Declared here but unused by the app

`categories`, `certifications`, `daily_quotes`, `disciplines`, `drills`,
`families`, `levels`, `member_counter`, `progression_rules`.

Some of these are deliberate (the curriculum ships bundled in the app rather
than being served). But `player_progress.drill_id` is a foreign key to
`drills.id`, and if `drills` is empty in production then every mastery upload
fails that constraint — this was diagnosed and worked around in July, and it is
worth confirming it stayed fixed.

## How to make this file authoritative again

Do not hand-edit it. Dump the live schema and replace the file:

```bash
# Structure only, public schema, no ownership noise
pg_dump "$SUPABASE_DB_URL" \
  --schema=public \
  --schema-only \
  --no-owner \
  --no-privileges \
  > backend/schema.sql
```

Or, if you'd rather keep the current file's hand-written comments (they're
genuinely useful — the RLS reasoning in particular), dump to a second file and
reconcile:

```bash
pg_dump "$SUPABASE_DB_URL" --schema=public --schema-only --no-owner > /tmp/live.sql
diff <(grep -oP '(?<=CREATE TABLE )[a-z_.]+' /tmp/live.sql | sort) \
     <(grep -oiP '(?<=CREATE TABLE IF NOT EXISTS )[a-z_]+' backend/schema.sql | sort)
```

The connection string is in the Supabase dashboard under Project Settings →
Database → Connection string (use the session pooler URI).

Once it's regenerated, the migration in `backend/migrations/` can be validated
against it properly — right now its section 5 is commented out precisely
because the real column names for `session_logs` and friends aren't knowable
from this repo.
