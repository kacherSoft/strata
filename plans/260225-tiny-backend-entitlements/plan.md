# Strata Backend & Entitlements - Master Implementation Tracker

Date: 2026-02-26  
Status: Active implementation plan (split by phase)

## Goal

Ship a small backend (Cloudflare Workers + D1) and updated client entitlement flow that:

1. Removes Dodo secret API keys from the distributed macOS app.
2. Enables instant entitlement activation after checkout.
3. Unifies VIP + Pro restore from one user entry point.
4. Hardens client-side entitlement trust against common tampering.

## Release Policy (Non-Negotiable)

This plan assumes internal development can run with temporary risk in early phases.

1. No public production release before all Phase 3 exit criteria are complete.
2. No external customer rollout while `/resolve` accepts `email + install_id` without install proof.
3. GA requires install-bound proof (`Secure Enclave` signature) for entitlement issuance.
4. GA requires direct insecure fallback paths to be disabled in release builds.

## Why This Split Exists

The original single-file plan was hard to track during implementation.  
This tracker keeps cross-phase decisions in one place and moves execution details to one file per phase.

## Phase Documents

1. [Phase 1 - Secure Proxy + Signed Tokens](./phase-01-secure-proxy-signed-tokens.md)
2. [Phase 2 - Webhooks + Entitlement Store](./phase-02-webhooks-entitlement-store.md)
3. [Phase 3 - Instant Activation + Restore + Install Binding](./phase-03-instant-activation-restore-binding.md)

## Cross-Phase Security Model

| Control | Description | Phase |
|---|---|---|
| C0 | Server-signed entitlement tokens (Ed25519) | 1 |
| C1 | Secure Enclave install binding with nonce challenge | 3 |
| C2 | Hardened Runtime + release entitlement verification | 1 |
| C3 | Token expiry + clock rollback detection | 1 |
| C4 | Runtime self-integrity check (`SecCodeCheckValidity`) | 1 |

## Shared Architecture Decisions

### Backend

- Runtime: Cloudflare Workers
- Storage: D1 (SQLite)
- Signing: Ed25519 private key in Worker secrets only
- Provider ingest: Dodo webhooks

### App

- Token trust source: embedded Ed25519 public key
- Device trust source: Secure Enclave P-256 keypair (Phase 3)
- Local cache: signed token blob + clock checkpoint in Keychain

## Shared API Surface (Final Target)

### App-facing

- `POST /v1/entitlements/resolve`
- `POST /v1/checkout-sessions`
- `POST /v1/purchases/restore`
- `POST /v1/installs/register`
- `POST /v1/customer-portal/session` (optional but recommended)

### Provider-facing

- `POST /v1/webhooks/dodo`

## Shared Data Model (Final Target)

```sql
CREATE TABLE webhook_events (
  webhook_id    TEXT PRIMARY KEY,
  event_type    TEXT NOT NULL,
  event_ts      TEXT NOT NULL,
  payload_json  TEXT NOT NULL,
  received_at   TEXT NOT NULL DEFAULT (datetime('now')),
  processed_at  TEXT,
  status        TEXT NOT NULL DEFAULT 'pending'
);

CREATE TABLE purchase_links (
  id                  INTEGER PRIMARY KEY AUTOINCREMENT,
  install_id          TEXT NOT NULL,
  checkout_session_id TEXT,
  customer_id         TEXT,
  customer_email      TEXT,
  license_key_id      TEXT,
  install_pubkey      TEXT,
  created_at          TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at          TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE entitlements (
  id              INTEGER PRIMARY KEY AUTOINCREMENT,
  subject_type    TEXT NOT NULL,
  subject_id      TEXT NOT NULL,
  tier            TEXT NOT NULL DEFAULT 'free',
  state           TEXT NOT NULL DEFAULT 'inactive',
  source_event_id TEXT,
  effective_from  TEXT,
  effective_until TEXT,
  updated_at      TEXT NOT NULL DEFAULT (datetime('now')),
  UNIQUE(subject_type, subject_id)
);
```

## Master Milestone Checklist

- [ ] M1: Phase 1 completed and validated for internal testing.
- [ ] M2: Phase 2 completed; entitlement store authoritative.
- [ ] M3: Phase 3 completed; install binding and unified restore live.
- [ ] M4: GA gate review completed and signed off.

## GA Gate Checklist

All items below must be true before public release:

- [ ] `/resolve` requires install-bound proof (nonce signature).
- [ ] Release build has no Dodo secret key usage path.
- [ ] Legacy direct-fallback entitlement path disabled in release.
- [ ] Hardened Runtime explicitly verified for release artifacts.
- [ ] URL scheme + deep-link return path tested for checkout completion.
- [ ] Unified restore flow tested end-to-end (Pro + VIP).

## Out of Scope

1. Full user account system.
2. Multi-region failover.
3. Analytics warehouse.
4. TLS pinning unless active abuse requires it.

## Residual Risk

Local binaries can always be patched by skilled reversers.  
The target is to make offline cracking non-trivial while keeping server-backed capabilities protected by signed and bound tokens.
