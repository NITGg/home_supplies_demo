import { prisma } from "@/config/prisma";
import { HttpError } from "@/lib/httpError";
import type FeatureApi from "@/lib/featureApi";
import type {
  CreateBrandInput,
  UpdateBrandInput,
  ReorderBrandsInput,
  DeleteBrandsInput,
} from "./brands.schema";
import { Prisma } from "@prisma/client";
import {
  uploadSingleFile,
  extractPublicIdFromUrl,
  destroySingleFile,
} from "@/lib/cloudinary/cloudinary.service";

export async function listBrandsService(data: FeatureApi["data"]) {
  const take = Number(data.take) || 10;
  const [totalBrands, brands] = await prisma.$transaction([
    prisma.brand.count({ where: data.where }),
    prisma.brand.findMany(data as any),
  ]);

  return {
    totalBrands,
    totalPages: Math.ceil(totalBrands / take),
    brands,
  };
}

export async function getBrandByIdService(data: FeatureApi["data"]) {
  const brand = await prisma.brand.findUnique(data as any);
  if (!brand) throw new HttpError(404, "brands:errors.not_found");
  return brand;
}

export async function createBrandService(
  data: CreateBrandInput,
  queryOptions?: FeatureApi["data"]["select"],
  files?: { [fieldname: string]: Express.Multer.File[] },
) {
  const { categories, products, ...rest } = data;

  // --- image handling ---
  const logoFile = files?.["logo_url"]?.[0];
  if (logoFile) {
    const { secure_url } = await uploadSingleFile({
      fileLocation: logoFile.path, // .path or .buffer
      storagePathOnCloudinary: "brands",
    });
    rest.logo_url = secure_url;
  }

  const coverFile = files?.["cover_url"]?.[0];
  if (coverFile) {
    const { secure_url } = await uploadSingleFile({
      fileLocation: coverFile.path, // .path or .buffer
      storagePathOnCloudinary: "brands",
    });
    rest.cover_url = secure_url;
  }

  return prisma.brand.create({
    data: {
      ...rest,
      categories: {
        create: categories?.map((id) => ({ category_id: id })) ?? [],
      },
      products: {
        connect: products?.map((id) => ({ id })) ?? [],
      },
    },
    ...queryOptions,
  });
}

export async function updateBrandService(input: {
  id: number;
  data: UpdateBrandInput;
  query?: FeatureApi["data"]["select"];
  files?: { [fieldname: string]: Express.Multer.File[] };
}) {
  const { categories, products, deleteCoverUrl, deleteLogoUrl, ...rest } =
    input.data;

  const existing = await prisma.brand.findUnique({
    where: { id: input.id },
    include: {
      categories: { select: { id: true, category_id: true } },
    },
  });

  if (!existing) throw new HttpError(404, "brands:errors.not_found");

  // --- logo handling ---
  const logoFile = input.files?.["logo_url"]?.[0];
  if (logoFile) {
    const { secure_url } = await uploadSingleFile({
      fileLocation: logoFile.path, // .path or .buffer
      storagePathOnCloudinary: "brands",
    });
    rest.logo_url = secure_url;
    if (existing.logo_url) {
      const publicId = extractPublicIdFromUrl(existing.logo_url);
      if (publicId) {
        await destroySingleFile({ public_id: publicId }).catch((err) =>
          console.error(err),
        );
      }
    }
  } else if (deleteLogoUrl) {
    if (existing.logo_url) {
      const publicId = extractPublicIdFromUrl(existing.logo_url);
      if (publicId) {
        await destroySingleFile({ public_id: publicId }).catch((err) =>
          console.error(err),
        );
      }
    }
    rest.logo_url = null;
  }

  // --- cover handling ---
  const coverFile = input.files?.["cover_url"]?.[0];
  if (coverFile) {
    const { secure_url } = await uploadSingleFile({
      fileLocation: coverFile.path, // .path or .buffer
      storagePathOnCloudinary: "brands",
    });
    rest.cover_url = secure_url;
    if (existing.cover_url) {
      const publicId = extractPublicIdFromUrl(existing.cover_url);
      if (publicId) {
        await destroySingleFile({ public_id: publicId }).catch((err) =>
          console.error(err),
        );
      }
    }
  } else if (deleteCoverUrl) {
    if (existing.cover_url) {
      const publicId = extractPublicIdFromUrl(existing.cover_url);
      if (publicId) {
        await destroySingleFile({ public_id: publicId }).catch((err) =>
          console.error(err),
        );
      }
    }
    rest.cover_url = null;
  }

  // --- relation handling ---
  const updatePayload: Prisma.BrandUpdateInput = { ...rest };

  if (categories !== undefined) {
    const toDelete = existing.categories
      .filter((c) => !categories.includes(c.category_id))
      .map((c) => ({ id: c.id }));

    updatePayload.categories = {
      ...(toDelete.length ? { deleteMany: toDelete } : {}),
      upsert: categories.map((catId) => ({
        where: {
          brand_id_category_id: {
            brand_id: input.id,
            category_id: catId,
          },
        },
        create: { category_id: catId },
        update: { category_id: catId },
      })),
    };
  }

  if (products !== undefined) {
    updatePayload.products = {
      set: products.map((id) => ({ id })),
    };
  }

  return prisma.brand.update({
    where: { id: input.id },
    data: updatePayload,
    ...(input.query ?? []),
  });
}

export async function reorderBrandsService(input: ReorderBrandsInput) {
  const caseSql = input.brands
    .map((b) => `WHEN ${b.id} THEN ${b.sort_id}`)
    .join(" ");
  const idsSql = input.brands.map((b) => b.id).join(",");

  await prisma.$executeRawUnsafe(`
    UPDATE brand SET sort_id = CASE id ${caseSql} END WHERE id IN (${idsSql});
  `);
  return { ok: true as const };
}

export async function bulkDeleteBrandsService(input: DeleteBrandsInput) {
  const where: Prisma.BrandWhereInput = {};

  // TypeScript narrows the type of 'input' inside each block
  if ("isDeleted" in input) {
    where.deleted_at = { not: null };
  } else if ("notActive" in input) {
    where.is_active = false;
  } else if ("ids" in input) {
    where.id = { in: input.ids };
  }

  // Handle 'permanent' check safely
  const isPermanent = "permanent" in input ? input.permanent : false;

  if (isPermanent) {
    return prisma.brand.deleteMany({ where });
  }

  return prisma.brand.updateMany({
    where,
    data: { deleted_at: new Date(), is_active: false },
  });
}

// export async function updateBrandUpTo(brandId: number) {
//   try {
//     const now = new Date();
//     const [brand, product] = await Promise.all([
//       prisma.brand.findUnique({
//         where: { id: brandId },
//         select: { up_to: true },
//       }),
//       prisma.product.findFirst({
//         where: {
//           brand_id: brandId,
//           is_active: true,
//           deleted_at: null,
//           stock: { gte: 1 },
//           offer: { not: null, gt: 0 },
//           offer_valid_from: { lte: now },
//           offer_valid_to: { gte: now },
//         },
//         orderBy: { offer: "desc" },
//         select: { offer: true },
//       }),
//     ]);

//     const newOffer = product?.offer ?? 0;
//     if (brand && newOffer !== brand.up_to) {
//       await prisma.brand.update({
//         where: { id: brandId },
//         data: { up_to: newOffer },
//       });
//     }
//   } catch (error: any) {
//     console.error(
//       `Brand ${brandId}: Error updating max offer →`,
//       error.message,
//     );
//   }
// }
