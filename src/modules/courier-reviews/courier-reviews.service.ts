import type FeatureApi from "@/lib/featureApi";
import { HttpError } from "@/lib/httpError";
import { prisma } from "@/config/prisma";
import type {
  CreateCustomerReviewFromCourierInput,
  DeleteManyCourierReviewsInput,
  UpdateCustomerReviewFromCourierInput,
} from "./courier-reviews.schema";

export async function listCourierReviewsService(data: FeatureApi["data"]) {
  const take = data.take ?? 20;

  const [totalReviews, reviews] = await prisma.$transaction([
    prisma.customerReviewFromCourier.count({ where: data.where as any }),
    prisma.customerReviewFromCourier.findMany(data as any),
  ]);

  return {
    totalReviews,
    totalPages: Math.ceil(totalReviews / take),
    reviews,
  };
}

export async function listCustomerReceivedReviewsService(input: {
  userId: number;
  data: FeatureApi["data"];
}) {
  return listCourierReviewsService({
    ...input.data,
    where: {
      ...(input.data.where ?? {}),
      customer_id: input.userId,
    },
  } as FeatureApi["data"]);
}

export async function getCourierReviewByIdService(input: { id: number }) {
  const review = await prisma.customerReviewFromCourier.findUnique({
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

  if (!review) throw new HttpError(404, "courier-reviews:errors.not_found");

  return review;
}

export async function getCustomerReceivedReviewByIdService(input: {
  id: number;
  userId: number;
}) {
  const review = await getCourierReviewByIdService({ id: input.id });

  if (review.customer_id !== input.userId) {
    throw new HttpError(403, "courier-reviews:errors.forbidden");
  }

  return review;
}

async function ensureCourierExists(courierId: number) {
  const courier = await prisma.courier.findUnique({
    where: { id: courierId },
    select: { id: true, deleted_at: true },
  });

  if (!courier || courier.deleted_at) {
    throw new HttpError(404, "courier-reviews:errors.courier_not_found");
  }
}

async function ensureCustomerExists(customerId: number) {
  const customer = await prisma.user.findUnique({
    where: { id: customerId },
    select: { id: true, deleted_at: true },
  });

  if (!customer || customer.deleted_at) {
    throw new HttpError(404, "courier-reviews:errors.customer_not_found");
  }
}

async function ensureOrderMatchesParticipants(input: {
  order_id: number | null;
  courier_id: number;
  customer_id: number;
}) {
  if (!input.order_id) return;

  const order = await prisma.order.findUnique({
    where: { id: input.order_id },
    select: { id: true, courier_id: true, customer_id: true },
  });

  if (!order) {
    throw new HttpError(404, "courier-reviews:errors.order_not_found");
  }

  if (
    order.customer_id !== input.customer_id ||
    order.courier_id !== input.courier_id
  ) {
    throw new HttpError(
      409,
      "courier-reviews:errors.order_participants_mismatch",
    );
  }
}

export async function createCustomerReviewFromCourierService(
  input: CreateCustomerReviewFromCourierInput,
) {
  await ensureCourierExists(input.courier_id);
  await ensureCustomerExists(input.customer_id);
  await ensureOrderMatchesParticipants({
    order_id: input.order_id ?? null,
    courier_id: input.courier_id,
    customer_id: input.customer_id,
  });

  return prisma.customerReviewFromCourier.create({
    data: {
      courier_id: input.courier_id,
      customer_id: input.customer_id,
      order_id: input.order_id ?? null,
      rating: input.rating,
      comment: input.comment ?? null,
    },
  });
}

export async function updateCustomerReviewFromCourierService(input: {
  id: number;
  data: UpdateCustomerReviewFromCourierInput;
}) {
  const exists = await prisma.customerReviewFromCourier.findUnique({
    where: { id: input.id },
  });

  if (!exists) throw new HttpError(404, "courier-reviews:errors.not_found");

  const courier_id = input.data.courier_id ?? exists.courier_id;
  const customer_id = input.data.customer_id ?? exists.customer_id;
  const order_id =
    input.data.order_id === undefined
      ? exists.order_id
      : (input.data.order_id ?? null);

  await ensureCourierExists(courier_id);
  await ensureCustomerExists(customer_id);
  await ensureOrderMatchesParticipants({
    order_id,
    courier_id,
    customer_id,
  });

  return prisma.customerReviewFromCourier.update({
    where: { id: input.id },
    data: {
      courier_id: input.data.courier_id,
      customer_id: input.data.customer_id,
      order_id:
        input.data.order_id === undefined
          ? undefined
          : (input.data.order_id ?? null),
      rating: input.data.rating,
      comment:
        input.data.comment === undefined
          ? undefined
          : (input.data.comment ?? null),
    },
  });
}

export async function deleteCourierReviewService(input: { id: number }) {
  const exists = await prisma.customerReviewFromCourier.findUnique({
    where: { id: input.id },
    select: { id: true },
  });

  if (!exists) throw new HttpError(404, "courier-reviews:errors.not_found");

  await prisma.customerReviewFromCourier.delete({ where: { id: input.id } });
  return { ok: true as const };
}

export async function deleteManyCourierReviewsService(
  input: DeleteManyCourierReviewsInput,
) {
  const result = await prisma.customerReviewFromCourier.deleteMany({
    where: { id: { in: input.ids } },
  });

  return { count: result.count };
}
