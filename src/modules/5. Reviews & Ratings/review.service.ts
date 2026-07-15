import { NextFunction, Request, Response } from "express";
import { SubmitReviewDTO } from "./review.dto";
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

    // step: Apply filters
    const { filters, pagination, paginationMeta } = applyFilters(
      res.locals.validatedData,
      {
        rating: "range",
        created_at: "dateRange",
      },
    );

    // Apply strict filters
    filters.courier_id = courier.id;

    const [reviews, total, supplierReviews] = await Promise.all([
      prisma.courierReviewFromCustomer.findMany({
        where: filters,
        include: {
          customer: {
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
      prisma.courierReviewFromCustomer.count({
        where: filters,
      }),
      prisma.courierReviewFromSupplier.findMany({
        where: filters,
        include: {
          supplier: {
            select: {
              id: true,
              user: {
                select: {
                  full_name: true,
                  personal_photo: true,
                },
              },
            },
          },
        },
        orderBy: { created_at: "desc" },
        ...pagination,
      }),
    ]);

    return responseHandler({
      res,
      message: res.__("messages.reviews_retrieved"),
      data: {
        reviews,
        supplierReviews,
        pagination: buildPaginationResponse(paginationMeta, total),
      },
    });
  };

  // ============================ reviewStatus ============================
  reviewStatus = async (req: Request, res: Response, next: NextFunction) => {
    const orderId = parseInt(req.params.orderId as string);
    const courierId = req.params.courierId
      ? parseInt(req.params.courierId as string)
      : undefined;

    // step: validate orderId
    if (isNaN(orderId)) {
      throw new AppError(
        HttpStatusCode.BAD_REQUEST,
        res.__("errors.invalid_order_id"),
      );
    }

    // step: validate courierId if provided
    if (req.params.courierId && isNaN(courierId!)) {
      throw new AppError(
        HttpStatusCode.BAD_REQUEST,
        res.__("errors.invalid_courier_id"),
      );
    }

    const whereCustomer = { order_id: orderId, ...(courierId && { courier_id: courierId }) };
    const whereSupplier = { order_id: orderId, ...(courierId && { courier_id: courierId }) };

    // step: check both review tables in parallel
    const [customerReview, supplierReview] = await Promise.all([
      prisma.courierReviewFromCustomer.findFirst({
        where: whereCustomer,
        select: {
          id: true,
          rating: true,
          comment: true,
          created_at: true,
          customer: {
            select: {
              id: true,
              full_name: true,
              personal_photo: true,
            },
          },
        },
      }),
      prisma.courierReviewFromSupplier.findFirst({
        where: whereSupplier,
        select: {
          id: true,
          rating: true,
          comment: true,
          created_at: true,
          supplier: {
            select: {
              id: true,
              user: {
                select: {
                  full_name: true,
                  personal_photo: true,
                },
              },
            },
          },
        },
      }),
    ]);

    const reviewedBy: string[] = [];
    if (customerReview) reviewedBy.push("customer");
    if (supplierReview) reviewedBy.push("supplier");

    return responseHandler({
      res,
      message: res.__("messages.review_status_retrieved"),
      data: {
        reviewed_by_customer: !!customerReview,
        reviewed_by_supplier: !!supplierReview,
        reviewed_by: reviewedBy,
        customer_review: customerReview ?? null,
        supplier_review: supplierReview ?? null,
      },
    });
  };

  // ============================ getReview ============================
  getReview = async (req: Request, res: Response, next: NextFunction) => {
    const user = res.locals.user;
    const orderId = parseInt(req.params.orderId as string);

    // step: validate orderId
    if (isNaN(orderId)) {
      throw new AppError(
        HttpStatusCode.BAD_REQUEST,
        res.__("errors.invalid_order_id"),
      );
    }

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

    // step: get review submitted by courier for this order
    const review = await prisma.customerReviewFromCourier.findFirst({
      where: {
        order_id: orderId,
        courier_id: courier.id,
      },
      include: {
        customer: {
          select: {
            id: true,
            full_name: true,
            personal_photo: true,
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
    const orderId = parseInt(req.params.orderId as string);
    const { rating, comment }: SubmitReviewDTO = req.body;

    // step: validate orderId
    if (isNaN(orderId)) {
      throw new AppError(
        HttpStatusCode.BAD_REQUEST,
        res.__("errors.invalid_order_id"),
      );
    }

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

    // step: verify order has a customer
    if (!order.customer_id) {
      throw new AppError(
        HttpStatusCode.INTERNAL_SERVER_ERROR,
        res.__("errors.order_missing_customer"),
      );
    }

    // step: check if review already exists
    const existingReview = await prisma.customerReviewFromCourier.findFirst({
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
    const review = await prisma.customerReviewFromCourier.create({
      data: {
        courier_id: courier.id,
        customer_id: order.customer_id,
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

  // ============================ submitSupplierReview ============================
  submitSupplierReview = async (
    req: Request,
    res: Response,
    next: NextFunction,
  ) => {
    const user = res.locals.user;
    const orderId = parseInt(req.params.orderId as string);
    const { rating, comment }: SubmitReviewDTO = req.body;

    // step: validate orderId
    if (isNaN(orderId)) {
      throw new AppError(
        HttpStatusCode.BAD_REQUEST,
        res.__("errors.invalid_order_id"),
      );
    }

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

    // step: verify order has been collected
    if (!order.order_collected_at) {
      throw new AppError(
        HttpStatusCode.BAD_REQUEST,
        res.__("errors.order_not_collected"),
      );
    }

    // step: verify order has a supplier
    if (!order.supplier_id) {
      throw new AppError(
        HttpStatusCode.BAD_REQUEST,
        res.__("errors.order_has_no_supplier"),
      );
    }

    // step: check if review already exists
    const existingReview = await prisma.supplierReviewFromCourier.findFirst({
      where: {
        order_id: orderId,
        courier_id: courier.id,
      },
    });

    if (existingReview) {
      throw new AppError(
        HttpStatusCode.BAD_REQUEST,
        res.__("errors.already_reviewed_supplier"),
      );
    }

    // step: create review
    const review = await prisma.supplierReviewFromCourier.create({
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
