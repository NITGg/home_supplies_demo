import type { Response } from "express";
import FeatureApi from "@/lib/featureApi";
import type { AuthedRequest } from "@/types/authedRequest";
import {
  createCourierReviewFromCustomerSchema,
  createSupplierReviewFromCustomerSchema,
  customerReviewIdParamSchema,
  deleteManyCustomerReviewsSchema,
  supplierReviewSourceSchema,
} from "./customer-reviews.schema";
import {
  createCourierReviewFromCustomerService,
  createSupplierReviewFromCustomerService,
  deleteCustomerReviewService,
  deleteManyCustomerReviewsService,
  deleteSupplierReviewService,
  getCourierReceivedReviewByIdService,
  getCustomerReviewByIdService,
  getMyGivenReviewByIdService,
  getSupplierReviewByIdService,
  listCourierReceivedReviewsService,
  listCourierReviewsAdminService,
  listCustomerReviewsAdminService,
  listCustomerReviewsService,
  listMyGivenReviewsService,
  listSupplierReviewsService,
} from "./customer-reviews.service";

export async function customerCreateCourierReview(
  req: AuthedRequest,
  res: Response,
) {
  const data = createCourierReviewFromCustomerSchema.parse(req.sanitized.body);
  const review = await createCourierReviewFromCustomerService({
    userId: req.user.id,
    data,
  });

  return res.status(201).json({
    message: req.t?.("customer-reviews:messages.created") ?? "Courier review created",
    review,
  });
}

export async function customerCreateSupplierReview(
  req: AuthedRequest,
  res: Response,
) {
  const data = createSupplierReviewFromCustomerSchema.parse(req.sanitized.body);
  const review = await createSupplierReviewFromCustomerService({
    userId: req.user.id,
    data,
  });

  return res.status(201).json({
    message:
      req.t?.("customer-reviews:messages.supplier_created") ??
      "Supplier review created",
    review,
  });
}

export async function courierListReceivedReviews(
  req: AuthedRequest,
  res: Response,
) {
  const data = new FeatureApi(req)
    .filter({}, { allowKeys: ["customer_id", "order_id", "rating"] })
    .sort("-created_at")
    .limit(20)
    .skip()
    .includes()
    .fields().data;

  const result = await listCourierReceivedReviewsService({
    userId: req.user.id,
    data,
  });

  return res.json(result);
}

export async function courierGetReceivedReviewById(
  req: AuthedRequest,
  res: Response,
) {
  const { id } = customerReviewIdParamSchema.parse(req.sanitized.params);
  const review = await getCourierReceivedReviewByIdService({
    id,
    userId: req.user.id,
  });

  return res.json({ review });
}

export async function customerListMyGivenReviews(
  req: AuthedRequest,
  res: Response,
) {
  const data = new FeatureApi(req)
    .filter({}, { allowKeys: ["courier_id", "order_id", "rating"] })
    .sort("-created_at")
    .limit(20)
    .skip()
    .includes()
    .fields().data;

  const result = await listMyGivenReviewsService({
    userId: req.user.id,
    data,
  });

  return res.json(result);
}

export async function customerGetMyGivenReviewById(
  req: AuthedRequest,
  res: Response,
) {
  const { id } = customerReviewIdParamSchema.parse(req.sanitized.params);
  const review = await getMyGivenReviewByIdService({
    id,
    userId: req.user.id,
  });

  return res.json({ review });
}

export async function adminListCustomerReviews(req: AuthedRequest, res: Response) {
  const data = new FeatureApi(req)
    .filter()
    .sort("-created_at")
    .limit(20)
    .skip()
    .includes()
    .keyword(["comment"], "OR")
    .fields().data;

  const result = await listCustomerReviewsService(data);
  return res.json(result);
}

export async function adminGetCustomerReview(req: AuthedRequest, res: Response) {
  const { id } = customerReviewIdParamSchema.parse(req.sanitized.params);
  const review = await getCustomerReviewByIdService({ id });
  return res.json({ review });
}

export async function adminDeleteCustomerReview(
  req: AuthedRequest,
  res: Response,
) {
  const { id } = customerReviewIdParamSchema.parse(req.sanitized.params);
  await deleteCustomerReviewService({ id });

  return res.json({
    message: req.t?.("customer-reviews:messages.deleted") ?? "Courier review deleted",
  });
}

export async function adminDeleteManyCustomerReviews(
  req: AuthedRequest,
  res: Response,
) {
  const input = deleteManyCustomerReviewsSchema.parse(req.sanitized.body);
  const result = await deleteManyCustomerReviewsService(input);

  return res.json({
    message: req.t?.("customer-reviews:messages.deleted") ?? "Courier reviews deleted",
    ...result,
  });
}

export async function adminListSupplierReviews(req: AuthedRequest, res: Response) {
  const data = new FeatureApi(req)
    .filter({}, { allowKeys: ["supplier_id", "order_id", "rating", "user_id", "courier_id"] })
    .sort("-created_at")
    .limit(20)
    .skip()
    .includes()
    .keyword(["comment"], "OR")
    .fields().data;

  const reviewFrom = req.query.review_from as string | undefined;
  const result = await listSupplierReviewsService(data, reviewFrom);
  return res.json(result);
}

export async function adminGetSupplierReview(req: AuthedRequest, res: Response) {
  const { id } = customerReviewIdParamSchema.parse(req.sanitized.params);
  const { review_from } = supplierReviewSourceSchema.parse(req.sanitized.body);
  const review = await getSupplierReviewByIdService({ id, review_from });
  return res.json({ review });
}

export async function adminDeleteSupplierReview(
  req: AuthedRequest,
  res: Response,
) {
  const { id } = customerReviewIdParamSchema.parse(req.sanitized.params);
  const { review_from } = supplierReviewSourceSchema.parse(req.sanitized.body);
  await deleteSupplierReviewService({ id, review_from });

  return res.json({
    message:
      req.t?.("customer-reviews:messages.supplier_deleted") ??
      "Supplier review deleted",
  });
}

export async function adminListCourierReviews(req: AuthedRequest, res: Response) {
  const data = new FeatureApi(req)
    .filter({}, { allowKeys: ["courier_id", "order_id", "rating", "customer_id", "supplier_id"] })
    .sort("-created_at")
    .limit(20)
    .skip()
    .includes()
    .keyword(["comment"], "OR")
    .fields().data;

  const reviewFrom = req.query.review_from as string | undefined;
  const result = await listCourierReviewsAdminService(data, reviewFrom);
  return res.json(result);
}

export async function adminListCustomerReviewsFromCourier(req: AuthedRequest, res: Response) {
  const data = new FeatureApi(req)
    .filter({}, { allowKeys: ["customer_id", "courier_id", "order_id", "rating"] })
    .sort("-created_at")
    .limit(20)
    .skip()
    .includes()
    .keyword(["comment"], "OR")
    .fields().data;

  const result = await listCustomerReviewsAdminService(data);
  return res.json(result);
}
