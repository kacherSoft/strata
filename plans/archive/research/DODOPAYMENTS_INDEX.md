# DodoPayments Research Index

**Research Date:** March 11, 2026
**Project:** Strata Promotional Licensing & Giveaway Strategy
**Status:** ✅ COMPLETE & READY FOR IMPLEMENTATION

---

## 📋 Report Inventory

### 1. PRIMARY RESEARCH REPORT
**File:** `research-dodopayments-giveaway-capabilities-260311.md` (14 KB)

Comprehensive technical research covering:
- ✅ Discount codes & promo codes (full API support)
- ✅ 100% discount codes (v1.30.0+)
- ✅ $0 payments / free checkout (one-time products)
- ⚠️ License keys (partial API support)
- ❌ Direct license issuance (not available)
- ❌ Gift cards (not available)
- Complete endpoint specifications with payloads
- Rate limits, authentication, error codes
- Limitations and workarounds

**Best For:** Deep technical understanding, architecture decisions

---

### 2. EXECUTIVE SUMMARY
**File:** `dodopayments-findings-summary.md` (7.4 KB)

Business-focused summary:
- What's possible vs. not possible
- Recommended giveaway workflow (diagram)
- Key API endpoints for quick reference
- Implementation phases (3-phase plan)
- Cost considerations
- Success metrics
- Unresolved items requiring support contact

**Best For:** Stakeholders, project managers, quick decision-making

---

### 3. DEVELOPER QUICK REFERENCE
**File:** `dodopayments-api-quick-reference.md` (4.5 KB)

Copy-paste reference guide:
- cURL commands for all operations
- Request/response payloads
- Amount encoding (basis points, cents)
- Authentication headers
- Error codes with meanings
- Testing vs. Production URLs

**Best For:** Daily development, API integration, troubleshooting

---

### 4. IMPLEMENTATION EXAMPLES
**File:** `dodopayments-payload-examples.md` (10 KB)

12 complete use case scenarios:
- Create 100% discount (free lifetime)
- Create percentage discounts (30% off)
- Create flat-rate discounts ($50 off)
- Auto-generate discount codes
- List and update discount codes
- Checkout integration (hosted & programmatic)
- License activation endpoint
- License validation endpoint
- Webhook payload handling
- Error handling patterns
- Testing workflow
- Production deployment checklist

**Best For:** Hands-on implementation, code examples, testing

---

### 5. DOCUMENTATION INDEX
**File:** `README.md` (2.5 KB)

Overview and navigation guide with:
- Summary of all reports
- Key findings at a glance
- Quick start guide
- Critical limitations
- Reading order recommendations
- Support resources

**Best For:** Getting oriented, choosing which report to read

---

## 🎯 Key Findings Summary

### ✅ FULLY SUPPORTED

| Feature | Endpoint | Status |
|---------|----------|--------|
| Discount codes | `POST /discounts` | Full API |
| 100% discounts | `amount: 10000` | Full API |
| Free checkouts | `POST /discounts` + checkout | Full API |
| License activation | `POST /licenses/activate` | Public API |
| Bulk discounts | `GET /discounts` | List & filter |

### ⚠️ PARTIALLY SUPPORTED

| Feature | Status | Note |
|---------|--------|------|
| License management | Read-only API | Activation only, no creation |
| Promo codes (subscriptions) | Partial | Works but limited to cycles |

### ❌ NOT SUPPORTED

| Feature | Reason |
|---------|--------|
| Direct license issuance | No `POST /licenses` endpoint |
| Admin-granted licenses | Requires checkout or manual dashboard |
| Gift cards | Not a feature of platform |
| Subscription free trials | Can discount but not fully free |

---

## 🚀 Implementation Roadmap

### Week 1: Sandbox Testing
- [ ] Create test discount with 100% value
- [ ] Test checkout flow with discount
- [ ] Verify $0 payment processing
- [ ] Validate webhook delivery

### Weeks 2-3: Core Integration
- [ ] Build discount code management UI
- [ ] Integrate `POST /discounts` endpoint
- [ ] Wire license activation to onboarding
- [ ] Add webhook listener for license keys

### Weeks 4-5: Campaign Setup
- [ ] Create branded discount codes
- [ ] Set up giveaway campaign dashboard
- [ ] Configure usage limits & expiration
- [ ] Deploy to production

### Ongoing: Monitoring
- [ ] Track discount usage metrics
- [ ] Monitor license activations
- [ ] Measure campaign success
- [ ] Adjust strategy based on data

---

## 📊 Technical Specifications

### Discount Codes
- **Endpoint:** `POST https://live.dodopayments.com/discounts`
- **Auth:** Bearer token (API key)
- **Amount Format:**
  - Percentage: basis points (10000 = 100%)
  - Flat: USD cents (5000 = $50)
- **Limits:** 16-char auto-generated code (or custom)
- **Restrictions:** By product, expiration, usage count
- **Cost:** Free to create (included in service)

### License Activation
- **Endpoint:** `POST https://live.dodopayments.com/licenses/activate`
- **Auth:** None (public endpoint)
- **Payload:** license_key + device_name
- **Response:** activation_id + customer data
- **Quota:** Configurable per product (e.g., 2 devices for Pro)

### Webhooks
- **Event:** `payment.completed`
- **Includes:** payment_id, license_key, customer, amount
- **Amount:** 0 for 100% discount / free checkout
- **Signature:** Verify with webhook key

---

## 🔐 Security Considerations

1. **API Key Storage:** Environment variables only
2. **Webhook Verification:** Validate signatures
3. **Rate Limiting:** Unknown (contact support)
4. **PII in Logs:** Be careful with customer emails
5. **License Key Delivery:** Use secure channels (email, in-app)
6. **Test vs. Live:** Use separate API keys, never mix

---

## 💡 Recommended Approach for Strata

### Primary: 100% Discount Code Path
```
User clicks → Checkout with STRATA_LAUNCH_FREE (100%)
           → $0 total displayed
           → Complete payment (no charge)
           → License key issued (webhook)
           → Strata activates account + license
```

### Secondary: Manual Pre-Generated Licenses
```
Admin creates licenses in dashboard
           → Share license keys via email/in-app
           → User activates with /licenses/activate
           → Strata verifies and grants access
```

### Fallback: Feature Request
```
Request POST /licenses from DodoPayments
           → Enable admin-only license issuance
           → Integrate into giveaway admin panel
           → Deploy when available
```

---

## 📞 Support Items to Clarify

1. Fee structure for $0 transactions
2. API rate limits (requests/minute)
3. Timeline for direct license creation API
4. Subscription discount behavior (if any)
5. Webhook retry policy
6. Maximum basis points for discounts

**Contact:** support@dodopayments.com

---

## 📚 Reference Links

- **API Documentation:** https://docs.dodopayments.com/api-reference
- **Feature Docs:** https://docs.dodopayments.com/features
- **Changelog:** https://docs.dodopayments.com/changelog
- **Discount Codes:** https://docs.dodopayments.com/features/discount-codes
- **License Keys:** https://docs.dodopayments.com/features/license-keys
- **v1.30.0 ($0 Support):** https://docs.dodopayments.com/changelog/v1.30.0

---

## ✅ Validation Checklist

- [x] Researched promo codes / discount codes ✅
- [x] Researched 100% discount codes ✅
- [x] Researched free checkout sessions ✅
- [x] Researched license key generation ✅
- [x] Investigated direct issuance API ✅
- [x] Checked for gift card support ❌ (not available)
- [x] Documented all endpoints with payloads ✅
- [x] Created payload examples (12 scenarios) ✅
- [x] Identified limitations & workarounds ✅
- [x] Outlined implementation phases ✅

---

## 📄 Document Statistics

| Report | Size | Lines | Purpose |
|--------|------|-------|---------|
| Primary Research | 14 KB | 400+ | Technical deep-dive |
| Executive Brief | 7.4 KB | 200+ | Strategic overview |
| Quick Reference | 4.5 KB | 150+ | Developer lookup |
| Payload Examples | 10 KB | 400+ | Implementation guide |
| README | 2.5 KB | 100+ | Navigation guide |

**Total Package:** ~38 KB, 1,250+ lines of documentation

---

## 🎓 Reading Recommendations

**For Quick Understanding (20 minutes):**
1. README.md (this file)
2. dodopayments-findings-summary.md (sections 1-3)

**For Complete Knowledge (2 hours):**
1. research-dodopayments-giveaway-capabilities-260311.md (full)
2. dodopayments-payload-examples.md (all sections)

**For Implementation (Ongoing reference):**
1. dodopayments-api-quick-reference.md (bookmark this)
2. dodopayments-payload-examples.md (sections 1, 8-11)

---

## ✨ Next Steps

1. **Review** this index and choose your starting point
2. **Clarify** any unknowns with DodoPayments support
3. **Test** endpoints in sandbox environment
4. **Integrate** discount creation into Strata admin
5. **Deploy** giveaway campaign with branded codes
6. **Monitor** usage and measure success

---

**Research Status:** ✅ COMPLETE
**Documentation Status:** ✅ PRODUCTION-READY
**Implementation Readiness:** ✅ GO

**Generated:** 2026-03-11 | Last Updated: 2026-03-11
