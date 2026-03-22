# Entitlement Cache Invalidation Fix

## Problem Summary

After device revoke + re-login, users get VIP back without needing to restore.
Root cause: `user_entitlements` table is a write-once cache that never gets re-verified against Dodo.

---

## Verified Bugs (from code + DB + logs)

### Bug 1: `resolveTierForUser` trusts cached tier forever
**File:** `backend/src/user-entitlements.ts:108-111`
```
if (userEntitlement && userEntitlement.state === "active") {
    return { tier, source: "user-store" };  // NEVER checks Dodo
}
```
Once `user_entitlements` has `state=active`, resolve returns immediately. Even if the license was revoked in Dodo, user keeps VIP.

### Bug 2: `ensureDeviceSeat` clears `revoked_at` unconditionally
**File:** `backend/src/user-entitlements.ts:230-234`
```
UPDATE user_devices SET revoked_at = NULL ...
```
When a revoked device calls resolve, `ensureDeviceSeat` clears `revoked_at`, re-activating the device.

### Bug 3: Device revoke doesn't clear entitlement cache
**File:** `backend/src/routes/devices-revoke.ts:31`
```
await revokeUserDevice(env, principal.userId, installId);
// Only sets revoked_at on device. user_entitlements untouched.
```

### Bug 4: Session revoke doesn't clear entitlement cache
**File:** `backend/src/routes/auth-session-revoke.ts:13`
```
await revokeAuthSession(request, env);
// Only revokes session token. user_entitlements untouched.
```

### Bug 5: resolve.ts has partial fix (revoked device check) but still trusts cached tier
**File:** `backend/src/routes/resolve.ts:102-104`
```
if (existingDevice?.revoked_at) {
    tier = "free";  // Forces free for revoked device
}
```
This prevents revoked devices from getting VIP, BUT only works if the device was previously registered. A NEW install_id (e.g., new Xcode build) bypasses this check entirely — `existingDevice` is null, so it falls through to `ensureDeviceSeat` which creates a new active device and returns VIP from the cached `user_entitlements`.

---

## BEFORE Flow (Current Bugs)

```
User has VIP (stored in user_entitlements)

Sign Out → Sign In:
  ├─ Client: clears local keychain ✓
  ├─ Backend: session revoked, BUT user_entitlements untouched ✗
  ├─ Re-login → resolve → reads user_entitlements → VIP! ✗
  └─ Result: VIP restored without checking Dodo ✗

Device Revoke → Sign In:
  ├─ Client: clears local keychain ✓
  ├─ Backend: device revoked_at set, BUT user_entitlements untouched ✗
  ├─ Re-login (same install_id) → resolve checks revoked_at → "free" ✓
  ├─ Re-login (NEW install_id) → resolve finds no device → ensureDeviceSeat
  │   → creates new device → returns VIP from cached user_entitlements ✗
  └─ Result: VIP restored on any new build ✗

License revoked in Dodo dashboard:
  ├─ Webhook: license_key.revoked → projector sets state=inactive ✓ (if webhook fires)
  ├─ No webhook? → user_entitlements stays active forever ✗
  └─ Result: Depends entirely on webhook delivery ✗
```

## AFTER Flow (Fixed)

```
User has VIP (stored in user_entitlements)

Sign Out → Sign In:
  ├─ Client: clears local keychain ✓
  ├─ Backend: session revoked (no entitlement change — correct for sign-out) ✓
  ├─ Re-login → resolve → reads user_entitlements → VIP ✓
  └─ Result: VIP preserved (sign-out is not a license action) ✓

Device Revoke → Sign In (same or new device):
  ├─ Client: clears local keychain ✓
  ├─ Backend: device revoked_at set + DELETE user_entitlements + DELETE entitlements ✓
  ├─ Re-login → resolve → no cached row → falls through to Dodo API ✓
  ├─ Dodo says license active? → VIP restored + re-cached ✓
  ├─ Dodo says license revoked? → Free ✓
  └─ Result: Always fresh from Dodo after device revoke ✓

License revoked in Dodo dashboard:
  ├─ Webhook fires → projector sets state=inactive ✓
  ├─ No webhook? → next device revoke forces re-check ✓
  └─ Result: Self-healing on next device revoke ✓
```

---

## Implementation Plan

### Phase 1: Backend — Clear entitlement cache on device revoke

**File: `backend/src/user-entitlements.ts`**
- Add `clearUserEntitlementCache(env, userId, email)` function
  - DELETE from `user_entitlements` WHERE `user_id = ?`
  - DELETE from `entitlements` WHERE `subject_type = 'email' AND subject_id = ?`

**File: `backend/src/routes/devices-revoke.ts`**
- After `revokeUserDevice()`, call `clearUserEntitlementCache()`
- This forces next resolve to re-check Dodo

### Phase 2: Backend — Fix `resolveTierForUser` Dodo fallback for VIP licenses

**File: `backend/src/user-entitlements.ts`**
- Current `findActiveSubscription()` only checks subscriptions (Pro)
- VIP is a license key, not a subscription — Dodo fallback never finds VIP
- Need to also check Dodo license key status in the fallback path

**File: `backend/src/dodo-client.ts`**
- Add `findActiveLicenseKey(email)` method
  - Query Dodo: GET /license_keys?customer_id=X&status=active
  - Check if any license has product_id matching VIP

### Phase 3: Backend — Remove resolve.ts revoked-device check (superseded)

**File: `backend/src/routes/resolve.ts`**
- Remove the `existingDevice?.revoked_at` check (lines 95-111)
- No longer needed: device revoke now clears the entitlement cache
- resolve simply calls `resolveTierForUser` → which re-checks Dodo if no cache
- Then calls `ensureDeviceSeat` normally

### Phase 4: Deploy + Clean + Test

1. Deploy backend to test
2. Clean test DB (user_entitlements, entitlements, user_devices for test user)
3. Clean client Keychain
4. Test: sign in → VIP → revoke → sign in → should be Free → restore → VIP again

---

## Files to Modify

| File | Change |
|---|---|
| `backend/src/user-entitlements.ts` | Add `clearUserEntitlementCache()` |
| `backend/src/routes/devices-revoke.ts` | Call cache clear after revoke |
| `backend/src/dodo-client.ts` | Add `findActiveLicenseKey()` for VIP fallback |
| `backend/src/routes/resolve.ts` | Remove revoked-device check, simplify |

## Files NOT Modified (verified correct)

| File | Why |
|---|---|
| `routes/auth-session-revoke.ts` | Sign-out should NOT clear entitlements (session ≠ license) |
| `routes/restore.ts` | Restore flow is correct — always checks Dodo + writes cache |
| `projector.ts` | Webhook handling is correct — sets state=inactive on revoke |
| Swift `EntitlementService.swift` | Client cleanup is correct after merge |
