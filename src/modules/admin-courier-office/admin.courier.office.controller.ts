import { requireAuth } from "@/middlewares/auth";
import { validation } from "@/middlewares/validation.middleware";
import { Router } from "express";
import { AdminCourierOfficeService } from "./admin.courier.office.service";
import {
  appendCourierToOfficeSchema,
  courierOfficeSchema,
  createCourierOfficeSchema,
  updateCourierOfficeSchema,
} from "./admin.courier.office.validation";

const router = Router();
const adminCourierOfficeService = new AdminCourierOfficeService();

router.post(
  "/create-courier-office",
  validation(createCourierOfficeSchema),
  requireAuth,
  adminCourierOfficeService.createCourierOffice,
);
router.put(
  "/update-courier-office/:courierOfficeId",
  validation(updateCourierOfficeSchema),
  requireAuth,
  adminCourierOfficeService.updateCourierOffice,
);
router.get(
  "/courier-office-details/:courierOfficeId",
  validation(courierOfficeSchema),
  requireAuth,
  adminCourierOfficeService.courierOfficeDetails,
);
router.get(
  "/all-courier-offices",
  requireAuth,
  adminCourierOfficeService.allCourierOffices,
);
router.post(
  "/append-courier-to-office",
  validation(appendCourierToOfficeSchema),
  requireAuth,
  adminCourierOfficeService.appendCourierToOffice,
);
router.get(
  "/earnings",
  requireAuth,
  adminCourierOfficeService.getOfficeEarnings,
);
router.get(
  "/couriers-earnings",
  requireAuth,
  adminCourierOfficeService.getCourierEarningsBreakdown,
);
router.delete(
  "/delete-courier-office/:courierOfficeId",
  requireAuth,
  adminCourierOfficeService.deleteCourierOffice,
);

export default router;
