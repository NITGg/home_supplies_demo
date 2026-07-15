import express from "express";
import cors from "cors";
import helmet from "helmet";
import compression from "compression";
import rateLimit from "express-rate-limit";
import cookieParser from "cookie-parser";
import pinoHttp from "pino-http";
import path from "node:path";
import authRoutes from "@/modules/auth/auth.routes";
import userRoutes from "@/modules/users/users.routes";
import rolesRoutes from "@/modules/roles/roles.routes";
import badgesRoutes from "@/modules/badges/badges.routes";
import profileRoutes from "@/modules/profile/profile.routes";
import adminOrdersRoutes from "@/modules/orders/admin/orders.admin.routes";
import ordersRoutes from "@/modules/orders/orders.routes";
import appSettingsRouter from "@/modules/app-settings/app-settings.routes";
import aboutAppRouter from "@/modules/about-app/about-app.routes";
import {
  adminArticlesRouter,
  articlesRouter,
} from "@/modules/articles/articles.routes";
import contactUsRouter from "@/modules/contact-us/contact-us.routes";
import { adminFaqsRouter, faqsRouter } from "./modules/faqs/faqs.routes";
import { adminPeakTimeRouter } from "./modules/peak-time/peak-time.routes";
import {
  adminOnBoardingRouter,
  onBoardingRouter,
} from "@/modules/on-boarding/on-boarding.routes";
import {
  adminGovernoratesRouter,
  governoratesRouter,
} from "@/modules/governorates/governorates.routes";
import { adminAreasRouter, areasRouter } from "@/modules/areas/areas.routes";

import { errorHandler } from "@/middlewares/errorHandler";
import { notFound } from "@/middlewares/notFound";
import { logger } from "@/config/logger";
import { i18nMiddleware } from "@/i18n";
import {
  adminCustomerCouponsRouter,
  customerCouponsRouter,
} from "./modules/customer-coupons/customer-coupons.routes";
import adminWalletRoutes from "@/modules/admin-wallet/admin.wallet.controller";
import customerPointsRouter from "@/modules/customer-points/customer.points.controller";
import adminApprovalRoutes from "@/modules/admin-approval/admin.approval.controller";
import adminI18nRoutes from "@/modules/admin-i18n/admin.i18n.controller";
import adminCancellationReasonRoutes from "@/modules/admin-cancellation-reason/admin.cancellation.reason.controller";
import adminCourierOfficeRoutes from "@/modules/admin-courier-office/admin.courier.office.controller";
import adminCourierStatRoutes from "@/modules/admin-courier-stat/admin.courier.stat.controller";
import adminVehicleRoutes from "@/modules/admin-vehicle/admin.vehicle.controller";
import adminManageSellerRoutes from "@/modules/admin-manage-seller/admin.manage.seller.controller";
import {
  adminCustomerReviewsRouter,
  adminSupplierReviewsRouter,
  customerReviewsRouter,
} from "@/modules/customer-reviews/customer-reviews.routes";
import {
  adminCourierReviewsRouter,
  courierReviewsRouter,
} from "@/modules/courier-reviews/courier-reviews.routes";
import notificationsRouter from "./modules/notifications/notifications.routes";
import {
  adminCourierCouponsRouter,
  courierCouponsRouter,
} from "./modules/courier-coupons/courier-coupons.routes";
import { unavailableAreaRequestRouter } from "./modules/unavailable-area-request/unavailable-area-request.routes";
import { distancesRouter } from "./modules/distances/distances.routes";
import categoryRouter from "./modules/categories/categories.routes";
import brandRouter from "./modules/brands/brands.routes";
import productRouter from "./modules/products/products.routes";
import cartRouter from "./modules/cart/cart.routes";
import offerRouter from "./modules/offers/offers.routes";
import adRouter from "./modules/ads/ads.routes";
import searchRouter from "./modules/search/search.routes";
import { sanitizeInput } from "./lib/sanitize";
import env from "@/config/env";
import { requestLogger } from "./middlewares/requestLogger";
import { logsRouter } from "./modules/logs/logs.routes";
import externalAppRouter from "./modules/externalApps/routes/externalApp.routes";
import externalAppWalletRouter from "./modules/externalApps/routes/externalApp.wallet.routes";
import refundRouter from "./modules/refunds/refunds.routes";
import refundReasonsRouter from "./modules/refund-reasons/refunds-reasons.routes";
import webhooksRouter from "./modules/webhooks/webhooks.routes";

const app = express();
const isProd = env.PROD;
// Parse allowed origins from env
const allowedOrigins = new Set(
  env.ALLOWED_ORIGINS.split(",").map((o) => o.trim()),
);
app.use("/uploads", express.static(path.join(__dirname, "..", "uploads")));

/* =====================
   Core middlewares
===================== */

app.set("trust proxy", 1);

app.use(
  pinoHttp({
    logger,
    customLogLevel: (_req, res, err) => {
      if (err || res.statusCode >= 500) return "error";
      if (res.statusCode >= 400) return "warn";
      return "info"; // log success
    },
    customSuccessMessage: (req, res) =>
      `${req.method} ${req.originalUrl} ${res.statusCode}`,
    customErrorMessage: (req, res, err) =>
      `${req.method} ${req.originalUrl} ${res.statusCode} - ${err?.message ?? "error"}`,
    serializers: {
      req() {
        return undefined as any; // removes full req dump
      },
      res() {
        return undefined as any; // removes full res dump
      },
    },
  }),
);

app.use(helmet());
app.use(compression());
app.use(cookieParser());

app.use(
  cors({
    origin: isProd
      ? (origin, callback) => {
          // In prod: block requests from unlisted origins.
          // Allow requests with no origin (mobile apps, curl, Postman).
          if (!origin || allowedOrigins.has(origin)) {
            callback(null, true);
          } else {
            callback(new Error(`CORS: origin ${origin} not allowed`));
          }
        }
      : true, // In dev: allow everything
    credentials: true,
  }),
);

app.use(express.json({ limit: "1mb" }));
app.use(express.urlencoded({ extended: true }));
app.set("query parser", "extended");

// ── Global sanitization ───────────────────────────────────────
app.use((req, _res, next) => {
  // Preserve the original body before stripping HTML so controllers that
  // need rich-text content (about-app, articles, etc.) can access it.
  (req as any).rawBody = req.body ? structuredClone(req.body) : {};

  const sanitizedBody = sanitizeInput(req.body ?? {});
  const sanitizedQuery = sanitizeInput(req.query ?? {});

  req.body = sanitizedBody;

  Object.defineProperty(req, "sanitized", {
    get() {
      return {
        body: sanitizedBody,
        query: sanitizedQuery,
        // params are read lazily — by the time a controller accesses
        // req.sanitized.params the router has already populated req.params
        params: sanitizeInput(req.params ?? {}),
      };
    },
    configurable: true,
  });

  next();
});

// ── Request Logger ─────────────────────────────────────────────
app.use(
  requestLogger({
    // Skip noisy or sensitive routes entirely
    exclude: [
      /^\/uploads\//, // static files
      /^\/api\/v1\/health/, // health checks (already default-excluded)
      /^\/api\/v1\/logs/, // logs routes (already default-excluded)
    ],

    // --- Option A: log everything except excludes (comment out `include`) ---

    // --- Option B: log only specific routes ---
    // include: [
    //   /^\/api\/v1\/orders/,
    //   /^\/api\/v1\/auth/,
    //   "/api/v1/admin/wallet",
    // ],

    skipSuccess: false, // set true to only log 4xx/5xx
    logBody: true,
    logQuery: true,
  }),
);

app.use(
  rateLimit({
    windowMs: env.RATE_LIMIT_WINDOW_MINUTES * 60 * 1000, // Converts minutes to ms
    limit: env.RATE_LIMIT_MAX_REQUESTS,
    standardHeaders: true, // Return rate limit info in the `RateLimit-*` headers
    legacyHeaders: false, // Disable the `X-RateLimit-*` headers
    skip: () => !env.PROD,
    message: {
      message: "Too many requests, please try again later.",
    },
  }),
);

app.use(i18nMiddleware);

/* =====================
   API v1
===================== */

const apiV1 = express.Router();

apiV1.get("/health", (_req, res) => res.json({ ok: true }));
apiV1.use("/auth", authRoutes);
apiV1.use("/users", userRoutes);
apiV1.use("/roles", rolesRoutes);
apiV1.use("/badges", badgesRoutes);
apiV1.use("/profile", profileRoutes);
apiV1.use("/admin/orders", adminOrdersRoutes);
apiV1.use("/orders", ordersRoutes);
apiV1.use("/governorates", governoratesRouter);
apiV1.use("/admin/governorates", adminGovernoratesRouter);
apiV1.use("/areas", areasRouter);
apiV1.use("/admin/areas", adminAreasRouter);
apiV1.use("/app-settings", appSettingsRouter);
apiV1.use("/about-app", aboutAppRouter);
apiV1.use("/articles", articlesRouter);
apiV1.use("/admin/articles", adminArticlesRouter);
apiV1.use("/contact-us", contactUsRouter);
apiV1.use("/faqs", faqsRouter);
apiV1.use("/admin/faqs", adminFaqsRouter);
apiV1.use("/admin/peak-time", adminPeakTimeRouter);
apiV1.use("/on-boarding", onBoardingRouter);
apiV1.use("/admin/on-boarding", adminOnBoardingRouter);
apiV1.use("/customer-coupons", customerCouponsRouter);
apiV1.use("/admin/customer-coupons", adminCustomerCouponsRouter);
apiV1.use("/admin/approval", adminApprovalRoutes);
apiV1.use("/admin/i18n", adminI18nRoutes);
apiV1.use("/admin/cancellation-reason", adminCancellationReasonRoutes);
apiV1.use("/admin/courier-office", adminCourierOfficeRoutes);
apiV1.use("/admin/courier-stat", adminCourierStatRoutes);
apiV1.use("/admin/manage-seller", adminManageSellerRoutes);
apiV1.use("/admin/vehicle", adminVehicleRoutes);
apiV1.use("/admin/wallet", adminWalletRoutes);
apiV1.use("/customer/points", customerPointsRouter);
apiV1.use("/customer-reviews", customerReviewsRouter);
apiV1.use("/admin/customer-reviews", adminCustomerReviewsRouter);
apiV1.use("/admin/supplier-reviews", adminSupplierReviewsRouter);
apiV1.use("/courier-reviews", courierReviewsRouter);
apiV1.use("/admin/courier-reviews", adminCourierReviewsRouter);
apiV1.use("/notifications", notificationsRouter);
apiV1.use("/courier-coupons", courierCouponsRouter);
apiV1.use("/admin/courier-coupons", adminCourierCouponsRouter);
apiV1.use("/unavailable-area-request", unavailableAreaRequestRouter);
apiV1.use("/distances", distancesRouter);
apiV1.use("/categories", categoryRouter);
apiV1.use("/brands", brandRouter);
apiV1.use("/products", productRouter);
apiV1.use("/cart", cartRouter);
apiV1.use("/offers", offerRouter);
apiV1.use("/ads", adRouter);
apiV1.use("/search", searchRouter);
apiV1.use("/logs", logsRouter);
apiV1.use("/external-apps", externalAppRouter);
apiV1.use("/wallet", externalAppWalletRouter);
apiV1.use("/refunds", refundRouter);
apiV1.use("/refund-reasons", refundReasonsRouter);
apiV1.use("/webhooks", webhooksRouter);
// ─────────────────────────────────────────────────────────────────────────────
// Debugging / Echo HTML View
// Catches any HTTP method on /test or /test/:id and renders a clean UI page
// ─────────────────────────────────────────────────────────────────────────────
import crypto from "node:crypto";

apiV1.all(["/test", "/test/:id"], (req, res) => {
  const inspectData = {
    timestamp: new Date().toISOString(),
    method: req.method,
    path: req.path,
    url: req.originalUrl,
    params: req.params,
    query: req.query,
    body: req.body,
    headers: req.headers,
  };
  logger.info(inspectData);

  // 1. Generate a unique cryptographic nonce for this single request
  const nonce = crypto.randomBytes(16).toString("base64");

  // 2. Append the nonce securely to your existing CSP headers dynamically
  // This tells the browser: "Trust scripts explicitly marked with this specific token"
  const currentCsp = (res.getHeader("Content-Security-Policy") as string) || "";

  if (currentCsp) {
    // If helmet or another middleware already set a CSP, append our nonce to script-src
    const updatedCsp = currentCsp.replace(
      "script-src 'self'",
      `script-src 'self' 'nonce-${nonce}'`,
    );
    res.setHeader("Content-Security-Policy", updatedCsp);
  } else {
    // Fallback if no CSP was set yet by helmet
    res.setHeader(
      "Content-Security-Policy",
      `default-src 'self'; script-src 'self' 'nonce-${nonce}'; style-src 'self' 'unsafe-inline'`,
    );
  }

  const html = `
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>API Inspector - ${req.method} ${req.path}</title>
      <style>
        body {
          font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
          background-color: #0d1117;
          color: #c9d1d9;
          margin: 0;
          padding: 20px;
        }
        .container { max-width: 1000px; margin: 0 auto; }
        header { display: flex; align-items: center; justify-content: space-between; border-bottom: 1px solid #21262d; padding-bottom: 15px; margin-bottom: 20px; }
        h1 { font-size: 1.5rem; margin: 0; color: #f0f6fc; }
        .badge { padding: 4px 8px; border-radius: 4px; font-family: monospace; font-weight: bold; font-size: 0.9rem; }
        .method-GET { background-color: #2ea043; color: white; }
        .method-POST { background-color: #1f6feb; color: white; }
        .method-PUT { background-color: #d29922; color: black; }
        .method-DELETE { background-color: #f85149; color: white; }
        pre { background-color: #161b22; border: 1px solid #30363d; border-radius: 6px; padding: 16px; overflow-x: auto; font-family: "SFMono-Regular", Consolas, "Liberation Mono", Menlo, monospace; font-size: 14px; line-height: 1.5; }
        .string { color: #a5d6ff; }
        .number { color: #ffa657; }
        .boolean { color: #79c0ff; }
        .null { color: #ff7b72; }
        .key { color: #7ee787; }
      </style>
    </head>
    <body>
      <div class="container">
        <header>
          <h1>API Request Inspector</h1>
          <span class="badge method-${req.method}">${req.method}</span>
        </header>
        <pre id="json-output">Processing payload...</pre>
      </div>

      <script type="application/json" id="payload-raw">${JSON.stringify(inspectData)}</script>

      <script nonce="${nonce}">
        try {
          const rawText = document.getElementById('payload-raw').textContent;
          const data = JSON.parse(rawText);
          
          function syntaxHighlight(json) {
            if (typeof json !== 'string') {
               json = JSON.stringify(json, undefined, 2);
            }
            return json.replace(/("(\\u[a-zA-Z0-9]{4}|\\[^u]|[^\\"])*"(\s*:)?|\b(true|false|null)\b|-?\d+(?:\.\d*)?(?:[eE][+-]?\d+)?)/g, function (match) {
              let cls = 'number';
              if (/^"/.test(match)) {
                if (/:$/.test(match)) {
                  cls = 'key';
                } else {
                  cls = 'string';
                }
              } else if (/true|false/.test(match)) {
                cls = 'boolean';
              } else if (/null/.test(match)) {
                cls = 'null';
              }
              return '<span class="' + cls + '">' + match + '</span>';
            });
          }

          document.getElementById('json-output').innerHTML = syntaxHighlight(data);
        } catch (err) {
          document.getElementById('json-output').innerText = "Inspector Execution Error: " + err.message;
        }
      </script>
    </body>
    </html>
  `;

  res.setHeader("Content-Type", "text/html");
  return res.status(200).send(html);
});

app.use("/api/v1", apiV1);

/* =====================
   Errors
===================== */

app.use(notFound);
app.use(errorHandler);

export default app;
