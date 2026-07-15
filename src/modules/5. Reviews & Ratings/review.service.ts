import { NextFunction, Request, Response } from "express";
import { AppError } from "../../core/errors/app.error";
import { responseHandler } from "../../core/handlers/response.handler";
import { HttpStatusCode } from "../../core/http/http.status.code";
import { prisma } from "../../DB/lib/prisma";
import { OrderStatus } from "@prisma/client";
import { applyFilters, buildPaginationResponse } from "../../utils/filter";

export class ReviewService {
  constructor() {}

  // ============================ allReviews ============================
  allReviews = async (req: Request, res: Response, next: NextFunction) => {
    const user = res.locals.user;

    // step: get supplier
    const supplier = await prisma.supplier.findUnique({
      where: { user_id: user.id },
    });

    if (!supplier) {
      throw new AppError(
        HttpStatusCode.FORBIDDEN,
        res.__("errors.not_supplier"),
      );
    }

    // step: Apply filters
    const { filters, pagination, paginationMeta } = applyFilters(
      res.locals.validatedData,
      {
        rating: "range",
        created_at: "dateRange",
      },
    );

    // step: Apply strict filters
    filters.supplier_id = supplier.id;

    // step: Get reviews1
    const [supplierReviewFromCustomer, totalSupplierReviewFromCustomer] =
      await Promise.all([
        prisma.supplierReviewFromCustomer.findMany({
          where: filters,
          include: {
            user: {
              select: {
                id: true,
                full_name: true,
                personal_photo: true,
              },
            },
          },
          orderBy: { created_at: "desc" },
          ...pagination,
        }),
        prisma.supplierReviewFromCustomer.count({
          where: filters,
        }),
      ]);

    // step: Get reviews1
    const [supplierReviewFromCourier, totalSupplierReviewFromCourier] =
      await Promise.all([
        prisma.supplierReviewFromCourier.findMany({
          where: filters,
          include: {
            courier: {
              select: {
                id: true,
              },
            },
          },
          orderBy: { created_at: "desc" },
          ...pagination,
        }),
        prisma.supplierReviewFromCourier.count({
          where: filters,
        }),
      ]);

    return responseHandler({
      res,
      message: res.__("messages.reviews_retrieved"),
      data: {
        supplierReviewFromCourier,
        courierPagination: buildPaginationResponse(
          paginationMeta,
          totalSupplierReviewFromCourier,
        ),
        supplierReviewFromCustomer,
        customerPagination: buildPaginationResponse(
          paginationMeta,
          totalSupplierReviewFromCustomer,
        ),
      },
    });
  };

  // ============================ getReview ============================
  getReview = async (req: Request, res: Response, next: NextFunction) => {
    const user = res.locals.user;
    const { orderId } = res.locals.validatedData as { orderId: number };

    // step: get supplier
    const supplier = await prisma.supplier.findUnique({
      where: { user_id: user.id },
    });

    if (!supplier) {
      throw new AppError(
        HttpStatusCode.FORBIDDEN,
        res.__("errors.not_supplier"),
      );
    }

    // step: get review submitted by supplier for this order
    const review = await prisma.courierReviewFromSupplier.findFirst({
      where: {
        order_id: orderId,
        supplier_id: supplier.id,
      },
      include: {
        courier: {
          select: {
            id: true,
          },
        },
      },
    });

    if (!review) {
      throw new AppError(
        HttpStatusCode.NOT_FOUND,
        res.__("errors.review_not_found"),
      );
    }

    return responseHandler({
      res,
      message: res.__("messages.review_retrieved"),
      data: { review },
    });
  };

  // ============================ submitReview ============================
  submitReview = async (req: Request, res: Response, next: NextFunction) => {
    const user = res.locals.user;
    const { orderId, rating, comment } = res.locals.validatedData as {
      orderId: number;
      rating: number;
      comment?: string;
    };

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
    });

    if (!order) {
      throw new AppError(
        HttpStatusCode.NOT_FOUND,
        res.__("errors.order_not_found"),
      );
    }

    // step: verify courier delivered this order
    if (order.courier_id !== courier.id) {
      throw new AppError(
        HttpStatusCode.FORBIDDEN,
        res.__("errors.not_assigned_to_order"),
      );
    }

    // step: verify order status is DELIVERED
    if (order.status !== OrderStatus.DELIVERED) {
      throw new AppError(
        HttpStatusCode.BAD_REQUEST,
        res.__("errors.order_not_delivered"),
      );
    }

    // step: verify order has a supplier
    if (!order.supplier_id) {
      throw new AppError(
        HttpStatusCode.INTERNAL_SERVER_ERROR,
        res.__("errors.order_missing_supplier"),
      );
    }

    // step: check if review already exists
    const existingReview = await prisma.courierReviewFromSupplier.findFirst({
      where: {
        order_id: orderId,
        courier_id: courier.id,
      },
    });

    if (existingReview) {
      throw new AppError(
        HttpStatusCode.BAD_REQUEST,
        res.__("errors.already_reviewed"),
      );
    }

    // step: create review
    const review = await prisma.courierReviewFromSupplier.create({
      data: {
        courier_id: courier.id,
        supplier_id: order.supplier_id,
        order_id: orderId,
        rating,
        comment: comment || null,
      },
    });

    return responseHandler({
      res,
      message: res.__("messages.review_submitted"),
      data: { review },
    });
  };
}
