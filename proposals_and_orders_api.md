# Tawreedat Customer App — Proposals & Orders API Reference

> **Audience:** Next.js web developers building the customer-facing web app.  
> **Context:** This documents the same backend APIs consumed by the Flutter mobile app. Section 4 ("Proposal Card") describes the mobile UI behaviour as a reference spec for you to re-implement in React/Next.js — the field names, display logic, and state transitions are what matter, not the Flutter widgets.  
> **Source files (Flutter reference):** `lib/features/` — cited per section so you can trace exact request/response handling if needed.

---

## Base URL & Common Conventions

| Detail        | Value                                                              |
| ------------- | ------------------------------------------------------------------ |
| Base URL      | Configured in `ApiClient` (Dio) — check `lib/core/network/`        |
| Language      | All endpoints append `?lang={currentLocale}` (e.g. `en`, `ar`)     |
| Amounts       | Monetary values are in **cents** — divide by 100 for EGP display   |
| DateTime      | ISO 8601 UTC strings; parsed to local time in the app              |
| Pagination    | `skip` / `limit` pattern on all list endpoints                     |
| Image uploads | Multipart — only **JPEG, PNG, WEBP** accepted                      |
| Error shape   | `DioException` → `statusCode` + `response.data` with error details |

---

## 1. Orders — Create

**Source:** `lib/features/orders/data/data_source/order_remote_data_source.dart`

### 1a. Custom Pickup Order

```
POST /orders?lang={locale}
Content-Type: multipart/form-data  (if image attached)
             application/json      (no image)
```

**Body:**

| Field                          | Type            | Required | Notes                      |
| ------------------------------ | --------------- | -------- | -------------------------- |
| `type`                         | string          | ✅       | `"CUSTOM_PICKUP"`          |
| `product_description`          | string          | ✅       |                            |
| `budget`                       | int             | ✅       | cents                      |
| `pickup_area_id`               | int             | ✅       |                            |
| `pickup_address_description`   | string          | ✅       |                            |
| `pickup_lat`                   | double          | ✅       |                            |
| `pickup_long`                  | double          | ✅       |                            |
| `delivery_area_id`             | int             | ✅       |                            |
| `delivery_address_description` | string          | ✅       |                            |
| `delivery_lat`                 | double          | ✅       |                            |
| `delivery_long`                | double          | ✅       |                            |
| `payment_method`               | string          | ✅       | `CASH` / `WALLET` / `CARD` |
| `is_order_scheduled`           | bool            | ❌       |                            |
| `order_schedule_at`            | ISO 8601 string | ❌       | UTC, only if scheduled     |
| `coupon_code`                  | string          | ❌       |                            |
| `product_image`                | file            | ❌       | multipart, JPEG/PNG/WEBP   |

**Response:** `OrderResponse` — see [Order Model](#order-model).

---

### 1b. Order Price Preview (Cost Estimate)

```
POST /orders/preview?lang={locale}
Content-Type: application/json
```

Send the same body as §1a with `type = "CUSTOM_PICKUP"`.

**Response:**

```json
{
  "courierFee": 0.0,
  "deliveryFee": 0.0,
  "platformFee": 0.0,
  "vatAmount": 0.0,
  "discountAmount": 0.0,
  "totalFee": 0.0,
  "distanceM": 0.0
}
```

---

## 2. Orders — Retrieve

**Source:** `lib/features/orders/data/data_source/order_remote_data_source.dart`

### 2a. List Orders (Active & History)

```
GET /orders?lang={locale}
```

**Query params:**

| Param             | Type     | Notes                                             |
| ----------------- | -------- | ------------------------------------------------- |
| `skip`            | int      | default `0`                                       |
| `limit`           | int      | default `20`                                      |
| `includes`        | string   | always `"courier=user"`                           |
| `status`          | string   | optional — see statuses below                     |
| `expires_at[gte]` | DateTime | set when `filterByExpiry=true` to exclude expired |

**Order statuses:** `SCHEDULED` · `PENDING` · `IN_PROGRESS` · `DELIVERED` · `CANCELLED` · `EXPIRED`

> **Active orders** → filter by `SCHEDULED`, `PENDING`, `IN_PROGRESS`  
> **History** → filter by `DELIVERED`, `CANCELLED`, `EXPIRED` (no expiry filter)

**Response:**

```json
{
  "orders": [
    /* Order[] */
  ],
  "totalOrders": 0,
  "totalPages": 0
}
```

---

## 3. Proposals — Get & Accept/Reject

**Source:** `lib/features/orders/data/data_source/order_remote_data_source.dart`

### 3a. Get Proposals for an Order

```
GET /orders/{orderId}/proposals?lang={locale}
```

**Response — each `Proposal`:**

| Field               | Type        | Notes                                    |
| ------------------- | ----------- | ---------------------------------------- |
| `id`                | int         |                                          |
| `orderId`           | int         |                                          |
| `courierId`         | int         |                                          |
| `courierUserId`     | int         |                                          |
| `discountFee`       | double      | EGP (converted from cents)               |
| `platformFee`       | double      | EGP                                      |
| `courierFee`        | double      | EGP                                      |
| `totalFee`          | double      | EGP                                      |
| `status`            | string      | `PENDING` / `ACCEPTED` / `REJECTED`      |
| `distanceToPickupM` | int         | meters                                   |
| `timeToPickup`      | int         | seconds                                  |
| `createdAt`         | DateTime    |                                          |
| `confirmedAt`       | DateTime?   |                                          |
| `courier`           | CourierInfo | `{ id, fullName, phone, personalPhoto }` |
| `vehicle`           | VehicleInfo | `{ id, name, nameAr, icon }`             |

---

### 3b. Accept or Reject a Proposal

```
PUT /orders/{orderId}/proposals/{proposalId}?lang={locale}
Content-Type: application/json
```

**Body:**

```json
{ "status": "ACCEPTED" }
// or
{ "status": "REJECTED" }
```

**Response:** raw `Map<String, dynamic>` from the API.

---

## 4. Proposal Card — UI & Behaviour

**Flutter reference:** `lib/features/orders/presentation/widgets/sheets/proposal_sheet.dart`

> This section describes the mobile behaviour as a spec — implement the equivalent in your Next.js UI (e.g. a modal/drawer). The API calls, field mappings, and state transitions are identical; the widget names are Flutter-specific and can be ignored.

On the web this should open as a modal or slide-over panel when the customer views a PENDING order. On mobile it occupies 70% of screen height as a bottom sheet.

### Data loading

- On open: calls `OrderCubit.loadProposals(orderId)` → `GET /orders/{orderId}/proposals`.
- Real-time: listens on a **WebSocket** (`SocketService.onNewOffer`). When an event arrives for the same `orderId`, it re-fetches proposals and shows a success banner ("New proposal received!").

### Sorting

Two toggle chips let the customer sort the list:

| Chip         | First tap          | Second tap          |
| ------------ | ------------------ | ------------------- |
| Delivery Fee | fee ascending      | fee descending      |
| Near Me      | distance ascending | distance descending |

Rejected proposals are always pushed to the bottom regardless of the active sort.

### Proposal card layout (`_ProposalCard`)

Each card is **expandable** — tap the header to reveal fee details and action buttons.

**Collapsed header (always visible):**

| Element           | Value shown                                                             | Source field                                                          |
| ----------------- | ----------------------------------------------------------------------- | --------------------------------------------------------------------- |
| Avatar            | Courier profile photo                                                   | `proposal.courier.user.personalPhoto`                                 |
| Name              | Courier full name                                                       | `proposal.courier.user.fullName`                                      |
| Phone button      | Tapping opens the phone dialer                                          | `proposal.courier.user.phone`                                         |
| Status badge      | `PENDING` (orange) / `ACCEPTED` (green) / `REJECTED` (red)              | `proposal.status`                                                     |
| Total fee preview | `courierFee + platformFee` in EGP; shown in green if a discount applies | `proposal.courierFee`, `proposal.platformFee`, `proposal.discountFee` |
| Distance          | Metres if < 1 km, otherwise km (1 dp)                                   | `proposal.distanceToPickupM`                                          |
| ETA               | Minutes or hours/minutes to pickup                                      | `proposal.timeToPickup` (seconds)                                     |

**Expanded body (vehicle + fee breakdown):**

| Element        | Value shown                                                                                                        | Source field                                                          |
| -------------- | ------------------------------------------------------------------------------------------------------------------ | --------------------------------------------------------------------- |
| Vehicle icon   | Image from URL                                                                                                     | `proposal.vehicle.icon`                                               |
| Vehicle name   | Localised (EN/AR)                                                                                                  | `proposal.vehicle.name` / `proposal.vehicle.nameAr`                   |
| Plate number   | Egyptian plate widget                                                                                              | `proposal.courier.courierVehiclePlate` (hidden if `"N/A"`)            |
| Courier rating | Star rating                                                                                                        | `proposal.courier.courierRate`                                        |
| ETA badge      | Time to pickup                                                                                                     | `proposal.timeToPickup`                                               |
| Delivery fee   | `courierFee + platformFee` — if `discountFee > 0`: original price struck through in red, discounted price in green | `proposal.courierFee`, `proposal.platformFee`, `proposal.discountFee` |

**Discount fee logic:**

```
discountedCourierFee = (courierFee - discountFee).clamp(0, ∞)
displayedTotal       = discountedCourierFee + platformFee
```

**Action buttons** (only shown when `proposal.status == PENDING`):

| Button                | Action                                                                                                |
| --------------------- | ----------------------------------------------------------------------------------------------------- |
| Reject (red outlined) | Shows confirmation dialog → `PUT /orders/{orderId}/proposals/{proposalId}` `{ "status": "REJECTED" }` |
| Accept (green filled) | Shows confirmation dialog → `PUT /orders/{orderId}/proposals/{proposalId}` `{ "status": "ACCEPTED" }` |

### Accept confirmation dialog

Shows courier name and the final fee (with discount if applicable). On confirm calls `OrderCubit.acceptProposal()`. If the wallet balance is insufficient, an `InsufficientBalanceSheet` is shown instead with a top-up shortcut.

### States handled

| State                               | UI                                                             |
| ----------------------------------- | -------------------------------------------------------------- |
| `ProposalsLoading` (initial)        | Full-screen spinner                                            |
| `ProposalsError` (no cached data)   | Error icon + message + retry button                            |
| `ProposalsLoaded` (empty list)      | Empty state illustration + "Couriers will send proposals soon" |
| `ProposalsLoaded` (with data)       | Scrollable list of `_ProposalCard`                             |
| `ProposalAccepted`                  | Bottom sheet closes automatically                              |
| `ProposalAcceptInsufficientBalance` | `InsufficientBalanceSheet` shown                               |

---

## 5. Orders — Cancel

**Source:** `lib/features/orders/data/data_source/order_remote_data_source.dart`  
**Sheet UI:** `lib/features/orders/presentation/widgets/sheets/cancel_order_sheet.dart`

### 5a. Get Cancellation Reasons

```
GET /admin/cancellation-reason/all-reasons
```

**Query params:** `role_id` (int, `3` for customer) · `page` · `limit`

**Response:**

```json
{
  "data": {
    "reasons": [
      { "id": 1, "role_id": 3, "reason_en": "...", "reason_ar": "..." }
    ]
  }
}
```

### 5b. Cancel an Order

```
POST /orders/{orderId}/cancel?lang={locale}
Content-Type: application/json
```

**Body:**

```json
{ "cancelled_reason": "Reason text here" }
```

**Response:** `200 OK` on success.

---

## 6. Orders — Retry & Price Adjustment

**Source:** `lib/features/orders/data/data_source/order_remote_data_source.dart`

### 6a. Retry a Failed Order

```
POST /orders/{orderId}/retry?lang={locale}
```

No request body.  
**Response:** `Map<String, dynamic>` with retry result.

---

### 6b. Respond to a Price Adjustment

When a courier proposes a price change, the customer accepts or rejects it.

```
PUT /orders/{orderId}/price-adjustment?lang={locale}
Content-Type: application/json
```

**Body:**

```json
{ "status": "ACCEPTED" }
// or
{ "status": "REJECTED" }
```

**Response:** `Map<String, dynamic>`.

---

## 6. Delivery Confirmation (QR Scan)

**Source:** `lib/features/orders/data/data_source/order_remote_data_source.dart`

```
POST /orders/confirm-delivery?lang={locale}
Content-Type: application/json
```

**Body:**

```json
{
  "order_id": 123,
  "courier_id": 456
}
```

The `order_id` and `courier_id` are parsed from the QR code scanned at delivery. The QR payload also contains `action: "CONFIRM_DELIVERY"` and a `timestamp`.

**Response:** `Map<String, dynamic>` with confirmation result.

---

## 7. Reviews & Ratings

**Source:**

- `lib/features/orders/presentation/widgets/sheets/review_bottom_sheet.dart`
- `lib/features/reviews/data/data_source/reviews_remote_data_source.dart`

### 7a. Submit Courier Review

```
POST /customer-reviews
Content-Type: application/json
```

**Body:**

```json
{
  "order_id": 123,
  "courier_id": 456,
  "rating": 5,
  "comment": "Great service!"
}
```

**Response:** `201 Created`

---

### 7b. Award Points to Courier

```
POST /customer/points/give-points-to-courier/{courierUserId}
```

No body. **Response:** `200 OK`

---

### 7c. Get My Reviews (as customer, about couriers)

```
GET /courier-reviews?lang={locale}
```

**Query params:** `skip` · `limit` · `sort` (default: `-created_at`)

**Response:** `ReviewsResponse` with list of review objects.

---

## 8. Refunds

**Source:** `lib/features/refunds/data/data_source/refund_remote_data_source.dart`

### 8a. Get Refund Reasons

```
GET /refund-reasons?lang={locale}
```

**Response:**

```json
{
  "refundReasons": [{ "id": 1, "reason_en": "...", "reason_ar": "..." }],
  "totalRefundReasons": 0,
  "totalPages": 0
}
```

---

### 8b. List Refunds

```
GET /refunds?lang={locale}
```

**Query params:** `skip` · `limit`

**Response — each `Refund`:**

| Field             | Type      | Notes              |
| ----------------- | --------- | ------------------ |
| `id`              | int       |                    |
| `order_id`        | int       |                    |
| `amount`          | int       | cents              |
| `currency`        | string    |                    |
| `evidence_images` | string[]? |                    |
| `reason`          | string    |                    |
| `status`          | string    | see statuses below |
| `is_full_refund`  | bool      |                    |
| `reviewed_at`     | ISO 8601? |                    |
| `created_at`      | ISO 8601  |                    |

**Refund statuses:** `REQUESTED` · `PROCESSING` · `APPROVED` · `COMPLETED` · `REJECTED` · `CANCELLED` · `FAILED`

---

## 9. Stats

```
GET /orders/stats/completed-count
```

**Response:** `{ "total": int }` — number of completed orders for the customer.

---

## Order Model

Key fields returned on `OrderResponse`:

| Field           | Type         | Notes                                                        |
| --------------- | ------------ | ------------------------------------------------------------ |
| `id`            | int          |                                                              |
| `orderNumber`   | string       | human-readable                                               |
| `status`        | string       | see statuses in §2a                                          |
| `type`          | string       | always `CUSTOM_PICKUP`                                       |
| `budget`        | double       | EGP                                                          |
| `courierFee`    | double       | EGP                                                          |
| `platformFee`   | double       | EGP                                                          |
| `totalFee`      | double       | EGP                                                          |
| `paymentMethod` | string       | `CASH` / `WALLET` / `CARD`                                   |
| `payment`       | PaymentInfo? | only for `CARD` — `{ provider, transactionId, checkoutUrl }` |
| `courier`       | CourierInfo? | assigned courier                                             |
| `createdAt`     | DateTime     |                                                              |
| `scheduledAt`   | DateTime?    | if scheduled                                                 |

---

## Flow Diagrams

### Custom Order + Proposal Flow

```
Customer creates order (POST /orders, type=CUSTOM_PICKUP)
        │
        ▼
Order status: PENDING
        │
        ▼  (couriers send proposals)
Customer polls GET /orders/{id}/proposals
        │
        ├─► Accept: PUT /orders/{id}/proposals/{pid}  { status: ACCEPTED }
        │         Order moves to IN_PROGRESS
        │
        └─► Reject: PUT /orders/{id}/proposals/{pid}  { status: REJECTED }
                  (wait for more proposals or cancel)
```

### Order Completion Flow

```
IN_PROGRESS
    │
    ▼  (courier arrives, scans QR)
POST /orders/confirm-delivery
    │
    ▼
Status: DELIVERED
    │
    ├─► POST /customer-reviews  (rate courier)
    └─► POST /refunds           (if items damaged/missing)
```

### Retry / Price Adjustment Flow

```
Order fails or price changes
    │
    ├─► Retry:           POST /orders/{id}/retry
    └─► Price change:    PUT  /orders/{id}/price-adjustment  { status: ACCEPTED/REJECTED }
```
