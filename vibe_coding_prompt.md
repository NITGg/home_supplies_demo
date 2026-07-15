# Vibe Coding Prompt for Admin Dashboard

_Copy and paste the prompt below into your AI assistant (e.g., Cursor, GitHub Copilot, ChatGPT, or Claude) to start building your Admin Dashboard._

---

**System Role:** You are an expert Frontend Developer and UI/UX Designer specializing in React/Next.js and modern admin panels. We are building the "Tawreedat Go" Admin Dashboard.

### Project Context

I have a robust Node.js/Express backend for an e-commerce & courier delivery platform called `tawreedat_go`. I need to build a comprehensive, modern, and fully responsive Admin Dashboard to manage users, roles, couriers, orders, wallets, public content, and application settings.

Please use modern design aesthetics (e.g., Tailwind CSS, Shadcn UI, or Material-UI) with a sleek sidebar layout, dashboard overview widgets, and highly functional data tables with sorting, filtering, and pagination.

### Objective

Your goal is to scaffold the pages, API integration services (using Axios or Fetch), and React components to interact with the existing backend APIs smoothly. Please focus on creating reusable table components, form modals for additions/edits, and a centralized authentication state.

### Existing Backend APIs

Below is the complete catalog of REST APIs available for the Admin role. All endpoints are prefixed with the base URL (e.g., `/api/v1`). Assume standard RESTful patterns for requests (e.g., JSON bodies for `POST`/`PUT` containing the resource fields, except when an `image` or `photo` upload is specified, which requires `multipart/form-data`).

#### 🔐 Authentication (`/auth`)

- `POST /auth/login` → body: `{ email, password }` → returns: auth token and user detials

#### 👥 Users Management (`/users`)

- `GET /users` → List all users
- `POST /users` (multipart: `photo`) → Create a new user
- `GET /users/:id` → Get user details
- `PUT /users/:id` (multipart: `photo`) → Update a user
- `DELETE /users` → Bulk delete users
- `DELETE /users/:id` → Delete a user
- `GET /users/:userId/addresses` → List user addresses
- `POST /users/:userId/addresses` → Create user address
- `PUT /users/:userId/addresses/:addressId` → Update address
- `DELETE /users/:userId/addresses/:addressId` → Delete address

#### 🛡️ Roles Management (`/roles`)

- `GET /roles` → List all roles
- `POST /roles` → Create a role
- `GET /roles/:id` → Get role details
- `PUT /roles/:id` → Update a role
- `DELETE /roles` → Bulk delete roles
- `DELETE /roles/:id` → Delete a role

#### 📛 Badges Management (`/badges`)

- `GET /badges` → List badges
- `POST /badges` (multipart: `image`) → Create a badge
- `GET /badges/:id` → Get badge
- `PUT /badges/:id` (multipart: `image`) → Update badge
- `DELETE /badges` → Bulk delete badges
- `DELETE /badges/:id` → Delete badge

#### 📦 Orders Management (`/admin/orders`)

- `GET /admin/orders` → List orders
- `GET /admin/orders/:id` → Get order details
- `PUT /admin/orders/:id` → Update order
- `POST /admin/orders/:id/cancel` → Cancel an order
- `GET /admin/orders/:id/proposals` → List order proposals
- `PATCH /admin/orders/proposals/:proposalId` → Update order proposal

#### 🗺️ Areas & Governorates (`/admin/areas`, `/admin/governorates`)

- `GET /admin/governorates` → List governorates
- `POST /admin/governorates` → Create governorate
- `GET /admin/governorates/:id` → Get governorate
- `PUT /admin/governorates/:id` → Update governorate
- `DELETE /admin/governorates` / `DELETE /admin/governorates/:id` → Delete governorates
  _Same CRUD endpoints exist for `/admin/areas`._

#### 📚 Articles Management (`/admin/articles`)

- `GET /admin/articles` → List articles
- `POST /admin/articles` (multipart: `cover_image`) → Create article
- `GET /admin/articles/:id` → Get article
- `PUT /admin/articles/:id` (multipart: `cover_image`) → Update article
- `DELETE /admin/articles` / `DELETE /admin/articles/:id` → Delete articles

#### ⚙️ Settings & Info (`/app-settings`, `/about-app`)

- `GET /app-settings` → Get all settings
- `PUT /app-settings` → Upsert settings
- `GET /about-app` → Get "About Us" content
- `PUT /about-app` → Upsert "About Us" content

#### ❓ FAQs & On-Boarding (`/admin/faqs`, `/admin/on-boarding`)

- **FAQs:** Full CRUD on `/admin/faqs`
- **On-Boarding:** Full CRUD on `/admin/on-boarding` (POST/PUT support `image` upload)

#### 🎟️ Customer Coupons (`/admin/customer-coupons`)

- `GET /admin/customer-coupons` → List coupons
- `POST /admin/customer-coupons` → Create coupon
- `GET /admin/customer-coupons/:id` → Get coupon details
- `PUT /admin/customer-coupons/:id` → Update coupon
- `DELETE /admin/customer-coupons` / `DELETE /admin/customer-coupons/:id` → Delete coupons
- `GET /admin/customer-coupons/user/:userId/usages` → List usages by user

#### ⭐ Reviews (`/admin/customer-reviews`, `/admin/courier-reviews`)

- **Customer Reviews:** GET/DELETE on `/admin/customer-reviews`
- **Courier Reviews:** Full CRUD on `/admin/courier-reviews`

#### 📞 Contact Us (`/contact-us`)

- `GET /contact-us` → List contact messages
- `GET /contact-us/:id` → Get specific message
- `PUT /contact-us/:id` → Update message (e.g., resolve)
- `DELETE /contact-us` / `DELETE /contact-us/:id` → Delete messages

#### 💰 Admin Wallet (`/admin/wallet`)

- `GET /admin/wallet/wallets` → List wallets
- `GET /admin/wallet/unpaidCommissions` → List unpaid commissions
- `GET /admin/wallet/penalties` → List penalties
- `GET /admin/wallet/escrows` → List escrows
- `GET /admin/wallet/paymentMethods` → List payment methods
- `GET /admin/wallet/transactions` → List transactions
- `POST /admin/wallet/adjust-balance/:userId` → Adjust a user's balance
- `POST /admin/wallet/freeze/:walletId` → Freeze wallet
- `POST /admin/wallet/unfreeze/:walletId` → Unfreeze wallet
- `POST /admin/wallet/apply-penalty/:userId` → Apply penalty
- `POST /admin/wallet/waive-penalty/:penaltyId` → Waive penalty
- `POST` / `GET` / `PATCH` for platform wallet records...

#### ✅ Admin Approvals (`/admin/approval`)

- `GET /admin/approval/all-couriers` → List couriers pending approval
- `GET /admin/approval/courier-details/:courierId` → Get details of courier pending approval
- `POST /admin/approval/approve-courier/:courierId` → Approve courier
- `POST /admin/approval/reject-courier/:courierId` → Reject courier

### Tasks for You:

1. **Initialize Project:** Create the structural layout including a top navbar (with user info/logout) and a comprehensive sidebar outlining all the modules listed above.
2. **Setup Routing:** Generate placeholder pages for each core section (Users, Orders, Wallets, Content Management, etc.) using `react-router-dom` or Next.js file-system routing.
3. **API Integration Structure:** Create an Axios instance with interceptors to automatically attach the auth token to requests and handle 401 unauthenticated errors.
4. **First Feature Implementation:** Fully implement the **Admin Approvals** and **Users Management** screens first, complete with API hooks, data tables, and action buttons.
5. **State Management:** Set up a lightweight state manager (like Zustand or React Context) to manage the global authentication state.

_Please provide the initial folder structure, the Axios instance setup, and the complete code for the layout and the "Users Management" page._
