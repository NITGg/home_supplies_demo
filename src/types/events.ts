import { CouponScope, OrderType, Prisma, Product } from "@prisma/client";
import { AdminUser } from "./authedRequest";

export type AppEvents = {
  "order.delivered": {
    orderId: number;
    customerId?: number;
    externalAppId?: number;
    courierId: number;

    actualPriceCents: Prisma.Decimal;
    totalFeeCents: Prisma.Decimal;
    courierFeeCents: Prisma.Decimal;
    platformFeeCents: Prisma.Decimal;
    partnerFeeCents?: Prisma.Decimal;
    paymentAmountCents: Prisma.Decimal;
    paymentMethod: "WALLET" | "CASH" | "CARD";
    discountCents: number;
    type: OrderType;
    supplierId?: number;
    deliveredAt: Date;
    coupon_type?: CouponScope;
  };

  "order.status.changed": {
    orderId: number;
    from: string;
    to: string;
    at: Date;
    byUserId: number;
  };

  "order.created": {
    orderId: number;
    customerId?: number;
    createdAt: string;
    deliveryAreaId: number;
    pickupAreaId: number;
    budget: number;
    vehicleIds: number[];
    distanceM: number;
    proposalsDeadline: string;
    expiresAt: string;
    targetCourierId?: number; // for manual assign, otherwise null
    mode?: "FIXED_FEE";
    total_fee?: number; // only for FIXED_FEE mode, otherwise null
    type: OrderType;
    supplierId?: number;
    isFixedFee?: boolean;
    pickupLat: number;
    pickupLng: number;
    // add scheduled time
    isScheduled?: boolean;
    externalAppId?: number;
    // add order delivery date and time
    is_order_scheduled?: boolean;
    order_schedule_at?: Date;
    supplier_store_address_id?: number;
  };

  "order.cancelled": {
    orderId: number;
    customerId?: number;
    externalAppId?: number;
    courierId?: number | null; // might be null if not assigned yet
    pickupAreaId: number;
    cancelledAt: string;
    type: OrderType;
    supplierId?: number;
  };

  "offer.accepted": {
    orderId: number;
    offerId: number;
    courierId: number;
    customerId: number;
    pickupAreaId: number;
    acceptedAt: string;
  };

  "offer.rejected": {
    orderId: number;
    offerId: number;
    courierId: number;
    customerId: number;
    rejectedAt: string;
  };

  "order.no_proposals": {
    orderId: number;
    detectedAt: string;
    customerId: number | null;
    externalAppId: number | null;
  };

  "order.expired": {
    orderId: number;
    expiredAt: string;
    customerId: number | null;
    externalAppId: number | null;
    pickupAreaId: number;
  };
  "courier-coupon.created": {
    couponId: number;
    title: string;
    titleAr: string | null;
    price: Prisma.Decimal;
    bonusCourierFee: Prisma.Decimal;
    durationDays: number;
    isActive: boolean;
    createdByUserId: number;
    createdAt: Date;
  };

  "courier-coupon.updated": {
    couponId: number;
    title: string;
    titleAr: string | null;
    price: Prisma.Decimal;
    bonusCourierFee: Prisma.Decimal;
    durationDays: number;
    isActive: boolean;
    updatedByUserId: number;
    updatedAt: Date;
  };

  "customer-coupon.created": {
    couponId: number;
    code: string;
    title: string;
    titleAr: string | null;
    type: "ORDER_DISCOUNT" | "WALLET_CREDIT";
    isActive: boolean;
    createdByUserId: number;
    createdAt: Date;
  };

  "customer-coupon.updated": {
    couponId: number;
    code: string;
    title: string;
    titleAr: string | null;
    type: "ORDER_DISCOUNT" | "WALLET_CREDIT";
    isActive: boolean;
    updatedByUserId: number;
    updatedAt: Date;
  };

  "order.issue.created": {
    orderId: number;
    customerId: number;
    courierId: number;
    issueId: number;
    reason: string;
    description?: string;
    createdAt: Date;
  };
  "order.issue.resolved": {
    orderId: number;
    issueId: number;
    status: "RESOLVED" | "DISMISSED";
    resolutionNote?: string;
    resolvedAt: Date;
  };

  syncProduct: {
    action: "create" | "update";
    product: Product;
    admin: AdminUser;
  };

  "order:assingnedOrderAccepted": {
    orderId: number;
  };

  "order.scheduled_activated": {
    orderId: number;
    activatedAt: Date;
  };

  "refund.requested": {
    refundId: number;
    orderId: number;
    orderNumber: string;
    customerId: number;
    amount: number;
    reason: string;
    requestedAt: Date;
  };

  "refund.approved": {
    refundId: number;
    orderId: number;
    orderNumber: string;
    customerId: number;
    faultType: "SUPPLIER" | "COURIER";
    faultyUserId?: number | null; // The supplier or courier penalized
    amountRefunded: number;
    reviewedByAdminId: number;
    reviewedAt: Date;
  };

  "refund.rejected": {
    refundId: number;
    orderId: number;
    orderNumber: string;
    customerId: number;
    adminNotes?: string | null;
    reviewedByAdminId: number;
    reviewedAt: Date;
  };
};
