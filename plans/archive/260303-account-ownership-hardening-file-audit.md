# Account Ownership Hardening - Complete File Audit
**Date:** 2026-03-03  
**Scope:** All files related to auth, OTP, sessions, devices, restore, resolve, checkout, entitlements, install proof, webhook projection, and validation

---

## Summary Statistics
- **Backend Core Files:** 10 files, 2,551 lines
- **Backend Routes:** 12 files, 1,261 lines
- **Backend Tests:** 12 files, 2,414 lines
- **Database Migrations:** 5 files, 282 lines
- **Swift Services:** 4 files, 1,784 lines
- **Swift Views (Premium/Auth):** 4 files, 611 lines
- **Swift Settings Views:** 2 files, 751 lines
- **TOTAL:** 49 files, 9,654 lines

---

## 1. BACKEND CORE (Utilities, Services, Configuration)

### Core Authentication & Entitlements
| File | Lines | Purpose |
|------|-------|---------|
| `/Volumes/OCW-2TB/LocalProjects/TaskManager/backend/src/auth.ts` | 590 | Core auth logic, session management, OTP verification |
| `/Volumes/OCW-2TB/LocalProjects/TaskManager/backend/src/user-entitlements.ts` | 229 | User entitlement querying and management |
| `/Volumes/OCW-2TB/LocalProjects/TaskManager/backend/src/projector.ts` | 539 | Webhook event projection and state synchronization |

### Signing & Validation
| File | Lines | Purpose |
|------|-------|---------|
| `/Volumes/OCW-2TB/LocalProjects/TaskManager/backend/src/signing.ts` | 149 | Cryptographic signing and verification |
| `/Volumes/OCW-2TB/LocalProjects/TaskManager/backend/src/validation.ts` | 52 | Request/data validation schemas |

### Install Proof & External Clients
| File | Lines | Purpose |
|------|-------|---------|
| `/Volumes/OCW-2TB/LocalProjects/TaskManager/backend/src/install-proof.ts` | 363 | Install proof generation and validation |
| `/Volumes/OCW-2TB/LocalProjects/TaskManager/backend/src/dodo-client.ts` | 295 | Dodo payments/licensing API client |

### Configuration & Types
| File | Lines | Purpose |
|------|-------|---------|
| `/Volumes/OCW-2TB/LocalProjects/TaskManager/backend/src/types.ts` | 237 | TypeScript type definitions |
| `/Volumes/OCW-2TB/LocalProjects/TaskManager/backend/src/errors.ts` | 64 | Error classes and definitions |
| `/Volumes/OCW-2TB/LocalProjects/TaskManager/backend/src/config.ts` | 33 | Configuration management |

**Subtotal Core:** 10 files, 2,551 lines

---

## 2. BACKEND ROUTES (API Endpoints)

### Authentication Routes
| File | Lines | Purpose |
|------|-------|---------|
| `/Volumes/OCW-2TB/LocalProjects/TaskManager/backend/src/routes/auth-start.ts` | 37 | Initiate OTP authentication flow |
| `/Volumes/OCW-2TB/LocalProjects/TaskManager/backend/src/routes/auth-verify.ts` | 36 | Verify OTP and issue session/tokens |
| `/Volumes/OCW-2TB/LocalProjects/TaskManager/backend/src/routes/auth-session-revoke.ts` | 22 | Revoke user sessions |

### Device Management Routes
| File | Lines | Purpose |
|------|-------|---------|
| `/Volumes/OCW-2TB/LocalProjects/TaskManager/backend/src/routes/devices-list.ts` | 37 | List user devices |
| `/Volumes/OCW-2TB/LocalProjects/TaskManager/backend/src/routes/devices-revoke.ts` | 40 | Revoke specific device |

### Licensing & Checkout Routes
| File | Lines | Purpose |
|------|-------|---------|
| `/Volumes/OCW-2TB/LocalProjects/TaskManager/backend/src/routes/checkout.ts` | 171 | Manage checkout flow and transactions |
| `/Volumes/OCW-2TB/LocalProjects/TaskManager/backend/src/routes/restore.ts` | 537 | Restore licenses from previous purchases |
| `/Volumes/OCW-2TB/LocalProjects/TaskManager/backend/src/routes/resolve.ts` | 223 | Resolve entitlements and validate purchases |

### Install & Validation Routes
| File | Lines | Purpose |
|------|-------|---------|
| `/Volumes/OCW-2TB/LocalProjects/TaskManager/backend/src/routes/install.ts` | 94 | Handle install proof submission |
| `/Volumes/OCW-2TB/LocalProjects/TaskManager/backend/src/routes/challenge.ts` | 35 | Generate install challenges |

### Portal & Webhooks Routes
| File | Lines | Purpose |
|------|-------|---------|
| `/Volumes/OCW-2TB/LocalProjects/TaskManager/backend/src/routes/portal.ts` | 78 | User account portal endpoint |
| `/Volumes/OCW-2TB/LocalProjects/TaskManager/backend/src/routes/webhook.ts` | 216 | Handle payment webhook events |

**Subtotal Routes:** 12 files, 1,261 lines

---

## 3. BACKEND TESTS

| File | Lines | Purpose |
|------|-------|---------|
| `/Volumes/OCW-2TB/LocalProjects/TaskManager/backend/tests/auth.test.ts` | 416 | Authentication flow tests |
| `/Volumes/OCW-2TB/LocalProjects/TaskManager/backend/tests/devices.test.ts` | 120 | Device management tests |
| `/Volumes/OCW-2TB/LocalProjects/TaskManager/backend/tests/checkout.test.ts` | 143 | Checkout flow tests |
| `/Volumes/OCW-2TB/LocalProjects/TaskManager/backend/tests/restore.test.ts` | 381 | License restoration tests |
| `/Volumes/OCW-2TB/LocalProjects/TaskManager/backend/tests/resolve.test.ts` | 250 | Entitlement resolution tests |
| `/Volumes/OCW-2TB/LocalProjects/TaskManager/backend/tests/projector.test.ts` | 321 | Webhook projection tests |
| `/Volumes/OCW-2TB/LocalProjects/TaskManager/backend/tests/install-proof.test.ts` | 219 | Install proof tests |
| `/Volumes/OCW-2TB/LocalProjects/TaskManager/backend/tests/install.test.ts` | 124 | Install route tests |
| `/Volumes/OCW-2TB/LocalProjects/TaskManager/backend/tests/portal.test.ts` | 151 | Portal endpoint tests |
| `/Volumes/OCW-2TB/LocalProjects/TaskManager/backend/tests/challenge.test.ts` | 73 | Challenge generation tests |
| `/Volumes/OCW-2TB/LocalProjects/TaskManager/backend/tests/signing.test.ts` | 187 | Signing/verification tests |
| `/Volumes/OCW-2TB/LocalProjects/TaskManager/backend/tests/webhook.test.ts` | 29 | Webhook handling tests |

**Subtotal Tests:** 12 files, 2,414 lines

---

## 4. DATABASE MIGRATIONS

| File | Lines | Purpose |
|------|-------|---------|
| `/Volumes/OCW-2TB/LocalProjects/TaskManager/backend/migrations/0001_initial.sql` | 55 | Initial schema |
| `/Volumes/OCW-2TB/LocalProjects/TaskManager/backend/migrations/0002_install_challenges.sql` | 18 | Install challenge tables |
| `/Volumes/OCW-2TB/LocalProjects/TaskManager/backend/migrations/0003_hardening.sql` | 88 | Auth hardening tables (sessions, OTP) |
| `/Volumes/OCW-2TB/LocalProjects/TaskManager/backend/migrations/0004_account_auth.sql` | 78 | Account and auth tables |
| `/Volumes/OCW-2TB/LocalProjects/TaskManager/backend/migrations/0005_user_backfill.sql` | 43 | User data backfill |

**Subtotal Migrations:** 5 files, 282 lines

---

## 5. SWIFT CLIENT SERVICES

### Core Entitlement & Backend Services
| File | Lines | Purpose |
|------|-------|---------|
| `/Volumes/OCW-2TB/LocalProjects/TaskManager/TaskManager/Sources/TaskManager/Services/EntitlementService.swift` | 972 | Main entitlement service, license validation, sync |
| `/Volumes/OCW-2TB/LocalProjects/TaskManager/TaskManager/Sources/TaskManager/Services/EntitlementBackendClient.swift` | 547 | HTTP client for entitlement backend API |

### Security Services
| File | Lines | Purpose |
|------|-------|---------|
| `/Volumes/OCW-2TB/LocalProjects/TaskManager/TaskManager/Sources/TaskManager/Services/SecureEnclaveService.swift` | 148 | Secure Enclave cryptographic operations |
| `/Volumes/OCW-2TB/LocalProjects/TaskManager/TaskManager/Sources/TaskManager/AI/Services/KeychainService.swift` | 97 | Keychain storage for secure credentials |

**Subtotal Services:** 4 files, 1,784 lines

---

## 6. SWIFT UI - PREMIUM AUTHENTICATION VIEWS

| File | Lines | Purpose |
|------|-------|---------|
| `/Volumes/OCW-2TB/LocalProjects/TaskManager/TaskManager/Sources/TaskManager/Views/Premium/AccountSignInView.swift` | 168 | Account sign-in interface |
| `/Volumes/OCW-2TB/LocalProjects/TaskManager/TaskManager/Sources/TaskManager/Views/Premium/SubscriptionLinkingView.swift` | 147 | Link existing subscriptions |
| `/Volumes/OCW-2TB/LocalProjects/TaskManager/TaskManager/Sources/TaskManager/Views/Premium/PremiumUpsellView.swift` | 202 | Premium feature upsell interface |
| `/Volumes/OCW-2TB/LocalProjects/TaskManager/TaskManager/Sources/TaskManager/Views/Premium/LicenseActivationView.swift` | 94 | License activation interface |

**Subtotal Premium Views:** 4 files, 611 lines

---

## 7. SWIFT UI - SETTINGS VIEWS

| File | Lines | Purpose |
|------|-------|---------|
| `/Volumes/OCW-2TB/LocalProjects/TaskManager/TaskManager/Sources/TaskManager/Views/Settings/ManageDevicesView.swift` | 140 | Device management interface |
| `/Volumes/OCW-2TB/LocalProjects/TaskManager/TaskManager/Sources/TaskManager/Views/Settings/GeneralSettingsView.swift` | 611 | General settings including auth/premium sections |

**Subtotal Settings Views:** 2 files, 751 lines

---

## File Organization Summary

### By Category
- **Backend Services:** 22 files (10 core + 12 routes)
- **Backend Testing:** 12 files
- **Database:** 5 files
- **Swift Services:** 4 files
- **Swift UI Views:** 6 files

### By Line Count
- Largest backend file: `restore.ts` (537 lines)
- Largest Swift file: `EntitlementService.swift` (972 lines)
- Largest settings file: `GeneralSettingsView.swift` (611 lines)

### Critical Files for Account Hardening
1. **auth.ts** - Core authentication logic
2. **EntitlementService.swift** - License validation
3. **restore.ts** - License restoration
4. **projector.ts** - Webhook event handling
5. **user-entitlements.ts** - Entitlement queries
6. **install-proof.ts** - Install validation
7. **0003_hardening.sql** - Auth schema
8. **0004_account_auth.sql** - Account schema

---

## Dependency Graph (Key Integrations)

**Backend Flow:**
```
auth-start → auth-verify → auth-session-revoke
                ↓
        user-entitlements → projector
                ↓
    checkout ↔ restore ↔ resolve
                ↓
        webhook → dodo-client
                ↓
    install-proof ← challenge ← install
```

**Swift Flow:**
```
EntitlementBackendClient
    ↓
EntitlementService
    ↓
AccountSignInView → SubscriptionLinkingView
    ↓
ManageDevicesView ← GeneralSettingsView
    ↓
SecureEnclaveService ↔ KeychainService
```

---

## Next Steps
- Use this inventory to track implementation progress
- Cross-reference files when making architectural changes
- Monitor test coverage for critical paths
- Track migration dependencies for schema updates

