import { NextFunction, Request, Response } from "express";
import { OrderStatus, Prisma, ProposalStatus } from "@prisma/client";
import {
  SubmitOfferDTO,
  ReportUnavailableOrderDTO,
  CancelOtherDTO,
  ReportOrderHighPriceDTO,
  CompleteDeliveryDTO,
  HistoryQueryDTO,
  AcceptFixedFeeOfferDTO,
  UpdateLocationDTO,
  RejectAssignedOrderDTO,
  AcceptAssignedOrderDTO,
} from "./order.dto";
import { AppError } from "../../core/errors/app.error";
import { responseHandler } from "../../core/handlers/response.handler";
import { HttpStatusCode } from "../../core/http/http.status.code";
import { i18n } from "../../bootstrap";
import { notifyUser } from "../../utils/firebase-notification/notification.service";
import { prisma } from "../../DB/lib/prisma";
import * as QRCode from "qrcode";
import { OrderSocketioService } from "../../utils/socketio/order.socketio.service";
import { applyFilters, buildPaginationResponse } from "../../utils/filter";
import logger from "../../config/logger.config";
import FeatureApi from "../../utils/featureApi";
import {
  confirmDeliveryAdminApi,
  formatOrderItem,
  handleOrderReversal,
  orderItemInclude,
  refundCustomerWallet,
  restoreStockIfCatalog,
  updateCourierLocation,
} from "../../utils/order.helpers";
import {
  sendWebhookEvent,
  WebhookFixedFeeAcceptedPayload,
  WebhookFixedFeeRejectedPayload,
  WebhookOfferSubmittedPayload,
  WebhookOrderCancelledPayload,
  WebhookOrderCollectedPayload,
  WebhookOrderPriceReportedPayload,
} from "../../queues/webhook";
import { deleteOrderChatOnCompletion } from "../11. Chat/chat.service";

export class OrderService {
  constructor() {}

  // ============================ assertFinesWithinLimit (helper) ============================
  // step: claude: shared guard for submitOffer / acceptFixedFeeOffer — block couriers
  // whose combined unpaid penalties + unpaid commissions exceed their vehicle's
  // `total_fines` threshold from submitting/accepting new offers until they settle up.
  readonly assertFinesWithinLimit = async (
    res: Response,
    courier: { id: number; user_id: number; vehicle_id: number | null },
    vehicleId?: number | null,
  ) => {
    const [unpaidCommissions, unpaidPenalties, vehicle] = await Promise.all([
      prisma.unpaidCommission.findMany({
        where: { user_id: courier.user_id, is_paid: false },
      }),
      prisma.penalty.findMany({
        where: { user_id: courier.user_id, is_paid: false, is_waived: false },
      }),
      prisma.vehicle.findUnique({
        where: { id: vehicleId ?? courier.vehicle_id ?? -1 },
        select: { total_fines: true },
      }),
    ]);

    if (!vehicle) return; // no vehicle resolved — nothing to compare against

    const totalUnpaidCommissionAmount = unpaidCommissions.reduce(
      (sum, item) => sum + Number(item.amount),
      0,
    );
    const totalPenalties = unpaidPenalties.reduce(
      (sum, item) => sum + Number(item.amount),
      0,
    );
    const total = totalUnpaidCommissionAmount + totalPenalties;
    console.log("total", total);
    console.log("vehicle.total_fines", vehicle.total_fines);

    if (total > Number(vehicle.total_fines)) {
      throw new AppError(
        HttpStatusCode.BAD_REQUEST,
        res.__("errors.outstanding_fines_limit_exceeded"),
      );
    }
  };

  // ============================ availableOrders ============================
  availableOrders = async (req: Request, res: Response, next: NextFunction) => {
    const user = res.locals.user;

    const { filters, pagination, paginationMeta } = applyFilters(
      res.locals.validatedData,
      {
        price: "range",
        created_at: "dateRange",
        lat: "exact",
        lng: "exact",
      },
    );

    // step: get courier data with selected areas
    const courier = await prisma.courier.findUnique({
      where: { user_id: user.id },
      select: {
        id: true,
        lat: true,
        lng: true,
        vehicle_id: true,
        min_order_price: true,
        max_order_price: true,
        selectedAreas: { select: { area_id: true } },
        vehicle: {
          select: {
            min_distance_per_km: true,
            max_distance_per_km: true,
          },
        },
      },
    });
    if (!courier) {
      throw new AppError(
        HttpStatusCode.FORBIDDEN,
        res.__("errors.not_courier"),
      );
    }
    if (!courier.vehicle_id) {
      throw new AppError(
        HttpStatusCode.FORBIDDEN,
        res.__("errors.courier_no_vehicle"),
      );
    }
    const courierLat = filters.lat ?? courier?.lat;
    const courierLng = filters.lng ?? courier?.lng;

    // step: apply price filter to budget or actual_price (treat null as 0)
    let priceFilterForRawSQL = null;
    if (filters.price) {
      priceFilterForRawSQL = filters.price;
      delete filters.price;
      // Handle price filtering for all queries
      filters.OR = [
        // Budget within range (not null)
        { AND: [{ budget: priceFilterForRawSQL }, { budget: { not: null } }] },
        // Actual price within range (not null)
        {
          AND: [
            { actual_price: priceFilterForRawSQL },
            { actual_price: { not: null } },
          ],
        },
        // Always show orders with supplier_id == null and budget == 1
        // (Frontend add 1 cent to budget to mark this order as paid from customer and courier will not pay anything)
        { AND: [{ supplier_id: null }, { budget: 1 }] },
      ];
    }

    const areaIds = courier.selectedAreas.map((a) => a.area_id);

    filters.status = OrderStatus.PENDING;
    filters.courier_id = null;
    filters.pickup_area_id = { in: areaIds };
    filters.distance_m = {
      ...(courier.vehicle?.min_distance_per_km != null && {
        gte: courier.vehicle.min_distance_per_km,
      }),
      ...(courier.vehicle?.max_distance_per_km != null && {
        lte: courier.vehicle.max_distance_per_km,
      }),
    };

    filters.AND = [
      ...(filters.AND || []),
      {
        OR: [
          {
            is_scheduled: false,
            is_ready_for_pickup: false,
          },
          {
            is_scheduled: true,
            is_ready_for_pickup: true,
          },
          {
            is_order_scheduled: true,
            is_ready_for_pickup: true,
          },
        ],
      },
    ];

    // ── If courier has a known location, update location and use standard Prisma query ────────
    if (courierLat != null && courierLng != null) {
      if (filters.lat != null && filters.lng != null) {
        await prisma.courier.update({
          where: { id: courier.id },
          data: {
            lat: filters.lat,
            lng: filters.lng,
            last_location_update: new Date(),
          },
        });
      }
    }

    // ── Fallback: courier has no location — original Prisma path ─────────────
    const [orders, total] = await Promise.all([
      prisma.order.findMany({
        where: filters,
        include: {
          pickup_area: true,
          delivery_area: true,
          customer: {
            select: { id: true, full_name: true, personal_photo: true },
          },
          orderItems: { include: orderItemInclude },
          coupon: { select: { scope: true } },
          _count: { select: { proposals: true } },
        },
        orderBy: { created_at: "desc" },
        ...pagination,
      }),
      prisma.order.count({ where: filters }),
    ]);

    const relatedProposals = await prisma.orderProposal.findMany({
      where: {
        courier_id: courier.id,
        order_id: { in: orders.map((o) => o.id) },
      },
    });

    const ordersWithHistory = orders.map((order) => {
      const { orderItems, coupon, ...orderFields } = order;
      return {
        ...orderFields,
        coupon_type: coupon?.scope ?? null,
        orderItems: orderItems.map(formatOrderItem),
        proposalHistory: relatedProposals.filter(
          (p) => p.order_id === order.id,
        ),
      };
    });

    // step: claude: compute the courier's current allowed price range for a new
    // order so the frontend can disable orders outside of it. The minimum is a
    // fixed per-order floor; only the maximum (remaining headroom) shrinks by
    // the value of the courier's current in-progress orders.
    const courierCurrentOrders = await prisma.order.findMany({
      where: {
        courier_id: courier.id,
        status: OrderStatus.IN_PROGRESS,
      },
      select: { budget: true, products_total: true },
    });

    const currentOrdersValue = courierCurrentOrders.reduce(
      (sum, o) => sum + Number(o.budget ?? o.products_total ?? 0),
      0,
    ); // total order value the courier is currently carrying

    const minOrderPrice = courier.min_order_price
      ? Number(courier.min_order_price)
      : null;
    const maxOrderPrice = courier.max_order_price
      ? Number(courier.max_order_price)
      : null;

    const priceRange = {
      min_order_price: minOrderPrice,
      max_order_price: maxOrderPrice,
      current_orders_value: currentOrdersValue,
      // allowed value range for a new order given current in-progress orders:
      // the floor stays at min_order_price; the ceiling is the remaining headroom
      allowed_min_order_price: minOrderPrice,
      allowed_max_order_price:
        maxOrderPrice !== null
          ? Math.max(maxOrderPrice - currentOrdersValue, 0)
          : null,
    };

    return responseHandler({
      res,
      message: res.__("messages.available_orders_retrieved"),
      data: {
        orders: ordersWithHistory,
        priceRange,
        pagination: buildPaginationResponse(paginationMeta, total),
      },
    });
  };

  // ============================ orderDetails ============================
  orderDetails = async (req: Request, res: Response, next: NextFunction) => {
    const user = res.locals.user;
    const orderId = parseInt(req.params.id as string);

    // step: validate orderId
    if (isNaN(orderId)) {
      throw new AppError(
        HttpStatusCode.BAD_REQUEST,
        res.__("errors.invalid_order_id"),
      );
    }

    // step: get courier
    const courier = await prisma.courier.findUnique({
      where: { user_id: user.id },
    });

    if (!courier) {
      throw new AppError(
        HttpStatusCode.FORBIDDEN,
        res.__("errors.not_courier"),
      );
    }

    // step: get order with full details
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
        proposals: {
          where: { courier_id: courier.id },
        },
        orderItems: { include: orderItemInclude },
        coupon: {
          select: {
            scope: true,
          },
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

    const { orderItems, coupon, ...orderFields } = order;

    return responseHandler({
      res,
      message: res.__("messages.order_details_retrieved"),
      data: {
        order: {
          ...orderFields,
          coupon_type: coupon?.scope || null,
          orderItems: orderItems.map(formatOrderItem),
        },
      },
    });
  };

  // ============================ submitOffer ============================
  submitOffer = async (req: Request, res: Response, next: NextFunction) => {
    const user = res.locals.user;
    const orderId = parseInt(req.params.orderId as string);
    const {
      total_fee,
      courier_lat,
      courier_long,
      courier_location_address,
      distance_to_pickup,
      estimated_arrival_at_pickup,
      vehicle_id,
    }: SubmitOfferDTO = req.body;

    // step: get app settings
    const appSettings = await prisma.applicationSetting.findFirst();
    if (!appSettings) {
      throw new AppError(
        HttpStatusCode.INTERNAL_SERVER_ERROR,
        "ApplicationSettigns record not found",
      );
    }

    // step: validate orderId
    if (isNaN(orderId)) {
      throw new AppError(
        HttpStatusCode.BAD_REQUEST,
        res.__("errors.invalid_order_id"),
      );
    }

    // step: get courier
    const courier = await prisma.courier.findUnique({
      where: { user_id: user.id },
    });

    if (!courier) {
      throw new AppError(
        HttpStatusCode.FORBIDDEN,
        res.__("errors.not_courier"),
      );
    }

    // step: claude: block submitting offers when unpaid penalties + unpaid
    // commissions exceed the courier's vehicle `total_fines` threshold
    await this.assertFinesWithinLimit(res, courier, vehicle_id);

    // step: get order
    const order = await prisma.order.findUnique({
      where: { id: orderId },
      include: {
        externalApp: true,
      },
    });
    if (!order) {
      throw new AppError(
        HttpStatusCode.NOT_FOUND,
        res.__("errors.order_not_found"),
      );
    }

    // step: check order is pending
    if (order.status !== OrderStatus.PENDING) {
      throw new AppError(
        HttpStatusCode.BAD_REQUEST,
        res.__("errors.order_not_available"),
      );
    }

    // step: check fee is within limits
    // if (appSettings?.min_delivery_fee) {
    //   const est_fee = Number(order.estemated_delivery_fee || 0);
    //   const ratio = Number(appSettings.delivery_fee_ratio || 0);
    //   if (
    //     total_fee > Number(appSettings.min_delivery_fee) ||
    //     total_fee < est_fee * ratio + est_fee
    //   ) {
    //     throw new AppError(
    //       HttpStatusCode.BAD_REQUEST,
    //       res.__("errors.fee_out_of_range"),
    //     );
    //   }
    // }

    // step: check courier hasn't already submitted an offer
    // const existingProposal = await prisma.orderProposal.findFirst({
    //   where: {
    //     order_id: orderId,
    //     courier_id: courier.id,
    //     status: { in: [ProposalStatus.PENDING, ProposalStatus.ACCEPTED] },
    //   },
    // });
    // if (existingProposal) {
    //   throw new AppError(
    //     HttpStatusCode.BAD_REQUEST,
    //     res.__("errors.already_submitted_offer"),
    //   );
    // }

    // step: check courier has not reached to max_orders_per_trip
    const activeOrders = await prisma.order.findMany({
      where: {
        courier_id: courier.id,
        status: OrderStatus.IN_PROGRESS,
      },
    });
    if (activeOrders.length >= appSettings.max_orders_per_trip) {
      throw new AppError(
        HttpStatusCode.BAD_REQUEST,
        res.__("errors.max_orders_per_trip_reached"),
      );
    }

    // step: claude: check that this order's value plus the value of the
    // courier's other pending offers stays within the courier's configured
    // min/max order price range
    const orderValue = Number(order.budget ?? order.products_total ?? 0);

    const pendingProposals = await prisma.orderProposal.findMany({
      where: {
        courier_id: courier.id,
        status: ProposalStatus.PENDING,
        order_id: { not: orderId },
      },
      include: {
        order: { select: { budget: true, products_total: true } },
      },
    });

    const otherOffersValue = pendingProposals.reduce(
      (sum, p) => sum + Number(p.order.budget ?? p.order.products_total ?? 0),
      0,
    );

    const cumulativeOffersValue = orderValue + otherOffersValue;

    const minOrderPrice = courier.min_order_price
      ? Number(courier.min_order_price)
      : null;
    const maxOrderPrice = courier.max_order_price
      ? Number(courier.max_order_price)
      : null;

    if (minOrderPrice !== null && cumulativeOffersValue < minOrderPrice) {
      throw new AppError(
        HttpStatusCode.BAD_REQUEST,
        res.__(
          "errors.offers_total_below_min_price",
          cumulativeOffersValue.toString(),
          minOrderPrice.toString(),
          maxOrderPrice?.toString() ?? "-",
        ),
      );
    }

    if (maxOrderPrice !== null && cumulativeOffersValue > maxOrderPrice) {
      throw new AppError(
        HttpStatusCode.BAD_REQUEST,
        res.__(
          "errors.offers_total_above_max_price",
          cumulativeOffersValue.toString(),
          minOrderPrice?.toString() ?? "-",
          maxOrderPrice.toString(),
        ),
      );
    }

    // step: create proposal
    const proposal = await prisma.orderProposal.create({
      data: {
        order_id: orderId,
        courier_id: courier.id,
        total_fee: total_fee,
        status: ProposalStatus.PENDING,
        courier_lat: courier_lat ?? null,
        courier_long: courier_long ?? null,
        courier_location_address: courier_location_address ?? null,
        distance_to_pickup: distance_to_pickup ?? null,
        estimated_arrival_at_pickup: estimated_arrival_at_pickup ?? null,
        vehicle_id: vehicle_id ?? null,
      },
    });

    if (order?.externalApp?.webhook_url && order?.externalApp?.webhook_secret) {
      await sendWebhookEvent<WebhookOfferSubmittedPayload>(
        order.external_app_id!,
        {
          webhookUrl: order.externalApp.webhook_url,
          webhookSecret: order.externalApp.webhook_secret,
          eventType: "ORDER_OFFER_SUBMITTED", // Ensure this exists in your Prisma Enum
          payload: {
            id: proposal.id,
            proposal_id: proposal.order_id,
            courier_id: proposal.courier_id!,
            total_fee: Number(proposal.total_fee),
            courier_lat: proposal.courier_lat
              ? Number(proposal.courier_lat)
              : null,
            courier_long: proposal.courier_long
              ? Number(proposal.courier_long)
              : null,
            distance_to_pickup: proposal.distance_to_pickup
              ? Number(proposal.distance_to_pickup)
              : null,
            estimated_arrival_at_pickup: proposal.estimated_arrival_at_pickup,
            status: proposal.status,
            created_at: new Date().toISOString(),
          },
        },
      );
    }
    // --- NEW WEBHOOK LOGIC END ---

    // step: emit socket events to customer app
    OrderSocketioService.emitOfferNew(orderId);

    logger.info(
      { courierId: courier.id, orderId, totalFee: total_fee },
      "[Order] Offer submitted",
    );

    return responseHandler({
      res,
      message: res.__("messages.offer_submitted"),
      data: { proposal },
    });
  };

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

  // ============================ activeOrder ============================
  activeOrder = async (req: Request, res: Response, next: NextFunction) => {
    const user = res.locals.user;

    // step: get courier
    const courier = await prisma.courier.findUnique({
      where: { user_id: user.id },
    });

    if (!courier) {
      throw new AppError(
        HttpStatusCode.FORBIDDEN,
        res.__("errors.not_courier"),
      );
    }

    // step: get active orders (IN_PROGRESS status)
    const activeOrder = await prisma.order.findMany({
      where: {
        courier_id: courier.id,
        status: OrderStatus.IN_PROGRESS,
      },
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
        orderItems: { include: orderItemInclude },
        coupon: {
          select: {
            scope: true,
          },
        },
      },
    });

    const formattedOrders = activeOrder.map((order) => {
      const { orderItems, coupon, ...orderFields } = order;
      return {
        ...orderFields,
        coupon_type: coupon?.scope || null,
        orderItems: orderItems.map(formatOrderItem),
      };
    });

    return responseHandler({
      res,
      message:
        formattedOrders.length > 0
          ? res.__("messages.active_order_retrieved")
          : res.__("messages.no_active_order"),
      data: { order: formattedOrders },
    });
  };

  // ============================ orderCollected ============================
  orderCollected = async (req: Request, res: Response, next: NextFunction) => {
    const user = res.locals.user;
    const orderId = parseInt(req.params.orderId as string);

    // step: validate orderId
    if (isNaN(orderId)) {
      throw new AppError(
        HttpStatusCode.BAD_REQUEST,
        res.__("errors.invalid_order_id"),
      );
    }

    // step: get courier
    const courier = await prisma.courier.findUnique({
      where: { user_id: user.id },
    });

    if (!courier) {
      throw new AppError(
        HttpStatusCode.FORBIDDEN,
        res.__("errors.not_courier"),
      );
    }

    // step: get order with customer for notification
    const order = await prisma.order.findUnique({
      where: { id: orderId },
      include: {
        externalApp: true,
        customer: {
          select: { id: true, lang: true, fcm_token: true },
        },
      },
    });

    if (!order) {
      throw new AppError(
        HttpStatusCode.NOT_FOUND,
        res.__("errors.order_not_found"),
      );
    }

    // step: verify courier is assigned to this order
    if (order.courier_id !== courier.id) {
      throw new AppError(
        HttpStatusCode.FORBIDDEN,
        res.__("errors.not_assigned_to_order"),
      );
    }

    // step: check order is in progress
    if (order.status !== OrderStatus.IN_PROGRESS) {
      throw new AppError(
        HttpStatusCode.BAD_REQUEST,
        res.__("errors.order_not_in_progress"),
      );
    }

    // step: prevent double-collect
    if (order.order_collected_at) {
      throw new AppError(
        HttpStatusCode.BAD_REQUEST,
        res.__("errors.order_already_collected"),
      );
    }

    const collectedAt = new Date();
    // step: mark as collected
    const updatedOrder = await prisma.order.update({
      where: { id: orderId },
      data: { order_collected_at: collectedAt },
    });
    // --- WEBHOOK LOGIC ---
    if (order.externalApp?.webhook_url && order.externalApp?.webhook_secret) {
      await sendWebhookEvent<WebhookOrderCollectedPayload>(
        order.external_app_id!,
        {
          webhookUrl: order.externalApp.webhook_url,
          webhookSecret: order.externalApp.webhook_secret,
          eventType: "ORDER_COLLECTED",
          payload: {
            id: order.id,
            order_number: order.order_number,
            courier_id: courier.id,
            status: "IN_PROGRESS",
            collected_at: collectedAt.toISOString(),
          },
        },
      );
    }

    // step: emit socket event to customer app
    OrderSocketioService.emitOrderCollected(orderId, courier.id, user.id);

    // step: push notification to customer
    if (order.customer) {
      await notifyUser({
        user: {
          id: order.customer.id,
          lang: order.customer.lang,
          fcm_token: order.customer.fcm_token,
        },
        content: {
          title: { en: "Order picked up", ar: "تم استلام الطلب" },
          body: {
            en: `Your order #${order.order_number} has been picked up and is on its way.`,
            ar: `تم استلام طلبك رقم #${order.order_number} وهو في طريقه إليك.`,
          },
        },
        data: {
          page: `/orders/${orderId}`,
          navigate: "order_details",
          orderId,
          type: "ORDER_COLLECTED",
        },
      });
    }

    logger.info({ courierId: courier.id, orderId }, "[Order] Order collected");

    return responseHandler({
      res,
      message: res.__("messages.order_collected"),
      data: { order: updatedOrder },
    });
  };

  // ============================ completeDelivery ============================
  completeDelivery = async (
    req: Request,
    res: Response,
    next: NextFunction,
  ) => {
    const user = res.locals.user;
    const orderId = parseInt(req.params.orderId as string);
    const { actual_price, confirmation_otp }: CompleteDeliveryDTO = req.body;

    // step: validate orderId
    if (isNaN(orderId)) {
      throw new AppError(
        HttpStatusCode.BAD_REQUEST,
        res.__("errors.invalid_order_id"),
      );
    }

    // step: get courier with user badge info
    const courier = await prisma.courier.findUnique({
      where: { user_id: user.id },
      include: {
        user: {
          include: { badge: true },
        },
        stat: true,
      },
    });

    if (!courier) {
      throw new AppError(
        HttpStatusCode.FORBIDDEN,
        res.__("errors.not_courier"),
      );
    }

    // step: get order
    const order = await prisma.order.findUnique({
      where: { id: orderId },
    });

    if (!order) {
      throw new AppError(
        HttpStatusCode.NOT_FOUND,
        res.__("errors.order_not_found"),
      );
    }

    // step: verify courier is assigned to this order
    if (order.courier_id !== courier.id) {
      throw new AppError(
        HttpStatusCode.FORBIDDEN,
        res.__("errors.not_assigned_to_order"),
      );
    }

    // step: check order is in progress
    if (order.status !== OrderStatus.IN_PROGRESS) {
      throw new AppError(
        HttpStatusCode.BAD_REQUEST,
        res.__("errors.order_not_in_progress"),
      );
    }

    // step: update actual_price
    await prisma.order.update({
      where: { id: order.id },
      data: { actual_price },
    });

    // step: verify confirmation OTP if provided
    if (confirmation_otp) {
      // step: check OTP
      if (confirmation_otp !== order.confirmation_otp) {
        throw new AppError(
          HttpStatusCode.BAD_REQUEST,
          res.__("errors.invalid_confirmation_otp"),
        );
      }
      const authHeader = req.headers.authorization;

      // If your middleware ensures "Bearer <token>" format:
      const token = authHeader?.split(" ")[1];
      if (!token) {
        throw new AppError(
          HttpStatusCode.UNAUTHORIZED,
          "Authorization header missing",
        );
      }

      // ✅ Call admin backend
      await confirmDeliveryAdminApi({
        // const adminResponse = await confirmDeliveryAdminApi({
        order_id: order.id,
        courier_id: courier.id,
        token,
      });
      OrderSocketioService.emitOrderCollected(orderId, courier.id, user.id);

      logger.info(
        { orderId: order.id, courierId: courier.id },
        "[Order] Delivery confirmed via admin API",
      );

      return responseHandler({
        res,
        message: res.__("messages.done"),
        // data: {
        //   admin_response: adminResponse, // optional
        // },
      });
    } else {
      // step: generate QR code
      // 1. Create the payload (what the QR contains)
      const qrPayload = JSON.stringify({
        orderId: order.id,
        courierId: courier.id,
        userId: user.id,
        action: "CONFIRM_DELIVERY",
        timestamp: new Date().toISOString(),
        actual_price,
      });
      // 2. Generate the QR Code (Returns a Data URL string: "data:image/png;base64,..." )
      const qrCodeDataURL = await QRCode.toDataURL(qrPayload);
      logger.info(
        { courierId: courier.id, orderId },
        "[Order] Delivery complete — QR generated",
      );
      return responseHandler({
        res,
        message: res.__("messages.qr_generated"),
        data: {
          qr_code: qrCodeDataURL,
          order_id: order.id,
        },
      });
    }
  };

  //============================ cancelUnavailable ============================
  cancelUnavailable = async (
    req: Request,
    res: Response,
    next: NextFunction,
  ) => {
    const user = res.locals.user;
    const orderId = parseInt(req.params.orderId as string);
    const { note }: ReportUnavailableOrderDTO = req.body;

    // step: validate orderId
    if (isNaN(orderId)) {
      throw new AppError(
        HttpStatusCode.BAD_REQUEST,
        res.__("errors.invalid_order_id"),
      );
    }

    // step: get courier
    const courier = await prisma.courier.findUnique({
      where: { user_id: user.id },
    });

    if (!courier) {
      throw new AppError(
        HttpStatusCode.FORBIDDEN,
        res.__("errors.not_courier"),
      );
    }

    // step: get order
    const order = await prisma.order.findUnique({
      where: { id: orderId },
      include: {
        externalApp: true,
        customer: {
          select: {
            id: true,
            lang: true,
            fcm_token: true,
          },
        },
      },
    });

    if (!order) {
      throw new AppError(
        HttpStatusCode.NOT_FOUND,
        res.__("errors.order_not_found"),
      );
    }

    // step: verify courier is assigned to this order
    if (order.courier_id !== courier.id) {
      throw new AppError(
        HttpStatusCode.FORBIDDEN,
        res.__("errors.not_assigned_to_order"),
      );
    }

    // step: check order is in progress
    if (order.status !== OrderStatus.IN_PROGRESS) {
      throw new AppError(
        HttpStatusCode.BAD_REQUEST,
        res.__("errors.order_not_in_progress_unavailable"),
      );
    }

    const cancellationReason = note || "Product unavailable";
    const cancelledAt = new Date();
    // step: cancel order without penalty
    const updatedOrder = await prisma.$transaction(async (tx) => {
      await handleOrderReversal(tx, order);

      await refundCustomerWallet(
        tx,
        order,
        "Refund after courier cancellation (unavailable)",
      );

      // ── 4. Update order ────────────────────────
      return tx.order.update({
        where: { id: orderId },
        data: {
          status: OrderStatus.CANCELLED,
          cancelled_reason: cancellationReason,
          canceled_at: cancelledAt,
          cancelled_by: courier.id,
          cancellation_fee: null,
        },
      });
    });

    if (order.externalApp?.webhook_url && order.externalApp?.webhook_secret) {
      await sendWebhookEvent<WebhookOrderCancelledPayload>(
        order.external_app_id!,
        {
          webhookUrl: order.externalApp.webhook_url,
          webhookSecret: order.externalApp.webhook_secret,
          eventType: "ORDER_CANCELLED",
          payload: {
            id: order.id,
            order_number: order.order_number,
            status: "CANCELLED",
            reason: cancellationReason,
            cancelled_at: cancelledAt.toISOString(),
            cancelled_by_type: "COURIER",
          },
        },
      );
    }
    // step: emit socket event to customer app
    OrderSocketioService.emitOrderCancelledUnavailable(orderId);

    // step: send push notification to customer
    if (order.customer) {
      await notifyUser({
        user: {
          id: order.customer.id,
          lang: order.customer.lang,
          fcm_token: order.customer.fcm_token,
        },
        content: {
          title: {
            en: "Order cancelled",
            ar: "تم إلغاء الطلب",
          },
          body: {
            en: `Order #${orderId} has been cancelled.`,
            ar: `تم إلغاء الطلب رقم #${orderId}.`,
          },
        },
        data: {
          page: `/orders/${orderId}`,
          navigate: "order_details",
          orderId,
          type: "ORDER_CANCELLED",
        },
      });
    }

    // step: delete the order's chat (messages + participants) and its
    // stored "new message" notifications now that the order is cancelled
    await deleteOrderChatOnCompletion(orderId).catch((err) => {
      logger.error({ orderId, err }, "[Order] failed to clean up order chat");
    });

    logger.warn(
      { courierId: courier.id, orderId },
      "[Order] Order cancelled — item unavailable",
    );

    return responseHandler({
      res,
      message: res.__("messages.order_cancelled_unavailable"),
      data: { order: updatedOrder },
    });
  };

  // ============================ cancelOther ============================
  cancelOther = async (req: Request, res: Response, next: NextFunction) => {
    const user = res.locals.user;
    const orderId = parseInt(req.params.orderId as string);
    const { reason }: CancelOtherDTO = req.body;

    // step: validate orderId
    if (isNaN(orderId)) {
      throw new AppError(
        HttpStatusCode.BAD_REQUEST,
        res.__("errors.invalid_order_id"),
      );
    }

    // step: get courier with stats and wallet
    const courier = (await prisma.courier.findUnique({
      where: { user_id: user.id },
      include: {
        stat: true,
        user: {
          include: {
            wallet: true,
          },
        } as any,
      },
    })) as any;

    if (!courier) {
      throw new AppError(
        HttpStatusCode.FORBIDDEN,
        res.__("errors.not_courier"),
      );
    }

    // step: get order
    const order = await prisma.order.findUnique({
      where: { id: orderId },
      include: {
        externalApp: true,
        customer: {
          select: {
            id: true,
            lang: true,
            fcm_token: true,
          },
        },
      },
    });

    if (!order) {
      throw new AppError(
        HttpStatusCode.NOT_FOUND,
        res.__("errors.order_not_found"),
      );
    }

    // step: verify courier is assigned to this order
    if (order.courier_id !== courier.id) {
      throw new AppError(
        HttpStatusCode.FORBIDDEN,
        res.__("errors.not_assigned_to_order"),
      );
    }

    // step: check order is in progress
    if (order.status !== OrderStatus.IN_PROGRESS) {
      throw new AppError(
        HttpStatusCode.BAD_REQUEST,
        res.__("errors.order_not_in_progress_cancel"),
      );
    }

    // step: calculate cancellation fee (penalty) - 50% of delivery fee
    const totalFee = Number(order.total_fee || 0);
    const cancellationFee = totalFee * 0.5;
    const cancelledAt = new Date();

    // Transaction to ensure atomicity
    const updatedOrder = await prisma.$transaction(async (tx) => {
      await handleOrderReversal(tx, order);

      await refundCustomerWallet(
        tx,
        order,
        "Full refund (courier cancellation with penalty)",
      );

      // 1. Create Penalty Record
      const penalty = await tx.penalty.create({
        data: {
          user_id: courier.user_id,
          amount: cancellationFee,
          reason: `Cancellation fee for Order #${order.order_number}`,
          is_paid: false,
          created_at: cancelledAt,
        },
      });

      // 2. Check Wallet and Deduct if sufficient funds
      if (
        courier.user.wallet &&
        Number(courier.user.wallet.balance) >= cancellationFee
      ) {
        // Deduct from wallet
        await tx.wallet.update({
          where: { id: courier.user.wallet.id },
          data: {
            balance: { decrement: cancellationFee },
          },
        });

        // Mark penalty as paid
        await tx.penalty.update({
          where: { id: penalty.id },
          data: {
            is_paid: true,
            paid_at: new Date(),
          },
        });

        // Create Transaction Record
        await tx.transaction.create({
          data: {
            wallet_id: courier.user.wallet.id,
            order_id: order.id,
            type: "PENALTY",
            amount: cancellationFee,
            description: `Paid penalty for cancelling Order #${order.order_number}`,
            status: "COMPLETED",
          },
        });

        // step: Update Platform Wallet Balance
        const platformWallet = await tx.wallet.findFirst({
          where: { owner_type: "PLATFORM" },
        });
        if (!platformWallet) {
          throw new AppError(
            HttpStatusCode.INTERNAL_SERVER_ERROR,
            "Admin wallet not found",
          );
        }
        await tx.wallet.update({
          where: { id: platformWallet.id },
          data: {
            balance: { increment: cancellationFee },
          },
        });
      }

      // 3. Update Order Status
      const updated = await tx.order.update({
        where: { id: orderId },
        data: {
          status: OrderStatus.CANCELLED,
          courier_id: null,
          cancelled_reason: reason,
          canceled_at: cancelledAt,
          cancelled_by: courier.id,
          cancellation_fee: cancellationFee,
        },
      });

      // 4. Update Courier Stats (Earnings)
      if (courier.stat && cancellationFee > 0) {
        await tx.courierStat.update({
          where: { courier_id: courier.id },
          data: {
            total_earnings: Math.max(
              0,
              Number(courier.stat.total_earnings || 0) - cancellationFee,
            ),
          },
        });
      }

      return updated;
    });

    // --- WEBHOOK LOGIC ---
    if (order.externalApp?.webhook_url && order.externalApp?.webhook_secret) {
      await sendWebhookEvent<WebhookOrderCancelledPayload>(
        order.external_app_id!,
        {
          webhookUrl: order.externalApp.webhook_url,
          webhookSecret: order.externalApp.webhook_secret,
          eventType: "ORDER_CANCELLED",
          payload: {
            id: order.id,
            order_number: order.order_number,
            status: "CANCELLED",
            reason: reason || "Courier cancelled for other reasons",
            cancelled_at: cancelledAt.toISOString(),
            cancelled_by_type: "COURIER",
          },
        },
      );
    }

    // step: emit socket event to customer app
    OrderSocketioService.emitOrderCancelledOther(orderId);

    // step: send push notification to customer
    if (order.customer) {
      await notifyUser({
        user: {
          id: order.customer.id,
          lang: order.customer.lang,
          fcm_token: order.customer.fcm_token,
        },
        content: {
          title: {
            en: "Order cancelled",
            ar: "تم إلغاء الطلب",
          },
          body: {
            en: `Order #${orderId} has been cancelled.`,
            ar: `تم إلغاء الطلب رقم #${orderId}.`,
          },
        },
        data: {
          page: `/orders/${orderId}`,
          navigate: "order_details",
          orderId,
          type: "ORDER_CANCELLED",
        },
      });
    }

    // step: delete the order's chat (messages + participants) and its
    // stored "new message" notifications now that the order is cancelled
    await deleteOrderChatOnCompletion(orderId).catch((err) => {
      logger.error({ orderId, err }, "[Order] failed to clean up order chat");
    });

    logger.warn(
      { courierId: courier.id, orderId, cancellationFee },
      "[Order] Order cancelled with penalty",
    );

    return responseHandler({
      res,
      message: res.__("messages.order_cancelled_fee"),
      data: {
        order: updatedOrder,
        cancellationFee,
      },
    });
  };

  // ============================ acceptAssignedOrder ============================
  acceptAssignedOrder = async (
    req: Request,
    res: Response,
    next: NextFunction,
  ) => {
    const user = res.locals.user;
    const { orderId }: AcceptAssignedOrderDTO = res.locals.validatedData;

    // step: emit socket to admin
    OrderSocketioService.emitAssignedOrderAccepted(orderId);

    return responseHandler({
      res,
      message: res.__("messages.order_accepted"),
    });
  };

  // ============================ rejectAssignedOrder ============================
  rejectAssignedOrder = async (
    req: Request,
    res: Response,
    next: NextFunction,
  ) => {
    const user = res.locals.user;
    const { orderId }: RejectAssignedOrderDTO = res.locals.validatedData;

    // step: emit socket to admin
    OrderSocketioService.emitAssignedOrderRejected(orderId);

    return responseHandler({
      res,
      message: res.__("messages.order_rejected"),
    });
  };

  // ============================ reportOrderHighPrice ============================
  reportOrderHighPrice = async (
    req: Request,
    res: Response,
    next: NextFunction,
  ) => {
    const user = res.locals.user;
    const orderId = parseInt(req.params.orderId as string);
    const { actual_price }: ReportOrderHighPriceDTO = req.body;

    // step: validate orderId
    if (isNaN(orderId)) {
      throw new AppError(
        HttpStatusCode.BAD_REQUEST,
        res.__("errors.invalid_order_id"),
      );
    }

    // step: get courier
    const courier = await prisma.courier.findUnique({
      where: { user_id: user.id },
    });

    if (!courier) {
      throw new AppError(
        HttpStatusCode.FORBIDDEN,
        res.__("errors.not_courier"),
      );
    }

    // step: get order
    const order = await prisma.order.findUnique({
      where: { id: orderId },
      include: { externalApp: true }, // Include external app for webhook
    });

    if (!order) {
      throw new AppError(
        HttpStatusCode.NOT_FOUND,
        res.__("errors.order_not_found"),
      );
    }

    // step: verify courier is assigned to this order
    if (order.courier_id !== courier.id) {
      throw new AppError(
        HttpStatusCode.FORBIDDEN,
        res.__("errors.not_assigned_to_order"),
      );
    }

    // step: check order is in progress
    if (order.status !== OrderStatus.IN_PROGRESS) {
      throw new AppError(
        HttpStatusCode.BAD_REQUEST,
        res.__("errors.order_not_in_progress_price"),
      );
    }

    // step: validate actual price is higher than budget
    if (actual_price <= Number(order.budget)) {
      throw new AppError(
        HttpStatusCode.BAD_REQUEST,
        res.__("errors.price_must_be_higher"),
      );
    }
    const proposedAt = new Date();

    // step: update order with actual price (waiting for customer confirmation)
    const updatedOrder = await prisma.order.update({
      where: { id: orderId },
      data: {
        actual_price: actual_price,
        price_adjustment_status: "PENDING",
        proposed_at: proposedAt,
      },
    });

    // --- WEBHOOK LOGIC START ---
    if (order.externalApp?.webhook_url && order.externalApp?.webhook_secret) {
      await sendWebhookEvent<WebhookOrderPriceReportedPayload>(
        order.external_app_id!,
        {
          webhookUrl: order.externalApp.webhook_url,
          webhookSecret: order.externalApp.webhook_secret,
          eventType: "ORDER_PRICE_CHANGED",
          payload: {
            id: order.id,
            order_number: order.order_number,
            courier_id: courier.id,
            original_budget: Number(order.budget),
            new_actual_price: Number(actual_price),
            status: "IN_PROGRESS",
            price_adjustment_status: "PENDING",
            reported_at: proposedAt.toISOString(),
          },
        },
      );
    }
    // --- WEBHOOK LOGIC END ---

    // step: emit socket event to customer app
    OrderSocketioService.emitPriceReport(orderId, actual_price);

    logger.info(
      { courierId: courier.id, orderId, actualPrice: actual_price },
      "[Order] High price reported",
    );

    return responseHandler({
      res,
      message: res.__("messages.high_price_reported"),
      data: { order: updatedOrder },
    });
  };

  // ============================ history ============================
  history = async (req: Request, res: Response, next: NextFunction) => {
    const user = res.locals.user;

    // step: apply filters and pagination using universal filter utility
    const { filters, pagination, paginationMeta } = applyFilters(
      res.locals.validatedData,
      {
        status: "exact",
        budget: "range",
        pickup_area_id: "exact",
        delivery_area_id: "exact",
        pickup_lat: "exact",
        pickup_long: "exact",
        delivery_lat: "exact",
        delivery_long: "exact",
      },
    );

    const courier = await prisma.courier.findUnique({
      where: { user_id: user.id },
    });

    if (!courier) {
      throw new AppError(
        HttpStatusCode.FORBIDDEN,
        res.__("errors.not_courier"),
      );
    }

    // step: add custom business logic filters
    filters.courier_id = courier.id;

    // step: fetch orders and total count
    const [orders, total] = await Promise.all([
      prisma.order.findMany({
        where: filters,
        include: {
          pickup_area: true,
          delivery_area: true,
          customer: {
            select: {
              id: true,
              full_name: true,
              personal_photo: true,
            },
          },
          orderItems: { include: orderItemInclude },
          coupon: {
            select: {
              scope: true,
            },
          },
        },
        orderBy: { created_at: "desc" },
        ...pagination,
      }),
      prisma.order.count({
        where: filters,
      }),
    ]);

    return responseHandler({
      res,
      message: res.__("messages.order_history_retrieved"),
      data: {
        orders: orders.map(({ orderItems, coupon, ...orderFields }) => ({
          ...orderFields,
          coupon_type: coupon?.scope || null,
          orderItems: orderItems.map(formatOrderItem),
        })),
        pagination: buildPaginationResponse(paginationMeta, total),
      },
    });
  };

  // ============================ allCancellationReasons ============================
  allCancellationReasons = async (
    req: Request,
    res: Response,
    next: NextFunction,
  ) => {
    const queryOptions = new FeatureApi(req) // queryOptions :{where, orderBy, take, skip}
      .filter({ role_id: 2 })
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
    const { reasonId } = req.params;

    // step: check if reason exists
    if (!reasonId) {
      throw new AppError(
        HttpStatusCode.BAD_REQUEST,
        res.__("errors.reason_id_required"),
      );
    }
    const reason = await prisma.cancellationReason.findUnique({
      where: { id: Number(reasonId) },
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

  // ============================ acceptFixedFeeOffer ============================
  acceptFixedFeeOffer = async (
    req: Request,
    res: Response,
    next: NextFunction,
  ) => {
    const user = res.locals.user;
    const orderId = parseInt(req.params.orderId as string);
    const {
      action,
      courier_lat,
      courier_long,
      courier_location_address,
      distance_to_pickup,
      estimated_arrival_at_pickup,
      vehicle_id,
    }: AcceptFixedFeeOfferDTO = req.body;

    if (isNaN(orderId)) {
      throw new AppError(
        HttpStatusCode.BAD_REQUEST,
        res.__("errors.invalid_order_id"),
      );
    }

    const courier = await prisma.courier.findUnique({
      where: { user_id: user.id },
    });

    if (!courier) {
      throw new AppError(
        HttpStatusCode.FORBIDDEN,
        res.__("errors.not_courier"),
      );
    }

    // step: claude: block accepting fixed-fee offers when unpaid penalties + unpaid
    // commissions exceed the courier's vehicle `total_fines` threshold
    await this.assertFinesWithinLimit(res, courier, vehicle_id);

    const order = await prisma.order.findUnique({
      where: { id: orderId },
      include: { externalApp: true }, // Ensure externalApp is included
    });

    if (!order) {
      throw new AppError(
        HttpStatusCode.NOT_FOUND,
        res.__("errors.order_not_found"),
      );
    }

    // This endpoint is only for fixed-fee orders
    if (!order.is_fixed_fee) {
      throw new AppError(
        HttpStatusCode.BAD_REQUEST,
        res.__("errors.order_not_fixed_fee"),
      );
    }

    if (order.status !== OrderStatus.PENDING) {
      throw new AppError(
        HttpStatusCode.BAD_REQUEST,
        res.__("errors.order_not_available"),
      );
    }

    // step: check order products_total is within courier's min/max order price range
    const productsTotal = Number(order.products_total || 0);
    const minOrderPrice = courier.min_order_price
      ? Number(courier.min_order_price)
      : null;
    const maxOrderPrice = courier.max_order_price
      ? Number(courier.max_order_price)
      : null;

    if (minOrderPrice !== null && productsTotal < minOrderPrice) {
      throw new AppError(
        HttpStatusCode.BAD_REQUEST,
        res.__(
          "errors.order_below_min_price",
          minOrderPrice?.toString() ?? "-",
          maxOrderPrice?.toString() ?? "-",
        ),
      );
    }

    if (maxOrderPrice !== null && productsTotal > maxOrderPrice) {
      throw new AppError(
        HttpStatusCode.BAD_REQUEST,
        res.__(
          "errors.order_above_max_price",
          minOrderPrice?.toString() ?? "-",
          maxOrderPrice?.toString() ?? "-",
        ),
      );
    }

    // step: get app settings
    const appSettings = await prisma.applicationSetting.findFirst();
    if (!appSettings) {
      throw new AppError(
        HttpStatusCode.INTERNAL_SERVER_ERROR,
        "ApplicationSettings record not found",
      );
    }

    // step: check courier has not reached to max_orders_per_trip
    const activeOrders = await prisma.order.findMany({
      where: {
        courier_id: courier.id,
        status: OrderStatus.IN_PROGRESS,
      },
    });
    if (activeOrders.length >= appSettings.max_orders_per_trip) {
      throw new AppError(
        HttpStatusCode.BAD_REQUEST,
        res.__("errors.max_orders_per_trip_reached"),
      );
    }

    // ── REJECT ────────────────────────────────────────────────────────────────
    if (action === "REJECT") {
      // Create a rejected proposal so the admin/customer can see who declined
      const proposal = await prisma.orderProposal.create({
        data: {
          order_id: orderId,
          courier_id: courier.id,
          total_fee: order.total_fee ?? 0,
          status: ProposalStatus.REJECTED,
          vehicle_id: vehicle_id ?? null,
        },
      });

      // Send Webhook for Rejection
      if (order.externalApp?.webhook_url && order.externalApp?.webhook_secret) {
        await sendWebhookEvent<WebhookFixedFeeRejectedPayload>(
          order.external_app_id!,
          {
            webhookUrl: order.externalApp.webhook_url,
            webhookSecret: order.externalApp.webhook_secret,
            eventType: "ORDER_OFFER_REJECTED",
            payload: {
              id: order.id,
              proposal_id: proposal.id,
              courier_id: courier.id,
              status: "REJECTED",
            },
          },
        );
      }

      logger.info(
        { courierId: courier.id, orderId },
        "[Order] Fixed-fee offer rejected",
      );

      return responseHandler({
        res,
        message: res.__("messages.fixed_fee_offer_rejected"),
        data: { proposal },
      });
    }

    // ── ACCEPT ────────────────────────────────────────────────────────────────
    // For fixed-fee orders the fee is already set on the order — no negotiation.
    // We create an ACCEPTED proposal immediately and move the order to IN_PROGRESS.
    const result = await prisma.$transaction(async (tx) => {
      // Guard against race: another courier may have accepted in the same instant
      const freshOrder = await tx.order.findUnique({
        where: { id: orderId },
        select: { status: true, total_fee: true },
      });

      if (freshOrder?.status !== OrderStatus.PENDING) {
        throw new AppError(
          HttpStatusCode.CONFLICT,
          res.__("errors.order_no_longer_available"),
        );
      }

      // const proposal = await tx.orderProposal.create({
      //   data: {
      //     order_id: orderId,
      //     courier_id: courier.id,
      //     total_fee: order.total_fee ?? 0,
      //     status: ProposalStatus.ACCEPTED,
      //     confirmed_at: new Date(),
      //     courier_lat: courier_lat ?? null,
      //     courier_long: courier_long ?? null,
      //     courier_location_address: courier_location_address ?? null,
      //     distance_to_pickup: distance_to_pickup ?? null,
      //     estimated_arrival_at_pickup: estimated_arrival_at_pickup ?? null,
      //     vehicle_id: vehicle_id ?? null,
      //   },
      // });

      const updatedOrder = await tx.order.update({
        where: { id: orderId },
        data: {
          courier_id: courier.id,
          status: OrderStatus.IN_PROGRESS,
          offer_accepted_at: new Date(),
        },
        include: {
          externalApp: true,
        },
      });

      return { updatedOrder };
      // return { proposal, updatedOrder };
    });
    if (
      result.updatedOrder.externalApp?.webhook_url &&
      result.updatedOrder.externalApp?.webhook_secret
    ) {
      await sendWebhookEvent<WebhookFixedFeeAcceptedPayload>(
        result.updatedOrder.external_app_id!,
        {
          webhookUrl: result.updatedOrder.externalApp.webhook_url,
          webhookSecret: result.updatedOrder.externalApp.webhook_secret,
          eventType: "ORDER_OFFER_ACCEPTED",
          payload: {
            id: result.updatedOrder.id,
            order_number: result.updatedOrder.order_number,
            courier_id: courier.id,
            status: "IN_PROGRESS",
            accepted_at: result.updatedOrder.offer_accepted_at!.toISOString(),
            total_fee: Number(result.updatedOrder.total_fee),
          },
        },
      );
    }
    // Notify customer via socket
    // OrderSocketioService.emitOfferAccepted(orderId, courier.id);
    // OrderSocketioService.emitOfferNew(orderId);
    OrderSocketioService.emitOrderCollected(orderId, courier.id, user.id);

    logger.info(
      { courierId: courier.id, orderId },
      "[Order] Fixed-fee offer accepted",
    );

    return responseHandler({
      res,
      message: res.__("messages.fixed_fee_offer_accepted"),
      data: {
        order: result.updatedOrder,
        // proposal: result.proposal,
      },
    });
  };

  // ============================ updateLocation ============================
  updateLocation = async (req: Request, res: Response, next: NextFunction) => {
    const user = res.locals.user;
    const orderId = Number(req.params.orderId);

    if (!Number.isInteger(orderId) || orderId <= 0) {
      throw new AppError(
        HttpStatusCode.BAD_REQUEST,
        res.__("errors.invalid_order_id"),
      );
    }
    const { lat, lng }: UpdateLocationDTO = req.body;

    // 2. Validate order
    const order = await prisma.order.findFirst({
      where: {
        id: orderId,
        courier_id: user.courier.id,
        status: "IN_PROGRESS",
        customer_id: { not: null },
      },
      select: {
        id: true,
        customer_id: true,
      },
    });

    if (order?.customer_id === null) {
      throw new AppError(
        HttpStatusCode.BAD_REQUEST,
        res.__("errors.no_active_order"),
      );
    }

    // 3. Update location
    await updateCourierLocation(user.courier.id, lat, lng);

    const timestamp = new Date().toISOString();

    // 4. Emit via socket (IMPORTANT 🔥)
    OrderSocketioService.emitCourierLocationUpdate({
      courierId: user.courier.id,
      orderId,
      lat,
      lng,
      customerId: order?.customer_id!,
      timestamp,
    });

    return responseHandler({
      res,
      message: res.__("messages.location_updated"),
    });
  };
}
