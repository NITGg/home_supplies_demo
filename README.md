
```
backend
├─ AI.md
├─ package-lock.json
├─ package.json
├─ pnpm-lock.yaml
├─ pnpm-workspace.yaml
├─ prisma
│  ├─ models
│  │  ├─ ad.prisma
│  │  ├─ cancellationReason.prisma
│  │  ├─ catalog.prisma
│  │  ├─ chat.prisma
│  │  ├─ content.prisma
│  │  ├─ courier.prisma
│  │  ├─ CourierPointBatch.prisma
│  │  ├─ CustomerPointBatch.prisma
│  │  ├─ externalApp.prisma
│  │  ├─ logs.prisma
│  │  ├─ notification.prisma
│  │  ├─ offer.prisma
│  │  ├─ order.prisma
│  │  ├─ payment.prisma
│  │  ├─ review.prisma
│  │  ├─ seller.prisma
│  │  ├─ supplier.prisma
│  │  └─ user.prisma
│  └─ schema.prisma
├─ prisma.config.ts
├─ src
│  ├─ app.ts
│  ├─ config
│  │  ├─ env.ts
│  │  ├─ logger.ts
│  │  ├─ prisma.ts
│  │  └─ redis.ts
│  ├─ errors
│  │  ├─ handelZodIssue.ts
│  │  └─ handleMulterIssue.ts
│  ├─ events
│  │  ├─ bus.ts
│  │  ├─ handlers
│  │  │  ├─ courierCoupon.ts
│  │  │  ├─ customerCoupon.ts
│  │  │  ├─ noProposals.ts
│  │  │  ├─ notifySupplier.ts
│  │  │  ├─ orderCancelled.ts
│  │  │  ├─ orderCreated.ts
│  │  │  ├─ orderDelivered.ts
│  │  │  ├─ orderExpired.ts
│  │  │  ├─ orderIssue.ts
│  │  │  ├─ orderProposal.ts
│  │  │  └─ syncProductChanges.ts
│  │  └─ register.ts
│  ├─ i18n
│  │  ├─ index.ts
│  │  ├─ locales
│  │  │  ├─ ar
│  │  │  │  ├─ about-app.json
│  │  │  │  ├─ admin-approval.json
│  │  │  │  ├─ admin-courier-office.json
│  │  │  │  ├─ admin-courier-stat.json
│  │  │  │  ├─ admin-vehicle.json
│  │  │  │  ├─ admin-wallet.json
│  │  │  │  ├─ ads.json
│  │  │  │  ├─ areas.json
│  │  │  │  ├─ articles.json
│  │  │  │  ├─ auth.json
│  │  │  │  ├─ badges.json
│  │  │  │  ├─ brands.json
│  │  │  │  ├─ cancellation-reason.json
│  │  │  │  ├─ cart.json
│  │  │  │  ├─ categories.json
│  │  │  │  ├─ common.json
│  │  │  │  ├─ contact-us.json
│  │  │  │  ├─ courier-coupons.json
│  │  │  │  ├─ customer-coupons.json
│  │  │  │  ├─ customer-reviews.json
│  │  │  │  ├─ faqs.json
│  │  │  │  ├─ governorates.json
│  │  │  │  ├─ offers.json
│  │  │  │  ├─ on-boarding.json
│  │  │  │  ├─ orders.json
│  │  │  │  ├─ points.json
│  │  │  │  ├─ products.json
│  │  │  │  ├─ profile.json
│  │  │  │  ├─ roles.json
│  │  │  │  ├─ seller-management.json
│  │  │  │  ├─ settings.json
│  │  │  │  ├─ unavailable-area-request.json
│  │  │  │  └─ users.json
│  │  │  └─ en
│  │  │     ├─ about-app.json
│  │  │     ├─ admin-approval.json
│  │  │     ├─ admin-courier-office.json
│  │  │     ├─ admin-courier-stat.json
│  │  │     ├─ admin-vehicle.json
│  │  │     ├─ admin-wallet.json
│  │  │     ├─ ads.json
│  │  │     ├─ areas.json
│  │  │     ├─ articles.json
│  │  │     ├─ auth.json
│  │  │     ├─ badges.json
│  │  │     ├─ brands.json
│  │  │     ├─ cancellation-reason.json
│  │  │     ├─ cart.json
│  │  │     ├─ categories.json
│  │  │     ├─ common.json
│  │  │     ├─ contact-us.json
│  │  │     ├─ courier-coupons.json
│  │  │     ├─ customer-coupons.json
│  │  │     ├─ customer-reviews.json
│  │  │     ├─ faqs.json
│  │  │     ├─ governorates.json
│  │  │     ├─ offers.json
│  │  │     ├─ on-boarding.json
│  │  │     ├─ orders.json
│  │  │     ├─ points.json
│  │  │     ├─ products.json
│  │  │     ├─ profile.json
│  │  │     ├─ roles.json
│  │  │     ├─ seller-management.json
│  │  │     ├─ settings.json
│  │  │     ├─ unavailable-area-request.json
│  │  │     └─ users.json
│  │  └─ t.ts
│  ├─ index.ts
│  ├─ jobs
│  │  ├─ courierCouponExpiryReminder.job.ts
│  │  ├─ index.ts
│  │  ├─ logsJobs.ts
│  │  └─ registerOrderJobs.ts
│  ├─ lib
│  │  ├─ attribute.utils.ts
│  │  ├─ badgeHelper.ts
│  │  ├─ catalogHelpers.ts
│  │  ├─ deleteImage.ts
│  │  ├─ emails
│  │  │  └─ verificationEmail.ts
│  │  ├─ featureApi.ts
│  │  ├─ featureApiRules.md
│  │  ├─ filter.ts
│  │  ├─ getAdminUsers.ts
│  │  ├─ getOrCreateBadge.ts
│  │  ├─ getOrCreateRole.ts
│  │  ├─ handleImageService.ts
│  │  ├─ httpError.ts
│  │  ├─ jwt.ts
│  │  ├─ mailer.ts
│  │  ├─ money.ts
│  │  ├─ otp.ts
│  │  ├─ printRouterRoutes.ts
│  │  ├─ productImages.ts
│  │  ├─ sanitize.ts
│  │  ├─ sendFcmMessage.ts
│  │  ├─ slugify.ts
│  │  ├─ uploadImage.ts
│  │  ├─ vehicle-selector.ts
│  │  └─ walletHelper.ts
│  ├─ middlewares
│  │  ├─ asyncHandler.ts
│  │  ├─ auth
│  │  │  ├─ authHelpers.ts
│  │  │  ├─ index.ts
│  │  │  ├─ optionalAuth.ts
│  │  │  ├─ requireAnyAuth.ts
│  │  │  ├─ requireAuth.ts
│  │  │  ├─ requireExternalApp.ts
│  │  │  └─ requireRole.ts
│  │  ├─ errorHandler.ts
│  │  ├─ notFound.ts
│  │  ├─ requestLogger.ts
│  │  ├─ upload.ts
│  │  └─ validation.middleware.ts
│  ├─ modules
│  │  ├─ about-app
│  │  │  ├─ about-app.controller.ts
│  │  │  ├─ about-app.routes.ts
│  │  │  ├─ about-app.schema.ts
│  │  │  └─ about-app.service.ts
│  │  ├─ admin-approval
│  │  │  ├─ admin.approval.controller.ts
│  │  │  ├─ admin.approval.dto.ts
│  │  │  ├─ admin.approval.service.ts
│  │  │  └─ admin.approval.validation.ts
│  ├─ queues
│  │  └─ webhook
│  │     ├─ index.ts
│  │     ├─ webhook.events.ts
│  │     ├─ webhook.queue.ts
│  │     ├─ webhook.service.ts
│  │     ├─ webhook.types.ts
│  │     └─ webhook.worker.ts
│  ├─ schemas
│  │  ├─ addresses.schema.ts
│  │  └─ phone.ts
│  ├─ services
│  │  ├─ addresses.service.ts
│  │  ├─ notification.service.ts
│  │  └─ paymob.service.ts
│  ├─ socket
│  │  ├─ adminHandlers.ts
│  │  ├─ auth.ts
│  │  ├─ courierHandlers.ts
│  │  ├─ index.ts
│  │  ├─ rooms.ts
│  │  ├─ status.ts
│  │  ├─ test-client.ts
│  │  └─ test-dashboard-location.ts
│  └─ types
│     ├─ authedRequest.ts
│     ├─ events.ts
│     ├─ express.d.ts
│     ├─ paymob.types.ts
│     ├─ prisma.types.ts
│     └─ serviceCtx.ts
├─ tsconfig.json
└─ vibe_coding_prompt.md

```