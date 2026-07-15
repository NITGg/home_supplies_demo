import { prisma } from "@/config/prisma";
import { HttpError } from "@/lib/httpError";
import type FeatureApi from "@/lib/featureApi";
import type {
  CreateCustomerCouponInput,
  UpdateCustomerCouponInput,
  DeleteManyCustomerCouponsInput,
} from "./customer-coupons.schema";
import { bus } from "@/events/bus";
import { AuthedRequest } from "@/types/authedRequest";
import { CouponScope, OrderType } from "@prisma/client";
import {
  uploadSingleFile,
  extractPublicIdFromUrl,
  destroySingleFile,
} from "@/lib/cloudinary/cloudinary.service";
import {
  assertCouponDates,
  assertOrderCouponMinOrdersCount,
  assertOrderCouponUsageLimits,
} from "../profile/services/wallet.service";

function generateCouponCode() {
  // Example: CC-7H2K9D (short, admin-friendly)
  const rand = Math.random().toString(36).slice(2, 8).toUpperCase();
  return `CC-${rand}`;
}

async function generateUniqueCouponCode() {
  for (let i = 0; i < 10; i++) {
    const code = generateCouponCode();
    const exists = await prisma.customerCoupon.findFirst({
      where: { code },
      select: { id: true },
    });
    if (!exists) return code;
  }
  throw new HttpError(500, "customer-coupons:errors.code_generation_failed");
}

export async function listCustomerCouponsService(data: FeatureApi["data"]) {
  const take = data.take ?? 20;
  const [totalCoupons, coupons] = await prisma.$transaction([
    prisma.customerCoupon.count({ where: data.where as any }),
    prisma.customerCoupon.findMany(data as any),
  ]);

  return { totalCoupons, totalPages: Math.ceil(totalCoupons / take), coupons };
}

export async function getCustomerCouponByIdService(input: { id: number }) {
  const coupon = await prisma.customerCoupon.findUnique({
    where: { id: input.id },
  });
  if (!coupon) throw new HttpError(404, "customer-coupons:errors.not_found");
  return coupon;
}

export async function createCustomerCouponService(
  input: CreateCustomerCouponInput,
  userId: AuthedRequest["user"]["id"],
  file?: Express.Multer.File,
) {
  const code = input.code?.trim()
    ? input.code.trim()
    : await generateUniqueCouponCode();

  // if user provided a code, enforce uniqueness
  if (input.code?.trim()) {
    const exists = await prisma.customerCoupon.findFirst({
      where: { code },
      select: { id: true },
    });
    if (exists) throw new HttpError(409, "customer-coupons:errors.code_exists");
  }

  const isOrderDiscount = input.type === "ORDER_DISCOUNT";

  let image: string | null = null;
  if (file) {
    const { secure_url } = await uploadSingleFile({
      fileLocation: file.path, // .path or .buffer
      storagePathOnCloudinary: "users/Customer",
    });
    image = secure_url;
  }
  const coupon = await prisma.customerCoupon.create({
    data: {
      code,
      title: input.title,
      title_ar: input.title_ar ?? null,
      description: input.description ?? null,
      description_ar: input.description_ar ?? null,

      type: input.type,
      scope: input.scope,
      image,

      // New Fields
      is_first: input.is_first ?? false,
      button_text: input.button_text ?? null,
      button_text_ar: input.button_text_ar ?? null,

      start_at: input.start_at ?? null,
      end_at: input.end_at ?? null,

      is_active: input.is_active ?? true,
      deleted_at: null,

      max_total_uses: input.max_total_uses ?? null,
      max_user_uses: input.max_user_uses ?? null,
      min_orders_count: input.min_orders_count ?? 0,

      discount_type: isOrderDiscount ? (input.discount_type ?? null) : null,
      discount_value: isOrderDiscount ? (input.discount_value ?? null) : null,
      max_discount_cents: isOrderDiscount
        ? (input.max_discount_cents ?? null)
        : null,
      min_order_total_cents: isOrderDiscount
        ? (input.min_order_total_cents ?? null)
        : null,

      wallet_amount_cents: isOrderDiscount
        ? 0
        : (input.wallet_amount_cents ?? 0),
      wallet_points: isOrderDiscount ? 0 : (input.wallet_points ?? 0),
    },
  });
  bus.emit("customer-coupon.created", {
    couponId: coupon.id,
    code: coupon.code,
    title: coupon.title,
    titleAr: coupon.title_ar,
    type: coupon.type,
    isActive: coupon.is_active,
    createdByUserId: userId,
    createdAt: new Date(),
  });
  return coupon;
}

export async function updateCustomerCouponService(
  input: {
    id: number;
    data: UpdateCustomerCouponInput;
  },
  file?: Express.Multer.File,
) {
  const exists = await prisma.customerCoupon.findUnique({
    where: { id: input.id },
    select: { id: true, image: true },
  });
  if (!exists) throw new HttpError(404, "customer-coupons:errors.not_found");

  // Handle Code Uniqueness
  if (input.data.code?.trim()) {
    const code = input.data.code.trim();
    const codeExists = await prisma.customerCoupon.findFirst({
      where: { code, id: { not: input.id } },
      select: { id: true },
    });
    if (codeExists)
      throw new HttpError(409, "customer-coupons:errors.code_exists");

    input.data.code = code;
  }

  // Handle Image Logic
  let image = undefined; // 'undefined' means Prisma won't touch the field
  if (file) {
    const { secure_url } = await uploadSingleFile({
      fileLocation: file.path, // .path or .buffer
      storagePathOnCloudinary: "users/Customer",
    });
    image = secure_url;
  } else if (input.data.deleteImage) {
    if (exists.image) {
      const publicId = extractPublicIdFromUrl(exists.image);
      if (publicId) {
        await destroySingleFile({ public_id: publicId }).catch((err: any) => {
          console.warn("Failed to delete image:", err);
        });
      }
    }
    image = null; // Explicitly remove the image
  }

  // Extract deleteImage so it doesn't get passed to Prisma's data object
  const { deleteImage: _deleteImage, ...updateData } = input.data;

  return prisma.customerCoupon.update({
    where: { id: input.id },
    data: {
      ...updateData,
      ...(image === undefined ? {} : { image }),
      // Handlers for nullable fields
      ...(updateData.title_ar === undefined
        ? {}
        : { title_ar: updateData.title_ar ?? null }),
      ...(updateData.description === undefined
        ? {}
        : { description: updateData.description ?? null }),
      ...(updateData.description_ar === undefined
        ? {}
        : { description_ar: updateData.description_ar ?? null }),
      ...(updateData.start_at === undefined
        ? {}
        : { start_at: updateData.start_at ?? null }),
      ...(updateData.end_at === undefined
        ? {}
        : { end_at: updateData.end_at ?? null }),
      ...(updateData.max_total_uses === undefined
        ? {}
        : { max_total_uses: updateData.max_total_uses ?? null }),
      ...(updateData.max_user_uses === undefined
        ? {}
        : { max_user_uses: updateData.max_user_uses ?? null }),
    },
  });
}

export async function deleteManyCustomerCouponsService(
  input: DeleteManyCustomerCouponsInput,
) {
  if (input.archived) {
    const result = await prisma.customerCoupon.updateMany({
      where: { id: { in: input.ids } },
      data: { deleted_at: new Date() },
    });
    return { count: result.count };
  }
  // 1. Find images before deleting from DB
  const coupons = await prisma.customerCoupon.findMany({
    where: { id: { in: input.ids } },
    select: { image: true },
  });

  // 2. Perform DB deletion
  const result = await prisma.customerCoupon.deleteMany({
    where: { id: { in: input.ids } },
  });

  // 3. Clean up files from storage
  const imagesToDelete = coupons
    .map((c) => c.image)
    .filter(Boolean) as string[];
  await Promise.allSettled(
    imagesToDelete.map((img) => {
      const publicId = extractPublicIdFromUrl(img);
      return publicId
        ? destroySingleFile({ public_id: publicId })
        : Promise.resolve();
    }),
  );

  return { count: result.count };
}

export async function deleteCustomerCouponService(input: {
  id: number;
  archived?: boolean;
}) {
  const exists = await prisma.customerCoupon.findUnique({
    where: { id: input.id },
    select: { id: true, image: true },
  });
  if (!exists) throw new HttpError(404, "customer-coupons:errors.not_found");

  if (input.archived) {
    await prisma.customerCoupon.update({
      where: { id: input.id },
      data: { deleted_at: new Date() },
    });
    return { archived: true as const };
  }

  // 1. Delete from Database
  await prisma.customerCoupon.delete({ where: { id: input.id } });

  // 2. Delete the actual file if it exists
  if (exists.image) {
    const publicId = extractPublicIdFromUrl(exists.image);
    if (publicId) {
      await destroySingleFile({ public_id: publicId }).catch(() => {
        console.error(`Failed to delete image: ${exists.image}`);
      });
    }
  }
  return { ok: true as const };
}

/**
 * Validation (rules you asked):
 * - active + not deleted
 * - within start/end
 * - min_orders_count
 * - max_total_uses, max_user_uses using CustomerCouponUsage table
 */
export async function validateCustomerCouponService(input: {
  userId: number;
  code: string;
  orderType: OrderType;
}) {
  const now = new Date();

  const coupon = await prisma.customerCoupon.findFirst({
    where: { code: input.code.trim(), is_active: true, deleted_at: null },
  });

  if (!coupon) throw new HttpError(404, "customer-coupons:errors.not_found");

  if (input.orderType === "CUSTOM_PICKUP" && coupon.scope !== "DELIVERY_FEE") {
    throw new HttpError(
      400,
      "customer-coupons:errors.invalid_coupon_scope_for_order_type",
    );
  }

  // 2. Use the shared assertion helpers for consistency
  assertCouponDates(coupon, now);

  await assertOrderCouponMinOrdersCount(
    prisma,
    { userId: input.userId },
    coupon, // Casting or ensuring type matches the assertion signature
  );

  await assertOrderCouponUsageLimits(prisma, { userId: input.userId }, coupon);

  return { coupon, valid: true as const };
}

// List usages (admin or user)
export async function listCustomerCouponUsagesService(
  data: FeatureApi["data"],
) {
  const take = data.take ?? 20;
  const [totalUsages, usages] = await prisma.$transaction([
    prisma.customerCouponUsage.count({ where: data.where as any }),
    prisma.customerCouponUsage.findMany(data as any),
  ]);

  return { totalUsages, totalPages: Math.ceil(totalUsages / take), usages };
}

/**
 * Resolves which portion of the order to apply the discount against.
 *
 * @param scope          - coupon scope
 * @param budgetCents    - customer's declared product budget (always present)
 * @param deliveryFee    - estimated or real delivery fee (may be 0 if not yet set)
 */
export function resolveBaseAmount(
  scope: CouponScope,
  budgetCents: number,
  deliveryFeeCents: number,
): number {
  switch (scope) {
    case "DELIVERY_FEE":
      return deliveryFeeCents;
    case "PRODUCTS_ONLY":
      return budgetCents; // budget IS the product value in your model
    case "ORDER_TOTAL":
    default:
      return budgetCents + deliveryFeeCents;
  }
}

export function calculateOrderDiscountCents(
  coupon: {
    discount_type: "PERCENT" | "FIXED_CENTS" | null;
    discount_value: number | null;
    max_discount_cents: number | null;
    scope: CouponScope;
    type: "ORDER_DISCOUNT" | "WALLET_CREDIT";
  },
  budgetCents: number,
  deliveryFeeCents: number,
): number {
  if (coupon.type === "WALLET_CREDIT") {
    return 0;
  }
  if (!coupon.discount_type || coupon.discount_value == null) {
    throw new HttpError(400, "customer-coupons:errors.invalid_order_discount");
  }

  const baseAmount = resolveBaseAmount(
    coupon.scope,
    budgetCents,
    deliveryFeeCents,
  );

  let discount = 0;

  if (coupon.discount_type === "PERCENT") {
    discount = (baseAmount * coupon.discount_value) / 100;
    if (coupon.max_discount_cents && discount > coupon.max_discount_cents) {
      discount = coupon.max_discount_cents;
    }
  } else {
    discount = coupon.discount_value;
  }

  // never exceed the base amount (can't discount more than what scope covers)
  return Math.max(0, Math.min(discount, baseAmount));
}
