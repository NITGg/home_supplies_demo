import FeatureApi from "@/lib/featureApi";
import type { AuthedRequest } from "@/types/authedRequest";
import type { Response } from "express";
import {
  acceptProposalParamsSchema,
  cancelOrderSchema,
  confirmDeliverySchema,
  createOrderIssueSchema,
  createOrderSchema,
  deliverySlotsQuerySchema,
  orderIdParamsSchema,
  orderProposalsParamsSchema,
  priceAdjustmentSchema,
  proposalDecisionSchema,
} from "./orders.schema";
import {
  createCatalogOrderService,
  getCartDeliverySlotsService,
  previewOrderService,
} from "./services/orders.catalog.service";
import {
  acceptPartnerProposalService,
  createPartnerOrderService,
  previewPartnerOrderService,
} from "./services/orders.partner.service";
import {
  acceptPriceAdjustmentService,
  acceptProposalService,
  cancelOrderService,
  completedOrdersCount,
  confirmDeliveryService,
  createOrderIssueService,
  createOrderService,
  customerRetryOrderService,
  getCourierLocationService,
  getOrderByIdService,
  listOrderProposalsService,
  listOrdersService,
  rejectPriceAdjustmentService,
  getOrderFeeBoundsService,
} from "./services/orders.service";

// ─── Helpers ──────────────────────────────────────────────────────────────────

function getCustomerId(req: AuthedRequest): number {
  return Number(req.user!.id);
}

// ─── Controllers ──────────────────────────────────────────────────────────────

export async function createOrder(req: AuthedRequest, res: Response) {
  const input = createOrderSchema.parse({
    ...req.sanitized.body,
    ...(req.externalApp ? { type: "CUSTOM_PICKUP" } : {}),
  });
  const file = req.file;

  // ── External app path ──────────────────────────────────────────────────────
  if (req.externalApp) {
    if (input.type !== "CUSTOM_PICKUP") {
      return res.status(400).json({
        message: req.t("orders:errors.external_app_catalog_not_allowed"),
        code: "CATALOG_NOT_ALLOWED",
      });
    }

    const baseUrl = `${req.protocol}://${req.get("host")}/admin_apis/api/v1`;
    const result = await createPartnerOrderService(
      input,
      req.externalApp.id,
      file,
      {
        lang: req.language,
        paymobWebhookUrl: `${baseUrl}/webhooks/paymob`,
        kashierWebhookUrl: `${baseUrl}/webhooks/kashier`,
        easykashWebhookUrl: `${baseUrl}/webhooks/easykash`,
      },
    );

    return res.status(201).json({
      message: req.t("orders:messages.order_created"),
      order: result.order,
      ...(result.cardPayment ? { payment: result.cardPayment } : {}),
    });
  }

  // ── User path ──────────────────────────────────────────────────────────────
  const customerId = getCustomerId(req);

  if (input.type === "CATALOG_PURCHASE") {
    // const baseUrl = `https://unwaddling-jericho-checkable.ngrok-free.dev/api/v1`;
    const baseUrl = `${req.protocol}://${req.get("host")}/admin_apis/api/v1`;
    const result = await createCatalogOrderService(input, customerId, {
      user: {
        full_name: req.user.full_name,
        email: req.user.email,
        phone: req.user.phone,
      },
      lang: req.language,
      paymobWebhookUrl: `${baseUrl}/webhooks/paymob`,
      kashierWebhookUrl: `${baseUrl}/webhooks/kashier`,
      easykashWebhookUrl: `${baseUrl}/webhooks/easykash`,
    });

    return res.status(201).json({
      message: req.t("orders:messages.order_created"),
      order: result.order,
      ...(result.cardPayment ? { payment: result.cardPayment } : {}),
    });
  }

  const order = await createOrderService(input, customerId, file);

  return res.status(201).json({
    message: req.t("orders:messages.order_created"),
    order,
  });
}

// step: claude: customer endpoint — available type-3 delivery slots for the cart on a given date
export async function getCartDeliverySlots(req: AuthedRequest, res: Response) {
  const customerId = getCustomerId(req);
  const { date } = deliverySlotsQuerySchema.parse(req.sanitized.query);
  const result = await getCartDeliverySlotsService(customerId, date);
  return res.json(result);
}

export async function previewOrder(req: AuthedRequest, res: Response) {
  const input = createOrderSchema.parse({
    ...req.sanitized.body,
    ...(req.externalApp
      ? {
          type: "CUSTOM_PICKUP",
          product_description: "External app order",
        }
      : {}),
  });
  const customerId = getCustomerId(req);

  if (req.externalApp) {
    if (input.type !== "CUSTOM_PICKUP") {
      return res.status(400).json({
        message: req.t("orders:errors.external_app_catalog_not_allowed"),
        code: "CATALOG_NOT_ALLOWED",
      });
    }
    const preview = await previewPartnerOrderService(input, req.externalApp.id);
    return res.json({ preview });
  }

  const preview = await previewOrderService(input, customerId);
  return res.json({ preview });
}

export async function listMyOrders(req: AuthedRequest, res: Response) {
  const customer_id = req.user?.id;
  const external_app_id = req.externalApp?.id;
  const data = new FeatureApi(req)
    .filter(
      { customer_id, external_app_id },
      {
        allowKeys: [
          "customer_id",
          "status",
          "created_at",
          "expires_at",
          "type",
        ],
      },
    )
    .sort("-created_at")
    .limit(10)
    .skip(0)
    .includes()
    .keyword(["order_number", "courier.full_name"])
    .fields().data;

  const result = await listOrdersService(data);
  return res.json(result);
}

export async function getOrderById(req: AuthedRequest, res: Response) {
  const userId = req.user?.id;
  const external_app_id = req.externalApp?.id;

  const { id } = orderIdParamsSchema.parse(req.sanitized.params);
  const order = await getOrderByIdService(id, userId, external_app_id);
  return res.json({ order });
}

export async function cancelOrder(req: AuthedRequest, res: Response) {
  const userId = req.user?.id;
  const { id } = orderIdParamsSchema.parse(req.sanitized.params);
  const data = cancelOrderSchema.parse(req.sanitized.body);
  const order = await cancelOrderService(id, data, userId);
  return res.json({
    message: req.t?.("orders:messages.order_cancelled") ?? "Order cancelled",
    order,
  });
}

export async function listOrderProposals(req: AuthedRequest, res: Response) {
  const customerId = req.user?.id;
  const { orderId } = orderProposalsParamsSchema.parse(req.sanitized.params);
  const proposals = await listOrderProposalsService(
    orderId,
    customerId,
    req.externalApp?.id,
  );
  return res.json({ proposals });
}

export async function acceptProposal(req: AuthedRequest, res: Response) {
  const data = proposalDecisionSchema.parse(req.sanitized.body);
  const { orderId, proposalId } = acceptProposalParamsSchema.parse(
    req.sanitized.params,
  );

  // Partner path
  if (req.externalApp) {
    const result = await acceptPartnerProposalService(
      orderId,
      proposalId,
      data,
      req.externalApp.id,
    );
    return res.json({
      message:
        data.status === "ACCEPTED"
          ? req.t("orders:messages.proposal_accepted")
          : req.t("orders:messages.proposal_rejected"),
      ...result,
    });
  }

  // Customer path
  const customerId = req.user?.id;
  const result = await acceptProposalService(
    orderId,
    proposalId,
    data,
    customerId,
  );
  return res.json({
    message:
      data.status === "ACCEPTED"
        ? (req.t?.("orders:messages.proposal_accepted") ?? "Proposal accepted")
        : (req.t?.("orders:messages.proposal_rejected") ?? "Proposal rejected"),
    ...result,
  });
}

export async function confirmDelivery(req: AuthedRequest, res: Response) {
  const customerId = req.user?.id;
  const data = confirmDeliverySchema.parse(req.sanitized.body);
  const order = await confirmDeliveryService(
    data,
    customerId,
    req.user.role.name,
  );

  return res.json({
    message:
      req.t?.("orders:messages.delivery_confirmed") ?? "Delivery confirmed",
    order,
  });
}

export async function priceAdjustment(req: AuthedRequest, res: Response) {
  const { orderId } = orderProposalsParamsSchema.parse(req.sanitized.params);
  const { status } = priceAdjustmentSchema.parse(req.sanitized.body);

  const isPartner = !!req.externalApp;
  const customerId = req.user?.id;
  const externalAppId = req.externalApp?.id;

  if (status === "REJECTED") {
    const order = await rejectPriceAdjustmentService({
      orderId,
      customerId: isPartner ? undefined : customerId,
      externalAppId: isPartner ? externalAppId : undefined,
    });
    return res.json({
      message:
        req.t?.("orders:messages.price_adjustment_rejected") ??
        "Price adjustment rejected",
      order,
    });
  }

  const order = await acceptPriceAdjustmentService({
    orderId,
    customerId: isPartner ? undefined : customerId,
    externalAppId: isPartner ? externalAppId : undefined,
  });

  return res.json({
    message:
      req.t?.("orders:messages.price_adjustment_accepted") ??
      "Price adjustment accepted",
    order,
  });
}

export async function retryOrder(req: AuthedRequest, res: Response) {
  const userId = req.user?.id;
  const { id } = orderIdParamsSchema.parse(req.sanitized.params);
  const order = await customerRetryOrderService(id, userId);
  return res.json({
    message: req.t?.("orders:messages.order_retried") ?? "Order retried",
    order,
  });
}

export async function createOrderIssue(req: AuthedRequest, res: Response) {
  const userId = req.user?.id;
  const { orderId } = orderProposalsParamsSchema.parse(req.sanitized.params);
  const data = createOrderIssueSchema.parse({
    ...req.sanitized.body,
    order_id: orderId,
  });
  const issue = await createOrderIssueService(data, userId);
  return res.status(201).json({
    message:
      req.t?.("orders:messages.order_issue.created_success") ?? "Issue created",
    issue,
  });
}

export async function getCompletedOrdersCount(
  req: AuthedRequest,
  res: Response,
) {
  const userId = req.user.id;
  const total = await completedOrdersCount(userId);
  return res.status(200).json({
    message:
      req.t?.("orders:messages.count_retrieved") ??
      "Order count retrieved successfully",
    total,
  });
}

export async function getCourierLocation(req: AuthedRequest, res: Response) {
  const userId = req.user.id;
  const isAdmin = req.user.role.name === "Admin";
  const { orderId } = orderProposalsParamsSchema.parse(req.sanitized.params);
  const location = await getCourierLocationService(
    orderId,
    isAdmin ? undefined : userId,
  );
  return res.json({ location });
}

export async function getOrderFeeBounds(req: AuthedRequest, res: Response) {
  const { id: orderId } = orderIdParamsSchema.parse(req.sanitized.params);
  const userId = req.user.id;

  const bounds = await getOrderFeeBoundsService(orderId, userId);

  return res.status(200).json(bounds);
}
