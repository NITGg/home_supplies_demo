import { asyncHandler } from "@/middlewares/asyncHandler";
import { requireAuth, requireRole, optionalAuth } from "@/middlewares/auth";
import { Router } from "express";
import {
  adminBulkDeleteOffers,
  adminCreateOffer,
  adminDeleteOffer,
  adminUpdateOffer,
  getOffer,
  listOffers,
} from "./offers.controller";

const offerRouter = Router();
const adminOnly = [requireAuth, requireRole("Admin")];

offerRouter
  .route("/")
  .get(optionalAuth, asyncHandler(listOffers))
  .post(...adminOnly, asyncHandler(adminCreateOffer))
  .delete(...adminOnly, asyncHandler(adminBulkDeleteOffers));

offerRouter
  .route("/:id")
  .get(optionalAuth, asyncHandler(getOffer))
  .put(...adminOnly, asyncHandler(adminUpdateOffer))
  .delete(...adminOnly, asyncHandler(adminDeleteOffer));

export default offerRouter;
