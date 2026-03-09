# Phase 3 - Instant Activation + Unified Restore + Install Binding

Date: 2026-02-26  
Status: Planned

## Objective

Complete security and UX requirements for production release:

1. Instant unlock after checkout.
2. Unified restore flow for VIP and Pro.
3. Install-bound entitlement issuance using Secure Enclave proof.

## Scope

### In Scope

1. Secure Enclave key generation and nonce signing.
2. Install registration endpoint.
3. Checkout session endpoint and deep-link return.
4. Unified restore endpoint and app UI flow.
5. Final GA release-gate enforcement.

### Out of Scope

1. Full user account system.
2. Multi-device account dashboard.

## Deliverables

1. `POST /v1/installs/register`
2. `POST /v1/checkout-sessions`
3. `POST /v1/purchases/restore`
4. App deep-link handling for `strata://checkout-complete`
5. Unified restore UI replacing split subscription/license restore entry points
6. Token claim `install_pubkey_hash` verified on client

## Backend Work Breakdown

### P3-BE-001: Install registration endpoint

- [ ] Implement `POST /v1/installs/register`.
- [ ] Accept:
  - `install_id`
  - `install_pubkey`
- [ ] Validate key shape and curve compatibility.
- [ ] Store install mapping in `purchase_links` (or dedicated install table if introduced).

### P3-BE-002: Challenge flow for proof of possession

- [ ] Add nonce challenge generation endpoint or challenge step in existing endpoints.
- [ ] Validate signed nonce against registered install public key.
- [ ] Reject entitlement issuance when signature verification fails.

### P3-BE-003: Checkout session endpoint

- [ ] Implement `POST /v1/checkout-sessions`.
- [ ] Include `install_id` and `return_url` metadata.
- [ ] Return `session_id` and `checkout_url`.
- [ ] Ensure checkout metadata is joinable by webhook processing.

### P3-BE-004: Unified restore endpoint

- [ ] Implement `POST /v1/purchases/restore`.
- [ ] Accept install proof (`nonce_signature`) and restore hint (`email`).
- [ ] Return token when proof is valid and entitlement exists.
- [ ] Return verification-required response when ownership proof is insufficient.

### P3-BE-005: Checkout-to-install linkage

- [ ] On webhook processing, map `checkout_session_id` to `install_id`.
- [ ] Persist link in `purchase_links`.
- [ ] Allow immediate `/resolve` success after checkout return.

## App Work Breakdown

### P3-APP-001: Secure Enclave service

- [ ] Add `Services/SecureEnclaveService.swift`.
- [ ] Generate non-exportable P-256 private key at first launch.
- [ ] Persist key tag for lookup in keychain metadata.
- [ ] Export public key for backend registration.

### P3-APP-002: Install identity bootstrap

- [ ] Create local stable `install_id` (UUID).
- [ ] Register `(install_id, pubkey)` with backend.
- [ ] Retry registration safely on transient failure.

### P3-APP-003: Resolve with install proof

- [ ] Request nonce (if separate challenge endpoint is used).
- [ ] Sign nonce using Secure Enclave private key.
- [ ] Submit signed proof with `/resolve`.
- [ ] Verify returned token includes matching `install_pubkey_hash`.

### P3-APP-004: Checkout flow switch

- [ ] Replace static checkout URLs with backend checkout session API call.
- [ ] Open returned checkout URL.
- [ ] On return deep link, trigger immediate entitlement refresh.

### P3-APP-005: Deep-link prerequisites

- [ ] Add app URL scheme config (`strata`) in project settings.
- [ ] Add app-level URL handler in SwiftUI app lifecycle.
- [ ] Handle `checkout-complete` path and refresh entitlement.

### P3-APP-006: Unified restore UX

- [ ] Replace split "I already subscribed" and "I have a license key" restore entry points with unified "Restore purchases".
- [ ] Keep manual VIP key activation available as fallback path where intended.
- [ ] Provide clear states:
  - restoring
  - verification required
  - restored
  - failed

### P3-APP-007: Final fallback removal for release

- [ ] Disable insecure direct fallback in release builds.
- [ ] Keep QA-only fallback controlled by debug/internal configuration.
- [ ] Verify release artifacts cannot toggle insecure mode.

## API Contracts

### Checkout session

```json
{
  "product_id": "pdt_...",
  "install_id": "uuid",
  "return_url": "strata://checkout-complete"
}
```

```json
{
  "session_id": "cks_...",
  "checkout_url": "https://checkout.dodopayments.com/session/..."
}
```

### Restore

```json
{
  "install_id": "uuid",
  "nonce_signature": "base64",
  "email": "user@example.com"
}
```

```json
{
  "token": "base64payload.base64signature"
}
```

```json
{
  "verification_required": true,
  "message": "Check your email"
}
```

## File Change Plan

- [ ] `TaskManager/Sources/TaskManager/Services/SecureEnclaveService.swift` (new)
- [ ] `TaskManager/Sources/TaskManager/Services/EntitlementBackendClient.swift`
- [ ] `TaskManager/Sources/TaskManager/Services/EntitlementService.swift`
- [ ] `TaskManager/Sources/TaskManager/Views/Premium/PremiumUpsellView.swift`
- [ ] `TaskManager/Sources/TaskManager/Views/Premium/SubscriptionLinkingView.swift` (replace/rework to unified restore)
- [ ] `TaskManager/Sources/TaskManager/Views/Settings/GeneralSettingsView.swift`
- [ ] `TaskManager/Sources/TaskManager/TaskManagerApp.swift` (deep-link handling)
- [ ] `TaskManager/project.yml` (URL scheme and release config)

## Validation Matrix

### Purchase activation

- [ ] Checkout -> return deep link -> instant unlock without manual steps.
- [ ] Webhook delay scenario still converges quickly once processed.

### Restore

- [ ] Fresh install restore succeeds with required ownership proof.
- [ ] Email-only abuse is blocked with verification-required response.
- [ ] VIP and Pro both restore from same entry point.

### Device binding

- [ ] Copying app bundle and keychain blobs to another device does not unlock premium.
- [ ] Token with mismatched `install_pubkey_hash` is rejected locally.

### Integration and regression

- [ ] Customer portal still works via backend session endpoint.
- [ ] Inline Enhance premium gating still respects `hasFullAccess`.
- [ ] Existing license activation fallback behaves as designed.

## Final GA Exit Criteria

All items below must be true before public release:

1. `/resolve` requires install-bound proof and enforces ownership checks.
2. Unified restore is live for VIP + Pro with verification flow.
3. Checkout instant activation works end-to-end.
4. Release build has no Dodo secret API keys embedded for entitlement logic.
5. Insecure fallback paths are disabled in release.
6. Hardened Runtime and integrity checks are validated in release artifact.
7. Deep-link return flow is fully operational in packaged app.

## Rollback Plan

1. If restore flow breaks, retain license manual activation path temporarily.
2. If checkout linkage fails, allow re-resolve on app foreground until webhook sync completes.
3. If install-binding defect appears, pause rollout and keep external release blocked.
