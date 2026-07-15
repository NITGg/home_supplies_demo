import { Router } from "express";
import { auth } from "../../core/middlewares/auth.middleware";
import { validation } from "../../core/middlewares/validation.middleware";
import { AboutusService } from "./aboutus.service";
import { faqsQuerySchema, onBoardingQuerySchema } from "./aboutus.validation";

const router = Router();
const aboutusService = new AboutusService();

router.get("/faqs", validation(faqsQuerySchema), aboutusService.faqs);
router.get("/about-app", aboutusService.aboutApp);
router.get("/on-boarding",validation(onBoardingQuerySchema),aboutusService.onBoarding);

export default router;
