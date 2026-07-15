import { prisma } from "@/config/prisma";
import { HttpError } from "@/lib/httpError";
import { parseProductImages } from "@/lib/productImages";
import type { CartItemCreateInput, CartItemUpdateInput } from "./cart.schema";
import type FeatureApi from "@/lib/featureApi";
import { Tx } from "@/types/prisma.types";
import { CartItem, DiscountType, Prisma } from "@prisma/client";
import {
  activeOfferWhere,
  buildSupplierProductPricing,
  calcEffectivePrices,
  ResolvedSP,
  resolveSupplierProductWithAddress,
} from "@/lib/catalogHelpers";
import { Decimal } from "@prisma/client/runtime/client";

function buildCartItemInclude() {
  return {
    supplierProduct: {
      include: {
        product: true,
        offers: {
          where: activeOfferWhere(),
          take: 1,
        },
      },
    },
  };
}

function formatCartItem(
  item: CartItem & {
    supplierProduct: Prisma.SupplierProductGetPayload<{
      include: { offers: true; product: true };
    }>;
  },
) {
  const { supplierProduct, ...cartFields } = item;
  const { product, offers, ...spFields } = supplierProduct;
  const activeOffer = offers?.[0] ?? null;
  const pricing = buildSupplierProductPricing(spFields, activeOffer);
  return {
    ...cartFields,
    supplier_product: pricing,
    product: parseProductImages(product),
    line_total: pricing.unit_price * item.quantity,
  };
}

// ─── syncCartTotal (incremental) ──────────────────────────────────────────────
// Instead of re-fetching all items, adjust the stored total by a delta.
// Pass a positive delta when adding/increasing, negative when removing/decreasing.
async function adjustCartTotal(tx: Tx, cartId: number, delta: number) {
  if (delta === 0) return;
  await tx.cart.update({
    where: { id: cartId },
    data: { total_price: { increment: delta } },
  });
}

// Full recalc — only used when we genuinely can't compute a delta
// (e.g. after removeItem where we don't have the item's price handy)
async function syncCartTotal(tx: Tx, cartId: number): Promise<number> {
  const items = await tx.cartItem.findMany({
    where: { cart_id: cartId },
    include: {
      supplierProduct: {
        include: { offers: { where: activeOfferWhere(), take: 1 } },
      },
    },
  });

  const total = items.reduce((sum, item) => {
    const sp = item.supplierProduct;
    // UPDATED: Now uses the new price logic
    const { finalUnitPrice } = calcEffectivePrices(
      sp.price ?? 0,
      sp.cost_price ?? 0,
      sp.offers[0] ?? null,
    );
    return sum + finalUnitPrice * item.quantity;
  }, 0);

  await tx.cart.update({ where: { id: cartId }, data: { total_price: total } });
  return total;
}

// ─── ensureCart ───────────────────────────────────────────────────────────────

export async function ensureCart(userId: number) {
  const id = Number(userId);
  if (!id || Number.isNaN(id))
    throw new HttpError(401, "cart:errors.invalid_user");

  // findUnique is cheaper than upsert when the row almost always exists
  const existing = await prisma.cart.findUnique({ where: { id } });
  if (existing) return existing;

  return prisma.cart.create({ data: { id, total_price: 0 } });
}

// ─── resolveSupplierProduct ───────────────────────────────────────────────────

async function resolveSupplierProduct(
  tx: Tx,
  spId: number,
): Promise<ResolvedSP> {
  const sp = await tx.supplierProduct.findUnique({
    where: { id: spId },
    select: {
      id: true,
      supplier_id: true,
      price: true,
      cost_price: true,
      stock: true,
      is_active: true,
      product_id: true,
      requires_delivery_windows: true,
      product: { select: { deleted_at: true } },
      offers: {
        where: activeOfferWhere(),
        select: {
          id: true,
          offer_type: true,
          offer_value: true,
          created_by_role: true,
        },
        take: 1,
      },
    },
  });

  if (!sp?.is_active || sp.product.deleted_at !== null)
    throw new HttpError(404, "cart:errors.product_not_available");
  if (sp.stock <= 0) throw new HttpError(400, "cart:errors.insufficient_stock");

  return {
    id: sp.id,
    supplier_id: sp.supplier_id,
    price: sp.price,
    cost_price: sp.cost_price,
    stock: sp.stock,
    is_active: sp.is_active,
    product_id: sp.product_id,
    requires_delivery_windows: sp.requires_delivery_windows,
    activeOffer: sp.offers[0] ?? null,
  };
}

// ─── Get cart ─────────────────────────────────────────────────────────────────
// Reads stored total_price — no recalculation on every GET.

export async function getCartService(
  userId: number,
  featureData?: FeatureApi["data"],
) {
  const cart = await ensureCart(userId);
  const take = Number(featureData?.take) || 10;
  const skip = Number(featureData?.skip) || 0;

  const cartItems = await prisma.cartItem.findMany({
    where: { cart_id: cart.id },
    include: buildCartItemInclude(),
    ...(featureData?.orderBy ? { orderBy: featureData.orderBy } : {}),
    take,
    skip,
  });

  const formatted = cartItems.map(formatCartItem);

  // A cart only ever holds items from a single supplier (enforced on add).
  // Surface that supplier's order-value limits so the client can validate.
  const supplierId = cartItems[0]?.supplierProduct.supplier_id ?? null;
  const supplier =
    supplierId === null
      ? null
      : await prisma.supplier.findUnique({
          where: { id: supplierId },
          select: {
            min_price_for_one_order: true,
            max_price_for_one_order: true,
          },
        });

  // Use stored total for the summary — avoids recalc on every GET.
  // The stored value is kept in sync by add/update/clear operations.
  const summary = {
    itemCount: formatted.length,
    totalItems: formatted.reduce((sum, it) => sum + it.quantity, 0),
    totalPrice: Number(cart.total_price),
  };

  return { cart, items: formatted, summary, supplier };
}

// ─── Add item ─────────────────────────────────────────────────────────────────

export async function addCartItemService(
  userId: number,
  input: CartItemCreateInput,
) {
  const cart = await ensureCart(userId);
  const { sp_id, quantity } = input;

  const { cartItem, hasWarning } = await prisma.$transaction(async (tx) => {
    // ✅ NOW TRULY PARALLEL: SP+address in one query, existing cart check in another
    const [sp, existingItem] = await Promise.all([
      resolveSupplierProductWithAddress(tx, sp_id), // replaces 2 sequential queries
      tx.cartItem.findFirst({
        where: { cart_id: cart.id },
        select: {
          sp_id: true,
          quantity: true,
          supplierProduct: { select: { supplier_id: true } },
        },
      }),
    ]);

    if (
      existingItem &&
      existingItem.supplierProduct.supplier_id !== sp.supplier_id
    ) {
      throw new HttpError(
        400,
        "cart:errors.multiple_suppliers_not_allowed",
        "MULTIPLE_SUPPLIERS",
        {
          current_supplier_id: existingItem.supplierProduct.supplier_id,
          attempted_supplier_id: sp.supplier_id,
        },
      );
    }

    // step: check if supplier product requires_delivery_windows and in order_windows
    if (sp.requires_delivery_windows) {
      const now = new Date();
      const currentDay = now.getDay(); // 0 = Sunday … 6 = Saturday
      const currentTime =
        String(now.getHours()).padStart(2, "0") +
        ":" +
        String(now.getMinutes()).padStart(2, "0");

      const orderWindows = await tx.supplierProductDeliveryWindow.findMany({
        where: {
          supplier_product_id: sp.id,
          window_type: "ORDER",
          day_of_week: currentDay,
        },
      });

      if (orderWindows.length === 0) {
        throw new HttpError(400, "cart:errors.no_order_windows_today");
      }

      const inWindow = orderWindows.some(
        (w) => currentTime >= w.time_from && currentTime < w.time_to,
      );

      if (!inWindow) {
        const slots = orderWindows
          .map((w) => `${w.time_from}–${w.time_to}`)
          .join(", ");
        throw new HttpError(
          400,
          "cart:errors.outside_order_window",
          "OUTSIDE_ORDER_WINDOW",
          { available_slots: slots },
        );
      }
    }

    const { finalUnitPrice } = calcEffectivePrices(
      sp.price ?? 0,
      sp.cost_price ?? 0,
      sp.activeOffer,
    );
    const prevQty = existingItem?.sp_id === sp_id ? existingItem.quantity : 0;
    const rawNewQty = prevQty + quantity;
    const cappedQty = Math.min(rawNewQty, sp.stock);
    const hasWarning = rawNewQty > sp.stock;
    const delta = finalUnitPrice * (cappedQty - prevQty);
    // ✅ PARALLEL: upsert + adjust total simultaneously
    const [cartItem] = await Promise.all([
      tx.cartItem.upsert({
        where: { cart_id_sp_id: { cart_id: cart.id, sp_id } },
        create: { cart_id: cart.id, sp_id, quantity: cappedQty },
        update: { quantity: cappedQty },
        include: buildCartItemInclude(),
      }),
      adjustCartTotal(tx, cart.id, delta),
    ]);

    return { cartItem, hasWarning };
  });

  return { hasWarning, cartItem: formatCartItem(cartItem) };
}

// ─── Update item ──────────────────────────────────────────────────────────────

function calcNewQuantity(
  current: number,
  action: CartItemUpdateInput["action"],
  quantity: number,
): number {
  if (action === "increment") return current + quantity;
  if (action === "decrement") return current - quantity;
  return quantity;
}

export async function updateCartItemService(
  userId: number,
  input: CartItemUpdateInput,
) {
  const cart = await ensureCart(userId);
  const { sp_id, action, quantity } = input;

  const result = await prisma.$transaction(async (tx) => {
    const now = new Date();

    if (action === "increment" || action === "set") {
      // ✅ PARALLEL: fetch existing item and SP price/stock at the same time
      const [existing, sp] = await Promise.all([
        tx.cartItem.findUnique({
          where: { cart_id_sp_id: { cart_id: cart.id, sp_id } },
          select: { id: true, quantity: true },
        }),
        resolveSupplierProduct(tx, sp_id), // validates stock + active
      ]);

      if (!existing) throw new HttpError(404, "cart:errors.item_not_found");

      if (sp.requires_delivery_windows) {
        const now = new Date();
        const currentDay = now.getDay();
        const currentTime =
          String(now.getHours()).padStart(2, "0") +
          ":" +
          String(now.getMinutes()).padStart(2, "0");

        const orderWindows = await tx.supplierProductDeliveryWindow.findMany({
          where: {
            supplier_product_id: sp.id,
            window_type: "ORDER",
            day_of_week: currentDay,
          },
        });

        if (orderWindows.length === 0) {
          throw new HttpError(400, "cart:errors.no_order_windows_today");
        }

        const inWindow = orderWindows.some(
          (w) => currentTime >= w.time_from && currentTime < w.time_to,
        );

        if (!inWindow) {
          const slots = orderWindows
            .map((w) => `${w.time_from}–${w.time_to}`)
            .join(", ");
          throw new HttpError(
            400,
            "cart:errors.outside_order_window",
            "OUTSIDE_ORDER_WINDOW",
            { available_slots: slots },
          );
        }
      }

      if (action === "set" && quantity === 0) {
        const { finalUnitPrice } = calcEffectivePrices(
          sp.price ?? 0,
          sp.cost_price ?? 0,
          sp.activeOffer,
        );
        const delta = -(finalUnitPrice * existing.quantity);
        await Promise.all([
          tx.cartItem.delete({ where: { id: existing.id } }),
          adjustCartTotal(tx, cart.id, delta),
        ]);
        return { deleted: true as const };
      }

      const { finalUnitPrice } = calcEffectivePrices(
        sp.price ?? 0,
        sp.cost_price ?? 0,
        sp.activeOffer,
      );
      let newQty = calcNewQuantity(existing.quantity, action, quantity);
      newQty = Math.min(newQty, sp.stock);

      const delta = finalUnitPrice * (newQty - existing.quantity);

      const [updated] = await Promise.all([
        tx.cartItem.update({
          where: { id: existing.id },
          data: { quantity: newQty },
          include: buildCartItemInclude(),
        }),
        adjustCartTotal(tx, cart.id, delta),
      ]);

      return { deleted: false as const, cartItem: updated };
    }

    // decrement path — no stock validation needed
    // ✅ PARALLEL: fetch existing item and SP price at the same time
    const [existing, spPrice] = await Promise.all([
      tx.cartItem.findUnique({
        where: { cart_id_sp_id: { cart_id: cart.id, sp_id } },
        select: { id: true, quantity: true },
      }),
      tx.$queryRaw<
        {
          price: number | null;
          cost_price: number | null;
          offer_type: DiscountType | null;
          offer_value: Decimal | null;
          created_by_role: "ADMIN" | "SUPPLIER" | null; // <--- Add this
        }[]
      >`
        SELECT
          sp.price,
          sp.cost_price,
          o.offer_type,
          o.offer_value,
          o.created_by_role
        FROM supplier_product sp
        LEFT JOIN offer o
          ON  o.supplier_product_id = sp.id
          AND o.is_active  = 1
          AND o.deleted_at IS NULL
          AND o.start_date <= ${now}
          AND o.end_date   >= ${now}
        WHERE sp.id = ${sp_id}
        LIMIT 1
      `,
    ]);

    if (!existing) throw new HttpError(404, "cart:errors.item_not_found");

    const priceRow = spPrice[0];
    const { finalUnitPrice } = calcEffectivePrices(
      priceRow?.price ?? 0,
      priceRow?.cost_price ?? 0,
      priceRow?.offer_type
        ? {
            id: 0,
            offer_type: priceRow.offer_type,
            offer_value: priceRow.offer_value,
            created_by_role: priceRow.created_by_role, // CRITICAL
          }
        : null,
    );

    let newQty = calcNewQuantity(existing.quantity, action, quantity);

    if (newQty <= 0) {
      const delta = -(finalUnitPrice * existing.quantity);
      await Promise.all([
        tx.cartItem.delete({ where: { id: existing.id } }),
        adjustCartTotal(tx, cart.id, delta),
      ]);
      return { deleted: true as const };
    }

    const delta = finalUnitPrice * (newQty - existing.quantity);

    const [updated] = await Promise.all([
      tx.cartItem.update({
        where: { id: existing.id },
        data: { quantity: newQty },
        include: buildCartItemInclude(),
      }),
      adjustCartTotal(tx, cart.id, delta),
    ]);

    return { deleted: false as const, cartItem: updated };
  });

  if (result.deleted) return { deleted: true };
  return { deleted: false, cartItem: formatCartItem(result.cartItem) };
}

// ─── Clear cart ───────────────────────────────────────────────────────────────

export async function clearCartService(userId: number) {
  const cart = await ensureCart(userId);
  await prisma.$transaction(async (tx) => {
    await tx.cartItem.deleteMany({ where: { cart_id: cart.id } });
    await tx.cart.update({ where: { id: cart.id }, data: { total_price: 0 } });
  });
  return { ok: true as const };
}
