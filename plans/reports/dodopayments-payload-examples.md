# DodoPayments API Payload Examples

Reference implementations for creating promotional codes and managing licenses.

---

## 1. CREATE 100% DISCOUNT CODE (Lifetime Giveaway)

### Scenario: Launch week free lifetime access

```bash
curl -X POST https://live.dodopayments.com/discounts \
  -H "Authorization: Bearer sk_live_abc123xyz789" \
  -H "Content-Type: application/json" \
  -d '{
  "type": "percentage",
  "amount": 10000,
  "code": "STRATA_LAUNCH_FREE",
  "name": "Strata Launch Week - Free Lifetime",
  "expires_at": "2026-03-18T23:59:59Z",
  "usage_limit": 1000
}'
```

### Response
```json
{
  "discount_id": "disc_1a2b3c4d",
  "business_id": "bus_xyz123",
  "code": "STRATA_LAUNCH_FREE",
  "type": "percentage",
  "amount": 10000,
  "name": "Strata Launch Week - Free Lifetime",
  "times_used": 0,
  "usage_limit": 1000,
  "created_at": "2026-03-11T10:00:00Z",
  "expires_at": "2026-03-18T23:59:59Z",
  "restricted_to": [],
  "subscription_cycles": null,
  "preserve_on_plan_change": false
}
```

---

## 2. CREATE PERCENTAGE DISCOUNT (Early Bird)

### Scenario: 30% off for first 100 customers

```bash
curl -X POST https://live.dodopayments.com/discounts \
  -H "Authorization: Bearer sk_live_abc123xyz789" \
  -H "Content-Type: application/json" \
  -d '{
  "type": "percentage",
  "amount": 3000,
  "code": "EARLYBIRD30",
  "name": "Early Bird - 30% Off",
  "expires_at": "2026-04-30T23:59:59Z",
  "usage_limit": 100,
  "restricted_to": ["prod_lifetime_license"]
}'
```

### Response
```json
{
  "discount_id": "disc_5e6f7g8h",
  "code": "EARLYBIRD30",
  "type": "percentage",
  "amount": 3000,
  "name": "Early Bird - 30% Off",
  "times_used": 0,
  "usage_limit": 100,
  "restricted_to": ["prod_lifetime_license"],
  "created_at": "2026-03-11T10:05:00Z"
}
```

**Note:** 3000 basis points = 30% discount

---

## 3. CREATE FLAT DOLLAR DISCOUNT

### Scenario: $50 off any purchase over $99

```bash
curl -X POST https://live.dodopayments.com/discounts \
  -H "Authorization: Bearer sk_live_abc123xyz789" \
  -H "Content-Type: application/json" \
  -d '{
  "type": "flat",
  "amount": 5000,
  "code": "SAVE50",
  "name": "$50 Off - Spring Sale",
  "expires_at": "2026-03-31T23:59:59Z",
  "usage_limit": 500
}'
```

### Response
```json
{
  "discount_id": "disc_9i0j1k2l",
  "code": "SAVE50",
  "type": "flat",
  "amount": 5000,
  "name": "$50 Off - Spring Sale"
}
```

**Note:** 5000 cents = $50.00 USD

---

## 4. CREATE AUTO-GENERATED DISCOUNT CODE

### Scenario: System auto-generates random 16-char code

```bash
curl -X POST https://live.dodopayments.com/discounts \
  -H "Authorization: Bearer sk_live_abc123xyz789" \
  -H "Content-Type: application/json" \
  -d '{
  "type": "percentage",
  "amount": 10000,
  "name": "Beta Tester - Free Lifetime",
  "expires_at": "2026-12-31T23:59:59Z",
  "usage_limit": 1
}'
```

### Response
```json
{
  "discount_id": "disc_3m4n5o6p",
  "code": "ABC123XYZ789QWER",
  "type": "percentage",
  "amount": 10000,
  "name": "Beta Tester - Free Lifetime",
  "created_at": "2026-03-11T10:10:00Z"
}
```

---

## 5. LIST ALL ACTIVE DISCOUNT CODES

### Scenario: Admin dashboard fetches all available codes

```bash
curl -X GET "https://live.dodopayments.com/discounts?page_size=50&active=true&code=STRATA" \
  -H "Authorization: Bearer sk_live_abc123xyz789"
```

### Response
```json
{
  "data": [
    {
      "discount_id": "disc_1a2b3c4d",
      "code": "STRATA_LAUNCH_FREE",
      "type": "percentage",
      "amount": 10000,
      "times_used": 247,
      "usage_limit": 1000,
      "expires_at": "2026-03-18T23:59:59Z",
      "created_at": "2026-03-11T10:00:00Z"
    },
    {
      "discount_id": "disc_5e6f7g8h",
      "code": "EARLYBIRD30",
      "type": "percentage",
      "amount": 3000,
      "times_used": 89,
      "usage_limit": 100,
      "expires_at": "2026-04-30T23:59:59Z"
    }
  ],
  "page_size": 50,
  "page_number": 0,
  "total": 2
}
```

---

## 6. UPDATE DISCOUNT CODE (Extend Expiry)

### Scenario: Extend successful campaign by 2 weeks

```bash
curl -X PATCH https://live.dodopayments.com/discounts/disc_1a2b3c4d \
  -H "Authorization: Bearer sk_live_abc123xyz789" \
  -H "Content-Type: application/json" \
  -d '{
  "expires_at": "2026-04-01T23:59:59Z",
  "usage_limit": 2000
}'
```

### Response
```json
{
  "discount_id": "disc_1a2b3c4d",
  "code": "STRATA_LAUNCH_FREE",
  "expires_at": "2026-04-01T23:59:59Z",
  "usage_limit": 2000,
  "times_used": 247
}
```

---

## 7. CHECKOUT WITH DISCOUNT PRE-APPLIED

### Scenario A: Hosted Checkout URL

```
https://checkout.dodopayments.com/?product_id=prod_lifetime_license&discount_code=STRATA_LAUNCH_FREE&return_url=https%3A%2F%2Fstrata.app%2Fcheckout-success&customer_email=user%40example.com
```

### Scenario B: Programmatic Checkout Session (TypeScript)

```typescript
import DodoPayments from '@dodopayments/client';

const client = new DodoPayments({
  bearerToken: 'sk_live_abc123xyz789',
});

const session = await client.checkouts.create({
  product_id: 'prod_lifetime_license',
  return_url: 'https://strata.app/checkout-success',
  customer: {
    email: 'user@example.com',
    name: 'John Doe'
  },
  discount_code: 'STRATA_LAUNCH_FREE'
});

console.log(session);
// Returns: {
//   checkout_id, checkout_url, expires_at, ...
// }
```

### Checkout Return URL (After Success)

User is redirected to:
```
https://strata.app/checkout-success?payment_id=pay_abc123&license_key=LK-XXXX-YYYY-ZZZZ
```

---

## 8. ACTIVATE LICENSE (User Device Registration)

### Scenario: User activates license on their Mac

```bash
curl -X POST https://live.dodopayments.com/licenses/activate \
  -H "Content-Type: application/json" \
  -d '{
  "license_key": "LK-STRATA-D7E8F9G0H1",
  "name": "John MacBook Pro 14\""
}'
```

### Response
```json
{
  "id": "lki_1a2b3c4d",
  "license_key_id": "lic_xyz123",
  "name": "John MacBook Pro 14\"",
  "business_id": "bus_strata",
  "created_at": "2026-03-11T14:30:00Z",
  "product": {
    "product_id": "prod_lifetime_license",
    "name": "Strata Lifetime"
  },
  "customer": {
    "customer_id": "cust_abc123",
    "name": "John Doe",
    "email": "john@example.com",
    "phone_number": null,
    "metadata": {}
  }
}
```

---

## 9. VALIDATE LICENSE (Check Before Use)

### Scenario: App checks if license is valid before granting access

```bash
curl -X POST https://live.dodopayments.com/licenses/validate \
  -H "Content-Type: application/json" \
  -d '{
  "license_key": "LK-STRATA-D7E8F9G0H1"
}'
```

### Response (Valid)
```json
{
  "valid": true,
  "license_key_id": "lic_xyz123",
  "status": "active",
  "activation_count": 2,
  "activation_limit": 3,
  "expires_at": null,
  "message": "License is valid and can be used"
}
```

### Response (Invalid/Expired)
```json
{
  "valid": false,
  "message": "License key not found",
  "status": 404
}
```

---

## 10. DEACTIVATE LICENSE (Remove Device)

### Scenario: User uninstalls from old laptop, needs to use activation on new one

```bash
curl -X POST https://live.dodopayments.com/licenses/deactivate \
  -H "Content-Type: application/json" \
  -d '{
  "license_key_instance_id": "lki_1a2b3c4d"
}'
```

### Response
```json
{
  "id": "lki_1a2b3c4d",
  "status": "deactivated",
  "deactivated_at": "2026-03-11T15:00:00Z"
}
```

---

## 11. WEBHOOK PAYLOAD (License Key Created at Checkout)

### Event: payment.completed

Strata backend receives this when customer completes free checkout:

```json
{
  "id": "evt_abc123xyz",
  "object": "event",
  "type": "payment.completed",
  "created_at": "2026-03-11T14:00:00Z",
  "data": {
    "payment_id": "pay_abc123",
    "business_id": "bus_strata",
    "status": "completed",
    "amount": 0,
    "currency": "USD",
    "product_id": "prod_lifetime_license",
    "customer": {
      "customer_id": "cust_abc123",
      "name": "Jane Smith",
      "email": "jane@example.com",
      "phone_number": null,
      "metadata": {}
    },
    "license_key": "LK-STRATA-D7E8F9G0H1",
    "discount_code": "STRATA_LAUNCH_FREE",
    "discount_amount": 9999,
    "metadata": {
      "product_name": "Strata Lifetime License",
      "campaign": "launch_week"
    }
  }
}
```

**Handle in Strata backend:**
1. Verify webhook signature
2. Extract license_key and customer email
3. Create/activate user account
4. Register license in Strata database
5. Send welcome email with next steps

---

## 12. ERROR HANDLING EXAMPLES

### Invalid Discount Code (Not Found)

```json
{
  "error": {
    "code": "NOT_FOUND",
    "message": "Discount code not found",
    "status": 404
  }
}
```

### License Activation Limit Reached

```json
{
  "error": {
    "code": "ACTIVATION_LIMIT_REACHED",
    "message": "This license key has reached its activation limit of 2 devices",
    "status": 422
  }
}
```

### Invalid API Key

```json
{
  "error": {
    "code": "UNAUTHORIZED",
    "message": "Invalid or missing API key",
    "status": 401
  }
}
```

### Duplicate Discount Code

```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Discount code 'STRATA_LAUNCH' already exists",
    "status": 422
  }
}
```

---

## TESTING WORKFLOW

### 1. Create Test Discount
```bash
# Create 100% discount in sandbox
curl -X POST https://test.dodopayments.com/discounts \
  -H "Authorization: Bearer sk_test_xxx" \
  -d '{"type":"percentage","amount":10000,"code":"TEST_FREE"}'
```

### 2. Build Checkout Link
```
https://checkout.dodopayments.com/?product_id=prod_test&discount_code=TEST_FREE&return_url=http://localhost:3000/callback
```

### 3. Complete Payment (Test Card: 4242 4242 4242 4242)
- Navigate to checkout link
- See $0 total with discount applied
- Use test card with any future date
- Complete payment

### 4. Activate License (Test)
```bash
curl -X POST https://test.dodopayments.com/licenses/activate \
  -d '{"license_key":"LK-TEST-XXX","name":"Test Device"}'
```

### 5. Verify Webhook
- Check application logs for webhook payload
- Verify license_key in response

---

## PRODUCTION DEPLOYMENT CHECKLIST

- [ ] API key securely stored in environment variable
- [ ] Webhook endpoint HTTPS and signed verification enabled
- [ ] Discount code auto-cleanup for expired codes
- [ ] License activation quota enforced in Strata app logic
- [ ] User can deactivate old devices if quota reached
- [ ] Admin dashboard shows real-time discount usage
- [ ] Error handling for failed license activations
- [ ] Webhook retry logic (in case of network failures)
- [ ] Database transaction for atomic license creation
- [ ] User notification when license expires (if applicable)

---

**Last Updated:** 2026-03-11
**API Version:** Latest (check docs.dodopayments.com for updates)
