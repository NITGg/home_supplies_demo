import { getIo } from "@/socket";
import { rooms } from "@/socket/rooms";
import type { AppEvents } from "@/types/events";
import { prisma } from "@/config/prisma";
import { notifyUser } from "@/services/notification.service";

type OnOfferAcceptedPayload = AppEvents["offer.accepted"];

export async function onOfferAccepted(e: OnOfferAcceptedPayload) {
  const courierRoom = rooms.courier(e.courierId);
  const areaRoom = rooms.area(e.pickupAreaId);

  getIo().to(areaRoom).emit("order:taken", { orderId: e.orderId });

  getIo().to(courierRoom).emit("offer:accepted", {
    orderId: e.orderId,
    offerId: e.offerId,
  });

  // ── Tracking: notify customer that courier is now active on their order ──
  getIo().to(rooms.customer(e.customerId)).emit("order:tracking_started", {
    orderId: e.orderId,
    courierId: e.courierId,
  });

  const courier = await prisma.user.findFirst({
    where: {
      courier: {
        id: e.courierId,
      },
    },
    select: {
      id: true,
      lang: true,
      fcm_token: true,
    },
  });

  if (!courier) return;
  console.log(courier);

  const result = await notifyUser({
    user: courier,
    content: {
      title: {
        en: "Offer accepted",
        ar: "تم قبول العرض",
      },
      body: {
        en: `Your offer for order #${e.orderId} has been accepted.`,
        ar: `تم قبول عرضك للطلب رقم #${e.orderId}.`,
      },
    },
    data: {
      page: `/orders/${e.orderId}`,
      navigate: "order_details",
      orderId: e.orderId,
      offerId: e.offerId,
      type: "OFFER_ACCEPTED",
    },
  });
  console.log(result);
}

type OnOfferRejectedPayload = AppEvents["offer.rejected"];

export async function onOfferRejected(e: OnOfferRejectedPayload) {
  getIo().to(rooms.courier(e.courierId)).emit("offer:rejected", {
    orderId: e.orderId,
    offerId: e.offerId,
  });

  const courier = await prisma.user.findFirst({
    where: {
      courier: {
        id: e.courierId,
      },
    },
    select: {
      id: true,
      lang: true,
      fcm_token: true,
    },
  });

  if (!courier) return;

  await notifyUser({
    user: courier,
    content: {
      title: {
        en: "Offer rejected",
        ar: "تم رفض العرض",
      },
      body: {
        en: `Your offer for order #${e.orderId} was rejected.`,
        ar: `تم رفض عرضك للطلب رقم #${e.orderId}.`,
      },
    },
    data: {
      page: `/orders/${e.orderId}`,
      navigate: "order_details",
      orderId: e.orderId,
      offerId: e.offerId,
      type: "OFFER_REJECTED",
    },
  });
}
