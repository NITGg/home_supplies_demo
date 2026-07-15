import type { Response } from "express";
import type { AuthedRequest } from "@/types/authedRequest";
import { getRoadDistanceM } from "@/lib/distance";
import { DistanceRequestSchema } from "./distances.schema";

export async function calculateDistanceController(
  req: AuthedRequest,
  res: Response,
) {
  // 1. Validate input using Zod
  const data = DistanceRequestSchema.parse(req.sanitized.body);

  // 2. Call the service (OSRM with Google Fallback)
  const result = await getRoadDistanceM(data.pickup, data.delivery);

  // 3. Return localized response
  return res.status(200).json({
    message:
      req.t?.("shipping:messages.distance_calculated") ?? "Distance calculated",
    data: result,
  });
}
