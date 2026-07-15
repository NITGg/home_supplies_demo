import { Prisma } from "@prisma/client";
import { prisma } from "@/config/prisma";
import {
  activeOfferWhere,
  buildSupplierProductPricing,
} from "@/lib/catalogHelpers";
import { parseProductImages } from "@/lib/productImages";
import {
  getCatalogLocationSettings,
  processCatalogByLocation,
  type CatalogGeoFields,
  type CustomerLocation,
} from "@/lib/catalogLocation";

// ─── Keyword WHERE clauses ────────────────────────────────────────────────────

function productKeywordWhere(keyword: string) {
  return {
    deleted_at: null,
    OR: [
      { name: { contains: keyword } },
      { name_ar: { contains: keyword } },
      { description: { contains: keyword } },
      { description_ar: { contains: keyword } },
      { sku: { contains: keyword } },
      { barcode: { contains: keyword } },
      { synonyms: { contains: keyword } },
    ],
  };
}

function supplierProductWhere(keyword: string) {
  return {
    is_active: true,
    deleted_at: null,
    OR: [
      { product: { ...productKeywordWhere(keyword) } },
      {
        product: {
          deleted_at: null,
          category: {
            OR: [
              { name: { contains: keyword } },
              { name_ar: { contains: keyword } },
              { synonyms: { contains: keyword } },
            ],
          },
        },
      },
      {
        product: {
          deleted_at: null,
          brand: {
            OR: [
              { name: { contains: keyword } },
              { name_ar: { contains: keyword } },
              { synonyms: { contains: keyword } },
            ],
          },
        },
      },
    ],
  };
}

// ─── Include helpers ──────────────────────────────────────────────────────────

function getSPInclude() {
  return {
    product: { include: { attributes: true } },
    offers: { where: activeOfferWhere(), take: 1 },
  } satisfies Prisma.SupplierProductInclude;
}

function getSPLocationInclude() {
  return {
    ...getSPInclude(),
    supplier: {
      select: {
        id: true,
        addresses: {
          orderBy: { created_at: "asc" as const },
          take: 1,
          select: {
            latitude: true,
            longitude: true,
            area: { select: { id: true, governorate_id: true } },
          },
        },
        user: { select: { id: true, full_name: true, personal_photo: true } },
      },
    },
  } satisfies Prisma.SupplierProductInclude;
}

// ─── Types ────────────────────────────────────────────────────────────────────

type SPLocationRow = Prisma.SupplierProductGetPayload<{
  include: ReturnType<typeof getSPLocationInclude>;
}>;

// ─── Geo extractor ────────────────────────────────────────────────────────────

function spGeo(sp: SPLocationRow): CatalogGeoFields {
  const address = sp.supplier?.addresses?.[0] ?? null;
  return {
    lat: address?.latitude != null ? Number(address.latitude) : null,
    lng: address?.longitude != null ? Number(address.longitude) : null,
    governorateId: address?.area?.governorate_id ?? null,
    productId: sp.product_id,
    price: sp.price != null ? Number(sp.price) : null,
  };
}

// ─── Response mapper ──────────────────────────────────────────────────────────

function toSearchCard(sp: SPLocationRow, distanceKm: number | null) {
  const { product, offers, ...spFields } = sp;
  const offer = offers[0] ?? null;
  const pricing = buildSupplierProductPricing(spFields as any, offer);
  return {
    ...parseProductImages(product),
    supplier_data: pricing,
    distance_km: distanceKm,
  };
}

// ─── Service ──────────────────────────────────────────────────────────────────

export async function searchGlobalService(
  keyword: string,
  location?: CustomerLocation,
) {
  const [settings, brands, categories] = await Promise.all([
    getCatalogLocationSettings(),

    prisma.brand.findMany({
      where: {
        OR: [
          { name: { contains: keyword } },
          { name_ar: { contains: keyword } },
          { description: { contains: keyword } },
          { description_ar: { contains: keyword } },
          { synonyms: { contains: keyword } },
        ],
        deleted_at: null,
        is_active: true,
      },
      take: 10,
    }),

    prisma.category.findMany({
      where: {
        OR: [
          { name: { contains: keyword } },
          { name_ar: { contains: keyword } },
          { description: { contains: keyword } },
          { description_ar: { contains: keyword } },
          { synonyms: { contains: keyword } },
        ],
        is_active: true,
        deleted_at: null,
      },
      take: 10,
    }),
  ]);

  const hasCoords = location?.lat != null && location?.lng != null;
  const needsLocationFlow =
    hasCoords || settings.sameGovernorate || settings.cheapestPerProduct;

  // ── Fast path ────────────────────────────────────────────────────────────
  if (!needsLocationFlow) {
    const rows = await prisma.supplierProduct.findMany({
      where: supplierProductWhere(keyword),
      include: getSPInclude(),
      take: 20,
    });

    return {
      brands,
      categories,
      supplierProducts: rows.map(({ product, offers, ...sp }) => {
        const offer = offers[0] ?? null;
        const pricing = buildSupplierProductPricing(sp, offer);
        return { ...parseProductImages(product), supplier_data: pricing };
      }),
    };
  }

  // ── Location-aware path ──────────────────────────────────────────────────
  const rows = await prisma.supplierProduct.findMany({
    where: supplierProductWhere(keyword),
    include: getSPLocationInclude(),
  });

  const processed = await processCatalogByLocation(
    rows as SPLocationRow[],
    spGeo,
    location,
    settings,
  );

  return {
    brands,
    categories,
    supplierProducts: processed
      .slice(0, 20)
      .map(({ item, distanceKm }) => toSearchCard(item, distanceKm)),
  };
}
