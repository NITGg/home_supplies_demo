import { prisma } from "@/config/prisma";
import { adjustWalletBalance } from "@/lib/adjustWalletBalance";
import { HttpError } from "@/lib/httpError";
import { Tx } from "@/types/prisma.types";
import { bus } from "@/events/bus";
import { getRoadDistanceM } from "@/lib/distance";
import { selectVehiclesForDistance } from "@/lib/vehicle-selector";
import {
  activeOfferWhere,
  calcEffectivePrices,
  resolveSupplierPickupAddress,
} from "@/lib/catalogHelpers";
import type {
  CreateCatalogOrderInput,
  CreateOrderInput,
} from "../orders.schema";
import { initiateOrderPayment } from "@/services/payment-gateway.service";
import type { Lang } from "@/types/express";
import {
  computeEstimatedFeeSplit,
  deductStock,
  genOrderNumber,
  resolveDeliveryAddress,
  restoreStockIfCatalog,
  validateOrderCouponForCreate,
} from "../order.utils";
import { generateOtp } from "@/lib/otp";
import { Decimal } from "@prisma/client/runtime/client";

// ─── Types ────────────────────────────────────────────────────────────────────

interface OrderItemDraft {
  product_id: number;
  sp_id: number;
  quantity: number;
  unit_price: number;
  cost_price: number | null;
  offer_id: number | null;
  estimated_time_from: number | null;
  estimated_time_to: number | null;
}

interface ResolvedCart {
  supplierId: number;
  orderItems: OrderItemDraft[];
  productsTotal: number;
  totalCostPrice: number;
}

// step: claude: shared timezone-aware day/time helpers for type-3 (scheduled delivery window) products
const TYPE3_TZ = "Africa/Cairo";
const TYPE3_WEEKDAY_TO_NUM: Record<string, number> = {
  Sun: 0,
  Mon: 1,
  Tue: 2,
  Wed: 3,
  Thu: 4,
  Fri: 5,
  Sat: 6,
};

// step: claude: get the day-of-week (0=Sun..6=Sat) of a date in the type-3 timezone
function dowInTz(d: Date): number {
  const weekdayStr =
    new Intl.DateTimeFormat("en-US", { timeZone: TYPE3_TZ, weekday: "short" })
      .formatToParts(d)
      .find((p) => p.type === "weekday")?.value || "";
  return TYPE3_WEEKDAY_TO_NUM[weekdayStr];
}

// step: claude: get the "HH:mm" wall-clock time of a date in the type-3 timezone
function hhmmInTz(d: Date): string {
  const parts = new Intl.DateTimeFormat("en-US", {
    timeZone: TYPE3_TZ,
    hour: "2-digit",
    minute: "2-digit",
    hour12: false,
  }).formatToParts(d);
  const hourStr = parts.find((p) => p.type === "hour")?.value || "00";
  const minuteStr = parts.find((p) => p.type === "minute")?.value || "00";
  const hour24 = hourStr === "24" ? "00" : hourStr;
  return `${hour24}:${minuteStr}`;
}

// step: claude: count SCHEDULED orders that contain a given supplier-product and fall inside a delivery window on a given date
async function countScheduledInDeliveryWindow(
  client: Tx | typeof prisma,
  spId: number,
  scheduleDate: Date,
  timeFrom: string,
  timeTo: string,
): Promise<number> {
  const startOfDay = new Date(scheduleDate);
  startOfDay.setUTCHours(0, 0, 0, 0);
  const endOfDay = new Date(scheduleDate);
  endOfDay.setUTCHours(23, 59, 59, 999);

  const existing = await client.order.findMany({
    where: {
      status: "SCHEDULED",
      is_order_scheduled: true,
      order_schedule_at: { gte: startOfDay, lte: endOfDay },
      orderItems: { some: { sp_id: spId } },
    },
    select: { order_schedule_at: true },
  });

  let count = 0;
  for (const o of existing) {
    if (!o.order_schedule_at) continue;
    const t = hhmmInTz(o.order_schedule_at);
    if (t >= timeFrom && t < timeTo) count++;
  }
  return count;
}

// step: claude: validate every type-3 product against its ORDER window (now), DELIVERY window (order_schedule_at) and capacity
async function validateType3DeliveryWindows(
  tx: Tx,
  params: {
    supplierProductIds: number[];
    orderScheduleAt: Date;
    now: Date;
  },
): Promise<void> {
  const orderDay = dowInTz(params.now);
  const orderTime = hhmmInTz(params.now);
  const deliveryDay = dowInTz(params.orderScheduleAt);
  const deliveryTime = hhmmInTz(params.orderScheduleAt);

  for (const spId of params.supplierProductIds) {
    const windows = await tx.supplierProductDeliveryWindow.findMany({
      where: { supplier_product_id: spId },
    });
    const orderWindows = windows.filter((w) => w.window_type === "ORDER");
    const deliveryWindows = windows.filter((w) => w.window_type === "DELIVERY");

    // step: claude: a type-3 product must have both ORDER and DELIVERY windows configured
    if (orderWindows.length === 0 || deliveryWindows.length === 0) {
      throw new HttpError(400, "orders:errors.product_windows_not_configured");
    }

    // step: claude: current time must fall inside an ORDER window for today's day-of-week
    const orderOk = orderWindows.some(
      (w) =>
        w.day_of_week === orderDay &&
        orderTime >= w.time_from &&
        orderTime < w.time_to,
    );
    if (!orderOk) {
      throw new HttpError(400, "orders:errors.outside_order_window");
    }

    // step: claude: chosen delivery time must fall inside a DELIVERY window for that date's day-of-week
    const matched = deliveryWindows.find(
      (w) =>
        w.day_of_week === deliveryDay &&
        deliveryTime >= w.time_from &&
        deliveryTime < w.time_to,
    );
    if (!matched) {
      throw new HttpError(400, "orders:errors.outside_delivery_window");
    }

    // step: claude: enforce per-window capacity for the matched delivery window
    if (matched.max_orders != null) {
      const count = await countScheduledInDeliveryWindow(
        tx,
        spId,
        params.orderScheduleAt,
        matched.time_from,
        matched.time_to,
      );
      if (count >= matched.max_orders) {
        throw new HttpError(400, "orders:errors.delivery_slot_full");
      }
    }
  }
}

// ─── Resolve and validate cart items ─────────────────────────────────────────

async function resolveCartForOrder(
  tx: Tx,
  cartId: number,
  //  Pass customerId here to validate that the customer's saved delivery
  // address belongs to an area served by the resolved supplier store.
  // For now, area-matching is skipped — the delivery location is trusted as-is.
  // customerId: number,
): Promise<ResolvedCart> {
  const items = await tx.cartItem.findMany({
    where: { cart_id: cartId },
    include: {
      supplierProduct: {
        include: {
          product: {
            select: { id: true, deleted_at: true, name: true, name_ar: true },
          },
          supplier: { select: { id: true } },
          offers: {
            where: activeOfferWhere(),
            take: 1,
          },
        },
      },
    },
  });

  if (!items.length) throw new HttpError(400, "orders:errors.cart_empty");

  // Single-supplier constraint — one cart checkout = one supplier
  const supplierIds = new Set(items.map((i) => i.supplierProduct.supplier_id));
  if (supplierIds.size > 1) {
    throw new HttpError(
      400,
      "orders:errors.cart_multiple_suppliers",
      "MULTIPLE_SUPPLIERS",
    );
  }

  const supplierId = items[0].supplierProduct.supplier_id;
  const orderItems: OrderItemDraft[] = [];
  let productsTotal = 0;
  let totalCostPrice = 0;

  for (const item of items) {
    const sp = item.supplierProduct;
    const basePrice = sp.price ?? 0;
    const baseCost = sp.cost_price ?? 0;
    const activeOffer = sp.offers[0] ?? null;

    if (!sp.is_active || sp.product.deleted_at !== null) {
      throw new HttpError(400, "orders:errors.product_unavailable", undefined, {
        product: sp.product.name,
      });
    }

    if (sp.stock < item.quantity) {
      throw new HttpError(400, "orders:errors.insufficient_stock", undefined, {
        product: sp.product.name,
        available: sp.stock,
        requested: item.quantity,
      });
    }

    if (
      sp.max_amount_for_one_order !== null &&
      item.quantity > Number(sp.max_amount_for_one_order)
    ) {
      throw new HttpError(
        400,
        "orders:errors.exceeds_max_per_order",
        undefined,
        { product: sp.product.name, max: sp.max_amount_for_one_order },
      );
    }

    const { finalCostPrice, finalUnitPrice } = calcEffectivePrices(
      basePrice,
      baseCost,
      activeOffer,
    );

    productsTotal += finalUnitPrice * item.quantity;
    totalCostPrice += finalCostPrice * item.quantity;
    orderItems.push({
      product_id: sp.product.id,
      sp_id: sp.id,
      quantity: item.quantity,
      unit_price: finalUnitPrice,
      cost_price: finalCostPrice, // Include it in the draft
      offer_id: activeOffer?.id ?? null,
      estimated_time_from: sp.estimated_time_from,
      estimated_time_to: sp.estimated_time_to,
    });
  }

  return { supplierId, orderItems, productsTotal, totalCostPrice };
}

// step: claude: compare a cart's items against a pending order's items (same sp_id + quantity, regardless of order)
function cartMatchesOrderItems(
  cartItems: { sp_id: number; quantity: number }[],
  orderItems: { sp_id: number; quantity: number }[],
): boolean {
  if (cartItems.length !== orderItems.length) return false;
  const orderMap = new Map(orderItems.map((i) => [i.sp_id, i.quantity]));
  return cartItems.every((c) => orderMap.get(c.sp_id) === c.quantity);
}

// step: claude: release a stale/superseded PENDING_PAYMENT card order — fail its pending
// transaction, cancel the order and restore the stock that was reserved for it
async function cancelStalePendingCardOrder(
  orderId: number,
  pendingTransactionId: number | null,
  reason: string,
) {
  await prisma.$transaction(async (tx) => {
    if (pendingTransactionId) {
      await tx.transaction.update({
        where: { id: pendingTransactionId },
        data: { status: "FAILED", reject_reason: reason.slice(0, 255) },
      });
    }
    await tx.order.update({
      where: { id: orderId },
      data: { status: "EXPIRED", cancelled_reason: reason.slice(0, 255) },
    });
    await restoreStockIfCatalog(tx, { id: orderId, type: "CATALOG_PURCHASE" });
  });
}

// ─── Create catalog order service ─────────────────────────────────────────────────────

export interface CreateCatalogOrderContext {
  user: { full_name: string; email?: string | null; phone?: string | null };
  lang: Lang;
  paymobWebhookUrl: string;
  kashierWebhookUrl: string;
  easykashWebhookUrl: string;
}

export async function createCatalogOrderService(
  input: CreateCatalogOrderInput,
  customerId: number,
  ctx?: CreateCatalogOrderContext,
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

  // step: if order_schedule_at has value update it
  const appSettings = await prisma.applicationSetting.findFirst({
    select: {
      scheduled_delivery_offset_minutes: true,
      min_scheduled_delivery_minutes: true,
    },
  });
  if (!appSettings) {
    throw new HttpError(500, "orders:errors.app_settings_not_found");
  }

  // step: claude: detect type-3 (scheduled delivery window) products in the cart up front
  const cartProductsMeta = await prisma.cartItem.findMany({
    where: { cart_id: customerId },
    select: {
      sp_id: true,
      supplierProduct: {
        select: { requires_delivery_windows: true },
      },
    },
  });
  const type3SupplierProductIds = cartProductsMeta
    .filter((c) => c.supplierProduct.requires_delivery_windows)
    .map((c) => c.sp_id);
  const hasType3Products = type3SupplierProductIds.length > 0;

  // step: claude: when the cart has any type-3 product the whole order follows the type-3 delivery window —
  // step: claude: normal and preparation (type-2) products simply ride along and are delivered at that scheduled time
  if (hasType3Products) {
    input.is_order_scheduled = true;
    if (!input.order_schedule_at) {
      throw new HttpError(400, "orders:errors.order_schedule_required");
    }
  }

  // step: claude: for type-3 (option A) the sent order_schedule_at IS the chosen delivery slot time —
  // step: claude: do NOT subtract the courier-visibility offset, so window validation/capacity/storage all stay on the real delivery time
  if (!hasType3Products && input.order_schedule_at) {
    input.order_schedule_at = new Date(
      input.order_schedule_at.getTime() -
        appSettings.scheduled_delivery_offset_minutes * 60 * 1000,
    );
  }

  // step: scheduled time must be at least min_scheduled_delivery_minutes after the store opens that day
  // step: claude: skip the store-hours check for type-3 products — they follow product delivery windows, not store hours
  if (
    !hasType3Products &&
    input.is_order_scheduled === true &&
    input.order_schedule_at &&
    input.supplier_store_address_id
  ) {
    const storeAddr = await prisma.supplierStoreAddress.findFirst({
      where: { id: input.supplier_store_address_id },
      select: { working_hours: true },
    });
    if (!storeAddr) {
      throw new HttpError(400, "orders:errors.store_address_not_found");
    }
    const wh = storeAddr.working_hours as any;
    const tz = wh?.timezone || "Africa/Cairo";
    const scheduleDate = new Date(input.order_schedule_at);
    const dayMap: Record<string, number> = {
      Sun: 0,
      Mon: 1,
      Tue: 2,
      Wed: 3,
      Thu: 4,
      Fri: 5,
      Sat: 6,
    };
    const weekdayStr =
      new Intl.DateTimeFormat("en-US", { timeZone: tz, weekday: "short" })
        .formatToParts(scheduleDate)
        .find((p) => p.type === "weekday")?.value || "";
    const dayOfWeek = dayMap[weekdayStr];
    const dayObj = wh?.days?.[String(dayOfWeek)];
    if (
      dayObj &&
      !dayObj.is_closed &&
      Array.isArray(dayObj.slots) &&
      dayObj.slots.length > 0
    ) {
      // store opening = earliest slot open time for that day
      const openTime = dayObj.slots.map((s: any) => s.open as string).sort()[0];
      const [openHour, openMinute] = openTime.split(":").map(Number);
      const openMinutes = openHour * 60 + openMinute;
      const timeParts = new Intl.DateTimeFormat("en-US", {
        timeZone: tz,
        hour: "2-digit",
        minute: "2-digit",
        hour12: false,
      }).formatToParts(scheduleDate);
      const hourStr = timeParts.find((p) => p.type === "hour")?.value || "00";
      const minuteStr =
        timeParts.find((p) => p.type === "minute")?.value || "00";
      const scheduleMinutes =
        (hourStr === "24" ? 0 : Number(hourStr)) * 60 + Number(minuteStr);

      if (
        scheduleMinutes <
        openMinutes + appSettings.min_scheduled_delivery_minutes
      ) {
        throw new HttpError(400, "orders:errors.schedule_too_early");
      }
    }
  }

  // Pre-flight: cart and delivery area must exist before opening a transaction
  const [cart, settings] = await Promise.all([
    prisma.cart.findUnique({ where: { id: customerId }, select: { id: true } }),
    prisma.applicationSetting.findFirst({
      select: {
        proposal_waiting_time_minutes: true,
        order_expiration_time_minutes: true,
        vat: true, // Fetch VAT rate
        min_platform_fee: true,
        // delivery_price_for_each_1km: true, // Fetch base KM price
        // min_delivery_fee: true,
      },
    }),
  ]);

  if (!cart) throw new HttpError(400, "orders:errors.cart_empty");

  // step: claude: CARD orders aren't created twice for the same untouched cart —
  // reuse an in-flight PENDING_PAYMENT order's checkout link if nothing changed,
  // or release its stock reservation before creating a fresh order otherwise.
  if (input.payment_method === "CARD") {
    if (!ctx) throw new HttpError(500, "orders:errors.payment_init_failed");

    const existingOrder = await prisma.order.findFirst({
      where: { cart_id: cart.id, status: "PENDING_PAYMENT" },
      orderBy: { created_at: "desc" },
      include: { coupon: { select: { code: true } } },
    });

    if (existingOrder) {
      const [existingItems, currentCartItems, pendingTx, newDelivery] =
        await Promise.all([
          prisma.orderItem.findMany({
            where: { order_id: existingOrder.id },
            select: { sp_id: true, quantity: true },
          }),
          prisma.cartItem.findMany({
            where: { cart_id: cart.id },
            select: { sp_id: true, quantity: true },
          }),
          prisma.transaction.findFirst({
            where: {
              order_id: existingOrder.id,
              type: "ORDER_PAYMENT",
              status: "PENDING",
            },
            orderBy: { created_at: "desc" },
            include: { paymentMethod: { select: { provider: true } } },
          }),
          resolveDeliveryAddress(prisma, customerId, input.customer_address_id),
        ]);

      const requestedProvider = input.card_provider ?? "paymob";
      const existingProvider =
        pendingTx?.paymentMethod?.provider?.toLowerCase();

      // step: claude: also require the delivery address and coupon to match —
      // reusing the old checkout link with a stale address/coupon would charge
      // the customer the wrong amount or deliver to the wrong place.
      const addressMatches =
        existingOrder.delivery_area_id === newDelivery.deliveryAreaId &&
        Number(existingOrder.delivery_lat) === newDelivery.deliveryLat &&
        Number(existingOrder.delivery_long) === newDelivery.deliveryLong;

      const couponMatches =
        (existingOrder.coupon?.code ?? null) ===
        (input.coupon_code?.trim() || null);

      if (
        pendingTx?.checkout_url &&
        existingProvider === requestedProvider &&
        addressMatches &&
        couponMatches &&
        cartMatchesOrderItems(currentCartItems, existingItems)
      ) {
        // Same cart, address, coupon and provider, payment still pending —
        // re-serve the existing checkout link instead of creating a duplicate
        // order/reservation.
        return {
          order: existingOrder,
          cardPayment: {
            provider: requestedProvider,
            transactionId: pendingTx.id,
            checkoutUrl: pendingTx.checkout_url,
          },
        };
      }

      // Cart/provider changed, or the previous attempt is stale — release the old
      // reservation (restore stock, cancel order) before creating a fresh one.
      await cancelStalePendingCardOrder(
        existingOrder.id,
        pendingTx?.id ?? null,
        "Superseded by a new checkout attempt",
      );
    }
  }

  const {
    order,
    vehicles,
    distance,
    totalFeeWithVat,
    supplierId,
    stockSnapshot,
  } = await prisma.$transaction(async (tx) => {
    // step: claude: validate type-3 products against their order/delivery windows + capacity (inside tx for race-safe capacity)
    if (hasType3Products) {
      await validateType3DeliveryWindows(tx, {
        supplierProductIds: type3SupplierProductIds,
        orderScheduleAt: new Date(input.order_schedule_at!),
        now: new Date(),
      });
    }

    // step: check if is_order_scheduled == true
    // step: claude: skip store working-hours / slot checks for type-3 orders
    if (
      !hasType3Products &&
      input.is_order_scheduled === true &&
      input.supplier_store_address_id
    ) {
      // sup-stip:check supplier store address existance
      const storeAddress = await tx.supplierStoreAddress.findFirst({
        where: { id: input.supplier_store_address_id },
        select: {
          id: true,
          working_hours: true,
          default_max_orders: true,
          supplier_id: true,
        },
      });
      if (!storeAddress) {
        throw new HttpError(400, "orders:errors.store_address_not_found");
      }

      // sup-stip:extracnt working hours
      const scheduleDate = new Date(input.order_schedule_at!);
      const wh = storeAddress.working_hours as any;
      const tz = wh?.timezone || "Africa/Cairo";
      const formatterDay = new Intl.DateTimeFormat("en-US", {
        timeZone: tz,
        weekday: "short",
      });
      const weekdayStr =
        formatterDay
          .formatToParts(scheduleDate)
          .find((p) => p.type === "weekday")?.value || "";
      const dayMap: Record<string, number> = {
        Sun: 0,
        Mon: 1,
        Tue: 2,
        Wed: 3,
        Thu: 4,
        Fri: 5,
        Sat: 6,
      };
      const dayOfWeek = dayMap[weekdayStr];
      const formatterTime = new Intl.DateTimeFormat("en-US", {
        timeZone: tz,
        hour: "2-digit",
        minute: "2-digit",
        hour12: false,
      });
      const timeParts = formatterTime.formatToParts(scheduleDate);
      const hourStr = timeParts.find((p) => p.type === "hour")?.value || "00";
      const minuteStr =
        timeParts.find((p) => p.type === "minute")?.value || "00";
      const hour24 = hourStr === "24" ? "00" : hourStr;
      const timeStr = `${hour24}:${minuteStr}`;

      // sup-step: check working_hours if store open on this day/time
      let todayCloseTime: string | null = null;
      if (wh?.days) {
        const dayObj = wh.days[String(dayOfWeek)];
        if (!dayObj || dayObj.is_closed) {
          throw new HttpError(400, "orders:errors.store_closed");
        }
        if (Array.isArray(dayObj.slots)) {
          const withinSlot = dayObj.slots.find(
            (s: any) => timeStr >= s.open && timeStr < s.close,
          );
          if (!withinSlot) {
            throw new HttpError(400, "orders:errors.outside_working_hours");
          }
          todayCloseTime = withinSlot.close;
        }
      }

      // sup-step: get order items
      const cartItemsForEstimate = await tx.cartItem.findMany({
        where: { cart_id: cart.id },
        include: {
          supplierProduct: {
            select: { estimated_time_to: true, estimated_time_from: true },
          },
        },
      });

      // sup-step: get bigest estimated_time_to value of order items
      let maxEstimatedTimeTo = 0;
      for (const item of cartItemsForEstimate) {
        const sp = item.supplierProduct;
        const t = sp?.estimated_time_to ?? sp?.estimated_time_from ?? 0;
        if (t > maxEstimatedTimeTo) {
          maxEstimatedTimeTo = t;
        }
      }

      // sup-step: check if order_schedule_at + bigest estimated_time_to value <= closed time of today shift
      if (maxEstimatedTimeTo > 0 && todayCloseTime) {
        const scheduleDateWithEstimate = new Date(
          scheduleDate.getTime() + maxEstimatedTimeTo * 60000,
        );
        const timePartsEstimate = formatterTime.formatToParts(
          scheduleDateWithEstimate,
        );
        const eHourStr =
          timePartsEstimate.find((p) => p.type === "hour")?.value || "00";
        const eMinuteStr =
          timePartsEstimate.find((p) => p.type === "minute")?.value || "00";
        const eHour24 = eHourStr === "24" ? "00" : eHourStr;
        const eTimeStr = `${eHour24}:${eMinuteStr}`;

        const eWeekdayStr =
          formatterDay
            .formatToParts(scheduleDateWithEstimate)
            .find((p) => p.type === "weekday")?.value || "";

        if (eWeekdayStr !== weekdayStr || eTimeStr > todayCloseTime) {
          throw new HttpError(400, "orders:errors.outside_working_hours");
        }
      }

      // sup-step: check max_orders from SupplierSlotMaxOrder (granular) and default_max_orders (fallback)
      const slotLimit = await tx.supplierSlotMaxOrder.findFirst({
        where: {
          store_address_id: storeAddress.id,
          day_of_week: dayOfWeek,
          time_from: { lte: timeStr },
          time_to: { gt: timeStr },
        },
        select: { max_orders: true, time_from: true, time_to: true },
      });
      const effectiveMax =
        slotLimit?.max_orders ?? storeAddress.default_max_orders;
      if (typeof effectiveMax === "number") {
        // Count existing scheduled orders on the same date
        const startOfDay = new Date(scheduleDate);
        startOfDay.setUTCHours(0, 0, 0, 0);
        const endOfDay = new Date(scheduleDate);
        endOfDay.setUTCHours(23, 59, 59, 999);
        const existingOrders = await tx.order.findMany({
          where: {
            supplier_id: storeAddress.supplier_id,
            supplier_store_address_id: storeAddress.id,
            status: "SCHEDULED",
            is_order_scheduled: true,
            order_schedule_at: { gte: startOfDay, lte: endOfDay },
          },
          select: { order_schedule_at: true },
        });
        let ordersInRange = 0;
        for (const ord of existingOrders) {
          if (!ord.order_schedule_at) continue;
          if (slotLimit) {
            // Granular: count only orders within the matched sub-interval's time_from–time_to
            const oTimeParts = formatterTime.formatToParts(
              ord.order_schedule_at,
            );
            const oHour =
              oTimeParts.find((p) => p.type === "hour")?.value || "00";
            const oMin =
              oTimeParts.find((p) => p.type === "minute")?.value || "00";
            const oHour24 = oHour === "24" ? "00" : oHour;
            const oTimeStr = `${oHour24}:${oMin}`;
            if (
              oTimeStr >= slotLimit.time_from &&
              oTimeStr < slotLimit.time_to
            ) {
              ordersInRange++;
            }
          } else {
            // Fallback: default_max_orders applies to the whole day
            ordersInRange++;
          }
        }
        if (ordersInRange >= effectiveMax) {
          throw new HttpError(400, "orders:errors.slot_full");
        }
      }
    }

    // 1. Validate cart items
    const { supplierId, orderItems, productsTotal, totalCostPrice } =
      await resolveCartForOrder(tx, cart.id);

    // 1.1 Enforce the supplier's minimum order value for every catalog order
    // (applies to both ASAP and scheduled orders, before any costly work).
    const supplier = await tx.supplier.findUnique({
      where: { id: supplierId },
      select: { min_price_for_one_order: true, max_price_for_one_order: true },
    });
    const minPriceForOneOrder = supplier?.min_price_for_one_order
      ? Number(supplier.min_price_for_one_order)
      : 0;
    const maxPriceForOneOrder = supplier?.max_price_for_one_order
      ? Number(supplier.max_price_for_one_order)
      : 0;
    if (productsTotal < minPriceForOneOrder) {
      throw new HttpError(
        400,
        "orders:errors.products_total_too_low",
        undefined,
        {
          min_price_for_one_order: minPriceForOneOrder / 100,
        },
      );
    }
    if (productsTotal > maxPriceForOneOrder) {
      throw new HttpError(
        400,
        "orders:errors.products_total_too_high",
        undefined,
        {
          max_price_for_one_order: maxPriceForOneOrder / 100,
        },
      );
    }

    // 2. Resolve supplier store pickup address
    const pickup = await resolveSupplierPickupAddress(tx, supplierId);

    const delivery = await resolveDeliveryAddress(
      tx,
      customerId,
      input.customer_address_id,
    );

    // 3. Distance + vehicle matching
    const { distance } = await getRoadDistanceM(
      { lat: pickup.lat, lng: pickup.long },
      { lat: delivery.deliveryLat, lng: delivery.deliveryLong },
    );

    console.log("Distance + vehicle matching", distance);

    const vehicles = await selectVehiclesForDistance(distance);

    const estimatedFee = await computeEstimatedFeeSplit(tx, {
      distanceM: distance,
      vehicleId: vehicles[0].id,
      vehicle: vehicles[0],
      vatRate: Decimal(settings?.vat ?? 0).div(100),
      minPlatformFee: Decimal(settings?.min_platform_fee ?? 0),
    });

    const fullOrderCents =
      productsTotal + estimatedFee.totalFeeWithVat.toNumber();

    console.log(
      "[ORDER] productsTotal:",
      productsTotal,
      "| fullOrderCents:",
      fullOrderCents,
    );
    console.log("====== /CATALOG ORDER — Fee Calculation ======\n");

    // 5. Coupon — passes VAT-inclusive delivery fee so scope calculations are correct
    let appliedCoupon: {
      couponId: number;
      discountCents: number;
      payableCents: number;
    } | null = null;

    if (input.coupon_code?.trim()) {
      appliedCoupon = await validateOrderCouponForCreate(tx, {
        userId: customerId,
        code: input.coupon_code,
        budgetCents: productsTotal,
        estimatedDeliveryFeeCents: +estimatedFee.courierFee,
        orderType: "CATALOG_PURCHASE",
      });
    }

    const holdCents =
      appliedCoupon !== null && appliedCoupon !== undefined
        ? appliedCoupon.payableCents + estimatedFee.platformFee.toNumber()
        : fullOrderCents;

    // 6. Payment hold
    let walletId: number | null = null;
    if (input.payment_method === "WALLET") {
      const wallet = await tx.wallet.findUnique({
        where: { user_id: customerId },
        select: { id: true, balance: true, status: true },
      });

      if (!wallet) throw new HttpError(404, "wallet:errors.not_found");
      if (wallet.status !== "ACTIVE")
        throw new HttpError(409, "wallet:errors.wallet_not_active");
      if (wallet.balance < holdCents)
        throw new HttpError(400, "orders:errors.insufficient_wallet_balance");

      await adjustWalletBalance(tx, wallet.id, -holdCents, {
        customer_coupon_id: appliedCoupon?.couponId,
      });

      walletId = wallet.id;
    }
    // CARD: no wallet deduction here — payment gateway handles it async

    // 7. Deduct stock (rolls back on any failure above)
    await deductStock(tx, orderItems);

    // 8. Create order — store VAT-inclusive fee and vatAmount immediately
    const proposalMinutes = settings?.proposal_waiting_time_minutes ?? 5;
    const expirationMinutes = settings?.order_expiration_time_minutes ?? 15;
    const now = new Date();
    const proposalsDeadline = new Date(
      now.getTime() + proposalMinutes * 60_000,
    );
    const expiresAt = new Date(now.getTime() + expirationMinutes * 60_000);

    // 8.0: calculate order direction depend on supplier
    const orderDirection = calculateOrderDirectionDependOnSupplier(
      pickup.lat,
      pickup.long,
      delivery.deliveryLat,
      delivery.deliveryLong,
    );

    // 8.1: step: check if order is scheduled
    let isScheduled = false;
    let order;
    // loop on orderItems and check if any item has estimated_time_from>0
    for (const item of orderItems) {
      if (item.estimated_time_from && item.estimated_time_from > 0) {
        isScheduled = true;
        break;
      }
    }

    // sup-step: get bigest estimated_time_to value of order items
    let maxEstimatedTimeToAsap = 0;
    for (const item of orderItems) {
      const t = item.estimated_time_to ?? item.estimated_time_from ?? 0;
      if (t > maxEstimatedTimeToAsap) {
        maxEstimatedTimeToAsap = t;
      }
    }

    // sup-step: check if current date and time + bigest estimated_time_to value <= closed time of today shift
    if (!input.is_order_scheduled && maxEstimatedTimeToAsap > 0) {
      const pickupStore = await tx.supplierStoreAddress.findUnique({
        where: { id: pickup.storeAddressId },
        select: { working_hours: true },
      });
      const wh = pickupStore?.working_hours as any;
      const tz = wh?.timezone || "Africa/Cairo";

      const formatterTime = new Intl.DateTimeFormat("en-US", {
        timeZone: tz,
        hour: "2-digit",
        minute: "2-digit",
        hour12: false,
      });
      const formatterDay = new Intl.DateTimeFormat("en-US", {
        timeZone: tz,
        weekday: "short",
      });

      const cairoWeekdayStr =
        formatterDay.formatToParts(now).find((p) => p.type === "weekday")
          ?.value || "";
      const cairoTimeParts = formatterTime.formatToParts(now);
      const cHourStr =
        cairoTimeParts.find((p) => p.type === "hour")?.value || "00";
      const cMinuteStr =
        cairoTimeParts.find((p) => p.type === "minute")?.value || "00";
      const cTimeStr = `${cHourStr === "24" ? "00" : cHourStr}:${cMinuteStr}`;

      const dayMap: Record<string, number> = {
        Sun: 0,
        Mon: 1,
        Tue: 2,
        Wed: 3,
        Thu: 4,
        Fri: 5,
        Sat: 6,
      };
      const dayOfWeek = dayMap[cairoWeekdayStr];

      let todayCloseTime: string | null = null;
      if (wh?.days) {
        const dayObj = wh.days[String(dayOfWeek)];
        if (dayObj && !dayObj.is_closed && Array.isArray(dayObj.slots)) {
          const withinSlot = dayObj.slots.find(
            (s: any) => cTimeStr >= s.open && cTimeStr < s.close,
          );
          if (withinSlot) {
            todayCloseTime = withinSlot.close;
          }
        }
      }

      if (todayCloseTime) {
        const targetDate = new Date(
          now.getTime() + maxEstimatedTimeToAsap * 60000,
        );

        const timePartsEstimate = formatterTime.formatToParts(targetDate);
        const eHourStr =
          timePartsEstimate.find((p) => p.type === "hour")?.value || "00";
        const eMinuteStr =
          timePartsEstimate.find((p) => p.type === "minute")?.value || "00";
        const eHour24 = eHourStr === "24" ? "00" : eHourStr;
        const eTimeStr = `${eHour24}:${eMinuteStr}`;

        const eWeekdayStr =
          formatterDay
            .formatToParts(targetDate)
            .find((p) => p.type === "weekday")?.value || "";

        if (eWeekdayStr !== cairoWeekdayStr || eTimeStr > todayCloseTime) {
          throw new HttpError(400, "orders:errors.outside_working_hours");
        }
      }
    }

    // Strip fields that don't exist in the Prisma OrderItem model yet
    const prismaOrderItems = orderItems.map(
      ({ estimated_time_from, estimated_time_to, ...rest }) => rest,
    );

    // 8.2: create scheduled catalog order and order delivery date and time
    order = await tx.order.create({
      data: {
        type: "CATALOG_PURCHASE",
        customer_id: customerId,
        supplier_id: supplierId,
        cart_id: cart.id,
        order_number: genOrderNumber(),
        payment_method: input.payment_method,
        products_total: productsTotal,
        total_cost_price: totalCostPrice, // <-- Save the total cost here
        actual_price: productsTotal,
        courier_fee: estimatedFee.courierFee.toNumber(),
        platform_fee:
          estimatedFee.platformFee.toNumber() +
          (productsTotal - totalCostPrice),
        total_fee: estimatedFee.totalFeeWithVat.toNumber(), // Now includes VAT
        vat_amount: estimatedFee.vatAmount.toNumber(),
        coupon_id: appliedCoupon?.couponId,
        discount_amount: appliedCoupon?.discountCents ?? 0,
        payable_amount: holdCents,
        pickup_area_id: pickup.areaId,
        pickup_address_description: pickup.address,
        pickup_lat: pickup.lat,
        pickup_long: pickup.long,
        delivery_area_id: delivery.deliveryAreaId,
        delivery_address_description: delivery.deliveryAddressDescription,
        delivery_lat: delivery.deliveryLat,
        delivery_long: delivery.deliveryLong,
        distance_m: distance,
        // TODO: order delivery date and time
        status:
          input.payment_method === "CARD"
            ? "PENDING_PAYMENT"
            : input.is_order_scheduled
              ? "SCHEDULED"
              : "PENDING",
        proposals_deadline_at: proposalsDeadline,
        expires_at: expiresAt,
        is_fixed_fee: true,
        confirmation_otp: generateOtp(4),
        orderItems: { createMany: { data: prismaOrderItems } },
        order_direction_depend_on_supplier: orderDirection,
        // For scheduled orders (product-level scheduling)
        is_scheduled: isScheduled ? true : false,
        // CARD orders start as PENDING_PAYMENT — webhook confirms and moves to PENDING/SCHEDULED.
        // IMPORTANT: non-scheduled orders MUST have is_ready_for_pickup=false
        // so the courier availableOrders filter can find them.
        // Filter expects: (is_scheduled=false, is_ready_for_pickup=false)
        //             OR: (is_scheduled=true, is_ready_for_pickup=true)
        is_ready_for_pickup: false,
        // Order-level scheduling
        is_order_scheduled: input.is_order_scheduled,
        order_schedule_at: input.order_schedule_at,
        supplier_store_address_id: input.supplier_store_address_id,
      },
    });
    if (!order) {
      throw new Error("Order was not created - this should not happen");
    }

    // 9. Coupon usage slot
    if (appliedCoupon) {
      await tx.customerCouponUsage.create({
        data: {
          user_id: customerId,
          coupon_id: appliedCoupon.couponId,
          context: "ORDER",
          order_id: order.id,
          discount_cents: appliedCoupon.discountCents,
        },
      });
    }

    // 10. Wallet escrow (CARD orders skip this — no wallet involved)
    if (walletId !== null) {
      const escrow = await tx.escrow.create({
        data: {
          order_id: order.id,
          wallet_id: walletId,
          held_amount: holdCents,
        },
      });

      await tx.transaction.create({
        data: {
          wallet_id: walletId,
          order_id: order.id,
          escrow_id: escrow.id,
          type: "ESCROW_HOLD",
          status: "COMPLETED",
          amount: holdCents,
          description: `Hold for catalog order ${order.order_number}`,
        },
      });
    }

    // 11. Clear cart — skipped for CARD: cart is cleared AFTER the payment gateway
    //     responds successfully (outside this transaction), so that if the gateway
    //     call fails the user's cart is still intact and they can retry.
    //     For WALLET / COD the cart is cleared here as before.
    if (input.payment_method !== "CARD") {
      await tx.cartItem.deleteMany({ where: { cart_id: cart.id } });
      await tx.cart.update({
        where: { id: cart.id },
        data: { total_price: 0 },
      });
    }

    return {
      order,
      vehicles,
      distance,
      supplierId,
      holdCents,
      vatAmount: estimatedFee.vatAmount,
      totalFeeWithVat: estimatedFee.totalFeeWithVat,
      // Carried out for CARD stock-restoration on gateway failure
      stockSnapshot: prismaOrderItems.map((i) => ({
        sp_id: i.sp_id,
        quantity: i.quantity,
      })),
    };
  });

  // ── CARD: initiate payment gateway ──────────────────────────────────────────
  // bus.emit is deferred until the payment webhook confirms — see order-payment.handler.ts.
  // Cart is intentionally left intact: it is only cleared once the payment webhook
  // confirms a successful payment (see activateOrder in order-payment.handler.ts).
  // If the user abandons checkout, the cart remains so they can retry.
  if (input.payment_method === "CARD") {
    if (!ctx) throw new HttpError(500, "orders:errors.payment_init_failed");

    // payable_amount is stored on the order (holds the pre-computed amount in cents)
    const amountCents = Math.round(Number(order.payable_amount ?? 0));

    let cardPayment: {
      provider: string;
      transactionId: number;
      checkoutUrl: string;
    };
    try {
      cardPayment = await initiateOrderPayment({
        userId: customerId,
        orderId: order.id,
        amountCents,
        orderNumber: order.order_number,
        user: ctx.user,
        provider: input.card_provider ?? "paymob",
        lang: ctx.lang,
        redirectionUrl: input.card_redirection_url,
        paymobWebhookUrl: ctx.paymobWebhookUrl,
        kashierWebhookUrl: ctx.kashierWebhookUrl,
        easykashWebhookUrl: ctx.easykashWebhookUrl,
      });
    } catch (err) {
      // Gateway init failed after order & stock were committed.
      // Roll back manually: restore stock, cancel order.
      // Cart was intentionally NOT cleared for CARD — it remains intact so user can retry.
      await prisma.$transaction([
        ...stockSnapshot.map((item) =>
          prisma.supplierProduct.update({
            where: { id: item.sp_id },
            data: { stock: { increment: item.quantity } },
          }),
        ),
        prisma.order.update({
          where: { id: order.id },
          data: { status: "CANCELLED" },
        }),
      ]);
      throw err;
    }

    // Gateway responded — user is on checkout page; clear cart now.
    // await prisma.$transaction([
    //   prisma.cartItem.deleteMany({ where: { cart_id: cartId } }),
    //   prisma.cart.update({ where: { id: cartId }, data: { total_price: 0 } }),
    // ]);

    return { order, cardPayment };
  }

  // WALLET / COD — emit courier dispatch event immediately
  bus.emit("order.created", {
    orderId: order.id,
    deliveryAreaId: order.delivery_area_id!,
    createdAt: new Date().toISOString(),
    customerId: order.customer_id!,
    budget: Number(order.products_total ?? 0),
    pickupAreaId: order.pickup_area_id!,
    vehicleIds: vehicles.map((v) => v.id),
    distanceM: distance,
    proposalsDeadline: order.proposals_deadline_at!.toISOString(),
    expiresAt: order.proposals_deadline_at!.toISOString(),
    // FIXED_FEE mode — couriers cannot negotiate; the VAT-inclusive fee is set
    mode: "FIXED_FEE",
    total_fee: totalFeeWithVat.toNumber(),
    type: "CATALOG_PURCHASE",
    supplierId,
    isFixedFee: true,
    pickupLat: +order.pickup_lat!,
    pickupLng: +order.pickup_long!,
    isScheduled: order.is_scheduled,
  });

  return { order };
}

// ─── preview catalog order service ─────────────────────────────────────────────────────
export async function previewOrderService(
  input: CreateOrderInput, // Use the union type
  customerId: number,
) {
  const settings = await prisma.applicationSetting.findFirst({
    select: { vat: true, min_platform_fee: true },
  });

  const vatRate = Decimal(settings?.vat ?? 0).div(100);
  const minPlatformFee = Decimal(settings?.min_platform_fee ?? 0);

  return prisma
    .$transaction(async (tx) => {
      let productsTotal = 0;
      let pickupCoords: { lat: number; lng: number };
      let deliveryCoords: { lat: number; lng: number };
      let deliveryAreaId: number;
      let deliveryDescription: string;
      let itemCount = 0;

      // --- BRANCH LOGIC BY TYPE ---
      if (input.type === "CATALOG_PURCHASE") {
        const cart = await tx.cart.findUnique({ where: { id: customerId } });
        if (!cart) throw new HttpError(400, "orders:errors.cart_empty");

        const {
          supplierId,
          orderItems,
          productsTotal: resolvedTotal,
        } = await resolveCartForOrder(tx, cart.id);

        const pickup = await resolveSupplierPickupAddress(tx, supplierId);
        const delivery = await resolveDeliveryAddress(
          tx,
          customerId,
          input.customer_address_id,
        );

        productsTotal = resolvedTotal;
        itemCount = orderItems.reduce((s, i) => s + i.quantity, 0);
        pickupCoords = { lat: pickup.lat, lng: pickup.long };
        deliveryCoords = {
          lat: delivery.deliveryLat,
          lng: delivery.deliveryLong,
        };
        deliveryAreaId = delivery.deliveryAreaId;
        deliveryDescription = delivery.deliveryAddressDescription;
      } else {
        // CUSTOM_PICKUP
        productsTotal = input.budget;
        itemCount = 1; // Custom orders treated as 1 package
        pickupCoords = { lat: +input.pickup_lat, lng: +input.pickup_long };
        deliveryCoords = {
          lat: +input.delivery_lat,
          lng: +input.delivery_long,
        };
        deliveryAreaId = input.delivery_area_id;
        deliveryDescription = input.delivery_address_description;
      }

      // --- COMMON CALCULATION LOGIC ---
      const { distance } = await getRoadDistanceM(pickupCoords, deliveryCoords);
      const vehicles = await selectVehiclesForDistance(distance);

      // Use the first available vehicle for estimate
      const estimatedFee = await computeEstimatedFeeSplit(tx, {
        distanceM: distance,
        vehicleId: vehicles[0].id,
        vehicle: vehicles[0],
        vatRate,
        minPlatformFee,
      });

      const fullOrderCents =
        productsTotal + estimatedFee.totalFeeWithVat.toNumber();

      // Coupon Validation (Dry Run)
      let appliedCoupon: {
        couponId: number;
        discountCents: number;
        payableCents: number;
      } | null = null;
      if (input.coupon_code?.trim()) {
        appliedCoupon = await validateOrderCouponForCreate(tx, {
          userId: customerId,
          code: input.coupon_code,
          budgetCents: productsTotal,
          estimatedDeliveryFeeCents: estimatedFee.totalFeeWithVat.toNumber(),
          orderType: input.type,
        });
      }

      const payableCents = appliedCoupon?.payableCents ?? fullOrderCents;

      // Return the preview shape
      throw new PreviewSignal(
        buildPreviewShape({
          productsTotal,
          deliveryFee: +estimatedFee.totalFeeWithVat - +estimatedFee.vatAmount,
          vatAmount: estimatedFee.vatAmount.toNumber(),
          totalFee: estimatedFee.totalFeeWithVat.toNumber(),
          courierFee: +estimatedFee.courierFee,
          platformFee: +estimatedFee.platformFee,
          discountAmount: appliedCoupon?.discountCents ?? 0,
          couponId: appliedCoupon?.couponId ?? null,
          payableAmount: payableCents,
          distanceM: distance,
          itemCount,
          deliveryAddress: {
            areaId: deliveryAreaId,
            description: deliveryDescription,
            lat: deliveryCoords.lat,
            long: deliveryCoords.lng,
          },
        }),
      );
    })
    .catch((err) => {
      if (err instanceof PreviewSignal) return err.data;
      throw err;
    });
}

// Sentinel — carry preview data out of the transaction rollback
class PreviewSignal {
  constructor(public readonly data: ReturnType<typeof buildPreviewShape>) {}
}

// Helper so TypeScript infers the return shape from one place
function buildPreviewShape(data: {
  productsTotal: number;
  deliveryFee: number;
  vatAmount: number;
  totalFee: number;

  // ✅ ADD THESE
  courierFee: number;
  platformFee: number;

  discountAmount: number;
  couponId: number | null;
  payableAmount: number;
  distanceM: number;
  itemCount: number;
  deliveryAddress: {
    areaId: number;
    description: string;
    lat: number;
    long: number;
  };
}) {
  return data;
}

// ─── Calculate order direction depend on supplier ─────────────────────────────────
function calculateOrderDirectionDependOnSupplier(
  pickup_lat: number,
  pickup_long: number,
  delivery_lat: number,
  delivery_long: number,
) {
  // Bearing from pickup → delivery mapped to:
  // 1: East, 2: West, 3: North, 4: South
  // 5: Northeast, 6: Northwest, 7: Southeast, 8: Southwest
  const φ1 = (pickup_lat * Math.PI) / 180;
  const φ2 = (delivery_lat * Math.PI) / 180;
  const Δλ = ((delivery_long - pickup_long) * Math.PI) / 180;

  const y = Math.sin(Δλ) * Math.cos(φ2);
  const x =
    Math.cos(φ1) * Math.sin(φ2) - Math.sin(φ1) * Math.cos(φ2) * Math.cos(Δλ);
  const bearingDeg = ((((Math.atan2(y, x) * 180) / Math.PI) % 360) + 360) % 360;

  if (bearingDeg >= 337.5 || bearingDeg < 22.5) return 3; // North
  if (bearingDeg < 67.5) return 5; // Northeast
  if (bearingDeg < 112.5) return 1; // East
  if (bearingDeg < 157.5) return 7; // Southeast
  if (bearingDeg < 202.5) return 4; // South
  if (bearingDeg < 247.5) return 8; // Southwest
  if (bearingDeg < 292.5) return 2; // West
  return 6; // Northwest
}

// ─── Customer: available type-3 delivery slots for the cart ───────────────────

// step: claude: intersect two lists of [from,to] intervals, returning their overlapping sub-intervals
function intersectIntervals(
  a: Array<{ from: string; to: string }>,
  b: Array<{ from: string; to: string }>,
): Array<{ from: string; to: string }> {
  const out: Array<{ from: string; to: string }> = [];
  for (const x of a) {
    for (const y of b) {
      const from = x.from > y.from ? x.from : y.from;
      const to = x.to < y.to ? x.to : y.to;
      if (from < to) out.push({ from, to });
    }
  }
  return out;
}

// step: claude: return selectable delivery slots (with remaining capacity) for the type-3 products in the customer's cart on a given date
export async function getCartDeliverySlotsService(
  customerId: number,
  date: Date,
) {
  // step: claude: collect the cart's type-3 products
  const cartItems = await prisma.cartItem.findMany({
    where: {
      cart_id: customerId,
      supplierProduct: { requires_delivery_windows: true },
    },
    select: { sp_id: true },
  });
  const spIds = [...new Set(cartItems.map((c) => c.sp_id))];

  if (spIds.length === 0) {
    return { is_scheduled_windows: false, date, slots: [] };
  }

  const dayOfWeek = dowInTz(date);

  // step: claude: load each product's DELIVERY windows for that day-of-week
  const perProductWindows = await Promise.all(
    spIds.map(async (spId) => {
      const windows = await prisma.supplierProductDeliveryWindow.findMany({
        where: {
          supplier_product_id: spId,
          window_type: "DELIVERY",
          day_of_week: dayOfWeek,
        },
        select: { time_from: true, time_to: true, max_orders: true },
      });
      return { spId, windows };
    }),
  );

  // step: claude: a product with no delivery window for that day means no common slot exists
  if (perProductWindows.some((p) => p.windows.length === 0)) {
    return { is_scheduled_windows: true, date, slots: [] };
  }

  // step: claude: intersect all products' windows so the slot is deliverable for every type-3 product
  let intervals = perProductWindows[0].windows.map((w) => ({
    from: w.time_from,
    to: w.time_to,
  }));
  for (let i = 1; i < perProductWindows.length; i++) {
    intervals = intersectIntervals(
      intervals,
      perProductWindows[i].windows.map((w) => ({
        from: w.time_from,
        to: w.time_to,
      })),
    );
    if (intervals.length === 0) break;
  }

  // step: claude: for each overlapping slot compute remaining capacity = min across products
  const slots: Array<{
    time_from: string;
    time_to: string;
    remaining: number | null;
  }> = [];
  for (const interval of intervals) {
    let remaining: number | null = null; // null = unlimited
    for (const { spId, windows } of perProductWindows) {
      // the product window that covers this overlap
      const covering = windows.find(
        (w) => w.time_from <= interval.from && w.time_to >= interval.to,
      );
      if (!covering || covering.max_orders == null) continue;
      const used = await countScheduledInDeliveryWindow(
        prisma,
        spId,
        date,
        covering.time_from,
        covering.time_to,
      );
      const productRemaining = covering.max_orders - used;
      remaining =
        remaining == null
          ? productRemaining
          : Math.min(remaining, productRemaining);
    }
    if (remaining == null || remaining > 0) {
      slots.push({
        time_from: interval.from,
        time_to: interval.to,
        remaining,
      });
    }
  }

  return { is_scheduled_windows: true, date, slots };
}
