# Remove forced sign-in for players, coach-only Google login, and zero out all fake data

## What changes

### 1. Players never have to sign in

- Right after "The Code" screen, players go **straight into building their profile** — name, position, pledge, kit number, passport. No Apple ID, no email, no password.
- A player's profile and progress live on their device. Creating a profile is instant and frictionless.

### 2. Coaches are the only ones who sign in

- The sign-in step becomes **optional**, not forced. The screen will show a clear primary action to **"Continue as a player"** and a smaller secondary option: **"MF Elite Coach? Sign in."**
- Coaches sign in with **Google (Gmail)** so their email matches the authorized coaches list. If their email is on the list, they're recognized as a coach and taken straight to the home screen with full access — skipping all the player setup steps.
- If someone who isn't on the coaches list signs in, they're simply treated as a regular player (no coach powers).

### 3. New onboarding flow

- **Player sees:** Splash → The Code → Continue as player → Identify → Position → Pledge → Number → Passport → Home.
- **Coach sees:** Splash → The Code → Coach sign in → Home.
- The progress bar at the bottom of each step updates to reflect the player's steps (no longer counts a sign-in step).

### 4. Everything starts at zero — no fake data

Across the entire app, nothing is pre-filled with made-up numbers or sample people:

- **Streaks, XP, levels, and stats** all start at zero for a brand-new profile.
- Any leftover "14-day streak" sample text and example stat values are removed or shown as real zeros/empty states.
- **Coach roster** no longer shows a fake example athlete — it starts empty until real players exist.
- **Family / multiple athletes** starts empty.
- **Parent report and progress screens** show clean empty states instead of placeholder data.
- The fixed "Coach Matteo Finazzi" placeholder name is no longer hard-coded into a new player's profile.

### Design / feel

- The new "Continue as a player" screen keeps the same cinematic dark MF Elite styling — bold MF mark, the same typography and diagonal-stripe backdrop — so it feels like a natural part of the admission flow, not a barrier.
- Empty states (no streak yet, no athletes yet, no progress yet) get short, encouraging copy rather than blank space, so the app still feels intentional on day one.

### Notes

- Because players no longer have accounts, their data stays on-device and won't sync to the cloud. Coaches (who do sign in) keep full cloud access to manage curriculum and content.
- After the changes I'll run a full build check to make sure everything compiles cleanly.

