import { Router } from "express";
import { requireAuth, requireRole } from "@/middlewares/auth";
import { asyncHandler } from "@/middlewares/asyncHandler.js";
import {
  adminCreateFaq,
  adminDeleteFaq,
  adminGetFaq,
  adminListFaqs,
  adminUpdateFaq,
  deleteManyFaqs,
  listPublicFaqs,
} from "./faqs.controller";

export const faqsRouter = Router();
export const adminFaqsRouter = Router();

// Public
faqsRouter.get("/", asyncHandler(listPublicFaqs));

// Admin
adminFaqsRouter.use(requireAuth);
adminFaqsRouter.use(requireRole("Admin"));
adminFaqsRouter.get("/", asyncHandler(adminListFaqs));
adminFaqsRouter.get("/:id", asyncHandler(adminGetFaq));
adminFaqsRouter.post("/", asyncHandler(adminCreateFaq));
adminFaqsRouter.put("/:id", asyncHandler(adminUpdateFaq));
adminFaqsRouter.delete("/", asyncHandler(deleteManyFaqs));
adminFaqsRouter.delete("/:id", asyncHandler(adminDeleteFaq));
