import z from "zod";
import { allReviewsSchema, submitReviewSchema } from "./review.validation";

export type AllReviewsQueryDTO = z.infer<typeof allReviewsSchema>;
export type SubmitReviewDTO = z.infer<typeof submitReviewSchema>;
