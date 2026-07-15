# 🔍 Admin API — Full Security & Code Audit Report

**Codebase:** `~/Downloads/tawreedat/APIs/AdminAPIs`  
**Stack:** Node.js · TypeScript · Express 5 · Prisma ORM · MariaDB · Socket.IO · Paymob · Firebase FCM  
**Date:** 2026-05-11  
**Auditor:** Claude Code

---

## 📊 Executive Summary

The Admin API is **significantly more mature** than the Supplier and Courier APIs. It has helmet, compression, Zod env validation, DOMPurify sanitization, magic-byte file validation, production-only CORS whitelisting, and a proper error handler that hides stack traces. **However**, it shares two critical bugs with the other APIs and has several high-severity issues around logging, race conditions, and financial audit trails.

| Category | Critical | High | Medium | Total |
|---|---|---|---|---|
| Security | 2 | 6 | 4 | 12 |
| API Issues | 0 | 1 | 3 | 4 |
| Code Quality | 0 | 2 | 5 | 7 |
| Performance | 0 | 1 | 4 | 5 |

---

## 🚨 CRITICAL Security Findings

---

### [CRIT-1] Hardcoded OTP "123" for Phone Password Reset

**File:** `src/modules/auth/services/auth.service.ts:152`

```typescript
const code = input.email ? generateOtp(6) : "123";
```

**Impact:** Any user with a registered phone number can reset their password by providing OTP `"123"`. This is the **same bug** found in the Supplier and Courier APIs — it exists across the entire platform.

**Attack scenario:** Attacker knows a target's phone number → calls `POST /api/v1/auth/forget-password` with phone → calls `POST /api/v1/auth/reset-password` with OTP `"123"` → full account takeover.

**Fix:**
```typescript
const code = generateOtp(6);
// Then send via SMS provider (remove the TODO, integrate SMS now)
```

**Developer note:** This is a P0 pre-launch blocker. Every customer, courier, and supplier account on the platform can be taken over without knowing the victim's password. The phone OTP path must not be released to production without a real SMS provider.

---

### [CRIT-2] JWT Algorithm Not Enforced — Algorithm Confusion Attack

**File:** `src/lib/jwt.ts:25,33`

```typescript
export function verifyAccessToken(token: string): UserTokenPayload {
  return jwt.verify(token, USER_JWT_SECRET) as UserTokenPayload; // ← no algorithms option
}

export function verifyExternalAppToken(token: string): ExternalAppTokenPayload {
  return jwt.verify(token, EXTERNAL_APP_JWT_SECRET) as ExternalAppTokenPayload; // ← same
}
```

**Impact:** Without `algorithms: ["HS256"]`, an attacker can forge a token using `alg: none` (no signature required) in some `jsonwebtoken` versions, or craft an RS256/ES256 token using the HS256 secret as the RSA public key.

**Fix:**
```typescript
export function verifyAccessToken(token: string): UserTokenPayload {
  return jwt.verify(token, USER_JWT_SECRET, { algorithms: ["HS256"] }) as UserTokenPayload;
}
export function verifyExternalAppToken(token: string): ExternalAppTokenPayload {
  return jwt.verify(token, EXTERNAL_APP_JWT_SECRET, { algorithms: ["HS256"] }) as ExternalAppTokenPayload;
}
```

Same fix applies to the Socket.IO auth (`socket/auth.ts:40` — calls `verifyAccessToken` which doesn't enforce algorithm).

---

## 🔴 HIGH Security Findings

---

### [HIGH-1] Raw JWT Token Logged to Console in Socket Auth

**File:** `src/socket/auth.ts:38–45`

```typescript
console.log("token:", token);           // ← RAW JWT EXPOSED IN LOGS

const payload = verifyAccessToken(token);
console.log({                           // ← payload details dumped
  ...payload,
  iat: new Date((payload?.iat || 1) * 1000),
  exp: new Date((payload?.exp || 1) * 1000),
});
```

**Impact:** Every Socket.IO connection logs the user's full JWT token to stdout. Anyone with log access (admins, DevOps, CI logs, log aggregators) can steal valid tokens and impersonate users. JWT tokens are credentials — they must never be logged.

**Fix:** Remove both `console.log` statements entirely. If debugging is needed, use `logger.debug({ userId: payload?.userId }, "socket auth")` — never the token itself.

**Additional:** Lines 154 and 159 in the same file also `console.log` room-joining details. Harmless but noisy — use structured logger.

---

### [HIGH-2] No Brute-Force Protection on Login

**File:** `src/modules/auth/services/auth.service.ts:69`

No failed-attempt counter, no lockout, no CAPTCHA, no exponential backoff after failed logins. The rate limiter (`app.ts:189`) is:
- **Completely skipped** outside production (`skip: () => !env.PROD`)
- Set to a default of **9,999 requests per 15 minutes** (env default) — effectively unlimited

An attacker can enumerate passwords for any known email/phone with no friction.

**Fix:**
- Track `login_failed_attempts` + `login_locked_until` on the user model
- Lock account for N minutes after 5–10 failed attempts
- Apply a stricter route-level rate limiter specifically to `/auth/login` and `/auth/forget-password`

---

### [HIGH-3] Rate Limiter Disabled Outside Production + Insecure Default

**File:** `src/app.ts:195`, `src/config/env.ts:62`

```typescript
rateLimit({
  limit: env.RATE_LIMIT_MAX_REQUESTS,   // defaults to 9999
  skip: () => !env.PROD,               // ← skipped in dev AND staging
})
```

Staging environments are often connected to production databases. If staging has no rate limiting and shares the prod DB, the limiter provides zero protection during pre-release testing.

**Fix:** Remove `skip: () => !env.PROD`. Apply rate limiting always. Use a reasonable default of 100–200 requests per 15 minutes.

---

### [HIGH-4] `/uploads` Directory Publicly Accessible — No Auth

**File:** `src/app.ts:85`

```typescript
app.use("/uploads", express.static(path.join(__dirname, "..", "uploads")));
```

This serves uploaded files (user photos, tax cards, commercial register documents, PDFs) to anyone who can guess the URL. These are sensitive business documents.

**Fix:** Either (a) serve uploads through an authenticated controller that checks ownership, or (b) move to Cloudinary/S3 with signed URLs and remove local upload serving entirely.

---

### [HIGH-5] `adjustBalance` Uses Non-Transactional Read Inside a Transaction

**File:** `src/modules/admin-wallet/admin.wallet.service.ts:358`

```typescript
await prisma.$transaction(async (tx) => {
  const wallet = await prisma.wallet.findUnique({ // ← uses prisma, NOT tx!
    where: { id: wallet_id },
  });
```

The wallet check uses the global `prisma` client, not the transaction client `tx`. This means the initial wallet read **is not part of the transaction**, breaking isolation. A concurrent request could modify the wallet between this read and the subsequent `tx.wallet.update`, leading to incorrect balance calculations.

**Fix:** Change `prisma.wallet.findUnique` → `tx.wallet.findUnique` (and similarly for the order check at line 374).

---

### [HIGH-6] `requireRole` Returns Untranslated i18n Key as Error Message

**File:** `src/middlewares/auth/requireRole.ts:9`

```typescript
return res.status(401).json({ message: "admin:errors.unauthorized" });
```

Returns the raw translation key string (e.g., `"admin:errors.unauthorized"`) directly to the client instead of calling `req.t()`. This leaks the internal i18n namespace structure and returns a broken user-facing error.

**Fix:**
```typescript
return res.status(401).json({ message: req.t("admin:errors.unauthorized") });
```

---

## 🟡 MEDIUM Security Findings

---

### [MED-1] OTP Generated with `Math.random()` — Not Cryptographically Secure

**File:** `src/lib/otp.ts:2`

```typescript
export function generateOtp(length = 6) {
  let out = "";
  for (let i = 0; i < length; i++) out += Math.floor(Math.random() * 10);
  return out;
}
```

`Math.random()` is **not** a CSPRNG. With 1,000,000 possible 6-digit OTPs and a predictable RNG, an attacker with timing information could narrow the search space.

**Fix:**
```typescript
import { randomInt } from "node:crypto";
export function generateOtp(length = 6) {
  return Array.from({ length }, () => randomInt(0, 10)).join("");
}
```

---

### [MED-2] Password Reset OTP Lookup by Code Only

**File:** `src/modules/auth/services/auth.service.ts:200`

```typescript
const record = await prisma.userVerify.findUnique({
  where: { code: input.code },  // ← only code, no user context
```

If two users happen to generate the same OTP simultaneously (1 in 1,000,000 chance), the wrong user's password could be reset. Should also scope by user ID or include the phone/email in the lookup.

---

### [MED-3] Paymob Auth Token Cached Indefinitely — No TTL

**File:** `src/services/paymob.service.ts:23,39`

```typescript
let cachedAuthToken: string | null = null;

export async function getPaymobAuthToken(): Promise<string> {
  if (cachedAuthToken) return cachedAuthToken;  // ← never expires
```

When Paymob's auth token expires, all payment operations fail with 401 until the server restarts or `clearPaymobAuthTokenCache()` is manually called. There's no TTL-based refresh.

**Fix:** Store token with expiry timestamp, refresh proactively before it expires.

---

### [MED-4] `DELETE /logs/cleanup` Route Is Unreachable (Path Conflict)

**File:** `src/modules/logs/logs.routes.ts:27`

```typescript
logsRouter.get("/:id", ...);        // ← registered first
logsRouter.delete("/cleanup", ...); // ← Express matches /:id="cleanup" first!
```

The `/cleanup` route is registered after `/:id`, so Express routes `DELETE /cleanup` to the `/:id` handler with `id = "cleanup"`, likely returning a 404 "log not found" error.

**Fix:** Register specific paths before parameterized paths:
```typescript
logsRouter.delete("/cleanup", requireRole("Admin"), asyncHandler(adminDeleteOldLogs));
logsRouter.delete("/:id", ...);
```

---

## 📡 API Issues

---

### [API-1] `POST /auth/register` Returns Token With No Verification Gate

Registration creates the user and immediately returns a valid JWT token — no email/phone verification required before access. The OTP `confirm-user` flow exists but is optional. Any unverified account gets full API access.

**Recommendation:** Either (a) enforce verification before issuing a usable token, or (b) block sensitive endpoints if `is_email_verified === false`.

---

### [API-2] `POST /auth/token` (External App Issuer) Has No Route-Level Rate Limit

**File:** `src/modules/auth/auth.routes.ts:34`

The external app token endpoint is unauthenticated and takes `client_id` + `client_secret` in the request body. There's no rate limit specific to this route — only the global 9,999 req/15min limit applies.

**Recommendation:** Apply strict rate limiting to this route specifically.

---

### [API-3] `GET /users/suppliers` — Public Endpoint Leaks Business Data

`GET /users/suppliers` is `optionalAuth` — no authentication required. Depending on what `listSuppliers` returns, this may expose business-sensitive supplier data to anonymous users.

---

### [API-4] Socket.IO Token Expiry Timer Lost on Server Restart

**File:** `src/socket/auth.ts:129–132`

If a user connects with a 6-hour remaining token and the server restarts in 5 hours, the expiry timer is lost. After restart, reconnected socket goes through auth again (correct behavior). Minor UX issue but worth documenting.

---

## 🏗️ Code Quality Issues

---

### [CODE-1] Points Wallet Transactions Are Not Recorded — Financial Audit Gap

**File:** `src/lib/walletHelper.ts:105–116`

```typescript
// await tx.pointsTransaction.create({
//   data: {
//     wallet_id: wallet.id,
//     type: input.type ?? "ORDER_REWARD",
//     amount: input.points,
//     ...
//   },
// });
```

The `addToWallet` function increments `wallet.points` but the corresponding `pointsTransaction` record creation is **completely commented out**. Points are awarded/deducted with zero audit trail. This is a financial compliance issue — you cannot reconstruct how a user accumulated or lost points.

**Developer note:** Uncomment and fix this before enabling rewards. Every financial ledger entry must be recorded.

---

### [CODE-2] Debug `console.log` in Production Financial Code

**File:** `src/lib/walletHelper.ts:140–144`, `src/socket/auth.ts:38,41`

```typescript
console.log("paymentAmountCents", paymentAmountCents);
console.log("paymentAmountCents / 100", paymentAmountCents / 100);
console.log("points", Math.floor(paymentMajor * (ratio / 100)));
```

Debug logs inside `calcRewardPointsFromBadge` — called on every paid order. Remove or replace with `logger.debug()`.

---

### [CODE-3] Hardcoded Role IDs in Auth Logic

**File:** `src/modules/auth/services/auth.service.ts:18`

```typescript
const ALLOWED_ROLE_IDS = [1, 2, 3, 4, 6]; // 1=Admin, 2=Courier, 3=Customer, 4=Seller, 6=Supplier
```

If the database is reseeded or a migration changes IDs, these hardcoded values silently break authentication.

**Fix:** Query roles by name and cache the IDs at startup, or use a role-name enum approach.

---

### [CODE-4] `console.error` Instead of Structured Logger in Auth Middleware

**File:** `src/middlewares/auth/authHelpers.ts:43`

```typescript
console.error("Auth middleware error:", err);
```

The rest of the codebase uses pino (`logger.error()`). This breaks log aggregation pipelines.

**Fix:** `logger.error({ err }, "Auth middleware error");`

---

### [CODE-5] `getOrCreateRole` Race Condition on Concurrent OAuth Registrations

**File:** `src/modules/auth/services/oauth.service.ts:106,222`

```typescript
const role = await getOrCreateRole("CUSTOMER", "عميل");
const badge_id = await getBadgeId(role.id, "Basic");
```

These are called on every new Google/Apple signup. Without DB-level unique constraints, concurrent registrations could create duplicate roles. Verify the `getOrCreateRole` implementation uses upsert with a unique constraint.

---

## ⚡ Performance Issues

---

### [PERF-1] N+1 Queries in `adjustBalance` Wallet Deduction Loop

**File:** `src/modules/admin-wallet/admin.wallet.service.ts:446–530`

For each unpaid commission and each penalty, the code runs 4 queries inside a serial loop (update status + create transaction + 2× update wallet). For a user with 50 unpaid commissions this is 200+ queries in one HTTP request.

**Fix:** Batch wallet increments/decrements into a single `update` summing all amounts. Use `updateMany` for commission/penalty status updates.

---

### [PERF-2] Order Jobs Run Every Minute × 2 Schedules With No Overlap Guard

**File:** `src/jobs/registerOrderJobs.ts:10,19`

```typescript
cron.schedule("* * * * *", async () => { await handleNoProposalOrders(); });
cron.schedule("* * * * *", async () => { await handleExpiredOrders(); });
```

No mutex/guard — if either job takes >60s, overlapping runs occur.

**Fix:** Add a `let running = false` flag or use a job lock library.

---

### [PERF-3] `wallet.findFirst` Without Select in Financial Operations

Multiple `prisma.wallet.findFirst({ where: { owner_type: "PLATFORM" } })` calls in `admin.wallet.service.ts` fetch all columns when only `id` and `balance` are needed.

---

### [PERF-4] Paymob Token Never Refreshed — Unpredictable Checkout Latency

After a long server uptime, the first payment after Paymob token expiry takes 2× the normal time (re-auth + actual call). Fix under [MED-3].

---

## ✅ What the Admin API Does Well (vs. Other APIs)

| Feature | Supplier API | Courier API | Admin API |
|---|---|---|---|
| Stack trace hidden in prod | ❌ | ❌ | ✅ |
| Magic byte file validation | ❌ | ❌ | ✅ |
| File size limit | 50 MB ❌ | 50 MB ❌ | 5 MB ✅ |
| DOMPurify input sanitization | ❌ | ❌ | ✅ |
| Zod env validation at startup | ❌ | ❌ | ✅ |
| Helmet + compression | ❌ | Partial | ✅ |
| CORS prod allowlist | ❌ | ❌ | ✅ |
| Password invalidates tokens | ❌ | ❌ | ✅ |
| Separate external app JWT secret | N/A | N/A | ✅ |
| External app tokens: 2h expiry | N/A | 7d ❌ | ✅ |
| Cron jobs only run in prod | ❌ | ❌ | ✅ |
| `featureApi` allowKeys guard | ❌ | ✅ | ✅ |
| Structured logger (pino) | ❌ | ❌ | ✅ (inconsistent) |
| Global i18n on error responses | Partial | Partial | ✅ |

---

## 🎯 Priority Action Table

| Priority | ID | Issue | Effort |
|---|---|---|---|
| 🔴 P0 | CRIT-1 | Remove hardcoded OTP "123", integrate SMS provider | Medium |
| 🔴 P0 | CRIT-2 | Add `algorithms: ["HS256"]` to all `jwt.verify()` calls | Low |
| 🔴 P0 | HIGH-1 | Remove `console.log("token:", token)` from socket auth | Low |
| 🔴 P0 | HIGH-5 | Fix `prisma.` → `tx.` inside `adjustBalance` transaction | Low |
| 🔴 P0 | CODE-1 | Uncomment points transaction recording in `walletHelper` | Low |
| 🟠 P1 | HIGH-2 | Add login brute-force lockout (failed attempts counter) | Medium |
| 🟠 P1 | HIGH-3 | Remove `skip: () => !env.PROD`, lower default rate limit to 200 | Low |
| 🟠 P1 | HIGH-6 | Fix `requireRole` to call `req.t()` on error messages | Low |
| 🟠 P1 | MED-4 | Fix `/logs/cleanup` route registration order | Low |
| 🟡 P2 | HIGH-4 | Auth-gate `/uploads` static files or move to Cloudinary | High |
| 🟡 P2 | MED-1 | Replace `Math.random()` with `crypto.randomInt()` in OTP | Low |
| 🟡 P2 | CODE-2 | Remove debug `console.log` from wallet and socket code | Low |
| 🟡 P2 | MED-3 | Add TTL to Paymob auth token cache | Low |
| 🟢 P3 | PERF-1 | Batch wallet deductions in `adjustBalance` | Medium |
| 🟢 P3 | PERF-2 | Add overlap guard to order cron jobs | Low |
| 🟢 P3 | CODE-3 | Replace hardcoded role IDs with name-based lookup | Medium |

---

## 💬 Developer Remarks

1. **This is the best of the three APIs** — the security middleware stack is production-ready. The bugs that exist are correctness issues, not architectural ones.

2. **The OTP "123" bug is a copy-paste artifact** shared by all three APIs (Supplier, Courier, Admin). It needs a coordinated fix across all services before any of them go live.

3. **The commented-out `pointsTransaction.create` is a financial data integrity hole.** Wallets are stateful financial objects — every credit and debit must be traceable. Fix this before enabling rewards.

4. **The socket debug logs are a credential leak.** A raw Bearer token appearing in application stdout means every developer with log access can impersonate any online user in real time.

5. **The `prisma` vs `tx` bug in `adjustBalance` is a concurrency bug** that will manifest as balance corruption under concurrent admin wallet adjustments. It's subtle and easy to miss in code review.

6. **Production rate limiting of 9,999 requests** should be reduced to something meaningful. A legitimate admin user makes at most tens of requests per minute. 9,999 is indistinguishable from no rate limit.
