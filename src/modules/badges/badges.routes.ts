import { Router } from "express";
import { asyncHandler } from "@/middlewares/asyncHandler";
import { requireAuth, requireRole } from "@/middlewares/auth";
import upload from "@/middlewares/upload";

import {
  createBadge,
  listBadges,
  getBadge,
  updateBadge,
  deleteBadges,
  deleteBadge,
} from "./badges.controller";

const router = Router();

router.use(requireAuth);
router.use(requireRole("Admin"));

router.get("/", asyncHandler(listBadges));

router.post("/", upload.single("image"), asyncHandler(createBadge));

router.get("/:id", asyncHandler(getBadge));

router.put("/:id", upload.single("image"), asyncHandler(updateBadge));

router.delete("/", asyncHandler(deleteBadges));
router.delete("/:id", asyncHandler(deleteBadge));

export default router;
