# DodoPayments API Research: Giveaway & Promotion Capabilities

**Date:** 2026-03-11
**Subject:** DodoPayments API capabilities for promo codes, giveaways, and license distribution
**Status:** Complete

---

## Executive Summary

DodoPayments **DOES support** several promotion mechanisms suitable for giveaways:

1. **Discount Codes** (Promo/Coupon codes) — ✅ Fully available via API
2. **100% Discount Codes** — ✅ Supported as of v1.30.0 (June 2025)
3. **$0 Payments** — ✅ Supported as of v1.30.0 for one-time products
4. **License Keys** — ✅ Available but with important limitations
5. **Gift Cards** — ❌ No evidence of dedicated gift card API
6. **Direct License Issuance API** — ❌ Not available; must go through checkout or dashboard

---

## 1. PROMO CODES / DISCOUNT CODES

### API Endpoint: Create Discount

**Endpoint:** `POST /discounts`

**Servers:**
- Test: `https://test.dodopayments.com/discounts`
- Live: `https://live.dodopayments.com/discounts`

**Authentication:** Bearer token (required)

**Request Payload:**

```json
{
  "type": "percentage",
  "amount": 10000,
  "code": "GIVEAWAY2025",
  "name": "Special Promotion",
  "expires_at": "2026-12-31T23:59:59Z",
  "usage_limit": 1000,
  "subscription_cycles": null,
  "preserve_on_plan_change": false,
  "restricted_to": ["product_id_1", "product_id_2"]
}
```

**Field Specifications:**

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| `type` | enum | Yes | "percentage", "flat", or "flat_per_unit" |
| `amount` | integer | Yes | If percentage: basis points (10000 = 100%). If flat: USD cents (100 = $1.00) |
| `code` | string | No | 3+ chars, auto-generated if omitted (16-char uppercase) |
| `name` | string | No | Display name for dashboard |
| `expires_at` | ISO timestamp | No | Optional expiration date |
| `usage_limit` | integer | No | Max usage count across all customers |
| `subscription_cycles` | integer | No | Limit to N billing cycles; null = indefinite |
| `preserve_on_plan_change` | boolean | No | Preserve discount if customer changes subscription plan |
| `restricted_to` | array | No | Product IDs to restrict discount to |

**Response (200 OK):**

```json
{
  "discount_id": "disc_abc123",
  "business_id": "bus_xyz",
  "code": "GIVEAWAY2025",
  "type": "percentage",
  "amount": 10000,
  "name": "Special Promotion",
  "times_used": 0,
  "usage_limit": 1000,
  "created_at": "2026-03-11T12:00:00Z",
  "expires_at": "2026-12-31T23:59:59Z",
  "restricted_to": ["product_id_1", "product_id_2"],
  "subscription_cycles": null,
  "preserve_on_plan_change": false
}
```

### API Endpoint: List Discounts

**Endpoint:** `GET /discounts`

**Query Parameters:**

```
GET /discounts?page_size=10&page_number=0&code=GIVEAWAY&active=true&product_id=prod_123
```

| Parameter | Type | Default | Max | Notes |
|-----------|------|---------|-----|-------|
| `page_size` | integer | 10 | 100 | Results per page |
| `page_number` | integer | 0 | — | Zero-indexed |
| `code` | string | — | — | Partial match, case-insensitive |
| `discount_type` | enum | — | — | Filter by "percentage" |
| `active` | boolean | — | — | true = not expired, false = expired |
| `product_id` | string | — | — | Filter by product restriction |

**Response:** Paginated array of discount objects

### API Endpoint: Validate Discount

**Endpoint:** `GET /discounts/{discount_id}`

**Purpose:** Check if discount is valid and applicable before checkout

**Response:** Returns full discount object with validity status

### API Endpoint: Update Discount

**Endpoint:** `PATCH /discounts/{discount_id}`

**Purpose:** Modify existing discount configuration (amount, expiration, usage limits)

### Special Case: 100% Discount Codes

**Supported:** YES, as of v1.30.0 (June 2, 2025)

**To create a 100% discount:**

```json
{
  "type": "percentage",
  "amount": 10000,
  "code": "FREE_LIFETIME",
  "usage_limit": 50
}
```

The `amount: 10000` represents 10,000 basis points = 100% discount.

---

## 2. FREE CHECKOUT SESSIONS / $0 PAYMENTS

### Status: ✅ Supported as of v1.30.0

**Release Notes (June 2, 2025):**
> "Support for $0 payments and 100% discount codes for one-time products, enabling free product offerings."

**Implementation Methods:**

#### Option A: Use 100% Discount Code
1. Create discount with `amount: 10000` (100%)
2. Apply discount code at checkout
3. Customer completes checkout with $0 charge

#### Option B: Check for Zero-Dollar Amount
- DodoPayments explicitly supports "$0 payments" for one-time products
- No special endpoint documented — uses standard checkout flow with zero amount

**Limitations:**
- **One-time products only** — not for subscriptions
- Must be applied at checkout time (not pre-applied universally)
- Requires customer to go through checkout process

---

## 3. LICENSE KEYS

### Status: ⚠️ Partially Available

DodoPayments provides license key management with public activation endpoints, but **does not expose a programmatic API for issuing new licenses**.

### Available Endpoints

#### Activate License (Public)

**Endpoint:** `POST /licenses/activate`

**Authentication:** None required (public endpoint)

**Request Payload:**

```json
{
  "license_key": "LK-ABC123-DEF456",
  "name": "User Device Name"
}
```

**Response (201 Created):**

```json
{
  "id": "lki_abc123",
  "business_id": "bus_xyz",
  "name": "User Device Name",
  "license_key_id": "lic_xyz789",
  "created_at": "2026-03-11T12:00:00Z",
  "product": {
    "product_id": "prod_123",
    "name": "Strata"
  },
  "customer": {
    "customer_id": "cust_abc",
    "name": "John Doe",
    "email": "john@example.com",
    "phone_number": null,
    "metadata": {}
  }
}
```

**Error Responses:**
- `403`: License key cannot be activated (inactive)
- `404`: License key not found
- `422`: Activation limit reached
- `500`: Server error

#### Deactivate License (Public)

**Endpoint:** `POST /licenses/deactivate`

**Purpose:** Revoke an activation to free up license seat capacity

#### Validate License (Public)

**Endpoint:** `POST /licenses/validate`

**Purpose:** Check license key validity and constraints

#### List/Get License Keys (Authenticated)

**Endpoints:**
- `GET /licenses` — List all license keys
- `GET /licenses/{license_key_id}` — Get specific license key

**Response includes:**
- Expiration settings
- Activation limits
- Current activation count
- Device instance details

#### Update License Key (Authenticated)

**Endpoint:** `PATCH /licenses/{license_key_id}`

**Purpose:** Modify expiry dates, activation limits, or status

### How Licenses Are Currently Issued

**Dashboard Method (Only):**
1. Navigate to License Keys in DodoPayments dashboard
2. Configure expiration, activation limits
3. Save configuration
4. System generates license keys automatically on product purchase

**Automatic Issuance at Checkout:**
- When customer purchases a product with license keys enabled
- License key appears in checkout return URL:
  ```
  https://yoursite.com/return?payment_id=pay_xxx&license_key=LK-001
  ```

**Important Limitation:**
- ❌ **No API endpoint to directly create/issue new license keys**
- ❌ **Cannot bypass checkout flow for admin-granted licenses**
- Licenses must either:
  1. Be pre-generated in dashboard and manually distributed, OR
  2. Be auto-generated upon product purchase

---

## 4. GIFT CARDS / GIFT CODES

### Status: ❌ Not Available

**Finding:** No evidence of dedicated gift card or gift code API in DodoPayments documentation.

**Search Results:**
- No Gift Cards section in API reference
- No gift code endpoints documented
- Platform focuses on discount codes, not gift cards

**Alternative:** Use discount codes as pseudo-gift cards by creating high-value flat-rate discounts with usage limits.

---

## 5. CHECKOUT INTEGRATION

### Discount Code Application in Checkout

**For Hosted Checkout Link:**

```
https://checkout.dodopayments.com/...?discount_code=GIVEAWAY2025
```

**For Programmatic Checkout:**

```javascript
const session = await client.checkouts.create({
  product_id: 'prod_123',
  return_url: 'https://yourapp.com/success',
  customer: {
    email: 'customer@example.com'
  },
  discount_code: 'GIVEAWAY2025'  // Pre-apply discount
});
```

**UI Controls:**
- `feature_flags.allow_discount_code` — Enable/disable customer-facing discount input field
- Discounts update total in real-time

---

## 6. PROMOTIONAL WORKFLOW RECOMMENDATIONS

### For Lifetime License Giveaways

**Recommended Flow:**

1. **Create a promotion product** at $0 base price (or use existing)
2. **Create a 100% discount code:**
   ```json
   {
     "type": "percentage",
     "amount": 10000,
     "code": "LIFETIME2025",
     "usage_limit": 100,
     "expires_at": "2026-06-30T23:59:59Z"
   }
   ```
3. **Share checkout link with discount pre-applied:**
   ```
   https://checkout.dodopayments.com/?product_id=LIFETIME_PRODUCT&discount_code=LIFETIME2025
   ```
4. **Users complete free checkout**
5. **Strata receives license key in webhook** and activates user account

### For Admin-Granted Promotions (Without Customer Checkout)

**Workaround (since no direct issuance API):**

1. Create a hidden/private discount code (e.g., `ADMIN_GRANT_001`)
2. Manually create license key in dashboard
3. Grant license key directly to user via email or in-app
4. User activates with `POST /licenses/activate`

**Better Alternative:**
- Contact DodoPayments support to request direct license issuance API endpoint
- Current platform limitation prevents purely admin-driven giveaways

---

## 7. API AUTHENTICATION

**All Authenticated Endpoints Require:**
```
Authorization: Bearer {API_KEY}
```

**Rate Limiting:** Not explicitly documented; check with DodoPayments support

---

## 8. CHANGELOG REFERENCES

| Version | Feature | Date |
|---------|---------|------|
| v1.30.0 | $0 payments & 100% discount codes (one-time products) | June 2, 2025 |
| v1.87.0 | Discount support in plan change | — |
| v0.24.0 | Discount coupons introduced | — |

---

## 9. UNRESOLVED QUESTIONS & GAPS

1. **Can licenses be issued directly via API?** NO — not publicly exposed
2. **Do discount codes work for subscriptions?** Partially — subscription_cycles parameter available, but 100% discounts only confirmed for one-time products
3. **Can gift cards be created?** NO — feature not available
4. **What's the maximum discount percentage?** 10,000 basis points (100%) confirmed; no mention of higher values
5. **Are discount codes case-sensitive?** Code filtering is case-insensitive; actual usage not specified
6. **Can $0 be applied to subscriptions?** Documentation says "one-time products only"
7. **What's the rate limit for API calls?** Not documented; contact support
8. **Can discounts be retroactively applied?** No indication; likely not

---

## 10. ENDPOINTS SUMMARY TABLE

| Endpoint | Method | Auth | Purpose | Status |
|----------|--------|------|---------|--------|
| `/discounts` | POST | ✅ | Create discount code | ✅ Full |
| `/discounts` | GET | ✅ | List discounts | ✅ Full |
| `/discounts/{id}` | GET | ✅ | Get discount details | ✅ Full |
| `/discounts/{id}` | PATCH | ✅ | Update discount | ✅ Full |
| `/licenses/activate` | POST | ❌ | Activate license | ✅ Full |
| `/licenses/deactivate` | POST | ❌ | Deactivate license | ✅ Full |
| `/licenses/validate` | POST | ❌ | Validate license | ✅ Full |
| `/licenses` | GET | ✅ | List licenses | ✅ Full |
| `/licenses/{id}` | GET | ✅ | Get license | ✅ Full |
| `/licenses/{id}` | PATCH | ✅ | Update license | ✅ Full |
| License issuance (create) | POST | — | Create new license | ❌ Not available |
| Gift card endpoints | — | — | Gift cards | ❌ Not available |

---

## 11. SOURCES & DOCUMENTATION REFERENCES

- [Discounts API - Create Discount](https://docs.dodopayments.com/api-reference/discounts/create-discount)
- [Discounts API - List Discounts](https://docs.dodopayments.com/api-reference/discounts)
- [Discount Code Features](https://docs.dodopayments.com/features/discount-codes)
- [License Keys Features](https://docs.dodopayments.com/features/license-keys)
- [License Keys Product Page](https://dodopayments.com/distribution/license-keys)
- [Activate License Endpoint](https://docs.dodopayments.com/api-reference/licenses/activate-license)
- [v1.30.0 Changelog - $0 Payments Support](https://docs.dodopayments.com/changelog/v1.30.0)
- [Official API Reference](https://docs.dodopayments.com/api-reference/introduction)

---

## 12. RECOMMENDATIONS FOR STRATA

### Immediate Actions ✅

1. **Implement 100% Discount Codes** for promotional giveaways
   - Use `type: "percentage"` with `amount: 10000`
   - Set appropriate expiration and usage limits
   - Auto-generate codes or use branded codes (e.g., "STRATA_LAUNCH")

2. **Integrate License Activation Flow**
   - Call `POST /licenses/activate` from Strata app
   - Capture user device name
   - Store returned license activation ID for tracking

3. **Pre-Generate License Keys** in DodoPayments dashboard for giveaway campaigns
   - Manually create batch of licenses before promotion
   - Distribute license keys via email/in-app messaging
   - Users activate with their device name

### Future Considerations

1. **Request Custom API Extension** from DodoPayments
   - Ask for `POST /licenses` endpoint to issue licenses programmatically
   - Enables true admin-driven giveaways without checkout

2. **Monitor Feature Releases**
   - Watch changelog for new promotional features
   - Subscribe to product announcements

3. **Consider Fallback Solutions**
   - Use discount codes as primary promotion vehicle
   - Combine with license activation for full flow
   - Document workaround in marketing materials

---

**Report Generated:** 2026-03-11
**Next Steps:** Implement discount code creation and integrate license activation endpoints into Strata checkout flow
