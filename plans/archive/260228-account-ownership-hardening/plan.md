# Strata Account Ownership Hardening Plan

Date: 2026-02-28
Status: SUPERSEDED — See `plans/260303-account-ownership-hardening-finalization/plan.md`
Owner: Backend + macOS client

## 1) Problem Statement

Current restore and resolve flows trust `email` too much. If a paying user shares their email, another person can restore paid access on a different PC.

Current risk points in code:
- `backend/src/routes/restore.ts:309` accepts user-supplied email for restore.
- `backend/src/routes/restore.ts:342` grants Pro from active subscription lookup by email.
- `backend/src/routes/resolve.ts:146` can grant Pro from Dodo fallback by email.
- `TaskManager/Sources/TaskManager/Views/Premium/SubscriptionLinkingView.swift:47` is email-only restore UX.

## 2) Goals

1. Make paid entitlement ownership tied to a verified user identity, not raw email input.
2. Allow legitimate multi-device use with explicit seat/device controls.
3. Keep purchase activation smooth on the purchasing device.
4. Preserve webhook-driven entitlement truth and replayability.
5. Provide clear in-app behavior for restore, seat conflicts, and device changes.

## 3) Non-Goals

1. Building full social login/OAuth account system (phase scope is passwordless email OTP account proof).
2. Perfectly eliminating sharing (not feasible); goal is strong reduction + enforceable controls.
3. Removing Dodo; Dodo remains payment source of truth.

## 4) Evidence Baseline

### Code Evidence
- Email-based restore grant: `backend/src/routes/restore.ts:309`
- Pro fallback by email: `backend/src/routes/restore.ts:342`
- Resolve fallback by email: `backend/src/routes/resolve.ts:146`
- Email-first restore UI: `TaskManager/Sources/TaskManager/Views/Premium/SubscriptionLinkingView.swift:47`

### Docs Evidence (Official)
- Dodo Checkout sessions (customer binding fields):
  https://docs.dodopayments.com/api-reference/checkouts/create-a-new-checkout-session
- Dodo Checkout retrieval fields (`customer_email`, `customer_id`, `payment_status`):
  https://docs.dodopayments.com/api-reference/checkouts/retrieve-a-checkout
- Dodo Payments retrieval (product cart/customer/payment status):
  https://docs.dodopayments.com/api-reference/payments/retrieve-a-payment
- Dodo Webhook signature verification (Svix):
  https://docs.dodopayments.com/developer-resources/webhooks/standard-webhooks
- Dodo Webhook event catalog:
  https://docs.dodopayments.com/developer-resources/webhooks/events
- Dodo Product Collections setting (`allow_multiple_subscriptions`, default enabled):
  https://docs.dodopayments.com/developer-resources/subscription/product-collection
- Dodo License key instances (device-level license control surface):
  https://docs.dodopayments.com/api-reference/license-key-instance/get-license-key-instances-list

### Community Evidence
- Auth0 community recommendation: shared accounts are inherently weaker; use verified identity and stronger controls:
  https://community.auth0.com/t/recommendation-on-how-to-stop-users-from-sharing-account/73834
- RevenueCat guidance on restore semantics and transfer strategy tradeoffs (analogous subscription entitlement domain):
  https://www.revenuecat.com/docs/getting-started/restoring-purchases
- Stack Overflow discussion showing device-limit enforcement requires server-side tracked device sessions, not client-only checks:
  https://stackoverflow.com/questions/72658327/firebase-authentication-to-limit-1-account-for-1-device

Assumptions: none

## 5) Target Security Model (Post-Implementation)

1. Entitlement subject becomes `user_id` (internal stable account id), not email.
2. App must hold a verified account session token (issued after OTP verification).
3. `restore` and `resolve` require both:
   - Verified account session token
   - Install proof (`install_id + challenge_id + nonce_signature`)
4. Device seats enforced per `user_id` (plan-based limits).
5. VIP license remains required for manual VIP restoration path, with instance tracking and seat checks.

## 6) Implementation Phases

## Phase 0 - Foundation + Guard Rails

### Scope
- Introduce account and device schema.
- Keep existing flow alive behind feature flags.

### Backend tasks
1. Add tables:
   - `users(id, email_normalized, email_verified_at, created_at, updated_at)`
   - `auth_challenges(id, email_normalized, otp_hash, expires_at, attempts, consumed_at)`
   - `account_sessions(id, user_id, session_hash, expires_at, revoked_at, created_at)`
   - `user_devices(id, user_id, install_id, nickname, first_seen_at, last_seen_at, revoked_at)`
   - `user_entitlements(user_id, tier, state, source_event_id, effective_from, effective_until, updated_at)`
2. Add feature flags:
   - `AUTH_REQUIRED_FOR_RESTORE`
   - `AUTH_REQUIRED_FOR_RESOLVE`
   - `ENFORCE_DEVICE_SEATS`
3. Add audit columns/logging for decision traces.

### Client tasks
1. Add hidden debug switch to opt-in new auth flow in test env.
2. No behavior change for production users yet.

### Exit criteria
- Migrations applied in test env.
- Existing tests pass unchanged.
- New schema smoke-tested.

## Phase 1 - Verified Identity (Email OTP)

### Scope
- Add passwordless account verification and session issuance.

### Backend tasks
1. `POST /v1/auth/email/start`:
   - Accept email.
   - Create OTP challenge (rate-limited + attempt-limited).
   - Send OTP via transactional email provider.
2. `POST /v1/auth/email/verify`:
   - Verify OTP.
   - Upsert `users` row.
   - Issue signed/opaque session token (`account_session`).
3. Add session verification middleware.

### Client tasks
1. New "Sign in to restore purchases" sheet:
   - Enter email.
   - Enter OTP.
   - Persist session token in Keychain.
2. Show signed-in identity in Settings.
3. Add "Sign out" and "Switch account".

### Security controls
- OTP expiry 10 minutes.
- Max attempts 5 per challenge.
- Rate limit per IP + email.

### Exit criteria
- Restore cannot proceed in new flow without valid account session.
- Session survives app restart.
- Full unit/integration tests for OTP lifecycle.

## Phase 2 - Bind Purchases to User Identity

### Scope
- Convert entitlement ownership from email-centric to user-centric.

### Backend tasks
1. Checkout creation:
   - If signed-in: pass `customer_id` when known, else normalized email from verified account.
   - Continue storing `install_id` metadata and `checkout_session_id`.
2. Webhook projector:
   - Resolve Dodo event -> `customer_id/email` -> `user_id` mapping.
   - Update `user_entitlements` (not only `entitlements` by email).
3. Keep compatibility mirror for old email-based table during migration window.

### Client tasks
1. Purchase buttons require signed-in state for Pro/VIP purchase flows.
2. Checkout return flow triggers immediate entitlement refresh by `user_id` session.

### Exit criteria
- New purchases always map to a `user_id`.
- Entitlement refresh uses account session, not raw email.

## Phase 3 - Secure Restore + Resolve Cutover

### Scope
- Remove email-only trust paths.

### Backend tasks
1. `POST /v1/purchases/restore`:
   - Require account session + install proof.
   - Ignore request email field for entitlement grant decision.
2. `POST /v1/entitlements/resolve`:
   - Require account session + install proof.
   - Read entitlement by `user_id`.
   - Remove Dodo email fallback from resolve path.
3. VIP path:
   - Manual restore for VIP requires valid license key if no active `user_entitlements.vip`.
   - Validate license product + ownership consistency.

### Client tasks
1. Remove email entry requirement from restore UX after account sign-in.
2. If unauthenticated and user taps Restore: route to OTP sign-in.
3. Show precise error messages:
   - "Sign-in required"
   - "Seat limit reached"
   - "License key required"

### Exit criteria
- Attempting restore on a random machine with only shared email fails.
- Existing rightful user with OTP succeeds.
- Resolve no longer grants from typed email.

## Phase 4 - Device Seat Enforcement + Device Management

### Scope
- Control account sharing via explicit seat policy and tooling.

### Policy proposal
- Free: 1 active device.
- Pro: 2 active devices.
- VIP: 3 active devices.

### Backend tasks
1. On entitlement resolve/restore, enforce seat cap against `user_devices` active set.
2. If cap exceeded:
   - Return `DEVICE_LIMIT_REACHED` with current active devices metadata.
3. Add endpoints:
   - `GET /v1/devices`
   - `POST /v1/devices/revoke`

### Client tasks
1. New "Manage Devices" section in Settings.
2. If limit exceeded, show chooser to revoke an older device.

### Exit criteria
- Third unauthorized device cannot silently consume paid access.
- Legit user can self-recover by revoking stale devices.

## Phase 5 - Subscription Anti-Sharing Hardening (Dodo Config + App UX)

### Scope
- Prevent duplicate/abusive subscription linking and tighten ownership consistency.

### Dodo configuration tasks
1. Ensure product collection `allow_multiple_subscriptions=false` where product strategy requires one active subscription per customer.
2. Verify webhook subscriptions include all entitlement-affecting events.

### Backend tasks
1. Reject restore when Dodo customer mismatch occurs between checkout/payment/customer binding and authenticated `user_id` mapping.
2. Add anomaly logging for:
   - frequent account switches on one install
   - many installs in short interval per user

### Client tasks
1. Account mismatch UI copy:
   - "This purchase belongs to another account. Sign in with the purchase owner email."

### Exit criteria
- Duplicate-subscription abuse reduced by provider config + backend checks.
- Clear UX for account mismatch.

## Phase 6 - Migration, Cleanup, and GA Security Gate

### Scope
- Migrate existing users and remove legacy trust paths.

### Migration steps
1. Backfill `users` from existing entitlement-linked emails.
2. Backfill `user_entitlements` from current `entitlements`.
3. Soft-launch: support both flows for limited window (test + selected internal users).
4. Cutover flags:
   - `AUTH_REQUIRED_FOR_RESTORE=true`
   - `AUTH_REQUIRED_FOR_RESOLVE=true`
   - `ENFORCE_DEVICE_SEATS=true`
5. Remove/deprecate legacy email-only code paths.

### GA gate
- No endpoint grants paid tier from unverified raw email.
- Device seat policy enforced for paid tiers.
- All docs and runbooks updated.

## 7) User Story and Edge Case Behavior Matrix (Post-Implementation)

## Story A: Existing paid user upgrades to new PC
1. User installs app on new PC.
2. App starts as Free.
3. User taps Restore.
4. App requests OTP sign-in.
5. User verifies email OTP.
6. Backend checks entitlement by `user_id` and seat policy.
7. If seat available, app upgrades automatically.
8. If seat full, app shows active devices and asks user to revoke one.

Expected app behavior:
- No manual email-only restore.
- Explicit progress and final state.

## Story B: User shares email, another person tries to restore
1. Second person enters shared email.
2. OTP is sent to owner mailbox only.
3. Without OTP, no session token.
4. Restore fails with auth-required error.

Expected app behavior:
- Remains Free.
- Shows "Verify ownership via OTP".

## Story C: User shares OTP intentionally
1. Second person can sign in if owner shares OTP intentionally.
2. Seat policy still applies.
3. If seat full, unauthorized device cannot activate unless owner revokes a device.

Expected app behavior:
- This is residual risk by explicit owner consent.
- Logged as account-sharing signal for review.

## Story D: Pro subscriber cancels subscription in portal
1. Webhook marks entitlement inactive after provider state transition.
2. Next resolve/revalidate downgrades to Free (respecting grace logic, if any configured).

Expected app behavior:
- Plan label changes from Pro -> Free on next refresh.
- Clear message if downgrade is due to subscription state.

## Story E: VIP user changes PC and lost key
1. User signs in with OTP.
2. If backend already has active VIP entitlement bound to `user_id`, restore succeeds.
3. If not, app asks for license key.
4. License activation checks product + activation limits.

Expected app behavior:
- Deterministic path, no silent fallback to shared-email grant.

## Story F: Webhook delay after checkout
1. User returns from browser.
2. App shows "Finalizing purchase activation...".
3. App polls restore/resolve with bounded retries.
4. If still pending, user sees "Payment received, waiting for confirmation" and can retry.

Expected app behavior:
- No unexplained waiting.
- No duplicate windows.

## Story G: Offline on launch after previous successful validation
1. App uses cached signed token within offline policy.
2. Once network returns, revalidate by account session + install proof.

Expected app behavior:
- Paid access continuity per existing offline grace rules.

## Story H: Same account on too many devices quickly (abuse pattern)
1. Backend detects seat threshold breaches and unusual bursts.
2. Resolve returns seat-limit response or additional verification requirement (future policy hook).

Expected app behavior:
- Clear next action (revoke device / retry).

## 8) API and Data Contract Changes

## New endpoints
- `POST /v1/auth/email/start`
- `POST /v1/auth/email/verify`
- `GET /v1/devices`
- `POST /v1/devices/revoke`

## Modified endpoints
- `POST /v1/purchases/restore`:
  - remove trust in request email for entitlement grants
  - require account session
- `POST /v1/entitlements/resolve`:
  - require account session
  - resolve by `user_id`

## Deprecated behavior
- Email-only restore for Pro/VIP.
- Resolve fallback by arbitrary email.

## 9) Validation Checklist by Phase

1. Unit tests for OTP challenge/session lifecycle.
2. Integration tests for restore/resolve requiring account session.
3. E2E test: purchase on PC A -> restore on PC B -> seat handling.
4. E2E test: shared email without OTP -> denied.
5. E2E test: shared OTP + seat full -> denied until revoke.
6. E2E test: webhook delay -> user-facing pending state then success.
7. Regression tests for existing secure install proof checks.

## 10) Rollout Strategy

1. Implement phases in test env first.
2. Internal dogfood on test Dodo mode with forced edge-case scripts.
3. Add telemetry dashboards for restore failures by reason.
4. Enable in production behind flags for small cohort.
5. Full cutover after 7-day clean metrics window.

## 11) Risks and Mitigations

1. Risk: OTP email delivery delays.
   - Mitigation: resend cooldown + alternate support flow.
2. Risk: Legit users blocked by seat caps.
   - Mitigation: self-service device revoke in-app.
3. Risk: Migration mismatch from old email records.
   - Mitigation: staged backfill + reconciliation job + rollback flag.
4. Risk: Increased implementation complexity.
   - Mitigation: phase gates and strict test criteria per phase.

## 12) Review Questions (Need Product/Engineering Sign-Off)

1. Final seat limits per plan (Pro/VIP).
2. OTP validity window and resend policy.
3. Whether to require signed-in state before checkout, or allow guest checkout then claim.
4. Support policy when user lost mailbox access but still has paid entitlement.
5. Sunset date for legacy email-only restore.
