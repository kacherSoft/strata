# System Architecture

_Last updated: 2026-03-10_

## Overview

Strata is a macOS-native productivity app with a serverless backend for entitlement management and authentication. The Swift app handles all task data locally; the backend only manages subscriptions, auth, and licensing.

```
┌─────────────────────────────────────────┐
│           macOS App (Swift/SwiftUI)      │
│  TaskManagerApp → ModelContainer         │
│  Views → Services → Data (SwiftData)     │
│  AI providers (Gemini, z.ai)             │
└────────────────────┬────────────────────┘
                     │ HTTPS (entitlements + auth only)
┌────────────────────▼────────────────────┐
│      Backend (Cloudflare Workers + D1)   │
│  itty-router → Auth → Entitlements       │
│  Ed25519 signing → Webhook processing    │
└─────────────────────────────────────────┘
```

---

## Swift App Layers

### Data Layer (`Sources/TaskManager/Data/`)
- **@Model classes**: `TaskModel`, `AIModeModel`, `SettingsModel`, `CustomFieldDefinitionModel`, `CustomFieldValueModel`
- **Schema versioning**: `SchemaVersioning.swift` — `VersionedSchema` V1→V2, `MigrationPlan`, explicit store URL
- **ModelContainer config**: `ModelContainer+Config.swift` — pre-migration backup, `DataErrorView` on init failure
- **Repositories**: `TaskRepository.swift`, `AIModeRepository.swift` — SwiftData query abstraction

### Services Layer (`Sources/TaskManager/Services/`)
| Service | Responsibility |
|---------|---------------|
| `EntitlementService` | Verify/refresh entitlement tokens, gate premium features |
| `EntitlementBackendClient` | HTTP calls to backend (restore, resolve, checkout) |
| `DodoPaymentsClient` | Portal link generation |
| `SecureEnclaveService` | P-256 keypair management, challenge signing |
| `NotificationService` | Local reminder scheduling and delivery |
| `DataExportService` | JSON backup/restore |
| `PhotoStorageService` | Photo attachment file management |
| `InlineEnhanceCoordinator` | Orchestrate Accessibility API text capture + replacement |
| `TextCaptureEngine` | AX element text extraction |
| `TextReplacementEngine` | Write enhanced text back to focused element |
| `CodeIntegrityService` | Tamper detection |

### AI Layer (`Sources/TaskManager/AI/`)
- Protocol-based provider system — each provider implements a common `AIProvider` protocol
- Providers: Gemini (google-generative-ai-swift), z.ai (custom HTTP)
- `AIService` orchestrates mode selection, prompt formatting, streaming

### Views Layer (`Sources/TaskManager/Views/`)
- Task list, detail, kanban, calendar views
- Premium gate views (paywall, onboarding)
- Settings: AI config, shortcuts, custom fields, account, devices

### Windows Layer (`Sources/TaskManager/Windows/`)
- `QuickEntryPanel` — floating window, global shortcut activated
- `EnhanceMePanel` — AI enhancement window
- `InlineEnhanceHUD` — overlay HUD during system-wide enhancement
- `WindowManager` (via `WindowActivator.swift` extension) — NSWindow lifecycle

---

## Backend Layers (`backend/src/`)

### Router (`index.ts`)
- `itty-router` with middleware chain
- Middleware: request ID injection, structured error handling
- Route groups: `/v1/auth/*`, `/v1/install/*`, `/v1/checkout`, `/v1/restore`, `/v1/resolve`, `/v1/portal`, `/v1/devices/*`, `/v1/webhook`

### Auth (`auth.ts`, `rate-limit.ts`)
- Email OTP: 6-digit code, 10-minute TTL, stored hashed in `otp_challenges`
- Session tokens: 32-byte random, SHA-256 hashed in `sessions`, 30-day TTL
- `requireSession()` middleware — validates `Authorization: Bearer <token>` header
- Rate limiting: per-IP on start/verify, per-install on restore/resolve

### Entitlements (`user-entitlements.ts`, `projector.ts`)
- `user_entitlements` table: one row per user, stores tier and product IDs
- Projector pattern: webhook events are replayed against current state to derive authoritative entitlement
- Supported events: `subscription.active`, `subscription.cancelled`, `license_key.activated`, `license_key.revoked`, `payment.refunded`

### Signing (`signing.ts`)
- Ed25519 key pair (stored in Worker secrets)
- Token payload: `install_id`, `user_id`, `tier`, `iat`, `exp` (72h), `kid`
- `kid` claim enables key rotation without token invalidation

### Install Proof (`install-proof.ts`, `routes/challenge.ts`, `routes/install.ts`)
- Backend issues a random nonce challenge
- App signs nonce with Secure Enclave P-256 private key
- Backend verifies signature against stored public key — binds entitlement to device

### Scheduled Cleanup (`scheduled-cleanup.ts`)
- Cloudflare CRON trigger: every 6 hours
- Deletes expired OTP challenges, sessions, and stale device records

### Anomaly Detection (`anomaly-detection.ts`)
- Fire-and-forget logging of account-sharing signals (multiple install IDs per session in short window)
- Does not block requests; logged to D1 for offline review

---

## Key Data Flows

### Entitlement Lifecycle
```
User pays (DodoPayments)
  → Webhook → POST /v1/webhook
    → projector(event, currentState) → new entitlement row
      → App calls POST /v1/restore (session token + install proof)
        → Backend verifies session + install proof
          → Signs Ed25519 token (72h TTL)
            → App stores token in Keychain
              → EntitlementService validates token on every app launch
```

### Auth Flow
```
User enters email
  → POST /v1/auth/email/start → OTP sent via Resend
    → User enters 6-digit code
      → POST /v1/auth/email/verify → session token returned
        → App stores session token in Keychain
          → All subsequent requests use Bearer token
```

### Install Binding
```
First launch
  → SecureEnclaveService generates P-256 keypair (hardware-bound)
    → GET /v1/install/challenge → nonce
      → App signs nonce with private key
        → POST /v1/install → public key + signature registered
          → install_id stored in Keychain
```

---

## Security Model

| Layer | Mechanism | TTL / Scope |
|-------|-----------|-------------|
| Auth session | SHA-256 hashed opaque token | 30 days |
| Entitlement token | Ed25519 signed JWT-like | 72 hours |
| Install binding | P-256 ECDSA (Secure Enclave) | Permanent (per device) |
| OTP code | 6-digit, hashed at rest | 10 minutes |
| Rate limiting | Per-IP (auth) + per-install (entitlements) | Sliding window |
| Key rotation | `kid` claim, multi-key verification | On secret rotation |

**No credentials stored in app binary.** All secrets (Ed25519 keys, Resend API key, Dodo webhook secret) stored in Cloudflare Worker secrets.
