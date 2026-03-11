# Strata — Feature & Project Status

_Last updated: 2026-03-10 (v1.0 GA)_

---

## What's In Progress

| Work Item | Status | Plan |
|-----------|--------|------|
| v1.0 Release Preparation | **Phase 5 (Documentation)** | [Active plan](../plans/260309-1600-v1-release-preparation/plan.md) |

---

## What's Done

### Product Features — All DONE

#### Free Tier (no limits)

| Category | Feature | Notes |
|---|---|---|
| **Task Management** | Task CRUD (title, description, status) | Todo/In Progress/Completed |
| | Tags | Tag-based organization & filtering |
| | Priorities | None → Critical levels |
| | Due dates & reminders | With alarm handling |
| | Photo attachments | Stored in Application Support |
| | Search & filtering | Full-text search |
| | Data import/export | Backup & restore |
| **Views** | List view | Default view with sorting |
| | Calendar view | Monthly calendar with task indicators |
| **AI** | Built-in AI modes | Correct Me, Enhance Prompt, Explain |
| | Custom AI modes (basic) | Create modes with custom prompts |
| | Enhance Me panel | Floating window via global shortcut |
| | **UNLIMITED** in-app enhancements | No monthly cap |
| **Shortcuts** | Quick Entry, Enhance Me, Main Window | All customizable |
| **Data** | Local storage + SwiftData | All data on device |

#### Premium Tier (Pro Subscription or VIP Lifetime)

| Category | Feature | Notes |
|---|---|---|
| **Views** | Kanban board | Drag-and-drop workflow view |
| **Task Management** | Recurring tasks | Daily/weekly/monthly/yearly/weekdays + intervals |
| | Custom fields | Text, number, currency, date, toggle |
| | Budget/client/effort | Extended task metadata |
| **AI** | Inline Enhance | System-wide text enhancement in ANY app |
| | AI attachments | Image/PDF support in AI modes |
| | Attachments in custom modes | Enable attachments for user-created modes |

### Account & Security — All DONE

| Feature | Status | Notes |
|---|---|---|
| Email OTP authentication | ✅ Done | Passwordless sign-in via 6-digit code (Resend) |
| Account session management | ✅ Done | 30-day bearer tokens, stored in Keychain |
| Auth-gated restore/resolve/checkout | ✅ Done | All entitlement endpoints require verified session |
| Device seat enforcement | ✅ Done | Free: 1 / Pro: 2 / VIP: 3 active devices |
| Manage Devices UI | ✅ Done | List, revoke devices in Settings |
| Install proof (Secure Enclave) | ✅ Done | ECDSA P-256 challenge-nonce signing |
| Webhook entitlement sync | ✅ Done | Dodo events → user_entitlements via projector |
| User backfill migration | ✅ Done | Legacy email entitlements → user_id mapping |
| Account-based entitlements | ✅ Done | user_id ownership, not email-based |
| Legacy email-only paths | ✅ Removed | Code deleted — no email-only trust path remains |
| Anomaly logging | ✅ Done | Account-sharing signals logged via fire-and-forget |
| CRON session/OTP cleanup | ✅ Done | Scheduled every 6h via Cloudflare CRON trigger |
| Ed25519 key rotation | ✅ Done | kid claim in token, multi-key verification support |
| Security hardening | ✅ Done | Rate limiting, TOCTOU fix, CORS removal, webhook handlers |

### Data Integrity — All DONE

| Feature | Status | Notes |
|---|---|---|
| VersionedSchema (V1→V2) | ✅ Done | Explicit schema versioning with MigrationPlan |
| Pre-migration store backup | ✅ Done | Backup to Application Support before every migration |
| DataErrorView | ✅ Done | Shown on container init failure instead of silent in-memory fallback |
| Explicit persistent store URL | ✅ Done | No silent in-memory fallback on schema mismatch |

### Technical Implementation — All DONE

| Area | Status | Notes |
|---|---|---|
| Unified access gate (`hasFullAccess`) | ✅ | Pro OR VIP OR debug override |
| Pro subscription (DodoPayments) | ✅ | Subscription linking |
| VIP lifetime (DodoPayments) | ✅ | License key activation |
| Server-signed entitlement tokens | ✅ | Ed25519, 72h TTL, install-bound |
| Settings & configuration | ✅ | AI, shortcuts, custom fields, inline enhance |
| Data persistence (SwiftData) | ✅ | Local storage, photos in Application Support |

---

## Product Tiers

| Tier | Price | What You Get |
|---|---|---|
| **Free** | $0 forever | Full task management, list + calendar views, AI modes (unlimited), local storage |
| **Pro** | $4.99/month | Everything in Free + Kanban, recurring tasks, custom fields, Inline Enhance, AI attachments |
| **VIP** | $99.99 (one-time) | Same as Pro, lifetime access + priority support + early features |

---

## Architecture

- **UI**: SwiftUI, native macOS
- **Data**: SwiftData with model containers
- **AI**: Protocol-based provider system (Gemini, z.ai)
- **Shortcuts**: System-wide via Carbon API
- **Inline Enhance**: Accessibility API for system-wide text capture
- **Backend**: Cloudflare Workers + D1 (SQLite), Ed25519 token signing
- **Auth**: Email OTP via Resend, opaque session tokens (SHA-256 hashed)
- **Install Binding**: Secure Enclave P-256 keypair, challenge-nonce protocol
- **Distribution**: Developer ID (notarized), website download, DodoPayments (MoR)
