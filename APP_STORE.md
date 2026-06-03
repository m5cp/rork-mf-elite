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
soccer,football,training,drills,academy,youth,coaching,fitness,skills,mastery,streak,elite,athlete
```

## Promotional text (170 char max)

```
Train like the elite. Master drills, earn certifications, build streaks, and rise through academy ranks.
```

## Description

```
MF Elite is the training app for serious young footballers. Built around a structured academy curriculum, it transforms daily practice into measurable development.

FOUR DEVELOPMENT PATHWAYS
Progress through Technical, Physical, Tactical, and Psychological training — the four pillars of elite player development.

STRUCTURED CURRICULUM
Train through mastery levels, complete drills, and earn certifications. Every drill has coaching points, a timed challenge, and an honour-code accountability system.

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
3. **Drill Player** — "Train with purpose" / "Timed drills with coaching points and honour-code accountability."
4. **Certifications** — "Earn your certifications" / "Master every level. Get coach-signed certifications on your record."
5. **Streak** — "Build the habit" / "Daily streaks, freeze tokens, and milestones from Day 1 to Century."

## App Review notes

```
Test account: Will be provided via App Store Connect.

Onboarding does NOT require an invite code — sign-up flows straight through. A coach invite code is optional and can be redeemed later via Settings → Redeem a code (Apple's native code redemption sheet).

Coach admin is accessible from Profile → Settings → Coach workspace. Coach passcode: 1234

The app uses RevenueCat for subscription management. A sandbox Apple ID can be used to test purchases. Restore Purchases is available on the paywall and in Settings → Subscription.

Curriculum content (drills, categories, levels) is managed remotely via Supabase. The app ships with seed data for offline/first-launch use.

No user-generated content is uploaded. Players log drill completions via an honour-code self-report system (no video recording or upload). Coach demo films are a future feature.

Account deletion is available in-app: Settings → Delete account. It removes all remote player records and local data, then returns to onboarding.
```

## Data collection (App Privacy)

Mirrors `PrivacyInfo.xcprivacy`. All linked to identity; **no tracking**.

- Name, Email address (Sign in with Apple), Fitness (training sessions), User ID, Product interaction (usage), Purchase history.
- Not collected: location, contacts, browsing/search history, photos/videos.
