import { Router } from "express";
import { asyncHandler } from "@/middlewares/asyncHandler";
import { requireAuth, requireRole, optionalAuth } from "@/middlewares/auth";
import upload from "@/middlewares/upload";
import {
  createUser,
  listUsers,
  getUser,
  updateUser,
  deleteUsers,
  deleteUser,
  getOnlineCouriers,
  listSuppliers,
  listNearbySuppliers,
  getSupplier,
  approveSupplier,
  rejectSupplier,
  updateSupplier,
  getSupplierCategories,
  getSupplierProducts,
  createSupplierAddressHandler,
  updateSupplierAddressHandler,
} from "./controllers/users.controller";

import {
  createAddress,
  deleteAddress,
  deleteAddresses,
  listAddresses,
  updateAddress,
} from "./controllers/addresses.controller";

const router = Router();

// Public — no token required
router.get("/suppliers", optionalAuth, asyncHandler(listSuppliers));
// Location-aware listing — must be registered before "/suppliers/:id"
router.get("/suppliers/nearby", optionalAuth, asyncHandler(listNearbySuppliers));
router.get(
  "/suppliers/:id/categories",
  optionalAuth,
  asyncHandler(getSupplierCategories),
);
router.get(
  "/suppliers/:id/products",
  optionalAuth,
  asyncHandler(getSupplierProducts),
);
router.get("/suppliers/:id", optionalAuth, asyncHandler(getSupplier));

router.use(requireAuth);
// router.use(requireRole("Admin"));

router.get("/", requireRole("Admin", "CustomerSupport"), asyncHandler(listUsers));
router.patch(
  "/suppliers/:id/approve",
  requireRole("Admin"),
  asyncHandler(approveSupplier),
);
router.patch(
  "/suppliers/:id/reject",
  requireRole("Admin"),
  asyncHandler(rejectSupplier),
);
// Supplier store address management (admin only)
router.post(
  "/suppliers/:id/addresses",
  requireRole("Admin"),
  asyncHandler(createSupplierAddressHandler),
);
router.patch(
  "/suppliers/:id/addresses/:addressId",
  requireRole("Admin"),
  asyncHandler(updateSupplierAddressHandler),
);

router.patch(
  "/suppliers/:id",
  requireRole("Admin"),
  upload.fields([
    { name: "personal_photo", maxCount: 1 },
    { name: "tax_card", maxCount: 1 },
    { name: "commercial_register", maxCount: 1 },
  ]),
  asyncHandler(updateSupplier),
);

// ✅ image upload: field name "photo"
router.post(
  "/",
  requireRole("Admin", "CustomerSupport"),
  upload.single("photo"),
  asyncHandler(createUser),
);

router.get(
  "/online-couriers",
  requireRole("Admin", "CustomerSupport"),
  asyncHandler(getOnlineCouriers),
);

router.get(
  "/:id",
  requireRole("Admin", "CustomerSupport"),
  asyncHandler(getUser),
);

router.put(
  "/:id",
  requireRole("Admin"),
  upload.single("photo"),
  asyncHandler(updateUser),
);

// bulk delete
router.delete("/", requireRole("Admin"), asyncHandler(deleteUsers));

// single delete
router.delete("/:id", requireRole("Admin"), asyncHandler(deleteUser));

// user addresses routes
router.get(
  "/:userId/addresses",
  requireRole("Admin", "CustomerSupport"),
  asyncHandler(listAddresses),
);
router.post(
  "/:userId/addresses",
  requireRole("Admin"),
  asyncHandler(createAddress),
);
router.delete(
  "/:userId/addresses",
  requireRole("Admin"),
  asyncHandler(deleteAddresses),
);

router.put(
  "/:userId/addresses/:addressId",
  requireRole("Admin"),
  asyncHandler(updateAddress),
);
router.delete(
  "/:userId/addresses/:addressId",
  requireRole("Admin"),
  asyncHandler(deleteAddress),
);

export default router;
