# Project Changelog

All notable changes to Strata. Follows [Keep a Changelog](https://keepachangelog.com) format.

---

## [Unreleased] — v1.0 Release Preparation

_Branch: main, 2026-03-09 onward_

### Security
- Remove debug OTP code from API responses
- Add rate limiting (per-IP and per-install) to auth/entitlement endpoints
- Fix device seat TOCTOU race condition (atomic INSERT with conflict guard)
- Handle `license_key.revoked` and `payment.refunded` webhooks
- Fix tier precedence state bug (VIP/Pro ordering)
- Remove CORS headers (native app, no browser clients)
- Remove all legacy email-only code paths

### Fixed
- Critical: SwiftData silent in-memory fallback causing data loss on schema mismatch

### Added
- VersionedSchema + MigrationPlan (V1→V2) for CustomFieldDefinitionModel / CustomFieldValueModel
- Pre-migration store backup to Application Support
- DataErrorView shown on container init failure
- CRON scheduled cleanup every 6h (expired OTPs, sessions, device records)
- Anomaly logging for account-sharing detection (fire-and-forget)
- Ed25519 key rotation support (`kid` claim in token header)

---

## [0.9.0] — 2026-03-03

### Added
- Email OTP authentication (passwordless, via Resend)
- User system: `users` table, session management, 30-day bearer tokens
- Device seat management: Free 1 / Pro 2 / VIP 3 active devices
- Auth-gated restore, resolve, and checkout endpoints
- Account sign-in UI (email entry, OTP verification)
- Manage Devices view in Settings (list + revoke)
- Auth session revoke endpoint

### Changed
- Checkout, restore, and resolve routes now require verified session
- Entitlements bound to `user_id` (not email)

---

## [0.8.0] — 2026-02-28

### Added
- Entitlement backend integration in Swift app (restore, resolve, checkout flows)
- DodoPayments API client (`DodoPaymentsClient.swift`)
- KeychainService extensions for entitlement token storage
- Secure Enclave install proof: P-256 ECDSA challenge-nonce protocol
- Ed25519 server-signed entitlement tokens (72h TTL, install-bound)
- `install`, `challenge`, `restore`, `resolve`, `checkout`, `portal` backend routes
- Webhook handler: `license_key.activated`, `subscription.active` → `user_entitlements`
- User backfill migration: legacy email entitlements → user_id mapping

### Fixed
- Prevent duplicate main windows on deep-link callbacks

---

## [0.7.0] — 2026-02-22

### Added
- Inline Enhance: system-wide text enhancement using Accessibility API
- InlineEnhanceHUD with shimmer animation and Strata S logo
- Developer ID code signing and notarization
- Screenshot paste support in Enhance Me view

### Changed
- Project renamed from TaskManager to Strata
- App icon redesign

### Fixed
- Inline enhance reliability across browsers and Electron apps
- Duplicate text in Warp terminal (clipboard paste retry guard)
- AX handling stabilization for text replacement flow

---

## [0.6.0] — 2026-02-18

### Added
- Custom fields system: text, number, currency, date, toggle types
- Premium + VIP tier structure (Pro $4.99/mo, VIP $99.99 lifetime)
- Light/dark mode support with appearance settings
- Kanban board animations
- Tag autocomplete
- AI typewriter effect in EnhanceMe panel
- Menu bar icon

### Fixed
- Code review issues (Oracle-validated)
- File size refactoring (200 LOC limit)

---

## [0.5.0] — 2026-02-13

### Added
- Calendar view (monthly, with task indicators)
- Timer-based reminders with duration picker and sound preview
- Priority filter section in sidebar
- Global keyboard shortcuts: Quick Entry, Enhance Me, Main Window
- Tag filtering and enhanced sidebar features

### Fixed
- Persistence, import/export, and settings flows hardened
- SwiftUI List selection and Sheet binding issues
- Search bar empty state overlap

---

## [0.4.0] — 2026-02-05

### Added
- AI integration: protocol-based provider system (Gemini, z.ai)
- Built-in AI modes: Correct Me, Enhance Prompt, Explain
- Enhance Me floating panel (global shortcut)
- Custom AI modes with user-defined prompts
- Quick Entry panel (global shortcut)
- Settings window

---

## [0.3.0] — 2026-02-03

### Added
- Initial app with SwiftData persistence
- Task CRUD: title, description, status (Todo / In Progress / Completed)
- Tags with pastel chip display
- Priority levels (None → Critical), due dates
- Photo attachments (stored in Application Support)
- List view with sorting, search, and filtering
- Data import/export (JSON backup/restore)
