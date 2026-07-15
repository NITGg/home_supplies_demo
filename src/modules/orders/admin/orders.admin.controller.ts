import type { Response } from "express";
import {
  orderIdParamsSchema,
  adminUpdateOrderSchema,
  adminCancelOrderSchema,
  proposalIdParamsSchema,
  adminUpdateProposalSchema,
  adminManualAssignSchema,
  adminRetryOrderSchema,
  adminSoftCancelSchema,
  adminSendFixedOfferSchema,
  adminBroadcastFixedOfferSchema,
} from "./orders.admin.schema";
import {
  adminListOrdersService,
  adminGetOrderByIdService,
  adminUpdateOrderService,
  adminCancelOrderService,
  adminListProposalsService,
  adminUpdateProposalService,
} from "./orders.admin.service";
import FeatureApi from "@/lib/featureApi";
import { AuthedRequest } from "@/types/authedRequest";
import {
  adminBroadcastFixedService,
  adminManualAssignFixedService,
  adminManualAssignService,
  adminManualAssignServiceV2,
  adminRetryOrderService,
  adminSoftCancelService,
} from "./admin.recovery.service";
import { deleteOrderChatService } from "@/modules/orders/services/orders.chat.service";

export async function adminListOrders(req: AuthedRequest, res: Response) {
  const data = new FeatureApi(req)
    .filter()
    .sort("-created_at")
    .limit(10)
    .skip(0)
    .includes()
    .keyword(["order_number", "customer.full_name", "courier.user.full_name"])
    .fields().data;
  const result = await adminListOrdersService(data);
  return res.json(result);
}

export async function adminGetOrder(req: AuthedRequest, res: Response) {
  const { id } = orderIdParamsSchema.parse(req.sanitized.params);
  const data = new FeatureApi(req)
    .includes()
    .filter({ id }, { allowKeys: ["id"] })
    .fields().data;

  const order = await adminGetOrderByIdService(data);
  return res.json({ order });
}

export async function adminUpdateOrder(req: AuthedRequest, res: Response) {
  const { id } = orderIdParamsSchema.parse(req.sanitized.params);
  const data = adminUpdateOrderSchema.parse(req.sanitized.body);
  const order = await adminUpdateOrderService(id, data);
  return res.json({
    message: req.t("orders:messages.order_updated") ?? "Order updated",
    order,
  });
}

export async function adminCancelOrder(req: AuthedRequest, res: Response) {
  const adminId = req.user?.id;
  const { id } = orderIdParamsSchema.parse(req.sanitized.params);
  const data = adminCancelOrderSchema.parse(req.sanitized.body);
  const order = await adminCancelOrderService(id, data, adminId);
  return res.json({
    message: req.t?.("orders:messages.order_cancelled") ?? "Order cancelled",
    order,
  });
}

export async function adminListOrderProposals(
  req: AuthedRequest,
  res: Response,
) {
  const { id } = orderIdParamsSchema.parse(req.sanitized.params);
  const proposals = await adminListProposalsService(id);
  return res.json({ proposals });
}

export async function adminUpdateProposal(req: AuthedRequest, res: Response) {
  const { proposalId } = proposalIdParamsSchema.parse(req.sanitized.params);
  const data = adminUpdateProposalSchema.parse(req.sanitized.body);
  const proposal = await adminUpdateProposalService(proposalId, data);
  return res.json({
    message: req.t?.("orders:messages.proposal_updated") ?? "Proposal updated",
    proposal,
  });
}

// ── Playbook A ────────────────────────────────────────────────────────────────

export async function adminManualAssignController(
  req: AuthedRequest,
  res: Response,
) {
  const orderId = Number(req.sanitized.params.orderId);
  const adminUserId = req.user.id; // populated by your auth middleware

  const input = adminManualAssignSchema.parse(req.sanitized.body);

  const proposal = await adminManualAssignService(orderId, input, adminUserId);

  res.status(200).json({
    message: req.t("orders:messages.manual_assign"),
    data: proposal,
  });
}

// ── Playbook A (v2) ───────────────────────────────────────────────────────────

export async function adminManualAssignControllerV2(
  req: AuthedRequest,
  res: Response,
) {
  const orderId = Number(req.sanitized.params.orderId);
  const adminUserId = req.user.id; // populated by your auth middleware

  const input = adminManualAssignSchema.parse(req.sanitized.body);

  const { courier } = await adminManualAssignServiceV2(
    orderId,
    input,
    adminUserId,
  );

  res.status(200).json({
    message: req.t("orders:messages.manual_assign"),
    data: { courier },
  });
}

// ── Playbook B ────────────────────────────────────────────────────────────────

export async function adminRetryOrderController(
  req: AuthedRequest,
  res: Response,
) {
  const orderId = Number(req.sanitized.params.orderId);
  const adminUserId = req.user.id;

  const input = adminRetryOrderSchema.parse(req.sanitized.body);

  const result = await adminRetryOrderService(orderId, input, adminUserId);

  res.status(200).json({
    message: req.t("orders:messages.order_retried"),
    data: result,
  });
}

// ── Playbook C ────────────────────────────────────────────────────────────────

export async function adminSoftCancelController(
  req: AuthedRequest,
  res: Response,
) {
  const orderId = Number(req.sanitized.params.orderId);
  const adminUserId = req.user.id;

  const input = adminSoftCancelSchema.parse(req.sanitized.body);

  const result = await adminSoftCancelService(orderId, input, adminUserId);

  res.status(200).json({
    message: req.t("orders:messages.soft_cancelled"),
    data: result,
  });
}

export async function adminManualAssignFixedController(
  req: AuthedRequest,
  res: Response,
) {
  const orderId = Number(req.sanitized.params.orderId);
  const adminUserId = req.user.id; // populated by your auth middleware
  const input = adminSendFixedOfferSchema.parse(req.sanitized.body);

  const proposal = await adminManualAssignFixedService(
    orderId,
    input,
    adminUserId,
  );
  res.status(200).json({
    message: req.t("orders:messages.manual_assign_fixed"),
    data: proposal,
  });
}

// step: claude: "9- delete order user chat notifications"
// DELETE /admin/orders/:orderId/chat
// Hard-deletes the Chat linked to the order (cascades to ChatMessage + ChatParticipant)
// and fires a `chat:deleted` socket event to every former participant.
export async function adminDeleteOrderChat(req: AuthedRequest, res: Response) {
  const orderId = Number(req.sanitized.params.orderId);
  const result = await deleteOrderChatService(orderId, req.user.id, true);
  res.status(200).json({
    message: req.t("orders:messages.chat_deleted"),
    data: result,
  });
}

export async function adminBroadcastFixedController(
  req: AuthedRequest,
  res: Response,
) {
  const orderId = Number(req.sanitized.params.orderId);
  const adminUserId = req.user.id; // populated by your auth middleware
  const input = adminBroadcastFixedOfferSchema.parse(req.sanitized.body);

  const result = await adminBroadcastFixedService(orderId, input, adminUserId);
  res.status(200).json({
    message: req.t("orders:messages.broadcast_fixed"),
    data: result,
  });
}
