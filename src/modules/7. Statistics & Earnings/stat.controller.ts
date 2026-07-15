import { Router } from "express";
import { validation } from "../../core/middlewares/validation.middleware";
import { auth } from "../../core/middlewares/auth.middleware";
import { StatService } from "./stat.service";

const router = Router();
const statService = new StatService();

// router.get("/earnings-summary", auth, statService.earningsSummary);
// router.get("/earnings-history",auth,statService.earningsHistory);
// router.get("/performance",auth,statService.performance);

router.get("/all-stat",auth,statService.allStat);

export default router;
