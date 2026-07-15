import { Router } from "express";
import { auth } from "../../core/middlewares/auth.middleware";
import { PointsService } from "./points.service";

const router = Router();
const pointsService = new PointsService();

router.get("/rules", auth, pointsService.rules);
router.get("/progress", auth, pointsService.progress);

export default router;
