# Cloudflare Workers Security Best Practices

## 1. D1 Database Atomic Operations & TOCTOU Prevention

**Challenge:** Race conditions between concurrent reads and writes.

**Pattern:** Use atomic batch transactions with D1's batch API. All statements in a batch succeed or fail together.

```javascript
// Insert + select in single atomic batch (prevents TOCTOU)
const result = await db.batch([
  db.prepare('INSERT INTO locks (resource_id, owner) VALUES (?, ?)')
    .bind(resourceId, ownerId),
  db.prepare('SELECT owner FROM locks WHERE resource_id = ?')
    .bind(resourceId)
]);
```

**Sessions API:** Bind subsequent reads to primary DB to prevent stale reads post-write. Ensures read-after-write consistency across replicas.

**Note:** D1 processes queries single-threaded per database. For high-concurrency critical sections, use Durable Objects alongside D1.

---

## 2. Cloudflare Cron Triggers

**wrangler.jsonc Configuration:**
```json
{
  "triggers": {
    "crons": ["*/5 * * * *", "0 0 * * *"]
  }
}
```

**Scheduled Handler Export Pattern:**
```javascript
export default {
  async scheduled(controller, env, ctx) {
    switch (controller.cron) {
      case "*/5 * * * *":
        // 5-minute job
        break;
      case "0 0 * * *":
        // Daily job
        break;
    }
    // Explicit ctx.waitUntil() for async cleanup
    ctx.waitUntil(asyncTask());
  }
};
```

**Testing:** `wrangler dev --test-scheduled` exposes `/__scheduled` route for HTTP-based testing.

**Management:** Wrangler replaces all cron triggers on deploy. Use empty array `crons: []` to disable.

---

## 3. Rate Limiting Patterns (D1-Based)

**D1 Implementation Strategy:**
```javascript
// Single-threaded nature = sequential processing
// Insert+select in one atomic batch for atomicity
const [inserted, current] = await db.batch([
  db.prepare(`INSERT INTO rate_limits (ip, count, window)
             VALUES (?, 1, datetime('now', '+1 minute'))
             ON CONFLICT(ip) DO UPDATE SET count = count + 1`),
  db.prepare(`SELECT count FROM rate_limits WHERE ip = ?
             AND window > datetime('now')`).bind(clientIp)
]);
```

**Recommendation:** Use native Rate Limiting API for edge-global limiting (simpler, lower latency). Reserve D1 approach for per-user or application-specific quotas where strong consistency matters.

**Caveat:** D1's single-threaded model makes it unsuitable for high-volume, global rate limiting. Durable Objects provide better concurrency guarantees.

---

## 4. CORS Configuration for Native App Backends

**Removal Pattern:** For native apps (not web browsers), CORS headers can be controlled or removed entirely via Workers:

```javascript
const response = new Response(body, { status: 200 });
// Remove unnecessary CORS for native clients
// Only include if cross-origin web clients exist
if (request.headers.get('origin')) {
  response.headers.set('Access-Control-Allow-Origin', 'https://trusted.domain');
  response.headers.set('Access-Control-Allow-Credentials', 'true');
}
return response;
```

**Preflight Handling:**
```javascript
if (request.method === 'OPTIONS') {
  return new Response(null, {
    headers: {
      'Access-Control-Allow-Origin': request.headers.get('origin'),
      'Access-Control-Allow-Methods': 'POST, GET',
      'Access-Control-Max-Age': '86400'
    }
  });
}
```

**Security Rule:** No wildcard origins (`*`) for native app backends. Use exact domain matching. Native clients can omit CORS entirely if they don't make cross-origin requests.

---

## 5. Ed25519 Key Rotation with `kid` Claim

**Pattern: Match JWT `kid` Header to Active Key**
```javascript
// Fetch JWKS from identity provider (cache aggressively)
const jwks = await fetch('https://provider/.well-known/jwks.json');
const keys = await jwks.json();

// Decode JWT header to extract 'kid'
const [header] = token.split('.');
const { kid, alg } = JSON.parse(atob(header));

// Find matching key by kid
const publicKey = keys.keys.find(k => k.kid === kid && k.alg === alg);
if (!publicKey) throw new Error('Key not found');

// Verify with Ed25519 public key
const verified = await crypto.subtle.verify(
  'Ed25519',
  publicKey,
  signature,
  message
);
```

**Rotation Strategy:**
- Keep 2-3 keys active simultaneously (current + previous + upcoming)
- New keys issued before old keys deactivated
- Use Cron Trigger to auto-fetch latest JWKS every 6 hours
- Match `kid` to rotate transparently without client changes

**Best Practice:** Never hardcode keys. Fetch from JWKS endpoint dynamically. Cloudflare Access supports up to 4 keys per configuration.

---

## Summary

| Topic | Recommendation |
|-------|-----------------|
| **D1 + Race Conditions** | Batch atomicity + Sessions API for consistency |
| **Cron Setup** | wrangler.jsonc triggers + scheduled() handler |
| **Rate Limiting** | Native API for global limits; D1 for per-user quotas |
| **CORS (Native Apps)** | Remove entirely or use exact origin matching; no wildcards |
| **Key Rotation** | `kid` header matching + JWKS endpoint fetching |

---

**Sources:**
- [Cloudflare D1 Documentation](https://developers.cloudflare.com/d1/)
- [Scheduled Handler API](https://developers.cloudflare.com/workers/runtime-apis/handlers/scheduled/)
- [Cron Triggers Guide](https://developers.cloudflare.com/workers/configuration/cron-triggers/)
- [Rate Limiting API](https://developers.cloudflare.com/workers/runtime-apis/bindings/rate-limit/)
- [JWT Validation with Key Rotation](https://developers.cloudflare.com/api-shield/security/jwt-validation/)
- [CORS Configuration](https://developers.cloudflare.com/workers/examples/cors-header-proxy/)
