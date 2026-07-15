import { Router } from "express";
import { requireAuth, requireRole } from "@/middlewares/auth";
import { asyncHandler } from "@/middlewares/asyncHandler";
import {
  sendNotificationController,
  sendNotificationStreamController,
} from "./notifications.controller";

const notificationsRouter = Router();

/**
 * POST /api/v1/admin/notifications/send
 * body:
 * {
 *   "recipientType": "all" | "users" | "role",
 *   "userIds"?: [1,2,3],
 *   "roles"?: ["admin" | "customer" | "courier"],
 *    "content": {
 *      "title": {
 *         "en": "New offer",
 *         "ar": "عرض جديد",
 *       },
 *      "body": {
 *         "en": "You received a new discount",
 *         "ar": "لقد حصلت على خصم جديد",
 *      },
 *     }
 *   "data"?: {
 *     "route": "/orders/12",
 *     "navigate": "order_details",
 *     "orderId": 12
 *   }
 * }
 */
notificationsRouter.use(requireAuth);
notificationsRouter.use(requireRole("Admin", "CustomerSupport"));

notificationsRouter.post("/send", asyncHandler(sendNotificationController));
notificationsRouter.post(
  "/send/stream",
  requireAuth,
  asyncHandler(sendNotificationStreamController),
);

export default notificationsRouter;
