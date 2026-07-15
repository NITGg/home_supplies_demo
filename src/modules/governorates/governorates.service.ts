import { prisma } from "@/config/prisma.js";
import { HttpError } from "@/lib/httpError.js";
import FeatureApi from "@/lib/featureApi.js";
import {
  CreateGovtInput,
  DeleteGovtInput,
  DeleteManyGovtInput,
  UpdateGovtInput,
} from "./governorates.schema.js";

export async function listGovernorates(data: FeatureApi["data"]) {
  const take = data.take || 10;
  const [governorates, totalCount] = await prisma.$transaction([
    prisma.governorate.findMany(data as any),
    prisma.governorate.count({
      where: data.where,
    }),
  ]);

  return { governorates, totalCount, totalPages: Math.ceil(totalCount / take) };
}

export async function getGovernorateById(data: FeatureApi["data"]) {
  const governorate = await prisma.governorate.findUnique(data as any);

  if (!governorate) {
    throw new HttpError(404, "governorates:errors.not_found");
  }

  return governorate;
}

export async function createGovernorate(data: CreateGovtInput) {
  console.log({ data });
  // Optional: enforce uniqueness if you add a unique index later.
  const created = await prisma.governorate.create({
    data,
  });

  return created;
}

export async function updateGovernorate(id: number, data: UpdateGovtInput) {
  const existing = await prisma.governorate.findFirst({
    where: { id },
  });

  if (!existing) {
    throw new HttpError(404, "governorates:errors.not_found");
  }

  const updated = await prisma.governorate.update({
    where: { id },
    data,
  });

  return updated;
}

export async function deleteGovernorate({ id, archived }: DeleteGovtInput) {
  const existing = await prisma.governorate.findFirst({
    where: { id },
  });

  if (!existing) {
    throw new HttpError(404, "governorates:errors.not_found");
  }
  if (archived) {
    // Soft delete governorate (areas are left as-is; you can decide cascade behavior)
    await prisma.governorate.update({
      where: { id },
      data: { deleted_at: new Date() },
    });
    return { archived: true as const };
  }

  await prisma.$transaction([
    prisma.area.deleteMany({
      where: { governorate_id: id },
    }),
    prisma.governorate.delete({
      where: { id },
    }),
  ]);
  return { archived: false as const };
}

export async function deleteGovernorates({
  ids,
  archived,
}: DeleteManyGovtInput) {
  // Ensure at least one exists (optional but matches your style)
  const existing = await prisma.governorate.findFirst({
    where: { id: { in: ids } },
    select: { id: true },
  });

  if (!existing) {
    throw new HttpError(404, "governorates:errors.not_found");
  }

  if (archived) {
    // Soft delete many governorates
    const result = await prisma.governorate.updateMany({
      where: { id: { in: ids } },
      data: { deleted_at: new Date() },
    });
    return { archived: true as const, count: result.count };
  }

  // Hard delete many: delete related areas first then governorates
  const [, result] = await prisma.$transaction([
    prisma.area.deleteMany({
      where: { governorate_id: { in: ids } },
    }),
    prisma.governorate.deleteMany({
      where: { id: { in: ids } },
    }),
  ]);

  return { archived: false as const, count: result.count };
}
