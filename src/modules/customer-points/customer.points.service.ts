import { NextFunction, Request, Response } from "express";
import { prisma } from "@/config/prisma";
import { adjustWalletBalance } from "@/lib/adjustWalletBalance";
import { PayFinesDTO, PayFinesUsingPointsDTO } from "./customer.points.dto";

export class CustomerPointsService {
  constructor() {}

  // ============================ rules ============================
  rules = async (req: Request, res: Response, next: NextFunction) => {
    // step: get application settings
    const settings = await prisma.applicationSetting.findFirst();
    if (!settings) {
      return res.status(404).json({
        message: req.t("settings:errors.not_found"),
      });
    }

    const cashbackPct =
      settings.customer_points_cashback_percentage_per_orders_batch;
    const requiredOrders =
      settings.customer_number_of_delivered_orders_required_per_reward_batch;
    const pointsPerEgp = settings.customer_number_of_points_required_per_1egp;
    const validityDays = settings.customer_points_validity_days;
    const minRating = settings.customer_points_minimum_rating_threshold;

    const rules = {
      orders_reward: `Earn ${cashbackPct}% cashback as points on each successful order placed with a supplier (rating ≥ ${minRating}). Complete ${requiredOrders} successful orders in a row to unlock the batch and transfer points to your wallet. A low-rated order (rating < ${minRating}) breaks the chain and expires the current batch. Orders without a supplier do not earn points.`,
      points_value: `Every ${pointsPerEgp} points = 1 EGP`,
      expiration: `Each batch expires after ${validityDays} days`,
      redemption:
        "Redeem points to buy coupons, pay commissions, or cover penalties",
    };

    const rules_ar = {
      orders_reward: `احصل على ${cashbackPct}% كاشباك كنقاط على كل طلب ناجح من مورد (تقييم ≥ ${minRating}). أكمل ${requiredOrders} طلبات ناجحة متتالية لفتح الدفعة وتحويل النقاط لمحفظتك. الطلب منخفض التقييم (أقل من ${minRating}) يكسر السلسلة وينهي الدفعة الحالية. الطلبات بدون مورد لا تكسب نقاطًا.`,
      points_value: `كل ${pointsPerEgp} نقاط = 1 جنيه`,
      expiration: `تنتهي صلاحية كل دفعة بعد ${validityDays} يومًا`,
      redemption:
        "يمكنك استخدام النقاط لشراء كوبونات أو سداد العمولات أو تغطية الغرامات",
    };

    return res.status(200).json({
      message: req.t("points:messages.points_retrieved"),
      data: { rules, rules_ar },
    });
  };

  // ============================ progress ============================
  progress = async (req: Request, res: Response, next: NextFunction) => {
    const user = req.user;
    if (!user) {
      return res.status(401).json({
        message: req.t("auth:errors.unauthorized"),
      });
    }

    // step: get application settings
    const settings = await prisma.applicationSetting.findFirst();
    if (!settings) {
      return res.status(404).json({
        message: req.t("settings:errors.not_found"),
      });
    }

    // step: get user wallet to determine user type
    const wallet = await prisma.wallet.findUnique({
      where: { user_id: user.id },
    });
    const isCourier = wallet?.owner_type === "COURIER";

    // step: dynamic model and settings based on user type
    const batchModel = isCourier
      ? prisma.courierPointBatch
      : prisma.customerPointBatch;
    const validityDays = isCourier
      ? Number(settings.courier_points_validity_days)
      : Number(settings.customer_points_validity_days);
    const requiredOrders = isCourier
      ? Number(
          settings.courier_number_of_delivered_orders_required_per_reward_batch,
        )
      : Number(
          settings.customer_number_of_delivered_orders_required_per_reward_batch,
        );

    // step: get batches
    let availablePointBatch: any[] = [];
    let pendingPointBatch: any[] = [];

    // step: get available PointBatch
    availablePointBatch = await (batchModel as any).findMany({
      where: {
        user_id: user.id,
        is_expired: false,
        deleted_at: null,
        NOT: { all_points_collected_at: null },
      },
      orderBy: {
        created_at: "desc",
      },
    });

    // step: get pending PointBatch
    pendingPointBatch = await (batchModel as any).findMany({
      where: {
        user_id: user.id,
        is_expired: false,
        deleted_at: null,
        all_points_collected_at: null,
      },
      orderBy: {
        created_at: "desc",
      },
    });

    // step: get pending batch (the active one being filled)
    const pendingBatch =
      pendingPointBatch.length > 0 ? pendingPointBatch[0] : null;

    // step: build ordersProgress from pending batch
    const ordersCompletedInCurrentBatch =
      pendingBatch?.successful_orders_count || 0;
    const percentComplete = Math.round(
      (ordersCompletedInCurrentBatch / requiredOrders) * 100,
    );

    // step: build allExpirations from available batches
    const now = new Date();
    const allExpirations = availablePointBatch
      .filter((batch: any) => (batch.balance || 0) > 0)
      .map((batch: any) => {
        const computedExpiry = new Date(batch.created_at);
        computedExpiry.setDate(computedExpiry.getDate() + validityDays);
        return {
          batchId: batch.id,
          points: batch.balance || 0,
          expiryDate: computedExpiry.toISOString().split("T")[0],
          daysLeft: Math.max(
            0,
            Math.ceil(
              (computedExpiry.getTime() - now.getTime()) /
                (1000 * 60 * 60 * 24),
            ),
          ),
        };
      });

    // step: build availableBatches (raw batch objects)
    const availableBatches = availablePointBatch.map((batch: any) => batch);

    return res.status(200).json({
      message: req.t("points:messages.points_progress_retrieved"),
      data: {
        ordersProgress: {
          ordersCompletedInCurrentBatch,
          requiredOrdersForNextBatch: requiredOrders,
          percentComplete,
        },
        pendingBatch: pendingBatch || null,
        allExpirations,
        availableBatches,
      },
    });
  };

  // ============================ givePointsToCourier ============================
  givePointsToCourier = async (
    req: Request,
    res: Response,
    next: NextFunction,
  ) => {
    // ============================================================================
    // TODO: PROPOSED POINT MANAGEMENT SYSTEM LOGIC (FOR REVIEW)
    // ============================================================================
    //
    // SYSTEM OVERVIEW:
    // A courier must complete [requiredOrders] consecutive successful orders to earn [batchPoints] points.
    // An order is successful if its rating is >= [minRating].
    // Each successful order adds partial points (batchPoints / requiredOrders) to the batch's balance.
    // If an order fails (rating < minRating), the chain breaks, and the batch expires.
    //
    // BATCH COMPLETION RULE:
    // A batch is completed when successful_orders_count >= requiredOrders.
    // NOTE: fixed_batch_point_amount is NOT used for batch completion.
    // The batch unlock condition is order-count-based, NOT point-balance-based.
    //
    // STEP 1: CALCULATE POINTS PER ORDER
    // pointsPerOrder = Math.floor(batchPoints / requiredOrders)
    //
    // STEP 2: CHECK ORDER RATING
    // if (rating < minRating) {
    //   -> The chain is broken.
    //   -> Get the last active courierPointBatch (where all_points_collected_at is null AND is_expired is false)
    //   -> Update this batch to { is_expired: true }
    //   -> End process (no points awarded).
    // }
    //
    // STEP 3: SUCCESSFUL ORDER - HANDLE BATCH
    // Get the last courierPointBatch for this user (ordered by created_at DESC).
    //
    // CASE A: No active batch exists (last batch is collected, expired, or doesn't exist)
    // -> Create a NEW courierPointBatch
    //    {
    //      user_id: userId,
    //      successful_orders_count: 1,
    //      balance: pointsPerOrder, // The first order's worth of points
    //      is_expired: false,
    //      all_points_collected_at: null,
    //      expired_at: NOW + validityDays // Expiration period
    //    }
    //
    // CASE B: An active batch exists
    // -> Update the existing courierPointBatch
    //    {
    //      balance: { increment: pointsPerOrder },
    //      successful_orders_count: { increment: 1 }
    //    }

    const { userId } = req.params;

    // step: get user
    const user = await prisma.user.findUnique({
      where: { id: Number(userId) },
    });
    if (!user) {
      return res.status(404).json({
        message: req.t("users:errors.user_not_found"),
      });
    }

    // step: get courier
    const courier = await prisma.courier.findUnique({
      where: { user_id: Number(userId) },
    });
    if (!courier) {
      return res.status(404).json({
        message: req.t("users:errors.user_not_found"),
      });
    }

    // step: get applicationSetting
    const settings = await prisma.applicationSetting.findFirst();
    if (!settings) {
      return res.status(404).json({
        message: req.t("settings:errors.not_found"),
      });
    }
    const var1 = settings.courier_number_of_points_required_per_1egp;
    const var2 =
      settings.courier_number_of_delivered_orders_required_per_reward_batch;
    const var3 =
      settings.courier_number_of_points_awarded_per_completed_order_batch;
    const var4 = settings.courier_points_validity_days;
    const var5 = settings.courier_points_minimum_rating_threshold;
    const var6 = settings.courier_points_expiration_notification_days;

    const minRating = Number(settings.courier_points_minimum_rating_threshold);
    const requiredOrders = Number(
      settings.courier_number_of_delivered_orders_required_per_reward_batch,
    );
    const batchPoints = Number(
      settings.courier_number_of_points_awarded_per_completed_order_batch,
    );
    const validityDays = Number(settings.courier_points_validity_days);

    // STEP 1: CALCULATE POINTS PER ORDER
    const pointsPerOrder = Math.floor(batchPoints / requiredOrders);

    // Find the last processed order ID using aggregate (efficient with index)
    const lastOrderResult = await prisma.courierPointBatch.aggregate({
      where: { user_id: Number(userId) },
      _max: { last_order_id_collect_points: true },
    });
    const lastOrderId = lastOrderResult._max.last_order_id_collect_points || 0;

    // Find all unprocessed delivered orders (outside transaction)
    const unprocessedOrders = await prisma.order.findMany({
      where: {
        courier_id: courier.id,
        status: "DELIVERED",
        id: { gt: lastOrderId },
      },
      orderBy: { id: "asc" },
    });

    if (unprocessedOrders.length === 0) {
      return res.status(200).json({
        message: req.t("points:messages.no_unprocessed_orders", {
          defaultValue: "No new completed orders found to process points.",
        }),
        data: { status: "no_unprocessed_orders" },
      });
    }

    // Process orders in chunks to avoid transaction timeout
    const CHUNK_SIZE = 5;
    let processedCount = 0;

    for (let i = 0; i < unprocessedOrders.length; i += CHUNK_SIZE) {
      const chunk = unprocessedOrders.slice(i, i + CHUNK_SIZE);

      await prisma.$transaction(
        async (tx) => {
          for (const order of chunk) {
            // Fetch the rating from the DB for this order
            let rating = 0; // Default to 0 if no review is found
            const review = await tx.courierReviewFromCustomer.findFirst({
              where: {
                courier_id: courier.id,
                order_id: order.id,
              },
            });
            if (review) {
              rating = review.rating;
            }

            // STEP 2: CHECK ORDER RATING
            if (rating < minRating) {
              // The chain is broken.
              // Get the last active courierPointBatch
              const lastActiveBatch = await tx.courierPointBatch.findFirst({
                where: {
                  user_id: Number(userId),
                  deleted_at: null,
                  all_points_collected_at: null,
                  is_expired: false,
                },
                orderBy: { created_at: "desc" },
              });

              if (lastActiveBatch) {
                await tx.courierPointBatch.update({
                  where: { id: lastActiveBatch.id },
                  data: {
                    is_expired: true,
                    last_order_id_collect_points: order.id,
                  },
                });
                console.log(
                  `[givePointsToCourier] Expired batch ${lastActiveBatch.id} for courier ${userId} — rating ${rating} < min ${minRating}`,
                );
              } else {
                // Must advance the pointer even if no active batch exists
                const anyLastBatch = await tx.courierPointBatch.findFirst({
                  where: { user_id: Number(userId), deleted_at: null },
                  orderBy: { created_at: "desc" },
                });

                if (anyLastBatch) {
                  await tx.courierPointBatch.update({
                    where: { id: anyLastBatch.id },
                    data: { last_order_id_collect_points: order.id },
                  });
                } else {
                  // Create a dummy expired batch just to hold the pointer
                  await tx.courierPointBatch.create({
                    data: {
                      user_id: Number(userId),
                      successful_orders_count: 0,
                      balance: 0,
                      is_expired: true,
                      last_order_id_collect_points: order.id,
                    },
                  });
                }
              }
              continue; // Move to the next order
            }

            // STEP 3: SUCCESSFUL ORDER - HANDLE BATCH
            // Get the last courierPointBatch for this user
            const lastBatch = await tx.courierPointBatch.findFirst({
              where: { user_id: Number(userId), deleted_at: null },
              orderBy: { created_at: "desc" },
            });

            const hasActiveBatch =
              lastBatch &&
              !lastBatch.is_expired &&
              lastBatch.all_points_collected_at === null;

            if (!hasActiveBatch) {
              // CASE A: No active batch exists
              const expiredAt = new Date();
              expiredAt.setDate(expiredAt.getDate() + validityDays);

              const newBatch = await tx.courierPointBatch.create({
                data: {
                  user_id: Number(userId),
                  successful_orders_count: 1,
                  balance: pointsPerOrder, // The first order's worth of points
                  is_expired: false,
                  expired_at: expiredAt,
                  last_order_id_collect_points: order.id,
                },
              });
              console.log(
                `[givePointsToCourier] Created new batch ${newBatch.id} for courier ${userId}: orders 1/${requiredOrders}, balance ${pointsPerOrder}`,
              );

              // Check completion immediately (in case var2 = 1)
              await completeCourierBatchIfReady(
                tx,
                newBatch.id,
                Number(userId),
                settings,
              );
            } else {
              // CASE B: An active batch exists
              const newBalance = (lastBatch.balance ?? 0) + pointsPerOrder;
              const newOrderCount =
                (lastBatch.successful_orders_count ?? 0) + 1;

              await tx.courierPointBatch.update({
                where: { id: lastBatch.id },
                data: {
                  balance: newBalance,
                  successful_orders_count: newOrderCount,
                  last_order_id_collect_points: order.id,
                },
              });
              console.log(
                `[givePointsToCourier] Updated batch ${lastBatch.id} for courier ${userId}: orders ${newOrderCount}/${requiredOrders}, balance ${lastBatch.balance} → ${newBalance}`,
              );

              // STEP 4: CHECK BATCH COMPLETION
              await completeCourierBatchIfReady(
                tx,
                lastBatch.id,
                Number(userId),
                settings,
              );
            }
          }
        },
        { timeout: 30000 }, // 30 second timeout per chunk
      );

      processedCount += chunk.length;
    }

    // step: send response
    return res.status(200).json({
      message: req.t("points:messages.points_processed_successfully", {
        defaultValue: "Points processed successfully for recent orders.",
      }),
      data: {
        status: "success",
        processedOrders: processedCount,
      },
    });
  };

  // ============================ givePointsToCustomer ============================
  givePointsToCustomer = async (
    req: Request,
    res: Response,
    next: NextFunction,
  ) => {
    // ============================================================================
    // TODO: PROPOSED CUSTOMER POINT MANAGEMENT SYSTEM LOGIC (FOR REVIEW)
    // ============================================================================
    //
    // SYSTEM OVERVIEW:
    // A customer must complete successful orders to earn points.
    // Points are only awarded for orders that have a supplier (order.supplier_id is not null).
    // Orders without a supplier are skipped — they advance the pointer but earn no points.
    // An order is successful if its rating is >= [customer_points_minimum_rating_threshold].
    // If an order fails (rating < min_threshold), the chain breaks, and the batch expires.
    // Unlike couriers who earn a fixed amount per batch, customers earn points as cashback
    // based on the total cost of each successful order.
    //
    // BATCH COMPLETION RULE:
    // A batch is completed when the count of successful orders in the batch reaches
    // [customer_number_of_delivered_orders_required_per_reward_batch] from ApplicationSetting.
    // NOTE: fixed_batch_point_amount in CustomerPointBatch is NOT used for batch completion.
    // It is only stored as a snapshot. The batch unlock condition is order-count-based,
    // NOT point-balance-based.
    //
    // STEP 1: FIND UNPROCESSED ORDERS
    // Find the last processed order ID from `customerPointBatch.last_order_id_collect_points`.
    // Fetch all delivered orders for the customer with ID > last processed order ID.
    //
    // STEP 2: LOOP THROUGH UNPROCESSED ORDERS
    // For each order:
    //   a. Check if order.supplier_id is null.
    //      - If YES (no supplier): Skip this order. Advance the pointer only.
    //        No points awarded, no batch impact. Continue to next order.
    //   b. Fetch the order rating.
    //   c. Check if rating < minRating.
    //      - If YES (broken chain): Expire the active customerPointBatch (is_expired: true).
    //        Update last_order_id_collect_points. Continue to next order.
    //      - If NO (successful order):
    //        - Calculate cashback points for this specific order:
    //          cashBackAsEGP = orderTotalValue * (cashbackPct / 100)
    //          cashBackAsPoints = Math.floor(cashBackAsEGP * pointsPerEgp)
    //
    //        - Handle Batch:
    //          - CASE A: No active batch exists
    //            -> Create a NEW customerPointBatch
    //               {
    //                 user_id: Number(userId),
    //                 fixed_batch_point_amount: null, // NOT used for batch completion
    //                 balance: cashBackAsPoints,
    //                 successful_orders_count: 1,
    //                 is_expired: false,
    //                 all_points_collected_at: null,
    //                 expired_at: NOW + validityDays,
    //                 last_order_id_collect_points: order.id
    //               }
    //
    //          - CASE B: An active batch exists
    //            -> Update the existing customerPointBatch
    //               {
    //                 balance: { increment: cashBackAsPoints },
    //                 successful_orders_count: { increment: 1 },
    //                 last_order_id_collect_points: order.id
    //               }
    //
    //        - Check Batch Completion:
    //          If successful_orders_count >= customer_number_of_delivered_orders_required_per_reward_batch,
    //          mark the batch as completed and process the wallet update.
    //
    // ============================================================================

    // step: get user
    const { userId } = req.params;

    const user = await prisma.user.findUnique({
      where: { id: Number(userId) },
    });
    if (!user) {
      return res.status(404).json({
        message: req.t("users:errors.user_not_found"),
      });
    }
    // step: check user is customer
    const userRole = await prisma.userRole.findFirst({
      where: { name: "CUSTOMER" },
    });
    if (!userRole) {
      return res.status(404).json({
        message: req.t("users:errors.role_not_found"),
      });
    }
    if (userRole.id != user.role_id) {
      return res.status(404).json({
        message: req.t("users:errors.invalid_role"),
      });
    }

    // step: get application settings
    const settings = await prisma.applicationSetting.findFirst();
    if (!settings) {
      return res.status(404).json({
        message: req.t("settings:errors.not_found"),
      });
    }

    const minRating = Number(settings.customer_points_minimum_rating_threshold);
    const requiredOrders = Number(
      settings.customer_number_of_delivered_orders_required_per_reward_batch,
    );
    const cashbackPct = Number(
      settings.customer_points_cashback_percentage_per_orders_batch,
    );
    const pointsPerEgp = Number(
      settings.customer_number_of_points_required_per_1egp,
    );
    const validityDays = Number(settings.customer_points_validity_days);

    // Find the last processed order ID using aggregate (efficient with index)
    const lastOrderResult = await prisma.customerPointBatch.aggregate({
      where: { user_id: Number(userId) },
      _max: { last_order_id_collect_points: true },
    });
    const lastOrderId = lastOrderResult._max.last_order_id_collect_points || 0;

    // Find all unprocessed delivered orders (outside transaction)
    const unprocessedOrders = await prisma.order.findMany({
      where: {
        customer_id: Number(userId),
        status: "DELIVERED",
        id: { gt: lastOrderId },
      },
      orderBy: { id: "asc" },
    });

    if (unprocessedOrders.length === 0) {
      return res.status(200).json({
        message: req.t("points:messages.no_unprocessed_orders", {
          defaultValue: "No new completed orders found to process points.",
        }),
        data: { status: "no_unprocessed_orders" },
      });
    }

    // Process orders in chunks to avoid transaction timeout
    const CHUNK_SIZE = 5;
    let processedCount = 0;
    let supplierOrderCount = 0;
    let nonSupplierOrderCount = 0;

    for (let i = 0; i < unprocessedOrders.length; i += CHUNK_SIZE) {
      const chunk = unprocessedOrders.slice(i, i + CHUNK_SIZE);

      await prisma.$transaction(
        async (tx) => {
          for (const order of chunk) {
            // STEP 2a: CHECK IF ORDER HAS A SUPPLIER
            if (!order.supplier_id) {
              console.log(
                `[givePointsToCustomer] Order ${order.id} has no supplier — skipping (no points).`,
              );
              // Advance the pointer only, no points or batch impact
              const anyLastBatch = await tx.customerPointBatch.findFirst({
                where: { user_id: Number(userId), deleted_at: null },
                orderBy: { created_at: "desc" },
              });

              if (anyLastBatch) {
                await tx.customerPointBatch.update({
                  where: { id: anyLastBatch.id },
                  data: { last_order_id_collect_points: order.id },
                });
              } else {
                await tx.customerPointBatch.create({
                  data: {
                    user_id: Number(userId),
                    successful_orders_count: 0,
                    balance: 0,
                    is_expired: true,
                    last_order_id_collect_points: order.id,
                  },
                });
              }
              continue;
            }

            // Fetch the rating from the DB for this order
            let rating = 0; // Default to 0 if no review is found
            const review = await tx.customerReviewFromCourier.findFirst({
              where: {
                customer_id: Number(userId),
                order_id: order.id,
              },
            });
            if (review) {
              rating = review.rating;
            }

            // STEP 2: CHECK ORDER RATING
            if (rating < minRating) {
              // The chain is broken.
              // Get the last active customerPointBatch
              const lastActiveBatch = await tx.customerPointBatch.findFirst({
                where: {
                  user_id: Number(userId),
                  deleted_at: null,
                  all_points_collected_at: null,
                  is_expired: false,
                },
                orderBy: { created_at: "desc" },
              });

              if (lastActiveBatch) {
                await tx.customerPointBatch.update({
                  where: { id: lastActiveBatch.id },
                  data: {
                    is_expired: true,
                    last_order_id_collect_points: order.id,
                  },
                });
                console.log(
                  `[givePointsToCustomer] Expired batch ${lastActiveBatch.id} for customer ${userId} — rating ${rating} < min ${minRating}`,
                );
              } else {
                // Must advance the pointer even if no active batch exists
                const anyLastBatch = await tx.customerPointBatch.findFirst({
                  where: { user_id: Number(userId), deleted_at: null },
                  orderBy: { created_at: "desc" },
                });

                if (anyLastBatch) {
                  await tx.customerPointBatch.update({
                    where: { id: anyLastBatch.id },
                    data: { last_order_id_collect_points: order.id },
                  });
                } else {
                  // Create a dummy expired batch just to hold the pointer
                  await tx.customerPointBatch.create({
                    data: {
                      user_id: Number(userId),
                      successful_orders_count: 0,
                      balance: 0,
                      is_expired: true,
                      last_order_id_collect_points: order.id,
                    },
                  });
                }
              }
              continue; // Move to the next order
            }

            // STEP 3: SUCCESSFUL ORDER - HANDLE BATCH
            const orderValueCents = Number(
              order.actual_price ?? order.budget ?? 0,
            );
            const orderValueEGP = orderValueCents / 100;
            const cashBackAsEGP = orderValueEGP * (cashbackPct / 100);
            const cashBackAsPoints = Math.floor(cashBackAsEGP * pointsPerEgp);

            if (cashBackAsPoints <= 0) {
              console.log(
                `[givePointsToCustomer] Cashback points = 0 for order ${order.id} (value: ${orderValueEGP} EGP). Only updating pointer.`,
              );

              // Still need to update pointer and increment successful_orders_count
              const anyLastBatch = await tx.customerPointBatch.findFirst({
                where: { user_id: Number(userId), deleted_at: null },
                orderBy: { created_at: "desc" },
              });

              if (anyLastBatch) {
                const isActive =
                  !anyLastBatch.is_expired &&
                  anyLastBatch.all_points_collected_at === null;
                if (isActive) {
                  await tx.customerPointBatch.update({
                    where: { id: anyLastBatch.id },
                    data: {
                      successful_orders_count: { increment: 1 },
                      last_order_id_collect_points: order.id,
                    },
                  });
                  // Check completion even with 0 points
                  await completeCustomerBatchIfReady(
                    tx,
                    anyLastBatch.id,
                    Number(userId),
                    settings,
                  );
                } else {
                  await tx.customerPointBatch.update({
                    where: { id: anyLastBatch.id },
                    data: { last_order_id_collect_points: order.id },
                  });
                }
              } else {
                // Create a dummy expired batch just to hold the pointer
                await tx.customerPointBatch.create({
                  data: {
                    user_id: Number(userId),
                    successful_orders_count: 0,
                    balance: 0,
                    is_expired: true,
                    last_order_id_collect_points: order.id,
                  },
                });
              }

              continue;
            }

            // Get the last customerPointBatch for this user
            const lastBatch = await tx.customerPointBatch.findFirst({
              where: { user_id: Number(userId), deleted_at: null },
              orderBy: { created_at: "desc" },
            });

            const hasActiveBatch =
              lastBatch &&
              !lastBatch.is_expired &&
              lastBatch.all_points_collected_at === null;

            if (!hasActiveBatch) {
              // CASE A: No active batch exists
              const expiredAt = new Date();
              expiredAt.setDate(expiredAt.getDate() + validityDays);

              const newBatch = await tx.customerPointBatch.create({
                data: {
                  user_id: Number(userId),
                  successful_orders_count: 1,
                  balance: cashBackAsPoints,
                  is_expired: false,
                  expired_at: expiredAt,
                  last_order_id_collect_points: order.id,
                },
              });
              console.log(
                `[givePointsToCustomer] Created new batch ${newBatch.id} for customer ${userId}: orders 1/${requiredOrders}, balance ${cashBackAsPoints}`,
              );

              // Check completion immediately
              await completeCustomerBatchIfReady(
                tx,
                newBatch.id,
                Number(userId),
                settings,
              );
            } else {
              // CASE B: An active batch exists
              const newBalance = (lastBatch.balance ?? 0) + cashBackAsPoints;
              const newOrderCount =
                (lastBatch.successful_orders_count ?? 0) + 1;

              await tx.customerPointBatch.update({
                where: { id: lastBatch.id },
                data: {
                  balance: newBalance,
                  successful_orders_count: newOrderCount,
                  last_order_id_collect_points: order.id,
                },
              });
              console.log(
                `[givePointsToCustomer] Updated batch ${lastBatch.id} for customer ${userId}: orders ${newOrderCount}/${requiredOrders}, balance ${lastBatch.balance} → ${newBalance}`,
              );

              // STEP 4: CHECK BATCH COMPLETION
              await completeCustomerBatchIfReady(
                tx,
                lastBatch.id,
                Number(userId),
                settings,
              );
            }
          }
        },
        { timeout: 30000 }, // 30 second timeout per chunk
      );

      processedCount += chunk.length;
      // Count supplier vs non-supplier orders in this chunk
      for (const order of chunk) {
        if (order.supplier_id) {
          supplierOrderCount++;
        } else {
          nonSupplierOrderCount++;
        }
      }
    }

    // step: send response
    return res.status(200).json({
      message: req.t("points:messages.points_processed_successfully", {
        defaultValue: "Points processed successfully for recent orders.",
      }),
      data: {
        status: "success",
        processedOrders: processedCount,
        supplierOrders: supplierOrderCount,
        nonSupplierOrders: nonSupplierOrderCount,
        note:
          nonSupplierOrderCount > 0
            ? `${nonSupplierOrderCount} order(s) were skipped because they are not associated with a supplier. Points are only awarded for orders placed with a supplier.`
            : undefined,
      },
    });
  };

  // ============================ convertPointsToMoney ============================
  convertPointsToMoney = async (
    req: Request,
    res: Response,
    next: NextFunction,
  ) => {
    // ============================================================================
    // TODO: PROPOSED POINTS TO MONEY CONVERSION LOGIC (FOR REVIEW)
    // ============================================================================
    //
    // SYSTEM OVERVIEW:
    // A user (Courier or Customer) can convert their earned points into real wallet balance (money in cents).
    // The conversion rate is determined by application settings:
    //   - For Courier: courier_number_of_points_required_per_1egp
    //   - For Customer: customer_number_of_points_required_per_1egp
    //
    // Note: The wallet balance is stored in cents (1 EGP = 100 cents).
    // The settings fields above represent the number of points required per 1 EGP (per 100 cents).
    //
    const { userId, piontsToMoney } = req.body as {
      userId: number | string;
      piontsToMoney: number;
    };

    // STEP 1: VALIDATE INPUT
    const pointsToConvert = Math.floor(piontsToMoney);
    if (pointsToConvert <= 0) {
      return res.status(400).json({
        message: req.t("points:errors.invalid_points_amount", {
          defaultValue: "Invalid points amount",
        }),
      });
    }

    // STEP 2: VALIDATE WALLET POINTS
    const wallet = await prisma.wallet.findUnique({
      where: { user_id: Number(userId) },
    });

    if (!wallet) {
      return res.status(404).json({
        message: req.t("points:errors.wallet_not_found", {
          defaultValue: "Wallet not found",
        }),
      });
    }

    if ((wallet.points || 0) < pointsToConvert) {
      return res.status(400).json({
        message: req.t("points:errors.insufficient_points", {
          defaultValue: "Insufficient points",
        }),
      });
    }

    // STEP 3: DETERMINE CONVERSION RATE
    const settings = await prisma.applicationSetting.findFirst();
    if (!settings) {
      return res.status(404).json({
        message: req.t("settings:errors.not_found", {
          defaultValue: "Application settings not found",
        }),
      });
    }

    const isCourier = wallet.owner_type === "COURIER";
    const pointsPerEgp = isCourier
      ? Number(settings.courier_number_of_points_required_per_1egp)
      : Number(settings.customer_number_of_points_required_per_1egp);

    if (pointsPerEgp <= 0) {
      return res.status(400).json({
        message: req.t("points:errors.invalid_conversion_rate", {
          defaultValue: "Invalid points conversion rate in settings",
        }),
      });
    }

    // STEP 4: CALCULATE MONEY VALUE (IN CENTS)
    const money_cents = Math.floor((pointsToConvert / pointsPerEgp) * 100);
    if (money_cents <= 0) {
      return res.status(400).json({
        message: req.t("points:errors.insufficient_points_for_conversion", {
          defaultValue: "Not enough points to convert",
        }),
      });
    }
    const money_egp = money_cents / 100;

    // STEP 5: CALCULATE EXACT POINTS TO DEDUCT
    const actualPointsToDeduct = (money_cents / 100) * pointsPerEgp;

    // STEP 6: PROCESS CONVERSION IN TRANSACTION
    await prisma.$transaction(async (tx) => {
      // Decrement `actualPointsToDeduct` from `wallet.points`.
      // Increment `money_cents` to `wallet.balance`.
      await adjustWalletBalance(tx, wallet.id, money_cents, {
        points_to_money: wallet.points,
      });
      await tx.wallet.update({
        where: { id: wallet.id },
        data: {
          points: { decrement: actualPointsToDeduct },
        },
      });

      // Create a TopUp Transaction logging the converted points
      await tx.transaction.create({
        data: {
          wallet_id: wallet.id,
          type: "TOPUP",
          status: "COMPLETED",
          amount: money_cents, // Logging the monetary value added to balance in cents
          description: `Converted ${actualPointsToDeduct} points to wallet balance`,
        },
      });
    });

    return res.status(200).json({
      message: req.t("points:messages.points_converted_to_money", {
        defaultValue: "Points successfully converted to money",
      }),
      data: {
        pointsUsed: actualPointsToDeduct,
        moneyAddedEgp: money_egp,
        moneyAddedCents: money_cents,
        pointsPerEgp,
        userType: isCourier ? "COURIER" : "CUSTOMER",
      },
    });
  };

  // ============================ payFines ============================
  payFines = async (req: Request, res: Response, next: NextFunction) => {
    // Note: This is an admin API, so we take user_id from the body
    const {
      user_id,
      penalty_ids,
      commission_ids,
    }: PayFinesDTO & { user_id: any } = req.body as any;
    const userId = Number(user_id);

    const hasSpecificIds =
      (penalty_ids && penalty_ids.length > 0) ||
      (commission_ids && commission_ids.length > 0);

    // step: get application settings
    const settings = await prisma.applicationSetting.findFirst();
    if (!settings) {
      return res.status(404).json({
        message: req.t("settings:errors.not_found"),
      });
    }

    // step: get user wallet
    const wallet = await prisma.wallet.findUnique({
      where: { user_id: userId },
    });
    if (!wallet) {
      return res.status(404).json({
        message: req.t("points:errors.wallet_not_found"),
      });
    }

    // step: determine user type (CUSTOMER or COURIER) for correct batch model and rate
    const isCourier = wallet.owner_type === "COURIER";
    console.log(
      `[payFinesUsingPoints] userId=${userId}, walletId=${wallet.id}, owner_type=${wallet.owner_type}, isCourier=${isCourier}`,
    );

    // step: get unpaid commissions
    const unpaidCommissions = await prisma.unpaidCommission.findMany({
      where: {
        user_id: userId,
        is_paid: false,
        ...(commission_ids && commission_ids.length > 0
          ? { id: { in: commission_ids } }
          : {}),
      },
      orderBy: { created_at: "asc" },
    });

    // step: get pending penalties
    const pendingPenalties = await prisma.penalty.findMany({
      where: {
        user_id: userId,
        is_paid: false,
        is_waived: false,
        ...(penalty_ids && penalty_ids.length > 0
          ? { id: { in: penalty_ids } }
          : {}),
      },
      orderBy: { created_at: "asc" },
    });

    console.log(
      `[payFinesUsingPoints] unpaidCommissions=${unpaidCommissions.length}, pendingPenalties=${pendingPenalties.length}`,
    );

    // step: check if there are fines to pay
    if (unpaidCommissions.length === 0 && pendingPenalties.length === 0) {
      return res.status(400).json({
        message: req.t("points:errors.no_fines_to_pay"),
      });
    }

    const availableBalance = wallet.balance || 0;

    if (hasSpecificIds) {
      // ==================== MODE: pay specific IDs ====================

      // step: calculate total fines for requested IDs
      const totalCommissions = unpaidCommissions.reduce(
        (sum, c) => sum + Number(c.amount),
        0,
      );
      const totalPenalties = pendingPenalties.reduce(
        (sum, p) => sum + Number(p.amount),
        0,
      );
      const totalFinesEgp = totalCommissions + totalPenalties;

      // step: check sufficient balance for all requested items
      if (availableBalance < totalFinesEgp) {
        return res.status(400).json({
          message: req.t("points:errors.insufficient_balance", {
            defaultValue: "Insufficient balance to pay fines",
          }),
        });
      }

      // step: process payment in a transaction
      await prisma.$transaction(async (tx) => {
        // step: decrement wallet balance
        // await adjustWalletBalance(tx, wallet.id, -totalFinesEgp);

        // step: get platform wallet
        const platformWallet = await tx.wallet.findFirst({
          where: { owner_type: "PLATFORM" },
        });

        // step: pay unpaid commissions
        for (const commission of unpaidCommissions) {
          const commissionAmount = Number(commission.amount);

          await tx.unpaidCommission.update({
            where: { id: commission.id },
            data: { is_paid: true, paid_at: new Date() },
          });

          await tx.transaction.create({
            data: {
              wallet_id: wallet.id,
              order_id: commission.order_id,
              type: "PLATFORM_COD_COMMISSION",
              status: "COMPLETED",
              amount: -commissionAmount,
              description: `Commission paid for order #${commission.order_id}`,
            },
          });

          // step: edit user balance
          await adjustWalletBalance(tx, wallet.id, -commissionAmount, {
            unpaid_commission_id: commission.id,
          });

          // step: edit platform balance
          if (platformWallet) {
            await adjustWalletBalance(tx, platformWallet.id, commissionAmount, {
              unpaid_commission_id: commission.id,
            });
          }
        }

        // step: pay penalties
        for (const penalty of pendingPenalties) {
          const penaltyAmount = Number(penalty.amount);

          await tx.penalty.update({
            where: { id: penalty.id },
            data: { is_paid: true, paid_at: new Date() },
          });

          await tx.transaction.create({
            data: {
              wallet_id: wallet.id,
              type: "PENALTY",
              status: "COMPLETED",
              amount: -penaltyAmount,
              description: `Penalty paid: ${penalty.reason || "Penalty"}`,
            },
          });

          // step: edit user balance
          await adjustWalletBalance(tx, wallet.id, -penaltyAmount, {
            penalty_id: penalty.id,
          });

          // step: edit platform balance
          if (platformWallet) {
            await adjustWalletBalance(tx, platformWallet.id, penaltyAmount, {
              penalty_id: penalty.id,
            });
          }
        }
      });
      return res.status(200).json({
        message: req.t("points:messages.fines_paid", {
          defaultValue: "Fines paid successfully",
        }),
        data: {
          commissionsPaid: totalCommissions,
          penaltiesPaid: totalPenalties,
          totalFinesPaid: totalFinesEgp,
        },
      });
    } else {
      // ==================== MODE: pay as many as possible ====================

      // step: check if customer has any balance
      if (availableBalance <= 0) {
        return res.status(400).json({
          message: req.t("points:errors.insufficient_balance", {
            defaultValue: "Insufficient balance to pay fines",
          }),
        });
      }

      // step: process payment in a transaction
      let totalAmountUsed = 0;
      let totalCommissionsPaid = 0;
      let totalPenaltiesPaid = 0;

      await prisma.$transaction(async (tx) => {
        let remainingBalance = availableBalance;

        // step: get platform wallet
        const platformWallet = await tx.wallet.findFirst({
          where: { owner_type: "PLATFORM" },
        });

        // step: pay unpaid commissions (oldest first, skip if can't fully cover)
        for (const commission of unpaidCommissions) {
          const commissionAmount = Number(commission.amount);

          if (remainingBalance < commissionAmount) continue;

          await tx.unpaidCommission.update({
            where: { id: commission.id },
            data: { is_paid: true, paid_at: new Date() },
          });

          await tx.transaction.create({
            data: {
              wallet_id: wallet.id,
              order_id: commission.order_id,
              type: "PLATFORM_COD_COMMISSION",
              status: "COMPLETED",
              amount: -commissionAmount,
              description: `Commission paid for order #${commission.order_id}`,
            },
          });

          if (platformWallet) {
            await adjustWalletBalance(tx, platformWallet.id, commissionAmount, {
              unpaid_commission_id: commission.id,
            });
          }

          remainingBalance -= commissionAmount;
          totalAmountUsed += commissionAmount;
          totalCommissionsPaid += commissionAmount;
        }

        // step: pay penalties (oldest first, skip if can't fully cover)
        for (const penalty of pendingPenalties) {
          const penaltyAmount = Number(penalty.amount);

          if (remainingBalance < penaltyAmount) continue;

          await tx.penalty.update({
            where: { id: penalty.id },
            data: { is_paid: true, paid_at: new Date() },
          });

          await tx.transaction.create({
            data: {
              wallet_id: wallet.id,
              type: "PENALTY",
              status: "COMPLETED",
              amount: -penaltyAmount,
              description: `Penalty paid: ${penalty.reason || "Penalty"}`,
            },
          });

          // step: edit user balance
          await adjustWalletBalance(tx, wallet.id, -penaltyAmount, {
            penalty_id: penalty.id,
          });

          // step: edit platform balance
          if (platformWallet) {
            await adjustWalletBalance(tx, platformWallet.id, penaltyAmount, {
              penalty_id: penalty.id,
            });
          }

          remainingBalance -= penaltyAmount;
          totalAmountUsed += penaltyAmount;
          totalPenaltiesPaid += penaltyAmount;
        }

        // step: check if anything was paid
        if (totalAmountUsed <= 0) return;

        // step: decrement wallet balance
        // await adjustWalletBalance(tx, wallet.id, -totalAmountUsed);
      });

      if (totalAmountUsed <= 0) {
        return res.status(400).json({
          message: req.t("points:errors.insufficient_balance", {
            defaultValue: "Insufficient balance to pay fines",
          }),
        });
      }
      return res.status(200).json({
        message: req.t("points:messages.fines_paid", {
          defaultValue: "Fines paid successfully",
        }),
        data: {
          commissionsPaid: totalCommissionsPaid,
          penaltiesPaid: totalPenaltiesPaid,
          totalFinesPaid: totalCommissionsPaid + totalPenaltiesPaid,
        },
      });
    }
  };

  // ============================ payFinesUsingPoints ============================
  payFinesUsingPoints = async (
    req: Request,
    res: Response,
    next: NextFunction,
  ) => {
    const {
      user_id,
      penalty_ids,
      commission_ids,
    }: PayFinesUsingPointsDTO & { user_id: any } = req.body as any;
    const userId = Number(user_id);

    const hasSpecificIds =
      (penalty_ids && penalty_ids.length > 0) ||
      (commission_ids && commission_ids.length > 0);

    // 1. Calculate needed points for passed penalty_ids and commission_ids
    const unpaidCommissions = await prisma.unpaidCommission.findMany({
      where: {
        user_id: userId,
        is_paid: false,
        ...(commission_ids && commission_ids.length > 0
          ? { id: { in: commission_ids } }
          : {}),
      },
    });

    const pendingPenalties = await prisma.penalty.findMany({
      where: {
        user_id: userId,
        is_paid: false,
        is_waived: false,
        ...(penalty_ids && penalty_ids.length > 0
          ? { id: { in: penalty_ids } }
          : {}),
      },
    });

    if (unpaidCommissions.length === 0 && pendingPenalties.length === 0) {
      return res.status(400).json({
        message: req.t("points:errors.no_fines_to_pay"),
      });
    }

    const totalCommissions = unpaidCommissions.reduce(
      (sum, c) => sum + Number(c.amount),
      0,
    );
    const totalPenalties = pendingPenalties.reduce(
      (sum, p) => sum + Number(p.amount),
      0,
    );
    const totalFinesCents = totalCommissions + totalPenalties;
    const totalFinesEgp = totalFinesCents / 100;

    const wallet = await prisma.wallet.findUnique({
      where: { user_id: userId },
    });
    if (!wallet)
      return res
        .status(404)
        .json({ message: req.t("points:errors.wallet_not_found") });

    const settings = await prisma.applicationSetting.findFirst();
    if (!settings)
      return res
        .status(404)
        .json({ message: req.t("settings:errors.not_found") });

    const isCourier = wallet.owner_type === "COURIER";
    const pointsPerEgp = isCourier
      ? Number(settings.courier_number_of_points_required_per_1egp)
      : Number(settings.customer_number_of_points_required_per_1egp);

    let neededPoints = Math.ceil(totalFinesEgp * pointsPerEgp);

    // If not specific IDs (paying as much as possible), cap the points to what they have
    if (!hasSpecificIds) {
      if ((wallet.points || 0) < neededPoints) {
        // Ensure they only convert points that map to full EGP
        const maxEgpTheyCanAfford = Math.floor(
          (wallet.points || 0) / pointsPerEgp,
        );
        neededPoints = maxEgpTheyCanAfford * pointsPerEgp;
      }
    }

    if (neededPoints <= 0) {
      return res.status(400).json({
        message: req.t("points:errors.insufficient_points_for_conversion", {
          defaultValue: "Not enough points to convert to at least 1 EGP",
        }),
      });
    }

    // 2. Call convert-points-to-money api
    let convertError: any = null;

    const mockRes1 = {
      status: (code: number) => {
        return {
          json: (data: any) => {
            if (code !== 200) {
              convertError = { code, data };
            }
          },
        };
      },
    } as Response;

    const mockReq1 = {
      ...req,
      body: {
        userId: userId,
        piontsToMoney: neededPoints,
      },
    } as Request;

    await this.convertPointsToMoney(mockReq1, mockRes1, next);

    if (convertError) {
      return res.status(convertError.code).json(convertError.data);
    }

    // 3. Call pay-fines api
    // This will return the actual response directly to the user
    const mockReq2 = {
      ...req,
      body: {
        user_id: userId,
        penalty_ids,
        commission_ids,
      },
    } as Request;

    return await this.payFines(mockReq2, res, next);
  };
}

// ================================ completeCourierBatchIfReady ================================
async function completeCourierBatchIfReady(
  tx: Parameters<Parameters<typeof prisma.$transaction>[0]>[0],
  batchId: number,
  userId: number,
  settings: any,
): Promise<boolean> {
  const batch = await tx.courierPointBatch.findUnique({
    where: { id: batchId },
  });
  if (
    !batch ||
    batch.successful_orders_count === null ||
    batch.balance === null
  )
    return false;

  const requiredOrders = Number(
    settings.courier_number_of_delivered_orders_required_per_reward_batch,
  );
  const orderCount = batch.successful_orders_count;
  const balance = batch.balance;

  if (orderCount >= requiredOrders) {
    // step: mark batch as complete
    await tx.courierPointBatch.update({
      where: { id: batchId },
      data: { all_points_collected_at: new Date() },
    });

    // step: transfer all accumulated points to wallet
    const pointsToWallet = balance;
    await tx.wallet.updateMany({
      where: { user_id: Number(userId), owner_type: "COURIER" },
      data: { points: { increment: pointsToWallet } },
    });
    console.log(
      `[completeCourierBatch] Batch ${batchId} completed — ${pointsToWallet} points → wallet for courier ${userId} (${orderCount} orders)`,
    );

    // // step: log transaction
    // const userWallet = await tx.wallet.findFirst({
    //   where: { user_id: Number(userId), owner_type: "COURIER" },
    // });
    // if (userWallet) {
    //   await tx.transaction.create({
    //     data: {
    //       wallet_id: userWallet.id,
    //       courier_point_batch_id: batchId,
    //       type: "TOPUP",
    //       status: "COMPLETED",
    //       amount: pointsToWallet,
    //       description: `Points awarded for completing order batch #${batchId}`,
    //     },
    //   });
    // }

    return true;
  }
  return false;
}

// ================================ completeCustomerBatchIfReady ================================
async function completeCustomerBatchIfReady(
  tx: Parameters<Parameters<typeof prisma.$transaction>[0]>[0],
  batchId: number,
  userId: number,
  settings: any,
): Promise<boolean> {
  const batch = await tx.customerPointBatch.findUnique({
    where: { id: batchId },
  });
  if (
    !batch ||
    batch.successful_orders_count === null ||
    batch.balance === null
  )
    return false;

  const requiredOrders = Number(
    settings.customer_number_of_delivered_orders_required_per_reward_batch,
  );
  const orderCount = batch.successful_orders_count;
  const balance = batch.balance;

  if (orderCount >= requiredOrders) {
    // step: mark batch as complete
    await tx.customerPointBatch.update({
      where: { id: batchId },
      data: { all_points_collected_at: new Date() },
    });

    // step: transfer all accumulated points to wallet
    const pointsToWallet = balance;
    await tx.wallet.updateMany({
      where: { user_id: userId, owner_type: "CUSTOMER" },
      data: { points: { increment: pointsToWallet } },
    });
    console.log(
      `[completeCustomerBatch] Batch ${batchId} completed — ${pointsToWallet} points → wallet for customer ${userId} (${orderCount} orders)`,
    );

    // // step: log transaction
    // const userWallet = await tx.wallet.findFirst({
    //   where: { user_id: Number(userId), owner_type: "CUSTOMER" },
    // });
    // if (userWallet) {
    //   await tx.transaction.create({
    //     data: {
    //       wallet_id: userWallet.id,
    //       customer_point_batch_id: batchId,
    //       type: "TOPUP",
    //       status: "COMPLETED",
    //       amount: pointsToWallet,
    //       description: `Points awarded for completing order batch #${batchId} (${orderCount} orders, ${pointsToWallet} points)`,
    //     },
    //   });
    // }

    return true;
  }
  return false;
}
