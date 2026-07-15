import { prisma } from "@/config/prisma";
import { HttpError } from "@/lib/httpError";
import type FeatureApi from "@/lib/featureApi";
import type {
  CreateCourierCouponInput,
  UpdateCourierCouponInput,
  DeleteManyCourierCouponsInput,
} from "./courier-coupons.schema";

export async function listCourierCouponsService(data: FeatureApi["data"]) {
  const take = data.take ?? 20;

  const [totalCoupons, coupons] = await prisma.$transaction([
    prisma.courierCoupon.count({ where: data.where as any }),
    prisma.courierCoupon.findMany(data as any),
  ]);

  return { totalCoupons, totalPages: Math.ceil(totalCoupons / take), coupons };
}

export async function getCourierCouponByIdService(input: { id: number }) {
  const coupon = await prisma.courierCoupon.findUnique({
    where: { id: input.id },
  });

  if (!coupon) throw new HttpError(404, "courier-coupons:errors.not_found");
  return coupon;
}

export async function createCourierCouponService(
  input: CreateCourierCouponInput,
) {
  return prisma.courierCoupon.create({
    data: {
      title: input.title,
      title_ar: input.title_ar ?? null,
      description: input.description ?? null,
      description_ar: input.description_ar ?? null,
      price: input.price,
      bonus_courier_fee: input.bonus_courier_fee,
      duration_days: input.duration_days,
      is_active: input.is_active ?? true,
      deleted_at: null,
    },
  });
}

export async function updateCourierCouponService(input: {
  id: number;
  data: UpdateCourierCouponInput;
}) {
  const exists = await prisma.courierCoupon.findUnique({
    where: { id: input.id },
    select: { id: true },
  });

  if (!exists) throw new HttpError(404, "courier-coupons:errors.not_found");

  return prisma.courierCoupon.update({
    where: { id: input.id },
    data: {
      ...input.data,
      ...(input.data.title_ar === undefined
        ? {}
        : { title_ar: input.data.title_ar ?? null }),
      ...(input.data.description === undefined
        ? {}
        : { description: input.data.description ?? null }),
      ...(input.data.description_ar === undefined
        ? {}
        : { description_ar: input.data.description_ar ?? null }),
    },
  });
}

export async function deleteManyCourierCouponsService(
  input: DeleteManyCourierCouponsInput,
) {
  if (input.archived) {
    const result = await prisma.courierCoupon.updateMany({
      where: { id: { in: input.ids } },
      data: { deleted_at: new Date() },
    });
    return { count: result.count };
  }

  const result = await prisma.courierCoupon.deleteMany({
    where: { id: { in: input.ids } },
  });

  return { count: result.count };
}

export async function deleteCourierCouponService(input: {
  id: number;
  archived?: boolean;
}) {
  const exists = await prisma.courierCoupon.findUnique({
    where: { id: input.id },
    select: { id: true },
  });

  if (!exists) throw new HttpError(404, "courier-coupons:errors.not_found");

  if (input.archived) {
    await prisma.courierCoupon.update({
      where: { id: input.id },
      data: { deleted_at: new Date() },
    });
    return { archived: true as const };
  }

  await prisma.courierCoupon.delete({
    where: { id: input.id },
  });

  return { ok: true as const };
}

export async function validateCourierCouponService(input: {
  userId: number;
  couponId: number;
}) {
  const now = new Date();

  const coupon = await prisma.courierCoupon.findFirst({
    where: {
      id: input.couponId,
      is_active: true,
      deleted_at: null,
    },
  });

  if (!coupon) {
    throw new HttpError(404, "courier-coupons:errors.not_found");
  }

  const activeUsage = await prisma.courierCouponUsage.findFirst({
    where: {
      user_id: input.userId,
      end_date: { gte: now },
    },
    orderBy: { end_date: "desc" },
  });

  if (activeUsage) {
    throw new HttpError(
      400,
      "courier-coupons:errors.already_has_active_coupon",
    );
  }

  return { coupon, valid: true as const };
}

export async function listCourierCouponUsagesService(data: FeatureApi["data"]) {
  const take = data.take ?? 20;

  const [totalUsages, usages] = await prisma.$transaction([
    prisma.courierCouponUsage.count({ where: data.where as any }),
    prisma.courierCouponUsage.findMany(data as any),
  ]);

  return { totalUsages, totalPages: Math.ceil(totalUsages / take), usages };
}
