# Fix onboarding number, real member ID, class year, level state, and remove placeholder stats

## What I'll fix

**1. Stray letter in the number box**
On the "Pick your number" screen, the badge currently draws the player's initial (the "J") behind the big number, so it reads like "2J2". I'll make the badge show only the number cleanly, with no letter behind it.

**2. Real member number (no more made-up number)**
Right now every player gets a random 4‑digit number. Instead, each new profile will get the **next number in line based on how many profiles already exist in your database** (member #1, #2, #3…), saved permanently to that player. If the phone is offline at sign‑up, the app will **wait and assign the real number once it syncs** rather than showing a fake one — so the number on the passport is always accurate and tied to a real subscriber/profile.

**3. Class year shows as "2,029"**
The welcome line still prints the year with a comma. I'll make the class year always display as a clean four‑digit year (e.g. "2029") everywhere it appears, with no comma.

**4. "Resume level" when nothing's been started**
On the Today screen, the pathway card says "Resume level" even at 0 of 4 drills. I'll make it say **"Start level"** when the player hasn't begun, and only say "Resume level" once they've actually made progress.

**5. "Parent report" → "Player report" everywhere**
I'll rename it to "Player report" across the app — the paywall feature list, the paywall description text, the report screen itself, and the coach tools that create it.

**6. Remove the fake 86% consistency**
The report card shows a hardcoded 86% "consistency" score. I'll make all the report stats reflect **real training data**, so a brand‑new player correctly shows 0% until sessions are logged. As drills are completed, those logged sessions sync to your database and feed the consistency score and XP, so the scores grow from genuine activity.

## Notes

- All numbers and stats default to zero/empty for a fresh account since the app isn't live yet.
- I'll build the app to confirm everything compiles cleanly before handing back.

