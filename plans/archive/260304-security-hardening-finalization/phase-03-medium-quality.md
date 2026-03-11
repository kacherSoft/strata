# Phase 3 — Medium Quality & Validation Fixes

Priority: **P2 — Before GA**
Status: Pending
Depends on: None (can run parallel with Phase 1/2, see file conflicts in plan.md)
Estimated tasks: 7
Parallelism: **All 7 tasks can run in parallel** (different files/sections)

## Overview

Fix medium-severity validation gaps, input handling, and quality issues. These prevent edge-case abuse and improve robustness but are not active exploits.

## Agent Assignment Strategy

```
Agent H (validation.ts):     Tasks 3-1, 3-6           [PARALLEL — same file, different functions]
Agent I (auth.ts):            Task 3-2                 [PARALLEL — different section from Phase 1]
Agent J (index.ts):           Tasks 3-3, 3-4           [SEQUENTIAL — same file]
Agent K (projector.ts):       Task 3-5                 [PARALLEL — after Phase 1-6 and Phase 2-2/2-3]
Agent L (Swift client):       Task 3-7                 [PARALLEL — client-only]
```

**File conflict note**: Task 3-5 touches `projector.ts` which is modified by Phase 1 (1-6) and Phase 2 (2-2, 2-3). Run after those complete. Task 3-2 touches `auth.ts` which is modified by Phase 1 (1-1 through 1-5). Run after Phase 1 auth.ts tasks.

Minimum 3 agents. Ideal 5 agents.

---

## Task 3-1: Email Length Validation [PARALLEL]

**Severity**: MEDIUM
**File**: `backend/src/validation.ts:26-36`

**Current problem**: `requireEmail()` uses regex but has no length cap. RFC 5321 limits emails to 254 characters. Extremely long strings consume memory in `.trim().toLowerCase()` and D1 storage.

**Action**:
```typescript
export function requireEmail(value: unknown): string {
    if (typeof value !== "string") {
        throw new AppError(400, "INVALID_EMAIL", "email is required");
    }
    const normalized = value.trim().toLowerCase();
    if (normalized.length > 254) {
        throw new AppError(400, "INVALID_EMAIL", "email exceeds maximum length");
    }
    if (!EMAIL_RE.test(normalized)) {
        throw new AppError(400, "INVALID_EMAIL", "email format is invalid");
    }
    return normalized;
}
```

**Test**: Submit email with 255+ characters → verify 400 response.

---

## Task 3-2: OTP Modulo Bias Fix [PARALLEL]

**Severity**: LOW
**File**: `backend/src/auth.ts:141-152`

**Current problem**: `byte % 10` produces biased distribution. Digits 0-5 appear ~3.9% more often than 6-9. Negligible practical impact but easy fix.

**Action** — Use rejection sampling:
```typescript
function randomDigits(length: number): string {
    const out: string[] = [];
    while (out.length < length) {
        const buffer = new Uint8Array(length * 2); // Over-allocate for rejections
        crypto.getRandomValues(buffer);
        for (const byte of buffer) {
            if (byte >= 250) continue; // Reject biased values (250-255)
            out.push(String(byte % 10));
            if (out.length >= length) break;
        }
    }
    return out.join("");
}
```

**Rationale**: Values 0-249 distribute evenly across digits 0-9 (25 values each). Values 250-255 are discarded. Over-allocating `length * 2` ensures enough non-rejected bytes in a single pass.

**Test**: Generate 100,000 OTPs → verify chi-squared test shows uniform distribution.

---

## Task 3-3: Request Body Size Limit [PARALLEL]

**Severity**: MEDIUM
**File**: `backend/src/index.ts` — add before route dispatch

**Current problem**: No application-level body size check. Platform limit is 100MB (Cloudflare Workers). A large malicious payload is fully buffered before any validation.

**Action** — Add centralized body size check in the router:
```typescript
// After CORS preflight check, before route matching:
if (method === "POST") {
    const contentLength = parseInt(request.headers.get("Content-Length") || "0", 10);
    if (contentLength > 1_048_576) { // 1MB — generous for all endpoints
        const requestId = generateRequestId();
        response = errorResponse(413, "BODY_TOO_LARGE", "Request body exceeds size limit", requestId);
        // Attach CORS and return early
        const corsResp = new Response(response.body, response);
        for (const [key, value] of Object.entries(corsHeaders())) {
            corsResp.headers.set(key, value);
        }
        return corsResp;
    }
}
```

**Note**: `Content-Length` can be spoofed. For defense-in-depth, individual handlers can also check `body.length` after parsing. But the header check prevents buffering.

**Test**: Send POST with `Content-Length: 2000000` → verify 413 response before body is read.

---

## Task 3-4: Content-Type Validation [PARALLEL]

**Severity**: LOW
**File**: `backend/src/index.ts` — add before route dispatch

**Current problem**: No Content-Type check. POST endpoints parse JSON regardless of Content-Type header. Could allow CSRF-like probes from HTML forms.

**Action** — Add after body size check:
```typescript
if (method === "POST") {
    const contentType = request.headers.get("Content-Type") || "";
    // Webhook endpoint may receive varying Content-Types from provider
    if (path !== "/v1/webhooks/dodo" && !contentType.includes("application/json")) {
        const requestId = generateRequestId();
        response = errorResponse(415, "UNSUPPORTED_MEDIA_TYPE",
            "Content-Type must be application/json", requestId);
        const corsResp = new Response(response.body, response);
        for (const [key, value] of Object.entries(corsHeaders())) {
            corsResp.headers.set(key, value);
        }
        return corsResp;
    }
}
```

**Note**: Exclude webhook endpoint since Dodo/Svix may use varying Content-Type headers.

**Test**: Send POST to `/v1/auth/email/start` with `Content-Type: text/plain` → verify 415.

---

## Task 3-5: Subscription Product ID in Projector [PARALLEL — after Phase 1-6, 2-2, 2-3]

**Severity**: MEDIUM
**File**: `backend/src/projector.ts` — subscription event branch (~lines 105-129)

**Current problem**: All subscription events hardcode `tier: "pro"`. The `product_id` field from subscription data is never examined. If Dodo sends a subscription event for a VIP product, it would be projected as Pro.

**Action**:
1. Import `PRODUCT_IDS` (already imported in the file).
2. Extract product_id and map to correct tier in the subscription branch:
```typescript
case "subscription.active":
case "subscription.renewed":
case "subscription.updated":
case "subscription.plan_changed": {
    const email = extractEmail(data);
    if (!email) return null;
    const state = normalizeSubscriptionState(eventType, data);
    if (!state) return null;
    // Determine tier from product_id
    const productId = ((data.product_id as string) || "").trim();
    const tier: Tier = productId === PRODUCT_IDS.vipLifetime ? "vip" : "pro";
    return {
        tier,
        state,
        subjectType: "email",
        subjectId: email,
        effectiveFrom: ...,
        effectiveUntil: ...,
    };
}
```

3. Apply same logic to inactive subscription events:
```typescript
case "subscription.cancelled":
case "subscription.expired":
case "subscription.failed":
case "subscription.on_hold": {
    // Same product_id extraction
    const productId = ((data.product_id as string) || "").trim();
    const tier: Tier = productId === PRODUCT_IDS.vipLifetime ? "vip" : "pro";
    // ...
}
```

**Test**: Send `subscription.active` with `product_id: vipLifetime` → verify tier is "vip" not "pro".

---

## Task 3-6: Nickname Validation [PARALLEL]

**Severity**: LOW
**File**: `backend/src/validation.ts` — add new function

**Current problem**: Device nickname stored as-is with no length or character validation. No current endpoint accepts user-supplied nicknames, but the field exists in schema and API responses.

**Action** — Add proactive validation:
```typescript
export function sanitizeNickname(value: unknown): string | null {
    if (value === null || value === undefined) return null;
    if (typeof value !== "string") return null;
    const trimmed = value.trim().slice(0, 100); // Max 100 chars
    if (trimmed.length === 0) return null;
    // Strip control characters
    return trimmed.replace(/[\x00-\x1F\x7F]/g, "");
}
```

Update `ensureDeviceSeat` in `user-entitlements.ts` to use it:
```typescript
const nickname = sanitizeNickname(params.nickname);
```

**Test**: Submit nickname with 200 chars → verify truncated to 100. Submit nickname with control chars → verify stripped.

---

## Task 3-7: Seat Limit Error UI (Client) [PARALLEL]

**Severity**: MEDIUM
**File**: `TaskManager/Sources/TaskManager/Views/Premium/SubscriptionLinkingView.swift`

**Current problem**: When backend returns `DEVICE_LIMIT_REACHED`, the client shows a generic error. No guidance to manage devices.

**Action**:
1. Parse `error_code` from the response body.
2. If `error_code === "DEVICE_LIMIT_REACHED"`, show specific UI:
   - Message: "Device limit reached for your plan."
   - Action button: "Manage Devices" → navigate to ManageDevicesView
   - Secondary text: "Remove an unused device to activate on this one."
3. Keep generic error display for other error codes.

**Test**: Trigger DEVICE_LIMIT_REACHED from backend → verify client shows device management prompt.

---

## Exit Criteria

- [ ] Email validation rejects > 254 characters
- [ ] OTP generation uses rejection sampling (unbiased)
- [ ] POST requests > 1MB rejected with 413
- [ ] Non-JSON Content-Type rejected with 415 (except webhook)
- [ ] Subscription events use product_id for tier mapping
- [ ] Nickname validated and length-capped
- [ ] Client shows actionable seat limit error with device management link
- [ ] All existing tests pass

## Verification

```bash
cd backend && npm run test

# Manual:
# 1. Submit 300-char email → 400
# 2. POST with Content-Type: text/plain → 415
# 3. POST with Content-Length: 2MB → 413
# 4. Trigger seat limit from device → verify client shows "Manage Devices"
```
