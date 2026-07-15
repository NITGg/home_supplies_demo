import { bus } from "./bus";
import { logger } from "@/config/logger";
import { onOrderDelivered } from "./handlers/orderDelivered";
import { onOrderCreated } from "./handlers/orderCreated";
import { onOfferAccepted, onOfferRejected } from "./handlers/orderProposal";
import { onOrderCancelled } from "./handlers/orderCancelled";
import {
  onCourierCouponCreated,
  onCourierCouponUpdated,
} from "./handlers/courierCoupon";
import {
  onCustomerCouponCreated,
  onCustomerCouponUpdated,
} from "./handlers/customerCoupon";
import onNoProposalOrders from "./handlers/noProposals";
import onOrderIssueCreated from "./handlers/orderIssue";
import onOrderExpired from "./handlers/orderExpired";
import { getIo } from "@/socket";
import {
  onRefundApproved,
  onRefundRequested,
  onRefundRejected,
} from "./handlers/refunds";

export function registerEvents() {
  bus.on("order.delivered", (e) => {
    logger.info(e, "event: order.delivered");

    onOrderDelivered(e).catch((err) => {
      console.error("event handler failed: order.delivered", err);
    });
  });

  bus.on("order.cancelled", (e) => {
    logger.info(e, "event: order.cancelled");
    onOrderCancelled(e).catch((err) =>
      console.error("handler failed: order.cancelled", err),
    );
  });

  bus.on("order.status.changed", (e) => {
    logger.info({ ...e }, "event: order.status.changed");
  });

  bus.on("order.created", (e) => {
    logger.info(e, "event: order.created");

    onOrderCreated(e).catch((err) =>
      console.error("event handler failed: order.created", err),
    );
  });

  bus.on("offer.accepted", (e) => {
    logger.info(e, "event: offer.accepted");

    onOfferAccepted(e).catch((err) =>
      console.error("event handler failed: offer.accepted", err),
    );
  });

  bus.on("offer.rejected", (e) => {
    logger.info(e, "event: offer.rejected");

    onOfferRejected(e).catch((err) =>
      console.error("event handler failed: offer.rejected", err),
    );
  });

  bus.on("courier-coupon.created", (e) => {
    logger.info(e, "event: courier-coupon.created");

    onCourierCouponCreated(e).catch((err) =>
      console.error("event handler failed: courier-coupon.created", err),
    );
  });

  bus.on("courier-coupon.updated", (e) => {
    logger.info(e, "event: courier-coupon.updated");

    onCourierCouponUpdated(e).catch((err) =>
      console.error("event handler failed: courier-coupon.updated", err),
    );
  });

  bus.on("customer-coupon.created", (e) => {
    logger.info(e, "event: customer-coupon.created");

    onCustomerCouponCreated(e).catch((err) =>
      console.error("event handler failed: customer-coupon.created", err),
    );
  });

  bus.on("customer-coupon.updated", (e) => {
    logger.info(e, "event: customer-coupon.updated");

    onCustomerCouponUpdated(e).catch((err) =>
      console.error("event handler failed: customer-coupon.updated", err),
    );
  });

  bus.on("order.no_proposals", (e) => {
    logger.info(e, "event: order.no_proposals");
    onNoProposalOrders(e).catch((err) =>
      console.error("event handler failed: order.no_proposals", err),
    );
  });

  bus.on("order.expired", (e) => {
    logger.info(e, "event: order.expired");
    onOrderExpired(e).catch((err) =>
      console.error("event handler failed: order.expired", err),
    );
  });

  bus.on("order.issue.created", (e) => {
    logger.info(e, "event: order.issue.created");
    onOrderIssueCreated(e).catch((err) =>
      console.error("event handler failed: order.issue.created", err),
    );
  });

  bus.on("order:assingnedOrderAccepted", (e) => {
    logger.info(e, "event: order:assingnedOrderAccepted");
    getIo().on("order:assingnedOrderAccepted", (e) => {
      logger.info(e, "event: order:assingnedOrderAccepted");
    });
  });
  bus.on("refund.approved", (e) => {
    logger.info(e, "event: refund.approved");
    onRefundApproved(e).catch((err) =>
      console.error("event handler failed: refund.approved", err),
    );
  });
  bus.on("refund.rejected", (e) => {
    logger.info(e, "event: refund.rejected");
    onRefundRejected(e).catch((err) =>
      console.error("event handler failed: refund.rejected", err),
    );
  });
  bus.on("refund.requested", (e) => {
    logger.info(e, "event: refund.requested");
    onRefundRequested(e).catch((err) =>
      console.error("event handler failed: refund.requested", err),
    );
  });
}
