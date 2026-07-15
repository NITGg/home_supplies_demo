# Dashboard Merge Notes

**Merged from:** `admin-dashboard-dev` (Vite React SPA)  
**Into:** `ahmed_dashboard` (Next.js 14 App Router)  
**Date:** 2026-05-02

---

## Features MERGED (new pages added to ahmed_dashboard)

| Feature | Route | Files |
|---------|-------|-------|
| Statistics / Analytics | `/statistics` | `app/(dashboard)/statistics/page.tsx`, `lib/statistics.ts` |
| App Settings | `/settings` | `app/(dashboard)/settings/page.tsx`, `lib/settings.ts` |
| About App Management | `/about-app` | `app/(dashboard)/about-app/page.tsx`, `lib/about-app.ts` |
| Role Management | `/roles` | `app/(dashboard)/roles/page.tsx`, `lib/roles.ts` |

### Statistics page covers:
- Orders tab: status breakdown, payment method distribution
- Financial tab: total revenue, courier fees, platform fees
- Users tab: unique customer and courier counts
- Areas tab: top pickup / delivery areas with bar charts

### Settings page covers:
- General: VAT, commissions, feature toggles (OTP, guest login, live payment, etc.)
- Delivery: min distance/fee, pricing per km, fines, cash budget limit
- Security: login/register/password/API rate limits
- Points: courier and customer loyalty point configuration
- Apps: customer and courier app URLs and version numbers

### About App page covers:
- Contact: phone, email, WhatsApp, support numbers, VodafonCash, InstaPay
- Social: Facebook, YouTube, Instagram, Twitter, TikTok, Snapchat, Pinterest, LinkedIn, Reddit, Telegram
- Content: About, Mission, Vision, Digital Card, Delete Account instructions (bilingual EN/AR)
- Policies: Terms, Privacy Policy, Courier Terms, Courier Privacy Policy (bilingual EN/AR)

### Roles page covers:
- Paginated table of all system roles
- Create / Edit / Delete with bilingual name + description
- Search by name

---

## Features NOT MERGED (already exist in ahmed_dashboard)

| Feature | Reason |
|---------|--------|
| User Management (customers, couriers, sellers) | Already in `/users` |
| Order Management | Already in `/orders` |
| Badges | Already in `/badges` |
| Coupons (customer + courier) | Already in `/coupons`, `/courier-coupons` |
| Reviews | Already in `/reviews` |
| Courier Offices | Already in `/courier-offices` |
| Vehicles | Already in `/vehicles` |
| Onboarding Management | Already in `/onboarding` |
| Cancellation Reasons | Already in `/cancellation-reasons` |
| Wallet (wallets, transactions, penalties) | Already in `/wallet` |
| Area Management | Already in `/areas`, `/governorates` |
| Unavailable Area Requests | Already in `/area-requests` |
| Notifications (send) | Already in `/notifications` |

## Features in ahmed_dashboard NOT in admin-dashboard-dev

| Feature |
|---------|
| Ads Management (`/ads`) |
| Articles Management (`/articles`) |
| Brands Management (`/brands`) |
| Categories Management (`/categories`) |
| Chat with couriers/customers (`/chat`) |
| Contact Messages (`/contact`) |
| Couriers Live Map (`/couriers-map`) with Socket.IO |
| FAQs Management (`/faqs`) |
| Products Management (`/products`) |
| Suppliers Management (`/suppliers`) |
| Translations Editor (`/translations`) |
| Courier Approvals (`/courier-approvals`) |

---

## Tech Stack Differences (not merged)

- **Theme switching** (dark/light mode): admin-dashboard-dev uses CSS variables + shadcn — not ported, would require significant CSS refactor
- **Socket.io real-time features**: admin-dashboard-dev uses client-side socket for online-status; ahmed_dashboard uses REST polling + its own socket server
- **React Hook Form + Zod validation**: admin-dashboard-dev forms use these — ahmed_dashboard uses plain React state forms (consistent with existing pages)
