# TawreedatGo – AI Working Agreement

## Goal
You are helping me develop and maintain this backend API project. Prefer production-grade, type-safe, consistent code.

## Tech Stack
- Node.js + TypeScript
- Express (ESM)
- Prisma (MariaDB)
- Zod for validation
- i18next for translations
- pino + pino-http logging
- pnpm

## Run Commands
- Dev: `pnpm dev`
- Build: `pnpm build`
- Start: `pnpm start`
- Prisma: `pnpm mig`, `pnpm gen`, `pnpm studio`

## Project Structure
- `src/index.ts` bootstrap
- `src/app.ts` express app + middlewares + routes
- `src/modules/*` feature modules:
  - `*.routes.ts`
  - `*.controller.ts`
  - `*.service.ts`
  - `*.schema.ts`
- `src/lib/*` shared utilities (jwt, prisma, httpError, featureApi, cloudinary, etc.)
- `src/middlewares/*`
- `src/i18n/*` translations + middleware

## Events & Side Effects (Event-Driven Architecture)

### Purpose
We use an in-process event bus to keep **service/business logic** clean and move **side effects** (wallet updates, badge updates, notifications, analytics, realtime) into dedicated event handlers.

### Folder Structure (Add)
- `src/events/`
  - `bus.ts` – typed event emitter wrapper
  - `registerEvents.ts` – registers handlers once at boot
  - `handlers/` – event handlers (each file handles one event or domain)
    - Example: `handlers/orderDelivered.ts`

### Conventions
- Services may `bus.emit(...)` **after** the DB transaction commits (or emit only values that are known to be committed).
- Event handlers:
  - MUST be idempotent (safe if called twice).
  - MUST do DB writes inside `prisma.$transaction(...)` when applying multi-step updates (wallet + badge, etc.).
  - MUST NOT put transport concerns (HTTP, Express `req/res`) inside handlers.
- Keep event payloads small and stable. Prefer **IDs + cents** (Int) over floats.
- If/when we later move to a queue/outbox, event payloads should remain serializable.

## Realtime Sockets (Planned – Do Not Implement Yet)

### Folder Structure (Plan)
- `src/socket/`
  - `socket.ts` – initializes Socket.IO and exports `io`
  - `auth.ts` – socket auth middleware (JWT) + room joins
  - `rooms.ts` – constants/helpers for room names (e.g., `user:{id}`, `courier:{id}`, `order:{id}`)

### Conventions (When We Start)
- **Never** emit socket events from services directly.
- Emit sockets from event handlers (e.g. `order.delivered` handler) **after** DB transaction success.
- Room strategy:
  - `user:{userId}` (customer)
  - `courier:{courierId}` (courier)
  - `order:{orderId}` (optional watchers/admin)
- Keep socket payloads minimal; clients refetch details when needed.

## API Conventions
### Authentication
- `requireAuth` middleware must set `req.user` and `req.auth`
- Controllers in protected routers assume `req.user` exists (typed requests allowed)
- Roles are taken from DB (`req.user.role.name`) not token

### Error Handling
- Throw `HttpError(status, i18nKey, details?, meta?)`
- Errors must use i18n keys like: `orders:errors.order_not_found`
- Use consistent HTTP status:
  - 400 validation/invalid input
  - 401 unauthorized (no/invalid token)
  - 403 forbidden (no permission)
  - 404 not found
  - 409 conflict (duplicate, invalid state transition)

### Validation
- Zod schemas live in `*.schema.ts`
- Controllers do:
  - `schema.parse(req.sanitized.body)` or `parse` and respond with localized message
- Prefer `z.coerce.number()` for query/params
- For money/decimal values, accept number or string but store with `Prisma.Decimal`

### Responses
- Always return JSON
- Success responses may include:
  - `{ message, data }` or `{ message, entity }`
- List endpoints should return:
  - `{ totalX, totalPages, items }`

### FeatureApi
- List endpoints often use `new FeatureApi(req).filter().sort().limit().skip().includes().keyword().fields().data`
- When creating list services, accept `FeatureApi["data"]`

### Routes
- Admin routes live under `/api/v1/admin/*`
- Normal routes under `/api/v1/*`
- Always use `asyncHandler` for async routes

## i18n Requirements
- Every new error/message key must be added to:
  - `src/i18n/locales/en/<module>.json`
  - `src/i18n/locales/ar/<module>.json`
- Keep keys consistent across languages

## Coding Style
- TypeScript strict
- Avoid `any` unless unavoidable; prefer `unknown` + narrowing
- Prefer small helpers inside service file for reuse
- Use Prisma transactions for multi-step updates
- Avoid doing expensive operations (upload/delete files) before DB checks
  - Validate + check conflicts first
  - Then upload
  - Then commit DB
  - If DB fails after upload: attempt cleanup (best effort)

## What I Want From You (AI)
When I ask for a feature or fix, respond with:
1) Which files to create/update
2) Full code for each file (or a minimal diff)
3) Any new translation keys + suggested EN/AR values
4) Any Prisma schema changes + migrations needed
5) Any edge cases or race conditions to consider

## Do NOT
- Do not invent existing project files or routes—ask or infer from code shown
- Do not change code style conventions unless I ask
- Do not add new libraries unless necessary; prefer existing stack
