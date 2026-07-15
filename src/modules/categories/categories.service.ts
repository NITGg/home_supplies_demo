import { prisma } from "@/config/prisma";
import { HttpError } from "@/lib/httpError";
import {
  uploadSingleFile,
  extractPublicIdFromUrl,
  destroySingleFile,
} from "@/lib/cloudinary/cloudinary.service";
import type FeatureApi from "@/lib/featureApi";
import type {
  CreateCategoryInput,
  UpdateCategoryInput,
  ReorderCategoriesInput,
} from "./categories.schema";

export async function listCategoriesService(data: FeatureApi["data"]) {
  const take = Number(data.take) || 10;

  const [totalCount, categories] = await prisma.$transaction([
    prisma.category.count({ where: data.where }),
    prisma.category.findMany(data as any),
  ]);

  return {
    totalCount,
    totalPages: Math.ceil(totalCount / take),
    categories,
  };
}

export async function getCategoryByIdService(data?: FeatureApi["data"]) {
  const category = await prisma.category.findUnique(data as any);
  if (!category) throw new HttpError(404, "categories:errors.not_found");
  return category;
}

export async function createCategoryService(
  data: CreateCategoryInput,
  queryOptions?: FeatureApi["data"]["select"],
  files?: { [fieldname: string]: Express.Multer.File[] },
) {
  if (data.parent_id === undefined) delete data.parent_id;

  // --- image handling ---
  const imageFile = files?.["image_url"]?.[0];
  if (imageFile) {
    const { secure_url } = await uploadSingleFile({
      fileLocation: imageFile.path, // .path or .buffer
      storagePathOnCloudinary: "categories",
    });
    data.image_url = secure_url;
  }

  const iconFile = files?.["icon_url"]?.[0];
  if (iconFile) {
    const { secure_url } = await uploadSingleFile({
      fileLocation: iconFile.path, // .path or .buffer
      storagePathOnCloudinary: "categories",
    });
    data.icon_url = secure_url;
  }

  return prisma.category.create({
    data,
    ...(queryOptions ?? []),
  });
}

export async function updateCategoryService(input: {
  id: number;
  data: UpdateCategoryInput;
  query?: FeatureApi["data"]["select"];
  files?: { [fieldname: string]: Express.Multer.File[] };
}) {
  const existing = await prisma.category.findUnique({
    where: { id: input.id },
    select: { id: true, image_url: true, icon_url: true },
  });

  if (!existing) throw new HttpError(404, "categories:errors.not_found");

  const { delete_image, delete_icon, ...rest } = input.data;

  // --- image handling ---
  const imageFile = input.files?.["image_url"]?.[0];
  if (imageFile) {
    const { secure_url } = await uploadSingleFile({
      fileLocation: imageFile.path, // .path or .buffer
      storagePathOnCloudinary: "categories",
    });
    rest.image_url = secure_url;
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

  // --- icon handling ---
  const iconFile = input.files?.["icon_url"]?.[0];
  if (iconFile) {
    const { secure_url } = await uploadSingleFile({
      fileLocation: iconFile.path, // .path or .buffer
      storagePathOnCloudinary: "categories",
    });
    rest.icon_url = secure_url;
    if (existing.icon_url) {
      const publicId = extractPublicIdFromUrl(existing.icon_url);
      if (publicId) {
        await destroySingleFile({ public_id: publicId }).catch((err) =>
          console.error(err),
        );
      }
    }
  } else if (delete_icon) {
    if (existing.icon_url) {
      const publicId = extractPublicIdFromUrl(existing.icon_url);
      if (publicId) {
        await destroySingleFile({ public_id: publicId }).catch((err) =>
          console.error(err),
        );
      }
    }
    rest.icon_url = null;
  }

  return prisma.category.update({
    where: { id: existing.id },
    data: rest,
    ...(input.query ?? []),
  });
}

export async function deleteCategoryService(input: {
  id: number;
  permanent?: boolean;
}) {
  const existing = await prisma.category.findUnique({
    where: { id: input.id },
    select: { id: true, image_url: true, icon_url: true },
  });

  if (!existing) throw new HttpError(404, "categories:errors.not_found");

  if (input.permanent) {
    // Clean up images before hard delete
    if (existing.image_url) {
      const publicId = extractPublicIdFromUrl(existing.image_url);
      if (publicId) {
        await destroySingleFile({ public_id: publicId }).catch((err) =>
          console.error(err),
        );
      }
    }
    if (existing.icon_url) {
      const publicId = extractPublicIdFromUrl(existing.icon_url);
      if (publicId) {
        await destroySingleFile({ public_id: publicId }).catch((err) =>
          console.error(err),
        );
      }
    }
    await prisma.category.delete({ where: { id: input.id } });
  } else {
    await prisma.category.update({
      where: { id: input.id },
      data: { deleted_at: new Date(), is_active: false },
    });
  }

  return { ok: true as const };
}

export async function reorderCategoriesService(input: ReorderCategoriesInput) {
  const caseSql = input.categories
    .map((c) => `WHEN ${c.id} THEN ${c.sort_id}`)
    .join(" ");
  const idsSql = input.categories.map((c) => c.id).join(",");

  await prisma.$executeRawUnsafe(`
    UPDATE category
    SET sort_id = CASE id ${caseSql} END
    WHERE id IN (${idsSql});
  `);

  return { ok: true as const };
}
