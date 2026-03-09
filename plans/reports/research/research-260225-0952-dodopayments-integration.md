# DodoPayments Integration Research Report

> **Date:** 2025-02-25
> **Project:** Strata - Personal AI Task Manager
> **Purpose:** Evaluate DodoPayments as external payment provider to replace StoreKit

---

## Executive Summary

**Recommendation:** ✅ **DodoPayments is well-suited for Strata's requirements**

DodoPayments offers a comprehensive Merchant of Record solution that aligns with Strata's distribution model (Developer ID, website distribution, no App Store). Key advantages include:

- Supports both **subscriptions** (Pro tier) and **one-time payments** (VIP lifetime)
- **License key management** built-in for lifetime purchases
- **Global tax handling** as Merchant of Record
- Compatible with **external distribution** (non-App Store)
- **API-first** approach with SDK support

---

## Strata Requirements Summary

| Requirement | Details |
|-------------|---------|
| **Distribution** | Developer ID (notarized), website download |
| **Sandbox** | Disabled (Accessibility API requirement) |
| **Pro Subscription** | ~$4.99/mo, ~$39.99/yr |
| **VIP Lifetime** | ~$79.99 one-time |
| **Entitlement Check** | `hasFullAccess` = isPremium OR isVIPPurchased OR isVIPAdminGranted |
| **Current State** | StoreKit implementation exists, migration pending |

---

## DodoPayments Overview

### Company Profile
- **Website:** https://dodopayments.com
- **Type:** Global Merchant of Record (MoR)
- **Coverage:** 220+ countries, 30+ payment methods, 14+ languages

### Pricing Model
| Transaction Type | Fee |
|------------------|-----|
| US Domestic Cards | 4% + 40¢ |
| International Payments | 5.5% + 40¢ |
| PayPal & BNPL | 7% + 40¢ |

**Note:** As Merchant of Record, DodoPayments handles all tax collection, remittance, and compliance globally.

---

## SDK & API Support

### Available SDKs
| Language/Platform | Support |
|-------------------|---------|
| TypeScript/Node.js | ✅ npm package |
| Python | ✅ pip package |
| Go | ✅ |
| PHP | ✅ |
| Java | ✅ |
| Kotlin | ✅ |
| C# | ✅ |
| Ruby | ✅ |
| React Native (iOS) | ✅ |
| React Native (Android) | ✅ |

### Integration Options
1. **API-First:** RESTful API for custom integrations
2. **Better-Auth Plugin:** Pre-built authentication integration
3. **MCP Server:** AI agent integration capability
4. **No-Code Checkout:** Hosted checkout pages
5. **Storefront:** Built-in storefront feature

---

## Features Relevant to Strata

### ✅ Subscription Billing
- Recurring payments (monthly/annual)
- Subscription management
- Automatic renewal handling
- Add-ons support

### ✅ License Key Management
- Generate and validate license keys
- Perfect for VIP lifetime purchases
- API for key validation in-app

### ✅ One-Time Payments
- Lifetime purchase support
- Instant delivery
- No recurring billing needed

### ✅ Global Merchant of Record
- Tax collection and remittance
- Compliance handling
- No need for separate tax solution

### ✅ External Distribution Compatible
- Not tied to App Store
- Works with website distribution
- No IAP restrictions

---

## Proposed Integration Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Strata macOS App                        │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐  │
│  │ Entitlement │  │  License    │  │  Subscription       │  │
│  │   Manager   │  │  Validator  │  │     Manager         │  │
│  └──────┬──────┘  └──────┬──────┘  └──────────┬──────────┘  │
│         │                │                    │              │
│         └────────────────┴────────────────────┘              │
│                          │                                   │
│                    ┌─────▼─────┐                             │
│                    │   API     │                             │
│                    │  Client   │                             │
│                    └─────┬─────┘                             │
└──────────────────────────┼──────────────────────────────────┘
                           │ HTTPS
                    ┌──────▼──────┐
                    │ DodoPayments│
                    │     API     │
                    └─────────────┘
```

### Implementation Components

1. **License Validator Service**
   - Validates VIP lifetime keys on app launch
   - Caches validation status locally
   - Periodic re-validation

2. **Subscription Manager**
   - Checks Pro subscription status
   - Handles subscription state changes
   - Manages grace periods

3. **Entitlement Manager** (existing, modified)
   - Uses DodoPayments API for `isPremium` check
   - Uses license validation for `isVIPPurchased` check
   - Maintains `isVIPAdminGranted` for debug

---

## Migration Path from StoreKit

### Phase 1: Backend Setup
- [ ] Create DodoPayments account
- [ ] Configure products (Pro subscription, VIP lifetime)
- [ ] Set up webhooks for status changes
- [ ] Test in sandbox environment

### Phase 2: App Integration
- [ ] Add DodoPayments API client to Strata
- [ ] Implement license key validation
- [ ] Implement subscription status check
- [ ] Modify `hasFullAccess` logic
- [ ] Add purchase/restore UI

### Phase 3: Testing
- [ ] Test VIP lifetime purchase flow
- [ ] Test Pro subscription flow
- [ ] Test subscription renewal
- [ ] Test subscription cancellation
- [ ] Test license key validation
- [ ] Test restore purchases

### Phase 4: Launch
- [ ] Update website with checkout links
- [ ] Deploy app update
- [ ] Monitor webhook events
- [ ] Support existing StoreKit users (grandfather or migrate)

---

## Considerations & Risks

### Advantages
- **No App Store restrictions** - Full control over pricing and promotions
- **Global tax handling** - No tax compliance burden
- **License key flexibility** - Can issue keys for promotions, refunds, etc.
- **Lower fees than App Store** - 4% vs 15-30%

### Potential Issues
- **No native macOS SDK** - Use API directly or TypeScript SDK via bridge
- **Migration complexity** - Existing StoreKit users need handling
- **Website required** - Checkout happens externally
- **API dependency** - App needs internet for validation

### Open Questions
1. How to handle existing StoreKit subscribers? (Grandfather, migrate, or discontinue?)
2. Offline grace period for entitlement checks?
3. Webhook endpoint hosting? (Could use Cloudflare Workers)
4. Currency and regional pricing strategy?

---

## Comparison: StoreKit vs DodoPayments

| Aspect | StoreKit | DodoPayments |
|--------|----------|--------------|
| Distribution | App Store required | Any (website, etc.) |
| Fees | 15-30% | 4-7% + 40¢ |
| Tax Handling | Apple handles | DodoPayments handles |
| License Keys | Limited | Full control |
| Subscriptions | ✅ Native | ✅ API-based |
| One-time | ✅ Native | ✅ Native |
| Sandbox | ✅ Built-in | ✅ Test mode |
| macOS Native | ✅ SwiftUI | ⚠️ API only |

---

## Recommended Next Steps

1. **Create DodoPayments account** and explore dashboard
2. **Define product SKUs** matching Strata's tiers
3. **Design entitlement storage** strategy (Keychain + API validation)
4. **Plan StoreKit migration** for existing users
5. **Build proof-of-concept** for license validation

---

## Sources

- DodoPayments Official: https://dodopayments.com
- Pricing: https://dodopayments.com/pricing
- npm Package: https://www.npmjs.com/package/dodopayments
- MCP Server: Documented via official API (GitHub link deprecated)

---

*Report generated: 2025-02-25*
