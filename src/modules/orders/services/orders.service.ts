import { bus } from "@/events/bus";
import { getRoadDistanceM } from "@/lib/distance";
import FeatureApi from "@/lib/featureApi";
import { HttpError } from "@/lib/httpError";
import { generateOtp } from "@/lib/otp";
import { prisma } from "@/config/prisma";
import { adjustWalletBalance } from "@/lib/adjustWalletBalance";
import { uploadSingleFile } from "@/lib/cloudinary/cloudinary.service";
import { selectVehiclesForDistance } from "@/lib/vehicle-selector";
import { CouponScope, PartnerFeeSplit, Prisma, User } from "@prisma/client";
import { calculateOrderDiscountCents } from "../../customer-coupons/customer-coupons.service";
import {
  adjustOrderEscrowToAmount,
  applyWalletCouponReward,
  assertOrderAcceptable,
  calculateSharedFeeLogic,
  computeEstimatedFeeSplit,
  computeOrderFeeSplit,
  deductStock,
  formatOrderItem,
  genOrderNumber,
  getOrderOrThrow,
  getProposalOrThrow,
  orderItemInclude,
  OrderWithItems,
  recalculateOrderCouponForOrder,
  rejectOtherProposals,
  rejectProposal,
  restoreStockIfCatalog,
  roundTo100,
  sumOrderAmount,
  validateOrderCouponForCreate,
} from "../order.utils";
import type {
  CancelOrderInput,
  ConfirmDeliveryInput,
  CreateOrderInput,
  CreateOrderIssueInput,
  ProposalDecisionInput,
} from "../orders.schema";
import {
  adjustPartnerOrderEscrow,
  computePartnerSplitFromCourierBudget,
} from "./orders.partner.service";
import { Decimal } from "@prisma/client/runtime/client";
import { RawProposalRow } from "@/types/orders";
import { logger } from "@/config/logger";
import {
  executeCardRefund,
  executeCardVoid,
  getCardPaymentTransaction,
} from "@/lib/cardRefund";

export async function createOrderService(
  input: CreateOrderInput,
  customerId: number,
  file?: Express.Multer.File,
) {
  // step: check if phone not veirefied throw error
  const userPhoneCheck = await prisma.user.findUnique({
    where: { id: customerId },
    select: { is_phone_verified: true },
  });
  if (!userPhoneCheck?.is_phone_verified) {
    throw new HttpError(
      403,
      "auth:errors.account_not_verified",
      "PHONE_NOT_VERIFIED",
    );
  }

  // step: check if type is CUSTOM_PICKUP or CATALOG_PURCHASE
  if (input.type !== "CUSTOM_PICKUP")
    throw new HttpError(400, "orders:errors.wrongServices");

  // step: get user
  const user = await prisma.user.findUnique({
    where: { id: customerId },
    select: { role: true },
  });
  if (!user) {
    if (!user) throw new HttpError(404, "auth:errors.user_not_found");
  }

  // Fee deducted from the supplier's shopping budget and re-allocated to the
  // platform fee. Stays 0 for non-supplier roles.
  let supplierBudgetFeeCents = 0;

  if (user.role.name == "Customer") {
    // step: check customer budget range
    const appSettings = await prisma.applicationSetting.findFirst({
      select: {
        customer_shopping_min_price_for_one_order: true,
        customer_shopping_max_price_for_one_order: true,
      },
    });
    const minBudget = Number(
      appSettings?.customer_shopping_min_price_for_one_order ?? 5000,
    );
    const maxBudget = Number(
      appSettings?.customer_shopping_max_price_for_one_order ?? 100000,
    );
    if (input.budget < minBudget || input.budget > maxBudget) {
      throw new HttpError(
        400,
        "orders:errors.budget_out_of_range",
        "BUDGET_OUT_OF_RANGE",
        { min: minBudget / 100, max: maxBudget / 100 },
      );
    }
  } else if (user.role.name == "Supplier") {
    // step: check supplier budget range
    const supplier = await prisma.supplier.findFirst({
      where: { user_id: customerId },
      select: {
        shopping_min_price_for_one_order: true,
        shopping_max_price_for_one_order: true,
        shopping_budget_fee: true,
      },
    });

    // step: check supplier budget range (against the passed/gross budget)
    const minBudget = Number(
      supplier?.shopping_min_price_for_one_order ?? 5000,
    );
    const maxBudget = Number(
      supplier?.shopping_max_price_for_one_order ?? 100000,
    );
    if (input.budget < minBudget || input.budget > maxBudget) {
      throw new HttpError(
        400,
        "orders:errors.budget_out_of_range",
        "BUDGET_OUT_OF_RANGE",
        { min: minBudget / 100, max: maxBudget / 100 },
      );
    }

    // step: extract shopping_budget_fee
    // shopping_budget_fee is a percentage (e.g. 5 => 5%). The frontend adds the
    // fee on top of the supplier's entered shopping budget, so input.budget
    // arrives as enteredBudget * (1 + ratio). Divide it back out to recover the
    // entered shopping budget and the fee, then route the fee to the platform
    // fee inside the transaction below.
    const budgetFeeRatio = Number(supplier?.shopping_budget_fee ?? 0) / 100;
    if (budgetFeeRatio > 0) {
      const shoppingBudget = Math.round(input.budget / (1 + budgetFeeRatio));
      // [SUPPLIER_BUDGET_FEE] set here, consumed inside the $transaction below
      // (search "[SUPPLIER_BUDGET_FEE]") where it is added to the platform fee.
      supplierBudgetFeeCents = input.budget - shoppingBudget;
      input.budget = shoppingBudget;
    }
  }

  const [pickupArea, deliveryArea, settings] = await Promise.all([
    prisma.area.findUnique({
      where: { id: input.pickup_area_id },
      select: { id: true, is_active: true },
    }),
    prisma.area.findUnique({
      where: { id: input.delivery_area_id },
      select: { id: true, is_active: true },
    }),
    prisma.applicationSetting.findFirst({
      select: {
        proposal_waiting_time_minutes: true,
        order_expiration_time_minutes: true,
        vat: true,
        min_platform_fee: true,
      },
    }),
  ]);

  // step: check if pickup or delivery area is active
  if (!pickupArea?.is_active)
    throw new HttpError(400, "orders:errors.pickup_area_not_found");
  if (!deliveryArea?.is_active)
    throw new HttpError(400, "orders:errors.delivery_area_not_found");

  // step: collect data
  const proposalMinutes = settings?.proposal_waiting_time_minutes ?? 5;
  const expirationMinutes = settings?.order_expiration_time_minutes ?? 15;
  const now = new Date();
  // TODO: For scheduled orders, deadlines start from the scheduled time
  const baseTime =
    input.is_order_scheduled && input.order_schedule_at
      ? new Date(input.order_schedule_at)
      : now;
  const proposalsDeadline = new Date(
    baseTime.getTime() + proposalMinutes * 60_000,
  );
  const expiresAt = new Date(baseTime.getTime() + expirationMinutes * 60_000);

  const distanceM = await getRoadDistanceM(
    { lat: +input.pickup_lat, lng: +input.pickup_long },
    { lat: +input.delivery_lat, lng: +input.delivery_long },
  );

  const vehicles = await selectVehiclesForDistance(distanceM.distance);

  let product_image = input.product_image ?? null;
  if (file) {
    const { secure_url } = await uploadSingleFile({
      fileLocation: file.path, // .path or .buffer
      storagePathOnCloudinary: "orders",
    });
    product_image = secure_url;
  }

  // step: async transactions
  const order = await prisma.$transaction(async (tx) => {
    // step: collect data
    const estimatedFee = await computeEstimatedFeeSplit(tx, {
      distanceM: distanceM.distance,
      vehicleId: vehicles[0].id,
      vehicle: vehicles[0],
      vatRate: Decimal(settings?.vat ?? 0).div(100),
      minPlatformFee: Decimal(settings?.min_platform_fee ?? 0),
    });

    // step: re-allocate the supplier shopping budget fee to the platform fee.
    // [SUPPLIER_BUDGET_FEE] supplierBudgetFeeCents is set only in the Supplier
    // branch above (search "[SUPPLIER_BUDGET_FEE]"); it lives here, not there,
    // because estimatedFee.platformFee is computed inside this transaction.
    // The budget was already reduced by this amount above, so adding it here to
    // both the platform fee and the total keeps the supplier's payable total
    // unchanged while routing the fee to the platform.
    if (supplierBudgetFeeCents > 0) {
      const budgetFeeDec = new Decimal(supplierBudgetFeeCents);
      estimatedFee.platformFee = estimatedFee.platformFee.add(budgetFeeDec);
      estimatedFee.totalFeeWithVat =
        estimatedFee.totalFeeWithVat.add(budgetFeeDec);
    }

    let wallet: { id: number; balance: number; status: string } | null = null;

    let appliedCoupon: {
      couponId: number;
      type: "ORDER_DISCOUNT" | "WALLET_CREDIT";
      discountCents: number;
      payableCents: number;
    } | null = null;

    // step: check if there is a coupon
    if (input.coupon_code?.trim()) {
      appliedCoupon = await validateOrderCouponForCreate(tx, {
        userId: customerId,
        code: input.coupon_code,
        budgetCents: input.budget,
        estimatedDeliveryFeeCents: estimatedFee.courierFee.toNumber(),
        orderType: "CUSTOM_PICKUP",
      });
    }

    const holdCents =
      appliedCoupon !== null && appliedCoupon !== undefined
        ? appliedCoupon.payableCents + estimatedFee.platformFee.toNumber()
        : input.budget + estimatedFee.totalFeeWithVat.toNumber();

    // step: check if payment method is WALLET
    if (input.payment_method === "WALLET") {
      wallet = await tx.wallet.findUnique({
        where: { user_id: customerId },
        select: { id: true, balance: true, status: true },
      });

      if (!wallet) throw new HttpError(404, "wallet:errors.not_found");
      if (wallet.status !== "ACTIVE")
        throw new HttpError(409, "wallet:errors.wallet_not_active");
      if (wallet.balance < holdCents)
        throw new HttpError(
          400,
          "orders:errors.insufficient_wallet_balance",
          undefined,
          {
            required: holdCents,
            current: wallet.balance,
          },
        );

      await adjustWalletBalance(tx, wallet.id, -holdCents, {
        customer_coupon_id: appliedCoupon?.couponId,
      });
    }

    const order = await tx.order.create({
      data: {
        customer_id: customerId,
        order_number: genOrderNumber(),
        product_description: input.product_description,
        product_image,
        budget: input.budget,
        courier_fee: estimatedFee.courierFee,
        platform_fee: estimatedFee.platformFee,
        vat_amount: estimatedFee.vatAmount,
        total_fee: estimatedFee.totalFeeWithVat,
        // [REVIEW][SUPPLIER_BUDGET_FEE_FIX] persist the supplier budget fee (cents)
        // so proposal-accept / price-adjustment can re-apply it instead of dropping it.
        supplier_budget_fee: supplierBudgetFeeCents,
        payment_method: input.payment_method,
        coupon_id: appliedCoupon?.couponId,
        discount_amount: appliedCoupon?.discountCents ?? 0,
        payable_amount: holdCents,
        pickup_area_id: input.pickup_area_id,
        pickup_address_description: input.pickup_address_description,
        pickup_lat: input.pickup_lat ?? null,
        pickup_long: input.pickup_long ?? null,
        delivery_area_id: input.delivery_area_id,
        delivery_address_description: input.delivery_address_description,
        delivery_lat: input.delivery_lat ?? null,
        delivery_long: input.delivery_long ?? null,
        estemated_delivery_fee: estimatedFee.totalFeeWithVat,
        distance_m: distanceM.distance,
        // TODO: order delivery date and time
        status: input.is_order_scheduled ? "SCHEDULED" : "PENDING",
        proposals_deadline_at: proposalsDeadline,
        expires_at: expiresAt,
        is_fixed_fee: false,
        confirmation_otp: generateOtp(4),
        // TODO: order delivery date and time
        is_order_scheduled: input.is_order_scheduled,
        order_schedule_at: input.order_schedule_at,
      },
    });

    // Reserve the coupon slot immediately to enforce usage limits
    if (appliedCoupon) {
      await tx.customerCouponUsage.create({
        data: {
          user_id: customerId,
          coupon_id: appliedCoupon.couponId,
          context: appliedCoupon.type === "WALLET_CREDIT" ? "WALLET" : "ORDER",
          order_id: order.id,
          discount_cents: appliedCoupon.discountCents, // 0 for DELIVERY_FEE scope, real value otherwise
        },
      });
    }

    if (input.payment_method === "WALLET" && wallet) {
      const escrow = await tx.escrow.create({
        data: {
          order_id: order.id,
          wallet_id: wallet.id,
          held_amount: holdCents,
        },
      });

      await tx.transaction.create({
        data: {
          wallet_id: wallet.id,
          order_id: order.id,
          escrow_id: escrow.id,
          type: "ESCROW_HOLD",
          status: "COMPLETED",
          amount: holdCents,
          description: `Hold for order ${order.order_number}`,
        },
      });
    }

    return order;
  });

  bus.emit("order.created", {
    orderId: order.id,
    deliveryAreaId: order.delivery_area_id!,
    createdAt: new Date().toISOString(),
    customerId: order.customer_id!,
    budget: +order.budget!,
    pickupAreaId: order.pickup_area_id!,
    vehicleIds: vehicles.map((v) => v.id),
    distanceM: distanceM.distance,
    proposalsDeadline: proposalsDeadline.toISOString(),
    expiresAt: expiresAt.toISOString(),
    type: "CUSTOM_PICKUP",
    pickupLat: +order.pickup_lat!,
    pickupLng: +order.pickup_long!,
  });

  return order;
}

export async function listOrdersService(data: FeatureApi["data"]) {
  const take = data.take ?? 10;

  const baseArgs = {
    where: data.where,
    orderBy: data.orderBy,
    skip: data.skip,
    take: data.take,
  } satisfies Omit<Prisma.OrderFindManyArgs, "select" | "include">;

  let queryOptions: Prisma.OrderFindManyArgs;

  const hasCouponInSelect = !!data.select?.coupon || !!data.include?.coupon;
  if (data.select) {
    queryOptions = {
      ...baseArgs,
      select: {
        ...data.select,
        orderItems: {
          select: orderItemInclude(),
        },
        ...(hasCouponInSelect
          ? {}
          : {
              coupon: {
                select: {
                  scope: true,
                },
              },
            }),
      },
    };
  } else {
    queryOptions = {
      ...baseArgs,
      include: {
        ...(data.include ?? []),
        orderItems: {
          include: orderItemInclude(),
        },
        ...(hasCouponInSelect
          ? {}
          : {
              coupon: {
                select: {
                  scope: true,
                },
              },
            }),
      },
    };
  }

  const [totalOrders, rawOrders] = await prisma.$transaction([
    prisma.order.count({ where: data.where }),
    prisma.order.findMany(queryOptions),
  ]);
  const orders = rawOrders.map((order) => {
    const { orderItems, coupon, ...orderFields } = order as OrderWithItems;

    return {
      ...orderFields,
      coupon_type: coupon?.scope || null,
      orderItems: (orderItems ?? []).map(formatOrderItem),
      ...(hasCouponInSelect ? { coupon } : []),
    };
  });

  return {
    totalOrders,
    totalPages: Math.ceil(totalOrders / take),
    orders,
  };
}

export async function getOrderByIdService(
  orderId: number,
  viewerUserId?: number,
  external_app_id?: number,
) {
  const order = await prisma.order.findUnique({
    where: { id: orderId },
    include: {
      courier: {
        select: {
          user: {
            select: {
              full_name: true,
              phone: true,
              personal_photo: true,
              id: true,
            },
          },
        },
      },
      orderItems: {
        where: { order_id: orderId },
        include: orderItemInclude(),
      },
      proposals: true,
      coupon: {
        select: {
          scope: true,
        },
      },
      pickup_area: { select: { id: true, name: true } },
      delivery_area: { select: { id: true, name: true } },
    },
  });

  if (!order) throw new HttpError(404, "orders:errors.order_not_found");
  if (
    order.customer_id !== viewerUserId &&
    order.external_app_id !== external_app_id
  )
    throw new HttpError(403, "orders:errors.forbidden");

  const { orderItems, coupon, ...orderFields } = order;

  // For CARD orders awaiting payment, re-serve the checkout link so the
  // customer can resume payment without re-initiating the gateway.
  let checkout_url: string | null = null;
  if (order.payment_method === "CARD" && order.status === "PENDING_PAYMENT") {
    const pendingTx = await prisma.transaction.findFirst({
      where: { order_id: order.id, type: "ORDER_PAYMENT", status: "PENDING" },
      orderBy: { created_at: "desc" },
      select: { checkout_url: true },
    });
    checkout_url = pendingTx?.checkout_url ?? null;
  }

  return {
    ...orderFields,
    coupon_type: coupon?.scope || null,
    orderItems: orderItems.map(formatOrderItem),
    ...(checkout_url ? { checkout_url } : {}),
  };
}

export async function listOrderProposalsService(
  orderId: number,
  customerId?: number,
  externalAppId?: number,
) {
  const now = new Date();
  const [order, settings, peakTimeMatch] = await Promise.all([
    getOrderOrThrow(orderId, {
      coupon: true,
    }),
    prisma.applicationSetting.findFirst({
      select: { vat: true, min_platform_fee: true },
    }),
    externalAppId
      ? prisma.peakTime.findFirst({
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
        })
      : null,
  ]);

  if (!order) throw new HttpError(404, "orders:errors.not_found");

  const isOwner = customerId && order.customer_id === customerId;
  const isAppOwner = externalAppId && order.external_app_id === externalAppId;
  if (!isOwner && !isAppOwner) throw new HttpError(403, "forbidden");

  const vatRate = Decimal(settings?.vat ?? 0).div(100);
  const minPlatformFee = Decimal(settings?.min_platform_fee ?? 0);

  const rawProposals = await prisma.$queryRaw<RawProposalRow[]>`
    SELECT 
      p.*,
      u.id as user_id, u.full_name, u.phone, u.personal_photo, u.badge_id,
      c.vehicle_plate,
      v.id as v_id, v.name as v_name, v.name_ar as v_name_ar, 
      v.price_per_km as v_price_per_km, v.icon as v_icon,
      v.fee_base_distance_km as v_fee_base_distance_km,
      v.fee_extra_platform_per_km as v_fee_extra_platform_per_km,
      v.fee_extra_courier_per_km as v_fee_extra_courier_per_km,
      v.peak_time_fee_ratio as v_peak_time_fee_ratio,
      v.min_delivery_fee as v_min_delivery_fee, -- Added this to get Motorcycle's min fee
      ub.ratio as badge_ratio,
      (
        SELECT snapshot_bonus_courier_fee 
        FROM courier_coupon_usage 
        WHERE user_id = u.id AND start_date <= ${now} AND end_date >= ${now}
        ORDER BY created_at DESC LIMIT 1
      ) as courier_active_bonus_percent,
      COALESCE((SELECT AVG(rating) FROM courier_review_from_customer WHERE courier_id = c.id), 0) as avg_rating,
      (SELECT COUNT(*) FROM courier_review_from_customer WHERE courier_id = c.id) as review_count
    FROM order_proposal p
    JOIN courier c ON p.courier_id = c.id
    JOIN user u ON c.user_id = u.id
    LEFT JOIN vehicle v ON c.vehicle_id = v.id -- 👈 CHANGED: Use c.vehicle_id (Current Courier Vehicle)
    LEFT JOIN user_badge ub ON u.badge_id = ub.id
    WHERE p.order_id = ${orderId}
    ORDER BY p.created_at DESC
`;

  // ─── Batch Fetch Partner Splits ─────────────────────────────────────────────
  let partnerSplits: PartnerFeeSplit[] = [];
  if (order.external_app_id && order.contract_vehicle_id) {
    partnerSplits = await prisma.partnerFeeSplit.findMany({
      where: {
        contract_vehicle_id: order.contract_vehicle_id,
        badge_id: {
          in: rawProposals.map((r) => r.badge_id).filter(Boolean) as number[],
        },
      },
    });
  }

  const proposals = await Promise.all(
    rawProposals.map(async (row) => {
      const totalFeeInput = Decimal(Number(row.total_fee));
      // Determine which split logic to use
      const feeData = order.external_app_id
        ? computePartnerSplitFromCourierBudget(
            totalFeeInput,
            row,
            partnerSplits,
            vatRate,
            !!peakTimeMatch, // Pass whether peak time was found
          )
        : await computeOrderFeeSplit(prisma, {
            courierId: row.courier_id!,
            courierBid: row.total_fee,
            distanceM: +order.distance_m!,
            vatRate,
            minPlatformFee,
            preFetched: {
              badgeRatio: row.badge_ratio ?? 30,
              couponBonusPercent: row.courier_active_bonus_percent,
              vehicle: {
                min_delivery_fee: row.v_min_delivery_fee,
                fee_base_distance_km: row.v_fee_base_distance_km,
                fee_extra_platform_per_km: row.v_fee_extra_platform_per_km,
                fee_extra_courier_per_km: row.v_fee_extra_courier_per_km,
                peak_time_fee_ratio: row.v_peak_time_fee_ratio,
              },
            },
          });

      // Coupon Calculation
      let discountCents = 0;
      if (order.coupon && !order.external_app_id) {
        // Usually partners don't use consumer coupons
        discountCents = calculateOrderDiscountCents(
          order.coupon,
          Number(order.budget),
          feeData.courierFee.toNumber(),
        );
      }

      const payableCents =
        Number(order.budget) + +feeData.totalFeeWithVat - discountCents;

      return {
        id: row.id,
        order_id: row.order_id,
        courier_id: row.courier_id,
        vehicle_id: row.vehicle_id,
        total_fee: feeData.totalFeeWithVat,
        total_fee_without_vat: feeData.totalFeeWithVat.sub(feeData.vatAmount),
        courier_fee: feeData.courierFee.toNumber(),
        platform_fee: feeData.platformFee.toNumber(),
        // partner_fee: feeData.partner_fee?.toNumber() ?? 0,
        vat_amount: feeData.vatAmount.toNumber(),
        discount_amount: discountCents,
        payable_amount: payableCents,

        status: row.status,
        courier_lat: row.courier_lat,
        courier_long: row.courier_long,
        distance_to_pickup: row.distance_to_pickup,
        estimated_arrival_at_pickup: row.estimated_arrival_at_pickup,
        created_at: row.created_at,
        confirmed_at: row.confirmed_at,

        courier: {
          id: row.courier_id,
          vehicle_plate: row.vehicle_plate,
          avg_rating: Number.parseFloat(Number(row.avg_rating).toFixed(1)),
          _count: { customerReviews: Number(row.review_count) },
          user: {
            id: row.user_id,
            full_name: row.full_name,
            phone: row.phone,
            personal_photo: row.personal_photo,
          },
        },

        vehicle: row.v_id
          ? {
              id: row.v_id,
              name: row.v_name,
              name_ar: row.v_name_ar,
              price_per_km: row.v_price_per_km,
              icon: row.v_icon,
            }
          : null,
      };
    }),
  );
  return proposals;
}

export async function cancelOrderService(
  orderId: number,
  input: CancelOrderInput,
  customerId?: number,
  externalAppId?: number,
) {
  const order = await getOrderOrThrow(orderId);
  const isPartnerOrder = order.external_app_id !== null;

  // ── Ownership ──────────────────────────────────────────────────────────────
  if (isPartnerOrder && order.external_app_id !== externalAppId)
    throw new HttpError(403, "orders:errors.forbidden");

  if (!isPartnerOrder && order.customer_id !== customerId)
    throw new HttpError(403, "orders:errors.forbidden");

  if (order.status === "DELIVERED")
    throw new HttpError(409, "orders:errors.cannot_cancel_delivered");
  if (order.status === "CANCELLED")
    throw new HttpError(409, "orders:errors.already_cancelled");

  const applyFee = order.status === "IN_PROGRESS";

  const cancelledOrder = await prisma.$transaction(async (tx) => {
    const settings = await tx.applicationSetting.findUnique({
      where: { id: 1 },
      select: {
        cancellation_fee_ratio: true,
        courier_cancellation_fee_ratio: true,
      },
    });

    // ── Coupon slot release (customer orders only) ─────────────────────────
    if (!isPartnerOrder && order.coupon_id) {
      await tx.customerCouponUsage.deleteMany({
        where: {
          order_id: orderId,
          coupon_id: order.coupon_id,
          context: "ORDER",
        },
      });
    }

    // ── Stock restore (CATALOG_PURCHASE only) ─────────────────────────────
    await restoreStockIfCatalog(tx, order);

    // ── Cancellation fee ──────────────────────────────────────────────────
    const cancelRatioPercent = settings?.cancellation_fee_ratio ?? 0;
    const courierSharePercent = settings?.courier_cancellation_fee_ratio ?? 0;

    const base = sumOrderAmount({
      totalFee: order.total_fee ?? Decimal(0),
      actualPrice: order.actual_price ?? Decimal(0),
    });

    let cancellation_fee = Decimal(0);
    let courier_fee = Decimal(0);
    let platform_fee = Decimal(0);

    if (applyFee) {
      const cancelRatio = Decimal(cancelRatioPercent).div(100);
      cancellation_fee = base.mul(cancelRatio);
      const courierRatio = Decimal(courierSharePercent).div(100);
      courier_fee = cancellation_fee.mul(courierRatio);
      platform_fee = cancellation_fee.sub(courier_fee);
    }

    // ── Wallet refund ─────────────────────────────────────────────────────
    if (order.payment_method === "WALLET") {
      // Find the correct wallet — partner wallet or customer wallet
      const wallet = isPartnerOrder
        ? await tx.wallet.findUnique({
            where: { external_app_id: order.external_app_id! },
            select: { id: true },
          })
        : await tx.wallet.findUnique({
            where: { user_id: customerId },
            select: { id: true },
          });

      if (!wallet) throw new HttpError(404, "wallet:errors.not_found");

      const escrow = await tx.escrow.findFirst({
        where: { order_id: orderId, wallet_id: wallet.id },
        orderBy: { created_at: "desc" },
      });
      if (!escrow) throw new HttpError(500, "orders:errors.escrow_missing");

      const held = Decimal(escrow.held_amount);
      const fee = Decimal(cancellation_fee);
      const refund = held.sub(fee);
      const refundSafe = refund.gt(0) ? refund : Decimal(0);

      if (refundSafe.gt(0)) {
        await adjustWalletBalance(tx, wallet.id, +refundSafe, {
          order_id: orderId,
        });
        await tx.transaction.create({
          data: {
            wallet_id: wallet.id,
            order_id: orderId,
            escrow_id: escrow.id,
            type: "ESCROW_REMOVE",
            amount: refundSafe,
            status: "COMPLETED",
            description: `Refund after cancellation for ${order.order_number}`,
          },
        });
      }

      if (fee.gt(0)) {
        // Penalty recorded against the cancelling party
        const penaltyUserId = isPartnerOrder
          ? null // partner penalty tracked differently — just record fee
          : customerId!;

        if (!isPartnerOrder) {
          await tx.penalty.create({
            data: {
              user_id: penaltyUserId!,
              amount: fee,
              reason: "Order cancellation fee",
              is_paid: true,
              paid_at: new Date(),
            },
          });
        }

        await tx.transaction.create({
          data: {
            wallet_id: wallet.id,
            order_id: orderId,
            escrow_id: escrow.id,
            type: "PENALTY",
            amount: fee,
            status: "COMPLETED",
            description: `Cancellation penalty for ${order.order_number}`,
          },
        });
      }

      await tx.escrow.update({
        where: { id: escrow.id },
        data: { held_amount: Decimal(0) },
      });
    }

    // ── Card refund fee bookkeeping ─────────────────────────────────────────
    // The actual void/refund call to the gateway happens after the transaction
    // commits (external API calls must not run inside a DB transaction). Here
    // we just record the cancellation fee as a penalty, mirroring the wallet
    // branch — it reduces the amount refunded to the customer below.
    if (order.payment_method === "CARD" && !isPartnerOrder) {
      const fee = Decimal(cancellation_fee);
      if (fee.gt(0)) {
        await tx.penalty.create({
          data: {
            user_id: customerId!,
            amount: fee,
            reason: "Order cancellation fee",
            is_paid: true,
            paid_at: new Date(),
          },
        });
      }
    }

    return tx.order.update({
      where: { id: orderId },
      data: {
        status: "CANCELLED",
        cancelled_by: isPartnerOrder ? null : customerId,
        canceled_at: new Date(),
        cancellation_fee,
        courier_fee,
        platform_fee,
        ...input,
      },
      select: {
        id: true,
        customer_id: true,
        external_app_id: true,
        courier_id: true,
        supplier_id: true,
        pickup_area_id: true,
        type: true,
        order_number: true,
        payment_method: true,
        payable_amount: true,
        cancellation_fee: true,
      },
    });
  });

  bus.emit("order.cancelled", {
    orderId: cancelledOrder.id,
    customerId: cancelledOrder.customer_id ?? undefined,
    externalAppId: cancelledOrder.external_app_id ?? undefined,
    courierId: cancelledOrder.courier_id,
    pickupAreaId: cancelledOrder.pickup_area_id!,
    cancelledAt: new Date().toISOString(),
    type: cancelledOrder.type,
    supplierId: cancelledOrder.supplier_id ?? undefined,
  });

  // ── Card refund/void ───────────────────────────────────────────────────────
  // Runs after the DB transaction commits since it calls out to the payment
  // gateway. A failure here is logged but doesn't block the cancellation —
  // admins can process the refund manually via the refunds module.
  if (cancelledOrder.payment_method === "CARD") {
    const payableCents = Math.round(Number(cancelledOrder.payable_amount ?? 0));
    const feeCents = Math.round(Number(cancelledOrder.cancellation_fee ?? 0));
    const refundCents = Math.max(0, payableCents - feeCents);

    if (payableCents > 0 && refundCents > 0) {
      try {
        const paymentTx = await getCardPaymentTransaction(orderId);
        const withinVoidWindow =
          !!paymentTx &&
          Date.now() - paymentTx.created_at.getTime() <= 24 * 60 * 60 * 1000;

        const reason = `Order ${cancelledOrder.order_number} cancelled`;
        const isFullRefund = refundCents === payableCents;

        const result =
          withinVoidWindow && isFullRefund
            ? await executeCardVoid(orderId, reason)
            : await executeCardRefund(orderId, refundCents, reason);

        const wallet = cancelledOrder.external_app_id
          ? await prisma.wallet.findUnique({
              where: { external_app_id: cancelledOrder.external_app_id },
              select: { id: true },
            })
          : cancelledOrder.customer_id
            ? await prisma.wallet.findUnique({
                where: { user_id: cancelledOrder.customer_id },
                select: { id: true },
              })
            : null;

        await prisma.$transaction([
          prisma.order.update({
            where: { id: orderId },
            data: {
              refund_status: isFullRefund
                ? "FULLY_REFUNDED"
                : "PARTIALLY_REFUNDED",
            },
          }),
          prisma.transaction.create({
            data: {
              order_id: orderId,
              wallet_id: wallet?.id,
              type: "REFUND",
              status: "COMPLETED",
              amount: Decimal(refundCents),
              description: `${"voidId" in result ? "Void" : "Refund"} after cancellation for ${cancelledOrder.order_number}`,
            },
          }),
        ]);
      } catch (err) {
        logger.error(
          { orderId, err: (err as Error)?.message },
          "[CancelOrder] Card refund/void failed — requires manual processing",
        );
      }
    }
  }

  return cancelledOrder;
}

// ============================ confirmDeliveryService ============================
export async function confirmDeliveryService(
  input: ConfirmDeliveryInput,
  userId: number,
  role: string,
) {
  const [order, settings] = await Promise.all([
    getOrderOrThrow(input.order_id),
    prisma.applicationSetting.findFirst({
      select: { vat: true, min_platform_fee: true },
    }),
  ]);
  const courierId = order.courier_id;
  const totalFee = order.total_fee;
  const isPartnerOrder = order.external_app_id !== null;
  const vatRate = Decimal(settings?.vat ?? 0).div(100);
  const minPlatformFee = Decimal(settings?.min_platform_fee ?? 0);

  // ── Ownership ─────────────────────────────────────────────────────────────
  let isCourier = false;

  // ✅ Only fetch courier if role is courier
  if (role === "Courier") {
    const courier = await prisma.courier.findUnique({
      where: { user_id: userId },
      select: { id: true },
    });
    if (courier?.id === order.courier_id) isCourier = true;
  }

  // Partner orders have no customer — courier is the only valid confirmed
  const isCustomer = !isPartnerOrder && order.customer_id === userId;

  if (!isCustomer && !isCourier)
    throw new HttpError(403, "orders:errors.forbidden");
  if (order.status === "DELIVERED")
    throw new HttpError(409, "orders:errors.already_delivered");
  if (order.status !== "IN_PROGRESS")
    throw new HttpError(409, "orders:errors.order_not_in_progress");
  if (!courierId || courierId !== input.courier_id)
    throw new HttpError(409, "orders:errors.courier_mismatch");
  if (!totalFee) throw new HttpError(400, "orders:errors.total_fee_missing");

  return prisma.$transaction(async (tx) => {
    // actual_price is set by the courier during delivery (price adjustment flow).
    // For CATALOG_PURCHASE there is no price adjustment — products_total is final.
    const actualPrice = Decimal(
      order.actual_price ?? order.budget ?? order.products_total ?? 0,
    );

    // ── Fee split ─────────────────────────────────────────────────────────
    // Partner: fees finalized at courier accept — trust stored values.
    // CATALOG_PURCHASE: no bidding, compute now.
    // CUSTOM_PICKUP (customer): already set at proposal-accept.
    let courierFee: Prisma.Decimal;
    let platformFee: Prisma.Decimal;
    let vatAmount: Prisma.Decimal;

    if (!order.courier_fee || !order.platform_fee) {
      console.log(
        "recalculate fees | Fees missing or catalog purchase detected",
      );

      const feeSplit = await computeOrderFeeSplit(tx, {
        courierId: order.courier_id!,
        distanceM: +order.distance_m!,
        vatRate,
        minPlatformFee,
      });

      console.log("feeSplit:", feeSplit);
      courierFee = Decimal(feeSplit.courierFee);

      // Keep your product markup addition logic intact
      platformFee = Decimal(
        feeSplit.platformFee.add(
          (order?.products_total ?? Decimal(0)).sub(
            order?.total_cost_price ?? Decimal(0),
          ),
        ),
      );
      vatAmount = Decimal(feeSplit.vatAmount);
      console.log("fees:", { courierFee, platformFee, vatAmount });
    } else {
      // Pulls directly from order if it's a partner order OR already has valid fees
      console.log("Using existing fees from order payload");
      courierFee = Decimal(order.courier_fee ?? 0);
      platformFee = Decimal(order.platform_fee ?? 0);
      vatAmount = Decimal(order.vat_amount ?? 0);
    }

    // ── Coupon recalculation ──────────────────────────────────────────────
    // Partner: no coupons — use stored payable_amount.
    // CUSTOM_PICKUP: recalculate with real fee (DELIVERY_FEE scope deferred).
    // CATALOG_PURCHASE: finalized at checkout — use stored values.
    let couponPricing: {
      discountCents: number;
      payableCents: number;
      scope?: CouponScope;
    };

    if (isPartnerOrder) {
      couponPricing = {
        discountCents: 0,
        payableCents: order.payable_amount?.toNumber() ?? totalFee.toNumber(),
      };
    } else if (order.type === "CUSTOM_PICKUP") {
      couponPricing = await recalculateOrderCouponForOrder(tx, {
        orderId: order.id,
        budgetCents: actualPrice.toNumber() + platformFee.toNumber(),
        totalFeeCents: totalFee.toNumber() - platformFee.toNumber(),
        updateOrder: false,
      });

      if (order.coupon_id) {
        await applyWalletCouponReward(tx, {
          ...order,
          totalAmount: couponPricing.payableCents,
        });
      }
    } else {
      couponPricing = {
        discountCents: order.discount_amount?.toNumber() ?? 0,
        payableCents: order.payable_amount?.toNumber() ?? 0,
      };
    }
    console.log("couponPricing:", couponPricing);

    const updatedOrder = await tx.order.update({
      where: { id: order.id },
      data: {
        status: "DELIVERED",
        delivered_at: new Date(),
        actual_price: actualPrice,
        courier_fee: courierFee,
        platform_fee: platformFee,
        vat_amount: vatAmount,
        discount_amount: couponPricing.discountCents,
        payable_amount: couponPricing.payableCents,
      },
      select: {
        id: true,
        customer_id: true,
        external_app_id: true,
        order_number: true,
        delivered_at: true,
        payment_method: true,
        payable_amount: true,
        actual_price: true,
        type: true,
        supplier_id: true,
      },
    });

    bus.emit("order.delivered", {
      orderId: updatedOrder.id,
      customerId: updatedOrder.customer_id ?? undefined,
      externalAppId: updatedOrder.external_app_id ?? undefined,
      courierId,
      actualPriceCents: actualPrice,
      totalFeeCents: totalFee,
      courierFeeCents: courierFee,
      platformFeeCents: platformFee,
      discountCents: couponPricing.discountCents,
      paymentAmountCents: Decimal(couponPricing.payableCents),
      paymentMethod: updatedOrder.payment_method,
      deliveredAt: updatedOrder.delivered_at ?? new Date(),
      type: updatedOrder.type,
      supplierId: updatedOrder.supplier_id ?? undefined,
      partnerFeeCents: order.partner_fee ?? undefined,
      coupon_type: couponPricing.scope,
    });

    return updatedOrder;
  });
}

// ─── Customer proposal accept ─────────────────────────────────────────────────
export async function acceptProposalService(
  orderId: number,
  proposalId: number,
  input: ProposalDecisionInput,
  customerId: number,
) {
  const [order, settings] = await Promise.all([
    getOrderOrThrow(orderId),
    prisma.applicationSetting.findFirst({
      select: { vat: true, min_platform_fee: true },
    }),
  ]);

  if (order.external_app_id !== null)
    throw new HttpError(400, "orders:errors.use_partner_accept_endpoint");
  if (order.customer_id !== customerId)
    throw new HttpError(403, "orders:errors.forbidden");

  assertOrderAcceptable(order);

  const vatRate = Decimal(settings?.vat ?? 0).div(100);
  const minPlatformFee = Decimal(settings?.min_platform_fee ?? 0);

  const proposal = await getProposalOrThrow(proposalId, orderId);

  if (input.status === "REJECTED") {
    const updatedProposal = await rejectProposal(proposalId, {
      orderId,
      courierId: proposal.courier_id!,
      actorId: customerId,
    });
    return { order, proposal: updatedProposal };
  }

  const result = await prisma.$transaction(async (tx) => {
    const acceptedProposal = await tx.orderProposal.update({
      where: { id: proposalId },
      data: { status: "ACCEPTED", confirmed_at: new Date() },
    });

    await rejectOtherProposals(tx, orderId, proposalId);

    const feeSplit = await computeOrderFeeSplit(tx, {
      courierId: proposal.courier_id!,
      courierBid: proposal.total_fee,
      distanceM: +order.distance_m!,
      vatRate,
      minPlatformFee,
    });

    // [REVIEW][SUPPLIER_BUDGET_FEE_FIX] computeOrderFeeSplit recomputes the fees from
    // scratch and knows nothing about the supplier budget fee, so it must be re-added
    // here (mirrors createOrderService). Without this it was silently dropped, and the
    // escrow adjustment below refunded it back to the supplier instead of the platform.
    const supplierBudgetFee = order.supplier_budget_fee
      ? new Decimal(order.supplier_budget_fee)
      : new Decimal(0);
    if (supplierBudgetFee.gt(0)) {
      feeSplit.platformFee = feeSplit.platformFee.add(supplierBudgetFee);
      feeSplit.totalFeeWithVat = feeSplit.totalFeeWithVat.add(supplierBudgetFee);
    }

    const couponPricing = await recalculateOrderCouponForOrder(tx, {
      orderId,
      budgetCents: order.budget ? +order.budget : 0,
      totalFeeCents: order.coupon_id
        ? +feeSplit.courierFee
        : +feeSplit.totalFeeWithVat,
      updateOrder: false,
    });

    const payable_amount = couponPricing.discountCents
      ? couponPricing.payableCents + (feeSplit.platformFee.toNumber() ?? 0)
      : couponPricing.payableCents;

    const updatedOrder = await tx.order.update({
      where: { id: orderId },
      data: {
        courier_id: proposal.courier_id,
        total_fee: +feeSplit.totalFeeWithVat,
        courier_fee: feeSplit.courierFee,
        platform_fee: feeSplit.platformFee,
        vat_amount: feeSplit.vatAmount,
        status: "IN_PROGRESS",
        offer_accepted_at: new Date(),
        discount_amount: couponPricing.discountCents,
        payable_amount,
      },
      select: {
        id: true,
        customer_id: true,
        courier_id: true,
        delivery_area_id: true,
        pickup_area_id: true,
        payment_method: true,
        budget: true,
        total_fee: true,
        actual_price: true,
        order_number: true,
      },
    });

    if (updatedOrder.payment_method === "WALLET") {
      await adjustOrderEscrowToAmount(tx, {
        orderId: updatedOrder.id,
        customerId: updatedOrder.customer_id!,
        requiredAmount: Decimal(payable_amount),
        reason: "proposal accepted",
      });
    }

    return { order: updatedOrder, proposal: acceptedProposal };
  });

  bus.emit("offer.accepted", {
    orderId: result.order.id,
    offerId: result.proposal.id,
    courierId: result.order.courier_id!,
    customerId: result.order.customer_id!,
    pickupAreaId: result.order.pickup_area_id!,
    acceptedAt: new Date().toISOString(),
  });

  return result;
}

export async function acceptPriceAdjustmentService(input: {
  orderId: number;
  customerId?: number;
  externalAppId?: number;
}) {
  return prisma.$transaction(async (tx) => {
    const order = await tx.order.findUnique({ where: { id: input.orderId } });

    if (!order) throw new HttpError(404, "orders:errors.order_not_found");
    if (order.type !== "CUSTOM_PICKUP")
      throw new HttpError(400, "orders:errors.invalid_order_type_for_proposal");
    if (order.price_adjustment_status !== "PENDING" || !order.actual_price)
      throw new HttpError(409, "orders:errors.no_pending_price_adjustment");

    const isPartnerOrder = order.external_app_id !== null;

    // ── Ownership ────────────────────────────────────────────────────────
    if (isPartnerOrder) {
      if (order.external_app_id !== input.externalAppId)
        throw new HttpError(403, "orders:errors.forbidden");
    } else {
      if (order.customer_id !== input.customerId)
        throw new HttpError(403, "orders:errors.forbidden");
    }

    // ── Payable amount ───────────────────────────────────────────────────
    let payable_amount: number;
    let discountCents = 0;

    if (isPartnerOrder) {
      // Partner: no coupons — new payable = actual_price + total_fee
      payable_amount =
        order.actual_price.toNumber() + (order.total_fee?.toNumber() ?? 0);
    } else {
      const couponPricing = await recalculateOrderCouponForOrder(tx, {
        orderId: order.id,
        budgetCents: order.actual_price ? +order.actual_price : 0,
        totalFeeCents: order.coupon_id
          ? (order.courier_fee?.toNumber() ?? 0)
          : (order.total_fee?.toNumber() ?? 0),
        updateOrder: false,
      });

      discountCents = couponPricing.discountCents;
      payable_amount = couponPricing.discountCents
        ? couponPricing.payableCents + (order.platform_fee?.toNumber() ?? 0)
        : couponPricing.payableCents;
    }

    // ── Wallet escrow adjustment ──────────────────────────────────────────
    if (order.payment_method === "WALLET") {
      if (isPartnerOrder) {
        await adjustPartnerOrderEscrow(tx, {
          orderId: order.id,
          externalAppId: order.external_app_id!,
          requiredAmount: Decimal(payable_amount),
        });
      } else {
        await adjustOrderEscrowToAmount(tx, {
          orderId: order.id,
          customerId: order.customer_id!,
          requiredAmount: Decimal(payable_amount),
          reason: "price adjustment accepted",
        });
      }
    }

    return tx.order.update({
      where: { id: order.id },
      data: {
        actual_price: order.actual_price,
        price_adjustment_status: "ACCEPTED",
        price_adjusted_at: new Date(),
        discount_amount: discountCents,
        payable_amount,
      },
    });
  });
}

export async function rejectPriceAdjustmentService(input: {
  orderId: number;
  customerId?: number;
  externalAppId?: number;
  reason?: string;
}) {
  const order = await prisma.order.findUnique({ where: { id: input.orderId } });

  if (!order) throw new HttpError(404, "orders:errors.order_not_found");
  if (order.type !== "CUSTOM_PICKUP") {
    throw new HttpError(400, "orders:errors.invalid_order_type_for_proposal");
  }
  if (order.price_adjustment_status !== "PENDING")
    throw new HttpError(409, "orders:errors.no_pending_price_adjustment");

  const isPartnerOrder = order.external_app_id !== null;

  // ── Ownership ────────────────────────────────────────────────────────
  if (isPartnerOrder && order.external_app_id !== input.externalAppId)
    throw new HttpError(403, "orders:errors.forbidden");

  if (!isPartnerOrder && order.customer_id !== input.customerId)
    throw new HttpError(403, "orders:errors.forbidden");

  // ── Execution ────────────────────────────────────────────────────────
  // Pass the appropriate ID based on who is rejecting (Customer or Partner)
  return cancelOrderService(
    input.orderId,
    {
      cancelled_reason:
        input.reason ?? "Cancelled because price adjustment was rejected",
      price_adjustment_status: "REJECTED",
      price_adjusted_at: new Date(),
    },
    isPartnerOrder ? undefined : input.customerId,
    isPartnerOrder ? input.externalAppId : undefined,
  );
}

export async function customerRetryOrderService(
  orderId: number,
  customerId: number,
) {
  return prisma.$transaction(async (tx) => {
    const order = await tx.order.findUnique({ where: { id: orderId } });

    if (!order) throw new HttpError(404, "orders:errors.order_not_found");
    if (order.customer_id !== customerId)
      throw new HttpError(403, "orders:errors.forbidden");
    if (order.status !== "EXPIRED")
      throw new HttpError(409, "orders:errors.order_not_retryable");

    const settings = await tx.applicationSetting.findFirst({
      select: {
        proposal_waiting_time_minutes: true,
        order_expiration_time_minutes: true,
        max_order_retry_count: true,
      },
    });

    // ── Re-deduct stock for CATALOG_PURCHASE ──────────────────────────────
    // Stock was restored when the order expired — take it back now.
    if (order.type === "CATALOG_PURCHASE") {
      const items = await tx.orderItem.findMany({
        where: { order_id: orderId },
        select: { sp_id: true, quantity: true },
      });

      // Reuses the same pessimistic guard as checkout —
      // throws 409 if any product ran out since the order expired.
      await deductStock(tx, items);
    }

    const maxRetries = settings?.max_order_retry_count ?? 3;
    if ((order.retry_count ?? 0) >= maxRetries)
      throw new HttpError(409, "orders:errors.max_retry_reached");

    const now = new Date();
    const proposalMinutes = settings?.proposal_waiting_time_minutes ?? 5;
    const expirationMinutes = settings?.order_expiration_time_minutes ?? 15;
    const proposalsDeadline = new Date(
      now.getTime() + proposalMinutes * 60_000,
    );
    const expiresAt = new Date(now.getTime() + expirationMinutes * 60_000);

    const vehicles = await selectVehiclesForDistance(
      Number(order.distance_m ?? 0),
    );

    const updatedOrder = await tx.order.update({
      where: { id: orderId },
      data: {
        status: "PENDING",
        retry_count: { increment: 1 },
        failure_reason: null,
        proposals_deadline_at: proposalsDeadline,
        expires_at: expiresAt,
      },
    });

    // Re-reserve coupon slot — was deleted when order expired
    if (order.coupon_id) {
      await tx.customerCouponUsage.create({
        data: {
          user_id: customerId,
          coupon_id: order.coupon_id,
          context: "ORDER",
          order_id: order.id,
          discount_cents: 0, // unknown until proposal accepted
        },
      });
    }

    bus.emit("order.created", {
      orderId: order.id,
      deliveryAreaId: order.delivery_area_id!,
      createdAt: new Date().toISOString(),
      customerId: order.customer_id!,
      budget: +order.budget!,
      pickupAreaId: order.pickup_area_id!,
      vehicleIds: vehicles.map((v) => v.id),
      distanceM: Number(order.distance_m ?? 0),
      proposalsDeadline: proposalsDeadline.toISOString(),
      expiresAt: expiresAt.toISOString(),
      type: "CUSTOM_PICKUP",
      pickupLat: +order.pickup_lat!,
      pickupLng: +order.pickup_long!,
    });

    return updatedOrder;
  });
}

export async function createOrderIssueService(
  input: CreateOrderIssueInput,
  customerId: number,
) {
  const order = await prisma.order.findUnique({
    where: { id: input.order_id },
  });

  if (!order) throw new HttpError(404, "orders:errors.order_issue.not_found");
  if (order.customer_id !== customerId) throw new HttpError(403, "forbidden");
  if (order.status !== "IN_PROGRESS")
    throw new HttpError(409, "orders:errors.order_not_in_progress");

  const existing = await prisma.orderIssue.findFirst({
    where: {
      order_id: input.order_id,
      status: { in: ["OPEN", "UNDER_REVIEW"] },
    },
  });

  if (existing)
    throw new HttpError(409, "orders:errors.order_issue.already_exists");

  const issue = await prisma.orderIssue.create({
    data: {
      order_id: input.order_id,
      customer_id: customerId,
      courier_id: order.courier_id,
      reason: input.reason,
      description: input.description,
    },
  });

  bus.emit("order.issue.created", {
    orderId: input.order_id,
    customerId,
    courierId: order.courier_id!,
    issueId: issue.id,
    reason: input.reason,
    description: input.description,
    createdAt: issue.created_at,
  });

  return issue;
}

export async function completedOrdersCount(customer_id: User["id"]) {
  return prisma.order.count({
    where: {
      customer_id,
      OR: [
        {
          status: "DELIVERED",
        },
        {
          status: "IN_PROGRESS",
        },
      ],
    },
  });
}

export async function getCourierLocationService(
  orderId: number,
  userId?: number,
) {
  const order = await prisma.order.findFirst({
    where: {
      id: orderId,
      ...(userId ? { customer_id: userId } : []),
      status: "IN_PROGRESS",
      courier_id: { not: null },
    },
    select: {
      courier_id: true,
    },
  });

  if (!order) {
    throw new HttpError(404, "orders:errors.no_active_order");
  }

  const courier = await prisma.courier.findUnique({
    where: { id: order.courier_id! },
    select: {
      lat: true,
      lng: true,
      last_location_update: true,
    },
  });

  if (!courier || courier.lat === null || courier.lng === null) {
    throw new HttpError(404, "orders:errors.courier_location_unavailable");
  }

  return {
    courierId: order.courier_id!,
    lat: courier.lat,
    lng: courier.lng,
    orderId,
    timestamp: courier.last_location_update,
  };
}

export async function getOrderFeeBoundsService(
  orderId: number,
  userId: number,
) {
  const now = new Date();

  const [order, courier, settings, peakTimeMatch] = await Promise.all([
    getOrderOrThrow(orderId),
    prisma.courier.findUnique({
      where: { user_id: userId },
      include: { user: { include: { badge: true } }, vehicle: true },
    }),
    prisma.applicationSetting.findFirst({
      select: {
        proposal_waiting_time_minutes: true,
        order_expiration_time_minutes: true,
        vat: true,
        min_platform_fee: true,
      },
    }),
    prisma.peakTime.findFirst({
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
    }),
  ]);

  if (!courier) throw new HttpError(403, "orders:errors.courier_not_found");

  const badgeRatio = new Decimal(courier.user.badge?.ratio || 0.3).div(100); // Default if no badge
  const vehicle = courier.vehicle; // Fallback to order vehicle
  const vatRate = Decimal(settings?.vat ?? 0).div(100);
  const minPlatformFee = Decimal(settings?.min_platform_fee ?? 0);
  const distanceM = Number(order.distance_m || 0);

  if (!vehicle) throw new HttpError(400, "orders:errors.vehicle_required");

  if (
    vehicle.min_distance_per_km &&
    distanceM < Number(vehicle.min_distance_per_km)
  ) {
    throw new HttpError(400, "orders:errors.distance_too_short_for_vehicle");
  }

  // Check Maximum Distance
  if (
    vehicle.max_distance_per_km &&
    distanceM > Number(vehicle.max_distance_per_km)
  ) {
    throw new HttpError(400, "orders:errors.distance_too_long_for_vehicle");
  }
  const peakRatio = peakTimeMatch ? (vehicle.peak_time_fee_ratio ?? 0) : 0;

  // 3. Calculate "Base Courier Fee" using your Shared Logic
  // This gives us the 'Suggested' value (middle of the slider)
  const calcResult = calculateSharedFeeLogic({
    baseFee: vehicle.min_delivery_fee,
    distanceM,
    badgeRatio: badgeRatio.toNumber(),
    thresholdKm: vehicle.fee_base_distance_km,
    extraPlatformPerKm: vehicle.fee_extra_platform_per_km,
    extraCourierPerKm: vehicle.fee_extra_courier_per_km,
    peakRatio,
    vatRate,
    minPlatformFee,
  });

  const suggestedFee = calcResult.courierFee;

  // 4. Calculate Min and Max
  // Min: Purely the split of the base fee before extras
  const minFee = roundTo100(
    vehicle.min_delivery_fee.mul(new Decimal(1).sub(badgeRatio)),
  );

  // Max: Using the vehicle's specific delivery_fee_ratio
  const maxRatioMultiplier = new Decimal(1).add(
    new Decimal(vehicle.delivery_fee_ratio).div(100),
  );
  const maxFee = roundTo100(suggestedFee.mul(maxRatioMultiplier));

  return {
    minCourierFee: minFee.toDecimalPlaces(2).toNumber(),
    suggestedCourierFee: suggestedFee.toDecimalPlaces(2).toNumber(),
    maxCourierFee: maxFee.toDecimalPlaces(2).toNumber(),

    peakTimeSurcharge: calcResult.peakTimeSurcharge,
    isPeakTime: calcResult.isPeakTime,
    appliedBonus: calcResult.appliedBonus,
  };
}
