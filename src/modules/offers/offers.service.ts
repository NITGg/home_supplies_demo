import { prisma } from "@/config/prisma";
import { HttpError } from "@/lib/httpError";
import type FeatureApi from "@/lib/featureApi";
import type {
  CreateOfferInput,
  UpdateOfferInput,
  DeleteOffersInput,
} from "./offers.schema";

// ─── List ─────────────────────────────────────────────────────────────────────

export async function listOffersService(data: FeatureApi["data"]) {
  const take = Number(data.take) || 10;

  const [total, offers] = await prisma.$transaction([
    prisma.offer.count({ where: data.where as any }),
    prisma.offer.findMany(data as any),
  ]);

  return {
    offers,
    totalOffers: total,
    totalPages: Math.ceil(total / take),
  };
}

// ─── Get by ID ────────────────────────────────────────────────────────────────

export async function getOfferByIdService(data: FeatureApi["data"]) {
  const offer = await prisma.offer.findUnique(data as any);
  if (!offer) throw new HttpError(404, "offers:errors.not_found");
  return offer;
}

// ─── Create ───────────────────────────────────────────────────────────────────

export async function createOfferService(input: CreateOfferInput) {
  // 1. Validate supplier product exists & get financial details
  const sp = await prisma.supplierProduct.findUnique({
    where: { id: input.supplier_product_id },
    select: { id: true, cost_price: true, price: true },
  });

  if (!sp) throw new HttpError(404, "offers:errors.supplier_product_not_found");

  if (sp.price === null || sp.price === undefined) {
    throw new HttpError(400, "offers:errors.product_has_no_base_price");
  }

  // If Admin is involved, we MUST have a cost_price to compare against
  if (sp.cost_price === null || sp.cost_price === undefined) {
    throw new HttpError(400, "offers:errors.cost_price_missing_for_validation");
  }

  // 2. Calculate Effective Price
  let effectivePrice: number;
  if (input.offer_type === "PERCENT") {
    // price - (price * (value / 100))
    effectivePrice = sp.price - sp.price * (input.offer_value / 100);
  } else {
    // price - fixed_cents_value
    effectivePrice = sp.price - input.offer_value;
  }

  // 3. Apply Restriction for ADMIN
  // If the admin is creating this, the discounted price cannot be less than cost
  if (input.created_by_role === "ADMIN") {
    if (effectivePrice < sp.cost_price) {
      throw new HttpError(400, "offers:errors.offer_below_cost_price");
    }
  }

  // 4. Prevent overlapping active offers...
  const overlapping = await prisma.offer.findFirst({
    where: {
      supplier_product_id: input.supplier_product_id,
      deleted_at: null,
      is_active: true,
      start_date: { lte: input.end_date },
      end_date: { gte: input.start_date },
    },
  });
  if (overlapping) throw new HttpError(409, "offers:errors.overlapping_offer");

  return prisma.offer.create({ data: input });
}

// ─── Update ───────────────────────────────────────────────────────────────────

export async function updateOfferService(id: number, input: UpdateOfferInput) {
  const existing = await prisma.offer.findUnique({
    where: { id },
    select: {
      id: true,
      supplier_product_id: true,
      start_date: true,
      end_date: true,
    },
  });
  if (!existing) throw new HttpError(404, "offers:errors.not_found");

  // Check overlap only if dates are being changed
  const newStart = input.start_date ?? existing.start_date;
  const newEnd = input.end_date ?? existing.end_date;

  if (newStart && newEnd) {
    const overlapping = await prisma.offer.findFirst({
      where: {
        id: { not: id }, // exclude self
        supplier_product_id: existing.supplier_product_id,
        deleted_at: null,
        is_active: true,
        start_date: { lte: newEnd },
        end_date: { gte: newStart },
      },
    });
    if (overlapping)
      throw new HttpError(409, "offers:errors.overlapping_offer");
  }

  return prisma.offer.update({ where: { id }, data: input });
}

// ─── Soft delete single ───────────────────────────────────────────────────────

export async function deleteOfferService(id: number) {
  const existing = await prisma.offer.findUnique({
    where: { id },
    select: { id: true },
  });
  if (!existing) throw new HttpError(404, "offers:errors.not_found");

  return prisma.offer.update({
    where: { id },
    data: { deleted_at: new Date(), is_active: false },
  });
}

// ─── Bulk delete (strategy pattern) ──────────────────────────────────────────

export async function deleteOffersService(input: DeleteOffersInput) {
  const now = new Date();

  const strategies = {
    expired: () =>
      prisma.offer.updateMany({
        where: { end_date: { lt: now }, deleted_at: null },
        data: { deleted_at: now, is_active: false },
      }),
    inactive: () =>
      prisma.offer.updateMany({
        where: { is_active: false, deleted_at: null },
        data: { deleted_at: now },
      }),
    ids: () => {
      if (input.strategy !== "ids") return Promise.resolve({ count: 0 });
      return prisma.offer.updateMany({
        where: { id: { in: input.ids }, deleted_at: null },
        data: { deleted_at: now, is_active: false },
      });
    },
  };

  return strategies[input.strategy]();
}
