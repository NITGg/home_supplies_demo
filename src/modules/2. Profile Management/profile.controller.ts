import { Router } from "express";
import { validation } from "../../core/middlewares/validation.middleware";
import {
  createSupplierSlotMaxOrderSchema,
  badgeProgressSchema,
  getProfileSchema,
  hardDeleteSchema,
  locationGovernoratesAreasSchema,
  locationGovernoratesSchema,
  softDeleteSchema,
  updateDocumentsSchema,
  updateProfileSchema,
  updateSelectedAreasSchema,
  updateSupplierSlotMaxOrderSchema,
  listSupplierSlotMaxOrderSchema,
  deleteSupplierSlotMaxOrderSchema,
  supplierSlotMaxOrderStatusSchema,
} from "./profile.validation";
import { auth } from "../../core/middlewares/auth.middleware";
import upload, { cleanupTempUploads } from "../../core/middlewares/upload";
import { ProfileService } from "./profile.service";
import { authorize } from "../../core/middlewares/authorize.middlewar";
const router = Router();
const profileService = new ProfileService();

router.get(
  "/get-profile/:userId",
  auth,
  authorize("Supplier", "Admin"),
  validation(getProfileSchema),
  profileService.getProfile,
);

router.patch(
  "/update-profile/:userId",
  auth,
  authorize("Supplier", "Admin"),
  validation(updateProfileSchema),
  profileService.updateProfile,
);

router.patch(
  "/update-documents/:userId",
  auth,
  authorize("Supplier", "Admin"),
  upload.fields([
    { name: "personal_photo", maxCount: 1 },
    { name: "national_id_photo_front", maxCount: 1 },
    { name: "national_id_photo_back", maxCount: 1 },
    { name: "supplier_criminal_record", maxCount: 1 },
  ]),
  cleanupTempUploads,
  validation(updateDocumentsSchema),
  profileService.updateDocuments,
);

router.get(
  "/badge-progress/:userId",
  auth,
  authorize("Supplier", "Admin"),
  validation(badgeProgressSchema),
  profileService.badgeProgress,
);

router.delete(
  "/soft-delete/:userId",
  auth,
  authorize("Supplier", "Admin"),
  validation(softDeleteSchema),
  profileService.softDelete,
);

router.delete(
  "/hard-delete/:userId",
  auth,
  authorize("Supplier", "Admin"),
  validation(hardDeleteSchema),
  profileService.hardDelete,
);

router.post(
  "/create-supplier-slot-max-order",
  auth,
  authorize("Supplier", "Admin"),
  validation(createSupplierSlotMaxOrderSchema),
  profileService.createSupplierSlotMaxOrder,
);

router.patch(
  "/update-supplier-slot-max-order",
  auth,
  authorize("Supplier", "Admin"),
  validation(updateSupplierSlotMaxOrderSchema),
  profileService.updateSupplierSlotMaxOrder,
);

router.get(
  "/list-supplier-slot-max-order/:supplierStoreAddressId",
  auth,
  authorize("Supplier", "Admin", "Customer"),
  validation(listSupplierSlotMaxOrderSchema),
  profileService.listSupplierSlotMaxOrder,
);

router.delete(
  "/delete-supplier-slot-max-order/:supplierSlotMaxOrderId",
  auth,
  authorize("Supplier", "Admin"),
  validation(deleteSupplierSlotMaxOrderSchema),
  profileService.deleteSupplierSlotMaxOrder,
);

router.get(
  "/supplier-slot-max-order-status/:supplierStoreAddressId",
  auth,
  authorize("Supplier", "Admin", "Customer"),
  validation(supplierSlotMaxOrderStatusSchema),
  profileService.supplierSlotMaxOrderStatus,
);

export default router;
