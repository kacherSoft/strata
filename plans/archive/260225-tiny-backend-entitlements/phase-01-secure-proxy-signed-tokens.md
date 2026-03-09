# Phase 1 - Secure Proxy + Signed Tokens

Date: 2026-02-26  
Status: Planned

## Objective

Move subscription entitlement trust to backend-signed tokens and remove Dodo read-only key usage from app subscription and portal paths.

## Scope

### In Scope

1. Backend `/v1/entitlements/resolve`.
2. Backend signing with Ed25519.
3. App token verification and signed-token keychain cache.
4. App hardening controls C2, C3, C4.
5. Optional backend portal session endpoint.
6. Feature-flagged fallback for internal testing only.

### Out of Scope

1. Secure Enclave install binding enforcement (Phase 3).
2. Unified restore flow (Phase 3).
3. Checkout session creation (Phase 3).

## Temporary Risk (Accepted Only Before GA)

`/resolve` may accept `email + install_id` without install-proof in Phase 1.  
This is allowed only for internal testing while GA remains blocked by Phase 3 release gate.

## Deliverables

1. `EntitlementBackendClient.swift` implemented.
2. `EntitlementService.swift` switched to signed token trust for subscription path.
3. `KeychainService.swift` stores:
   - `strata.entitlementToken`
   - `strata.clockCheckpoint`
4. Release hardening checks documented and verified.
5. Feature flag for fallback path implemented.

## Backend Work Breakdown

### P1-BE-001: Worker skeleton and environment

- [ ] Create Worker app with versioned routes (`/v1/...`).
- [ ] Configure separate test/live environments.
- [ ] Add secrets:
  - `DODO_API_KEY`
  - `DODO_WEBHOOK_SECRET` (future Phase 2 use)
  - `ENTITLEMENT_SIGNING_PRIVATE_KEY`
- [ ] Add structured error response format:
  - `error_code`
  - `message`
  - `request_id`

### P1-BE-002: Entitlement resolve endpoint

- [ ] Implement `POST /v1/entitlements/resolve`.
- [ ] Validate request schema:
  - `email`: required, normalized lowercased
  - `install_id`: required UUID format
- [ ] Lookup subscription entitlement (initially via provider API until Phase 2 store is ready).
- [ ] Return signed token payload with `tier`, `sub`, `install_id`, `iat`, `exp`, `jti`.
- [ ] Enforce rate limiting per IP and per `install_id`.
- [ ] Avoid returning raw provider error bodies.

### P1-BE-003: Signing and token shape

- [ ] Use Ed25519 private key from Worker secrets.
- [ ] Token format: `base64(payload).base64(signature)`.
- [ ] Set short TTL for internal phase (for example 24h to 72h) and make configurable.
- [ ] Include claims:
  - `tier`
  - `sub`
  - `install_id`
  - `iat`
  - `exp`
  - `jti`
- [ ] Reserve `install_pubkey_hash` claim for Phase 3.

### P1-BE-004: Optional customer portal session proxy

- [ ] Implement `POST /v1/customer-portal/session`.
- [ ] Accept user identity input used today by app flow.
- [ ] Return only validated HTTPS portal URL.

## App Work Breakdown

### P1-APP-001: Backend entitlement client

- [ ] Add `Services/EntitlementBackendClient.swift`.
- [ ] Add base URL configuration with test/live selection.
- [ ] Add request/response models for `/resolve`.
- [ ] Implement retry policy for transient failures.
- [ ] Add bounded timeout.

### P1-APP-002: Token verification and storage

- [ ] Embed Ed25519 public key in app binary.
- [ ] Verify token signature before accepting entitlement.
- [ ] Validate claims:
  - signature valid
  - token not expired
  - `install_id` matches local install id
- [ ] Replace unsigned entitlement JSON cache.
- [ ] Add clock checkpoint storage for rollback detection.

### P1-APP-003: Entitlement service switch

- [ ] Update `EntitlementService.revalidate()`:
  - subscription checks use backend `/resolve`
  - maintain current license fallback path for internal phase if needed
- [ ] Remove dependence on `readOnlyAPIKey()` for subscription and portal calls.
- [ ] Keep `hasFullAccess` behavior stable for UI and inline enhancement gating.

### P1-APP-004: C3 clock rollback detection

- [ ] Replace `isWithinGracePeriod()` logic with token-expiration-first logic.
- [ ] Store checkpoint `{wallClock, systemUptime}` on successful validation.
- [ ] Detect backward wall-clock jumps greater than threshold.
- [ ] Reject stale/abusive offline extension attempts.

### P1-APP-005: C4 integrity check

- [ ] Add `Services/CodeIntegrityService.swift`.
- [ ] Implement `SecCodeCopySelf + SecCodeCheckValidity`.
- [ ] Execute at launch.
- [ ] Degrade entitlement to free if integrity check fails.

### P1-APP-006: C2 hardened runtime verification

- [ ] Add explicit release build setting verification for hardened runtime in project config.
- [ ] Verify release entitlements do not include:
  - `get-task-allow`
  - `disable-library-validation`
  - `allow-dyld-environment-variables`
- [ ] Record verification command and expected output in implementation notes.

### P1-APP-007: Feature flag and fallback policy

- [ ] Add feature flag:
  - recommended key: `entitlement.backend.enabled`
- [ ] Allow fallback only in debug/internal builds.
- [ ] Explicitly disable fallback in release builds before GA.

## API Contract

### Request

```json
{
  "email": "user@example.com",
  "install_id": "uuid-string"
}
```

### Response

```json
{
  "token": "base64payload.base64signature"
}
```

## File Change Plan

- [ ] `TaskManager/Sources/TaskManager/Services/EntitlementService.swift`
- [ ] `TaskManager/Sources/TaskManager/Services/DodoPaymentsClient.swift`
- [ ] `TaskManager/Sources/TaskManager/AI/Services/KeychainService.swift`
- [ ] `TaskManager/Sources/TaskManager/TaskManagerApp.swift` (launch integrity hook)
- [ ] `TaskManager/Sources/TaskManager/Services/EntitlementBackendClient.swift` (new)
- [ ] `TaskManager/Sources/TaskManager/Services/CodeIntegrityService.swift` (new)
- [ ] `TaskManager/project.yml` (explicit hardening and config as needed)

## Validation Matrix

### Functional

- [ ] Linked Pro user unlocks via backend token.
- [ ] Subscription portal still opens via backend proxy (if implemented).
- [ ] VIP manual path still behaves as designed in Phase 1.
- [ ] `hasFullAccess` remains consistent across UI gates.

### Security

- [ ] Editing keychain token does not unlock premium.
- [ ] MITM response tampering fails signature validation.
- [ ] Clock rollback does not extend offline access.
- [ ] Tampered app signature downgrades entitlement.

### Regression

- [ ] Build commands from `TaskManager/README.md` still work.
- [ ] Inline Enhance premium gating still respects entitlement state.
- [ ] No crash on first launch with empty entitlement state.

## Exit Criteria

1. Subscription entitlement decisions use server-signed token flow.
2. App no longer needs Dodo read-only key for subscription/portal logic.
3. Unsigned JSON entitlement cache path removed.
4. Integrity + clock checks are active.
5. Internal testing complete and documented.

## Rollback Plan

1. Keep release-disabled fallback path available during internal testing only.
2. If backend unavailable, use flagged temporary fallback build for QA only.
3. Do not release fallback-enabled build externally.
