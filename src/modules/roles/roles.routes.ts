import { Router } from "express";
import { asyncHandler } from "@/middlewares/asyncHandler";
import { requireAuth, requireRole } from "@/middlewares/auth";
import {
  createRole,
  listRoles,
  getRole,
  updateRole,
  deleteRoles,
  deleteRole,
} from "./roles.controller";

const router = Router();

router.use(requireAuth);
router.use(requireRole("Admin"));

router.get("/", asyncHandler(listRoles));
router.post("/", asyncHandler(createRole));
router.get("/:id", asyncHandler(getRole));
router.put("/:id", asyncHandler(updateRole));

// optional: bulk delete
router.delete("/", asyncHandler(deleteRoles));

// single delete
router.delete("/:id", asyncHandler(deleteRole));

export default router;
