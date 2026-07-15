import type { Response } from "express";
import FeatureApi from "@/lib/featureApi";
import type { AuthedRequest } from "@/types/authedRequest";
import {
  courierReviewIdParamSchema,
  createCustomerReviewFromCourierSchema,
  deleteManyCourierReviewsSchema,
  updateCustomerReviewFromCourierSchema,
} from "./courier-reviews.schema";
import {
  createCustomerReviewFromCourierService,
  deleteCourierReviewService,
  deleteManyCourierReviewsService,
  getCourierReviewByIdService,
  getCustomerReceivedReviewByIdService,
  listCourierReviewsService,
  listCustomerReceivedReviewsService,
  updateCustomerReviewFromCourierService,
} from "./courier-reviews.service";

export async function customerListReceivedCourierReviews(
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

  const result = await listCustomerReceivedReviewsService({
    userId: req.user.id,
    data,
  });

  return res.json(result);
}

export async function customerGetReceivedCourierReviewById(
  req: AuthedRequest,
  res: Response,
) {
  const { id } = courierReviewIdParamSchema.parse(req.sanitized.params);
  const review = await getCustomerReceivedReviewByIdService({
    id,
    userId: req.user.id,
  });

  return res.json({ review });
}

export async function adminListCourierReviews(
  req: AuthedRequest,
  res: Response,
) {
  const data = new FeatureApi(req)
    .filter()
    .sort("-created_at")
    .limit(20)
    .skip()
    .includes()
    .keyword(["comment"], "OR")
    .fields().data;

  const result = await listCourierReviewsService(data);
  return res.json(result);
}

export async function adminGetCourierReview(req: AuthedRequest, res: Response) {
  const { id } = courierReviewIdParamSchema.parse(req.sanitized.params);
  const review = await getCourierReviewByIdService({ id });
  return res.json({ review });
}

export async function adminCreateCourierReview(
  req: AuthedRequest,
  res: Response,
) {
  const input = createCustomerReviewFromCourierSchema.parse(req.sanitized.body);
  const review = await createCustomerReviewFromCourierService(input);

  return res.status(201).json({
    message: req.t?.("courier-reviews:messages.created") ?? "Courier review created",
    review,
  });
}

export async function adminUpdateCourierReview(
  req: AuthedRequest,
  res: Response,
) {
  const { id } = courierReviewIdParamSchema.parse(req.sanitized.params);
  const input = updateCustomerReviewFromCourierSchema.parse(req.sanitized.body);
  const review = await updateCustomerReviewFromCourierService({ id, data: input });

  return res.json({
    message: req.t?.("courier-reviews:messages.updated") ?? "Courier review updated",
    review,
  });
}

export async function adminDeleteCourierReview(
  req: AuthedRequest,
  res: Response,
) {
  const { id } = courierReviewIdParamSchema.parse(req.sanitized.params);
  await deleteCourierReviewService({ id });

  return res.json({
    message: req.t?.("courier-reviews:messages.deleted") ?? "Courier review deleted",
  });
}

export async function adminDeleteManyCourierReviews(
  req: AuthedRequest,
  res: Response,
) {
  const input = deleteManyCourierReviewsSchema.parse(req.sanitized.body);
  const result = await deleteManyCourierReviewsService(input);

  return res.json({
    message: req.t?.("courier-reviews:messages.deleted") ?? "Courier reviews deleted",
    ...result,
  });
}
