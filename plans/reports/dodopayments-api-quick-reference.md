# DodoPayments API Quick Reference — Giveaways & Promotions

## CREATE 100% DISCOUNT CODE

**Endpoint:** `POST https://live.dodopayments.com/discounts`

```bash
curl -X POST https://live.dodopayments.com/discounts \
  -H "Authorization: Bearer YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "percentage",
    "amount": 10000,
    "code": "STRATA_LIFETIME_2025",
    "name": "Strata Lifetime - Limited Time",
    "expires_at": "2026-06-30T23:59:59Z",
    "usage_limit": 100,
    "restricted_to": ["LIFETIME_PRODUCT_ID"]
  }'
```

**Key Points:**
- `amount: 10000` = 100% discount (basis points)
- Auto-generates code if omitted
- Works for one-time products (confirmed), subscriptions (check support)

---

## CREATE PROMO CODE (Percentage)

```json
{
  "type": "percentage",
  "amount": 5000,
  "code": "STRATA25OFF",
  "name": "25% Off - Spring Launch",
  "expires_at": "2026-04-30T23:59:59Z",
  "usage_limit": 500
}
```

**Amount Mapping:**
- `100` = 1%
- `1000` = 10%
- `5000` = 50%
- `10000` = 100%

---

## CREATE FLAT DISCOUNT CODE (Dollar Amount)

```json
{
  "type": "flat",
  "amount": 2999,
  "code": "SAVE30",
  "name": "$30 Off",
  "usage_limit": 200
}
```

**Amount:** USD cents (2999 = $29.99)

---

## LIST ALL DISCOUNT CODES

**Endpoint:** `GET https://live.dodopayments.com/discounts`

```bash
curl -X GET "https://live.dodopayments.com/discounts?page_size=50&active=true" \
  -H "Authorization: Bearer YOUR_API_KEY"
```

**Query Params:**
- `page_size` (1-100, default 10)
- `page_number` (0-indexed)
- `code` (partial match, case-insensitive)
- `active` (true/false)
- `product_id` (filter by product)

---

## ACTIVATE LICENSE (Public, No Auth)

**Endpoint:** `POST https://live.dodopayments.com/licenses/activate`

```bash
curl -X POST https://live.dodopayments.com/licenses/activate \
  -H "Content-Type: application/json" \
  -d '{
    "license_key": "LK-ABC123-DEF456",
    "name": "John MacBook Pro"
  }'
```

**Response:**
```json
{
  "id": "lki_abc123",
  "license_key_id": "lic_xyz789",
  "name": "John MacBook Pro",
  "created_at": "2026-03-11T12:00:00Z",
  "customer": {
    "customer_id": "cust_abc",
    "email": "john@example.com"
  }
}
```

---

## VALIDATE LICENSE (Public, No Auth)

**Endpoint:** `POST https://live.dodopayments.com/licenses/validate`

```bash
curl -X POST https://live.dodopayments.com/licenses/validate \
  -H "Content-Type: application/json" \
  -d '{
    "license_key": "LK-ABC123-DEF456"
  }'
```

---

## DEACTIVATE LICENSE (Public, No Auth)

**Endpoint:** `POST https://live.dodopayments.com/licenses/deactivate`

```bash
curl -X POST https://live.dodopayments.com/licenses/deactivate \
  -H "Content-Type: application/json" \
  -d '{
    "license_key_instance_id": "lki_abc123"
  }'
```

---

## CHECKOUT WITH DISCOUNT PRE-APPLIED

**Hosted Checkout URL:**
```
https://checkout.dodopayments.com/?product_id=LIFETIME_PRODUCT&discount_code=STRATA_LIFETIME_2025&return_url=https://yourapp.com/success
```

**Programmatic (Checkout Session):**
```javascript
const session = await client.checkouts.create({
  product_id: 'LIFETIME_PRODUCT',
  discount_code: 'STRATA_LIFETIME_2025',
  return_url: 'https://yourapp.com/success',
  customer: { email: 'user@example.com' }
});
```

---

## KEY LIMITATIONS

| Feature | Status | Notes |
|---------|--------|-------|
| **Promo codes** | ✅ | Full support |
| **100% discounts** | ✅ | v1.30.0+ |
| **$0 payments** | ✅ | One-time products only |
| **Free checkout sessions** | ✅ | Via 100% discount |
| **Direct license issuance (API)** | ❌ | Must go through checkout or manually created |
| **Gift cards** | ❌ | Not available |
| **Discount code deletion** | ✅ | Supported |

---

## AUTHENTICATION

```
Authorization: Bearer YOUR_API_KEY
```

Generate API key: [DodoPayments Dashboard](https://app.dodopayments.com/developer/api-keys)

---

## TESTING

**Test Server:**
```
https://test.dodopayments.com/
```

**Live Server:**
```
https://live.dodopayments.com/
```

---

## ERROR CODES

### License Activation Errors

- `403` — License key cannot be activated (inactive/disabled)
- `404` — License key not found
- `422` — Activation limit reached (device quota exceeded)
- `500` — Server error

### Discount Errors

- `400` — Invalid request (missing required field, invalid amount)
- `401` — Unauthorized (missing/invalid API key)
- `422` — Validation error (code already exists, invalid expiration date)

---

**Last Updated:** 2026-03-11
**Documentation:** https://docs.dodopayments.com/api-reference
