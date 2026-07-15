import { prisma } from "@/config/prisma";
import { HttpError } from "@/lib/httpError";
import {
  uploadSingleFile,
  extractPublicIdFromUrl,
  destroySingleFile,
} from "@/lib/cloudinary/cloudinary.service";
import type FeatureApi from "@/lib/featureApi";
import type {
  CreateAdInput,
  UpdateAdInput,
  ReorderAdsInput,
} from "./ads.schema";

// ─── List ─────────────────────────────────────────────────────────────────────

export async function listAdsService(data: FeatureApi["data"]) {
  const take = Number(data.take) || 10;

  const [totalCount, ads] = await prisma.$transaction([
    prisma.ad.count({ where: data.where }),
    prisma.ad.findMany(data as any),
  ]);

  return {
    totalCount,
    totalPages: Math.ceil(totalCount / take),
    ads,
  };
}

// ─── Get one ──────────────────────────────────────────────────────────────────

export async function getAdByIdService(data?: FeatureApi["data"]) {
  const ad = await prisma.ad.findUnique(data as any);
  if (!ad) throw new HttpError(404, "ads:errors.not_found");
  return ad;
}

// ─── Create ───────────────────────────────────────────────────────────────────

export async function createAdService(
  data: CreateAdInput,
  queryOptions?: FeatureApi["data"]["select"],
  files?: { [fieldname: string]: Express.Multer.File[] },
) {
  const file = files?.["image_url"]?.[0];
  if (file) {
    const { secure_url } = await uploadSingleFile({
      fileLocation: file.path, // .path or .buffer
      storagePathOnCloudinary: "ads",
    });
    data.image_url = secure_url;
  }

  return prisma.ad.create({
    data,
    ...(queryOptions ?? []),
  });
}

// ─── Update ───────────────────────────────────────────────────────────────────

export async function updateAdService(input: {
  id: number;
  data: UpdateAdInput;
  query?: FeatureApi["data"]["select"];
  files?: { [fieldname: string]: Express.Multer.File[] };
}) {
  const existing = await prisma.ad.findUnique({
    where: { id: input.id },
    select: { id: true, image_url: true },
  });

  if (!existing) throw new HttpError(404, "ads:errors.not_found");

  const { delete_image, ...rest } = input.data;

  const file = input.files?.["image_url"]?.[0];
  if (file) {
    const { secure_url } = await uploadSingleFile({
      fileLocation: file.path, // .path or .buffer
      storagePathOnCloudinary: "ads",
    });
    rest.image_url = secure_url;
    // Delete old image from Cloudinary
    if (existing.image_url) {
      const publicId = extractPublicIdFromUrl(existing.image_url);
      if (publicId) {
        await destroySingleFile({ public_id: publicId }).catch((err) =>
          console.error(err),
        );
      }
    }
  } else if (delete_image) {
    if (existing.image_url) {
      const publicId = extractPublicIdFromUrl(existing.image_url);
      if (publicId) {
        await destroySingleFile({ public_id: publicId }).catch((err) =>
          console.error(err),
        );
      }
    }
    rest.image_url = null;
  }

  return prisma.ad.update({
    where: { id: existing.id },
    data: rest,
    ...(input.query ?? []),
  });
}

// ─── Delete ───────────────────────────────────────────────────────────────────

export async function deleteAdService(input: {
  id: number;
  permanent?: boolean;
}) {
  const existing = await prisma.ad.findUnique({
    where: { id: input.id },
    select: { id: true, image_url: true },
  });

  if (!existing) throw new HttpError(404, "ads:errors.not_found");

  if (input.permanent) {
    if (existing.image_url) {
      const publicId = extractPublicIdFromUrl(existing.image_url);
      if (publicId) {
        await destroySingleFile({ public_id: publicId }).catch((err) =>
          console.error(err),
        );
      }
    }
    await prisma.ad.delete({ where: { id: input.id } });
  } else {
    await prisma.ad.update({
      where: { id: input.id },
      data: { deleted_at: new Date(), status: "INACTIVE" },
    });
  }

  return { ok: true as const };
}

// ─── Reorder ──────────────────────────────────────────────────────────────────

export async function reorderAdsService(input: ReorderAdsInput) {
  const caseSql = input.ads
    .map((a) => `WHEN ${a.id} THEN ${a.sort_id}`)
    .join(" ");
  const idsSql = input.ads.map((a) => a.id).join(",");

  await prisma.$executeRawUnsafe(`
    UPDATE ad
    SET sort_id = CASE id ${caseSql} END
    WHERE id IN (${idsSql});
  `);

  return { ok: true as const };
}
