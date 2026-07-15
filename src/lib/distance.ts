// lib/distance.ts
import { HttpError } from "./httpError";
import env from "@/config/env";
export async function getRoadDistanceM(
  pickup: { lat: number; lng: number },
  delivery: { lat: number; lng: number },
): Promise<{
  distance: number;
  duration: number;
  provider: "osrm" | "google";
}> {
  // --- Step 1: Attempt OSRM (Default) ---
  try {
    const osrmUrl = `https://router.project-osrm.org/route/v1/driving/${pickup.lng},${pickup.lat};${delivery.lng},${delivery.lat}?overview=false`;
    const osrmRes = await fetch(osrmUrl);

    if (!osrmRes.ok) throw new Error("OSRM Down");

    const osrmData = await osrmRes.json();
    if (osrmData.code === "Ok" && osrmData.routes?.[0]) {
      return {
        distance: osrmData.routes[0].distance, // OSRM returns meters by default
        duration: osrmData.routes[0].duration, // OSRM returns seconds
        provider: "osrm",
      };
    }
  } catch (error) {
    console.warn("OSRM failed, falling back to Google Maps:", error);
  }

  // --- Step 2: Fallback to Google Maps ---
  const googleUrl = new URL(
    "https://maps.googleapis.com/maps/api/distancematrix/json",
  );
  googleUrl.searchParams.set("origins", `${pickup.lat},${pickup.lng}`);
  googleUrl.searchParams.set("destinations", `${delivery.lat},${delivery.lng}`);
  googleUrl.searchParams.set("key", env.GOOGLE_MAPS_API_KEY);

  const gRes = await fetch(googleUrl.toString());
  const gData = await gRes.json();
  const element = gData?.rows?.[0]?.elements?.[0];

  if (element?.status === "OK") {
    return {
      distance: element.distance.value,
      duration: element.duration.value,
      provider: "google",
    };
  }

  // --- Step 3: Global Failure ---
  throw new HttpError(
    400,
    "Distance calculation unavailable from all providers.",
  );
}

export async function compareDistanceServices(
  pickup: { lat: number; lng: number },
  delivery: { lat: number; lng: number },
) {
  // 1. Google Maps Logic
  const googleUrl = new URL(
    "https://maps.googleapis.com/maps/api/distancematrix/json",
  );
  googleUrl.searchParams.set("origins", `${pickup.lat},${pickup.lng}`);
  googleUrl.searchParams.set("destinations", `${delivery.lat},${delivery.lng}`);
  googleUrl.searchParams.set("key", env.GOOGLE_MAPS_API_KEY);

  const googleRes = await fetch(googleUrl.toString());
  const googleData = await googleRes.json();
  const gElement = googleData?.rows?.[0]?.elements?.[0];

  // 2. OSRM Logic (Note: OSRM uses [lng, lat])
  const osrmUrl = `https://router.project-osrm.org/route/v1/driving/${pickup.lng},${pickup.lat};${delivery.lng},${delivery.lat}?overview=false`;
  const osrmRes = await fetch(osrmUrl);
  const osrmData = await osrmRes.json();
  const oRoute = osrmData.routes?.[0];

  return {
    google:
      gElement?.status === "OK"
        ? {
            distanceMeters: gElement.distance.value,
            durationSeconds: gElement.duration.value,
            note: "Includes live traffic if specified",
          }
        : "Error or No Route",
    osrm: oRoute
      ? {
          distanceMeters: oRoute.distance,
          durationSeconds: oRoute.duration,
          note: "Static/Ideal conditions only",
        }
      : "Error or No Route",
  };
}
