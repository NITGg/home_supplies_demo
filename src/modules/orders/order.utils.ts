import { HttpError } from "@/lib/httpError";
import { Tx } from "@/types/prisma.types";
import { Order, OrderItem, OrderType, Prisma, Vehicle } from "@prisma/client";
import crypto from "node:crypto";
import {
  assertCouponDates,
  assertOrderCouponMinOrdersCount,
  assertOrderCouponUsageLimits,
} from "../profile/services/wallet.service";
import { calculateOrderDiscountCents } from "../customer-coupons/customer-coupons.service";
import { parseProductImages } from "@/lib/productImages";
import {
  activeOfferWhere,
  buildSupplierProductPricing,
} from "@/lib/catalogHelpers";
import { prisma } from "@/config/prisma";
import { adjustWalletBalance } from "@/lib/adjustWalletBalance";
import { bus } from "@/events/bus";
import { Decimal } from "@prisma/client/runtime/client";

export function genOrderNumber() {
  const date = new Date().toISOString().slice(0, 10).replaceAll("-", "");
  const rand = crypto.randomBytes(3).toString("hex").toUpperCase();
  return `ORD-${date}-${rand}`;
}

export function sumOrderAmount(params: {
  totalFee: Prisma.Decimal;
  actualPrice: Prisma.Decimal;
}) {
  return params.totalFee?.add(params.actualPrice || 0);
}

export async function validateOrderCouponForCreate(
  tx: Tx,
  input: {
    userId: number;
    code: string;
    budgetCents: number;
    estimatedDeliveryFeeCents: number;
    orderType: OrderType;
  },
) {
  const now = new Date();
  const code = input.code.trim();

  const coupon = await tx.customerCoupon.findFirst({
    where: {
      code,
      is_active: true,
      deleted_at: null,
    },
    select: {
      id: true,
      code: true,
      type: true,
      scope: true,
      start_at: true,
      end_at: true,
      min_orders_count: true,
      max_total_uses: true,
      max_user_uses: true,
      discount_type: true,
      discount_value: true,
      max_discount_cents: true,
      min_order_total_cents: true,
    },
  });
  if (!coupon) throw new HttpError(404, "customer-coupons:errors.not_found");
  if (input.orderType === "CUSTOM_PICKUP" && coupon.scope !== "DELIVERY_FEE") {
    throw new HttpError(
      400,
      "customer-coupons:errors.invalid_coupon_scope_for_order_type",
    );
  }

  assertCouponDates(coupon, now);
  await assertOrderCouponMinOrdersCount(tx, { userId: input.userId }, coupon);
  await assertOrderCouponUsageLimits(tx, { userId: input.userId }, coupon);

  // min_order_total_cents always checks against the FULL order value regardless of scope
  const fullOrderCents = input.budgetCents + input.estimatedDeliveryFeeCents;

  if (
    coupon.min_order_total_cents != null &&
    fullOrderCents < coupon.min_order_total_cents
  ) {
    throw new HttpError(400, "customer-coupons:errors.min_order_total_not_met");
  }

  if (coupon.type === "WALLET_CREDIT") {
    return {
      couponId: coupon.id,
      type: coupon.type,
      discountCents: 0,
      payableCents: fullOrderCents,
    };
  }
  // DELIVERY_FEE scope: discount is deferred until we know the real fee
  // if (coupon.scope === "DELIVERY_FEE") {
  //   return {
  //     couponId: coupon.id,
  //     discountCents: 0,
  //     payableCents: input.budgetCents, // hold only budget, delivery applied later
  //   };
  // }

  const discountCents = calculateOrderDiscountCents(
    coupon,
    input.budgetCents,
    input.estimatedDeliveryFeeCents,
  );

  return {
    couponId: coupon.id,
    type: coupon.type,
    discountCents,
    payableCents: fullOrderCents - discountCents,
  };
}

export async function recalculateOrderCouponForOrder(
  tx: Tx,
  input: {
    orderId: number;
    budgetCents: number;
    totalFeeCents: number;
    updateOrder: boolean;
  },
) {
  const order = await tx.order.findUnique({
    where: { id: input.orderId },
    select: { id: true, customer_id: true, coupon_id: true },
  });

  if (!order) throw new HttpError(404, "orders:errors.order_not_found");

  const fullOrderCents = input.budgetCents + input.totalFeeCents;

  if (!order.coupon_id) {
    await tx.order.update({
      where: { id: order.id },
      data: {
        discount_amount: 0,
        payable_amount: Decimal(fullOrderCents),
      },
    });
    return { couponId: null, discountCents: 0, payableCents: fullOrderCents };
  }

  const coupon = await tx.customerCoupon.findUnique({
    where: { id: order.coupon_id },
    select: {
      id: true,
      type: true,
      scope: true,
      is_active: true,
      deleted_at: true,
      start_at: true,
      end_at: true,
      discount_type: true,
      discount_value: true,
      max_discount_cents: true,
      min_order_total_cents: true,
    },
  });

  const now = new Date();
  let discountCents = 0;

  if (
    coupon?.type === "ORDER_DISCOUNT" &&
    coupon.is_active &&
    !coupon.deleted_at
  ) {
    assertCouponDates(coupon, now);

    const meetsMinTotal =
      coupon.min_order_total_cents == null ||
      fullOrderCents >= coupon.min_order_total_cents;

    if (meetsMinTotal) {
      discountCents = calculateOrderDiscountCents(
        coupon,
        input.budgetCents,
        input.totalFeeCents,
      );
    }
  }

  const payableCents = Math.max(0, fullOrderCents - discountCents);

  if (input.updateOrder) {
    await tx.order.update({
      where: { id: order.id },
      data: {
        discount_amount: discountCents,
        payable_amount: payableCents,
      },
    });
  }

  await tx.customerCouponUsage.updateMany({
    where: { order_id: order.id, coupon_id: order.coupon_id, context: "ORDER" },
    data: { discount_cents: discountCents },
  });

  return {
    couponId: order.coupon_id,
    discountCents,
    payableCents,
    scope: coupon?.scope,
  };
}

export async function applyWalletCouponReward(
  tx: Tx,
  order: {
    id: number;
    customer_id: number | null;
    coupon_id: number | null;
    totalAmount: number;
  },
) {
  if (!order.coupon_id || !order.customer_id) return;

  const now = new Date();

  const coupon = await tx.customerCoupon.findUnique({
    where: { id: order.coupon_id },
    select: {
      id: true,
      type: true,
      is_active: true,
      deleted_at: true,
      start_at: true,
      end_at: true,
      wallet_amount_cents: true,
      wallet_points: true,
      min_orders_count: true,
      max_total_uses: true,
      max_user_uses: true,
      min_order_total_cents: true,
    },
  });

  if (!coupon) return;
  console.log("applyWalletCouponReward-> coupon", coupon);

  // ✅ Only wallet coupons
  if (coupon.type !== "WALLET_CREDIT") return;

  // ✅ Validity checks
  if (!coupon.is_active || coupon.deleted_at) return;

  assertCouponDates(coupon, now);
  await assertOrderCouponMinOrdersCount(
    tx,
    { userId: order.customer_id },
    coupon,
  );
  await assertOrderCouponUsageLimits(tx, { userId: order.customer_id }, coupon);

  if (
    coupon.min_order_total_cents != null &&
    order.totalAmount < coupon.min_order_total_cents
  ) {
    throw new HttpError(400, "customer-coupons:errors.min_order_total_not_met");
  }

  // ✅ Prevent double reward (VERY IMPORTANT)
  const existingUsage = await tx.customerCouponUsage.findFirst({
    where: {
      order_id: order.id,
      coupon_id: coupon.id,
      context: "WALLET",
    },
  });

  const wallet = await tx.wallet.findUnique({
    where: { user_id: order.customer_id },
  });

  console.log("user wallet:", wallet);

  if (!wallet) throw new HttpError(404, "wallet:errors.not_found");

  // 💰 Credit money
  if (coupon.wallet_amount_cents > 0) {
    console.log(
      "applyWalletCouponReward-> wallet_amount_cents",
      coupon.wallet_amount_cents,
    );

    await adjustWalletBalance(tx, wallet.id, coupon.wallet_amount_cents, {
      order_id: order.id,
    });

    // Credit points separately (adjustWalletBalance only handles balance)
    if (coupon.wallet_points > 0) {
      await tx.wallet.update({
        where: { id: wallet.id },
        data: { points: { increment: coupon.wallet_points } },
      });
    }

    await tx.transaction.create({
      data: {
        wallet_id: wallet.id,
        order_id: order.id,
        type: "COUPON_PURCHASE",
        status: "COMPLETED",
        amount: coupon.wallet_amount_cents,
        description: `Wallet reward from coupon ${coupon.id}`,
      },
    });
  }

  // ⭐ Credit points
  let pointsTransactionId: number | null = null;

  if (coupon.wallet_points > 0) {
    console.log(
      "applyWalletCouponReward-> wallet_points",
      coupon.wallet_points,
    );

    // const pointsTx = await tx.pointsTransaction.create({
    //   data: {
    //     // user: { connect: { id: order.customer_id } }, // Use 'user' relation, not 'user_id' field
    //     // wallet: { connect: { id: wallet.id } },
    //     user_id: order.customer_id,
    //     wallet_id: wallet.id,
    //     amount: coupon.wallet_points,
    //     type: "REDEEM_COUPON",
    //     order_id: order.id,
    //     coupon_usage_id: existingUsage?.id,
    //   },
    // });

    // pointsTransactionId = pointsTx.id;
  }

  // // ✅ Update usage (link points if exists)
  // await tx.customerCouponUsage.updateMany({
  //   where: {
  //     order_id: order.id,
  //     coupon_id: coupon.id,
  //   },
  //   data: {
  //     context: "WALLET",
  //     pointsTransactionId: pointsTransactionId ?? undefined,
  //   },
  // });
}

// Reusable rounding helpers
export const roundTo100 = (v: Prisma.Decimal) =>
  v.div(100).toDecimalPlaces(0, Prisma.Decimal.ROUND_HALF_UP).mul(100);

export const roundTo100Ceil = (v: Prisma.Decimal) =>
  v.div(100).toDecimalPlaces(0, Prisma.Decimal.ROUND_CEIL).mul(100);

/**
 * Core Logic: Split base fee, add distance surcharges, apply peak time, and handle courier bonuses.
 */
export function calculateSharedFeeLogic(params: {
  baseFee: Decimal;
  distanceM: number;
  badgeRatio: number;
  courierBid?: Decimal;
  thresholdKm: number;
  extraPlatformPerKm: number;
  extraCourierPerKm: number;
  peakRatio: number;
  vatRate: Decimal;
  minPlatformFee: Decimal;
  couponBonusPercent?: number;
}) {
  const {
    baseFee,
    distanceM,
    badgeRatio,
    thresholdKm,
    extraPlatformPerKm,
    extraCourierPerKm,
    peakRatio,
    vatRate,
    minPlatformFee,
    couponBonusPercent = 0,
    courierBid = Decimal(0),
  } = params;

  const distanceKm = distanceM / 1000;
  console.log(`--- Fee Calc Start [Dist: ${distanceKm.toFixed(2)}km] ---`);
  console.log(`[Init] Base: ${baseFee}, BadgeRatio: ${badgeRatio}`);

  // 1. Initial Split
  let platformFee = baseFee.mul(badgeRatio);
  let courierFee = baseFee.sub(platformFee);
  console.log(`[Split] Courier: ${courierFee}, Platform: ${platformFee}`);

  // 2. Extra Distance Fees
  if (distanceKm > thresholdKm) {
    const extraDistance = Decimal(distanceKm - thresholdKm);
    const platformExtra = extraDistance.mul(extraPlatformPerKm);
    const courierExtra = extraDistance.mul(extraCourierPerKm);

    platformFee = platformFee.add(platformExtra);
    courierFee = courierFee.add(courierExtra);
    console.log(
      `[Extra] Added Platform: +${platformExtra}, Courier: +${courierExtra}`,
    );
  }

  // 3. Peak Surcharge
  const subTotal = platformFee.add(courierFee);
  const peakSurcharge =
    peakRatio > 0
      ? roundTo100Ceil(subTotal.mul(peakRatio).div(100))
      : Decimal(0);

  if (peakSurcharge.gt(0)) {
    const peakPlatform = peakSurcharge.mul(badgeRatio);
    const peakCourier = peakSurcharge.sub(peakPlatform);
    platformFee = platformFee.add(peakPlatform);
    courierFee = courierFee.add(peakCourier);
    console.log(
      `[Peak] Total: ${peakSurcharge} (Ratio: ${peakRatio}%) | Split -> P: +${peakPlatform}, C: +${peakCourier}`,
    );
  }

  if (courierBid.gt(0)) {
    console.log(
      `[Sub Total] ${subTotal}, [platform] ${platformFee}, [courier] ${courierFee}, [new bid offer] ${courierBid}`,
    );
    const bidAdjustment = courierBid.sub(courierFee);
    courierFee = courierFee.add(bidAdjustment);
    console.log(`[Bid] Adjustment: ${bidAdjustment} added to Courier Fee`);
  }

  // 4. Courier Bonus (Incentive shift)
  let appliedBonus = Decimal(0);
  if (couponBonusPercent > 0) {
    const bonusPercentDec = Decimal(couponBonusPercent).div(100);
    const bonusFee = roundTo100(courierFee.mul(bonusPercentDec));
    const maxReducible = Prisma.Decimal.max(0, platformFee.sub(minPlatformFee));
    appliedBonus = Prisma.Decimal.min(bonusFee, maxReducible);

    platformFee = platformFee.sub(appliedBonus);
    courierFee = courierFee.add(appliedBonus);
    console.log(
      `[Bonus] Courier Bonus: ${appliedBonus} (Shifted from Platform)`,
    );
  }

  // 5. VAT on Platform Share
  const vatAmount = roundTo100Ceil(platformFee.mul(vatRate));
  console.log(`[VAT] Amount: ${vatAmount} (Rate: ${vatRate.mul(100)}%)`);

  const finalCourierFee = roundTo100(courierFee);
  const finalPlatformFeeWithVat = roundTo100(platformFee).add(vatAmount);

  const result = {
    courierFee: finalCourierFee,
    platformFee: finalPlatformFeeWithVat,
    vatAmount: vatAmount,
    totalFee: finalCourierFee.add(finalPlatformFeeWithVat),
    peakTimeSurcharge: peakSurcharge,
    isPeakTime: peakRatio > 0,
    appliedBonus: appliedBonus,
  };

  console.log(
    `[Final] Total: ${result.totalFee}, Courier: ${result.courierFee}, Platform(Incl.VAT): ${result.platformFee}`,
  );
  console.log(`--- Fee Calc End ---`);

  return result;
}

// ─── Peak time query helper (reused across all 3 functions) ───────────────────
export async function fetchPeakTimeSurcharge(
  tx: Prisma.TransactionClient,
  baseFee: Prisma.Decimal,
  peakTimeRatio: Prisma.Decimal,
): Promise<{ surcharge: Prisma.Decimal; isPeakTime: boolean }> {
  const now = new Date();
  const currentDay = now.getDay();
  const currentTime = `${String(now.getHours()).padStart(2, "0")}:${String(now.getMinutes()).padStart(2, "0")}`;

  const peakTimeMatch = await tx.peakTime.findFirst({
    where: {
      day: currentDay,
      start_time: { lte: currentTime },
      end_time: { gte: currentTime },
      is_active: true,
    },
  });

  if (!peakTimeMatch || peakTimeRatio.lte(0)) {
    return { surcharge: Decimal(0), isPeakTime: false };
  }

  const surcharge = roundTo100Ceil(baseFee.mul(peakTimeRatio).div(100));
  return { surcharge, isPeakTime: true };
}

// ─── computeOrderFeeSplit (used at acceptProposal) ────────────────────────────
export async function computeOrderFeeSplit(
  tx: Prisma.TransactionClient,
  input: {
    courierId: number;
    courierBid?: Decimal;
    distanceM: number;
    vatRate: Decimal;
    minPlatformFee: Decimal;
    isFixedFee?: boolean; // Added flag
    fixedTotalFee?: Decimal; // Passed historical fee
    preFetched?: {
      badgeRatio: number;
      vehicle: {
        min_delivery_fee: Decimal;
        fee_base_distance_km: number;
        fee_extra_platform_per_km: number;
        fee_extra_courier_per_km: number;
        peak_time_fee_ratio: number;
      };
      couponBonusPercent: number | null;
    };
  },
): Promise<{
  courierFee: Decimal;
  platformFee: Decimal;
  vatAmount: Decimal;
  totalFeeWithVat: Decimal;
  isPeakTime: boolean;
  peakTimeSurcharge: Decimal;
}> {
  let badgeRatio: number;
  let vehicle: {
    min_delivery_fee: Decimal;
    fee_base_distance_km: number;
    fee_extra_platform_per_km: number;
    fee_extra_courier_per_km: number;
    peak_time_fee_ratio: number;
  };
  let couponBonus: number = 0;

  if (input.preFetched) {
    badgeRatio = input.preFetched.badgeRatio / 100;
    vehicle = input.preFetched.vehicle;
    couponBonus = input.preFetched.couponBonusPercent ?? 0;
  } else {
    // Standard fetch for the "Accept" flow
    const courier = await tx.courier.findUnique({
      where: { id: input.courierId },
      include: { user: { include: { badge: true } }, vehicle: true },
    });
    if (!courier?.user || !courier.vehicle)
      throw new HttpError(404, "courier_or_vehicle_not_found");

    badgeRatio = (courier.user.badge?.ratio ?? 30) / 100;
    vehicle = courier.vehicle;

    const now = new Date();
    const activeCoupon = await tx.courierCouponUsage.findFirst({
      where: {
        user_id: courier.user.id,
        start_date: { lte: now },
        end_date: { gte: now },
      },
      orderBy: { created_at: "desc" },
    });
    couponBonus = Number(activeCoupon?.snapshot_bonus_courier_fee ?? 0);
  }

  // ── Fixed Fee Optimization Branch ──────────────────────────────────────────
  if (input.isFixedFee && input.fixedTotalFee) {
    console.log(
      `⚡ [FIXED_FEE_FLOW] Applying Badge Ratio split directly onto base: ${input.fixedTotalFee}`,
    );

    // Reverse-engineer clean split metrics directly from your shared math core
    // baseFee = platformFee + courierFee -> Applying direct balance shift logic
    let platformFee = input.fixedTotalFee.mul(badgeRatio);
    let courierFee = input.fixedTotalFee.sub(platformFee);

    // Apply active bonus coupons without affecting the fixed customer price ceiling
    if (couponBonus > 0) {
      const bonusPercentDec = Decimal(couponBonus).div(100);
      const bonusFee = roundTo100(courierFee.mul(bonusPercentDec));
      const maxReducible = Prisma.Decimal.max(
        0,
        platformFee.sub(input.minPlatformFee),
      );
      const appliedBonus = Prisma.Decimal.min(bonusFee, maxReducible);

      platformFee = platformFee.sub(appliedBonus);
      courierFee = courierFee.add(appliedBonus);
      console.log(
        `[Fixed Flow Bonus Shift] Adjusted platform -> courier by: ${appliedBonus}`,
      );
    }

    // Isolate internal platform taxation allocation
    const vatAmount = roundTo100Ceil(platformFee.mul(input.vatRate));

    return {
      courierFee: roundTo100(courierFee),
      platformFee: roundTo100(platformFee).add(vatAmount),
      vatAmount: vatAmount,
      totalFeeWithVat: input.fixedTotalFee, // Absolute locked consumer threshold
      isPeakTime: false,
      peakTimeSurcharge: Decimal(0),
    };
  }

  // 2. Determine Peak Time
  const now = new Date();
  const peakTimeMatch = await tx.peakTime.findFirst({
    where: {
      day: now.getDay(),
      start_time: {
        lte: `${String(now.getHours()).padStart(2, "0")}:${String(now.getMinutes()).padStart(2, "0")}`,
      },
      end_time: {
        gte: `${String(now.getHours()).padStart(2, "0")}:${String(now.getMinutes()).padStart(2, "0")}`,
      },
      is_active: true,
    },
  });
  const peakRatio = peakTimeMatch ? (vehicle.peak_time_fee_ratio ?? 0) : 0;

  // 3. Execute Shared Logic
  const result = calculateSharedFeeLogic({
    baseFee: vehicle.min_delivery_fee,
    distanceM: input.distanceM,
    badgeRatio,
    thresholdKm: vehicle.fee_base_distance_km,
    extraPlatformPerKm: vehicle.fee_extra_platform_per_km,
    extraCourierPerKm: vehicle.fee_extra_courier_per_km,
    peakRatio,
    vatRate: input.vatRate,
    minPlatformFee: input.minPlatformFee,
    couponBonusPercent: couponBonus,
    courierBid: input.courierBid,
  });

  return {
    courierFee: result.courierFee,
    platformFee: result.platformFee,
    vatAmount: result.vatAmount,
    totalFeeWithVat: result.totalFee,
    isPeakTime: result.isPeakTime,
    peakTimeSurcharge: result.peakTimeSurcharge,
  };
}

// ─── computeEstimatedFeeSplit (unchanged logic, rounding added) ───────────────
export async function computeEstimatedFeeSplit(
  tx: Prisma.TransactionClient,
  input: {
    distanceM: number;
    vehicleId: number;
    vehicle?: Vehicle; // Make vehicle optional
    vatRate: Decimal;
    minPlatformFee: Decimal;
  },
): Promise<{
  courierFee: Prisma.Decimal;
  platformFee: Prisma.Decimal;
  vatAmount: Prisma.Decimal;
  totalFeeWithVat: Prisma.Decimal;
  isPeakTime: boolean;
  peakTimeSurcharge: Prisma.Decimal;
}> {
  const now = new Date();
  const currentDay = now.getDay();
  const currentTime = `${String(now.getHours()).padStart(2, "0")}:${String(now.getMinutes()).padStart(2, "0")}`;

  // 1. Prepare parallel fetches.
  // We only fetch the vehicle if input.vehicle is undefined.
  const [fetchedVehicle, worstBadge, peakTimeMatch] = await Promise.all([
    input.vehicle
      ? Promise.resolve(null)
      : tx.vehicle.findUnique({ where: { id: input.vehicleId } }),
    tx.userBadge.findFirst({
      where: { role_id: 2 },
      orderBy: { ratio: "desc" },
      select: { ratio: true },
    }),
    tx.peakTime.findFirst({
      where: {
        day: currentDay,
        start_time: { lte: currentTime },
        end_time: { gte: currentTime },
        is_active: true,
      },
    }),
  ]);

  // Use the passed vehicle or the one we just fetched
  const vehicle = input.vehicle || fetchedVehicle;

  if (!vehicle) {
    throw new HttpError(404, "Vehicle not found");
  }

  const badgeRatio = (worstBadge?.ratio ?? 30) / 100;
  const peakRatio = peakTimeMatch ? (vehicle.peak_time_fee_ratio ?? 20) : 0;

  // 2. Call the reusable core logic
  const result = calculateSharedFeeLogic({
    baseFee: vehicle.min_delivery_fee,
    distanceM: input.distanceM,
    badgeRatio: badgeRatio,
    thresholdKm: vehicle.fee_base_distance_km,
    extraPlatformPerKm: vehicle.fee_extra_platform_per_km,
    extraCourierPerKm: vehicle.fee_extra_courier_per_km,
    peakRatio: peakRatio,
    vatRate: input.vatRate,
    minPlatformFee: input.minPlatformFee,
  });

  return {
    courierFee: result.courierFee,
    platformFee: result.platformFee,
    vatAmount: result.vatAmount,
    totalFeeWithVat: result.totalFee,
    isPeakTime: result.isPeakTime,
    peakTimeSurcharge: result.peakTimeSurcharge,
  };
}

/**
 * Tiered fixed-fee split — no badge/ratio logic.
 *
 * ≤ base distance  → flat base fees (platform + courier)
 * > base distance  → base + (extra per km × extra kms)
 *
 * All values come from ApplicationSettings so admins can tweak them live.
 */
export async function computeEstimatedFeeSplit2(
  tx: Prisma.TransactionClient,
  input: { courierBudgetCents: number; distanceM: number },
): Promise<{
  courierFee: Prisma.Decimal;
  platformFee: Prisma.Decimal;
  totalFee: Prisma.Decimal;
  isPeakTime: boolean;
  peakTimeSurcharge: Prisma.Decimal;
}> {
  const settings = await tx.applicationSetting.findFirst({
    select: {
      fee_base_distance_km: true,
      fee_base_platform_cents: true,
      fee_base_courier_cents: true,
      fee_extra_platform_per_km: true,
      fee_extra_courier_per_km: true,
      peak_time_fee_ratio: true,
    },
  });

  const baseDistanceKm = settings?.fee_base_distance_km ?? 2;
  const basePlatform = settings?.fee_base_platform_cents ?? 2000;
  const baseCourier = settings?.fee_base_courier_cents ?? 1000;
  const extraPlatformPerKm = settings?.fee_extra_platform_per_km ?? 100;
  const extraCourierPerKm = settings?.fee_extra_courier_per_km ?? 100;
  const peakTimeRatio = settings?.peak_time_fee_ratio ?? 20; // e.g. 20 = 20%

  console.log("\n===== computeEstimatedFeeSplit2 =====");
  console.log(
    "[INPUT]  distanceM:",
    input.distanceM,
    "| courierBudgetCents:",
    input.courierBudgetCents,
  );
  console.log("[DB]     settings:", settings);
  console.log(
    "[CONFIG] baseDistanceKm:",
    baseDistanceKm,
    "| basePlatform:",
    basePlatform,
    "| baseCourier:",
    baseCourier,
  );
  console.log(
    "[CONFIG] extraPlatformPerKm:",
    extraPlatformPerKm,
    "| extraCourierPerKm:",
    extraCourierPerKm,
  );
  console.log("[CONFIG] peakTimeRatio:", peakTimeRatio, "%");

  const distanceKm = input.distanceM / 1000;

  // How many full extra kms beyond the threshold?
  const extraKms = Math.max(0, Math.ceil(distanceKm) - baseDistanceKm);

  console.log(
    "[CALC]   distanceKm:",
    distanceKm,
    "| ceil:",
    Math.ceil(distanceKm),
    "| extraKms:",
    extraKms,
  );

  let platformFee = Decimal(basePlatform + extraKms * extraPlatformPerKm);
  let courierFee = Decimal(baseCourier + extraKms * extraCourierPerKm);
  let totalFee = platformFee.add(courierFee);

  console.log(
    "[BASE]   platformFee:",
    platformFee.toString(),
    "| courierFee:",
    courierFee.toString(),
    "| totalFee:",
    totalFee.toString(),
  );

  // ── Peak-time check ──────────────────────────────────────────────────────
  const now = new Date();
  const currentDay = now.getDay(); // 0=Sunday … 6=Saturday
  const currentTime = `${String(now.getHours()).padStart(2, "0")}:${String(now.getMinutes()).padStart(2, "0")}`;

  const peakTimeMatch = await tx.peakTime.findFirst({
    where: {
      day: currentDay,
      start_time: { lte: currentTime },
      end_time: { gte: currentTime },
      is_active: true,
    },
  });

  const isPeakTime = !!peakTimeMatch;
  let peakTimeSurcharge = Decimal(0);

  console.log(
    "[PEAK]   currentDay:",
    currentDay,
    "| currentTime:",
    currentTime,
    "| peakTimeMatch:",
    peakTimeMatch,
  );

  if (isPeakTime) {
    // Apply surcharge: e.g. 20% of totalFee
    peakTimeSurcharge = totalFee
      .mul(peakTimeRatio)
      .div(100)
      .toDecimalPlaces(0, Prisma.Decimal.ROUND_CEIL);

    // Split the surcharge proportionally between platform and courier
    const platformShare = platformFee.div(totalFee);
    const platformSurcharge = peakTimeSurcharge
      .mul(platformShare)
      .toDecimalPlaces(0, Prisma.Decimal.ROUND_CEIL);
    const courierSurcharge = peakTimeSurcharge.sub(platformSurcharge);

    platformFee = platformFee.add(platformSurcharge);
    courierFee = courierFee.add(courierSurcharge);
    totalFee = platformFee.add(courierFee);

    console.log(
      "[PEAK]   surcharge:",
      peakTimeSurcharge.toString(),
      "| platformSurcharge:",
      platformSurcharge.toString(),
      "| courierSurcharge:",
      courierSurcharge.toString(),
    );
  } else {
    console.log("[PEAK]   No peak time — no surcharge applied");
  }

  console.log(
    "[RESULT] platformFee:",
    platformFee.toString(),
    "| courierFee:",
    courierFee.toString(),
    "| totalFee:",
    totalFee.toString(),
    "| isPeakTime:",
    isPeakTime,
  );
  console.log("===== /computeEstimatedFeeSplit2 =====\n");

  return { courierFee, platformFee, totalFee, isPeakTime, peakTimeSurcharge };
}

export async function adjustOrderEscrowToAmount(
  tx: Prisma.TransactionClient,
  input: {
    orderId: number;
    customerId: number;
    requiredAmount: Prisma.Decimal;
    reason?: string;
  },
) {
  const order = await tx.order.findUnique({
    where: { id: input.orderId },
    select: {
      id: true,
      customer_id: true,
      payment_method: true,
      order_number: true,
    },
  });

  if (!order) throw new HttpError(404, "orders:errors.order_not_found");
  if (order.customer_id !== input.customerId)
    throw new HttpError(403, "orders:errors.forbidden");

  if (order.payment_method !== "WALLET") {
    return {
      ok: true,
      skipped: true,
      message: "Payment method is CASH; no escrow adjustment needed.",
    };
  }

  const wallet = await tx.wallet.findUnique({
    where: { user_id: input.customerId },
    select: { id: true, balance: true, status: true },
  });

  if (!wallet) throw new HttpError(404, "wallet:errors.not_found");
  if (wallet.status !== "ACTIVE")
    throw new HttpError(409, "wallet:errors.wallet_not_active");

  const escrow = await tx.escrow.findFirst({
    where: { order_id: order.id, wallet_id: wallet.id },
    orderBy: { created_at: "desc" },
  });

  if (!escrow) throw new HttpError(500, "orders:errors.escrow_missing");

  const required = Decimal(input.requiredAmount);
  if (required.lt(0)) throw new HttpError(400, "orders:errors.invalid_amount");

  const currentHeld = Decimal(escrow.held_amount);
  const diff = required.sub(currentHeld);
  console.log("diff", diff);

  if (diff.eq(0)) {
    return {
      ok: true,
      skipped: true,
      held_amount: currentHeld,
      diff: Decimal(0),
    };
  }

  const descReason = input.reason ? ` - ${input.reason}` : "";
  const baseDesc = `${order.order_number}${descReason}`;

  if (diff.gt(0)) {
    const addCents = +diff;

    if (wallet.balance < addCents) {
      throw new HttpError(
        400,
        "orders:errors.insufficient_wallet_balance_for_fee",
        undefined,
        { required: addCents, current: wallet.balance },
      );
    }

    await adjustWalletBalance(tx, wallet.id, -addCents, { order_id: order.id });

    const updatedEscrow = await tx.escrow.update({
      where: { id: escrow.id },
      data: { held_amount: required },
    });

    await tx.transaction.create({
      data: {
        wallet_id: wallet.id,
        order_id: order.id,
        escrow_id: escrow.id,
        type: "ESCROW_HOLD",
        status: "COMPLETED",
        amount: diff,
        description: `Increase escrow hold for ${baseDesc}`,
      },
    });

    return { ok: true, held_amount: updatedEscrow.held_amount, diff };
  }

  const refund = diff.abs();
  const refundCents = +refund;

  await adjustWalletBalance(tx, wallet.id, refundCents, { order_id: order.id });

  const updatedEscrow = await tx.escrow.update({
    where: { id: escrow.id },
    data: { held_amount: required },
  });

  await tx.transaction.create({
    data: {
      wallet_id: wallet.id,
      order_id: order.id,
      escrow_id: escrow.id,
      type: "ESCROW_REMOVE",
      status: "COMPLETED",
      amount: refund,
      description: `Decrease escrow hold for ${baseDesc}`,
    },
  });

  return { ok: true, held_amount: updatedEscrow.held_amount, diff };
}

export async function resolveDeliveryAddress(
  tx: Tx,
  customerId: number,
  customerAddressId?: number,
) {
  let address;
  if (customerAddressId) {
    address = await tx.customerAddress.findFirst({
      where: {
        id: customerAddressId,
        deleted_at: null,
      },
      select: {
        area_id: true,
        detailed_address: true,
        address_lat: true,
        address_long: true,
      },
    });
  } else {
    // Fall back to the customer's default address
    address = await tx.customerAddress.findFirst({
      where: {
        customer_id: customerId,
        is_default: true,
        deleted_at: null,
      },
      select: {
        area_id: true,
        detailed_address: true,
        address_lat: true,
        address_long: true,
      },
    });
  }

  if (!address) {
    throw new HttpError(422, "orders:errors.no_default_delivery_address");
  }
  if (!address.area_id) {
    throw new HttpError(422, "orders:errors.default_address_missing_area");
  }
  if (!address.address_lat || !address.address_long) {
    throw new HttpError(
      422,
      "orders:errors.default_address_missing_coordinates",
    );
  }

  return {
    deliveryAreaId: address.area_id,
    deliveryAddressDescription: address.detailed_address,
    deliveryLat: Number(address.address_lat),
    deliveryLong: Number(address.address_long),
  };
}

export async function restoreStockIfCatalog(
  tx: Tx,
  order: Pick<Order, "id" | "type">,
) {
  if (order.type !== "CATALOG_PURCHASE") return;

  const items = await tx.orderItem.findMany({
    where: { order_id: order.id },
    select: { sp_id: true, quantity: true },
  });

  if (!items.length) return;

  await Promise.all(
    items.map((item) =>
      tx.supplierProduct.update({
        where: { id: item.sp_id },
        data: {
          stock: { increment: item.quantity },
        },
      }),
    ),
  );
}
// ─── Deduct stock atomically ──────────────────────────────────────────────────
// Uses a single SQL statement (WHERE stock >= quantity + SET stock = stock - quantity)
// so the check and the decrement are one atomic operation — no race condition possible.

export async function deductStock(
  tx: Tx,
  items: { sp_id: number; quantity: number }[],
) {
  for (const item of items) {
    const result = await tx.supplierProduct.updateMany({
      where: { id: item.sp_id, stock: { gte: item.quantity } },
      data: { stock: { decrement: item.quantity } },
    });
    console.log(result);

    if (result.count === 0) {
      const sp = await tx.supplierProduct.findUnique({
        where: { id: item.sp_id },
        select: { stock: true, product: { select: { name: true } } },
      });
      console.log(sp);
      throw new HttpError(409, "orders:errors.insufficient_stock", undefined, {
        product: sp?.product.name ?? "",
        available: sp?.stock ?? 0,
        requested: item.quantity,
      });
    }
  }
}

export function formatOrderItem(
  item: OrderItem & {
    supplierProduct: Prisma.SupplierProductGetPayload<{
      include: { offers: true; product: true };
    }>;
  },
) {
  const { supplierProduct, ...orderFields } = item;
  const { product, offers, ...spFields } = supplierProduct;

  const activeOffer = offers?.[0] ?? null;
  const pricing = buildSupplierProductPricing(spFields, activeOffer);

  return {
    ...orderFields,
    supplier_product: pricing,
    product: parseProductImages(product),
    line_total: pricing.unit_price * item.quantity,
  };
}

// ─── Order item include ───────────────────────────────────────────────────────

export const orderItemInclude = () =>
  ({
    supplierProduct: {
      include: {
        product: true,
        offers: {
          where: activeOfferWhere(),
          take: 1,
        },
      },
    },
  }) satisfies Prisma.OrderItemInclude;

export type OrderWithItems = Prisma.OrderGetPayload<{
  include: {
    coupon: true;
    orderItems: {
      include: ReturnType<typeof orderItemInclude>;
    };
  };
}>;

export async function getProposalOrThrow(proposalId: number, orderId: number) {
  const proposal = await prisma.orderProposal.findUnique({
    where: { id: proposalId },
  });
  if (proposal?.order_id !== orderId)
    throw new HttpError(404, "orders:errors.proposal_not_found");
  return proposal;
}

export async function rejectProposal(
  proposalId: number,
  meta: {
    orderId: number;
    courierId: number;
    actorId: number;
    isPartner?: boolean;
  },
) {
  const updatedProposal = await prisma.orderProposal.update({
    where: { id: proposalId },
    data: { status: "REJECTED", confirmed_at: new Date() },
  });

  bus.emit("offer.rejected", {
    orderId: meta.orderId,
    offerId: updatedProposal.id,
    courierId: meta.courierId,
    // ...(meta.isPartner
    //   ? { externalAppId: meta.actorId }
    //   : { customerId: meta.actorId }),
    customerId: meta.actorId,
    rejectedAt: new Date().toISOString(),
  });

  return updatedProposal;
}

export function assertOrderAcceptable(order: {
  status: string;
  type: string;
  expires_at: Date | null;
}) {
  if (order.status !== "PENDING")
    throw new HttpError(409, "orders:errors.order_not_open_for_accept");
  if (order.type !== "CUSTOM_PICKUP")
    throw new HttpError(400, "orders:errors.invalid_order_type_for_proposal");
  if (order.expires_at && order.expires_at < new Date())
    throw new HttpError(409, "orders:errors.order_expired");
}

// Shared transaction steps — rejectOthers always runs on accept
export async function rejectOtherProposals(
  tx: Prisma.TransactionClient,
  orderId: number,
  acceptedProposalId: number,
) {
  await tx.orderProposal.updateMany({
    where: {
      order_id: orderId,
      id: { not: acceptedProposalId },
      status: "PENDING",
    },
    data: { status: "REJECTED" },
  });
}

export async function getOrderOrThrow<T extends Prisma.OrderInclude>(
  orderId: number,
  include?: T,
) {
  const order = await prisma.order.findUnique({
    where: { id: orderId },
    include,
  });

  if (!order) {
    throw new HttpError(404, "orders:errors.order_not_found");
  }

  // We cast to OrderGetPayload using the generic T
  return order as Prisma.OrderGetPayload<{ include: T }>;
}
