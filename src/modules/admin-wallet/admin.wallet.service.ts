import { HttpError } from "@/lib/httpError";
import { prisma } from "@/config/prisma";
import { Prisma } from "@prisma/client";
import { NextFunction, Request, Response } from "express";
import {
  AdjustBalanceDTO,
  ApplyPenaltyDTO,
  CPWRDTO,
  ChangeUserIdPWRDTO,
  DecBalancePWRDTO,
  EscrowsDTO,
  FreezeDTO,
  IncBalancePWRDTO,
  PaymentMethodsDTO,
  PenaltiesDTO,
  TransactionsDTO,
  UnpaidCommissionDTO,
  WalletDTO,
  SettlingBalanceDTO,
  SettlementReportDTO,
} from "./admin.wallet.dto";
import { applyFilters, buildPaginationResponse } from "@/lib/filter";
import FeatureApi from "@/lib/featureApi";
import { adjustWalletBalance } from "@/lib/adjustWalletBalance";

export class AdminWalletService {
  constructor() {}

  // ============================ wallets ============================
  wallets = async (req: Request, res: Response, next: NextFunction) => {
    // step: applyFilters handles typed where conditions (id, user_id, balance range, dates, etc.)
    const { filters, pagination, paginationMeta } = applyFilters(
      res.locals.validatedData,
      {
        id: "exact",
        user_id: "exact",
        owner_type: "exact",
        balance: "range",
        status: "exact",
        freeze_reason: "exact",
        frozen_at: "dateRange",
        frozen_by: "exact",
        created_at: "dateRange",
        updated_at: "dateRange",
        deleted_at: "dateRange",
      },
    );

    // step: FeatureApi handles include, select, orderBy, keyword, skip, limit
    const api = new FeatureApi(req)
      .includes() // ?includes=role=id-name,wallet,penalties
      .fields() // ?fields=id,user_id,balance
      .sort() // ?sort=-created_at
      .keyword(["freeze_reason"]) // ?keyword=xxx&items=freeze_reason
      .limit() // ?limit=20  (FeatureApi take — optional, applyFilters pagination is the fallback)
      .skip()
      .filter(); // ?skip=4

    // step: merge — applyFilters where takes precedence; FeatureApi adds include/select/orderBy
    const prismaQuery = {
      where: {
        ...filters,
        ...(api.data.where ?? {}), // keyword OR/AND conditions
      },
      ...(api.data.include ? { include: api.data.include } : {}),
      ...(api.data.select ? { select: api.data.select } : {}),
      ...(api.data.orderBy ? { orderBy: api.data.orderBy } : {}),
      // pagination: prefer FeatureApi values if explicitly passed, else fall back to applyFilters
      skip: api.data.skip ?? pagination.skip,
      take: api.data.take ?? pagination.take,
    };

    const [wallets, total] = await Promise.all([
      prisma.wallet.findMany(prismaQuery),
      prisma.wallet.count({ where: prismaQuery.where }),
    ]);

    return res.json({
      message: req.t("admin-wallet:messages.ok"),
      data: {
        wallets,
        pagination: buildPaginationResponse(paginationMeta, total),
      },
    });
  };

  // ============================ unpaidCommissions ============================
  unpaidCommissions = async (
    req: Request,
    res: Response,
    next: NextFunction,
  ) => {
    const { filters, pagination, paginationMeta } = applyFilters(
      res.locals.validatedData,
      {
        id: "exact",
        order_id: "exact",
        user_id: "exact",
        amount: "range",
        is_paid: "exact",
        created_at: "dateRange",
        paid_at: "dateRange",
      },
    );

    const api = new FeatureApi(req)
      .includes()
      .fields()
      .sort()
      .keyword(["reason"])
      .limit()
      .skip()
      .filter();

    const prismaQuery = {
      where: { ...filters, ...(api.data.where ?? {}) },
      ...(api.data.include ? { include: api.data.include } : {}),
      ...(api.data.select ? { select: api.data.select } : {}),
      ...(api.data.orderBy ? { orderBy: api.data.orderBy } : {}),
      skip: api.data.skip ?? pagination.skip,
      take: api.data.take ?? pagination.take,
    };

    const [unpaidCommissions, total] = await Promise.all([
      prisma.unpaidCommission.findMany(prismaQuery),
      prisma.unpaidCommission.count({ where: prismaQuery.where }),
    ]);

    return res.json({
      message: req.t("admin-wallet:messages.ok"),
      data: {
        unpaidCommissions,
        pagination: buildPaginationResponse(paginationMeta, total),
      },
    });
  };

  // ============================ penalties ============================
  penalties = async (req: Request, res: Response, next: NextFunction) => {
    const { filters, pagination, paginationMeta } = applyFilters(
      res.locals.validatedData,
      {
        id: "exact",
        user_id: "exact",
        created_by: "exact",
        amount: "range",
        reason: "exact",
        is_paid: "exact",
        paid_at: "dateRange",
        is_waived: "exact",
        waived_at: "dateRange",
        waived_by: "exact",
        created_at: "dateRange",
      },
    );

    const api = new FeatureApi(req)
      .includes()
      .fields()
      .sort()
      .keyword(["reason"])
      .limit()
      .skip()
      .filter();

    const prismaQuery = {
      where: { ...filters, ...(api.data.where ?? {}) },
      ...(api.data.include ? { include: api.data.include } : {}),
      ...(api.data.select ? { select: api.data.select } : {}),
      ...(api.data.orderBy ? { orderBy: api.data.orderBy } : {}),
      skip: api.data.skip ?? pagination.skip,
      take: api.data.take ?? pagination.take,
    };

    const [penalties, total] = await Promise.all([
      prisma.penalty.findMany(prismaQuery),
      prisma.penalty.count({ where: prismaQuery.where }),
    ]);

    return res.json({
      message: req.t("admin-wallet:messages.ok"),
      data: {
        penalties,
        pagination: buildPaginationResponse(paginationMeta, total),
      },
    });
  };

  // ============================ escrows ============================
  escrows = async (req: Request, res: Response, next: NextFunction) => {
    const { filters, pagination, paginationMeta } = applyFilters(
      res.locals.validatedData,
      {
        id: "exact",
        order_id: "exact",
        wallet_id: "exact",
        held_amount: "range",
        created_at: "dateRange",
        updated_at: "dateRange",
      },
    );

    const api = new FeatureApi(req)
      .includes()
      .fields()
      .sort()
      .keyword([])
      .limit()
      .skip()
      .filter();

    const prismaQuery = {
      where: { ...filters, ...(api.data.where ?? {}) },
      ...(api.data.include ? { include: api.data.include } : {}),
      ...(api.data.select ? { select: api.data.select } : {}),
      ...(api.data.orderBy ? { orderBy: api.data.orderBy } : {}),
      skip: api.data.skip ?? pagination.skip,
      take: api.data.take ?? pagination.take,
    };

    const [escrows, total] = await Promise.all([
      prisma.escrow.findMany(prismaQuery),
      prisma.escrow.count({ where: prismaQuery.where }),
    ]);

    return res.json({
      message: req.t("admin-wallet:messages.ok"),
      data: {
        escrows,
        pagination: buildPaginationResponse(paginationMeta, total),
      },
    });
  };

  // ============================ paymentMethods ============================
  paymentMethods = async (req: Request, res: Response, next: NextFunction) => {
    const { filters, pagination, paginationMeta } = applyFilters(
      res.locals.validatedData,
      {
        id: "exact",
        user_id: "exact",
        method_type: "exact",
        provider: "exact",
        instapay_number: "exact",
        mobile_wallet_number: "exact",
        provider_customer_id: "exact",
        provider_payment_method_id: "exact",
        display_name: "exact",
        is_default: "exact",
        created_at: "dateRange",
        updated_at: "dateRange",
        deleted_at: "dateRange",
      },
    );

    const api = new FeatureApi(req)
      .includes()
      .fields()
      .sort()
      .keyword(["display_name", "instapay_number", "mobile_wallet_number"])
      .limit()
      .skip()
      .filter();

    const prismaQuery = {
      where: { ...filters, ...(api.data.where ?? {}) },
      ...(api.data.include ? { include: api.data.include } : {}),
      ...(api.data.select ? { select: api.data.select } : {}),
      ...(api.data.orderBy ? { orderBy: api.data.orderBy } : {}),
      skip: api.data.skip ?? pagination.skip,
      take: api.data.take ?? pagination.take,
    };

    const [paymentMethods, total] = await Promise.all([
      prisma.paymentMethod.findMany(prismaQuery),
      prisma.paymentMethod.count({ where: prismaQuery.where }),
    ]);

    return res.json({
      message: req.t("admin-wallet:messages.ok"),
      data: {
        paymentMethods,
        pagination: buildPaginationResponse(paginationMeta, total),
      },
    });
  };

  // ============================ transactions ============================
  transactions = async (req: Request, res: Response, next: NextFunction) => {
    const { filters, pagination, paginationMeta } = applyFilters(
      res.locals.validatedData,
      {
        id: "exact",
        wallet_id: "exact",
        order_id: "exact",
        escrow_id: "exact",
        payment_method_id: "exact",
        processed_by: "exact",
        type: "exact",
        status: "exact",
        reject_reason: "exact",
        amount: "range",
        description: "exact",
        paymob_order_id: "exact",
        created_at: "dateRange",
        updated_at: "dateRange",
      },
    );

    const api = new FeatureApi(req)
      .includes()
      .fields()
      .sort()
      .keyword(["description", "reject_reason"])
      .limit()
      .skip()
      .filter();

    const prismaQuery = {
      where: { ...filters, ...(api.data.where ?? {}) },
      ...(api.data.include ? { include: api.data.include } : {}),
      ...(api.data.select ? { select: api.data.select } : {}),
      ...(api.data.orderBy ? { orderBy: api.data.orderBy } : {}),
      skip: api.data.skip ?? pagination.skip,
      take: api.data.take ?? pagination.take,
    };

    const [transactions, total] = await Promise.all([
      prisma.transaction.findMany(prismaQuery),
      prisma.transaction.count({ where: prismaQuery.where }),
    ]);

    return res.json({
      message: req.t("admin-wallet:messages.ok"),
      data: {
        transactions,
        pagination: buildPaginationResponse(paginationMeta, total),
      },
    });
  };

  // ============================ adjustBalance ============================
  adjustBalance = async (req: Request, res: Response, next: NextFunction) => {
    // step: get user
    const user = req.user;
    if (!user) {
      throw new HttpError(404, req.t("auth.errors.user_not_found"));
    }

    // step: get body data
    const {
      wallet_id,
      related_order_id,
      type,
      amount,
      description,
    }: AdjustBalanceDTO = req.sanitized.body;

    // step: invoke transaction
    await prisma.$transaction(async (tx) => {
      // step: check wallet existence
      const wallet = await prisma.wallet.findUnique({
        where: { id: wallet_id },
      });
      if (!wallet) {
        throw new HttpError(404, req.t("admin-wallet:errors.wallet_not_found"));
      }

      // step: check wallet is not frozen
      if (wallet.status === "FROZEN") {
        throw new HttpError(400, req.t("admin-wallet:errors.wallet_frozen"));
      }

      // step: check order existence if order_id is passed
      if (related_order_id) {
        const order = await prisma.order.findUnique({
          where: { id: related_order_id },
        });
        if (!order) {
          throw new HttpError(
            404,
            req.t("admin-wallet:errors.order_not_found"),
          );
        }
      }

      // step: check sufficient balance if type is MANUAL_DECREASE
      if (type === "MANUAL_DECREASE" && Number(wallet.balance) < amount) {
        throw new HttpError(
          400,
          req.t("admin-wallet:errors.insufficient_balance"),
        );
      }

      // step: create adjustment transaction record
      await tx.transaction.create({
        data: {
          wallet_id,
          order_id: related_order_id || null,
          processed_by: user.id,
          type,
          status: "COMPLETED",
          amount: amount,
          description: description,
          created_at: new Date(),
          updated_at: new Date(),
        },
      });

      // step: credit or debit user wallet balance
      await adjustWalletBalance(
        tx,
        wallet_id,
        type === "MANUAL_INCREASE" ? amount : -amount,
        { order_id: related_order_id },
      );

      // step: if MANUAL_INCREASE, auto-deduct unpaid commissions & penalties
      if (type === "MANUAL_INCREASE") {
        // step: get platform wallet
        const platformWallet = await tx.wallet.findFirst({
          where: { owner_type: "PLATFORM" },
        });
        if (!platformWallet) {
          throw new HttpError(
            404,
            req.t("admin-wallet:errors.platform_wallet_not_found"),
          );
        }

        // step: get updated user wallet balance after increment
        const updatedWallet = await tx.wallet.findUnique({
          where: { id: wallet_id },
        });
        let remainingBalance = Number(updatedWallet?.balance) || 0;

        // TODO-new: update platform wallet (platform_money)
        await tx.wallet.update({
          where: { id: platformWallet.id },
          data: { platform_money: { increment: amount } },
        });
        await tx.transaction.create({
          data: {
            wallet_id,
            processed_by: user.id,
            type: "MANUAL_INCREASE",
            status: "COMPLETED",
            amount: amount,
            description: `[adjustBalance] update platform wallet (platform_money)`,
          },
        });

        // step: fetch unpaid commissions (oldest first)
        const unpaidCommissions = await tx.unpaidCommission.findMany({
          where: {
            user_id: wallet.user_id,
            is_paid: false,
          },
          orderBy: { created_at: "asc" },
        });

        // step: deduct unpaid commissions from wallet balance
        for (const commission of unpaidCommissions) {
          if (remainingBalance <= 0) break;

          const commissionAmount = Number(commission.amount);

          // ✅ skip if can't fully cover
          if (remainingBalance < commissionAmount) continue;

          await tx.unpaidCommission.update({
            where: { id: commission.id },
            data: { is_paid: true, paid_at: new Date() },
          });

          await tx.transaction.create({
            data: {
              wallet_id,
              order_id: commission.order_id,
              processed_by: user.id,
              type: "PLATFORM_COD_COMMISSION",
              status: "COMPLETED",
              amount: -commissionAmount,
              description: `Commission deduction for order #${commission.order_id}`,
            },
          });

          await adjustWalletBalance(tx, wallet_id, -commissionAmount, {
            order_id: related_order_id,
          });

          await adjustWalletBalance(tx, platformWallet.id, commissionAmount, {
            order_id: related_order_id,
          });

          remainingBalance -= commissionAmount;
        }

        // step: fetch pending penalties (oldest first)
        const pendingPenalties = await tx.penalty.findMany({
          where: {
            user_id: wallet.user_id,
            is_paid: false,
            is_waived: false,
          },
          orderBy: { created_at: "asc" },
        });

        // step: deduct pending penalties from wallet balance
        for (const penalty of pendingPenalties) {
          if (remainingBalance <= 0) break;

          const penaltyAmount = Number(penalty.amount);

          // ✅ skip if can't fully cover
          if (remainingBalance < penaltyAmount) continue;

          await tx.penalty.update({
            where: { id: penalty.id },
            data: { is_paid: true, paid_at: new Date() },
          });

          await tx.transaction.create({
            data: {
              wallet_id,
              processed_by: user.id,
              type: "PENALTY",
              status: "COMPLETED",
              amount: -penaltyAmount,
              description: `Penalty payment: ${penalty.reason || "Penalty"}`,
            },
          });

          await adjustWalletBalance(tx, wallet_id, -penaltyAmount, {
            order_id: related_order_id,
          });

          await adjustWalletBalance(tx, platformWallet.id, penaltyAmount, {
            order_id: related_order_id,
          });

          remainingBalance -= penaltyAmount;
        }
      }
    });

    // step: return success response
    res.json({
      message: req.t("admin-wallet:messages.balance_adjusted"),
    });
  };

  // ============================ freeze ============================
  freeze = async (req: Request, res: Response, next: NextFunction) => {
    const { walletId } = req.sanitized.params;

    // step: get user
    const user = req.user;
    if (!user) {
      throw new HttpError(404, req.t("auth.errors.user_not_found"));
    }
    const { freeze_reason }: FreezeDTO = req.sanitized.body;

    // step: get selectedUser wallet
    const wallet = await prisma.wallet.findUnique({
      where: { id: Number(walletId) },
    });
    if (!wallet) {
      throw new HttpError(404, req.t("admin-wallet:errors.wallet_not_found"));
    }

    // step: freeze wallet
    await prisma.wallet.update({
      where: { id: Number(walletId) },
      data: {
        status: "FROZEN",
        freeze_reason,
        frozen_at: new Date(),
        frozen_by: user.id,
      },
    });

    res.json({
      message: req.t("admin-wallet:messages.wallet_frozen"),
    });
  };

  // ============================ unfreeze ============================
  unfreeze = async (req: Request, res: Response, next: NextFunction) => {
    const { walletId } = req.sanitized.params;

    // step: get user
    const user = req.user;
    if (!user) {
      throw new HttpError(404, req.t("auth.errors.user_not_found"));
    }

    // step: get wallet
    const wallet = await prisma.wallet.findUnique({
      where: { id: Number(walletId) },
    });
    if (!wallet) {
      throw new HttpError(404, req.t("admin-wallet:errors.wallet_not_found"));
    }

    // step: unfreeze selectedUser
    await prisma.wallet.update({
      where: { id: Number(walletId) },
      data: {
        status: "ACTIVE",
        freeze_reason: null,
        frozen_at: null,
        frozen_by: null,
      },
    });

    res.json({
      message: req.t("admin-wallet:messages.wallet_unfrozen"),
    });
  };

  // ============================ applyPenalty ============================
  applyPenalty = async (req: Request, res: Response, next: NextFunction) => {
    // step: get user
    const user = req.user;
    if (!user) {
      throw new HttpError(404, req.t("auth.errors.user_not_found"));
    }

    const { userId } = req.sanitized.params;
    const { amount, reason }: ApplyPenaltyDTO = req.sanitized.body;

    // step: get selected user
    const selectedUser = await prisma.user.findFirst({
      where: {
        id: Number(userId),
        role: {
          name: {
            not: "Admin",
          },
        },
      },
    });
    if (!selectedUser) {
      throw new HttpError(404, req.t("auth.errors.user_not_found"));
    }

    // step: invoke transaction
    const penalty = await prisma.$transaction(async (tx) => {
      // 1. Create Penalty Record
      let penalty = await tx.penalty.create({
        data: {
          user_id: selectedUser.id,
          amount,
          reason,
          created_by: user.id,
          is_paid: false,
        },
      });

      // 2. Check Wallet
      const wallet = await tx.wallet.findUnique({
        where: { user_id: selectedUser.id },
      });

      // 3. Deduct if sufficient balance
      if (wallet && Number(wallet.balance) >= amount) {
        // Update Wallet
        await adjustWalletBalance(tx, wallet.id, -amount);

        // Create Transaction
        await tx.transaction.create({
          data: {
            wallet_id: wallet.id,
            processed_by: user.id,
            type: "PENALTY",
            status: "COMPLETED",
            amount,
            description: `Penalty: ${reason}`,
          },
        });

        // Update Penalty to Paid
        penalty = await tx.penalty.update({
          where: { id: penalty.id },
          data: {
            is_paid: true,
            paid_at: new Date(),
          },
        });

        // step: Update Platform Wallet Balance
        const platformWallet = await tx.wallet.findFirst({
          where: { owner_type: "PLATFORM" },
        });
        if (!platformWallet) {
          throw new HttpError(
            404,
            req.t("admin-wallet:errors.platform_wallet_not_found"),
          );
        }
        await adjustWalletBalance(tx, platformWallet.id, amount);
      }
      return penalty;
    });

    res.json({
      message: req.t("admin-wallet:messages.penalty_applied"),
      data: {
        penalty,
      },
    });
  };

  // ============================ waivePenalty ============================
  waivePenalty = async (req: Request, res: Response, next: NextFunction) => {
    // step: get user
    const user = req.user;
    if (!user) {
      throw new HttpError(404, req.t("auth.errors.user_not_found"));
    }

    const { penaltyId } = req.sanitized.params;

    // step: get penalty
    const penalty = await prisma.penalty.findUnique({
      where: { id: Number(penaltyId) },
    });

    if (!penalty) {
      throw new HttpError(404, req.t("admin-wallet:errors.penalty_not_found"));
    }

    if (penalty.is_waived) {
      throw new HttpError(
        400,
        req.t("admin-wallet:errors.penalty_already_waived"),
      );
    }

    if (!penalty.user_id) {
      throw new HttpError(400, req.t("admin-wallet:errors.user_id_required"));
    }

    // step: invoke transaction
    await prisma.$transaction(async (tx) => {
      // 1. Mark Penalty as Waived
      await tx.penalty.update({
        where: { id: penalty.id },
        data: {
          is_waived: true,
          waived_at: new Date(),
          waived_by: user.id,
        },
      });

      // 2. Refund if it was paid
      if (penalty.is_paid) {
        const wallet = await tx.wallet.findUnique({
          where: { user_id: penalty.user_id || undefined },
        });

        if (wallet) {
          // Update Wallet
          await adjustWalletBalance(tx, wallet.id, Number(penalty.amount));

          await tx.transaction.create({
            data: {
              wallet_id: wallet.id,
              processed_by: user.id,
              type: "WAIVE_PENALTY",
              status: "COMPLETED",
              amount: penalty.amount,
              description: `Penalty Waiver Refund: ${penalty.reason}`,
            },
          });

          // step: Update Platform Wallet Balance
          const platformWallet = await tx.wallet.findFirst({
            where: { owner_type: "PLATFORM" },
          });
          if (!platformWallet) {
            throw new HttpError(
              404,
              req.t("admin-wallet:errors.platform_wallet_not_found"),
            );
          }
          await adjustWalletBalance(
            tx,
            platformWallet.id,
            -Number(penalty.amount),
          );
        }
      }
    });

    res.json({
      message: req.t("admin-wallet:messages.penalty_waived"),
      data: { penalty },
    });
  };

  // ============================ CPWR (Create Platform Wallet Record) ============================
  CPWR = async (req: Request, res: Response, next: NextFunction) => {
    // step: get user
    const user = req.user;
    if (!user) {
      throw new HttpError(404, req.t("auth.errors.user_not_found"));
    }

    // step: get body data
    const { user_id }: CPWRDTO = req.sanitized.body;

    // step: check if platform wallet already exists
    const existingWallet = await prisma.wallet.findFirst({
      where: { owner_type: "PLATFORM" },
    });

    if (existingWallet) {
      return res.json({
        message: req.t("admin-wallet:messages.platform_wallet_exists"),
        data: { wallet: existingWallet },
      });
    }

    // step: check if user_id already has a wallet
    const userWallet = await prisma.wallet.findUnique({
      where: { user_id },
    });

    if (userWallet) {
      throw new HttpError(
        400,
        req.t("admin-wallet:errors.user_already_has_wallet"),
      );
    }

    // step: create platform wallet
    const wallet = await prisma.wallet.create({
      data: {
        user_id,
        owner_type: "PLATFORM",
        balance: 0,
        status: "ACTIVE",
      },
    });

    res.json({
      message: req.t("admin-wallet:messages.platform_wallet_created"),
      data: { wallet },
    });
  };

  // ============================ GPWR (Get Platform Wallet Record) ============================
  GPWR = async (req: Request, res: Response, next: NextFunction) => {
    // step: get platform wallet
    const wallet = await prisma.wallet.findFirst({
      where: { owner_type: "PLATFORM" },
    });

    if (!wallet) {
      throw new HttpError(
        404,
        req.t("admin-wallet:errors.platform_wallet_not_found"),
      );
    }

    res.json({
      message: req.t("admin-wallet:messages.ok"),
      data: { wallet },
    });
  };

  // ============================ changeUserIdPWR (Change UserId Platform Wallet Record) ============================
  changeUserIdPWR = async (req: Request, res: Response, next: NextFunction) => {
    // step: get user
    const user = req.user;
    if (!user) {
      throw new HttpError(404, req.t("auth.errors.user_not_found"));
    }

    // step: check if current user is admin
    const currentUser = await prisma.user.findFirst({
      where: { id: user.id, role: { name: "Admin" } },
    });
    if (!currentUser) {
      throw new HttpError(403, req.t("admin-wallet:errors.user_not_admin"));
    }

    // step: get body data
    const { user_id }: ChangeUserIdPWRDTO = req.sanitized.body;

    // step: check if target user_id is admin
    const targetUser = await prisma.user.findFirst({
      where: { id: user_id, role: { name: "Admin" } },
    });
    if (!targetUser) {
      throw new HttpError(400, req.t("admin-wallet:errors.user_not_admin"));
    }

    // step: get platform wallet
    const wallet = await prisma.wallet.findFirst({
      where: { owner_type: "PLATFORM" },
    });

    if (!wallet) {
      throw new HttpError(
        404,
        req.t("admin-wallet:errors.platform_wallet_not_found"),
      );
    }

    // step: update platform wallet user_id
    const updatedWallet = await prisma.wallet.update({
      where: { id: wallet.id },
      data: { user_id },
    });

    res.json({
      message: req.t("admin-wallet:messages.platform_wallet_updated"),
      data: { wallet: updatedWallet },
    });
  };

  // ============================ incBalancePWR (Increment Balance Platform Wallet Record) ============================
  incBalancePWR = async (req: Request, res: Response, next: NextFunction) => {
    // step: get user
    const user = req.user;
    if (!user) {
      throw new HttpError(404, req.t("auth.errors.user_not_found"));
    }

    // step: check if current user is admin
    const currentUser = await prisma.user.findFirst({
      where: { id: user.id, role: { name: "Admin" } },
    });
    if (!currentUser) {
      throw new HttpError(403, req.t("admin-wallet:errors.user_not_admin"));
    }

    // step: get body data
    const { amount, description }: IncBalancePWRDTO = req.sanitized.body;

    // step: get platform wallet
    const wallet = await prisma.wallet.findFirst({
      where: { owner_type: "PLATFORM" },
    });

    if (!wallet) {
      throw new HttpError(
        404,
        req.t("admin-wallet:errors.platform_wallet_not_found"),
      );
    }

    // step: increment balance and create transaction
    await prisma.$transaction(async (tx) => {
      await adjustWalletBalance(tx, wallet.id, amount);

      await tx.transaction.create({
        data: {
          wallet_id: wallet.id,
          processed_by: user.id,
          type: "TOPUP",
          status: "COMPLETED",
          amount,
          description,
        },
      });
    });

    res.json({
      message: req.t("admin-wallet:messages.platform_wallet_updated"),
    });
  };

  // ============================ decBalancePWR (Decrement Balance Platform Wallet Record) ============================
  decBalancePWR = async (req: Request, res: Response, next: NextFunction) => {
    // step: get user
    const user = req.user;
    if (!user) {
      throw new HttpError(404, req.t("auth.errors.user_not_found"));
    }

    // step: check if current user is admin
    const currentUser = await prisma.user.findFirst({
      where: { id: user.id, role: { name: "Admin" } },
    });
    if (!currentUser) {
      throw new HttpError(403, req.t("admin-wallet:errors.user_not_admin"));
    }

    // step: get body data
    const { amount, description }: DecBalancePWRDTO = req.sanitized.body;

    // step: get platform wallet
    const wallet = await prisma.wallet.findFirst({
      where: { owner_type: "PLATFORM" },
    });
    if (!wallet) {
      throw new HttpError(
        404,
        req.t("admin-wallet:errors.platform_wallet_not_found"),
      );
    }

    // step: check if balance will go negative
    if (Number(wallet.balance) < amount) {
      throw new HttpError(
        400,
        req.t("admin-wallet:errors.insufficient_balance"),
      );
    }

    // step: decrement balance and create transaction
    await prisma.$transaction(async (tx) => {
      await adjustWalletBalance(tx, wallet.id, -amount);

      await tx.transaction.create({
        data: {
          wallet_id: wallet.id,
          processed_by: user.id,
          type: "WITHDRAWAL",
          status: "COMPLETED",
          amount,
          description,
        },
      });
    });

    res.json({
      message: req.t("admin-wallet:messages.platform_wallet_updated"),
    });
  };

  // ============================ settlingBalance ============================
  settlingBalance = async (req: Request, res: Response, next: NextFunction) => {
    // step: get user
    const user = req.user;
    if (!user) {
      throw new HttpError(404, req.t("admin-wallet:errors.user_not_found"));
    }

    // step: get body data
    const {
      target_user_id,
      target_owner_type,
      period_from: periodFromStr,
      period_to: periodToStr,
      note,
    }: SettlingBalanceDTO = req.sanitized.body;

    const getCairoStartOfDay = (d: Date) => {
      const parts = new Intl.DateTimeFormat("en-US", {
        timeZone: "Africa/Cairo",
        hour: "numeric",
        minute: "numeric",
        second: "numeric",
        hourCycle: "h23",
      }).formatToParts(d);

      const cHour = parseInt(parts.find((p) => p.type === "hour")!.value, 10);
      const cMinute = parseInt(parts.find((p) => p.type === "minute")!.value, 10);
      const cSecond = parseInt(parts.find((p) => p.type === "second")!.value, 10);

      const msSinceMidnight =
        (cHour * 3600 + cMinute * 60 + cSecond) * 1000 + d.getMilliseconds();
      return new Date(d.getTime() - msSinceMidnight);
    };

    const getCairoEndOfDay = (d: Date) => {
      const startOfDay = getCairoStartOfDay(d);
      const guessNextDay = new Date(startOfDay.getTime() + 25 * 3600 * 1000);
      const startOfNextDay = getCairoStartOfDay(guessNextDay);
      return new Date(startOfNextDay.getTime() - 1);
    };

    const periodFrom = periodFromStr ? new Date(periodFromStr) : null;
    let periodTo = periodToStr ? new Date(periodToStr) : null;

    const startOfTodayCairo = getCairoStartOfDay(new Date());

    if (periodFrom && periodFrom >= startOfTodayCairo) {
      throw new HttpError(
        400,
        req.t("admin-wallet:errors.invalid_date", {
          defaultValue: "Cannot settle balance for the current day or future dates",
        }),
      );
    }

    if (periodTo && periodTo >= startOfTodayCairo) {
      throw new HttpError(
        400,
        req.t("admin-wallet:errors.invalid_date", {
          defaultValue: "Cannot settle balance for the current day or future dates",
        }),
      );
    }

    if (!periodTo) {
      periodTo = new Date(startOfTodayCairo.getTime() - 1);
    } else {
      periodTo = getCairoEndOfDay(periodTo);
    }

    // step: validate date range
    if (periodFrom && periodTo && periodFrom > periodTo) {
      throw new HttpError(
        400,
        req.t("admin-wallet:errors.invalid_date_range", {
          defaultValue: "period_from must be before or equal to period_to",
        }),
      );
    }

    // step: get platform wallet
    const platformWallet = await prisma.wallet.findFirst({
      where: { owner_type: "PLATFORM" },
    });
    if (!platformWallet) {
      throw new HttpError(
        404,
        req.t("admin-wallet:errors.platform_wallet_not_found"),
      );
    }

    // step: check target_user_id existence
    let targetUser = null;
    let targetWallet = null;
    if (target_user_id) {
      targetUser = await prisma.user.findUnique({
        where: { id: target_user_id },
      });
      if (!targetUser) {
        throw new HttpError(404, req.t("admin-wallet:errors.user_not_found"));
      }
      targetWallet = await prisma.wallet.findUnique({
        where: { user_id: target_user_id },
      });
      if (!targetWallet) {
        throw new HttpError(404, req.t("admin-wallet:errors.wallet_not_found"));
      }
    }

    // ── helper: settle a single wallet ──
    const settleOneWallet = async (
      tx: Parameters<Parameters<typeof prisma.$transaction>[0]>[0],
      wallet: {
        id: number;
        user_id: number | null;
        owner_type: string;
        balance: number;
      },
      isplatformSelfSettle: boolean,
    ) => {
      const dateFilter: { gte?: Date; lte?: Date } = {};
      if (periodFrom) dateFilter.gte = periodFrom;
      if (periodTo) {
        dateFilter.lte = periodTo;
      }

      const unsettledEntries = await tx.walletEntry.findMany({
        where: {
          wallet_id: wallet.id,
          is_settled: false,
          ...(periodFrom || periodTo ? { created_at: dateFilter } : {}),
        },
        orderBy: { created_at: "asc" },
      });

      if (unsettledEntries.length === 0) {
        return null; // nothing to settle
      }

      // step: calculate net amount
      const netAmount = unsettledEntries.reduce(
        (sum, entry) => sum + entry.amount,
        0,
      );

      // step: skip if net is 0 or negative (nothing owed to the user)
      if (netAmount <= 0) {
        return null;
      }

      // step: for non-platform wallets, check platform_money can cover
      if (!isplatformSelfSettle) {
        const currentPlatformWallet = await tx.wallet.findUnique({
          where: { id: platformWallet.id },
        });
        if (Number(currentPlatformWallet?.platform_money) < netAmount) {
          return {
            wallet_id: wallet.id,
            user_id: wallet.user_id,
            skipped: true,
            reason: "insufficient_platform_money",
            net_amount: netAmount,
            entries_count: unsettledEntries.length,
          };
        }
      }

      // step: create settlement record
      const settlement = await tx.settlement.create({
        data: {
          wallet_id: wallet.id,
          processed_by: user.id,
          owner_type: wallet.owner_type as any,
          period_from: periodFrom,
          period_to: periodTo,
          total_amount: netAmount,
          wallets_count: 1,
          note: note || null,
        },
      });

      // step: mark entries as settled
      await tx.walletEntry.updateMany({
        where: {
          id: { in: unsettledEntries.map((e) => e.id) },
        },
        data: {
          is_settled: true,
          settled_at: new Date(),
          settlement_id: settlement.id,
        },
      });

      if (isplatformSelfSettle) {
        // step: platform self-settle: balance → platform_earnings (skipEntry: settling itself)
        await adjustWalletBalance(tx, wallet.id, -netAmount, {
          skipEntry: true,
        });
        await tx.wallet.update({
          where: { id: wallet.id },
          data: {
            platform_earnings: { increment: netAmount },
            platform_money: { decrement: netAmount },
          },
        });
      } else {
        // step: regular settle: deduct the settled amount from target wallet (skipEntry: settling itself)
        await adjustWalletBalance(tx, wallet.id, -netAmount, {
          skipEntry: true,
        });

        // step: decrement platform_money
        await tx.wallet.update({
          where: { id: platformWallet.id },
          data: { platform_money: { decrement: netAmount } },
        });
      }

      // step: fetch updated balances for response
      const updatedWallet = await tx.wallet.findUnique({
        where: { id: wallet.id },
      });
      const updatedPlatformWallet = await tx.wallet.findUnique({
        where: { id: platformWallet.id },
      });

      return {
        wallet_id: wallet.id,
        user_id: wallet.user_id,
        settlement_id: settlement.id,
        settled_entries_count: unsettledEntries.length,
        net_amount: netAmount,
        wallet_balance_before: wallet.balance,
        wallet_balance_after: updatedWallet?.balance,
        platform_money_after: updatedPlatformWallet?.platform_money,
        platform_earnings_after: updatedPlatformWallet?.platform_earnings,
      };
    };

    // TODO - Transaction:
    await prisma.$transaction(
      async (tx) => {
        // *step1: if target_owner_type is PLATFORM (platform self-settle)
        if (target_owner_type && target_owner_type === "PLATFORM") {
          const result = await settleOneWallet(tx, platformWallet as any, true);

          if (!result) {
            return res.json({
              message: req.t("admin-wallet:messages.balance_already_zero", {
                defaultValue: "No unsettled entries found in this period",
              }),
            });
          }

          return res.json({
            message: req.t("admin-wallet:messages.done"),
            data: result,
          });
        }

        // *step2: if specific target_user_id passed
        if (targetWallet && !target_owner_type) {
          const result = await settleOneWallet(tx, targetWallet as any, false);

          if (!result) {
            return res.json({
              message: req.t("admin-wallet:messages.balance_already_zero", {
                defaultValue: "No unsettled entries found in this period",
              }),
            });
          }

          if (result.skipped) {
            throw new HttpError(
              400,
              req.t("admin-wallet:errors.insufficient_platform_money"),
            );
          }

          return res.json({
            message: req.t("admin-wallet:messages.done"),
            data: result,
          });
        }

        // *step3: if target_owner_type passed (bulk settle by owner type)
        if (!target_user_id && target_owner_type) {
          const targetWallets = await tx.wallet.findMany({
            where: { owner_type: target_owner_type },
          });

          const results = [];
          const skipped = [];

          for (const wallet of targetWallets) {
            if (wallet.owner_type === "PLATFORM") continue;

            const result = await settleOneWallet(tx, wallet as any, false);
            if (!result) continue;

            if (result.skipped) {
              skipped.push(result);
            } else {
              results.push(result);
            }
          }

          return res.json({
            message: req.t("admin-wallet:messages.done"),
            data: {
              owner_type: target_owner_type,
              period_from: periodFrom,
              period_to: periodTo,
              settled_count: results.length,
              skipped_count: skipped.length,
              results,
              skipped,
            },
          });
        }

        // *step4: if body has no target (settle all non-platform wallets)
        if (!target_user_id && !target_owner_type) {
          const ownerTypes = ["CUSTOMER", "COURIER", "SUPPLIER"] as const;
          const allResults: Record<string, any[]> = {};
          const allSkipped: Record<string, any[]> = {};

          for (const ownerType of ownerTypes) {
            const targetWallets = await tx.wallet.findMany({
              where: { owner_type: ownerType },
            });

            const results = [];
            const skipped = [];

            for (const wallet of targetWallets) {
              const result = await settleOneWallet(tx, wallet as any, false);
              if (!result) continue;

              if (result.skipped) {
                skipped.push(result);
              } else {
                results.push(result);
              }
            }

            allResults[ownerType] = results;
            allSkipped[ownerType] = skipped;
          }

          res.json({
            message: req.t("admin-wallet:messages.done"),
            data: {
              period_from: periodFrom,
              period_to: periodTo,
              settled_counts: {
                CUSTOMER: allResults["CUSTOMER"].length,
                COURIER: allResults["COURIER"].length,
                SUPPLIER: allResults["SUPPLIER"].length,
              },
              skipped_counts: {
                CUSTOMER: allSkipped["CUSTOMER"].length,
                COURIER: allSkipped["COURIER"].length,
                SUPPLIER: allSkipped["SUPPLIER"].length,
              },
              results: allResults,
              skipped: allSkipped,
            },
          });
        }
      },
      { timeout: 60000 },
    );
  };

  // ============================ settlementReport ============================
  settlementReport = async (
    req: Request,
    res: Response,
    next: NextFunction,
  ) => {
    const { user_id, period_from, period_to, page, limit } = res.locals
      .validatedData as SettlementReportDTO;

    const whereCondition: Prisma.WalletEntryWhereInput = {};

    if (period_from || period_to) {
      whereCondition.created_at = {};
      if (period_from) whereCondition.created_at.gte = new Date(period_from);
      if (period_to) whereCondition.created_at.lte = new Date(period_to);
    }

    if (user_id) {
      whereCondition.wallet = { user_id };
    }

    const skip = (page! - 1) * limit!;

    const [entries, total_entries] = await prisma.$transaction([
      prisma.walletEntry.findMany({
        where: whereCondition,
        skip,
        take: limit,
        include: {
          wallet: {
            select: {
              id: true,
              owner_type: true,
              user: {
                select: { id: true, full_name: true, phone: true },
              },
              externalApp: {
                select: { id: true, name: true },
              },
            },
          },
          settlement: {
            select: {
              id: true,
              created_at: true,
              processedBy: {
                select: { id: true, full_name: true },
              },
            },
          },
          order: {
            select: {
              id: true,
              order_number: true,
              status: true,
              payable_amount: true,
              actual_price: true,
              created_at: true,
            },
          },
          penalty: {
            select: {
              id: true,
              amount: true,
              reason: true,
              is_paid: true,
              created_at: true,
            },
          },
          unpaidCommission: {
            select: {
              id: true,
              amount: true,
              is_paid: true,
              created_at: true,
            },
          },
          customerCoupon: {
            select: {
              id: true,
              code: true,
              type: true,
              discount_type: true,
              discount_value: true,
              wallet_amount_cents: true,
              wallet_points: true,
              is_active: true,
            },
          },
          courierCoupon: {
            select: {
              id: true,
              title: true,
              price: true,
              bonus_courier_fee: true,
              duration_days: true,
              is_active: true,
            },
          },
        },
        orderBy: { created_at: "desc" },
      }),
      prisma.walletEntry.count({ where: whereCondition }),
    ]);

    const formattedEntries = entries.map((entry) => {
      let explanation = "Manual adjustment";
      if (entry.order_id) {
        explanation = `Order earning / cost (Order ID: ${entry.order_id})`;
      } else if (entry.penalty_id) {
        explanation = `Penalty deduction (Penalty ID: ${entry.penalty_id})`;
      } else if (entry.unpaid_commission_id) {
        explanation = `Unpaid commission settled (Commission ID: ${entry.unpaid_commission_id})`;
      } else if (entry.customer_coupon_id) {
        explanation = `Customer coupon reward (Coupon ID: ${entry.customer_coupon_id})`;
      } else if (entry.courier_coupon_id) {
        explanation = `Courier coupon reward (Coupon ID: ${entry.courier_coupon_id})`;
      } else if (entry.points_to_money) {
        explanation = `Points converted to money (${entry.points_to_money})`;
      } else if (entry.settlement_id) {
        explanation = `Balance settlement payout (Settlement ID: ${entry.settlement_id})`;
      }

      if (entry.notes) {
        explanation = entry.notes;
      }

      return {
        id: entry.id,
        wallet: entry.wallet,
        amount_cents: entry.amount,
        amount_egp: entry.amount / 100,
        type: entry.amount >= 0 ? "CREDIT" : "DEBIT",
        points_to_money: entry.points_to_money,
        notes: entry.notes,
        explanation,
        is_settled: entry.is_settled,
        settled_at: entry.settled_at,
        settlement_details: entry.settlement,
        created_at: entry.created_at,
        order: entry.order,
        penalty: entry.penalty,
        unpaid_commission: entry.unpaidCommission,
        customer_coupon: entry.customerCoupon,
        courier_coupon: entry.courierCoupon,
      };
    });

    res.json({
      message: req.t("admin-wallet:messages.ok"),
      data: {
        period_from: period_from || null,
        period_to: period_to || null,
        pagination: {
          page: page!,
          limit: limit!,
          total_entries,
          total_pages: Math.ceil(total_entries / limit!),
        },
        entries: formattedEntries,
      },
    });
  };

  // ============================ settlementReport2 ============================
  settlementReport2 = async (
    req: Request,
    res: Response,
    next: NextFunction,
  ) => {
    const queryOptions = new FeatureApi(req) // queryOptions :{where, orderBy, take, skip}
      .filter()
      .sort("-created_at") // ?sort=-created_at
      .limit(10) // ?limit=10
      .skip(0) // ?skip=0
      .includes() // ?includes=role=id-name,wallet,penalties
      .keyword([]) // ?keyword=xxx&items=reason_ar,reason_en
      .fields().data; // ?fields=id,reason_ar,reason_en

    const [totalWalletEntry, walletEntries] = await prisma.$transaction([
      prisma.walletEntry.count({
        ...(queryOptions.where ? { where: queryOptions.where } : {}),
      }),
      prisma.walletEntry.findMany(queryOptions as any),
    ]);

    return res.status(200).json({
      message: req.t("admin-wallet:messages.ok"),
      data: {
        totalWalletEntry,
        totalPages: Math.ceil(totalWalletEntry / (queryOptions.take ?? 10)),
        walletEntries,
      },
    });
  };
}
