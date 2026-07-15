import { prisma } from "@/config/prisma";
import { HttpError } from "@/lib/httpError";
import type FeatureApi from "@/lib/featureApi";
import type {
  CreateBadgeInput,
  UpdateBadgeInput,
  DeleteBadgesInput,
} from "./badges.schema";
import type { Prisma } from "@prisma/client";
import {
  uploadSingleFile,
  extractPublicIdFromUrl,
  destroySingleFile,
} from "@/lib/cloudinary/cloudinary.service";

async function getRoleOrThrowTx(tx: Prisma.TransactionClient, role_id: number) {
  const role = await tx.userRole.findUnique({
    where: { id: role_id },
    select: { id: true },
  });
  if (!role) throw new HttpError(400, "badges:errors.role_not_found");
  return role;
}

async function assertBadgeNotUsed(badgeId: number) {
  const used = await prisma.user.count({ where: { badge_id: badgeId } });
  if (used > 0) throw new HttpError(409, "badges:errors.badge_in_use");
}

/**
 * Overlap rule (inclusive):
 * overlap exists if existing.min <= nextMax AND existing.max >= nextMin
 *
 * If you want touching to be allowed (e.g. [0,10] and [10,20]), switch to:
 * existing.min < nextMax AND existing.max > nextMin
 */
async function assertNoOverlapTx(params: {
  tx: Prisma.TransactionClient;
  role_id: number;
  min: number;
  max: number;
  excludeId?: number;
}) {
  const { tx, role_id, min, max, excludeId } = params;

  const overlap = await tx.userBadge.findFirst({
    where: {
      role_id,
      ...(excludeId ? { id: { not: excludeId } } : {}),
      min_count: { lte: max },
      max_count: { gte: min },
    },
    select: { id: true },
  });

  if (overlap)
    throw new HttpError(409, "badges:errors.range_overlap", undefined, {
      badgeId: overlap.id,
    });
}

/**
 * Optional: normalize name uniqueness behavior at app-level (DB unique is still best)
 */
function normalizeName(s: string) {
  return s.trim();
}

export async function createBadgeService(
  input: CreateBadgeInput,
  file?: Express.Multer.File,
) {
  // Check first
  await prisma.$transaction(async (tx) => {
    await getRoleOrThrowTx(tx, input.role_id);
    await assertNoOverlapTx({
      tx,
      role_id: input.role_id,
      min: input.min_count,
      max: input.max_count,
    });
  });

  // Upload after checks
  let image: string | null = input.image ?? null;
  if (file) {
    const { secure_url } = await uploadSingleFile({
      fileLocation: file.path, // .path or .buffer
      storagePathOnCloudinary: "badges",
    });
    image = secure_url;
  }
  return await prisma.userBadge.create({
    data: {
      role_id: input.role_id,
      name: normalizeName(input.name),
      name_ar: normalizeName(input.name_ar),
      image: image ?? "",
      description: input.description ?? null,
      description_ar: input.description_ar ?? null,
      min_count: input.min_count,
      max_count: input.max_count,
      ratio: input.ratio,
    },
  });
}

export async function updateBadgeService(
  input: { id: number; data: UpdateBadgeInput },
  file?: Express.Multer.File,
) {
  const exists = await prisma.userBadge.findUnique({
    where: { id: input.id },
    select: {
      id: true,
      image: true,
      role_id: true,
      min_count: true,
      max_count: true,
    },
  });
  if (!exists) throw new HttpError(404, "badges:errors.badge_not_found");

  const nextRoleId = input.data.role_id ?? exists.role_id;
  const nextMin = input.data.min_count ?? exists.min_count;
  const nextMax = input.data.max_count ?? exists.max_count;

  const roleChanging =
    typeof input.data.role_id === "number" &&
    input.data.role_id !== exists.role_id;

  const rangeChanging =
    (typeof input.data.min_count === "number" ||
      typeof input.data.max_count === "number") &&
    (nextMin !== exists.min_count || nextMax !== exists.max_count);

  // Check first (ONLY when needed)
  if (roleChanging || rangeChanging) {
    await prisma.$transaction(async (tx) => {
      await getRoleOrThrowTx(tx, nextRoleId);

      await assertNoOverlapTx({
        tx,
        role_id: nextRoleId,
        min: nextMin,
        max: nextMax,
        excludeId: input.id, // IMPORTANT: don't overlap with itself
      });
    });
  }

  // Image logic AFTER checks
  const _deleteImage = input.data.deleteImage === true;
  const hasNewFile = !!file?.path;

  if (_deleteImage && !hasNewFile) {
    throw new HttpError(400, "badges:errors.image_required");
  }

  let newImage: string | undefined;
  if (hasNewFile) {
    const { secure_url } = await uploadSingleFile({
      fileLocation: file!.path, // .path or .buffer
      storagePathOnCloudinary: "badges",
    });
    newImage = secure_url;
  }

  if ((_deleteImage || hasNewFile) && exists.image) {
    const publicId = extractPublicIdFromUrl(exists.image);
    if (publicId) {
      await destroySingleFile({ public_id: publicId }).catch((err) =>
        console.error(err),
      );
    }
  }

  const { deleteImage: _del, image: _im, ...rest } = input.data;

  const updated = await prisma.userBadge.update({
    where: { id: input.id },
    data: {
      ...rest,
      ...(typeof rest.name === "string"
        ? { name: normalizeName(rest.name) }
        : {}),
      ...(typeof rest.name_ar === "string"
        ? { name_ar: normalizeName(rest.name_ar) }
        : {}),
      ...(newImage ? { image: newImage } : {}),
    },
  });

  return updated;
}

export async function listBadgesService(data: FeatureApi["data"]) {
  const take = data.take ?? 10;
  const [totalBadges, badges] = await prisma.$transaction([
    prisma.userBadge.count({ where: data.where as any }),
    prisma.userBadge.findMany(data as any),
  ]);

  return {
    totalBadges,
    totalPages: Math.ceil(totalBadges / take),
    badges,
  };
}

export async function getBadgeByIdService(input: { id: number }) {
  const badge = await prisma.userBadge.findUnique({ where: { id: input.id } });
  if (!badge) throw new HttpError(404, "badges:errors.badge_not_found");
  return badge;
}

export async function deleteBadgesService(input: DeleteBadgesInput) {
  for (const id of input.ids) await assertBadgeNotUsed(id);

  const result = await prisma.userBadge.deleteMany({
    where: { id: { in: input.ids } },
  });

  return { count: result.count };
}

export async function deleteBadgeService(input: { id: number }) {
  const badge = await prisma.userBadge.findUnique({
    where: { id: input.id },
    select: { id: true },
  });
  if (!badge) throw new HttpError(404, "badges:errors.badge_not_found");

  await assertBadgeNotUsed(input.id);

  await prisma.userBadge.delete({ where: { id: input.id } });
  return { ok: true as const };
}
