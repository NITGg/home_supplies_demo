import { Router } from "express";
import { validation } from "../../core/middlewares/validation.middleware";
import {
  locationGovernoratesAreasSchema,
  locationGovernoratesSchema,
  updateDocumentsSchema,
  updateProfileSchema,
  updateSelectedAreasSchema,
} from "./profile.validation";
import { auth } from "../../core/middlewares/auth.middleware";
import upload, { cleanupTempUploads } from "../../core/middlewares/upload";
import { ProfileService } from "./profile.service";
import { authorize } from "../../core/middlewares/authorize";
const router = Router();
const profileService = new ProfileService();

router.get(
  "/get-profile",
  auth,
  authorize("Courier"),
  profileService.getProfile,
);
router.patch(
  "/update-profile",
  auth,
  validation(updateProfileSchema),
  profileService.updateProfile,
);
router.patch(
  "/update-profile/:userId",
  auth,
  validation(updateProfileSchema),
  profileService.updateProfileByAdmin,
);
router.patch(
  "/update-documents",
  auth,
  upload.fields([
    { name: "personal_photo", maxCount: 1 },
    { name: "national_id_photo_front", maxCount: 1 },
    { name: "national_id_photo_back", maxCount: 1 },
    { name: "vehicle_license_front", maxCount: 1 },
    { name: "vehicle_license_back", maxCount: 1 },
    { name: "courier_license_front", maxCount: 1 },
    { name: "courier_license_back", maxCount: 1 },
    { name: "courier_criminal_record", maxCount: 1 },
  ]),
  cleanupTempUploads,
  validation(updateDocumentsSchema),
  profileService.updateDocuments,
);
router.patch(
  "/update-documents/:userId",
  auth,
  upload.fields([
    { name: "personal_photo", maxCount: 1 },
    { name: "national_id_photo_front", maxCount: 1 },
    { name: "national_id_photo_back", maxCount: 1 },
    { name: "vehicle_license_front", maxCount: 1 },
    { name: "vehicle_license_back", maxCount: 1 },
    { name: "courier_license_front", maxCount: 1 },
    { name: "courier_license_back", maxCount: 1 },
    { name: "courier_criminal_record", maxCount: 1 },
  ]),
  cleanupTempUploads,
  validation(updateDocumentsSchema),
  profileService.updateDocumentsByAdmin,
);
router.get("/badge-progress", auth, profileService.badgeProgress);
router.get("/get-selected-areas", auth, profileService.getSelectedAreas);
router.get(
  "/locations/governorates",
  auth,
  validation(locationGovernoratesSchema),
  profileService.locationGovernorates,
);
router.get(
  "/locations/governorates/:id/areas",
  auth,
  validation(locationGovernoratesAreasSchema),
  profileService.locationGovernoratesAreas,
);
router.patch(
  "/update-selected-areas",
  auth,
  validation(updateSelectedAreasSchema),
  profileService.updateSelectedAreas,
);
router.delete("/soft-delete", auth, profileService.softDelete);
router.delete("/hard-delete", auth, profileService.hardDelete);

export default router;
