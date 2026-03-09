# Phase 2 - Webhooks + Entitlement Store

Date: 2026-02-26  
Status: Planned

## Objective

Make backend entitlement state authoritative and replay-safe so `/resolve` can rely on local state first and provider API second.

## Scope

### In Scope

1. Dodo webhook verification endpoint.
2. Idempotent event journal.
3. Deterministic entitlement projection.
4. `/resolve` reads from entitlement store first.

### Out of Scope

1. Secure Enclave challenge enforcement (Phase 3).
2. Checkout-return deep link flow (Phase 3).

## Deliverables

1. `POST /v1/webhooks/dodo` with signature and freshness validation.
2. D1 schema deployed for:
   - `webhook_events`
   - `entitlements`
   - `purchase_links`
3. Deterministic projector logic with replay safety.
4. `/resolve` prioritized local read path.

## Data Model Implementation Tasks

### P2-DB-001: Schema and indexes

- [ ] Create tables:
  - `webhook_events`
  - `entitlements`
  - `purchase_links`
- [ ] Add uniqueness constraints:
  - `webhook_events.webhook_id`
  - `entitlements(subject_type, subject_id)`
- [ ] Add query indexes for:
  - `entitlements.subject_type + subject_id`
  - `purchase_links.install_id`
  - `purchase_links.checkout_session_id`

### P2-DB-002: Migration hygiene

- [ ] Write idempotent migration scripts.
- [ ] Add migration order documentation.
- [ ] Add rollback script for non-destructive downgrade.

## Backend Work Breakdown

### P2-BE-001: Webhook ingress

- [ ] Implement `POST /v1/webhooks/dodo`.
- [ ] Verify signature using Dodo header contract (`webhook-id`, `webhook-timestamp`, `webhook-signature`).
- [ ] Reject stale webhook timestamps.
- [ ] Persist raw event and metadata in `webhook_events`.
- [ ] Return `200` quickly and process async with `waitUntil`.

### P2-BE-002: Idempotency and dedup

- [ ] On duplicate `webhook_id`, skip projection and return success.
- [ ] Mark event status transitions:
  - `pending`
  - `processed`
  - `ignored`
  - `error`
- [ ] Ensure failed projection can be retried safely.

### P2-BE-003: Event projection engine

- [ ] Map provider events to entitlement transitions.
- [ ] Use event timestamp ordering for deterministic projection.
- [ ] Apply tier precedence rule: `vip > pro > free`.
- [ ] Preserve causal safety when out-of-order events arrive.

### P2-BE-004: Resolve endpoint read-path switch

- [ ] Modify `/v1/entitlements/resolve` to:
  - read local `entitlements` first
  - fallback to provider lookup only when needed
- [ ] Record source path in logs/metrics (`store` vs `fallback`).

## Event Mapping Contract

| Event | Projection |
|---|---|
| `subscription.active` | `tier=pro`, `state=active` |
| `subscription.updated` | `tier=pro`, `state=active` |
| `subscription.cancelled` | `tier=pro`, `state=inactive` |
| `subscription.expired` | `tier=pro`, `state=inactive` |
| `license_key.created` | `tier=vip`, `state=active` |
| `payment.succeeded` | trigger lookup/reconciliation |

## API Behavior Requirements

### Webhook endpoint response

- [ ] Never expose internal stack traces.
- [ ] Do not leak provider payload details in error responses.
- [ ] Always include request correlation id in logs.

### Resolve endpoint behavior

- [ ] Continue returning signed entitlement token.
- [ ] Preserve response compatibility with Phase 1 app client.
- [ ] Handle missing local record via safe fallback.

## Security and Abuse Controls

- [ ] Constant-time signature compare.
- [ ] Schema validation before projection.
- [ ] Strict subject matching to prevent cross-user resolution.
- [ ] Rate limit webhook abuse and malformed payload spam.

## File and Artifact Plan

- [ ] Worker route handlers and middleware files.
- [ ] D1 migration files.
- [ ] Projection logic module.
- [ ] Operational runbook for replay/recovery.

## Validation Matrix

### Replay and idempotency

- [ ] Duplicate webhook deliveries do not duplicate state.
- [ ] Reprocessing same payload keeps deterministic result.

### Ordering

- [ ] Late `cancelled` event does not incorrectly override newer active state.
- [ ] Out-of-order delivery still yields expected final tier/state.

### Resolve behavior

- [ ] `/resolve` hits local store in normal case.
- [ ] Fallback path works when store is incomplete.

### Operational

- [ ] Backfill/replay script can rebuild entitlement state from journal.
- [ ] Failed events are observable and recoverable.

## Exit Criteria

1. Entitlement store is primary source for `/resolve`.
2. Webhook replay is safe and idempotent.
3. Tier precedence and ordering rules are proven by tests.
4. Fallback usage is measurable and low.

## Rollback Plan

1. Keep fallback provider lookup enabled for temporary recovery.
2. Disable projector writes if severe bug is detected.
3. Replay events after hotfix to rebuild consistent state.
