# DodoPayments Giveaway Capabilities — Executive Summary

**Research Date:** 2026-03-11
**Project:** Strata promotional licensing strategy

---

## KEY FINDINGS

### ✅ WHAT'S POSSIBLE

1. **Promo/Discount Codes** — FULL API support
   - Create via `POST /discounts` endpoint
   - Percentage-based (basis points: 10000 = 100%)
   - Flat-amount discounts (USD cents)
   - Usage limits, expiration dates, product restrictions

2. **100% Discount Codes** — CONFIRMED (v1.30.0+)
   - Set `type: "percentage"`, `amount: 10000`
   - Customers get full product for free
   - Works for one-time purchases
   - Released June 2, 2025

3. **Free Checkout Sessions** — AVAILABLE
   - Use 100% discount code, or
   - Create product at $0 base price
   - Customer completes checkout with $0 charge
   - Returns payment ID + any associated license key

4. **License Key Management** — PARTIAL
   - Public activation endpoint (`POST /licenses/activate`)
   - No authentication required for user activation
   - Supports activation limits (per-device seat capacity)
   - Full CRUD endpoints for authenticated admin operations

---

### ❌ WHAT'S NOT POSSIBLE (Currently)

1. **Direct License Key Issuance via API**
   - No `POST /licenses` endpoint to programmatically create licenses
   - Licenses auto-generated only when product is purchased at checkout
   - Workaround: Pre-create licenses in dashboard, distribute manually

2. **Admin-Granted Licenses Without Checkout**
   - Cannot bypass payment/checkout flow for giveaway licenses
   - Every license must either be:
     - Pre-generated in dashboard + manually given to user, OR
     - Auto-generated from checkout purchase

3. **Gift Cards**
   - Zero evidence of gift card or gift code API
   - Platform designed around discounts, not separate gift card system
   - Can use high-value flat-rate discounts as pseudo-gift cards

---

## RECOMMENDED GIVEAWAY FLOW FOR STRATA

```
┌─────────────────────────────────────┐
│  Create Giveaway Campaign           │
├─────────────────────────────────────┤
│ 1. Create 100% discount code        │
│    - type: "percentage"             │
│    - amount: 10000 (100%)           │
│    - code: "STRATA_LIFETIME_2025"   │
│    - usage_limit: 100               │
│    - expires_at: 2026-06-30         │
│                                     │
│ 2. Share checkout link with code:   │
│    checkout.dodopayments.com/...    │
│    ?product_id=LIFETIME             │
│    &discount_code=STRATA_LIFETIME   │
│    &return_url=strata.app/activate  │
│                                     │
│ 3. User clicks link, sees $0 price  │
│    Completes checkout (no payment)  │
│                                     │
│ 4. DodoPayments webhook fires:      │
│    - payment_id                     │
│    - license_key (LK-XXX)           │
│                                     │
│ 5. Strata receives webhook          │
│    Activates license in user account│
│    (or guides user through          │
│     /licenses/activate endpoint)    │
│                                     │
│ 6. User has lifetime license        │
└─────────────────────────────────────┘
```

---

## API ENDPOINTS FOR IMPLEMENTATION

### 1. Create Discount Code (Admin Tool)

```
POST https://live.dodopayments.com/discounts
Authorization: Bearer {API_KEY}

{
  "type": "percentage",
  "amount": 10000,
  "code": "STRATA_LIFETIME_2025",
  "name": "Strata Lifetime License",
  "expires_at": "2026-06-30T23:59:59Z",
  "usage_limit": 100
}
```

**Response:** discount_id, code, created_at, etc.

### 2. List Discount Codes (Admin Dashboard)

```
GET https://live.dodopayments.com/discounts?page_size=50&active=true
Authorization: Bearer {API_KEY}
```

**Response:** Array of discount codes with usage stats

### 3. Activate License (User Device)

```
POST https://live.dodopayments.com/licenses/activate
(No authentication required)

{
  "license_key": "LK-ABC123-DEF456",
  "name": "John's MacBook Pro"
}
```

**Response:** activation_id, customer_email, created_at

### 4. Webhook Listener (Backend)

```javascript
// Receives from DodoPayments on successful payment
{
  "event": "payment.completed",
  "payment_id": "pay_xxx",
  "license_key": "LK-ABC123-DEF456",  // If product has licenses
  "customer": { "email": "user@example.com" },
  "amount": 0  // Will be 0 for 100% discount
}
```

---

## IMPORTANT CONSTRAINTS

| Constraint | Impact | Workaround |
|-----------|--------|-----------|
| $0 payments only for one-time products | Can't offer free subscriptions | Offer subscription at steep discount |
| No direct license creation API | Can't do instant admin giveaways | Pre-generate batch in dashboard |
| License issuance tied to checkout | Every license flows through payment system | Use hidden $0 products for giveaways |
| No gift card support | Can't create standalone gift codes | Use discount codes as substitutes |
| Discount codes not case-sensitive | Code collision possible | Use unique, branded codes |

---

## SUCCESS METRICS FOR GIVEAWAY

1. **Code Creation:** API returns valid discount_id
2. **Code Application:** Discount appears in checkout, reduces total to $0
3. **Payment Processing:** Payment completes with $0 charge
4. **License Delivery:** Webhook delivers license_key to backend
5. **User Activation:** User or backend calls `/licenses/activate`
6. **Seat Counting:** User shows up in Strata with active lifetime seat

---

## COST CONSIDERATIONS

- **Discount codes:** Free to create, no quota mentioned
- **$0 payments:** No transaction fee (verify with support)
- **License keys:** Included with DodoPayments plan
- **Activation limit:** Set per-product (e.g., 2 devices for Pro tier)

---

## NEXT STEPS

### Phase 1: Setup (Immediate)
1. Create test 100% discount code in DodoPayments sandbox
2. Test checkout flow with discount applied
3. Verify $0 payment processes correctly
4. Test license key delivery via webhook

### Phase 2: Integration (1-2 weeks)
1. Add discount code management to Strata admin panel
2. Implement `POST /discounts` endpoint wrapper
3. Wire license activation endpoint into onboarding flow
4. Add giveaway campaign dashboard (track code usage)

### Phase 3: Campaign Execution (Ongoing)
1. Create branded 100% discount codes for launches
2. Share checkout links via email/socials
3. Monitor usage metrics in DodoPayments dashboard
4. Adjust usage limits and expiration dates as needed

---

## DOCUMENTATION REFERENCES

- **Full Research Report:** `/plans/reports/research-dodopayments-giveaway-capabilities-260311.md`
- **API Quick Reference:** `/plans/reports/dodopayments-api-quick-reference.md`
- **Official Docs:** https://docs.dodopayments.com/api-reference
- **Changelog:** https://docs.dodopayments.com/changelog/v1.30.0

---

## UNRESOLVED ITEMS

- [ ] Confirm $0 payment fee structure with DodoPayments support
- [ ] Test multi-device activation limits in production
- [ ] Verify discount code case sensitivity in actual checkout
- [ ] Request timeline for `POST /licenses` API endpoint
- [ ] Clarify subscription discount behavior (if available)

---

**Status:** Research Complete ✅
**Ready for Implementation:** YES
**Risk Level:** Low (well-documented, proven features)

