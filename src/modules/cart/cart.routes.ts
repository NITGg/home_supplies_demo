import { Router } from "express";
import { requireAuth } from "@/middlewares/auth";
import { asyncHandler } from "@/middlewares/asyncHandler";
import {
  getCart,
  addCartItem,
  updateCartItem,
  clearCart,
} from "./cart.controller";

const cartRouter = Router();

// All cart routes require an authenticated customer
cartRouter.use(requireAuth);

cartRouter
  .route("/")
  .get(asyncHandler(getCart))
  .post(asyncHandler(addCartItem))
  .put(asyncHandler(updateCartItem))
  .delete(asyncHandler(clearCart));

export default cartRouter;
