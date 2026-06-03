# Fix sign-in, splash flash, fake streak, free tier value, and remove film

## What I'll fix

### 1. Splash flash on launch

Right now the home screen briefly appears before the splash/onboarding shows. I'll make the splash appear instantly on every launch and hold it until the app has finished checking whether you're signed in — so new users see a clean splash → The Code → sign-in, and returning users see the splash then go straight home. No more home-then-splash flicker.

### 2. The fake 14-day streak

New users are currently seeded with a "demo" player that pretends they already have a 14-day streak and a pile of completed drills. I'll change this so a brand-new player starts at zero — 0-day streak, no XP, nothing marked complete. The full curriculum still loads; only the fake progress is removed. Anything that hardcodes "14-day streak" in copy (e.g. the parent report sample text) will be made dynamic or neutral.

### 3. Sign in with Apple not working

I'll harden the sign-in so it can't silently stall: clear loading feedback on the button, a visible error if Apple auth fails or times out, and a reliable retry. This makes the "Sign in with Apple" button actually complete and move you into the app.

### 4. Free tier — real, enticing value

Today the messaging makes free look like "Level 1 only." The app already unlocks **Level 1 of every discipline and category** for free — a real taste of the whole academy. I'll fix the paywall and comparison copy to clearly sell this: free users explore Technical, Physical, Tactical, and Psychological pathways at Level 1, and Elite unlocks every level beyond. This makes the freemium split honest and compelling.

### 5. Remove all "film" features and mentions

There is no film study or film vault, so I'll remove every reference to it:

- Remove "Tactical film library" / "Intro film session" / "Full tactical film library" from the paywall and comparison screens.
- Remove "Film Library" from the post-purchase welcome perks.
- Replace the "Daily film — watched" daily goal on the home screen with a real goal (a technical drill focus).
- Relabel the drill detail's "DEMO film" header to simply a demo preview, so no "film" wording remains anywhere.

## Design

Everything stays in the existing black, mono-accent MF Elite aesthetic. The free-vs-Elite comparison will read cleanly with the film rows replaced by genuine pathway value, and the welcome perks will reflect what users actually get.

## After this

- Clean splash with no flicker on launch
- New players start at zero (no fake streak or fake completed drills)
- Sign in with Apple completes reliably with proper feedback
- Free tier clearly offers Level 1 across every discipline
- No mention of film anywhere in the app

