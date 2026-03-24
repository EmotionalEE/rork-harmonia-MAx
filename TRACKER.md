# TRACKER

## App Shell / Architecture
- [x] SwiftUI app shell
- [x] Root navigation structure
- [x] Startup loading state
- [x] Startup retry/error state
- [x] App-wide theme styling
- [x] Config.swift environment usage

## Providers
- [x] AuthProvider equivalent
- [x] UserProgressProvider equivalent
- [x] JournalProvider equivalent
- [x] AudioProvider equivalent
- [x] VibroacousticProvider equivalent

## Types / Constants / Utilities
- [x] Session types
- [x] emotional states constants
- [x] sessions catalog constants
- [x] color constants
- [x] date/format utilities
- [ ] backend auth routes
- [ ] JWT helper
- [ ] user store

## Routes / Screens
- [x] `/` Home
- [x] `/welcome`
- [x] `/onboarding`
- [x] `/intro-session`
- [x] `/session`
- [x] `/end-reflection`
- [x] `/feelings-chat`
- [x] `/insights`
- [x] `/profile`
- [x] `/subscription`
- [x] `/journal-entry`
- [x] `/reset-password`
- [x] `/terms`
- [x] `/vibroacoustic-settings`
- [ ] `+not-found`
- [ ] `+native-intent`

## Shared Components
- [x] AIChatModal
- [x] EmotionIcons
- [x] HarmoniaJournal
- [x] SessionAudioControls
- [x] SessionGeometry
- [x] SynchroGeometry
- [x] SacredGeometry

## Feature Restoration Status
- [x] welcome gating
- [x] onboarding gating
- [x] intro session routing
- [x] home emotion filter strip
- [x] session cards
- [x] AI chat launch
- [x] session playback shell
- [x] playback controls
- [x] vibroacoustic settings surface
- [x] post-session reflection flow
- [x] daily journal storage
- [x] profile editing shell
- [x] insights dashboard
- [x] paywall UI demo
- [x] terms screen
- [ ] real backend auth
- [ ] real purchases
- [ ] remote AI integration
- [ ] custom uploaded avatar pipeline

## QA / Polish
- [x] safe area handling
- [x] loading/empty/error states
- [x] button press micro-interactions
- [x] major action testIDs
- [ ] exhaustive parity with original Expo backend/web behaviors
