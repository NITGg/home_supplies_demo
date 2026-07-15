import { requireAuth, requireRole } from "@/middlewares/auth";
import { validation } from "@/middlewares/validation.middleware";
import { Router } from "express";
import { AdminVehicleService } from "./admin.vehicle.service";
import {
  createVehicleSchema,
  listVehiclesSchema,
  updateVehicleSchema,
  vehicleIdSchema,
} from "./admin.vehicle.validation";
import upload from "@/middlewares/upload";

const router = Router();
const adminVehicleService = new AdminVehicleService();

router.get(
  "/list-vehicles",
  requireAuth,
  requireRole("Admin", "Courier"),
  validation(listVehiclesSchema),
  adminVehicleService.listVehicles,
);
router.get(
  "/vehicle/:vehicleId",
  requireAuth,
  requireRole("Admin", "Courier"),
  validation(vehicleIdSchema),
  adminVehicleService.vehicle,
);
router.post(
  "/create-vehicle",
  requireAuth,
  requireRole("Admin"),
  upload.single("icon"),
  validation(createVehicleSchema),
  adminVehicleService.createVehicle,
);
router.patch(
  "/update-vehicle/:vehicleId",
  requireAuth,
  requireRole("Admin"),
  upload.single("icon"),
  validation(updateVehicleSchema),
  adminVehicleService.updateVehicle,
);
router.delete(
  "/delete-vehicle/:vehicleId",
  requireAuth,
  requireRole("Admin"),
  validation(vehicleIdSchema),
  adminVehicleService.deleteVehicle,
);

export default router;
