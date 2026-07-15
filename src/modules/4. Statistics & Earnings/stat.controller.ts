import { Router } from "express";
import { validation } from "../../core/middlewares/validation.middleware";
import {
  earningsHistoryQuerySchema,
  performanceQuerySchema,
} from "./stat.validation";
import { auth } from "../../core/middlewares/auth.middleware";
import { StatService } from "./stat.service";

const router = Router();
const statService = new StatService();

router.get("/earnings-summary", auth, statService.earningsSummary);
router.get("/earnings-history",auth,validation(earningsHistoryQuerySchema),statService.earningsHistory);
router.get("/performance",auth,validation(performanceQuerySchema),statService.performance);

export default router;
