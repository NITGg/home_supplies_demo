// lib/geo.ts
// Lightweight geo helpers for distance + point-in-area (governorate) lookups.

export type LatLng = { lat: number; lng: number };

/**
 * Great-circle distance between two coordinates in kilometers (Haversine).
 * replaced with function getRoadDistanceM
 */
// export function haversineKm(
//   lat1: number,
//   lng1: number,
//   lat2: number,
//   lng2: number,
// ): number {
//   const R = 6371; // earth radius in km
//   const toRad = (d: number) => (d * Math.PI) / 180;

//   const dLat = toRad(lat2 - lat1);
//   const dLng = toRad(lng2 - lng1);

//   const a =
//     Math.sin(dLat / 2) ** 2 +
//     Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLng / 2) ** 2;

//   return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
// }

/**
 * Converts an Area.boundaries JSON value into an ordered polygon.
 * Expected shape: { point1: { lat, lng }, point2: { lat, lng }, ... }
 * Points are ordered by their numeric suffix (point1, point2, ...).
 */
export function boundariesToPolygon(boundaries: unknown): LatLng[] {
  if (!boundaries || typeof boundaries !== "object") return [];

  const obj = boundaries as Record<string, unknown>;

  return Object.keys(obj)
    .filter((k) => /^point\d+$/.test(k))
    .sort((a, b) => Number(a.slice(5)) - Number(b.slice(5)))
    .map((k) => obj[k])
    .filter(
      (p): p is LatLng =>
        !!p &&
        typeof p === "object" &&
        typeof (p as LatLng).lat === "number" &&
        typeof (p as LatLng).lng === "number",
    )
    .map((p) => ({ lat: p.lat, lng: p.lng }));
}

/**
 * Ray-casting point-in-polygon test. Treats lng as x and lat as y.
 * Returns false for degenerate polygons (< 3 vertices).
 */
export function isPointInPolygon(
  lat: number,
  lng: number,
  polygon: LatLng[],
): boolean {
  if (polygon.length < 3) return false;

  let inside = false;
  for (let i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
    const xi = polygon[i].lng;
    const yi = polygon[i].lat;
    const xj = polygon[j].lng;
    const yj = polygon[j].lat;

    const intersect =
      yi > lat !== yj > lat &&
      lng < ((xj - xi) * (lat - yi)) / (yj - yi) + xi;

    if (intersect) inside = !inside;
  }

  return inside;
}
