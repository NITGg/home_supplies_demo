// lib/catalogLocation.ts
// Shared "customer location" catalog behaviour, driven by ApplicationSetting:
//   - customer_home_products_radius_km            → hide items farther than N km
//   - customer_home_products_same_governorate     → only items in the customer's governorate
//   - customer_home_products_cheapest_per_product → order the cheapest variant first
//                                                   within each product_id group
import { z } from "zod";
import { prisma } from "@/config/prisma";
import { boundariesToPolygon, isPointInPolygon } from "./geo";
import { getRoadDistanceM } from "./distance";

// ─── Customer location (request body) ─────────────────────────────────────────

export const customerLocationSchema = z.object({
  lat: z.coerce.number().min(-90).max(90).optional(),
  lng: z.coerce.number().min(-180).max(180).optional(),
});

export type CustomerLocation = z.infer<typeof customerLocationSchema>;

// ─── Settings ─────────────────────────────────────────────────────────────────

export interface CatalogLocationSettings {
  radiusKm: number | null;
  sameGovernorate: boolean;
  cheapestPerProduct: boolean;
}

export async function getCatalogLocationSettings(): Promise<CatalogLocationSettings> {
  const settings = await prisma.applicationSetting.findFirst({
    select: {
      customer_home_products_radius_km: true,
      customer_home_products_same_governorate: true,
      customer_home_products_cheapest_per_product: true,
    },
  });

  return {
    radiusKm:
      settings?.customer_home_products_radius_km != null
        ? Number(settings.customer_home_products_radius_km)
        : null,
    sameGovernorate: !!settings?.customer_home_products_same_governorate,
    cheapestPerProduct: !!settings?.customer_home_products_cheapest_per_product,
  };
}

// ─── Governorate resolver ─────────────────────────────────────────────────────

// Resolve the governorate that contains a customer's coordinates by testing the
// point against every active area's boundary polygon.
export async function findGovernorateIdForPoint(
  lat: number,
  lng: number,
): Promise<number | null> {
  const areas = await prisma.area.findMany({
    where: { is_active: true },
    select: { governorate_id: true, boundaries: true },
  });

  for (const area of areas) {
    const polygon = boundariesToPolygon(area.boundaries);
    if (isPointInPolygon(lat, lng, polygon)) return area.governorate_id;
  }

  return null;
}

// ─── Generic location processing ──────────────────────────────────────────────

export interface CatalogGeoFields {
  lat: number | null;
  lng: number | null;
  governorateId: number | null;
  // Only used for the cheapest-per-product ordering (omit for non-product lists).
  productId?: number | null;
  price?: number | null;
}

export interface ProcessCatalogOptions {
  // When true, the result is sorted nearest-first (used for plain catalog &
  // supplier listings). When false, the input order is preserved (e.g. keep the
  // best-seller / recency ranking) and only filters + cheapest ordering apply.
  sortByDistance?: boolean;
  // Enable the cheapest-per-product ordering (off for lists without a product).
  cheapest?: boolean;
}

/**
 * Applies the radius / same-governorate filters, optional nearest-first sort and
 * cheapest-per-product ordering to an arbitrary list of items.
 *
 * Returns the surviving items (in final order) paired with their computed
 * distance in km (null when the customer has no coordinates or the item has no
 * usable location). Pagination is the caller's responsibility.
 */
export async function processCatalogByLocation<T>(
  items: T[],
  getGeo: (item: T) => CatalogGeoFields,
  location: CustomerLocation | undefined,
  settings: CatalogLocationSettings,
  options: ProcessCatalogOptions = {},
): Promise<Array<{ item: T; distanceKm: number | null }>> {
  const { sortByDistance = true, cheapest = true } = options;
  const hasCoords = location?.lat != null && location?.lng != null;

  const customerGovernorateId =
    settings.sameGovernorate && hasCoords
      ? await findGovernorateIdForPoint(location!.lat!, location!.lng!)
      : null;

  let enriched = await Promise.all(
    items.map(async (item) => {
      const geo = getGeo(item);
      let distanceKm: number | null = null;
      if (hasCoords && geo.lat != null && geo.lng != null) {
        try {
          const result = await getRoadDistanceM(
            { lat: geo.lat, lng: geo.lng },
            { lat: location!.lat!, lng: location!.lng! },
          );
          distanceKm = result.distance / 1000; // meters → km
        } catch {
          distanceKm = null;
        }
      }
      return { item, geo, distanceKm };
    }),
  );

  // Same-governorate filter: requires a resolvable customer governorate.
  // Skip entirely when the customer sent no coordinates → return all data
  // (no location filtering applied).
  if (hasCoords && settings.sameGovernorate) {
    enriched =
      customerGovernorateId == null
        ? []
        : enriched.filter((e) => e.geo.governorateId === customerGovernorateId);
  }

  // Radius filter: drop items whose location is beyond the configured distance
  // (or that have no usable location).
  if (hasCoords && settings.radiusKm != null) {
    enriched = enriched.filter(
      (e) => e.distanceKm != null && e.distanceKm <= settings.radiusKm!,
    );
  }

  // Normal sort: nearest first when requested and coordinates are available.
  if (sortByDistance && hasCoords) {
    enriched.sort(
      (a, b) =>
        (a.distanceKm ?? Number.POSITIVE_INFINITY) -
        (b.distanceKm ?? Number.POSITIVE_INFINITY),
    );
  }

  // Cheapest-per-product: keep every item in its current (normal) position, but
  // when several items share the same product_id, order the cheaper ones ahead
  // of the dearer ones within the slots those duplicates already occupy.
  if (cheapest && settings.cheapestPerProduct) {
    const slotsByProduct = new Map<number, number[]>();
    enriched.forEach((e, idx) => {
      const pid = e.geo.productId;
      if (pid == null) return;
      const slots = slotsByProduct.get(pid) ?? [];
      slots.push(idx);
      slotsByProduct.set(pid, slots);
    });

    for (const slots of slotsByProduct.values()) {
      if (slots.length < 2) continue;
      const group = slots.map((i) => enriched[i]);
      group.sort(
        (a, b) =>
          (a.geo.price ?? Number.POSITIVE_INFINITY) -
          (b.geo.price ?? Number.POSITIVE_INFINITY),
      );
      slots.forEach((slot, k) => {
        enriched[slot] = group[k];
      });
    }
  }

  return enriched.map((e) => ({ item: e.item, distanceKm: e.distanceKm }));
}
