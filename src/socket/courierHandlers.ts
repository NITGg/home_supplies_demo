import { Server, Socket } from "socket.io";
import { rooms } from "./rooms";
import { updateCourierLocation } from "@/modules/users/services/users.service";
import { prisma } from "@/config/prisma";
import { z } from "zod";

// ── Schemas ───────────────────────────────────────────────────────────────────

const courierLocationSchema = z.object({
  lat: z
    .number({ error: "courier:errors.lat_required" })
    .min(-90, "courier:errors.invalid_lat")
    .max(90, "courier:errors.invalid_lat"),
  lng: z
    .number({ error: "courier:errors.lng_required" })
    .min(-180, "courier:errors.invalid_lng")
    .max(180, "courier:errors.invalid_lng"),
});

const locationUpdateSchema = courierLocationSchema.extend({
  orderId: z
    .number({ error: "courier:errors.order_id_required" })
    .int()
    .positive(),
});

// ── Helpers ───────────────────────────────────────────────────────────────────
type TrackableOrder = {
  id: number;
  customer_id: number; // Guaranteed to be a number, no more '!'
};
/**
 * Fetch the active order for this courier and validate it is trackable.
 * Returns the order (with customer_id) or null if validation fails.
 */
async function getTrackableOrder(
  courierId: number,
  orderId: number,
): Promise<TrackableOrder | null> {
  const order = await prisma.order.findFirst({
    where: {
      id: orderId,
      courier_id: courierId,
      status: "IN_PROGRESS",
      customer_id: { not: null }, // Prisma ensures this is not null if found
    },
    select: {
      id: true,
      customer_id: true, // Prisma infers this as number | null
    },
  });

  // Explicit type guard
  if (order && order.customer_id !== null) {
    return order as TrackableOrder;
  }
  return null;
}
// ── Handler registration ──────────────────────────────────────────────────────

export function registerCourierHandlers(io: Server, socket: Socket) {
  // ── courier:location_update ───────────────────────────────────────────────
  // Courier frontend pushes its GPS position on a regular interval.
  // Backend validates the order, persists the location, then fans out
  // to the admin dashboard and the specific customer tracking the order.
  socket.on("courier:location_update", async (data, callback) => {
    try {
      const courierId = socket.data.auth?.courierId;
      if (!courierId) {
        return callback?.({
          success: false,
          error: "courier:errors.not_authorized",
        });
      }

      // Validate payload
      const parsed = locationUpdateSchema.safeParse(data);
      if (!parsed.success) {
        return callback?.({
          success: false,
          error: parsed.error.issues[0]?.message ?? "validation_error",
        });
      }

      const { orderId, lat, lng } = parsed.data;

      // Validate order belongs to this courier and is IN_PROGRESS
      const order = await getTrackableOrder(courierId, orderId);
      if (!order) {
        return callback?.({
          success: false,
          error: "courier:errors.no_active_order",
        });
      }

      // Persist to DB (updates courier.lat, courier.lng, courier.last_location_update)
      await updateCourierLocation(courierId, lat, lng);

      const timestamp = new Date().toISOString();

      // Fan-out → admin dashboard
      io.to(rooms.dashboard()).emit("courier:location_updated", {
        courierId,
        orderId,
        lat,
        lng,
        timestamp,
      });

      console.log("customer receive:", {
        orderId,
        courierId,
        lat,
        lng,
        timestamp,
      });

      // Fan-out → customer tracking this order
      io.to(rooms.customer(order.customer_id)).emit("order:courier_location", {
        orderId,
        courierId,
        lat,
        lng,
        timestamp,
      });

      return callback?.({ success: true });
    } catch (err: any) {
      console.error("courier:location_update error:", err);
      return callback?.({
        success: false,
        error: err.message ?? "internal_error",
      });
    }
  });

  // ── courier:location_response ─────────────────────────────────────────────
  // Response to an admin-initiated ping (courier:get_location).
  // No order context here — admin just wants a one-off position snapshot.
  socket.on("courier:location_response", async (data, callback) => {
    try {
      console.log("courier:location_response to update lat & lng");
      
      const courierId = socket.data.auth?.courierId;
      if (!courierId) {
        return callback?.({
          success: false,
          error: "courier:errors.not_authorized",
        });
      }

      // ✅ Zod validation
      const { lat, lng } = courierLocationSchema.parse(data);

      // ✅ Update DB
      await updateCourierLocation(courierId, lat, lng);
      console.log({
        courierId,
        lat,
        lng,
      });

      // ✅ Emit to dashboard
      io.to(rooms.dashboard()).emit("courier:location_updated", {
        courierId,
        lat,
        lng,
        timestamp: new Date().toISOString(),
      });

      return callback?.({ success: true });
    } catch (err: any) {
      console.error("courier:location_response error:", err);

      if (err.name === "ZodError") {
        return callback?.({
          success: false,
          error: err.errors?.[0]?.message ?? "validation_error",
        });
      }

      return callback?.({
        success: false,
        error: err.message ?? "internal_error",
      });
    }
  });
}
