import axios from "axios";

type BoundariesRecord = Record<string, { lat: number; lng: number }>;

// Cache to avoid re-fetching the same governorate boundary
const cache = new Map<string, BoundariesRecord | null>();

/**
 * Fetch the administrative boundary of an Egyptian governorate from OpenStreetMap (Nominatim).
 * Returns a BoundariesRecord suitable for rendering on the map.
 */
export const fetchGovernorateBoundary = async (
  governorateName: string,
): Promise<BoundariesRecord | null> => {
  if (!governorateName) return null;

  const cacheKey = governorateName.toLowerCase().trim();
  if (cache.has(cacheKey)) return cache.get(cacheKey) ?? null;

  try {
    const query = `${governorateName} Governorate, Egypt`;
    const url = `https://nominatim.openstreetmap.org/search?q=${encodeURIComponent(
      query,
    )}&format=json&polygon_geojson=1&limit=1`;

    const response = await axios.get(url, {
      headers: {
        "User-Agent": "TawreedatGoAdmin/1.0",
        "Accept-Language": "en",
      },
    });

    const data = response.data;
    if (data && data.length > 0 && data[0].geojson) {
      const geojson = data[0].geojson;
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      let coords: any[] = [];

      if (geojson.type === "Polygon") {
        coords = geojson.coordinates[0];
      } else if (geojson.type === "MultiPolygon") {
        // Take the largest polygon (outer boundary)
        let maxLen = 0;
        for (const poly of geojson.coordinates) {
          if (poly[0].length > maxLen) {
            maxLen = poly[0].length;
            coords = poly[0];
          }
        }
      }

      if (coords && coords.length > 0) {
        const boundaryObj: BoundariesRecord = {};
        // Decimate points if there are too many (Nominatim can return thousands)
        const step = Math.max(1, Math.floor(coords.length / 500));

        let ptIdx = 1;
        for (let i = 0; i < coords.length; i += step) {
          const coord = coords[i];
          boundaryObj[`point${ptIdx}`] = { lat: coord[1], lng: coord[0] }; // GeoJSON is [lng, lat]
          ptIdx++;
        }
        cache.set(cacheKey, boundaryObj);
        return boundaryObj;
      }
    }
    cache.set(cacheKey, null);
    return null;
  } catch (error) {
    console.error("Nominatim fetch error:", error);
    return null;
  }
};

/**
 * Fetch the administrative boundary of an area within an Egyptian governorate
 * from OpenStreetMap (Nominatim).
 * Returns a BoundariesRecord suitable for rendering on the map.
 */
export const fetchAreaBoundary = async (
  areaName: string,
  governorateName: string,
): Promise<BoundariesRecord | null> => {
  if (!areaName || !governorateName) return null;

  const cacheKey = `area:${areaName.toLowerCase().trim()}:${governorateName.toLowerCase().trim()}`;
  if (cache.has(cacheKey)) return cache.get(cacheKey) ?? null;

  try {
    const query = `${areaName}, ${governorateName} Governorate, Egypt`;
    const url = `https://nominatim.openstreetmap.org/search?q=${encodeURIComponent(
      query,
    )}&format=json&polygon_geojson=1&limit=1`;

    const response = await axios.get(url, {
      headers: {
        "User-Agent": "TawreedatGoAdmin/1.0",
        "Accept-Language": "en",
      },
    });

    const data = response.data;
    if (data && data.length > 0 && data[0].geojson) {
      const geojson = data[0].geojson;
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      let coords: any[] = [];

      if (geojson.type === "Polygon") {
        coords = geojson.coordinates[0];
      } else if (geojson.type === "MultiPolygon") {
        let maxLen = 0;
        for (const poly of geojson.coordinates) {
          if (poly[0].length > maxLen) {
            maxLen = poly[0].length;
            coords = poly[0];
          }
        }
      }

      if (coords && coords.length > 0) {
        const boundaryObj: BoundariesRecord = {};
        const step = Math.max(1, Math.floor(coords.length / 500));

        let ptIdx = 1;
        for (let i = 0; i < coords.length; i += step) {
          const coord = coords[i];
          boundaryObj[`point${ptIdx}`] = { lat: coord[1], lng: coord[0] };
          ptIdx++;
        }
        cache.set(cacheKey, boundaryObj);
        return boundaryObj;
      }
    }
    cache.set(cacheKey, null);
    return null;
  } catch (error) {
    console.error("Nominatim area fetch error:", error);
    return null;
  }
};
