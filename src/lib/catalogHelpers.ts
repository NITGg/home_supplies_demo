import { Tx } from "@/types/prisma.types";
import { DiscountType, Offer, SupplierProduct } from "@prisma/client";
import { HttpError } from "./httpError";
import { logger } from "@/config/logger";
import { Decimal } from "@prisma/client/runtime/client";

export interface ResolvedSP {
  id: number;
  supplier_id: number;
  price: number | null;
  cost_price: number | null;
  stock: number;
  is_active: boolean;
  product_id: number;
  requires_delivery_windows: boolean;
  activeOffer: Pick<
    Offer,
    "id" | "offer_type" | "offer_value" | "created_by_role"
  > | null;
}

export function calcEffectivePrices(
  price: number,
  costPrice: number,
  offer: ResolvedSP["activeOffer"], // Use your Offer type here
) {
  let finalUnitPrice = price;
  let finalCostPrice = costPrice;

  if (!offer) return { finalUnitPrice, finalCostPrice };

  const discount =
    offer.offer_type === "PERCENT"
      ? (price * Number(offer.offer_value)) / 100
      : Number(offer.offer_value);

  const costDiscount =
    offer.offer_type === "PERCENT"
      ? (costPrice * Number(offer.offer_value)) / 100
      : Number(offer.offer_value);

  if (offer.created_by_role === "SUPPLIER") {
    // Supplier offer: Reduce BOTH selling price and cost price
    finalUnitPrice = Math.max(0, price - discount);
    finalCostPrice = Math.max(0, costPrice - costDiscount);
  } else if (offer.created_by_role === "ADMIN") {
    // Admin offer: Reduce only selling price
    // Restriction: Cannot sell below original cost price
    finalUnitPrice = Math.max(costPrice, price - discount);
    finalCostPrice = costPrice; // Cost remains the same for the platform
  }

  return { finalUnitPrice, finalCostPrice };
}

// Called per-request so new Date() is always fresh
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
  const costPrice = sp.cost_price ?? 0;
  const { finalCostPrice, finalUnitPrice } = calcEffectivePrices(
    originalPrice,
    costPrice,
    offer,
  );

  return {
    ...sp,
    original_price: originalPrice,
    original_cost_price: costPrice,
    unit_price: finalUnitPrice,
    unit_cost_price: finalCostPrice,
    active_offer: offer,
  };
}

type WorkingHours = {
  timezone: string;
  days: {
    [key: number]: {
      is_closed: boolean;
      slots: { open: string; close: string }[];
    };
  };
};

function isSupplierOpenNow(workingHours: WorkingHours): boolean {
  if (!workingHours) return false;

  const timezone = workingHours.timezone || "UTC";

  const now = new Date(
    new Date().toLocaleString("en-US", { timeZone: timezone }),
  );

  const day = now.getDay(); // 0–6
  const currentMinutes = now.getHours() * 60 + now.getMinutes();

  const today = workingHours.days?.[day];

  if (!today || today.is_closed) return false;

  return today.slots.some((slot: any) => {
    const [openH, openM] = slot.open.split(":").map(Number);
    const [closeH, closeM] = slot.close.split(":").map(Number);

    const openMinutes = openH * 60 + openM;
    const closeMinutes = closeH * 60 + closeM;

    return currentMinutes >= openMinutes && currentMinutes <= closeMinutes;
  });
}

// ─── Resolve supplier pickup address ─────────────────────────────────────────
interface ResolvedSupplierAddress {
  storeAddressId: number;
  lat: number;
  long: number;
  areaId: number | null;
  address: string;
}

export async function resolveSupplierPickupAddress(
  tx: Tx,
  supplierId: number,
  // TODO: When multi-store is fully supported, pass the customer's delivery
  // coordinates here and select the nearest store address instead of [0].
  // deliveryLat: number,
  // deliveryLong: number,
): Promise<ResolvedSupplierAddress> {
  // TODO: Replace `.findFirst` with a nearest-store lookup once
  // SupplierStoreAddress has area_id or the matching logic is ready.
  // For now we use the supplier's single (first) registered address.
  const storeAddress = await tx.supplierStoreAddress.findFirst({
    where: { supplier_id: supplierId },
    select: {
      id: true,
      latitude: true,
      longitude: true,
      address_line_1: true,
      address_line_2: true,
      area_id: true,
      working_hours: true,
    },
    orderBy: { created_at: "asc" },
  });

  // logger.info(
  //   `Resolved pickup address for supplier ${supplierId}: ${storeAddress?.working_hours}`,
  // );

  if (
    !storeAddress?.latitude ||
    !storeAddress.longitude ||
    !storeAddress.area_id
  ) {
    throw new HttpError(422, "orders:errors.supplier_has_no_address");
  }

  const workingHours =
    typeof storeAddress.working_hours === "string"
      ? JSON.parse(storeAddress.working_hours)
      : storeAddress.working_hours;

  if (!isSupplierOpenNow(workingHours)) {
    throw new HttpError(422, "orders:errors.supplier_closed_now");
  }

  const addressLabel = [
    storeAddress.address_line_1,
    storeAddress.address_line_2,
  ]
    .filter(Boolean)
    .join(", ");

  return {
    storeAddressId: storeAddress.id,
    lat: Number(storeAddress.latitude),
    long: Number(storeAddress.longitude),
    areaId: storeAddress.area_id,
    address: addressLabel,
  };
}
// ─── catalogHelpers.ts ────────────────────────────────────────────────────────

export interface ResolvedSPWithAddress extends ResolvedSP {
  storeAddressId: number;
  lat: number;
  long: number;
  areaId: number | null;
  address: string;
  workingHours: WorkingHours;
}
interface SPWithAddressRow {
  sp_id: number;
  supplier_id: number;
  price: number | null;
  cost_price: number | null;
  stock: number;
  is_active: boolean | number; // MariaDB returns tinyint as number
  product_id: number;
  requires_delivery_windows: boolean | number;
  product_deleted_at: Date | null;
  offer_id: number | null;
  offer_type: DiscountType | null;
  offer_value: Decimal | null;
  offer_created_by: "ADMIN" | "SUPPLIER" | null; // <--- Add this
  store_address_id: number | null;
  latitude: string | null;
  longitude: string | null;
  address_line_1: string | null;
  address_line_2: string | null;
  area_id: number | null;
  working_hours: string | null;
}

export async function resolveSupplierProductWithAddress(
  tx: Tx,
  spId: number,
): Promise<ResolvedSPWithAddress> {
  const now = new Date();

  const rows = await tx.$queryRaw<SPWithAddressRow[]>`
    SELECT
      sp.id              AS sp_id,
      sp.supplier_id,
      sp.price,
      sp.cost_price,
      sp.stock,
      sp.is_active,
      sp.product_id,
      sp.requires_delivery_windows,
      p.deleted_at       AS product_deleted_at,

      o.id               AS offer_id,
      o.offer_type,
      o.offer_value,
      o.created_by_role   AS offer_created_by,

      sa.id              AS store_address_id,
      sa.latitude,
      sa.longitude,
      sa.address_line_1,
      sa.address_line_2,
      sa.area_id,
      sa.working_hours

    FROM supplier_product sp
    JOIN product p ON p.id = sp.product_id

    LEFT JOIN offer o
      ON  o.supplier_product_id = sp.id   -- adjust FK name if different
      AND o.is_active   = 1
      AND o.deleted_at  IS NULL
      AND o.start_date  <= ${now}
      AND o.end_date    >= ${now}

    LEFT JOIN supplier_store_address sa    -- adjust table name if different
      ON  sa.supplier_id  = sp.supplier_id
      AND sa.id = (
        SELECT id FROM supplier_store_address
        WHERE supplier_id = sp.supplier_id
        ORDER BY created_at ASC
        LIMIT 1
      )

    WHERE sp.id = ${spId}
    LIMIT 1
  `;

  const row = rows[0];

  if (!row) throw new HttpError(404, "cart:errors.product_not_available");

  // MariaDB returns tinyint(1) as 0/1
  if (!row.is_active || row.product_deleted_at !== null)
    throw new HttpError(404, "cart:errors.product_not_available");

  if (row.stock <= 0)
    throw new HttpError(400, "cart:errors.insufficient_stock");

  if (!row.store_address_id || !row.latitude || !row.longitude || !row.area_id)
    throw new HttpError(422, "orders:errors.supplier_has_no_address");

  const workingHours: WorkingHours =
    typeof row.working_hours === "string"
      ? JSON.parse(row.working_hours)
      : row.working_hours;

  if (!isSupplierOpenNow(workingHours))
    throw new HttpError(422, "orders:errors.supplier_closed_now");

  const activeOffer =
    row.offer_id == null
      ? null
      : {
          id: row.offer_id,
          offer_type: row.offer_type!,
          offer_value: row.offer_value,
          created_by_role: row.offer_created_by!, // <--- 2. Map it here
        };

  const addressLabel = [row.address_line_1, row.address_line_2]
    .filter(Boolean)
    .join(", ");

  return {
    id: row.sp_id,
    supplier_id: row.supplier_id,
    price: row.price,
    cost_price: row.cost_price,
    stock: row.stock,
    is_active: true,
    product_id: row.product_id,
    requires_delivery_windows: !!row.requires_delivery_windows,
    activeOffer,
    storeAddressId: row.store_address_id,
    lat: Number(row.latitude),
    long: Number(row.longitude),
    areaId: row.area_id,
    address: addressLabel,
    workingHours,
  };
}

// export async function resolveSupplierProductWithAddress(
//   tx: Tx,
//   spId: number,
// ): Promise<ResolvedSPWithAddress> {
//   // One query: SP + active offer + supplier's first store address
//   const sp = await tx.supplierProduct.findUnique({
//     where: { id: spId },
//     relationLoadStrategy: "join",
//     select: {
//       id: true,
//       supplier_id: true,
//       price: true,
//       stock: true,
//       is_active: true,
//       product_id: true,
//       product: { select: { deleted_at: true } },
//       offers: {
//         where: activeOfferWhere(),
//         select: { id: true, offer_type: true, offer_value: true },
//         take: 1,
//       },
//       supplier: {
//         select: {
//           addresses: {
//             select: {
//               id: true,
//               latitude: true,
//               longitude: true,
//               address_line_1: true,
//               address_line_2: true,
//               area_id: true,
//               working_hours: true,
//             },
//             orderBy: { created_at: "asc" },
//             take: 1,
//           },
//         },
//       },
//     },
//   });

//   if (!sp?.is_active || sp.product.deleted_at !== null)
//     throw new HttpError(404, "cart:errors.product_not_available");
//   if (sp.stock <= 0) throw new HttpError(400, "cart:errors.insufficient_stock");

//   const storeAddress = sp.supplier.addresses[0];
//   if (
//     !storeAddress?.latitude ||
//     !storeAddress.longitude ||
//     !storeAddress.area_id
//   )
//     throw new HttpError(422, "orders:errors.supplier_has_no_address");

//   const workingHours =
//     typeof storeAddress.working_hours === "string"
//       ? JSON.parse(storeAddress.working_hours)
//       : storeAddress.working_hours;

//   if (!isSupplierOpenNow(workingHours))
//     throw new HttpError(422, "orders:errors.supplier_closed_now");

//   const addressLabel = [
//     storeAddress.address_line_1,
//     storeAddress.address_line_2,
//   ]
//     .filter(Boolean)
//     .join(", ");

//   return {
//     id: sp.id,
//     supplier_id: sp.supplier_id,
//     price: sp.price,
//     stock: sp.stock,
//     is_active: sp.is_active,
//     product_id: sp.product_id,
//     activeOffer: sp.offers[0] ?? null,
//     storeAddressId: storeAddress.id,
//     lat: Number(storeAddress.latitude),
//     long: Number(storeAddress.longitude),
//     areaId: storeAddress.area_id,
//     address: addressLabel,
//     workingHours,
//   };
// }
