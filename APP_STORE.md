# MF Elite — App Store Connect Listing

Reference for pasting into App Store Connect. Code-side compliance (privacy manifest, entitlements, account deletion, PDF/cert sharing, restore + auto-renewal) lives in the app.

## App information

- **Title:** MF Elite — Academy Training
- **Subtitle:** Train. Master. Rise.
- **Primary category:** Health & Fitness
- **Secondary category:** Sports
- **Bundle ID:** app.rork.pgx8pb996dmcvbhdfnx8x
- **Version:** 1.1.0

## Keywords (100 char max)

```
soccer,training,drills,academy,youth,coaching,fitness,skills,mastery,streak,elite,athlete,touch
```

## Promotional text (170 char max)

```
Train like the elite. Master drills, earn certifications, build streaks, and rise through academy ranks.
```

## Description

```
MF Elite is the training app for serious young soccer players — built by a professional coach, powered by a real academy curriculum, and now with an Apple Watch companion so you can train anywhere.

BUILT BY COACH MATTEO FINAZZI
MF Elite Training is founded by Coach Matteo Finazzi — a former professional player born in Argentina and raised in Spain, who came up through Atlético de Madrid's academy (through U19) and went on to play professionally for Lyn FK in Norway. Matteo brings 10+ years coaching high-level players across five top soccer nations — Spain, Norway, England, Portugal, and the USA — including a 2025 Player of the Year and 2025 Offensive Player of the Year. His academy coaches 1,000+ players a year on the field, and the same curriculum, standards, and coaching points now live in your pocket.

FOUR DEVELOPMENT PATHWAYS
Progress through Technical, Physical, Tactical, and Psychological training — the four pillars of elite player development.

STRUCTURED CURRICULUM
Train through mastery levels, complete drills, and earn certifications. Every drill has coaching points, a timed challenge, and an honor-code accountability system.

APPLE WATCH COMPANION
Train with the MF Elite watch app on your wrist. Glance at today's session, your activity rings, streak, and daily steps; run a drill session with on-wrist timers and haptics between sets; and quick-log a completed session without your phone. Everything syncs both ways — your streak, XP, and training history stay consistent across iPhone and Apple Watch. Add the watch-face complication for a one-tap start.

STEP TRACKING
The Progress tab shows your daily steps against a goal you set. With your permission, steps are read from Apple Health (covering both iPhone and Apple Watch) — read-only, and never shared.

STREAK ENGINE
Build daily training habits. Track your streak, earn freeze tokens, and hit milestones from Week One to Century.

ACADEMY RANK
Rise through the ranks: Trialist, Cadet, Prospect, Starter, Captain. Every drill earns XP toward your next rank.

COACH-MANAGED CONTENT
Your coach updates drills, progression rules, and daily motivation through the admin workspace — no app update needed.

PARENT REPORTS
Monthly progress reports with training consistency, certifications earned, and a formal academy report card.

CERTIFICATIONS
Master every level in a category to earn a Skill Certification — signed by your coach and added to your academy record.

Train every day. Master every touch. Rise through the academy.
```

## Screenshot copy (5)

1. **Today** — "Your daily training, structured" / "Daily goals, coaching quotes, and your pathway — all in one place."
2. **Curriculum** — "Four pathways to elite" / "150+ drills across Technical, Physical, Tactical, and Psychological development."
3. **Drill Player** — "Train with purpose" / "Timed drills with coaching points and honor-code accountability."
4. **Certifications** — "Earn your certifications" / "Master every level. Get coach-signed certifications on your record."
5. **Streak** — "Build the habit" / "Daily streaks, freeze tokens, and milestones from Day 1 to Century."

## App Review notes

```
OVERVIEW
MF Elite is a structured soccer training app for youth athletes (10+). Players follow a curriculum of drills across four pathways (Technical, Physical, Tactical, Psychological), build streaks, earn XP/ranks, and collect coach-signed certifications. Built for use with parental oversight.

GETTING IN / TEST ACCOUNT
- A test account is provided in the App Store Connect "Sign-In Information" fields.
- Email: appreview@mfelite.app
- Password: MFelite-Review-2026
- Sign in with Apple is supported; you may also use email/password sign-up. The provided test account uses email/password.
- This reviewer account is on the coach allowlist, so the Coach tab/dashboard unlocks automatically after sign-in.
- Onboarding can be skipped at any time via the "Skip" button.
- There is NO login PIN or invite code gate. Account access is via Sign in with Apple or email/password only.

COACH WORKSPACE (NO PIN)
- The provided test account's email is registered as a coach in our backend (Supabase). After signing in, the extra "Coach" tab appears automatically.
- Coach access is granted purely by a server-side email allowlist — there is no separate coach password or PIN.

ACCOUNT DELETION (Guideline 5.1.1(v))
- Because the app supports account creation, in-app account deletion is provided.
- Profile -> Settings -> Account/Sync -> "Delete account" (visible only when signed in).
- Behind a "this can't be undone" confirmation. On confirm, a server-side function permanently deletes ALL of the user's data (training logs, progress, profiles, certifications, etc.) and the auth user, then clears local data and returns to a signed-out state. Completes entirely in-app — no email or website required.

SIGN IN WITH APPLE
- Fully supported. We only request name/email; no other Apple data is accessed.

GAME CENTER
- Used for optional leaderboards (weekly XP) and achievements. Players are authenticated via Game Center on launch if signed in; it is not required to use the app.

HEALTHKIT
- Optional. With permission, completed training sessions can be written as workouts. Health data is never sold or shared; it is not required to use the app.

SUBSCRIPTIONS (RevenueCat)
- In-app subscriptions are handled via RevenueCat over StoreCat/StoreKit. Use a Sandbox Apple ID to test. Prices and the paywall load dynamically.
- "Restore Purchases" and auto-renewal disclosure are present on the paywall.

PRIVACY / DATA
- Privacy manifest included. No tracking (NSPrivacyTracking = false), no third-party ad SDKs, no IDFA.
- Backend is Supabase, accessed client-side with a publishable (anon) key protected by row-level security. No user-generated content is shared publicly between users.

PARENT GATE (OPTIONAL)
- The app has an optional 4-digit Parent Gate (Profile -> Settings) a parent can set to lock purchases/family settings. It is OFF by default and is NOT required to review the app.

CONTENT MANAGEMENT
- Drills, progression rules, and daily motivation are managed by the coach via the in-app admin workspace — no App Store update needed.

AUDIENCE
- Designed for youth athletes (10+) with parental oversight.

CONTACT: mf.elitetraining@gmail.com
```

## What's New / App Review notes — version 1.1.0 update

This is an update to an already-approved app. Below is what changed in 1.1.0 so the reviewer knows exactly where to look. Nothing about the sign-in flow, subscriptions, account deletion, or content management has changed — see the notes above, which still apply.

```
WHAT CHANGED IN 1.1.0 (update to a previously approved app)

1. APPLE WATCH COMPANION APP (new)
- The build now includes a bundled Apple Watch app (watchOS target) plus a watch-face complication.
- On the watch you can: glance at today's session, activity rings, current streak, and today's step count; run a drill session on the wrist with set/rest timers and haptics; and quick-log a completed session.
- The watch and iPhone stay in sync through WatchConnectivity — a quick-log on the watch flows back through the SAME session-logging pipeline used on the phone, so streak, XP, and history update everywhere. No separate account or login is used on the watch.
- WHERE TO SEE IT: install on an iPhone paired with an Apple Watch, then open the MF Elite watch app. (The watch app cannot be exercised in the iOS Simulator; it is excluded from iPhone-simulator installs only and ships fully on device/TestFlight builds.)

2. STEP TRACKING (new, optional)
- Progress tab now has a "Today's Steps" card (below the training rings, above the leaderboard) that shows today's steps against an adjustable daily goal.
- This is READ-ONLY from Apple Health and is optional: on first use the app requests permission to READ step count only. If declined or unavailable, the app behaves exactly as before. We still never READ any other Health data, and we continue to WRITE completed sessions as workouts as in 1.0.0.
- New usage string: NSHealthShareUsageDescription (read steps). NSHealthUpdateUsageDescription (write workouts) was already present.

3. NAVIGATION CHANGES (no features removed)
- The first tab "TODAY" was renamed to "HOME". Same screen, same behavior.
- The separate "Train" tab was merged into the "MF Hub" tab: Routines, My Plan, Coach's Workouts, and Continue Your Pathway now live inside MF Hub. The player tab bar is now four tabs (Home, MF Hub, Progress, Profile). The Coach tab still appears for allowlisted coach accounts.
- All existing deep links / shortcuts that pointed at the old Train tab now resolve to the corresponding place inside MF Hub, so nothing is unreachable.

4. SESSION PLAYER TRANSPORT CONTROLS (minor)
- Added Previous drill, Restart set, and Restart drill controls to the in-session player. These do not affect XP, logging, or streaks.

ENTITLEMENTS / CAPABILITIES ADDED FOR THIS UPDATE
- App Group (shared between iPhone and Apple Watch) for phone-watch data sync.
- HealthKit read access for step count (write access was already used in 1.0.0).

NOTHING ELSE CHANGED: sign-in (Apple / email+password), coach allowlist, in-app account deletion, RevenueCat subscriptions + Restore Purchases, Game Center, privacy manifest, and coach-managed content all work exactly as described in the notes above.

CONTACT: mf.elitetraining@gmail.com
```

## Data collection (App Privacy)

Mirrors `PrivacyInfo.xcprivacy`. All linked to identity; **no tracking**.

- Name, Email address (Sign in with Apple), Fitness (training sessions), User ID, Product interaction (usage), Purchase history.
- Not collected: location, contacts, browsing/search history, photos/videos.
