import { NextFunction, Request, Response } from "express";
import { responseHandler } from "../../core/handlers/response.handler";
import { prisma } from "../../DB/lib/prisma";
import { HttpStatusCode } from "../../core/http/http.status.code";
import { TopupDTO } from "./wallet.dto";
import { PaymobService, getConfig } from "../../utils/paymob/paymob.service";
import { TransactionCallback } from "../../utils/paymob/paymob.types";
import { applyFilters, buildPaginationResponse } from "../../utils/filter";
import logger from "../../config/logger.config";

export class WalletService {
  constructor() {}
  paymobService = new PaymobService();

  // ============================ walletData ============================
  walletData = async (req: Request, res: Response, next: NextFunction) => {
    const user = res.locals.user;

    // step: get user wallet
    const wallet = await prisma.wallet.findUnique({
      where: { user_id: user.id },
    });
    if (!wallet) {
      return responseHandler({
        res,
        status: HttpStatusCode.NOT_FOUND,
        message: res.__("errors.wallet_not_found"),
      });
    }

    return responseHandler({
      res,
      message: res.__("messages.wallet_retrieved"),
      data: { wallet },
    });
  };

  // ============================ listTransaction ============================
  listTransaction = async (req: Request, res: Response, next: NextFunction) => {
    const user = res.locals.user;

    // step: Apply filters
    const { filters, pagination, paginationMeta } = applyFilters(
      res.locals.validatedData,
      {
        order_id: "exact",
        processed_by: "exact",
        type: "exact",
        status: "exact",
        amount: "exact",
        created_at: "dateRange",
        updated_at: "dateRange",
      },
    );

    // step: get user wallet
    const wallet = await prisma.wallet.findUnique({
      where: { user_id: user.id },
    });
    if (!wallet) {
      return responseHandler({
        res,
        status: HttpStatusCode.NOT_FOUND,
        message: res.__("errors.wallet_not_found"),
      });
    }

    // step: Apply strict filters
    filters.wallet_id = wallet.id;

    const [userTransactions, total] = await Promise.all([
      prisma.transaction.findMany({
        where: filters,
        orderBy: { created_at: "desc" },
        include: {
          order: true,
          paymentMethod: true,
        },
        ...pagination,
      }),
      prisma.transaction.count({
        where: filters,
      }),
    ]);

    return responseHandler({
      res,
      message: res.__("messages.transactions_retrieved"),
      data: {
        userTransactions,
        pagination: buildPaginationResponse(paginationMeta, total),
      },
    });
  };

  // ============================ listPenalty ============================
  listPenalty = async (req: Request, res: Response, next: NextFunction) => {
    const user = res.locals.user;

    // step: Apply filters
    const { filters, pagination, paginationMeta } = applyFilters(
      res.locals.validatedData,
      {
        created_by: "exact",
        amount: "exact",
        is_paid: "exact",
        is_waived: "exact",
        waived_by: "exact",
        paid_at: "dateRange",
        waived_at: "dateRange",
        created_at: "dateRange",
      },
    );

    // step: Apply strict filters
    filters.user_id = user.id;

    const [penalties, total] = await Promise.all([
      prisma.penalty.findMany({
        where: filters,
        orderBy: { created_at: "desc" },
        ...pagination,
      }),
      prisma.penalty.count({
        where: filters,
      }),
    ]);

    return responseHandler({
      res,
      message: res.__("messages.penalties_retrieved"),
      data: {
        penalties,
        pagination: buildPaginationResponse(paginationMeta, total),
      },
    });
  };

  // ============================ listUnpaidCommission ============================
  listUnpaidCommission = async (
    req: Request,
    res: Response,
    next: NextFunction,
  ) => {
    const user = res.locals.user;

    // step: Apply filters
    const { filters, pagination, paginationMeta } = applyFilters(
      res.locals.validatedData,
      {
        order_id: "exact",
        amount: "exact",
        is_paid: "exact",
        paid_at: "dateRange",
        created_at: "dateRange",
      },
    );

    // step: Apply strict filters
    filters.user_id = user.id;

    const [userUnpaidCommissions, total] = await Promise.all([
      prisma.unpaidCommission.findMany({
        where: filters,
        orderBy: { created_at: "desc" },
        include: {
          order: true,
        },
        ...pagination,
      }),
      prisma.unpaidCommission.count({
        where: filters,
      }),
    ]);

    return responseHandler({
      res,
      message: res.__("messages.unpaid_commissions_retrieved"),
      data: {
        userUnpaidCommissions,
        pagination: buildPaginationResponse(paginationMeta, total),
      },
    });
  };

  // ============================ totalFines ============================
  totalFines = async (req: Request, res: Response, next: NextFunction) => {
    const user = res.locals.user;

    // step: check user has not reached to max_unpaid_commission
    const userUnpaidCommissions = await prisma.unpaidCommission.findMany({
      where: { user_id: user.id, is_paid: false },
    });
    let totalUnpaidCommissionAmount = 0;
    userUnpaidCommissions.forEach((item) => {
      totalUnpaidCommissionAmount += Number(item.amount);
    });
    // step: check user has not reached to max_penalties
    const userPenalties = await prisma.penalty.findMany({
      where: { user_id: user.id, is_paid: false },
    });
    let totalPenalties = 0;
    userPenalties.forEach((item) => {
      totalPenalties += Number(item.amount);
    });
    const total = totalUnpaidCommissionAmount + totalPenalties;

    return responseHandler({
      res,
      data: { totalUnpaidCommissionAmount, totalPenalties, total },
    });
  };

  // ============================ topup ============================
  topup = async (req: Request, res: Response, next: NextFunction) => {
    const user = res.locals.user;
    const { amount }: TopupDTO = req.body;

    // step: verify payment method belongs to user
    let paymentMethod = await prisma.paymentMethod.findFirst({
      where: {
        user_id: user.id,
        method_type: "BANK_ACCOUNT",
        provider: "PAYMOB",
        deleted_at: null,
      },
    });
    if (!paymentMethod) {
      paymentMethod = await prisma.paymentMethod.create({
        data: {
          user_id: user.id,
          method_type: "BANK_ACCOUNT",
          provider: "PAYMOB",
        },
      });
    }

    // step: get user wallet
    const wallet = await prisma.wallet.findUnique({
      where: { user_id: user.id },
    });
    if (!wallet) {
      return responseHandler({
        res,
        status: HttpStatusCode.NOT_FOUND,
        message: res.__("errors.wallet_not_found"),
      });
    }

    // step: create pending transaction
    const transaction = await prisma.transaction.create({
      data: {
        wallet_id: wallet.id,
        payment_method_id: paymentMethod.id,
        type: "TOPUP",
        status: "PENDING",
        amount: amount,
        description: `Wallet top-up of ${amount} EGP`,
      },
    });

    // step: create payment intention on Paymob
    const amountCents = amount;
    const merchantOrderId = `topup_${transaction.id}_${Date.now()}`;

    try {
      const CONFIG = await getConfig();
      const intention = await this.paymobService.createIntention({
        amount: amountCents,
        currency: "EGP",
        payment_methods: [parseInt(CONFIG.INTEGRATION_ID)],
        items: [{ name: `Wallet Top-up`, amount: amountCents, quantity: 1 }],
        billing_data: {
          first_name: user.full_name?.split(" ")[0] || "User",
          last_name: user.full_name?.split(" ").slice(1).join(" ") || "User",
          email: user.email || `no-email-${user.id}@tawreedat.com`,
          phone_number: user.phone || "+201000000000",
        },
        special_reference: merchantOrderId,
        notification_url: CONFIG.NOTIFICATION_URL,
        redirection_url: CONFIG.REDIRECTION_URL,
      });

      // step: update transaction with paymob order id
      await prisma.transaction.update({
        where: { id: transaction.id },
        data: {
          description: `Wallet top-up - Order: ${intention.intention_order_id}`,
          paymob_order_id: intention.intention_order_id.toString(),
        },
      });

      // step: generate unified checkout URL
      const paymentUrl = await this.paymobService.getCheckoutUrl(
        intention.client_secret,
      );

      logger.info(
        {
          userId: user.id,
          transactionId: transaction.id,
          amountCents,
          paymobOrderId: intention.intention_order_id,
        },
        "[Wallet] Topup initiated via Paymob",
      );

      return responseHandler({
        res,
        message: res.__("messages.topup_initiated"),
        data: {
          transaction_id: transaction.id,
          paymob_order_id: intention.intention_order_id,
          payment_url: paymentUrl,
        },
      });
    } catch (error: any) {
      logger.error(
        {
          userId: user.id,
          transactionId: transaction.id,
          error: error.message,
        },
        "[Wallet] Paymob topup failed",
      );
      // step: mark transaction as failed if Paymob call fails
      await prisma.transaction.update({
        where: { id: transaction.id },
        data: {
          status: "FAILED",
          reject_reason: error.message || "Payment gateway error",
        },
      });

      return responseHandler({
        res,
        status: HttpStatusCode.INTERNAL_SERVER_ERROR,
        message: res.__("errors.payment_initiation_failed"),
        data: { error: error.message },
      });
    }
  };

  // ============================ paymobWebhook ============================
  paymobWebhook = async (req: Request, res: Response, next: NextFunction) => {
    const requestBody = req.body;
    const hmac = req.query.hmac as string;

    // step: verify HMAC signature
    if (
      !(await this.paymobService.verifyCallback(
        requestBody as TransactionCallback,
        hmac,
      ))
    ) {
      logger.warn(
        { paymobOrderId: requestBody?.obj?.order?.id },
        "[Wallet] Invalid Paymob HMAC signature",
      );
      return responseHandler({
        res,
        status: HttpStatusCode.UNAUTHORIZED,
        message: res.__("errors.invalid_hmac"),
      });
    }

    const paymobOrderId = requestBody.obj?.order?.id;
    const paymobTransactionId = requestBody.obj?.id?.toString();
    const isSuccess = requestBody.obj?.success === true;
    const amountCents = requestBody.obj?.amount_cents;
    const createdAt = requestBody.obj?.created_at;

    // step: validate timestamp - reject webhooks older than 5 minutes
    const webhookTime = createdAt ? new Date(createdAt * 1000) : null;
    const fiveMinutesAgo = new Date(Date.now() - 5 * 60 * 1000);
    if (webhookTime && webhookTime < fiveMinutesAgo) {
      logger.warn(
        { paymobOrderId, webhookTime },
        "[Wallet] Rejected stale Paymob webhook",
      );
      return responseHandler({
        res,
        status: HttpStatusCode.BAD_REQUEST,
        message: res.__("errors.stale_webhook"),
      });
    }

    // step: idempotency check - prevent replay attacks
    const existingTransaction = await prisma.transaction.findFirst({
      where: {
        paymob_order_id: paymobOrderId.toString(),
        status: "COMPLETED",
      },
    });
    if (existingTransaction) {
      logger.info(
        { paymobOrderId, transactionId: existingTransaction.id },
        "[Wallet] Paymob webhook already processed",
      );
      return responseHandler({
        res,
        status: HttpStatusCode.OK,
        message: "Already processed",
      });
    }

    // step: find transaction by paymob order id (stored in paymob_order_id)
    const transaction = await prisma.transaction.findFirst({
      where: {
        paymob_order_id: paymobOrderId.toString(),
        status: "PENDING",
      },
      include: { wallet: true },
    });

    if (!transaction || !transaction.wallet) {
      return responseHandler({
        res,
        status: HttpStatusCode.NOT_FOUND,
        message: res.__("errors.transaction_not_found"),
      });
    }

    if (isSuccess) {
      const amount = amountCents;

      // step: process successful payment in a transaction
      await prisma.$transaction(async (tx) => {
        // step: update transaction status
        await tx.transaction.update({
          where: { id: transaction.id },
          data: { status: "COMPLETED" },
        });

        // step: credit wallet balance
        await tx.wallet.update({
          where: { id: transaction.wallet_id! },
          data: { balance: { increment: amount } },
        });

        // step: get platform wallet
        const platformWallet = await tx.wallet.findFirst({
          where: { owner_type: "PLATFORM" },
        });

        // step: get updated wallet balance
        const updatedWallet = await tx.wallet.findUnique({
          where: { id: transaction.wallet_id! },
        });

        let remainingBalance = Number(updatedWallet?.balance) || 0;

        // step: auto-deduct unpaid commissions (oldest first)
        const unpaidCommissions = await tx.unpaidCommission.findMany({
          where: {
            user_id: transaction.wallet!.user_id,
            is_paid: false,
          },
          orderBy: { created_at: "asc" },
        });

        for (const commission of unpaidCommissions) {
          if (remainingBalance <= 0) break;

          const commissionAmount = Number(commission.amount);

          // skip if can't fully cover
          if (remainingBalance < commissionAmount) continue;

          // Atomically decrement balance only if sufficient (prevents negative under concurrency)
          const commissionDecrement = await tx.wallet.updateMany({
            where: {
              id: transaction.wallet_id!,
              balance: { gte: commissionAmount },
            },
            data: { balance: { decrement: commissionAmount } },
          });

          // Another concurrent deduction may have consumed the balance; skip safely
          if (commissionDecrement.count === 0) continue;

          await tx.unpaidCommission.update({
            where: { id: commission.id },
            data: { is_paid: true, paid_at: new Date() },
          });

          // Create deduction transaction
          await tx.transaction.create({
            data: {
              wallet_id: transaction.wallet_id!,
              order_id: commission.order_id,
              payment_method_id: transaction.payment_method_id,
              type: "PLATFORM_COD_COMMISSION",
              status: "COMPLETED",
              amount: -commissionAmount,
              description: `Commission deduction for order #${commission.order_id}`,
            },
          });

          // Credit platform wallet
          if (platformWallet) {
            await tx.wallet.update({
              where: { id: platformWallet.id },
              data: { balance: { increment: commissionAmount } },
            });
          }

          remainingBalance -= commissionAmount;
        }

        // step: auto-deduct pending penalties (oldest first)
        const pendingPenalties = await tx.penalty.findMany({
          where: {
            user_id: transaction.wallet!.user_id,
            is_paid: false,
            is_waived: false,
          },
          orderBy: { created_at: "asc" },
        });

        for (const penalty of pendingPenalties) {
          if (remainingBalance <= 0) break;

          const penaltyAmount = Number(penalty.amount);

          // skip if can't fully cover
          if (remainingBalance < penaltyAmount) continue;

          // Atomically decrement balance only if sufficient (prevents negative under concurrency)
          const penaltyDecrement = await tx.wallet.updateMany({
            where: {
              id: transaction.wallet_id!,
              balance: { gte: penaltyAmount },
            },
            data: { balance: { decrement: penaltyAmount } },
          });

          // Another concurrent deduction may have consumed the balance; skip safely
          if (penaltyDecrement.count === 0) continue;

          await tx.penalty.update({
            where: { id: penalty.id },
            data: { is_paid: true, paid_at: new Date() },
          });

          // Create penalty deduction transaction
          await tx.transaction.create({
            data: {
              wallet_id: transaction.wallet_id!,
              payment_method_id: transaction.payment_method_id,
              type: "PENALTY",
              status: "COMPLETED",
              amount: -penaltyAmount,
              description: `Penalty payment: ${penalty.reason || "Penalty"}`,
            },
          });

          // Credit platform wallet
          if (platformWallet) {
            await tx.wallet.update({
              where: { id: platformWallet.id },
              data: { balance: { increment: penaltyAmount } },
            });
          }

          remainingBalance -= penaltyAmount;
        }
      });

      logger.info(
        {
          transactionId: transaction.id,
          walletId: transaction.wallet_id,
          amountCents,
        },
        "[Wallet] Payment processed successfully",
      );

      return responseHandler({
        res,
        message: res.__("messages.payment_processed"),
      });
    } else {
      // step: mark transaction as failed
      await prisma.transaction.update({
        where: { id: transaction.id },
        data: {
          status: "FAILED",
          reject_reason: requestBody.obj?.data?.message || "Payment failed",
        },
      });

      logger.warn(
        { transactionId: transaction.id, paymobOrderId },
        "[Wallet] Payment failed",
      );

      return responseHandler({
        res,
        message: res.__("messages.payment_failed"),
      });
    }
  };

  // ============================ paymobRedirectionUrl ============================
  paymobRedirectionUrl = async (
    req: Request,
    res: Response,
    next: NextFunction,
  ) => {
    const requestBody = req.body;
    const isSuccess = requestBody.obj?.success === true;
    const paymobOrderId = requestBody.obj?.order?.id;

    // step: find transaction by paymob order id
    const transaction = await prisma.transaction.findFirst({
      where: {
        paymob_order_id: paymobOrderId?.toString(),
      },
    });

    const transactionId = transaction?.id || "";

    // step: redirect to frontend success/failed page
    const CONFIG = await getConfig();
    if (isSuccess) {
      return res.redirect(CONFIG.REDIRECTION_URL_SUCCESS_URL);
    } else {
      return res.redirect(CONFIG.REDIRECTION_URL_FAILED_URL);
    }
  };
}
