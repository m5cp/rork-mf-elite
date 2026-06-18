# MF Elite — App Store Connect Listing

Reference for pasting into App Store Connect. Code-side compliance (privacy manifest, entitlements, account deletion, PDF/cert sharing, restore + auto-renewal) lives in the app.

## App information

- **Title:** MF Elite — Academy Training
- **Subtitle:** Train. Master. Rise.
- **Primary category:** Health & Fitness
- **Secondary category:** Sports
- **Bundle ID:** app.rork.pgx8pb996dmcvbhdfnx8x
- **Version:** 1.0.0

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
MF Elite is the training app for serious young soccer players. Built around a structured academy curriculum, it transforms daily practice into measurable development.

FOUR DEVELOPMENT PATHWAYS
Progress through Technical, Physical, Tactical, and Psychological training — the four pillars of elite player development.

STRUCTURED CURRICULUM
Train through mastery levels, complete drills, and earn certifications. Every drill has coaching points, a timed challenge, and an honor-code accountability system.

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
- Sign in with Apple is supported; you may also use email/password sign-up. The provided test account uses email/password.
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

## Data collection (App Privacy)

Mirrors `PrivacyInfo.xcprivacy`. All linked to identity; **no tracking**.

- Name, Email address (Sign in with Apple), Fitness (training sessions), User ID, Product interaction (usage), Purchase history.
- Not collected: location, contacts, browsing/search history, photos/videos.
