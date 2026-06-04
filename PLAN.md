# Add player avatars (photo or built-in) and remove the swipe-typing popup

## Avatars on the player card & profile

**What you'll be able to do**
- On your player card (the white passport during onboarding) and the profile header, the plain photo box / initials badge becomes a tappable avatar.
- Tapping it opens a chooser where you can **upload a photo from your library** or **pick from a set of built-in MF avatars**.
- Your chosen avatar is saved on your device and shown on both the passport card and the profile screen.

**Editing your profile**
- In the profile screen you'll be able to **change your avatar, edit your name, and edit your kit number** in one place (a simple "Edit profile" sheet), with changes saved instantly.

**Design**
- The avatar sits in the same spot as today's photo placeholder — a clean rounded square on the passport card and a circular avatar on the profile header, matching the app's black-and-white editorial style.
- Built-in MF avatars will be simple, on-brand monogram/crest style tiles so they look intentional, not generic.
- A small camera/edit glyph overlays the avatar so it's clear it can be changed; tapping gives haptic feedback.

## Remove the "Speed up your typing" popup
- The popup is an iOS system tutorial that appears the first time the keyboard opens (on the name screen). I'll quietly trigger and dismiss it in the background at app launch so you never see it interrupt onboarding.

## Screens affected
- **Onboarding passport card** — photo box becomes the chosen avatar.
- **Profile header** — initials badge becomes the chosen avatar, plus a new "Edit profile" sheet for avatar, name, and number.
