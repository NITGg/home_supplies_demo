# Points Reward System — `givePointsToCourier` & `givePointsToCustomer`

> Both functions run **after an order is delivered**.
> Points accumulate in a **batch**. When the batch reaches its threshold, points transfer to the user's **Wallet** and become spendable.

---

## Settings Reference

All settings come from `ApplicationSetting` (single row, id=1).

### Courier Settings

| Setting | Default | Description |
|---------|---------|-------------|
| `courier_number_of_points_awarded_per_completed_order_batch` | 50 | Points needed to complete a batch (also the amount awarded) |
| `courier_number_of_delivered_orders_required_per_reward_batch` | 5 | Orders needed to fill a batch |
| `courier_points_minimum_rating_threshold` | 4 | Min rating to earn points |
| `courier_points_validity_days` | 90 | Days before batch expires |
| `courier_number_of_points_required_per_1egp` | 10 | Points per 1 EGP |

### Customer Settings

| Setting | Default | Description |
|---------|---------|-------------|
| `customer_number_of_points_awarded_per_completed_order_batch` | 50 | Points needed to complete a batch |
| `customer_points_cashback_percentage_per_orders_batch` | 4 | Cashback % of order value earned as points |
| `customer_points_minimum_rating_threshold` | 4 | Min rating to earn points |
| `customer_points_validity_days` | 90 | Days before batch expires |
| `customer_number_of_points_required_per_1egp` | 10 | Points per 1 EGP |

---

## Database Models

### CourierPointBatch / CustomerPointBatch

| Field | Type | Description |
|-------|------|-------------|
| `id` | Int | Primary key |
| `user_id` | Int? | Owner (user ID) |
| `fixed_batch_point_amount` | Int? | Threshold to complete batch |
| `balance` | Int? | Points accumulated so far |
| `all_points_collected_at` | DateTime? | Set when batch completes |
| `is_expired` | Boolean | Expired by low rating or cron |
| `expired_at` | DateTime? | Expiration date (created_at + validity_days) |

### Wallet

| Field | Type | Description |
|-------|------|-------------|
| `points` | Int | Spendable points (from completed batches) |

---

## givePointsToCourier

### How courier earns points

Each qualifying order earns a **fixed** amount:

```
per_order_points = awarded / required
Example: 50 / 5 = 10 points per order
```

### Logic

```
ORDER DELIVERED
    │
    ├── rating >= min_rating? ──── NO ──┐
    │                                    │
    │ YES                                │
    │                                    ▼
    ├── Active batch exists?        Active batch exists?
    │   ├── YES: add points         ├── YES: expire it (is_expired = true)
    │   └── NO: create new batch    └── NO: do nothing
    │
    └── Check if batch is complete
```

### Batch Completion Check

```
IF balance >= threshold:
    overflow = balance - threshold
    pointsToWallet = threshold       (i.e. balance - overflow)
    
    SET all_points_collected_at = NOW
    Wallet.points += pointsToWallet
    
    IF overflow > 0:
        Create NEW batch with balance = overflow
        Run this check again on the new batch
```

### Courier Example

> Settings: `awarded=50`, `required=5`, `min_rating=4`
> `per_order_points = 10`

| Order | Rating | Action | Batch Balance | Wallet | Notes |
|-------|--------|--------|---------------|--------|-------|
| 1 | ⭐5 | Create batch | 10 | 0 | New batch (threshold=50) |
| 2 | ⭐4 | Update batch | 20 | 0 | |
| 3 | ⭐5 | Update batch | 30 | 0 | |
| 4 | ⭐3 | **Expire batch** | — | 0 | Rating < 4 → all 30 points lost |
| 5 | ⭐5 | Create batch | 10 | 0 | Fresh start |
| 6 | ⭐4 | Update batch | 20 | 0 | |
| 7 | ⭐5 | Update batch | 30 | 0 | |
| 8 | ⭐4 | Update batch | 40 | 0 | |
| 9 | ⭐5 | Update batch | **50** | **50** | ✅ Batch complete! 50 pts → Wallet |

---

## givePointsToCustomer

### How customer earns points

Each order earns a **variable** amount based on order value:

```
cashBackAsEGP    = order_value × cashback_pct / 100
cashBackAsPoints = floor(cashBackAsEGP × points_per_egp)

Example: order=200 EGP, cashback=4%, points_per_egp=10
  → cashBackAsEGP = 200 × 4 / 100 = 8 EGP
  → cashBackAsPoints = 8 × 10 = 80 points
```

### Logic

Same as courier (create/update/expire/nothing), except:
- Points per order are **variable** (cashback-based) instead of fixed
- Uses `customer_*` settings instead of `courier_*`

### Batch Completion Check

Same as courier:
```
IF balance >= threshold:
    overflow = balance - threshold
    pointsToWallet = threshold
    
    Wallet.points += pointsToWallet
    
    IF overflow > 0:
        Create NEW batch with balance = overflow
        Check again
```

### Customer Example

> Settings: `threshold=50`, `cashback=4%`, `points_per_egp=10`, `min_rating=4`

| Order | Price | Rating | Points Earned | Batch Balance | Wallet | Notes |
|-------|-------|--------|---------------|---------------|--------|-------|
| 1 | 200 | ⭐5 | 80 | 80 → complete! | 50 | Batch hits 80 ≥ 50. Wallet +50. Overflow 30 → new batch |
| 2 | 50 | ⭐4 | 20 | 30+20 = 50 → complete! | 100 | 2nd batch complete. Wallet +50 |
| 3 | 30 | ⭐5 | 12 | 12 | 100 | New batch started |
| 4 | 30 | ⭐2 | — | — | 100 | **Batch expired!** Rating < 4, 12 points lost |
| 5 | 100 | ⭐5 | 40 | 40 | 100 | New batch started |

> Order #1: A single high-value order can complete a batch and overflow into the next one.

---

## Shared Behaviors

### 1. Transaction Safety
Both functions are wrapped in `prisma.$transaction()` to prevent race conditions.

### 2. Batch Expiration by Time
A **cron job** (separate project) marks batches expired when `expired_at < NOW()`:
```sql
UPDATE courier_point_batch / customer_point_batch
SET is_expired = true
WHERE expired_at < NOW() AND is_expired = false AND all_points_collected_at IS NULL
```

### 3. Low Rating Expires Entire Batch
One order with rating below the threshold **expires the entire active batch** — all accumulated progress is lost. This incentivizes consistent quality.

### 4. Wallet Points Usage
Spendable points can be used to:
- Buy coupons
- Pay unpaid commissions
- Cover penalties

Points are deducted from completed batches using **FIFO** (oldest first).
