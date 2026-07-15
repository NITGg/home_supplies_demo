import { prisma } from "@/config/prisma";
import { getIo } from "@/socket";
import { rooms } from "@/socket/rooms";
import { isUserOnline } from "@/socket/status";
import type { AppEvents } from "@/types/events";
import { notifySupplierOrder } from "./notifySupplier";

type Payload = AppEvents["order.created"];

export async function onOrderCreated(e: Payload) {
  const { vehicleIds, distanceM, targetCourierId, ...courierPayload } = e;

  // ── Supplier notification (CATALOG_PURCHASE only) ────────────────────────
  if (e.type === "CATALOG_PURCHASE" && e.supplierId) {
    await notifySupplierOrder(e.supplierId, e.orderId, "NEW_ORDER");
  }

  // ── Courier dispatch ─────────────────────────────────────────────────────
  if (targetCourierId) {
    await notifyTargetCourier(targetCourierId, courierPayload);
    return;
  }

  // TODO: ── Check is order scheduled or order delivery date and times ─────────────────────────────────────────
  if (e.isScheduled || e.is_order_scheduled == false) {
    return;
  }

  // ── Broadcast to all online couriers ─────────────────────────────────────────
  await broadcastToCouriers(e, courierPayload);
}

// ─── Couriers ────────────────────────────────────────────────────────────────

async function notifyTargetCourier(
  targetCourierId: number,
  payload: Omit<Payload, "vehicleIds" | "distanceM" | "targetCourierId">,
) {
  const courier = await prisma.courier.findUnique({
    where: { id: targetCourierId },
    select: {
      id: true,
      user_id: true,
      courier_criminal_record: true,
      created_at: true,
    },
  });

  if (
    courier &&
    isUserOnline(courier.user_id) &&
    (await canCourierReceiveOrders(courier))
  ) {
    getIo().to(rooms.courier(courier.id)).emit("order:new", payload);
  }
}

// ─── Eligibility ────────────────────────────────────────────────────────────

const MS_PER_DAY = 24 * 60 * 60 * 1000;

/**
 * Mirrors the courier app's `requireCriminalRecord` middleware: a courier who
 * hasn't submitted their criminal record can only receive orders within the
 * configured grace period (from their `created_at`).
 */
async function canCourierReceiveOrders(courier: {
  courier_criminal_record: string | null;
  created_at: Date;
}): Promise<boolean> {
  if (courier.courier_criminal_record) return true;

  const settings = await prisma.applicationSetting.findFirst({
    select: { courier_criminal_record_grace_period_days: true },
  });
  const gracePeriodDays =
    settings?.courier_criminal_record_grace_period_days ?? 30;

  const ageInDays =
    (Date.now() - new Date(courier.created_at).getTime()) / MS_PER_DAY;

  return ageInDays <= gracePeriodDays;
}

import { Prisma } from "@prisma/client";
import { getOnlineCouriersService } from "@/modules/users/services/users.service";

const NOTIFY_TOP_N = 10; // tune as needed

export async function broadcastToCouriers(
  e: Payload,
  payload: Omit<Payload, "vehicleIds" | "distanceM" | "targetCourierId">,
) {
  const onlineUserIds = await getOnlineCouriersService();
  if (onlineUserIds.total === 0) return;
  console.log("onlineUserIds:", onlineUserIds);

  const settings = await prisma.applicationSetting.findFirst({
    select: { courier_criminal_record_grace_period_days: true },
  });
  const gracePeriodDays =
    settings?.courier_criminal_record_grace_period_days ?? 30;

  // Pull matched couriers ordered by straight-line distance from pickup point.
  // We skip Google here — ST_Distance_Sphere is fast, good enough for ranking,
  // and we already paid for the real distance in the order creation flow.
  const matchedCouriers = await prisma.$queryRaw<
    { id: number; user_id: number }[]
  >(
    Prisma.sql`
    SELECT *
    FROM (
      SELECT
        c.id,
        c.user_id,

        -- ✅ compute ONCE
        ST_Distance_Sphere(
          POINT(c.lng, c.lat),
          POINT(${e.pickupLng}, ${e.pickupLat})
        ) AS distance_m,

        v.min_distance_per_km,
        v.max_distance_per_km

      FROM courier c
      JOIN vehicle v ON v.id = c.vehicle_id

      WHERE
        c.user_id IN (${Prisma.join(
          onlineUserIds.couriers.map((u) => u.user_id),
        )})
        AND c.deleted_at IS NULL
        AND c.is_approved = true
        AND c.lat IS NOT NULL
        AND c.lng IS NOT NULL

        -- Criminal record requirement (mirrors requireCriminalRecord middleware):
        -- couriers without one are only eligible within the grace period.
        AND (
          c.courier_criminal_record IS NOT NULL
          OR c.created_at > DATE_SUB(NOW(), INTERVAL ${gracePeriodDays} DAY)
        )

        -- Area filter
        AND EXISTS (
          SELECT 1 FROM courier_selected_area csa
          WHERE csa.courier_id = c.id
            AND csa.area_id = ${e.pickupAreaId}
            AND csa.deleted_at IS NULL
        )
    ) AS sub

    WHERE
      -- ✅ order distance constraint
      (sub.min_distance_per_km IS NULL OR sub.min_distance_per_km <= ${e.distanceM})
      AND (sub.max_distance_per_km IS NULL OR sub.max_distance_per_km >= ${e.distanceM})

      -- ✅ courier reach radius (uses computed distance)
      AND (
        sub.max_distance_per_km IS NULL
        OR sub.distance_m <= sub.max_distance_per_km
      )

    ORDER BY sub.distance_m ASC
    LIMIT ${NOTIFY_TOP_N}
  `,
  );

  console.log("matchedCouriers:", matchedCouriers);

  for (const courier of matchedCouriers) {
    getIo().to(rooms.courier(courier.id)).emit("order:new", payload);
  }
}
