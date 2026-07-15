import { HttpError } from "@/lib/httpError";
import { prisma } from "@/config/prisma";
import { NextFunction, Request, Response } from "express";
import { referralCodeDTO } from "./admin.manage.seller.dto";
import FeatureApi from "@/lib/featureApi";
import { generateReferralCode } from "@/lib/otp";

export class AdminManageSellerService {
  constructor() {}

  // ============================ convertCustomerToSeller ============================
  convertCustomerToSeller = async (
    req: Request,
    res: Response,
    next: NextFunction,
  ) => {
    const { userId } = req.sanitized.params;

    // step: check if user exists
    const user = await prisma.user.findUnique({
      where: { id: Number(userId) },
      include: { role: true },
    });
    if (!user) {
      throw new HttpError(404, req.t("users:errors.user_not_found"));
    }

    // step: check if user is already a seller
    if (user.role.id == 4) {
      throw new HttpError(
        400,
        req.t("seller-management:errors.already_seller"),
      );
    }

    // step: check if seller record already exists
    const existingSeller = await prisma.seller.findUnique({
      where: { user_id: Number(userId) },
    });
    if (existingSeller) {
      throw new HttpError(
        400,
        req.t("seller-management:errors.already_seller"),
      );
    }

    // step: get Seller role
    const sellerRole = await prisma.userRole.findUnique({
      where: { id: 4 },
    });
    if (!sellerRole) {
      throw new HttpError(
        404,
        req.t("seller-management:errors.seller_role_not_found"),
      );
    }

    // step: update user role and create seller record
    await prisma.$transaction(async (tx) => {
      await tx.user.update({
        where: { id: Number(userId) },
        data: { role_id: sellerRole.id, referral_code: generateReferralCode() },
      });

      await tx.seller.create({
        data: { user_id: Number(userId) },
      });
    });

    return res.json({
      message: req.t("seller-management:messages.customer_converted_to_seller"),
    });
  };

  // ============================ getSellerStat ============================
  getSellerStat = async (req: Request, res: Response, next: NextFunction) => {
    const { userId } = req.sanitized.params;

    // step: check if user exists
    const user = await prisma.user.findUnique({
      where: { id: Number(userId) },
      include: { role: true },
    });
    if (!user) {
      throw new HttpError(404, "users:errors.user_not_found");
    }

    // step: get seller record
    const seller = await prisma.seller.findUnique({
      where: { user_id: Number(userId) },
    });
    if (!seller) {
      throw new HttpError(404, "seller-management:errors.seller_not_found");
    }

    // step: use FeatureApi to handle date filtering from query params
    const filteredData = new FeatureApi(req)
      .filter()
      .sort("-id")
      .limit(10)
      .skip(0)
      .includes()
      .keyword(["phone", "email", "full_name"])
      .fields().data;

    // step: build date filter for orders
    const dateFilter: any = {};
    if (filteredData.where) {
      const where = filteredData.where as Record<string, any>;
      if (where.from || where.to || where.created_at) {
        dateFilter.created_at = {};
        if (where.from)
          dateFilter.created_at.gte = new Date(where.from as string);
        if (where.to) dateFilter.created_at.lte = new Date(where.to as string);
        if (where.created_at) {
          if (typeof where.created_at === "object") {
            dateFilter.created_at = where.created_at;
          } else {
            dateFilter.created_at.gte = new Date(where.created_at as string);
          }
        }
      }
    }

    // step: get seller stats with date filtering
    const [
      totalOrders,
      totalPendingOrders,
      totalInProgressOrders,
      totalDeliveredOrders,
      totalCancelledOrders,
      totalSearchingFailedOrders,
      totalExpiredOrders,
      numberOfReferralsBySeller,
    ] = await Promise.all([
      prisma.order.count({
        where: { customer_id: Number(userId), ...dateFilter },
      }),
      prisma.order.count({
        where: {
          customer_id: Number(userId),
          status: "PENDING",
          ...dateFilter,
        },
      }),
      prisma.order.count({
        where: {
          customer_id: Number(userId),
          status: "IN_PROGRESS",
          ...dateFilter,
        },
      }),
      prisma.order.count({
        where: {
          customer_id: Number(userId),
          status: "DELIVERED",
          ...dateFilter,
        },
      }),
      prisma.order.count({
        where: {
          customer_id: Number(userId),
          status: "CANCELLED",
          ...dateFilter,
        },
      }),
      prisma.order.count({
        where: {
          customer_id: Number(userId),
          status: "SEARCHING_FAILED",
          ...dateFilter,
        },
      }),
      prisma.order.count({
        where: {
          customer_id: Number(userId),
          status: "EXPIRED",
          ...dateFilter,
        },
      }),
      prisma.user.count({
        where: {
          referral_code: user.referral_code,
        },
      }),
    ]);

    return res.json({
      message: "seller-management:messages.ok",
      data: {
        seller,
        stats: {
          total_orders: totalOrders,
          total_pending_orders: totalPendingOrders,
          total_in_progress_orders: totalInProgressOrders,
          total_delivered_orders: totalDeliveredOrders,
          total_cancelled_orders: totalCancelledOrders,
          total_searching_failed_orders: totalSearchingFailedOrders,
          total_expired_orders: totalExpiredOrders,
          numberOfReferralsBySeller: numberOfReferralsBySeller - 1,
        },
      },
    });
  };

  // ============================ listSellersStat ============================
  listSellersStat = async (req: Request, res: Response, next: NextFunction) => {
    // step: use FeatureApi to handle filtering, sorting, pagination
    const api = new FeatureApi(req)
      .filter()
      .sort("-id")
      .limit(10)
      .skip(0)
      .includes()
      .fields();

    const take = api.data.take ?? 10;
    const skip = api.data.skip ?? 0;

    // step: get sellers with pagination
    const [totalSellers, sellers] = await prisma.$transaction([
      prisma.seller.count({ where: api.data.where }),
      prisma.seller.findMany({
        where: api.data.where,
        include: {
          user: true,
          ...(api.data.include || {}),
        },
        ...(api.data.select ? { select: api.data.select } : {}),
        ...(api.data.orderBy ? { orderBy: api.data.orderBy } : {}),
        skip,
        take,
      }),
    ]);

    // step: get applicationSetting
    const applicationSetting = await prisma.applicationSetting.findFirst();
    if (!applicationSetting) {
      throw new HttpError(404, "Application settings not found");
    }

    // step: get statistics for each seller
    const sellersWithStats = await Promise.all(
      sellers.map(async (seller) => {
        const [
          totalOrders,
          totalPendingOrders,
          totalInProgressOrders,
          totalDeliveredOrders,
          totalCancelledOrders,
          totalSearchingFailedOrders,
          totalExpiredOrders,
          numberOfReferralsBySeller,
        ] = await Promise.all([
          prisma.order.count({
            where: { customer_id: seller.user_id },
          }),
          prisma.order.count({
            where: { customer_id: seller.user_id, status: "PENDING" },
          }),
          prisma.order.count({
            where: { customer_id: seller.user_id, status: "IN_PROGRESS" },
          }),
          prisma.order.count({
            where: { customer_id: seller.user_id, status: "DELIVERED" },
          }),
          prisma.order.count({
            where: { customer_id: seller.user_id, status: "CANCELLED" },
          }),
          prisma.order.count({
            where: { customer_id: seller.user_id, status: "SEARCHING_FAILED" },
          }),
          prisma.order.count({
            where: { customer_id: seller.user_id, status: "EXPIRED" },
          }),
          prisma.user.count({
            where: {
              referral_code: seller.user.referral_code,
            },
          }),
        ]);

        return {
          ...seller,
          stats: {
            total_orders: totalOrders,
            total_pending_orders: totalPendingOrders,
            total_in_progress_orders: totalInProgressOrders,
            total_delivered_orders: totalDeliveredOrders,
            total_cancelled_orders: totalCancelledOrders,
            total_searching_failed_orders: totalSearchingFailedOrders,
            total_expired_orders: totalExpiredOrders,
            numberOfReferralsBySeller: numberOfReferralsBySeller - 1,
          },
        };
      }),
    );

    return res.json({
      message: "seller-management:messages.ok",
      data: {
        sellers: sellersWithStats,
        pagination: {
          total: totalSellers,
          totalPages: Math.ceil(totalSellers / take),
          page: Math.floor(skip / take) + 1,
          limit: take,
        },
      },
    });
  };

  // ============================ generateReferralLink ============================
  generateReferralLink = async (
    req: Request,
    res: Response,
    next: NextFunction,
  ) => {
    const { userId } = req.sanitized.params;

    // step: verify user exists and is a seller
    const user = await prisma.user.findUnique({
      where: { id: Number(userId) },
      include: { role: true },
    });
    if (!user) throw new HttpError(404, req.t("users:errors.user_not_found"));
    if (user.role.id !== 4)
      throw new HttpError(403, req.t("seller-management:errors.not_a_seller"));
    if (!user.referral_code)
      throw new HttpError(
        400,
        req.t("seller-management:errors.no_referral_code"),
      );

    // step: build referral link pointing to the redirect endpoint
    const referralLink = `${process.env.APP_BASE_URL}/api/v1/admin/manage-seller/referral/${user.referral_code}`;

    return res.json({
      message: req.t("seller-management:messages.ok"),
      data: {
        referral_link: referralLink,
        referral_code: user.referral_code,
      },
    });
  };

  // ============================ navToReferralLink ============================
  navToReferralLink = async (
    req: Request,
    res: Response,
    next: NextFunction,
  ) => {
    const { referral_code } = req.sanitized.params;

    // step: check if referral code belongs to an actual seller (role_id = 4)
    const sellerUser = await prisma.user.findFirst({
      where: { role_id: 4, referral_code: referral_code as string },
    });

    // step: if no seller found, use placeholder — still redirect normally
    const resolvedCode = sellerUser ? referral_code : "SELLER_NOT_FOUND";

    // step: get app store URLs from application settings
    const settings = await prisma.applicationSetting.findFirst();
    if (!settings?.app_android_url || !settings?.app_ios_url) {
      throw new HttpError(
        400,
        req.t("seller-management:errors.app_urls_not_configured"),
      );
    }

    // step: detect device from User-Agent
    const userAgent = req.headers["user-agent"] ?? "";
    const isAndroid = /android/i.test(userAgent);
    const isIos = /iphone|ipad|ipod/i.test(userAgent);

    // step: redirect to correct store with referral code embedded
    // Android: Play Store supports ?referrer= natively via Install Referrer API
    // iOS: store code in cookie — mobile team reads it via UIPasteboard on first launch
    if (isAndroid) {
      const storeUrl = `${settings.app_android_url}&referrer=ref_code%3${resolvedCode}`;
      return res.redirect(302, storeUrl);
    }

    if (isIos) {
      const storeUrl = `${settings.app_ios_url}&referrer=ref_code%3${resolvedCode}`;
      const clipboardData = `ref_code%3${resolvedCode}`;
      const isDebug = req.query.debug === 'true';
      const erudaScript = isDebug ? `\n  <script src="https://cdn.jsdelivr.net/npm/eruda"></script>\n  <script>eruda.init();</script>` : '';
      const html = `
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Welcome to Tawreedat</title>${erudaScript}
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Outfit:wght@400;500;600;700&display=swap" rel="stylesheet">
  <style>
    :root {
      --bg-color: #090d16;
      --card-bg: rgba(17, 25, 40, 0.75);
      --border-color: rgba(255, 255, 255, 0.08);
      --primary-gradient: linear-gradient(135deg, #6366f1 0%, #a855f7 100%);
      --text-main: #f3f4f6;
      --text-muted: #9ca3af;
      --glow-color: rgba(99, 102, 241, 0.35);
    }
    
    * {
      box-sizing: border-box;
      margin: 0;
      padding: 0;
    }
    
    body {
      font-family: 'Outfit', sans-serif;
      background-color: var(--bg-color);
      background-image: 
        radial-gradient(circle at 10% 20%, rgba(99, 102, 241, 0.15) 0%, transparent 40%),
        radial-gradient(circle at 90% 80%, rgba(168, 85, 247, 0.15) 0%, transparent 40%);
      color: var(--text-main);
      min-height: 100vh;
      display: flex;
      align-items: center;
      justify-content: center;
      padding: 24px;
      overflow: hidden;
    }
    
    .container {
      width: 100%;
      max-width: 420px;
      background: var(--card-bg);
      backdrop-filter: blur(20px);
      -webkit-backdrop-filter: blur(20px);
      border: 1px solid var(--border-color);
      border-radius: 24px;
      padding: 40px 32px;
      text-align: center;
      box-shadow: 0 20px 40px rgba(0, 0, 0, 0.3);
      animation: fadeIn 0.8s cubic-bezier(0.16, 1, 0.3, 1);
    }
    
    @keyframes fadeIn {
      from { opacity: 0; transform: translateY(20px); }
      to { opacity: 1; transform: translateY(0); }
    }
    
    .icon-wrapper {
      position: relative;
      width: 80px;
      height: 80px;
      margin: 0 auto 28px;
      background: var(--primary-gradient);
      border-radius: 20px;
      display: flex;
      align-items: center;
      justify-content: center;
      box-shadow: 0 12px 24px var(--glow-color);
      animation: pulse 2.5s infinite;
    }
    
    @keyframes pulse {
      0% { transform: scale(1); box-shadow: 0 12px 24px var(--glow-color); }
      50% { transform: scale(1.03); box-shadow: 0 16px 32px rgba(99, 102, 241, 0.5); }
      100% { transform: scale(1); box-shadow: 0 12px 24px var(--glow-color); }
    }
    
    .icon-wrapper svg {
      width: 40px;
      height: 40px;
      color: #fff;
    }
    
    h1 {
      font-size: 24px;
      font-weight: 700;
      margin-bottom: 12px;
      letter-spacing: -0.02em;
    }
    
    p.subtitle {
      font-size: 15px;
      color: var(--text-muted);
      line-height: 1.6;
      margin-bottom: 32px;
    }
    
    .code-badge {
      display: inline-flex;
      align-items: center;
      gap: 8px;
      background: rgba(255, 255, 255, 0.05);
      border: 1px solid var(--border-color);
      padding: 8px 16px;
      border-radius: 12px;
      font-family: monospace;
      font-size: 14px;
      color: #a855f7;
      margin-bottom: 32px;
      letter-spacing: 0.05em;
    }
    
    .btn {
      width: 100%;
      background: var(--primary-gradient);
      border: none;
      color: white;
      padding: 16px 24px;
      font-size: 16px;
      font-weight: 600;
      border-radius: 16px;
      cursor: pointer;
      box-shadow: 0 8px 20px var(--glow-color);
      transition: all 0.3s cubic-bezier(0.16, 1, 0.3, 1);
      display: flex;
      align-items: center;
      justify-content: center;
      gap: 10px;
      outline: none;
      -webkit-tap-highlight-color: transparent;
    }
    
    .btn:active {
      transform: scale(0.97);
      box-shadow: 0 4px 10px var(--glow-color);
    }
    
    .toast {
      position: fixed;
      bottom: 32px;
      left: 50%;
      transform: translateX(-50%) translateY(100px);
      background: rgba(17, 25, 40, 0.9);
      border: 1px solid rgba(255, 255, 255, 0.15);
      padding: 12px 24px;
      border-radius: 50px;
      font-size: 14px;
      font-weight: 500;
      color: #fff;
      box-shadow: 0 10px 30px rgba(0, 0, 0, 0.5);
      transition: transform 0.4s cubic-bezier(0.16, 1, 0.3, 1), opacity 0.4s;
      opacity: 0;
      display: flex;
      align-items: center;
      gap: 8px;
      pointer-events: none;
      z-index: 1000;
      white-space: nowrap;
    }
    
    .toast.show {
      transform: translateX(-50%) translateY(0);
      opacity: 1;
    }
    
    .toast svg {
      width: 18px;
      height: 18px;
      color: #10b981;
    }
  </style>
</head>
<body>

  <div class="container">
    <div class="icon-wrapper">
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
        <path d="M20.84 4.61a5.5 5.5 0 0 0-7.78 0L12 5.67l-1.06-1.06a5.5 5.5 0 0 0-7.78 7.78l1.06 1.06L12 21.23l7.78-7.78 1.06-1.06a5.5 5.5 0 0 0 0-7.78z"></path>
      </svg>
    </div>
    
    <h1>Welcome to Tawreedat</h1>
    <p class="subtitle">Tap below to open the App Store and automatically apply your referral code.</p>
    
    <div class="code-badge">
      <span>CODE:</span>
      <strong>${resolvedCode}</strong>
    </div>
    
    <button id="cta-btn" class="btn">
      <span>Get App & Apply Code</span>
      <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
        <line x1="5" y1="12" x2="19" y2="12"></line>
        <polyline points="12 5 19 12 12 19"></polyline>
      </svg>
    </button>
  </div>

  <div id="toast" class="toast">
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round">
      <polyline points="20 6 9 17 4 12"></polyline>
    </svg>
    <span>Referral code copied! Redirecting...</span>
  </div>

  <script>
    // Bulletproof Clipboard Copy
    function copyToClipboard(text) {
      return new Promise((resolve, reject) => {
        if (navigator.clipboard && navigator.clipboard.writeText) {
          navigator.clipboard.writeText(text).then(resolve).catch(err => {
            fallbackCopy(text) ? resolve() : reject(err);
          });
        } else {
          fallbackCopy(text) ? resolve() : reject(new Error('Clipboard API not supported'));
        }
      });
    }

    function fallbackCopy(text) {
      const textArea = document.createElement('textarea');
      textArea.value = text;
      textArea.style.top = '0';
      textArea.style.left = '0';
      textArea.style.position = 'fixed';
      textArea.style.opacity = '0';
      document.body.appendChild(textArea);
      textArea.focus();
      textArea.select();
      
      let successful = false;
      try {
        successful = document.execCommand('copy');
      } catch (err) {
        console.error('Fallback copy failed', err);
      }
      document.body.removeChild(textArea);
      return successful;
    }

    const btn = document.getElementById('cta-btn');
    const toast = document.getElementById('toast');
    const clipboardData = '${clipboardData}';
    const storeUrl = '${storeUrl}';

    btn.addEventListener('click', function() {
      // Trigger copy inside user action context
      copyToClipboard(clipboardData)
        .then(() => {
          console.log('Referral code copied successfully:', clipboardData);
        })
        .catch((err) => {
          console.error('Copy failed, proceeding with redirect anyway:', err);
        })
        .finally(() => {
          // Show toast feedback
          toast.classList.add('show');
          
          // Redirect after a brief delay so they see the gorgeous confirmation
          setTimeout(() => {
            window.location.href = storeUrl;
          }, 1000);
        });
    });

  </script>
</body>
</html>
      `;
      return res.send(html);
    }

    // step: fallback for desktop
    return res.redirect(302, settings.app_android_url);
  };

  // ============================ saveReferralCode ============================
  saveReferralCode = async (
    req: Request,
    res: Response,
    next: NextFunction,
  ) => {
    const { userId } = req.sanitized.params;
    const { referral_code }: referralCodeDTO = req.sanitized.body;

    // step: check if user exists
    const user = await prisma.user.findUnique({
      where: { id: Number(userId) },
      include: { role: true },
    });
    if (!user) {
      throw new HttpError(404, req.t("users:errors.user_not_found"));
    }

    //step: save referrel code
    await prisma.user.update({
      where: { id: Number(userId) },
      data: { referral_code },
    });

    return res.json({
      message: req.t("seller-management:messages.referral_code_updated"),
    });
  };
}
