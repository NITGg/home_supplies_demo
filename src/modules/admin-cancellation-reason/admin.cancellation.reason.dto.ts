import z from "zod";
import {
  reasonSchema,
  updateReasonSchema,
} from "./admin.cancellation.reason.validation";

export type reasonDTO = z.infer<typeof reasonSchema>;
export type updateReasonDTO = z.infer<typeof updateReasonSchema>;
