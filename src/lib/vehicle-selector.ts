import { prisma } from "@/config/prisma";
import { HttpError } from "./httpError";

export async function selectVehiclesForDistance(
  distanceM: number,
) {
  const vehicles = await prisma.vehicle.findMany({
    where: {
      AND: [
        {
          OR: [
            { min_distance_per_km: null },
            { min_distance_per_km: { lte: distanceM } },
          ],
        },
        {
          OR: [
            { max_distance_per_km: null },
            { max_distance_per_km: { gte: distanceM } },
          ],
        },
      ],
    },
    orderBy: { min_delivery_fee: "asc" },
  });

  if (vehicles.length === 0) {
    throw new HttpError(
      400,
      "orders:errors.no_vehicle_for_distance",
      undefined,
      { distanceM },
    );
  }

  return vehicles; // all matches, not just first
}
