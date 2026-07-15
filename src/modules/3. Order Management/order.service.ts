import { NextFunction, Request, Response } from "express";
import { OrderStatus, ProposalStatus } from "@prisma/client";
import { AppError } from "../../core/errors/app.error";
import { responseHandler } from "../../core/handlers/response.handler";
import { HttpStatusCode } from "../../core/http/http.status.code";
import { prisma } from "../../DB/lib/prisma";
import FeatureApi from "../../utils/featureApi";
import {
  connectedSockets,
  getSocketIOServer,
} from "../../utils/socketio/socketio.server";
import { notifyUser } from "../../utils/firebase-notification/notification.service";
import logger from "../../config/logger.config";
import { io } from "socket.io-client";
export class OrderService {
  constructor() {}

  private readonly SUPPLIER_ROLE_NAME = "Supplier";
  private readonly COURIER_ROLE_NAME = "Courier";
  private readonly MAX_COURIERS_TO_NOTIFY = 10;

  // ============================ appSettings ============================
  appSettings = async (req: Request, res: Response, next: NextFunction) => {
    const user = res.locals.user;

    // step: get app settings
    const appSettings = await prisma.applicationSetting.findFirst();
    if (!appSettings) {
      throw new AppError(
        HttpStatusCode.INTERNAL_SERVER_ERROR,
        "ApplicationSettigns record not found",
      );
    }
    return responseHandler({
      res,
      data: {
        ApplicationSettings: { ...appSettings },
      },
    });
  };

  // ============================ listOrders ============================
  listOrders = async (req: Request, res: Response, next: NextFunction) => {
    const user = res.locals.user;

    // step: get supplier
    const supplier = await prisma.supplier.findUnique({
      where: { user_id: user.id },
    });
    if (!supplier) {
      throw new AppError(
        HttpStatusCode.INTERNAL_SERVER_ERROR,
        "Supplier not found",
      );
    }

    // step: apply filters
    const queryOptions = new FeatureApi(req) // queryOptions :{where, orderBy, take, skip}
      .filter({ supplier_id: supplier.id })
      .sort("-created_at") // ?sort=-created_at
      .limit(10) // ?limit=10
      .skip(0) // ?skip=0
      .keyword(["order_number"]) // ?keyword=xxx
      .fields().data; // ?fields=id,...

    const [orders, totalOrders] = await prisma.$transaction([
      prisma.order.findMany({
        where: queryOptions.where,
        orderBy: queryOptions.orderBy,
        take: queryOptions.take,
        skip: queryOptions.skip,
        include: {
          customer: {
            select: {
              id: true,
              full_name: true,
              phone: true,
              personal_photo: true,
            },
          },
          orderItems: {
            include: {
              supplierProduct: {
                include: {
                  product: true,
                },
              },
            },
          },
        },
      } as any),
      prisma.order.count({
        ...(queryOptions.where ? { where: queryOptions.where } : {}),
      }),
    ]);

    return responseHandler({
      res,
      message: res.__("messages.available_orders_retrieved"),
      data: {
        totalOrders,
        totalPages: Math.ceil(totalOrders / (queryOptions.take ?? 10)),
        orders,
      },
    });
  };

  // ============================ orderDetails ============================
  orderDetails = async (req: Request, res: Response, next: NextFunction) => {
    const user = res.locals.user;
    const { orderId } = res.locals.validatedData as { orderId: number };

    // step: get supplier
    const supplier = await prisma.supplier.findUnique({
      where: { user_id: user.id },
    });
    if (!supplier) {
      throw new AppError(
        HttpStatusCode.INTERNAL_SERVER_ERROR,
        "Supplier not found",
      );
    }

    // step: get order with full details (ownership enforced via supplier_id)
    const order = await prisma.order.findUnique({
      where: { id: orderId },
      include: {
        pickup_area: {
          include: { governorate: true },
        },
        delivery_area: {
          include: { governorate: true },
        },
        customer: {
          select: {
            id: true,
            full_name: true,
            personal_photo: true,
            phone: true,
          },
        },
        courier: {
          select: {
            user_id: true,
            vehicle_id: true,
            courier_office_id: true,
            national_id_number: true,
            vehicle_plate: true,
          },
        },
        supplier: {
          select: {
            user_id: true,
            type_id: true,
            national_id_number: true,
          },
        },
        proposals: {
          where: { status: ProposalStatus.ACCEPTED },
        },
        _count: {
          select: { proposals: true },
        },
      },
    });

    if (!order) {
      throw new AppError(
        HttpStatusCode.NOT_FOUND,
        res.__("errors.order_not_found"),
      );
    }

    return responseHandler({
      res,
      message: res.__("messages.order_details_retrieved"),
      data: { order },
    });
  };

  // ============================ allCancellationReasons ============================
  allCancellationReasons = async (
    req: Request,
    res: Response,
    next: NextFunction,
  ) => {
    // step: get user role
    const userRole = await prisma.userRole.findFirst({
      where: { name: this.SUPPLIER_ROLE_NAME },
    });
    if (!userRole) {
      throw new AppError(
        HttpStatusCode.INTERNAL_SERVER_ERROR,
        res.__("errors.role_not_found"),
      );
    }

    const queryOptions = new FeatureApi(req) // queryOptions :{where, orderBy, take, skip}
      .filter({ role_id: userRole.id }) //{}{allowKeys:[]}
      .sort("-created_at") // ?sort=-created_at
      .limit(10) // ?limit=10
      .skip(0) // ?skip=0
      .includes() // ?includes=role=id-name,wallet,penalties
      .keyword(["reason_ar", "reason_en"]) // ?keyword=xxx&items=reason_ar,reason_en
      .fields().data; // ?fields=id,reason_ar,reason_en

    const [totalReasons, reasons] = await prisma.$transaction([
      prisma.cancellationReason.count({
        ...(queryOptions.where ? { where: queryOptions.where } : {}),
      }),
      prisma.cancellationReason.findMany(queryOptions as any),
    ]);

    return responseHandler({
      res,
      message: res.__("messages.all_reasons_retrieved"),
      data: {
        totalReasons,
        totalPages: Math.ceil(totalReasons / (queryOptions.take ?? 10)),
        reasons,
      },
    });
  };

  // ============================ cancellationReasonDetails ============================
  cancellationReasonDetails = async (
    req: Request,
    res: Response,
    next: NextFunction,
  ) => {
    const { reasonId } = res.locals.validatedData as { reasonId: number };

    const reason = await prisma.cancellationReason.findUnique({
      where: { id: reasonId },
    });
    if (!reason) {
      throw new AppError(
        HttpStatusCode.BAD_REQUEST,
        res.__("errors.reason_not_found"),
      );
    }

    return responseHandler({
      res,
      message: res.__("messages.reason_retrieved_successfully"),
      data: reason,
    });
  };

  // ============================ notifyOrderReady ============================
  notifyOrderReady = async (
    req: Request,
    res: Response,
    next: NextFunction,
  ) => {
    const user = res.locals.user;
    const { orderId } = res.locals.validatedData as { orderId: number };

    // step: get supplier
    const supplier = await prisma.supplier.findUnique({
      where: { user_id: user.id },
    });
    if (!supplier) {
      throw new AppError(
        HttpStatusCode.BAD_REQUEST,
        res.__("errors.supplier_not_found"),
      );
    }

    // step: get order
    const order = await prisma.order.findUnique({
      where: { id: orderId },
    });
    if (!order) {
      throw new AppError(
        HttpStatusCode.BAD_REQUEST,
        res.__("errors.order_not_found"),
      );
    }

    // step: get app settings
    const appSettings = await prisma.applicationSetting.findFirst();
    if (!appSettings) {
      throw new AppError(
        HttpStatusCode.BAD_REQUEST,
        res.__("errors.settings_not_found"),
      );
    }

    // step: check order_schedule_at not less than buffer time
    // Change this value to whatever number of minutes you want (e.g., 30, 45, 60, 120)
    const bufferMinutes = appSettings.order_scheduled_min_notice_minutes_from_supplier;
    if (order?.order_schedule_at) {
      const scheduleTime = new Date(order.order_schedule_at).getTime();
      const currentTime = Date.now();
      // Dynamically calculate the buffer in milliseconds (Minutes * Seconds * Milliseconds)
      const bufferInMs = bufferMinutes * 60 * 1000;
      if (scheduleTime - currentTime > bufferInMs) {
        throw new AppError(
          HttpStatusCode.BAD_REQUEST,
          res.__("errors.order_scheduled_too_early"), // Note: you might need to add this translation key!
        );
      }
    }

    // step: check is notified before
    // if (order.is_ready_for_pickup) {
    //   throw new AppError(
    //     HttpStatusCode.BAD_REQUEST,
    //     res.__("errors.order_already_ready"),
    //   );
    // }

    // step: check if order belongs to supplier
    if (order.supplier_id !== supplier.id) {
      throw new AppError(
        HttpStatusCode.BAD_REQUEST,
        res.__("errors.order_not_related_to_supplier"),
      );
    }

    // step: edit order status
    const updatedOrder = await prisma.order.update({
      where: { id: orderId },
      data: { is_ready_for_pickup: true, status: OrderStatus.PENDING },
    });

    // step: notify nearest (up to 10), online and available couriers
    // get online couriers from all sources (local socket, courier API socket, and recent db activity)
    const token = req.headers.authorization as string;
    const onlineUserIds = await this.getOnlineUserIds(token);

    console.log({ onlineUserIds });

    if (onlineUserIds.length > 0) {
      // get available couriers — approved, active, and not currently on another active order
      const couriersWithActiveOrders = await prisma.order.findMany({
        where: {
          status: OrderStatus.IN_PROGRESS,
          courier_id: { not: null },
        },
        select: { courier_id: true },
      });
      const busyCourierIds = new Set(
        couriersWithActiveOrders
          .map((o) => o.courier_id)
          .filter((id): id is number => id !== null),
      );

      const availableCouriers = await prisma.courier.findMany({
        where: {
          user_id: { in: onlineUserIds },
          is_approved: true,
          deleted_at: null,
          user: {
            is_active: true,
            role: { name: this.COURIER_ROLE_NAME },
          },
        },
        select: {
          id: true,
          user_id: true,
          lat: true,
          lng: true,
          user: {
            select: {
              id: true,
              lang: true,
              fcm_token: true,
            },
          },
        },
      });

      // exclude couriers who are busy with an active order
      const freeCouriers = availableCouriers.filter(
        (c) => !busyCourierIds.has(c.id),
      );

      // get nearest couriers — sort by Haversine distance to order pickup location
      const pickupLat = order.pickup_lat ? Number(order.pickup_lat) : null;
      const pickupLng = order.pickup_long ? Number(order.pickup_long) : null;

      type CourierWithDistance = (typeof freeCouriers)[number] & {
        distance: number;
      };

      let nearestCouriers: CourierWithDistance[];

      if (pickupLat !== null && pickupLng !== null) {
        // calculate distance for couriers that have a known location
        const couriersWithDistance: CourierWithDistance[] = freeCouriers
          .filter((c) => c.lat !== null && c.lng !== null)
          .map((c) => ({
            ...c,
            distance: this.haversineDistance(
              pickupLat,
              pickupLng,
              Number(c.lat),
              Number(c.lng),
            ),
          }));

        // sort ascending by distance and take up to MAX
        couriersWithDistance.sort((a, b) => a.distance - b.distance);
        nearestCouriers = couriersWithDistance.slice(
          0,
          this.MAX_COURIERS_TO_NOTIFY,
        );
      } else {
        // no pickup coordinates — fallback: take first MAX couriers (no distance sort)
        nearestCouriers = freeCouriers
          .slice(0, this.MAX_COURIERS_TO_NOTIFY)
          .map((c) => ({ ...c, distance: 0 }));
      }

      if (nearestCouriers.length > 0) {
        // send FCM push notifications (fire-and-forget)
        const usersToNotify = nearestCouriers.map((c) => c.user);

        // for (const user of usersToNotify) {
        //   try {
        //     await notifyUser({
        //       user,
        //       content: {
        //         title: {
        //           en: "Order Ready for Pickup",
        //           ar: "الطلب جاهز للاستلام",
        //         },
        //         body: {
        //           en: `Order #${order.order_number} is ready for pickup!`,
        //           ar: `الطلب #${order.order_number} جاهز للاستلام!`,
        //         },
        //       },
        //       data: {
        //         page: "/order-details",
        //         navigate: "order_details",
        //         orderId: String(order.id),
        //         orderNumber: order.order_number,
        //       },
        //     });
        //   } catch (err) {
        //     logger.error(
        //       `[notifyOrderReady] FCM notification error for user ${user.id}: ${err}`,
        //     );
        //   }
        // }

        // emit socket.io event to each courier (fire-and-forget)
        try {
          const ioServer = getSocketIOServer();

          for (const courier of nearestCouriers) {
            const socketIds = connectedSockets.get(courier.user_id);
            if (socketIds) {
              for (const socketId of socketIds) {
                ioServer.to(socketId).emit("order:new", {
                  orderId: order.id,
                  orderNumber: order.order_number,
                  pickupLat,
                  pickupLng,
                  distance: courier.distance,
                });
              }
            }
          }
        } catch (err) {
          logger.error(`[notifyOrderReady] socket.io emit error: ${err}`);
        }

        logger.info(
          `[notifyOrderReady] Notified ${nearestCouriers.length} courier(s) for order ${order.id}`,
        );
      }
    }

    return responseHandler({
      res,
      message: res.__("messages.order_ready_notification_sent"),
      data: { order: updatedOrder },
    });
  };

  // ============================ haversineDistance ============================
  /**
   * Calculates the great-circle distance between two coordinates in kilometres.
   */
  private haversineDistance(
    lat1: number,
    lon1: number,
    lat2: number,
    lon2: number,
  ): number {
    const R = 6371; // Earth radius in km
    const toRad = (deg: number) => (deg * Math.PI) / 180;

    const dLat = toRad(lat2 - lat1);
    const dLon = toRad(lon2 - lon1);

    const a =
      Math.sin(dLat / 2) ** 2 +
      Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLon / 2) ** 2;

    return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  }

  // ============================ getCourierSocketUserIds ============================
  private getCourierSocketUserIds(token?: string): Promise<number[]> {
    return new Promise((resolve) => {
      try {
        const socket = io("https://tawreedat.nitg-eg.com", {
          path: "/courier_apis/socket.io",
          transports: ["websocket", "polling"],
          auth: {
            accessToken: token,
          },
        });

        const timeoutId = setTimeout(() => {
          logger.warn(`[getCourierSocketUserIds] Request timeout`);
          socket.disconnect();
          resolve([]);
        }, 5000);

        socket.emit(
          "users:get_online_users",
          (response: { users?: number[] }) => {
            clearTimeout(timeoutId);
            socket.disconnect();
            try {
              const userIds =
                response?.users?.map(Number).filter((n) => !isNaN(n)) || [];
              resolve(userIds);
            } catch {
              resolve([]);
            }
          },
        );

        socket.on("connect_error", (err: any) => {
          logger.error(
            `[getCourierSocketUserIds] Connect error: ${err.message}`,
          );
          clearTimeout(timeoutId);
          socket.disconnect();
          resolve([]);
        });
      } catch (err) {
        logger.error(`[getCourierSocketUserIds] Error: ${err}`);
        resolve([]);
      }
    });
  }

  // ============================ getOnlineUserIds ============================
  private async getOnlineUserIds(token?: string): Promise<number[]> {
    // Source 1: couriers connected to courier backend socket
    const courierSocketUserIds = await this.getCourierSocketUserIds(token);
    // Source 2: couriers who updated location recently.
    const ONLINE_WINDOW_MS =
      courierSocketUserIds.length === 0
        ? 2 * 60 * 60 * 1000 // 2-hour fallback when sockets just reset
        : 60 * 60 * 1000; // 60-min normal window

    const recentlyActive = await prisma.courier.findMany({
      where: {
        last_location_update: { gte: new Date(Date.now() - ONLINE_WINDOW_MS) },
        deleted_at: null,
        is_approved: true,
      },
      select: { user_id: true },
    });
    const recentUserIds = recentlyActive.map((c) => c.user_id);

    const onlineUserIds = Array.from(
      new Set([...courierSocketUserIds, ...recentUserIds]),
    );

    logger.info(
      `[getOnlineUserIds] Found ${onlineUserIds.length} online couriers (courier socket: ${courierSocketUserIds.length}, recentDB: ${recentUserIds.length})`,
    );

    return onlineUserIds;
  }
}
