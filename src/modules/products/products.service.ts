import { prisma } from "@/config/prisma";
import { HttpError } from "@/lib/httpError";
import {
  uploadSingleFile,
  extractPublicIdFromUrl,
  destroySingleFile,
} from "@/lib/cloudinary/cloudinary.service";
import type FeatureApi from "@/lib/featureApi";
import type {
  CreateProductInput,
  UpdateProductInput,
  ReorderProductsInput,
  DeleteProductsInput,
  CreateSupplierProductInput,
  ListProductsLocationOptions,
  // UpdateSupplierProductInput,
} from "./products.schema";
import {
  getCatalogLocationSettings,
  processCatalogByLocation,
  type CatalogGeoFields,
} from "@/lib/catalogLocation";
import { boundariesToPolygon, isPointInPolygon } from "@/lib/geo";
// handleImageService removed
import { validateDynamicAttributes } from "@/lib/attribute.utils";
import { Prisma } from "@prisma/client";
import {
  activeOfferWhere,
  buildSupplierProductPricing,
} from "@/lib/catalogHelpers";
import { parseProductImages, parseProductsImages } from "@/lib/productImages";

// ─── SKU / Barcode generators ─────────────────────────────────────────────────

export async function generateSKU(
  categoryId: number,
  productName: string,
): Promise<string> {
  try {
    const category = await prisma.category.findUnique({
      where: { id: categoryId },
      select: { name: true },
    });

    const categoryPrefix =
      category?.name?.substring(0, 3).toUpperCase() ?? "PRD";
    const namePrefix = productName
      .substring(0, 3)
      .toUpperCase()
      .replaceAll(/[^A-Z]/g, "");
    const timestamp = Date.now().toString().slice(-6);
    const random = Math.random().toString(36).substring(2, 5).toUpperCase();

    let sku = `${categoryPrefix}-${namePrefix}-${timestamp}-${random}`;
    let counter = 1;
    while (await prisma.product.findUnique({ where: { sku } })) {
      sku = `${categoryPrefix}-${namePrefix}-${timestamp}-${random}-${counter++}`;
    }
    return sku;
  } catch {
    return `PRD-${Date.now()}-${Math.random().toString(36).substring(2, 8).toUpperCase()}`;
  }
}

export async function generateBarcode(): Promise<string> {
  const companyPrefix = "123";
  const productCode = Math.random().toString().slice(2, 11);
  const baseNumber = companyPrefix + productCode;

  const calcCheckDigit = (base: string) => {
    let sum = 0;
    for (let i = 0; i < base.length; i++) {
      const digit = Number.parseInt(base[i], 10);
      sum += i % 2 === 0 ? digit : digit * 3;
    }
    return (10 - (sum % 10)) % 10;
  };

  let barcode = baseNumber + calcCheckDigit(baseNumber);
  let counter = 1;

  while (await prisma.product.findUnique({ where: { barcode } })) {
    const newCode = (Number.parseInt(productCode, 10) + counter++)
      .toString()
      .padStart(9, "0");
    const newBase = companyPrefix + newCode;
    barcode = newBase + calcCheckDigit(newBase);
  }

  return barcode;
}

// ─── Dynamic Attributes ───────────────────────────────────────────────────────

async function handleDynamicAttributes(
  categoryId: number,
  attributes?: { key: string; value: any; value_ar?: string }[],
) {
  const category = await prisma.category.findUnique({
    where: { id: categoryId },
    select: { product_attributes: true },
  });

  const rules = category?.product_attributes as Record<string, any> | null;

  const providedMap = (attributes || []).reduce(
    (acc, curr) => {
      acc[curr.key] = curr;
      return acc;
    },
    {} as Record<string, { value: any; value_ar?: string }>,
  );

  const finalAttributes: {
    key: string;
    value: any;
    value_ar?: string | null;
  }[] = [];

  if (rules) {
    for (const [key, rule] of Object.entries(rules)) {
      const provided = providedMap[key];

      if (provided) {
        finalAttributes.push({
          key,
          value: provided.value,
          value_ar: provided.value_ar ?? null,
        });
      } else if (rule.default !== undefined) {
        finalAttributes.push({ key, value: rule.default, value_ar: null });
      } else if (rule.required) {
        throw new HttpError(400, `Attribute "${key}" is required`);
      }
    }
  }

  const result = validateDynamicAttributes(
    rules || {},
    finalAttributes.map((a) => ({ key: a.key, value: a.value })),
  );

  if (!result.success) {
    throw new HttpError(
      400,
      `Attribute Error: ${result.error.issues[0].message}`,
    );
  }

  return finalAttributes.map((attr) => ({
    key: String(attr.key),
    value: String(attr.value),
    value_ar: attr.value_ar ? String(attr.value_ar) : null,
  }));
}

// ─── List ─────────────────────────────────────────────────────────────────────

// Shared SupplierProduct include for catalog listings.
// ✅ Called fresh on every request
function getSPInclude() {
  return {
    product: {
      include: {
        attributes: true,
      },
    },
    offers: {
      where: activeOfferWhere(), // ← now evaluated per-call
      take: 1,
    },
    supplier: {
      include: {
        user: {
          select: {
            personal_photo: true,
          },
        },
      },
    },
  } satisfies Prisma.SupplierProductInclude;
}

export async function listProductsService(data: FeatureApi["data"]) {
  const take = Number(data.take) || 10;
  const [totalProducts, products] = await prisma.$transaction([
    prisma.product.count({ where: data.where as any }),
    prisma.product.findMany(data as any),
  ]);

  return {
    totalProducts,
    totalPages: Math.ceil(totalProducts / take),
    products: parseProductsImages(products),
  };
}

// SupplierProduct include used for the location-aware catalog: also pulls the
// supplier's first (oldest) store address + its area's governorate so we can
// compute distance and filter by governorate.
export function getSPLocationInclude() {
  return {
    ...getSPInclude(),
    supplier: {
      select: {
        id: true,
        addresses: {
          orderBy: { created_at: "asc" },
          take: 1,
          select: {
            id: true,
            latitude: true,
            longitude: true,
            area: { select: { id: true, governorate_id: true } },
          },
        },
        user: {
          select: {
            personal_photo: true,
          },
        },
      },
    },
  } satisfies Prisma.SupplierProductInclude;
}

type SPLocationRow = Prisma.SupplierProductGetPayload<{
  include: ReturnType<typeof getSPLocationInclude>;
}>;

// Geo fields for a SupplierProduct = its supplier's first store address.
function supplierProductGeo(sp: SPLocationRow): CatalogGeoFields {
  const address = sp.supplier?.addresses?.[0] ?? null;
  return {
    lat: address?.latitude != null ? Number(address.latitude) : null,
    lng: address?.longitude != null ? Number(address.longitude) : null,
    governorateId: address?.area?.governorate_id ?? null,
    productId: sp.product_id,
    price: sp.price,
  };
}

// Maps a location-included SupplierProduct row to the catalog response shape.
function toSupplierProductCard(sp: SPLocationRow, distanceKm: number | null) {
  const { product, offers, supplier, ...spFields } = sp;
  const offer = offers[0] || null;
  const pricing = buildSupplierProductPricing(spFields as any, offer);

  return {
    ...parseProductImages(product),
    supplier_image: supplier?.user?.personal_photo || null,
    supplier_data: pricing,
    distance_km: distanceKm,
  };
}

export async function listAllSupplierProductsService(
  data: FeatureApi["data"],
  location?: ListProductsLocationOptions,
) {
  const take = Number(data.take) || 10;
  const skip = data.skip ?? 0;

  // Location-aware behaviour is controlled globally via ApplicationSetting.
  const settings = await getCatalogLocationSettings();

  const hasCoords = location?.lat != null && location?.lng != null;
  const needsLocationFlow =
    hasCoords || settings.sameGovernorate || settings.cheapestPerProduct;

  // ── Fast path: no location-aware options → simple paginated query ──
  if (!needsLocationFlow) {
    const [totalProducts, supplierProducts] = await prisma.$transaction([
      prisma.supplierProduct.count({ where: data.where as any }),
      prisma.supplierProduct.findMany({
        where: data.where as any,
        include: getSPInclude(),
        skip,
        take,
        orderBy: data.orderBy,
      }),
    ]);

    return {
      totalProducts,
      totalPages: Math.ceil(totalProducts / take),
      products: supplierProducts.map(({ product, offers, supplier, ...sp }) => {
        const offer = offers[0] || null;
        const pricing = buildSupplierProductPricing(sp as any, offer);

        return {
          ...parseProductImages(product),
          supplier_image: supplier?.user?.personal_photo || null,
          supplier_data: pricing,
        };
      }),
    };
  }

  // ── Location-aware flow: filter/sort in memory ──
  // (distance, governorate and cheapest-per-product all depend on the
  //  supplier's store address, so we resolve the full matching set first.)
  const supplierProducts = await prisma.supplierProduct.findMany({
    where: data.where as any,
    include: getSPLocationInclude(),
    orderBy: data.orderBy,
  });

  const processed = await processCatalogByLocation(
    supplierProducts,
    supplierProductGeo,
    location,
    settings,
  );

  const totalProducts = processed.length;
  const paged = processed.slice(skip, skip + take);

  return {
    totalProducts,
    totalPages: Math.ceil(totalProducts / take),
    products: paged.map(({ item, distanceKm }) =>
      toSupplierProductCard(item, distanceKm),
    ),
  };
}

// ─── Get by ID ────────────────────────────────────────────────────────────────

export async function getProductByIdService(data: FeatureApi["data"]) {
  const product = await prisma.product.findUnique(data as any);
  if (!product) throw new HttpError(404, "products:errors.not_found");
  return parseProductImages(product);
}

// ─── Create ───────────────────────────────────────────────────────────────────

export async function createProductService(
  data: CreateProductInput,
  queryOptions?: FeatureApi["data"]["select"],
  files?: { [fieldname: string]: Express.Multer.File[] },
) {
  const { attributes, ...rest } = data;

  const sku = rest.sku || (await generateSKU(rest.category_id, rest.name));
  const barcode = rest.barcode || (await generateBarcode());

  const existingProduct = await prisma.product.findFirst({
    where: { OR: [{ sku }, { barcode }] },
  });
  if (existingProduct?.sku === sku)
    throw new HttpError(400, "products:errors.sku_exists");
  if (existingProduct?.barcode === barcode)
    throw new HttpError(400, "products:errors.barcode_exists");

  const formattedAttributes = await handleDynamicAttributes(
    rest.category_id,
    attributes,
  );

  const imageFiles = Array.isArray(files) ? files : files?.["images"] || [];
  const imageUrls: string[] = [];
  for (const file of imageFiles) {
    const { secure_url } = await uploadSingleFile({
      fileLocation: file.path, // .path or .buffer
      storagePathOnCloudinary: "products",
    });
    if (secure_url) imageUrls.push(secure_url);
  }

  const product = await prisma.product.create({
    data: {
      ...rest,
      sku,
      barcode,
      images: imageUrls.length ? JSON.stringify(imageUrls) : null,
      attributes: formattedAttributes?.length
        ? { create: formattedAttributes }
        : undefined,
    },
    ...queryOptions,
  });

  return parseProductImages(product);
}

// ─── Update ───────────────────────────────────────────────────────────────────

export async function updateProductService(input: {
  id: number;
  data: UpdateProductInput;
  query?: FeatureApi["data"]["select"];
  files?: { [fieldname: string]: Express.Multer.File[] };
}) {
  const existing = await prisma.product.findUnique({
    where: { id: input.id },
  });
  if (!existing) throw new HttpError(404, "products:errors.not_found");

  const {
    attributes,
    deleteAttributes,
    deleteSpecificImages,
    deleteAllImages,
    replaceImages,
    ...rest
  } = input.data;

  // 1. Delete specific attributes
  if (deleteAttributes?.length) {
    await prisma.productAttribute.deleteMany({
      where: { id: { in: deleteAttributes } },
    });
  }

  // 2. Upsert dynamic attributes
  let attributeOps;
  if (attributes?.length) {
    const formatted = await handleDynamicAttributes(
      rest.category_id || existing.category_id,
      attributes,
    );
    attributeOps = {
      upsert: formatted?.map((a) => ({
        where: { product_id_key: { product_id: input.id, key: a.key } },
        create: a,
        update: a,
      })),
    };
  }

  // 3. Image logic
  let updatedImages: string[] = JSON.parse(existing.images ?? "[]");

  if (deleteAllImages) {
    for (const img of updatedImages) {
      const publicId = extractPublicIdFromUrl(img);
      if (publicId) await destroySingleFile({ public_id: publicId }).catch(console.error);
    }
    updatedImages = [];
  }
  if (deleteSpecificImages?.length) {
    for (const img of deleteSpecificImages) {
      const publicId = extractPublicIdFromUrl(img);
      if (publicId) await destroySingleFile({ public_id: publicId }).catch(console.error);
    }
    updatedImages = updatedImages.filter(
      (img) => !deleteSpecificImages.includes(img),
    );
  }

  const newFiles = Array.isArray(input.files)
    ? input.files
    : input.files?.["images"] || [];
  console.log(newFiles);
  if (newFiles.length > 0) {
    const uploaded = (
      await Promise.all(
        newFiles.map(async (file) => {
          const { secure_url } = await uploadSingleFile({
            fileLocation: file.path, // .path or .buffer
            storagePathOnCloudinary: "products",
          });
          return secure_url;
        })
      )
    ).filter(Boolean) as string[];

    if (replaceImages) {
      for (const img of updatedImages) {
        const publicId = extractPublicIdFromUrl(img);
        if (publicId) await destroySingleFile({ public_id: publicId }).catch(console.error);
      }
    }
    updatedImages = replaceImages ? uploaded : [...updatedImages, ...uploaded];
  }

  // 4. Perform update
  const product = prisma.product.update({
    where: { id: input.id },
    data: {
      ...rest,
      images: updatedImages.length ? JSON.stringify(updatedImages) : null,
      attributes: attributeOps,
    },
    ...input.query,
  });
  return parseProductImages(product);
}

// ─── SupplierProduct: Upsert ──────────────────────────────────────────────────

export async function supplierProductService(
  productId: number,
  data: CreateSupplierProductInput,
) {
  // 1. Validate product + supplier in parallel
  const [product, supplier] = await Promise.all([
    prisma.product.findUnique({ where: { id: productId } }),
    prisma.supplier.findUnique({ where: { id: data.supplier_id } }),
  ]);

  if (!product) {
    throw new HttpError(404, "products:errors.not_found");
  }

  if (!supplier) {
    throw new HttpError(404, "suppliers:errors.not_found");
  }

  // Auto-compute price from cost_price × markup_ratio when price not provided
  const resolvedData = { ...data };
  if (
    resolvedData.price == null &&
    resolvedData.cost_price != null &&
    supplier.markup_ratio != null
  ) {
    resolvedData.price =
      Math.round(resolvedData.cost_price * supplier.markup_ratio * 100) / 100;
  }

  try {
    // 2. Upsert supplier_product and sync supplier_category in one transaction
    const [supplierProduct] = await prisma.$transaction([
      prisma.supplierProduct.upsert({
        where: {
          supplier_id_product_id: {
            supplier_id: data.supplier_id,
            product_id: productId,
          },
        },
        update: { ...resolvedData },
        create: { ...resolvedData, product_id: productId },
      }),
      prisma.supplierCategory.upsert({
        where: {
          supplier_id_category_id: {
            supplier_id: data.supplier_id,
            category_id: product.category_id,
          },
        },
        update: { deleted_at: null },
        create: {
          supplier_id: data.supplier_id,
          category_id: product.category_id,
        },
      }),
    ]);
    return supplierProduct;
  } catch (err: any) {
    if (err.code === "P2002") {
      throw new HttpError(409, "products:errors.supplier_product_exists");
    }
    throw err;
  }
}

// ─── SupplierProduct: Get all for product ────────────────────────────────────

export async function getProductSuppliersService(productId: number) {
  return prisma.supplierProduct.findMany({
    where: { product_id: productId, deleted_at: null },
    include: {
      supplier: {
        select: {
          id: true,
          is_approved: true,
          user: {
            select: {
              id: true,
              full_name: true,
              phone: true,
              email: true,
              personal_photo: true,
            },
          },
        },
      },
    },
    orderBy: { created_at: "asc" },
  });
}

// ─── SupplierProduct: Update ──────────────────────────────────────────────────

export async function updateSupplierProductService(
  productId: number,
  spId: number,
  data: Partial<CreateSupplierProductInput>,
) {
  const existing = await prisma.supplierProduct.findFirst({
    where: { id: spId, product_id: productId },
  });
  if (!existing)
    throw new HttpError(404, "products:errors.supplier_product_not_found");

  return prisma.supplierProduct.update({
    where: { id: spId },
    data,
    include: {
      supplier: {
        select: {
          id: true,
          user: {
            select: { id: true, full_name: true, phone: true, email: true },
          },
        },
      },
    },
  });
}

// ─── SupplierProduct: Reset price to markup default ──────────────────────────

export async function resetSupplierProductPriceService(
  productId: number,
  spId: number,
) {
  const sp = await prisma.supplierProduct.findFirst({
    where: { id: spId, product_id: productId },
    include: { supplier: { select: { markup_ratio: true } } },
  });
  if (!sp)
    throw new HttpError(404, "products:errors.supplier_product_not_found");

  if (sp.cost_price == null || sp.supplier.markup_ratio == null) {
    throw new HttpError(400, "products:errors.cannot_compute_price"); // cost or ratio missing
  }

  const defaultPrice =
    Math.round(sp.cost_price * sp.supplier.markup_ratio * 100) / 100;

  return prisma.supplierProduct.update({
    where: { id: spId },
    data: { price: defaultPrice },
  });
}

// ─── SupplierProduct: Delete ──────────────────────────────────────────────────

export async function deleteSupplierProductService(
  productId: number,
  spId: number,
) {
  const existing = await prisma.supplierProduct.findFirst({
    where: { id: spId, product_id: productId },
  });
  if (!existing)
    throw new HttpError(404, "products:errors.supplier_product_not_found");

  await prisma.supplierProduct.delete({ where: { id: spId } });
  return { ok: true as const };
}

// ─── SupplierProduct: List ──────────────────────────────────────────────────

export async function listSupplierProductsService(
  data: Omit<FeatureApi["data"], "select" | "include">,
) {
  const take = Number(data.take) || 10;
  const [totalProducts, supplierProducts] = await prisma.$transaction([
    prisma.supplierProduct.count({ where: data.where }),
    prisma.supplierProduct.findMany({
      where: data.where,
      include: getSPInclude(),
      skip: data.skip,
      take,
      orderBy: data.orderBy,
    }),
  ]);

  return {
    totalProducts,
    totalPages: Math.ceil(totalProducts / take),
    products: supplierProducts.map(({ product, offers, supplier, ...sp }) => {
      const offer = offers[0] || null;
      console.log("offer", offer);

      const pricing = buildSupplierProductPricing(sp as any, offer);

      return {
        ...parseProductImages(product),
        supplier_image: supplier?.user?.personal_photo || null,
        supplier_data: pricing,
      };
    }),
  };
}

// NOTE: last-bought intentionally ignores the customer_home_products_* settings
// (radius / same_governorate / cheapest). It simply returns the supplier
// products the customer most recently bought, newest first.
export async function listLastBoughtSupplierProductsService(
  supplierId: number | null,
  customerId: number,
  productFilters: Prisma.ProductWhereInput,
) {
  const LIMIT = 5;

  const recentItems = await prisma.orderItem.findMany({
    where: {
      supplierProduct: {
        ...(supplierId ? { supplier_id: supplierId } : {}),
        deleted_at: null,
        is_active: true,
        supplier: {
          is_approved: true,
          deleted_at: null,
        },
      },
      order: {
        status: "DELIVERED",
        customer_id: customerId,
      },
      product: productFilters,
    },
    select: {
      sp_id: true,
      order: { select: { delivered_at: true } },
    },
    orderBy: { order: { delivered_at: "desc" } },
    distinct: ["sp_id"],
    take: LIMIT,
  });

  if (recentItems.length === 0) {
    return { totalProducts: 0, totalPages: 0, products: [] };
  }

  const spIds = recentItems.map((i) => i.sp_id);

  const supplierProducts = await prisma.supplierProduct.findMany({
    where: {
      id: { in: spIds },
      product: productFilters,
    },
    include: getSPInclude(),
  });

  const ordered = spIds
    .map((id) => supplierProducts.find((sp) => sp.id === id))
    .filter((sp): sp is (typeof supplierProducts)[number] => sp != null);

  return {
    totalProducts: ordered.length,
    totalPages: 1,
    products: ordered.map(({ product, offers, supplier, ...sp }) => {
      const offer = offers[0] || null;
      const pricing = buildSupplierProductPricing(sp as any, offer);
      return { 
        ...parseProductImages(product), 
        supplier_image: supplier?.user?.personal_photo || null,
        supplier_data: pricing 
      };
    }),
  };
}

export async function listBestSellerSupplierProductsService(
  supplierId: number | null,
  productFilters: Prisma.ProductWhereInput,
  location?: ListProductsLocationOptions,
) {
  const LIMIT = 10;

  const bestSellers = await prisma.orderItem.groupBy({
    by: ["sp_id"],
    where: {
      order: {
        status: "DELIVERED",
      },
      supplierProduct: {
        ...(supplierId ? { supplier_id: supplierId } : {}),
        deleted_at: null,
        is_active: true,
        supplier: {
          is_approved: true,
          deleted_at: null,
        },
      },
      product: productFilters,
    },
    _sum: {
      quantity: true,
    },
    orderBy: {
      _sum: {
        quantity: "desc",
      },
    },
    take: LIMIT,
  });

  if (bestSellers.length === 0) {
    return { totalProducts: 0, totalPages: 0, products: [] };
  }

  const spIds = bestSellers.map((i) => i.sp_id);

  const supplierProducts = await prisma.supplierProduct.findMany({
    where: {
      id: { in: spIds },
      product: productFilters,
    },
    // location include → carries the supplier's first store address so the
    // radius / same-governorate / cheapest filters below can be applied.
    include: getSPLocationInclude(),
  });

  const ordered = spIds
    .map((id) => supplierProducts.find((sp) => sp.id === id))
    .filter((sp): sp is SPLocationRow => sp != null);

  // Apply location filters + cheapest ordering, but keep the best-seller
  // ranking (no nearest-first re-sort).
  const settings = await getCatalogLocationSettings();
  const processed = await processCatalogByLocation(
    ordered,
    supplierProductGeo,
    location,
    settings,
    { sortByDistance: false },
  );

  return {
    totalProducts: processed.length,
    totalPages: 1,
    products: processed.map(({ item, distanceKm }) =>
      toSupplierProductCard(item, distanceKm),
    ),
  };
}

// ─── SupplierProduct: Get by ID ──────────────────────────────────────────────────

export async function getSupplierProductByIdService(
  productId: number,
  supplierId: number,
) {
  const sp = await prisma.supplierProduct.findFirst({
    where: {
      supplier_id: supplierId,
      product_id: productId,
      deleted_at: null,
      product: {
        deleted_at: null,
      },
    },
    include: getSPInclude(),
  });

  if (!sp) {
    throw new HttpError(
      404,
      "products:errors.not_found",
      "PRODUCT_NOT_FOUND_FOR_SUPPLIER",
      {
        product_id: productId,
        supplier_id: supplierId,
      },
    );
  }

  const { product, offers, supplier, ...spFields } = sp;

  const offer = offers[0] || null;
  const pricing = buildSupplierProductPricing(spFields as any, offer);

  return {
    ...parseProductImages(product),
    supplier_image: supplier?.user?.personal_photo || null,
    supplier_data: pricing,
  };
}

// ─── Reorder ──────────────────────────────────────────────────────────────────

export async function reorderProductsService(input: ReorderProductsInput) {
  const caseSql = input.products
    .map((p) => `WHEN ${p.id} THEN ${p.sort_id}`)
    .join(" ");
  const idsSql = input.products.map((p) => p.id).join(",");

  await prisma.$executeRawUnsafe(`
    UPDATE product
    SET sort_id = CASE id ${caseSql} END
    WHERE id IN (${idsSql});
  `);

  return { ok: true as const };
}

// ─── Delete (strategy pattern) ────────────────────────────────────────────────

export async function deleteProductsService(input: DeleteProductsInput) {
  const strategies = {
    // A product is "inactive" when none of its supplier links are active
    inactive: () =>
      prisma.product.deleteMany({
        where: { suppliers: { none: { is_active: true } } },
      }),
    // Out of stock: all supplier links have stock === 0
    outOfStock: () =>
      prisma.product.deleteMany({
        where: { suppliers: { every: { stock: 0 } } },
      }),
    // Low stock: all supplier links are at or below their own min_stock
    lowStock: () =>
      prisma.product.deleteMany({
        where: {
          suppliers: {
            every: {
              stock: { lte: 5 }, // fallback; ideally compare per-row — see note
            },
          },
        },
      }),
    ids: async () => {
      if (input.strategy !== "ids") return Promise.resolve({ count: 0 });
      if (input.archived) {
        return prisma.product.updateMany({
          where: { id: { in: input.ids } },
          data: { deleted_at: new Date() },
        });
      }

      try {
        await prisma.supplierProduct.deleteMany({
          where: { product_id: { in: input.ids } },
        });
        return await prisma.product.deleteMany({
          where: { id: { in: input.ids } },
        });
      } catch (error: any) {
        if (error.code === "P2003") {
          throw new HttpError(400, "products:errors.cannot_delete_in_use");
        }
        throw error;
      }
    },
  };

  return strategies[input.strategy]();
}

// ─── Delete single ────────────────────────────────────────────────────────────

export async function deleteProductService(input: {
  id: number;
  permanent?: boolean;
  archived?: boolean;
}) {
  const existing = await prisma.product.findUnique({
    where: { id: input.id },
  });
  if (!existing) throw new HttpError(404, "products:errors.not_found");

  if (input.archived && !input.permanent) {
    return prisma.product.update({
      where: { id: input.id },
      data: { deleted_at: new Date() },
    });
  }

  // Hard delete: clean up images first
  try {
    const images = JSON.parse(existing.images ?? "[]");
    if (Array.isArray(images)) {
      for (const img of images) {
        const publicId = extractPublicIdFromUrl(img);
        if (publicId) {
          await destroySingleFile({ public_id: publicId }).catch(console.error);
        }
      }
    }
  } catch {
    /* empty */
  }

  try {
    // Attempt to clean up supplier links if there are no other dependent records (e.g. orders)
    await prisma.supplierProduct.deleteMany({
      where: { product_id: input.id },
    });
    await prisma.product.delete({ where: { id: input.id } });
  } catch (error: any) {
    if (error.code === "P2003") {
      throw new HttpError(400, "products:errors.cannot_delete_in_use");
    }
    throw error;
  }

  return { ok: true as const };
}
