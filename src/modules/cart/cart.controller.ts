import type { Response } from "express";
import type { AuthedRequest } from "@/types/authedRequest";
import FeatureApi from "@/lib/featureApi";
import { cartItemCreateSchema, cartItemUpdateSchema } from "./cart.schema";
import {
  getCartService,
  addCartItemService,
  updateCartItemService,
  clearCartService,
} from "./cart.service";

export async function getCart(req: AuthedRequest, res: Response) {
  const userId = req.user.id;
  const featureData = new FeatureApi(req).sort().skip().limit().data;

  const { cart, items, summary, supplier } = await getCartService(
    userId,
    featureData,
  );

  return res.json({
    message: req.t("cart:messages.success"),
    cart: { id: cart.id, total_price: cart.total_price },
    cartItems: items,
    cartSummary: summary,
    supplier,
  });
}

export async function addCartItem(req: AuthedRequest, res: Response) {
  const userId = req.user.id;
  const input = cartItemCreateSchema.parse(req.sanitized.body);

  const { cartItem, hasWarning } = await addCartItemService(userId, input);

  return res.status(201).json({
    message: req.t("cart:messages.item_added"),
    cartItem,
    ...(hasWarning
      ? { warning: req.t("cart:warnings.quantity_adjusted") }
      : {}),
  });
}

export async function updateCartItem(req: AuthedRequest, res: Response) {
  const userId = req.user.id;
  const input = cartItemUpdateSchema.parse(req.sanitized.body);

  const result = await updateCartItemService(userId, input);

  if (result.deleted) {
    return res.json({ message: req.t("cart:messages.item_removed") });
  }

  return res.json({
    message: req.t("cart:messages.item_updated"),
    cartItem: result.cartItem,
  });
}

export async function clearCart(req: AuthedRequest, res: Response) {
  const userId = req.user.id;
  await clearCartService(userId);

  return res.json({ message: req.t("cart:messages.cleared") });
}
