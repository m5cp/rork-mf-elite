# Strip Supabase & auth — local-only V1

V1 ships as a standalone, local-only training app. All data lives in SwiftData on-device. Supabase, authentication, and coach self-service are deferred to V2.

## Done in this patch

- [x] Removed all Supabase code, services, and the SPM package
- [x] Removed all authentication (no Sign in with Apple/Google/Rork Auth)
- [x] Removed the Coach Workspace and every coach view + coach role logic
- [x] Removed the announcements system
- [x] Simplified onboarding: Splash → Code → Identify → Position → Pledge → Number → Passport (no sign-in step)
- [x] Removed member-number concept (no backend to issue real sequential numbers)
- [x] Simplified Settings: no sign out, no delete account, no coach access; added on-device data note
- [x] Subscription gating now keyed off RevenueCat only
- [x] Family management works fully locally (no remote sync)
- [x] Drill progress saves locally only (no progress sync)
- [x] Player report uses hardcoded Coach Matteo Finazzi note

## Stays the same

- Full curriculum from bundled JSON, drill player, XP/streak/progression, certifications
- Today, Academy Hub, search, library, routines, streak detail, progression, badges
- RevenueCat paywall and content gating, local notifications, design system
