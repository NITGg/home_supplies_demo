/**
 * Area boundary validation — web replica of the Flutter app's
 * `AreaBoundaryValidator` (see `lib/core/utils/area_boundry_validator.dart`).
 *
 * Used to confirm a picked pickup/delivery pin actually falls inside the
 * area the user selected before an order can be created.
 */

export interface LatLng {
  lat: number;
  lng: number;
}

/**
 * Raw boundaries as returned by the API. Each value is either:
 *  - a `"lat,lng"` string, or
 *  - a `{ lat, lng }` object.
 * Keys are `point1`, `point2`, … (arbitrary count, sorted alphabetically).
 */
export type RawBoundaries =
  | Record<string, string | { lat: number; lng: number }>
  | null
  | undefined;

/** Parse the boundaries map into an ordered list of points (keys sorted alphabetically). */
export function parseBoundaries(boundaries: unknown): LatLng[] {
  if (!boundaries || typeof boundaries !== "object") return [];
  const record = boundaries as Record<string, unknown>;
  const points: LatLng[] = [];

  for (const key of Object.keys(record).sort()) {
    const value = record[key];
    if (value == null) continue;

    if (typeof value === "string") {
      const [latStr, lngStr] = value.split(",");
      const lat = parseFloat(latStr);
      const lng = parseFloat(lngStr);
      if (Number.isFinite(lat) && Number.isFinite(lng)) points.push({ lat, lng });
    } else if (typeof value === "object") {
      const obj = value as { lat?: unknown; lng?: unknown };
      const lat = Number(obj.lat);
      const lng = Number(obj.lng);
      if (Number.isFinite(lat) && Number.isFinite(lng)) points.push({ lat, lng });
    }
  }

  return points;
}

/**
 * Returns true if the point lies inside the area boundaries.
 *  - 0 points  → permissive (no restriction defined) → true
 *  - 2 points  → treated as opposite corners of a bounding box
 *  - 3+ points → ray-casting point-in-polygon test
 */
export function isPointInArea(lat: number, lng: number, boundaries: unknown): boolean {
  if (!Number.isFinite(lat) || !Number.isFinite(lng)) return true; // unparseable → skip
  const pts = parseBoundaries(boundaries);
  if (pts.length === 0) return true; // no boundaries → permissive

  if (pts.length === 2) {
    const minLat = Math.min(pts[0].lat, pts[1].lat);
    const maxLat = Math.max(pts[0].lat, pts[1].lat);
    const minLng = Math.min(pts[0].lng, pts[1].lng);
    const maxLng = Math.max(pts[0].lng, pts[1].lng);
    return lat >= minLat && lat <= maxLat && lng >= minLng && lng <= maxLng;
  }

  // Ray-casting: count how many times a ray to the right crosses polygon edges.
  let crossings = 0;
  for (let i = 0; i < pts.length; i++) {
    const a = pts[i];
    const b = pts[(i + 1) % pts.length];
    const straddles =
      (a.lng <= lng && lng < b.lng) || (b.lng <= lng && lng < a.lng);
    if (straddles && b.lng !== a.lng) {
      const intersectLat = ((b.lat - a.lat) / (b.lng - a.lng)) * (lng - a.lng) + a.lat;
      if (lat < intersectLat) crossings++;
    }
  }
  return crossings % 2 === 1;
}

/** Average of all boundary points — used to center the map on the area. */
export function areaCentroid(boundaries: unknown): LatLng | null {
  const pts = parseBoundaries(boundaries);
  if (pts.length === 0) return null;
  const lat = pts.reduce((sum, p) => sum + p.lat, 0) / pts.length;
  const lng = pts.reduce((sum, p) => sum + p.lng, 0) / pts.length;
  return { lat, lng };
}

/**
 * Scan a list of areas and return the first one whose (non-empty) boundaries
 * contain the point. Used to auto-detect the area from a dropped pin.
 */
export function findAreaContainingPoint<T extends { boundaries?: unknown }>(
  lat: number,
  lng: number,
  areas: T[],
): T | null {
  for (const area of areas) {
    if (parseBoundaries(area.boundaries).length === 0) continue; // ignore permissive areas
    if (isPointInArea(lat, lng, area.boundaries)) return area;
  }
  return null;
}
