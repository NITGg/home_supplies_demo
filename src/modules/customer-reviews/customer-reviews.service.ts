import type FeatureApi from "@/lib/featureApi";
import { HttpError } from "@/lib/httpError";
import { prisma } from "@/config/prisma";
import type {
  CreateCourierReviewFromCustomerInput,
  CreateSupplierReviewFromCustomerInput,
  DeleteManyCustomerReviewsInput,
} from "./customer-reviews.schema";

export async function createCourierReviewFromCustomerService(input: {
  userId: number;
  data: CreateCourierReviewFromCustomerInput;
}) {
  let courierId = input.data.courier_id;

  if (input.data.order_id) {
    const order = await prisma.order.findUnique({
      where: { id: input.data.order_id },
      select: { id: true, customer_id: true, courier_id: true, status: true },
    });

    if (!order) {
      throw new HttpError(404, "customer-reviews:errors.order_not_found");
    }

    if (order.customer_id !== input.userId) {
      throw new HttpError(403, "customer-reviews:errors.forbidden");
    }

    if (!order.courier_id) {
      throw new HttpError(409, "customer-reviews:errors.order_has_no_courier");
    }

    if (order.status !== "DELIVERED") {
      throw new HttpError(409, "customer-reviews:errors.order_not_delivered");
    }

    if (courierId && courierId !== order.courier_id) {
      throw new HttpError(409, "customer-reviews:errors.courier_mismatch");
    }

    courierId = order.courier_id;

    const alreadyReviewed = await prisma.courierReviewFromCustomer.findFirst({
      where: {
        customer_id: input.userId,
        courier_id: courierId,
        order_id: input.data.order_id,
      },
      select: { id: true },
    });

    if (alreadyReviewed) {
      throw new HttpError(409, "customer-reviews:errors.already_reviewed");
    }
  }

  if (!courierId) {
    throw new HttpError(400, "customer-reviews:errors.courier_id_required");
  }

  const courier = await prisma.courier.findUnique({
    where: { id: courierId },
    select: { id: true, deleted_at: true },
  });

  if (!courier || courier.deleted_at) {
    throw new HttpError(404, "customer-reviews:errors.courier_not_found");
  }

  return prisma.courierReviewFromCustomer.create({
    data: {
      customer_id: input.userId,
      courier_id: courierId,
      order_id: input.data.order_id ?? null,
      rating: input.data.rating,
      comment: input.data.comment ?? null,
    },
  });
}

export async function createSupplierReviewFromCustomerService(input: {
  userId: number;
  data: CreateSupplierReviewFromCustomerInput;
}) {
  const order = await prisma.order.findUnique({
    where: { id: input.data.order_id },
    select: { id: true, customer_id: true, supplier_id: true, status: true },
  });

  if (!order) {
    throw new HttpError(404, "customer-reviews:errors.order_not_found");
  }

  if (order.customer_id !== input.userId) {
    throw new HttpError(403, "customer-reviews:errors.forbidden");
  }

  if (!order.supplier_id) {
    throw new HttpError(409, "customer-reviews:errors.order_has_no_supplier");
  }

  if (order.status !== "DELIVERED") {
    throw new HttpError(409, "customer-reviews:errors.order_not_delivered");
  }

  const alreadyReviewed = await prisma.supplierReviewFromCustomer.findFirst({
    where: {
      user_id: input.userId,
      supplier_id: order.supplier_id,
      order_id: order.id,
    },
    select: { id: true },
  });

  if (alreadyReviewed) {
    throw new HttpError(
      409,
      "customer-reviews:errors.supplier_already_reviewed",
    );
  }

  const supplier = await prisma.supplier.findUnique({
    where: { id: order.supplier_id },
    select: { id: true, deleted_at: true },
  });

  if (!supplier || supplier.deleted_at) {
    throw new HttpError(404, "customer-reviews:errors.supplier_not_found");
  }

  return prisma.supplierReviewFromCustomer.create({
    data: {
      user_id: input.userId,
      supplier_id: order.supplier_id,
      order_id: order.id,
      rating: input.data.rating,
      comment: input.data.comment ?? null,
    },
  });
}

export async function listCustomerReviewsService(data: FeatureApi["data"]) {
  const take = data.take ?? 20;

  const [totalReviews, reviews] = await prisma.$transaction([
    prisma.courierReviewFromCustomer.count({ where: data.where as any }),
    prisma.courierReviewFromCustomer.findMany(data as any),
  ]);

  return {
    totalReviews,
    totalPages: Math.ceil(totalReviews / take),
    reviews,
  };
}

async function getCourierByUserIdOrThrow(userId: number) {
  const courier = await prisma.courier.findUnique({
    where: { user_id: userId },
    select: { id: true },
  });

  if (!courier) {
    throw new HttpError(
      404,
      "customer-reviews:errors.courier_profile_not_found",
    );
  }

  return courier;
}

export async function listCourierReceivedReviewsService(input: {
  userId: number;
  data: FeatureApi["data"];
}) {
  const courier = await getCourierByUserIdOrThrow(input.userId);

  return listCustomerReviewsService({
    ...input.data,
    where: {
      ...(input.data.where ?? {}),
      courier_id: courier.id,
    },
  } as FeatureApi["data"]);
}

export async function listMyGivenReviewsService(input: {
  userId: number;
  data: FeatureApi["data"];
}) {
  return listCustomerReviewsService({
    ...input.data,
    where: {
      ...(input.data.where ?? {}),
      customer_id: input.userId,
    },
  } as FeatureApi["data"]);
}

export async function getCustomerReviewByIdService(input: { id: number }) {
  const review = await prisma.courierReviewFromCustomer.findUnique({
    where: { id: input.id },
    include: {
      courier: {
        select: {
          id: true,
          user: { select: { id: true, full_name: true, phone: true } },
        },
      },
      customer: { select: { id: true, full_name: true, phone: true } },
      order: { select: { id: true, order_number: true, status: true } },
    },
  });

  if (!review) throw new HttpError(404, "customer-reviews:errors.not_found");

  return review;
}

export async function getMyGivenReviewByIdService(input: {
  id: number;
  userId: number;
}) {
  const review = await getCustomerReviewByIdService({ id: input.id });

  if (review.customer_id !== input.userId) {
    throw new HttpError(403, "customer-reviews:errors.forbidden");
  }

  return review;
}

export async function getCourierReceivedReviewByIdService(input: {
  id: number;
  userId: number;
}) {
  const courier = await getCourierByUserIdOrThrow(input.userId);
  const review = await getCustomerReviewByIdService({ id: input.id });

  if (review.courier_id !== courier.id) {
    throw new HttpError(403, "customer-reviews:errors.forbidden");
  }

  return review;
}

export async function deleteCustomerReviewService(input: { id: number }) {
  const exists = await prisma.courierReviewFromCustomer.findUnique({
    where: { id: input.id },
    select: { id: true },
  });

  if (!exists) throw new HttpError(404, "customer-reviews:errors.not_found");

  await prisma.courierReviewFromCustomer.delete({ where: { id: input.id } });
  return { ok: true as const };
}

export async function deleteManyCustomerReviewsService(
  input: DeleteManyCustomerReviewsInput,
) {
  const result = await prisma.courierReviewFromCustomer.deleteMany({
    where: { id: { in: input.ids } },
  });

  return { count: result.count };
}

export async function listSupplierReviewsService(
  data: FeatureApi["data"],
  reviewFrom?: string,
) {
  const take = data.take ?? 20;
  const where = (data.where ?? {}) as Record<string, any>;

  const { courier_id, user_id, ...shared } = where;

  const customerWhere = { ...shared, ...(user_id ? { user_id } : {}) };
  const courierWhere = { ...shared, ...(courier_id ? { courier_id } : {}) };

  const customerData = {
    ...data,
    where: customerWhere,
    include: { user: { select: { full_name: true } } },
  };
  const courierData = {
    ...data,
    where: courierWhere,
    include: { courier: { select: { user: { select: { full_name: true } } } } },
  };

  const includeCustomer = !reviewFrom || reviewFrom === "CUSTOMER";
  const includeCourier = !reviewFrom || reviewFrom === "COURIER";

  const [customerCount, customerReviews, courierCount, courierReviews] =
    await Promise.all([
      includeCustomer
        ? prisma.supplierReviewFromCustomer.count({ where: customerWhere as any })
        : 0,
      includeCustomer
        ? prisma.supplierReviewFromCustomer.findMany(customerData as any)
        : [],
      includeCourier
        ? prisma.supplierReviewFromCourier.count({ where: courierWhere as any })
        : 0,
      includeCourier
        ? prisma.supplierReviewFromCourier.findMany(courierData as any)
        : [],
    ]);

  const totalReviews = customerCount + courierCount;

  const reviews = [
    ...customerReviews.map((r: any) => ({
      ...r,
      source: "customer" as const,
      reviewer_name: r.user?.full_name ?? null,
    })),
    ...courierReviews.map((r: any) => ({
      ...r,
      source: "courier" as const,
      reviewer_name: r.courier?.user?.full_name ?? null,
    })),
  ].sort(
    (a, b) =>
      new Date(b.created_at).getTime() - new Date(a.created_at).getTime(),
  );

  return {
    totalReviews,
    totalPages: Math.ceil(totalReviews / take),
    reviews,
  };
}

export async function listCourierReviewsAdminService(
  data: FeatureApi["data"],
  reviewFrom?: string,
) {
  const take = data.take ?? 20;
  const where = (data.where ?? {}) as Record<string, any>;

  const { supplier_id, customer_id, ...shared } = where;

  const customerWhere = { ...shared, ...(customer_id ? { customer_id } : {}) };
  const supplierWhere = { ...shared, ...(supplier_id ? { supplier_id } : {}) };

  const customerData = {
    ...data,
    where: customerWhere,
    include: { customer: { select: { full_name: true } } },
  };
  const supplierData = {
    ...data,
    where: supplierWhere,
    include: { supplier: { select: { user: { select: { full_name: true } } } } },
  };

  const includeCustomer = !reviewFrom || reviewFrom === "CUSTOMER";
  const includeSupplier = !reviewFrom || reviewFrom === "SUPPLIER";

  const [customerCount, customerReviews, supplierCount, supplierReviews] =
    await Promise.all([
      includeCustomer
        ? prisma.courierReviewFromCustomer.count({ where: customerWhere as any })
        : 0,
      includeCustomer
        ? prisma.courierReviewFromCustomer.findMany(customerData as any)
        : [],
      includeSupplier
        ? prisma.courierReviewFromSupplier.count({ where: supplierWhere as any })
        : 0,
      includeSupplier
        ? prisma.courierReviewFromSupplier.findMany(supplierData as any)
        : [],
    ]);

  const totalReviews = customerCount + supplierCount;

  const reviews = [
    ...customerReviews.map((r: any) => ({
      ...r,
      source: "customer" as const,
      reviewer_name: r.customer?.full_name ?? null,
    })),
    ...supplierReviews.map((r: any) => ({
      ...r,
      source: "supplier" as const,
      reviewer_name: r.supplier?.user?.full_name ?? null,
    })),
  ].sort(
    (a, b) =>
      new Date(b.created_at).getTime() - new Date(a.created_at).getTime(),
  );

  return {
    totalReviews,
    totalPages: Math.ceil(totalReviews / take),
    reviews,
  };
}

export async function listCustomerReviewsAdminService(
  data: FeatureApi["data"],
) {
  const take = data.take ?? 20;

  const queryData = {
    ...data,
    include: {
      courier: { select: { user: { select: { full_name: true } } } },
    },
  };

  const [totalReviews, reviews] = await Promise.all([
    prisma.customerReviewFromCourier.count({ where: data.where as any }),
    prisma.customerReviewFromCourier.findMany(queryData as any),
  ]);

  return {
    totalReviews,
    totalPages: Math.ceil(totalReviews / take),
    reviews: reviews.map((r: any) => ({
      ...r,
      source: "courier" as const,
      reviewer_name: r.courier?.user?.full_name ?? null,
    })),
  };
}

export async function getSupplierReviewByIdService(input: {
  id: number;
  review_from: "COURIER" | "CUSTOMER";
}) {
  if (input.review_from === "COURIER") {
    const review = await prisma.supplierReviewFromCourier.findUnique({
      where: { id: input.id },
      include: {
        supplier: {
          select: {
            id: true,
            user: { select: { id: true, full_name: true, phone: true } },
          },
        },
        courier: {
          select: {
            id: true,
            user: { select: { id: true, full_name: true, phone: true } },
          },
        },
        order: { select: { id: true, order_number: true, status: true } },
      },
    });

    if (!review) throw new HttpError(404, "customer-reviews:errors.not_found");
    return { ...review, source: "courier" as const };
  }

  const review = await prisma.supplierReviewFromCustomer.findUnique({
    where: { id: input.id },
    include: {
      supplier: {
        select: {
          id: true,
          user: { select: { id: true, full_name: true, phone: true } },
        },
      },
      user: { select: { id: true, full_name: true, phone: true } },
      order: { select: { id: true, order_number: true, status: true } },
    },
  });

  if (!review) throw new HttpError(404, "customer-reviews:errors.not_found");
  return { ...review, source: "customer" as const };
}

export async function deleteSupplierReviewService(input: {
  id: number;
  review_from: "COURIER" | "CUSTOMER";
}) {
  if (input.review_from === "COURIER") {
    const exists = await prisma.supplierReviewFromCourier.findUnique({
      where: { id: input.id },
      select: { id: true },
    });
    if (!exists) throw new HttpError(404, "customer-reviews:errors.not_found");
    await prisma.supplierReviewFromCourier.delete({ where: { id: input.id } });
    return { ok: true as const };
  }

  const exists = await prisma.supplierReviewFromCustomer.findUnique({
    where: { id: input.id },
    select: { id: true },
  });
  if (!exists) throw new HttpError(404, "customer-reviews:errors.not_found");
  await prisma.supplierReviewFromCustomer.delete({ where: { id: input.id } });
  return { ok: true as const };
}
