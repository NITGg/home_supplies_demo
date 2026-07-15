import { Router } from "express";
import { requireAuth, requireRole } from "@/middlewares/auth";
import { asyncHandler } from "@/middlewares/asyncHandler";
import {
  adminDeleteContactUs,
  adminGetContactUs,
  adminListContactUs,
  adminUpdateContactUs,
  createContactUs,
  deleteManyContactUs,
} from "./contact-us.controller";

const contactUsRouter = Router();

// Public
contactUsRouter.post("/", asyncHandler(createContactUs));

// Admin
contactUsRouter.use(requireAuth);
contactUsRouter.use(requireRole("Admin"));
contactUsRouter.get("/", asyncHandler(adminListContactUs));
contactUsRouter.get("/:id", asyncHandler(adminGetContactUs));
contactUsRouter.put("/:id", asyncHandler(adminUpdateContactUs));
contactUsRouter.delete("/", asyncHandler(deleteManyContactUs));
contactUsRouter.delete("/:id", asyncHandler(adminDeleteContactUs));

export default contactUsRouter;
