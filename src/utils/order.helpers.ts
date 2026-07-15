import {
  Offer,
  Order,
  OrderItem,
  Prisma,
  SupplierProduct,
} from "@prisma/client";
import { parseProductImages } from "./productImages";
import { AppError } from "../core/errors/app.error";
import { HttpStatusCode } from "../core/http/http.status.code";
import { prisma } from "../DB/lib/prisma";
import { env } from "../config/env";

export interface ResolvedSP {
  id: number;
  supplier_id: number;
  price: number | null;
  stock: number;
  is_active: boolean;
  product_id: number;
  activeOffer: Pick<Offer, "id" | "offer_type" | "offer_value"> | null;
}

export function calcEffectivePrice(
  price: number | null,
  offer: ResolvedSP["activeOffer"],
): number {
  const base = price ?? 0;
  if (!offer?.offer_type || offer.offer_value == null) return base;

  if (offer.offer_type === "PERCENT") {
    return Math.max(0, base - (base * Number(offer.offer_value)) / 100);
  }

  if (offer.offer_type === "FIXED_CENTS") {
    return Math.max(0, base - Number(offer.offer_value));
  }

  return base;
}

export function activeOfferWhere() {
  const now = new Date();
  return {
    is_active: true,
    deleted_at: null,
    start_date: { lte: now },
    end_date: { gte: now },
  };
}

export function buildSupplierProductPricing(
  sp: SupplierProduct,
  offer: Offer | null,
) {
  const originalPrice = sp.price ?? 0;
  const unitPrice = calcEffectivePrice(originalPrice, offer);

  return {
    ...sp,
    original_price: originalPrice,
    unit_price: unitPrice,
    active_offer: offer,
  };
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

export const orderItemInclude = {
  supplierProduct: {
    include: {
      product: true,
      offers: {
        where: activeOfferWhere(),
        take: 1,
      },
    },
  },
} satisfies Prisma.OrderItemInclude;

export async function confirmDeliveryAdminApi(input: {
  order_id: number;
  courier_id: number;
  token: string;
}) {
  try {
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), 10000);

    const response = await fetch(
      `${env.ADMIN_API_BASE_URL}/orders/confirm-delivery`,
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          // Add auth if needed
          Authorization: `Bearer ${input.token}`,
        },
        body: JSON.stringify(input),
        signal: controller.signal,
      },
    );

    clearTimeout(timeoutId);

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}));
      throw new Error(
        `Request failed with status ${response.status} ${errorData.toString()}`,
      );
    }

    return await response.json();
  } catch (error: any) {
    // Note: If using a custom AppError class, ensure it handles the error structure
    throw new AppError(
      HttpStatusCode.BAD_REQUEST,
      "Failed to confirm delivery with admin service",
      error?.message || error,
    );
  }
}

export async function restoreStockIfCatalog(
  tx: Prisma.TransactionClient,
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

export async function handleOrderReversal(
  tx: Prisma.TransactionClient,
  order: Order,
) {
  // coupons
  if (order.coupon_id) {
    await tx.customerCouponUsage.deleteMany({
      where: {
        order_id: order.id,
        coupon_id: order.coupon_id,
        context: "ORDER",
      },
    });
  }

  // stock
  await restoreStockIfCatalog(tx, order);
}

export async function refundCustomerWallet(
  tx: Prisma.TransactionClient,
  order: Order,
  reason: string,
) {
  if (order.payment_method !== "WALLET") return;

  const wallet = await tx.wallet.findUnique({
    where: { user_id: order.customer_id! },
  });

  if (!wallet) return;

  const escrow = await tx.escrow.findFirst({
    where: {
      order_id: order.id,
      wallet_id: wallet.id,
    },
    orderBy: { created_at: "desc" },
  });

  if (!escrow) return;

  const amount = Number(escrow.held_amount);

  if (amount > 0) {
    await tx.wallet.update({
      where: { id: wallet.id },
      data: { balance: { increment: amount } },
    });

    await tx.transaction.create({
      data: {
        wallet_id: wallet.id,
        order_id: order.id,
        escrow_id: escrow.id,
        type: "ESCROW_REMOVE",
        amount,
        status: "COMPLETED",
        description: reason,
      },
    });
  }

  await tx.escrow.update({
    where: { id: escrow.id },
    data: { held_amount: 0 },
  });
}

export async function updateCourierLocation(
  courierId: number,
  lat: number,
  lng: number,
) {
  return prisma.courier.update({
    where: { id: courierId },
    data: {
      lat,
      lng,
      last_location_update: new Date(),
    },
  });
}
