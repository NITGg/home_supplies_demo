import { Router } from "express";
import { auth } from "../../core/middlewares/auth.middleware";
import { ReviewService } from "./review.service";
import { validation } from "../../core/middlewares/validation.middleware";
import {
  allReviewsSchema,
  submitReviewSchema,
  reviewIdParamSchema,
} from "./review.validation";

const router = Router();
const reviewService = new ReviewService();

router.get("/all-reviews",auth,validation(allReviewsSchema),reviewService.allReviews);
router.get("/review-status/:orderId/:courierId", auth, reviewService.reviewStatus);
router.get("/get-review/:orderId", auth, reviewService.getReview);
router.post("/submit-review/:orderId",auth,validation(submitReviewSchema),reviewService.submitReview);
router.post("/submit-supplier-review/:orderId",auth,validation(submitReviewSchema),reviewService.submitSupplierReview);

export default router;
