"use client";
import { useState, useMemo } from "react";
import Link from "next/link";
import { usePathname } from "next/navigation";
import {
  Tag,
  Users,
  Package,
  LogOut,
  Languages,
  Globe,
  Bookmark,
  ShoppingCart,
  CheckSquare,
  Ticket,
  Megaphone,
  Truck,
  Building2,
  Car,
  MapPin,
  Map,
  Award,
  XCircle,
  Repeat,
  FileText,
  HelpCircle,
  Smartphone,
  Mail,
  Star,
  Bell,
  Wallet,
  AlertTriangle,
  Navigation,
  MessageSquare,
  BarChart2,
  Settings,
  Info,
  Shield,
  Activity,
  Search,
  ChevronRight,
  PanelLeftClose,
  PanelLeftOpen,
  Store,
  LayoutDashboard,
  DollarSign,
  Package2,
  ClipboardList,
  UserCheck,
  Headphones,
  TrendingUp,
  Clock,
  ShoppingBag,
  PackagePlus,
  PackageSearch,
  History,
} from "lucide-react";
import { logout } from "@/lib/auth";
import { cn } from "@/lib/utils";
import { useT } from "@/contexts/LanguageContext";
import { useRole } from "@/hooks/useRole";
import type { AppRole } from "@/lib/rbac";

interface NavItem {
  href: string;
  labelKey: string;
  icon: React.ElementType;
}
interface NavGroup {
  titleKey: string;
  items: NavItem[];
  roles?: AppRole[]; // undefined = all roles can see it
}

// ── Admin nav (full access) ───────────────────────────────────────────────────
const ADMIN_GROUPS: NavGroup[] = [
  {
    titleKey: "navGroup.orders",
    items: [
      { href: "/orders", labelKey: "nav.orders", icon: ShoppingCart },
      { href: "/refunds", labelKey: "nav.refunds", icon: ShoppingCart },
    ],
  },
  {
    titleKey: "navGroup.delivery",
    items: [
      { href: "/couriers-map", labelKey: "nav.couriersMap", icon: Navigation },
      { href: "/chat", labelKey: "nav.chat", icon: MessageSquare },
      {
        href: "/courier-approvals",
        labelKey: "nav.courierApprovals",
        icon: Truck,
      },
      {
        href: "/courier-offices",
        labelKey: "nav.courierOffices",
        icon: Building2,
      },
      { href: "/vehicles", labelKey: "nav.vehicles", icon: Car },
      { href: "/peak-time", labelKey: "nav.peakTime", icon: Clock },
    ],
  },
  {
    titleKey: "navGroup.catalogue",
    items: [
      { href: "/categories", labelKey: "nav.categories", icon: Tag },
      { href: "/brands", labelKey: "nav.brands", icon: Bookmark },
      { href: "/products", labelKey: "nav.products", icon: Package },
    ],
  },
  {
    titleKey: "navGroup.users",
    items: [
      { href: "/users", labelKey: "nav.users", icon: Users },
      { href: "/badges", labelKey: "nav.badges", icon: Award },
    ],
  },
  {
    titleKey: "navGroup.geography",
    items: [
      { href: "/governorates", labelKey: "nav.governorates", icon: MapPin },
      { href: "/areas", labelKey: "nav.areas", icon: Map },
      {
        href: "/area-requests",
        labelKey: "nav.areaRequests",
        icon: AlertTriangle,
      },
    ],
  },
  {
    titleKey: "navGroup.marketing",
    items: [
      { href: "/coupons", labelKey: "nav.coupons", icon: Ticket },
      {
        href: "/courier-coupons",
        labelKey: "nav.courierCoupons",
        icon: Repeat,
      },
      { href: "/ads", labelKey: "nav.ads", icon: Megaphone },
      {
        href: "/cancellation-reasons",
        labelKey: "nav.cancellationReasons",
        icon: XCircle,
      },
    ],
  },
  {
    titleKey: "navGroup.content",
    items: [
      { href: "/articles", labelKey: "nav.articles", icon: FileText },
      { href: "/faqs", labelKey: "nav.faqs", icon: HelpCircle },
      { href: "/onboarding", labelKey: "nav.onboarding", icon: Smartphone },
    ],
  },
  {
    titleKey: "navGroup.finance",
    items: [
      { href: "/wallet", labelKey: "nav.wallet", icon: Wallet },
      { href: "/wallet-entry", labelKey: "nav.walletEntry", icon: FileText },
    ],
  },
  {
    titleKey: "navGroup.support",
    items: [
      { href: "/contact", labelKey: "nav.contact", icon: Mail },
      { href: "/reviews", labelKey: "nav.reviews", icon: Star },
      { href: "/notifications", labelKey: "nav.notifications", icon: Bell },
    ],
  },
  {
    titleKey: "navGroup.system",
    items: [
      { href: "/statistics", labelKey: "nav.statistics", icon: BarChart2 },
      {
        href: "/external-apps",
        labelKey: "nav.external-apps",
        icon: BarChart2,
      },
      { href: "/roles", labelKey: "nav.roles", icon: Shield },
      { href: "/roles-overview", labelKey: "nav.rolesOverview", icon: Users },
      { href: "/logs", labelKey: "nav.logs", icon: Activity },
      { href: "/settings", labelKey: "nav.settings", icon: Settings },
      { href: "/about-app", labelKey: "nav.aboutApp", icon: Info },
      { href: "/translations", labelKey: "nav.translations", icon: Globe },
      { href: "/translations/apps", labelKey: "nav.appTranslations", icon: Languages },
    ],
  },
];

// ── Supplier nav ──────────────────────────────────────────────────────────────
const SUPPLIER_GROUPS: NavGroup[] = [
  {
    titleKey: "navGroup.overview",
    items: [
      {
        href: "/supplier/dashboard",
        labelKey: "nav.supplierDashboard",
        icon: LayoutDashboard,
      },
    ],
  },
  {
    titleKey: "navGroup.personalOrders",
    items: [
      {
        href: "/supplier/personal-orders/create",
        labelKey: "nav.supplierCreateOrder",
        icon: PackagePlus,
      },
      {
        href: "/supplier/personal-orders/active",
        labelKey: "nav.supplierActiveOrders",
        icon: PackageSearch,
      },
      {
        href: "/supplier/personal-orders/history",
        labelKey: "nav.supplierOrderHistory",
        icon: History,
      },
    ],
  },
  {
    titleKey: "navGroup.myBusiness",
    items: [
      {
        href: "/supplier/orders",
        labelKey: "nav.supplierOrders",
        icon: ShoppingCart,
      },
      {
        href: "/supplier/shop",
        labelKey: "nav.supplierShop",
        icon: ShoppingBag,
      },
      {
        href: "/supplier/products",
        labelKey: "nav.supplierProducts",
        icon: Package2,
      },
      {
        href: "/supplier/reviews",
        labelKey: "nav.supplierReviews",
        icon: Star,
      },
    ],
  },
  {
    titleKey: "navGroup.finance",
    items: [
      {
        href: "/supplier/earnings",
        labelKey: "nav.supplierEarnings",
        icon: TrendingUp,
      },
      {
        href: "/supplier/wallet",
        labelKey: "nav.supplierWallet",
        icon: Wallet,
      },
    ],
  },
  {
    titleKey: "navGroup.account",
    items: [
      {
        href: "/supplier/profile",
        labelKey: "nav.supplierProfile",
        icon: Store,
      },
      {
        href: "/supplier/notifications",
        labelKey: "nav.supplierNotifications",
        icon: Bell,
      },
    ],
  },
  {
    titleKey: "navGroup.support",
    items: [
      {
        href: "/supplier/chat",
        labelKey: "nav.supplierChat",
        icon: MessageSquare,
      },
      {
        href: "/supplier/cancellations",
        labelKey: "nav.supplierCancellations",
        icon: XCircle,
      },
      {
        href: "/supplier/support",
        labelKey: "nav.supplierSupport",
        icon: Headphones,
      },
      { href: "/articles", labelKey: "nav.articles", icon: FileText },
      { href: "/faqs", labelKey: "nav.faqs", icon: HelpCircle },
    ],
  },
];

// ── Seller / Support nav ──────────────────────────────────────────────────────
const SELLER_GROUPS: NavGroup[] = [
  {
    titleKey: "navGroup.operations",
    items: [
      {
        href: "/support/orders",
        labelKey: "nav.supportOrders",
        icon: ClipboardList,
      },
      { href: "/support/map", labelKey: "nav.supportMap", icon: Navigation },
      {
        href: "/support/chat",
        labelKey: "nav.supportChat",
        icon: MessageSquare,
      },
    ],
  },
  {
    titleKey: "navGroup.users",
    items: [
      { href: "/support/users", labelKey: "nav.supportUsers", icon: Users },
      {
        href: "/support/couriers",
        labelKey: "nav.supportCouriers",
        icon: Truck,
      },
    ],
  },
  {
    titleKey: "navGroup.content",
    items: [
      { href: "/articles", labelKey: "nav.articles", icon: FileText },
      { href: "/faqs", labelKey: "nav.faqs", icon: HelpCircle },
      { href: "/notifications", labelKey: "nav.notifications", icon: Bell },
    ],
  },
];

// ── Customer Support nav ──────────────────────────────────────────────────────
const CUSTOMER_SUPPORT_GROUPS: NavGroup[] = [
  {
    titleKey: "navGroup.operations",
    items: [
      { href: "/support/orders",        labelKey: "nav.supportOrders",        icon: ClipboardList },
      { href: "/support/map",           labelKey: "nav.supportMap",           icon: Navigation },
    ],
  },
  {
    titleKey: "navGroup.users",
    items: [
      { href: "/support/users",         labelKey: "nav.supportUsers",         icon: Users },
      { href: "/support/couriers",      labelKey: "nav.supportCouriers",      icon: Truck },
    ],
  },
  {
    titleKey: "navGroup.support",
    items: [
      { href: "/support/chat",          labelKey: "nav.supportChat",          icon: MessageSquare },
    ],
  },
];

// ── Courier Office nav ────────────────────────────────────────────────────────
const OFFICE_GROUPS: NavGroup[] = [
  {
    titleKey: "navGroup.myCouriers",
    items: [
      { href: "/office/couriers", labelKey: "nav.officeCouriers", icon: Truck },
    ],
  },
  {
    titleKey: "navGroup.operations",
    items: [
      {
        href: "/office/orders",
        labelKey: "nav.officeOrders",
        icon: ShoppingCart,
      },
      {
        href: "/office/earnings",
        labelKey: "nav.officeEarnings",
        icon: DollarSign,
      },
    ],
  },
  {
    titleKey: "navGroup.account",
    items: [
      {
        href: "/office/profile",
        labelKey: "nav.officeProfile",
        icon: Building2,
      },
      { href: "/faqs", labelKey: "nav.faqs", icon: HelpCircle },
    ],
  },
];

// ── Group + item label dictionaries ──────────────────────────────────────────
const GROUP_LABELS_EN: Record<string, string> = {
  "navGroup.orders": "Orders",
  "navGroup.delivery": "Delivery",
  "navGroup.catalogue": "Catalogue",
  "navGroup.users": "Users",
  "navGroup.geography": "Geography",
  "navGroup.marketing": "Marketing",
  "navGroup.content": "Content",
  "navGroup.finance": "Finance",
  "navGroup.support": "Support",
  "navGroup.system": "System",
  "navGroup.overview": "Overview",
  "navGroup.personalOrders": "Personal Orders",
  "navGroup.myBusiness": "My Business",
  "navGroup.account": "Account",
  "navGroup.operations": "Operations",
  "navGroup.myCouriers": "My Couriers",
};
const GROUP_LABELS_AR: Record<string, string> = {
  "navGroup.orders": "الطلبات",
  "navGroup.delivery": "التوصيل",
  "navGroup.catalogue": "الكتالوج",
  "navGroup.users": "المستخدمون",
  "navGroup.geography": "الجغرافيا",
  "navGroup.marketing": "التسويق",
  "navGroup.content": "المحتوى",
  "navGroup.finance": "المالية",
  "navGroup.support": "الدعم",
  "navGroup.system": "النظام",
  "navGroup.overview": "نظرة عامة",
  "navGroup.personalOrders": "الطلبات الشخصية",
  "navGroup.myBusiness": "عملي",
  "navGroup.account": "الحساب",
  "navGroup.operations": "العمليات",
  "navGroup.myCouriers": "مندوبيّ",
};

const ITEM_LABELS_EN: Record<string, string> = {
  "nav.orders": "Orders",
  "nav.refunds": "Refunds",
  "nav.couriersMap": "Couriers Map",
  "nav.chat": "Chat",
  "nav.suppliers": "Suppliers",
  "nav.courierApprovals": "Courier Approvals",
  "nav.courierOffices": "Courier Offices",
  "nav.vehicles": "Vehicles",
  "nav.peakTime": "Peak Time",
  "nav.categories": "Categories",
  "nav.brands": "Brands",
  "nav.products": "Products",
  "nav.users": "Users",
  "nav.badges": "Badges",
  "nav.governorates": "Governorates",
  "nav.areas": "Areas",
  "nav.areaRequests": "Area Requests",
  "nav.coupons": "Coupons",
  "nav.courierCoupons": "Courier Coupons",
  "nav.ads": "Ads",
  "nav.cancellationReasons": "Cancellation Reasons",
  "nav.articles": "Articles",
  "nav.faqs": "FAQs",
  "nav.onboarding": "Onboarding",
  "nav.wallet": "Wallet",
  "nav.walletEntry": "Wallet Entries",
  "nav.contact": "Contact",
  "nav.reviews": "Reviews",
  "nav.notifications": "Notifications",
  "nav.statistics": "Statistics",
  "nav.roles": "Roles",
  "nav.logs": "Logs",
  "nav.settings": "Settings",
  "nav.aboutApp": "About App",
  "nav.translations": "Translations",
  "nav.appTranslations": "App Translations (i18n)",
  // Supplier
  "nav.supplierDashboard": "Dashboard",
  "nav.supplierCreateOrder": "Create Order",
  "nav.supplierActiveOrders": "Active Orders",
  "nav.supplierOrderHistory": "Orders History",
  "nav.supplierOrders": "My Orders",
  "nav.supplierShop": "My Shop",
  "nav.supplierProducts": "My Products",
  "nav.supplierOffers": "My Offers",
  "nav.supplierReviews": "Reviews",
  "nav.supplierEarnings": "Earnings",
  "nav.supplierWallet": "My Wallet",
  "nav.supplierProfile": "My Profile",
  "nav.supplierWorkingHours": "Working Hours",
  "nav.supplierNotifications": "Notifications",
  "nav.supplierSupport": "Support",
  "nav.supplierChat": "Messages",
  "nav.supplierCancellations": "Cancellations",
  // Seller / Support
  "nav.supportOrders": "All Orders",
  "nav.supportMap": "Live Map",
  "nav.supportChat": "Chat",
  "nav.supportUsers": "Users",
  "nav.supportCouriers": "Couriers",
  // Courier Office
  "nav.officeCouriers": "My Couriers",
  "nav.officeMap": "Live Map",
  "nav.officeOrders": "Orders",
  "nav.officeEarnings": "Earnings",
  "nav.officeProfile": "Office Profile",
  "nav.officeChat": "Messages",
  // Roles
  "nav.rolesOverview": "Roles Overview",
  "nav.external-apps": "External Apps",
};
const ITEM_LABELS_AR: Record<string, string> = {
  "nav.orders": "الطلبات",
  "nav.refunds": "استرداد",
  "nav.couriersMap": "خريطة المندوبين",
  "nav.chat": "المحادثات",
  "nav.suppliers": "الموردون",
  "nav.courierApprovals": "موافقات المندوبين",
  "nav.courierOffices": "مكاتب التوصيل",
  "nav.vehicles": "المركبات",
  "nav.peakTime": "إدارة أوقات الذروة",
  "nav.categories": "الفئات",
  "nav.brands": "الماركات",
  "nav.products": "المنتجات",
  "nav.users": "المستخدمون",
  "nav.badges": "الشارات",
  "nav.governorates": "المحافظات",
  "nav.areas": "المناطق",
  "nav.areaRequests": "طلبات المناطق",
  "nav.coupons": "الكوبونات",
  "nav.courierCoupons": "كوبونات المندوبين",
  "nav.ads": "الإعلانات",
  "nav.cancellationReasons": "أسباب الإلغاء",
  "nav.articles": "المقالات",
  "nav.faqs": "الأسئلة الشائعة",
  "nav.onboarding": "تعريف التطبيق",
  "nav.wallet": "المحفظة",
  "nav.walletEntry": "حركات المحفظة",
  "nav.contact": "التواصل",
  "nav.reviews": "التقييمات",
  "nav.notifications": "الإشعارات",
  "nav.statistics": "الإحصائيات",
  "nav.roles": "الأدوار",
  "nav.logs": "السجلات",
  "nav.settings": "الإعدادات",
  "nav.aboutApp": "عن التطبيق",
  "nav.translations": "الترجمات",
  "nav.appTranslations": "ترجمات التطبيقات (i18n)",
  // Supplier
  "nav.supplierDashboard": "لوحة التحكم",
  "nav.supplierCreateOrder": "إنشاء طلب",
  "nav.supplierActiveOrders": "الطلبات النشطة",
  "nav.supplierOrderHistory": "سجل الطلبات",
  "nav.supplierOrders": "طلباتي",
  "nav.supplierShop": "متجري",
  "nav.supplierProducts": "منتجاتي",
  "nav.supplierOffers": "عروضي",
  "nav.supplierReviews": "التقييمات",
  "nav.supplierEarnings": "الأرباح",
  "nav.supplierWallet": "محفظتي",
  "nav.supplierProfile": "ملفي الشخصي",
  "nav.supplierWorkingHours": "ساعات العمل",
  "nav.supplierNotifications": "الإشعارات",
  "nav.supplierSupport": "الدعم",
  "nav.supplierChat": "الرسائل",
  "nav.supplierCancellations": "الإلغاءات",
  // Seller / Support
  "nav.supportOrders": "جميع الطلبات",
  "nav.supportMap": "الخريطة المباشرة",
  "nav.supportChat": "المحادثات",
  "nav.supportUsers": "المستخدمون",
  "nav.supportCouriers": "المندوبون",
  // Courier Office
  "nav.officeCouriers": "مندوبيّ",
  "nav.officeMap": "الخريطة المباشرة",
  "nav.officeOrders": "الطلبات",
  "nav.officeEarnings": "الأرباح",
  "nav.officeProfile": "ملف المكتب",
  "nav.officeChat": "الرسائل",
  // Roles
  "nav.rolesOverview": "نظرة على الأدوار",
  "nav.external-apps": "تطبيقات خارجية",
};

// ── Role → badge color ────────────────────────────────────────────────────────
const ROLE_BADGE: Record<
  string,
  { label: string; labelAr: string; color: string }
> = {
  Admin: { label: "Admin", labelAr: "مدير", color: "bg-indigo-600" },
  Seller: { label: "Support", labelAr: "دعم", color: "bg-amber-600" },
  Supplier: { label: "Supplier", labelAr: "مورد", color: "bg-emerald-600" },
  CourierOffice: {
    label: "Courier Office",
    labelAr: "مكتب توصيل",
    color: "bg-blue-600",
  },
  CustomerSupport: {
    label: "Customer Support",
    labelAr: "دعم العملاء",
    color: "bg-teal-600",
  },
};

export default function Sidebar() {
  const path = usePathname();
  const { t, lang, setLang } = useT();
  const { user, role } = useRole();
  const [collapsed, setCollapsed] = useState(false);
  const [search, setSearch] = useState("");
  const [collapsedGroups, setCollapsedGroups] = useState<Set<string>>(
    new Set(),
  );

  // Pick nav groups based on role
  const navGroups = useMemo((): NavGroup[] => {
    switch (role) {
      case "Supplier":        return SUPPLIER_GROUPS;
      case "Seller":          return SELLER_GROUPS;
      case "CourierOffice":   return OFFICE_GROUPS;
      case "CustomerSupport": return CUSTOMER_SUPPORT_GROUPS;
      default:                return ADMIN_GROUPS;
    }
  }, [role]);

  const groupLabels = lang === "AR" ? GROUP_LABELS_AR : GROUP_LABELS_EN;
  const itemLabels = lang === "AR" ? ITEM_LABELS_AR : ITEM_LABELS_EN;

  const toggleGroup = (key: string) => {
    setCollapsedGroups((prev) => {
      const next = new Set(prev);
      if (next.has(key)) next.delete(key);
      else next.add(key);
      return next;
    });
  };

  const searchResults = useMemo(() => {
    const q = search.trim().toLowerCase();
    if (!q) return null;
    const results: NavItem[] = [];
    for (const group of navGroups) {
      for (const item of group.items) {
        const label = itemLabels[item.labelKey] ?? "";
        if (label.toLowerCase().includes(q) || item.href.includes(q)) {
          results.push(item);
        }
      }
    }
    return results;
  }, [search, itemLabels, navGroups]);

  const badge = ROLE_BADGE[role] ?? ROLE_BADGE.Admin;

  return (
    <aside
      className={cn(
        "min-h-screen bg-gray-900 text-white flex flex-col shrink-0 transition-all duration-200",
        collapsed ? "w-16" : "w-60",
      )}
    >
      {/* Brand + collapse toggle */}
      <div className="flex items-center gap-2 px-3 py-4 border-b border-gray-700">
        <div className="w-9 h-9 rounded-xl bg-indigo-600 flex items-center justify-center font-bold text-lg shrink-0">
          T
        </div>
        {!collapsed && (
          <span className="font-bold text-lg flex-1 truncate">
            {t("brand")}
          </span>
        )}
        <button
          onClick={() => setCollapsed((v) => !v)}
          className="p-1.5 rounded-lg hover:bg-gray-800 text-gray-400 hover:text-white transition shrink-0"
          title={collapsed ? "Expand sidebar" : "Collapse sidebar"}
        >
          {collapsed ? (
            <PanelLeftOpen size={16} />
          ) : (
            <PanelLeftClose size={16} />
          )}
        </button>
      </div>

      {/* Role badge */}
      {!collapsed && user && (
        <div className="px-3 pt-3 pb-1">
          <div className="flex items-center gap-2 px-2 py-1.5 rounded-lg bg-gray-800">
            <div className={cn("w-2 h-2 rounded-full shrink-0", badge.color)} />
            <div className="min-w-0">
              <p className="text-xs font-medium text-white truncate">
                {user.full_name}
              </p>
              <p className="text-[10px] text-gray-400">
                {lang === "AR" ? badge.labelAr : badge.label}
              </p>
            </div>
          </div>
        </div>
      )}

      {/* Search */}
      {!collapsed && (
        <div className="px-3 pt-2 pb-1">
          <div className="relative">
            <Search
              size={13}
              className="absolute left-2.5 top-1/2 -translate-y-1/2 text-gray-500 pointer-events-none"
            />
            <input
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              placeholder={lang === "AR" ? "بحث…" : "Search…"}
              className="w-full bg-gray-800 text-white text-sm pl-8 pr-3 py-1.5 rounded-lg placeholder-gray-500 outline-none focus:ring-1 focus:ring-indigo-500"
            />
            {search && (
              <button
                onClick={() => setSearch("")}
                className="absolute right-2 top-1/2 -translate-y-1/2 text-gray-500 hover:text-gray-300"
              >
                <XCircle size={13} />
              </button>
            )}
          </div>
        </div>
      )}

      {/* Nav */}
      <nav className="flex-1 px-2 py-2 overflow-y-auto space-y-1">
        {searchResults !== null ? (
          <div className="space-y-0.5">
            {searchResults.length === 0 ? (
              <p className="text-xs text-gray-500 px-3 py-6 text-center">
                {lang === "AR" ? "لا نتائج" : "No results"}
              </p>
            ) : (
              searchResults.map(({ href, labelKey, icon: Icon }) => (
                <Link
                  key={href}
                  href={href}
                  onClick={() => setSearch("")}
                  className={cn(
                    "flex items-center gap-3 px-3 py-2 rounded-lg text-sm font-medium transition",
                    path.startsWith(href)
                      ? "bg-indigo-600 text-white"
                      : "text-gray-400 hover:bg-gray-800 hover:text-white",
                  )}
                >
                  <Icon size={16} className="shrink-0" />
                  {itemLabels[labelKey]}
                </Link>
              ))
            )}
          </div>
        ) : (
          navGroups.map((group) => {
            const isOpen = !collapsedGroups.has(group.titleKey);
            return (
              <div key={group.titleKey}>
                {collapsed ? (
                  <div className="my-1 border-t border-gray-700/60" />
                ) : (
                  <button
                    onClick={() => toggleGroup(group.titleKey)}
                    className="w-full flex items-center justify-between px-3 py-1 rounded-lg hover:bg-gray-800/40 transition group"
                  >
                    <span className="text-[10px] font-semibold uppercase tracking-widest text-gray-500 group-hover:text-gray-400">
                      {groupLabels[group.titleKey] ?? group.titleKey}
                    </span>
                    <ChevronRight
                      size={12}
                      className={cn(
                        "text-gray-600 transition-transform duration-150",
                        isOpen && "rotate-90",
                      )}
                    />
                  </button>
                )}

                {(collapsed || isOpen) && (
                  <div className="space-y-0.5 mt-0.5">
                    {group.items.map(({ href, labelKey, icon: Icon }) => {
                      // More precise active state check to avoid matching similar route names
                      const isActive =
                        path === href ||
                        (path.startsWith(href) &&
                          (path.length === href.length ||
                            path[href.length] === "/"));

                      return (
                        <Link
                          key={href}
                          href={href}
                          title={collapsed ? itemLabels[labelKey] : undefined}
                          className={cn(
                            "flex items-center gap-3 py-2 rounded-lg text-sm font-medium transition",
                            collapsed ? "justify-center px-2" : "px-3",
                            isActive
                              ? "bg-indigo-600 text-white"
                              : "text-gray-400 hover:bg-gray-800 hover:text-white",
                          )}
                        >
                          <Icon size={16} className="shrink-0" />
                          {!collapsed && itemLabels[labelKey]}
                        </Link>
                      );
                    })}
                  </div>
                )}
              </div>
            );
          })
        )}
      </nav>

      {/* Bottom actions */}
      <div className="px-2 py-3 border-t border-gray-700 space-y-1">
        <button
          onClick={() => setLang(lang === "EN" ? "AR" : "EN")}
          title={collapsed ? t("lang.switch") : undefined}
          className={cn(
            "flex items-center gap-3 w-full py-2.5 rounded-lg text-sm text-gray-400 hover:bg-gray-800 hover:text-white transition",
            collapsed ? "justify-center px-2" : "px-3",
          )}
        >
          <Languages size={18} />
          {!collapsed && t("lang.switch")}
        </button>
        <button
          onClick={logout}
          title={collapsed ? t("nav.logout") : undefined}
          className={cn(
            "flex items-center gap-3 w-full py-2.5 rounded-lg text-sm text-gray-400 hover:bg-gray-800 hover:text-white transition",
            collapsed ? "justify-center px-2" : "px-3",
          )}
        >
          <LogOut size={18} />
          {!collapsed && t("nav.logout")}
        </button>
      </div>
    </aside>
  );
}
