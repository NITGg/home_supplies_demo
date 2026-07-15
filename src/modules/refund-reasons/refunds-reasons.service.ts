import { prisma } from "@/config/prisma";
import { HttpError } from "@/lib/httpError";
import type FeatureApi from "@/lib/featureApi";

import type {
  CreateRefundReasonInput,
  UpdateRefundReasonInput,
  DeleteRefundReasonsInput,
} from "./refunds-reasons.schema";

export async function listRefundReasonsService(data: FeatureApi["data"]) {
  const take = data.take ?? 10;

  const [totalRefundReasons, refundReasons] = await prisma.$transaction([
    prisma.refundReason.count({
      where: {
        ...data.where,
        deleted_at: null,
      },
    }),
    prisma.refundReason.findMany({
      ...(data as any),
      where: {
        ...data.where,
        deleted_at: null,
      },
    }),
  ]);

  return {
    totalRefundReasons,
    totalPages: Math.ceil(totalRefundReasons / take),
    refundReasons,
  };
}

export async function getRefundReasonByIdService(id: number) {
  const refundReason = await prisma.refundReason.findFirst({
    where: {
      id,
      deleted_at: null,
    },
  });

  if (!refundReason) throw new HttpError(404, "refundReasons:errors.not_found");

  return refundReason;
}

export async function createRefundReasonService(data: CreateRefundReasonInput) {
  return prisma.refundReason.create({
    data,
  });
}

export async function updateRefundReasonService(
  id: number,
  data: UpdateRefundReasonInput,
) {
  const exists = await prisma.refundReason.findFirst({
    where: {
      id,
      deleted_at: null,
    },
  });

  if (!exists) throw new HttpError(404, "refundReasons:errors.not_found");

  return prisma.refundReason.update({
    where: { id },
    data,
  });
}

export async function deleteRefundReasonService(id: number) {
  const exists = await prisma.refundReason.findFirst({
    where: {
      id,
      deleted_at: null,
    },
  });

  if (!exists) throw new HttpError(404, "refundReasons:errors.not_found");

  return prisma.refundReason.update({
    where: { id },
    data: {
      deleted_at: new Date(),
    },
  });
}

export async function deleteRefundReasonsService(
  input: DeleteRefundReasonsInput,
) {
  const result = await prisma.refundReason.updateMany({
    where: {
      id: {
        in: input.ids,
      },
      deleted_at: null,
    },
    data: {
      deleted_at: new Date(),
    },
  });

  return {
    count: result.count,
  };
}
