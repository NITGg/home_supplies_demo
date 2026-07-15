import { NextFunction, Request, Response } from "express";
import { responseHandler } from "../../core/handlers/response.handler";
import { prisma } from "../../DB/lib/prisma";
import { HttpStatusCode } from "../../core/http/http.status.code";
import { BuyCouponParamsDTO, CouponHistoryQueryDTO } from "./coupon.dto";
import { applyFilters, buildPaginationResponse } from "../../utils/filter";
import { AppError } from "../../core/errors/app.error";

export class CouponService {
  constructor() {}

  // ============================ listAvalilable ============================
  listAvalilable = async (req: Request, res: Response, next: NextFunction) => {
    // step: get all active coupons
    const coupons = await prisma.courierCoupon.findMany({
      where: {
        is_active: true,
        deleted_at: null,
      },
      orderBy: { created_at: "desc" },
    });

    return responseHandler({
      res,
      message: res.__("messages.coupons_retrieved"),
      data: { coupons },
    });
  };

  // ============================ buyCoupon ============================
  buyCoupon = async (req: Request, res: Response, next: NextFunction) => {
    const user = res.locals.user;
    const { id }: BuyCouponParamsDTO = req.params as any;

    // step: find coupon
    const coupon = await prisma.courierCoupon.findFirst({
      where: {
        id: Number(id),
        is_active: true,
        deleted_at: null,
      },
    });
    if (!coupon) {
      return responseHandler({
        res,
        status: HttpStatusCode.NOT_FOUND,
        message: res.__("errors.coupon_not_found"),
      });
    }

    // step: check if courier already has an active coupon
    const activeCoupon = await prisma.courierCouponUsage.findFirst({
      where: {
        user_id: user.id,
        end_date: { gt: new Date() },
      },
    });
    if (activeCoupon) {
      return responseHandler({
        res,
        status: HttpStatusCode.CONFLICT,
        message: res.__("errors.already_has_active_coupon"),
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

    // step: check sufficient balance
    const couponPrice = Number(coupon.price);
    if (wallet.balance < couponPrice) {
      return responseHandler({
        res,
        status: HttpStatusCode.BAD_REQUEST,
        message: res.__("errors.insufficient_balance"),
      });
    }

    // step: process purchase in a transaction
    const now = new Date();
    const endDate = new Date(now);
    endDate.setDate(endDate.getDate() + coupon.duration_days);

    const couponUsage = await prisma.$transaction(async (tx) => {
      // step: deduct from wallet
      await tx.wallet.update({
        where: { id: wallet.id },
        data: { balance: { decrement: couponPrice } },
      });

      // step: create coupon usage
      const usage = await tx.courierCouponUsage.create({
        data: {
          user_id: user.id,
          coupon_id: coupon.id,
          start_date: now,
          end_date: endDate,
          snapshot_price: coupon.price,
          snapshot_bonus_courier_fee: coupon.bonus_courier_fee,
        },
        include: { coupon: true },
      });

      // step: create transaction record
      await tx.transaction.create({
        data: {
          wallet_id: wallet.id,
          type: "COUPON_PURCHASE",
          status: "COMPLETED",
          amount: couponPrice,
          description: `Coupon purchase: ${coupon.title}`,
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
          balance: { increment: couponPrice },
        },
      });

      return usage;
    });

    return responseHandler({
      res,
      status: HttpStatusCode.CREATED,
      message: res.__("messages.coupon_purchased"),
      data: { couponUsage },
    });
  };

  // ============================ active ============================
  active = async (req: Request, res: Response, next: NextFunction) => {
    const user = res.locals.user;

    // step: find active coupon
    const activeCoupon = await prisma.courierCouponUsage.findFirst({
      where: {
        user_id: user.id,
        end_date: { gt: new Date() },
      },
      include: { coupon: true },
      orderBy: { created_at: "desc" },
    });

    if (!activeCoupon) {
      return responseHandler({
        res,
        message: res.__("messages.no_active_coupon"),
        data: { activeCoupon: null },
      });
    }

    return responseHandler({
      res,
      message: res.__("messages.active_coupon_retrieved"),
      data: { activeCoupon },
    });
  };

  // ============================ history ============================
  history = async (req: Request, res: Response, next: NextFunction) => {
    const user = res.locals.user;

    // step: apply filters
    const { filters, pagination, paginationMeta } = applyFilters(
      res.locals.validatedData,
      {
        coupon_id: "exact",
        start_date: "dateRange",
        end_date: "dateRange",
        snapshot_price: "range",
        snapshot_bonus_courier_fee: "range",
        created_at: "dateRange",
      },
    );

    // Apply strict filters
    filters.user_id = user.id;

    // step: get paginated history
    const [couponHistory, total] = await Promise.all([
      prisma.courierCouponUsage.findMany({
        where: filters,
        include: { coupon: true },
        orderBy: { created_at: "desc" },
        ...pagination,
      }),
      prisma.courierCouponUsage.count({ where: filters }),
    ]);

    return responseHandler({
      res,
      message: res.__("messages.coupon_history_retrieved"),
      data: {
        couponHistory,
        pagination: buildPaginationResponse(paginationMeta, total),
      },
    });
  };
}
