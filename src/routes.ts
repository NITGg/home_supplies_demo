import { Router } from "express";
const router = Router();
import authRouter from "./modules/1. Registration & Authentication/auth.controller";
import profileRouter from "./modules/2. Profile Management/profile.controller";
import orderRouter from "./modules/3. Order Management/order.controller";
import productRouter from "./modules/4. Product Mangement/product.controller";
import statRouter from "./modules/7. Statistics & Earnings/stat.controller";
import reviewRouter from "./modules/5. Reviews & Ratings/review.controller";
import notificationRouter from "./modules/6. Notifications/notification.controller";
import walletRouter from "./modules/9. Wallet Management/wallet.controller";
import aboutusRouter from "./modules/8. Aboutus/aboutus.controller";
import internalI18nRouter from "./modules/internal/internal.i18n.controller";

router.use("/auth", authRouter);
router.use("/profile", profileRouter);
router.use("/order", orderRouter);
router.use("/product", productRouter);
router.use("/stat", statRouter);
router.use("/review", reviewRouter);
router.use("/notification", notificationRouter);
router.use("/wallet", walletRouter);
router.use("/aboutus", aboutusRouter);
router.use("/internal/i18n", internalI18nRouter);

export default router;
