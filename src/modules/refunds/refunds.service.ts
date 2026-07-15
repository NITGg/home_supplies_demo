import { prisma } from "@/config/prisma";
import { HttpError } from "@/lib/httpError";
import type FeatureApi from "@/lib/featureApi";
import type { RequestRefundInput, ReviewRefundInput } from "./refunds.schema";
import { addToWallet, getPlatformWalletOrThrow } from "@/lib/walletHelper";
import { CouponScope, OrderRefundStatus } from "@prisma/client";
import { bus } from "@/events/bus";
import uploadImage from "@/lib/uploadImage";
import { executeCardRefund } from "@/lib/cardRefund";
import { logger } from "@/config/logger";

export async function requestRefundService(
  input: RequestRefundInput,
  customerId: number,
  files?:
    | { [fieldname: string]: Express.Multer.File[] }
    | Express.Multer.File[],
) {
  const result = await prisma.$transaction(async (tx) => {
    const order = await tx.order.findFirst({
      where: {
        id: input.order_id,
        customer_id: customerId,
        status: "DELIVERED",
        type: "CATALOG_PURCHASE",
      },
      include: {
        orderItems: { include: { product: true } },
      },
    });

    if (!order) throw new HttpError(400, "refunds:errors.order_not_eligible");

    const requestedItemIds = input.items.map((i) => i.order_item_id);
    const existingRefundItems = await tx.refundItem.findFirst({
      where: {
        order_item_id: { in: requestedItemIds },
        refund: { status: { in: ["REQUESTED", "APPROVED"] } },
      },
    });

    if (existingRefundItems) {
      throw new HttpError(
        400,
        "refunds:errors.item_already_refunded_or_pending",
      );
    }

    const totalOrderQuantity = order.orderItems.reduce(
      (sum, item) => sum + item.quantity,
      0,
    );
    const totalRefundQuantity = input.items.reduce(
      (sum, item) => sum + item.quantity,
      0,
    );

    const isFullRefund =
      input.items.length === order.orderItems.length &&
      totalOrderQuantity === totalRefundQuantity;

    let totalRefundAmount = 0;
    const now = new Date();
    const deliveredAt = order.delivered_at
      ? new Date(order.delivered_at)
      : null;

    const refundItemsData = input.items.map((item) => {
      const originalItem = order.orderItems.find(
        (oi) => oi.id === item.order_item_id,
      );
      if (!originalItem)
        throw new HttpError(404, "refunds:errors.item_not_found");

      if (originalItem.product.refundable === false) {
        throw new HttpError(400, "refunds:errors.product_not_refundable");
      }

      if (deliveredAt && originalItem.product.refundable_period) {
        const periodHours = Number(originalItem.product.refundable_period);
        const expiryDate = new Date(
          deliveredAt.getTime() + periodHours * 60 * 60 * 1000,
        );

        if (now > expiryDate) {
          throw new HttpError(400, "refunds:errors.refund_period_expired");
        }
      }

      if (item.quantity > originalItem.quantity) {
        throw new HttpError(400, "refunds:errors.invalid_quantity");
      }

      const itemAmount = Number(originalItem.unit_price) * item.quantity;
      totalRefundAmount += itemAmount;

      return {
        order_item_id: item.order_item_id,
        product_id: originalItem.product.id,
        quantity: item.quantity,
        amount: itemAmount,
      };
    });

    const imageFiles = Array.isArray(files)
      ? files
      : files?.["evidence_images"] || [];
    let evidenceImageUrls: string[] = [];
    if (imageFiles.length > 0) {
      evidenceImageUrls = await Promise.all(
        imageFiles.map((file) => uploadImage(file, "refunds")),
      );
    }

    const refund = await tx.refund.create({
      data: {
        order_id: input.order_id,
        amount: Math.floor(totalRefundAmount),
        reason: input.reason,
        status: "REQUESTED",
        is_full_refund: isFullRefund,
        evidence_images:
          evidenceImageUrls.length > 0 ? evidenceImageUrls.join(",") : null,
        requested_by_id: customerId,
        items: { create: refundItemsData },
      },
      include: { items: true },
    });

    return { order, refund };
  });

  bus.emit("refund.requested", {
    refundId: result.refund.id,
    orderId: result.order.id,
    orderNumber: result.order.order_number || "",
    customerId: customerId,
    amount: result.refund.amount,
    reason: result.refund.reason!,
    requestedAt: new Date(),
  });

  return result.refund;
}

export async function listRefundsService(data: FeatureApi["data"]) {
  const take = data.take ?? 10;
  const [totalRefunds, refunds] = await prisma.$transaction([
    prisma.refund.count({ where: data.where }),
    prisma.refund.findMany(data as any),
  ]);

  return {
    totalRefunds,
    totalPages: Math.ceil(totalRefunds / take),
    refunds,
  };
}

export async function getRefundByIdService(id: number, customerId?: number) {
  const refund = await prisma.refund.findFirst({
    where: { id, ...(customerId ? { requested_by_id: customerId } : {}) },
    include: { items: { include: { orderItem: true } }, order: true },
  });
  if (!refund) throw new HttpError(404, "refunds:errors.not_found");
  return refund;
}

export async function cancelRefundService(id: number, customerId: number) {
  const refund = await prisma.refund.findUnique({ where: { id } });
  if (!refund) throw new HttpError(404, "refunds:errors.not_found");
  if (refund.requested_by_id !== customerId)
    throw new HttpError(403, "errors.forbidden");
  if (refund.status !== "REQUESTED")
    throw new HttpError(400, "refunds:errors.cannot_cancel");

  return prisma.refund.update({
    where: { id },
    data: {
      status: "REJECTED",
      raw_response: "Cancelled by user",
    },
  });
}

// ─────────────────────────────────────────────────────────────────────────────

export async function processRefundReviewService(
  refundId: number,
  input: ReviewRefundInput,
  adminId: number,
) {
  const refund = await prisma.refund.findUnique({
    where: { id: refundId },
    include: {
      items: { include: { orderItem: true } },
      order: {
        include: {
          courier: { select: { user_id: true } },
          coupon: true,
          supplier: {
            select: {
              user_id: true,
            },
          },
        },
      },
    },
  });

  if (!refund) throw new HttpError(404, "refunds:errors.not_found");
  if (refund.status !== "REQUESTED")
    throw new HttpError(400, "refunds:errors.already_processed");

  const { order } = refund;
  const totalDeliveryFee = Number(order.total_fee || 0);
  const splitCourierFee = Number(order.courier_fee || 0);
  const platformDeliveryShare = totalDeliveryFee - splitCourierFee;

  const orderProductsTotal = Number(order.products_total || 0);
  const orderDiscountAmount = Number(order.discount_amount || 0);
  const orderPayableAmount = Number(order.payable_amount || 0);

  console.log(
    `\n🚀 [REFUND_REVIEW_START] ID: ${refundId} | Order: #${order.order_number} | Fault Target: ${input.fault_type}`,
  );

  // ── SCOPED COUPON MATH REASONING ─────────────────────────────────────────
  let itemDiscountFactor = 1;
  let deliveryDiscountFactor = 1;

  if (orderDiscountAmount > 0) {
    const scope: CouponScope = order.coupon?.scope ?? "ORDER_TOTAL";
    console.log(
      `🏷️  [COUPON_DETECTED] Scope: ${scope} | Discount Volume: ${orderDiscountAmount}`,
    );
    switch (scope) {
      case "PRODUCTS_ONLY":
        if (orderProductsTotal > 0) {
          itemDiscountFactor =
            (orderProductsTotal - orderDiscountAmount) / orderProductsTotal;
        }
        break;
      case "DELIVERY_FEE":
        if (totalDeliveryFee > 0) {
          deliveryDiscountFactor =
            (totalDeliveryFee - orderDiscountAmount) / totalDeliveryFee;
        }
        break;
      case "ORDER_TOTAL":
      default:
        const totalBeforeDiscount = orderProductsTotal + totalDeliveryFee;
        if (totalBeforeDiscount > 0) {
          const globalDiscountRatio = orderDiscountAmount / totalBeforeDiscount;
          itemDiscountFactor = 1 - globalDiscountRatio;
          deliveryDiscountFactor = 1 - globalDiscountRatio;
        }
        break;
    }
    console.log(
      `📊 [SCOPED_SCALING_FACTORS] Item Cost Multiplier: ${(itemDiscountFactor * 100).toFixed(2)}% | Delivery Cost Multiplier: ${(deliveryDiscountFactor * 100).toFixed(2)}%`,
    );
  }

  // ── CORE MATHEMATICS ───────────────────────────────────────────────────
  const rawCustomerRefund = Number(refund.amount);
  const customerBaseRefund = rawCustomerRefund * itemDiscountFactor;

  const totalSupplierCostPrice = refund.items.reduce((acc, item) => {
    const costPrice = Number(item.orderItem.cost_price || 0);
    return acc + costPrice * item.quantity;
  }, 0);

  const productMargin = customerBaseRefund - totalSupplierCostPrice;

  let finalCustomerCredit = customerBaseRefund;
  let finalFaultDebit = 0;
  let platformLoss = 0;
  let newRefundStatus: OrderRefundStatus = "PARTIALLY_REFUNDED";

  console.log(
    `📊 [CALC_PHASE] Base Unit Retail Price requested: ${rawCustomerRefund}`,
  );
  console.log(
    `📊 [CALC_PHASE] Scaled Customer Paid Out-Of-Pocket: ${customerBaseRefund.toFixed(2)}`,
  );
  console.log(
    `📊 [CALC_PHASE] Base Wholesale Cost Price: ${totalSupplierCostPrice}`,
  );
  console.log(
    `📊 [CALC_PHASE] Implicit Product Margin: ${productMargin.toFixed(2)}`,
  );
  console.log(
    `🚚 [DELIVERY_SPLIT] Total Delivery: ${totalDeliveryFee} | Courier Earns: ${splitCourierFee} | Platform Earns: ${platformDeliveryShare}`,
  );

  if (input.status === "APPROVED") {
    if (input.fault_type === "SUPPLIER") {
      finalFaultDebit = totalSupplierCostPrice;
      platformLoss = productMargin;
      console.log(
        `⚠️ [FAULT_SCENARIO] Supplier Fault. Platform loses markup of ${productMargin.toFixed(2)}.`,
      );

      if (refund.is_full_refund) {
        const adjustedPaidDelivery = totalDeliveryFee * deliveryDiscountFactor;
        finalCustomerCredit += adjustedPaidDelivery;
        finalFaultDebit += totalDeliveryFee;
        newRefundStatus = "FULLY_REFUNDED";
        console.log(
          `📦 [FULL_REFUND_TRIGGER] Supplier Fault Full. Adding scaled delivery back to customer (${adjustedPaidDelivery.toFixed(2)}) and raw fee penalty to Supplier (${totalDeliveryFee}).`,
        );
      }
    } else if (input.fault_type === "COURIER") {
      finalFaultDebit = customerBaseRefund;
      console.log(
        `⚠️ [FAULT_SCENARIO] Courier Fault. Platform retains product margin (${productMargin.toFixed(2)}). Supplier left untouched.`,
      );

      if (refund.is_full_refund) {
        const adjustedPaidDelivery = totalDeliveryFee * deliveryDiscountFactor;
        finalCustomerCredit += adjustedPaidDelivery;
        finalFaultDebit += splitCourierFee;
        platformLoss = platformDeliveryShare;
        newRefundStatus = "FULLY_REFUNDED";
        console.log(
          `🚚 [FULL_REFUND_TRIGGER] Courier Fault Full. Adding scaled delivery back to customer (${adjustedPaidDelivery.toFixed(2)}). Debiting courier fee slice (${splitCourierFee}).`,
        );
      }
    }

    const fineAmount = Number(input.penalty_amount || 0);
    finalFaultDebit += fineAmount;
    if (fineAmount > 0) {
      console.log(
        `➕ [EXTRA_PENALTY] Appending administrative charge: ${fineAmount} to the faulty party liability.`,
      );
    }
  } // <-- FIXED: Missing closing bracket added here for the APPROVED check

  let finalCustomerAmount = Math.floor(finalCustomerCredit);
  if (finalCustomerAmount > orderPayableAmount) {
    console.log(
      `🚨 [CRITICAL_OVERFLOW] Payout estimation (${finalCustomerAmount}) exceeded total cash paid at checkout (${orderPayableAmount}).`,
    );
    finalCustomerAmount = orderPayableAmount;
    console.log(
      `🚨 [CRITICAL_OVERFLOW] Hard ceiling applied. Customer payout forced to: ${finalCustomerAmount}`,
    );
  }

  const finalFaultAmount = Math.floor(finalFaultDebit);
  const finalPlatformDebit = Math.max(0, Math.floor(platformLoss));
  console.log(
    `✅ [FINAL_BALANCES_DETERMINED] Customer Payout: ${finalCustomerAmount} | Faulty Actor Deduct: ${finalFaultAmount} | Platform Loss: ${finalPlatformDebit}`,
  );

  // CARD orders: customer gets refunded via provider API (not wallet).
  // Set initial status to PROCESSING; we'll move to COMPLETED/FAILED after the API call.
  const isCardOrder = order.payment_method === "CARD";
  const inTxStatus =
    input.status === "APPROVED" && isCardOrder ? "PROCESSING" : input.status;

  // Execute structural updates inside transaction context
  const updatedRefund = await prisma.$transaction(async (tx) => {
    const reviewResult = await tx.refund.update({
      where: { id: refundId },
      data: {
        status: inTxStatus,
        raw_response: input.admin_notes,
        reviewed_by_id: adminId,
        reviewed_at: new Date(),
        amount: finalCustomerAmount,
      },
    });

    if (input.status === "APPROVED") {
      const [customerWallet, faultWallet, platformWallet] = await Promise.all([
        // CARD: no customer wallet lookup needed — refund goes back to card
        isCardOrder
          ? Promise.resolve(null)
          : tx.wallet.findUnique({ where: { user_id: order.customer_id! } }),
        input.fault_type === "SUPPLIER"
          ? tx.wallet.findUnique({
              where: { user_id: order.supplier?.user_id! },
            })
          : tx.wallet.findUnique({
              where: { user_id: order.courier?.user_id },
            }),
        getPlatformWalletOrThrow(tx),
      ]);

      if (!isCardOrder && customerWallet && finalCustomerAmount > 0) {
        console.log(
          `💳 [CUSTOMER_WALLET] ID: ${customerWallet.id} | Balance Before: ${customerWallet.balance}`,
        );
        await addToWallet(tx, order.customer_id!, {
          target: "BALANCE",
          amount: finalCustomerAmount,
          type: "ESCROW_RELEASE",
          status: "COMPLETED",
          orderId: order.id,
          processedBy: adminId,
          description: `Approved proportional coupon-adjusted refund for Order #${order.order_number}`,
        });
        console.log(`✨ [CUSTOMER_SUCCESS] Refund successfully credited.`);
      }

      if (isCardOrder && finalCustomerAmount > 0) {
        console.log(
          `💳 [CARD_REFUND] Order #${order.order_number} | Amount: ${finalCustomerAmount} piastres → provider API`,
        );
      }

      if (finalPlatformDebit > 0) {
        console.log(
          `🏢 [PLATFORM_WALLET] ID: ${platformWallet.id} | Balance Before: ${platformWallet.balance}`,
        );
        await addToWallet(tx, platformWallet.user_id!, {
          target: "BALANCE",
          amount: -finalPlatformDebit,
          type: "MANUAL_DECREASE",
          status: "COMPLETED",
          orderId: order.id,
          processedBy: adminId,
          description: `Platform adjusted loss tracking for ${input.fault_type} error on Order #${order.order_number}`,
        });
        console.log(
          `✨ [PLATFORM_SUCCESS] Loss of -${finalPlatformDebit} logged against platform capital.`,
        );
        console.log(platformWallet);
      } else {
        console.log(
          `🏢 [PLATFORM_WALLET] Platform skipped from loss pool for this transaction payload.`,
        );
      }

      // Execute Faulty Party Debit Ledger adjustments
      if (faultWallet && finalFaultAmount > 0) {
        const currentFaultBalance = Number(faultWallet.balance);
        let walletDebit = finalFaultAmount;
        console.log(
          `🛡️  [FAULT_ACTOR_WALLET] User: ${faultWallet.user_id} (${input.fault_type}) | Balance Before: ${currentFaultBalance}`,
        );

        if (currentFaultBalance < finalFaultAmount) {
          const penaltyAmount = finalFaultAmount - currentFaultBalance;
          walletDebit = Math.max(currentFaultBalance, 0);

          console.log(
            `🔴 [INSUFFICIENT_FUNDS] Balance insufficient. Transferring ${penaltyAmount} to system Penalties structure.`,
          );

          if (penaltyAmount > 0) {
            const penalty = await tx.penalty.create({
              data: {
                user_id: faultWallet.user_id,
                amount: penaltyAmount,
                reason: `Unpaid coupon-adjusted refund liability for Order #${order.order_number} (Total Due: ${finalFaultAmount})`,
                created_by: adminId,
              },
            });
            console.log(
              `📝 [PENALTY_RECORDED] Saved Penalty Item ID: ${penalty.id} with value ${penaltyAmount}`,
            );
          }
        }

        if (walletDebit > 0) {
          console.log(
            `💸 [DEBIT_ACTION] Debiting safe liquid value of -${walletDebit} from user account balance.`,
          );
          await addToWallet(tx, faultWallet.user_id!, {
            target: "BALANCE",
            amount: -walletDebit,
            type: "MANUAL_DECREASE",
            status: "COMPLETED",
            orderId: order.id,
            processedBy: adminId,
          });

          await tx.wallet.update({
            where: { id: faultWallet.id },
            data:
              input.fault_type === "SUPPLIER"
                ? { supplier_earnings: { decrement: walletDebit } }
                : { courier_earnings: { decrement: walletDebit } },
          });
          console.log(`✨ [DEBIT_SUCCESS] Target ledger sync finalized.`);
          console.log(faultWallet);
        } else {
          console.log(
            `ℹ️  [DEBIT_SKIPPED] Account balance empty or underwater. No current capital extracted.`,
          );
        }
      }

      await tx.order.update({
        where: { id: order.id },
        data: { refund_status: newRefundStatus },
      });
      console.log(`🚚 [ORDER_REFUND_STATUS_SYNCED]: ${newRefundStatus}`);
      console.log(`🏁 [REFUND_REVIEW_COMPLETE] ID: ${refundId}\n`);
    } else {
      console.log(
        `❌ [REFUND_DECLINED] Process skipped. Evaluation state parsed as: ${input.status}`,
      );
    }
    return reviewResult;
  });

  // ── CARD: call provider refund API (outside DB tx — external HTTP call) ───
  // Fault actor wallet debits already committed. Now reverse the card charge.
  if (input.status === "APPROVED" && isCardOrder && finalCustomerAmount > 0) {
    try {
      logger.info(
        { refundId, orderId: order.id, amountCents: finalCustomerAmount },
        "[CARD_REFUND] Calling provider refund API",
      );

      const providerResult = await executeCardRefund(
        order.id,
        finalCustomerAmount,
        refund.reason ?? undefined,
      );

      await prisma.refund.update({
        where: { id: refundId },
        data: {
          status: "COMPLETED",
          provider: providerResult.provider,
          provider_refund_id: providerResult.refundId,
          // TODO: create new field for provider response metadata instead of dumping into raw_response
          // raw_response: JSON.stringify(providerResult.raw),
        },
      });

      logger.info(
        {
          refundId,
          provider: providerResult.provider,
          providerRefundId: providerResult.refundId,
        },
        "[CARD_REFUND] Provider refund succeeded",
      );
    } catch (err: any) {
      // EasyKash has no refund API — leave as PROCESSING for manual handling.
      const isEasykashNoApi = err?.message?.includes("easykash_no_refund_api");

      await prisma.refund.update({
        where: { id: refundId },
        data: {
          status: isEasykashNoApi ? "PROCESSING" : "FAILED",
          raw_response: isEasykashNoApi
            ? "EasyKash does not support API refunds. Please process manually via the EasyKash dashboard."
            : (err?.message?.slice?.(0, 1000) ?? "Provider refund API failed"),
        },
      });

      logger.error(
        { refundId, orderId: order.id, err: err?.message, isEasykashNoApi },
        "[CARD_REFUND] Provider refund API failed — refund marked FAILED/PROCESSING",
      );

      // EasyKash: no API → silently leave as PROCESSING (admin handles manually)
      if (!isEasykashNoApi) {
        throw new HttpError(502, "refunds:errors.card_refund_provider_failed");
      }
    }
  }

  // ── DYNAMIC DISPATCH LIFECYCLE EVENTS ──────────────────────────────────
  let faultyUserId: number | null = null;
  if (input.status === "APPROVED") {
    faultyUserId =
      input.fault_type === "SUPPLIER"
        ? order.supplier?.user_id!
        : order.courier?.user_id || null;
  }

  if (input.status === "APPROVED") {
    bus.emit("refund.approved", {
      refundId: updatedRefund.id,
      orderId: order.id,
      orderNumber: order.order_number,
      customerId: order.customer_id!,
      faultType: input.fault_type as "SUPPLIER" | "COURIER",
      faultyUserId,
      amountRefunded: updatedRefund.amount,
      reviewedByAdminId: adminId,
      reviewedAt: new Date(),
    });
  } else if (input.status === "REJECTED") {
    bus.emit("refund.rejected", {
      refundId: updatedRefund.id,
      orderId: order.id,
      orderNumber: order.order_number,
      customerId: order.customer_id!,
      adminNotes: input.admin_notes,
      reviewedByAdminId: adminId,
      reviewedAt: new Date(),
    });
  }

  return updatedRefund;
}
