# Secure player profiles: unique usernames, coach roster (create/edit/reset), family enrollment & privacy boundaries

## Goal

Make sure a player's profile can be created either by the player or by a coach, always lands in the right shape, and stays private — coaches see training info, never personal/financial data. do not use the word child. each child should be called athlete. 

## How profiles get created

- **Player self-signup**: during onboarding the player picks a **unique username**. If it's already taken, the app says so and makes them choose another before continuing. Their name, kit number, and position are saved.
- **Coach pre-creates**: from the admin area a coach can add a player with name, kit number, position and an **invite code**. Entering a code is **optional and never blocks sign-up** — onboarding flows straight through without one. A player who has a code can redeem it any time from **Settings → Redeem a code**, and the coach's details merge into their existing profile automatically (their own username is preserved). the coach has to have a method to create that invite code. it can be a one time code that he creates when he sets up the coach profile. it has to fit the format of the app currently. it is only for players who have subscribed or on a free trial. when the trial goes away, the coach maintain access to the file in case the user resubscibes. the user loses access to the progress and other paid services once the trial ends or they do not resubscribe at the appropriate time.
- **Coach edits later**: a coach can update a joined player's name, kit number, or position at any time.
- **Coach reset**: if a player's info breaks, the coach can reset it from the admin and the player re-enters details on next launch.

## Uniqueness & validation rules

- **Username must be unique** across all users (case-insensitive). Enforced both in the app and at the data layer so two people can never share one — important at scale (thousands of users).
- **Kit numbers and fun identifiers can overlap** — no uniqueness forced there.
- **Positions** come from a fixed set (Goalkeeper, Defender, Midfielder, Forward, Winger, No preference).
- **Names** just need to be non-empty with a sensible length cap.
- Both the player path and the coach path run through the **same checks**, so data is always stored in one consistent format.

## Families

- One **parent/household account** can manage **multiple athlete** under a single login (each athlete is a separate player card with its own username, kit, and progress).
- An athlete who wants to train under their **own separate login** can do so instead — their profile lives on their own account.
- Coaches see each athlete as an individual player on the roster.

## Privacy & data security

- Profile data is split into two layers:
  - **Shareable (coach can see)**: username, display name, kit number, position, rank/XP, streaks, certifications, drill progress — same as typical training apps.
  - **Private (coach can NEVER see)**: email, account/sign-in identity, and subscription/billing status.
- Coaches can only read and write the shareable roster fields; the private layer is locked to the owner only. This is enforced at the data layer, not just hidden in the UI.

## Screens

- **Onboarding** gets a username step with live "this name is taken" feedback.
- **Coach admin → Squad roster**: shows real players from the server (no longer mock data), with **one example placeholder entry that is clearly marked and never appears in the player-facing app**, plus an "Add player" form (name, kit, position, generated invite code).
- **Coach player detail**: edit roster fields, see training progress, and a "Reset player info" action.
- **Redeem a code** (optional): a standard "Redeem a code" action in Settings that opens Apple's native App Store offer/promo code redemption sheet. It accepts whatever code format App Store Connect generates (not a fixed 6-char code) and uses no custom keyboard input, so no system swipe-typing tooltip appears. It is never part of the onboarding gate.

## Behind the scenes

- A documented data model + security rules for: shareable player records, private personal records, families, and coach invite codes.
- A small shared validation layer reused by both onboarding and the coach admin so nothing can be saved in the wrong format.
- The placeholder/example roster entry is flagged so it stays out of the player experience and any real reports.

I'll build the data model + security rules, the shared validation, the onboarding username step, and the coach admin roster (with the single hidden example), then verify the iOS build is clean.