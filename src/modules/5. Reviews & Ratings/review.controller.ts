import { Router } from "express";
import { auth } from "../../core/middlewares/auth.middleware";
import { ReviewService } from "./review.service";
import { validation } from "../../core/middlewares/validation.middleware";
import {
  allReviewsSchema,
  getReviewSchema,
  submitReviewSchema,
} from "./review.validation";

const router = Router();
const reviewService = new ReviewService();

router.get("/all-reviews",auth,validation(allReviewsSchema),reviewService.allReviews);
router.get(
  "/get-review/:orderId",
  auth,
  validation(getReviewSchema),
  reviewService.getReview,
);
router.post(
  "/submit-review/:orderId",
  auth,
  validation(submitReviewSchema),
  reviewService.submitReview,
);

export default router;
