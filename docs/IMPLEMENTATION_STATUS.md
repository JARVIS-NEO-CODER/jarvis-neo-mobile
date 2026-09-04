# JARVIS NEO Mobile

## Implemented foundation
- Flutter Android/iOS application shell
- Dark/light Material 3 UI
- JARVIS conversation screen
- Groq API configuration stored locally, never hard-coded
- Token-budget protection / context compaction
- Device hub foundation
- Files/AI actions surface
- Routines surface
- Sentinel/security surface
- Adaptive security policy with mandatory manual payment confirmation
- Preferences persistence
- Android/iOS GitHub Actions build pipelines

## Architecture targets
The mobile client is intentionally capability-driven. Native capabilities should be added behind platform adapters and explicit runtime permissions. PC control, remote desktop, Google Home, calls/messages, camera intelligence, location, NFC/Bluetooth, notifications, and cloud synchronization require corresponding native services and/or the JARVIS NEO PC backend.

## Safety / privacy invariants
- API keys are user-provided and not committed to source.
- Payment confirmation is always manual.
- Sensitive capabilities require explicit permissions.
- Offline/local fallback is preferred when cloud AI is unavailable.
- Token-heavy context is compacted before cloud requests.
