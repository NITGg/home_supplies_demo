import { prisma } from "@/config/prisma.js";
import { HttpError } from "@/lib/httpError.js";
import FeatureApi from "@/lib/featureApi.js";
import type {
  CreateAreaInput,
  AreaIdParam,
  DeleteManyAreasInput,
  UpdateAreaInput,
} from "./areas.schema.js";

export async function listAreas(data: FeatureApi["data"]) {
  const take = data.take || 10;

  const [areas, totalCount] = await prisma.$transaction([
    prisma.area.findMany(data as any),
    prisma.area.count({ where: data.where }),
  ]);

  return { areas, totalCount, totalPages: Math.ceil(totalCount / take) };
}

export async function getAreaById(data: FeatureApi["data"]) {
  const area = await prisma.area.findUnique(data as any);

  if (!area) {
    throw new HttpError(404, "areas:errors.not_found");
  }

  return area;
}

export async function createArea(data: CreateAreaInput) {
  // governorate must exist and not deleted
  const gov = await prisma.governorate.findFirst({
    where: { id: data.governorate_id, deleted_at: null },
    select: { id: true },
  });

  if (!gov) {
    throw new HttpError(404, "areas:errors.governorate_not_found");
  }

  const created = await prisma.area.create({ data });
  return created;
}

export async function updateArea(id: number, data: UpdateAreaInput) {
  const existing = await prisma.area.findUnique({ where: { id } });
  if (!existing) {
    throw new HttpError(404, "areas:errors.not_found");
  }

  // 1. Validate Governorate if it's being changed
  if (
    data.governorate_id !== undefined &&
    existing.governorate_id !== data.governorate_id
  ) {
    const gov = await prisma.governorate.findFirst({
      where: { id: data.governorate_id, deleted_at: null },
      select: { id: true },
    });

    if (!gov) {
      throw new HttpError(404, "areas:errors.governorate_not_found");
    }
  }

  // 2. Perform Transactional Update
  return await prisma.$transaction(async (tx) => {
    const updated = await tx.area.update({
      where: { id },
      data,
    });

    // 3. If area is deactivated, remove all courier associations
    if (data.is_active === false) {
      await tx.courierSelectedArea.deleteMany({
        where: {
          area_id: id,
        },
      });

      await tx.customerAddress.deleteMany({
        where: {
          area_id: id,
        },
      });

      console.log(
        `[Area Deactivation] Removed all couriers from Area ID: ${id}`,
      );
    }

    return updated;
  });
}

// Area has no deleted_at => hard delete
export async function deleteArea({ id }: AreaIdParam) {
  const existing = await prisma.area.findUnique({ where: { id } });
  if (!existing) {
    throw new HttpError(404, "areas:errors.not_found");
  }

  await prisma.area.delete({ where: { id } });
  return { deleted: true as const };
}

export async function deleteAreas({ ids }: DeleteManyAreasInput) {
  const existing = await prisma.area.findFirst({
    where: { id: { in: ids } },
    select: { id: true },
  });

  if (!existing) {
    throw new HttpError(404, "areas:errors.not_found");
  }

  const result = await prisma.area.deleteMany({
    where: { id: { in: ids } },
  });

  return { deleted: true as const, count: result.count };
}
