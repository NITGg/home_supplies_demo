# Create Order — Request Body Reference (`CUSTOM_PICKUP`)

Sent as **`multipart/form-data`** (always, even without an image).  
Endpoint: `POST /orders?lang={locale}`

---

## Common Fields (always sent)

| Field                          | Type   | Example                                                 |
| ------------------------------ | ------ | ------------------------------------------------------- |
| `type`                         | string | `"CUSTOM_PICKUP"`                                       |
| `product_description`          | string | `"I need 2kg of apples from the market"` (min 10 chars) |
| `pickup_area_id`               | int    | `3`                                                     |
| `pickup_address_description`   | string | `"Building 5, Street 10, Maadi"`                        |
| `pickup_lat`                   | string | `"30.0444"`                                             |
| `pickup_long`                  | string | `"31.2357"`                                             |
| `delivery_area_id`             | int    | `7`                                                     |
| `delivery_address_description` | string | `"Apartment 12, Tower B, Nasr City"`                    |
| `delivery_lat`                 | string | `"30.0650"`                                             |
| `delivery_long`                | string | `"31.3400"`                                             |
| `payment_method`               | string | `"CASH"` or `"WALLET"` — see rules below                |

---

## `budget` Field

> **Always sent as a string representing cents (piasters).**

| Mode         | Calculation                               | Example                                  |
| ------------ | ----------------------------------------- | ---------------------------------------- |
| **Shopping** | `(userEnteredEGP × 100).round()` → string | User types `50` EGP → send `"5000"`      |
| **Shipping** | Literal `"1"`                             | Signals shipping-only, no product budget |

---

## `payment_method` Rules

| Situation                                                  | Value sent |
| ---------------------------------------------------------- | ---------- |
| Shopping + user chose **Cash** + budget ≤ COD limit        | `"CASH"`   |
| Shopping + user chose **Wallet**                           | `"WALLET"` |
| Shopping + budget **exceeds** COD limit (forced to wallet) | `"WALLET"` |
| **Shipping mode** (no cash option, always wallet)          | `"WALLET"` |

---

## Optional Fields

| Field                | Type                  | When included                                                              |
| -------------------- | --------------------- | -------------------------------------------------------------------------- |
| `product_image`      | multipart file (jpg)  | User picked an image. **Required** in shipping mode, optional in shopping  |
| `is_order_scheduled` | boolean `true`        | User selected "Schedule". Omitted entirely for ASAP orders                 |
| `order_schedule_at`  | string — ISO 8601 UTC | Included alongside `is_order_scheduled`. e.g. `"2025-06-10T14:30:00.000Z"` |
| `coupon_code`        | string                | Wired but currently disabled in the UI                                     |

---

## "Near Me" Pickup

When the user checks **Near Me**, no separate pickup address is selected.  
The **delivery address doubles as the pickup address** — the same coordinates, area ID, and description are sent for both `pickup_*` and `delivery_*` fields.

---

## Full Examples

### Shopping — Cash, ASAP, no image

```json
{
  "type": "CUSTOM_PICKUP",
  "product_description": "2kg apples and 1 bottle of olive oil",
  "budget": "15000",
  "pickup_area_id": 3,
  "pickup_address_description": "Building 5, Street 10, Maadi",
  "pickup_lat": "30.0444",
  "pickup_long": "31.2357",
  "delivery_area_id": 7,
  "delivery_address_description": "Apartment 12, Tower B, Nasr City",
  "delivery_lat": "30.0650",
  "delivery_long": "31.3400",
  "payment_method": "CASH"
}
```

### Shopping — Wallet, Scheduled

```json
{
  "type": "CUSTOM_PICKUP",
  "product_description": "2kg apples and 1 bottle of olive oil",
  "budget": "15000",
  "pickup_area_id": 3,
  "pickup_address_description": "Building 5, Street 10, Maadi",
  "pickup_lat": "30.0444",
  "pickup_long": "31.2357",
  "delivery_area_id": 7,
  "delivery_address_description": "Apartment 12, Tower B, Nasr City",
  "delivery_lat": "30.0650",
  "delivery_long": "31.3400",
  "payment_method": "WALLET",
  "is_order_scheduled": true,
  "order_schedule_at": "2025-06-10T14:30:00.000Z"
}
```

### Shipping — Near Me, with image

```
multipart/form-data fields:

type                          = "CUSTOM_PICKUP"
product_description           = "Fragile package, handle with care"
budget                        = "1"
pickup_area_id                = 7          ← same as delivery
pickup_address_description    = "Apartment 12, Tower B, Nasr City"
pickup_lat                    = "30.0650"  ← same as delivery
pickup_long                   = "31.3400"  ← same as delivery
delivery_area_id              = 7
delivery_address_description  = "Apartment 12, Tower B, Nasr City"
delivery_lat                  = "30.0650"
delivery_long                 = "31.3400"
payment_method                = "WALLET"
product_image                 = <binary file — product_{timestamp}.jpg>
```

---

## Preview Endpoint

Used to fetch the estimated delivery fee **before** the user submits.

`POST /orders/preview?lang={locale}` — JSON body (not multipart)

Differences from the create body:

- `budget` is sent as **int in cents** (not a string) — e.g. `15000`
- `pickup_lat` / `pickup_long` / `delivery_lat` / `delivery_long` are sent as **floats** (not strings)
- `product_description` is a hardcoded placeholder `"product_description"` (value is irrelevant for fee calculation)
- No image, no schedule fields

```json
{
  "type": "CUSTOM_PICKUP",
  "product_description": "product_description",
  "budget": 15000,
  "payment_method": "CASH",
  "pickup_area_id": 3,
  "pickup_address_description": "Building 5, Street 10, Maadi",
  "pickup_lat": 30.0444,
  "pickup_long": 31.2357,
  "delivery_area_id": 7,
  "delivery_address_description": "Apartment 12, Tower B, Nasr City",
  "delivery_lat": 30.065,
  "delivery_long": 31.34
}
```

> For **shipping mode** the preview uses `budget: 1` (1 cent placeholder) and `payment_method: "WALLET"`.
