import { Router } from "express";
import { auth } from "../../core/middlewares/auth.middleware";
import { OrderService } from "./product.service";
import { validation } from "../../core/middlewares/validation.middleware";
import {
  updateSupplierProductSchema,
  createSupplierProductSchema,
  updateProductSchema,
  createProductSchema,
  setDeliveryWindowsSchema,
  createSupplierOfferSchema,
  updateSupplierOfferSchema,
} from "./product.validation";
import { applyOffersLimiter } from "../../core/middlewares/limiter.middleware";

const router = Router();
const orderService = new OrderService();

router.post(
  "/create-supplier-product",
  auth,
  validation(createSupplierProductSchema),
  orderService.createSupplierProduct,
);
router.get("/list-supplier-products", auth, orderService.listSupplierProducts);
router.patch(
  "/update-supplier-product/:supplierProductId",
  validation(updateSupplierProductSchema),
  auth,
  orderService.updateSupplierProduct,
);
router.delete(
  "/delete-supplier-product/:supplierProductId",
  auth,
  orderService.deleteSupplierProduct,
);

// step: claude: type-3 delivery window management (set/replace + list) for a supplier product
// step: claude: set logic moved into /create-supplier-product and /update-supplier-product (gated on category.has_window) — route no longer needed
// router.put("/set-supplier-product-delivery-windows/:supplierProductId/:supplierId",auth,validation(setDeliveryWindowsSchema),orderService.setSupplierProductDeliveryWindows);
router.get(
  "/get-supplier-product-delivery-windows/:supplierProductId/:supplierId",
  auth,
  orderService.getSupplierProductDeliveryWindows,
);

router.post(
  "/create-product",
  auth,
  validation(createProductSchema),
  orderService.createProduct,
);
router.get("/list-products", auth, orderService.listProducts);
router.patch(
  "/update-product/:productId",
  auth,
  validation(updateProductSchema),
  orderService.updateProduct,
);

router.get("/list-categories", auth, orderService.listCategories);

// ─── Supplier Offer Routes ────────────────────────────────────────────────────
router.post(
  "/offers",
  auth,
  validation(createSupplierOfferSchema),
  orderService.createOffer,
);
router.get("/offers", auth, applyOffersLimiter, orderService.listOffers);

router.patch(
  "/offers/:offerId",
  auth,
  validation(updateSupplierOfferSchema),
  orderService.updateOffer,
);
router.delete("/offers/:offerId", auth, orderService.deleteOffer);

export default router;
