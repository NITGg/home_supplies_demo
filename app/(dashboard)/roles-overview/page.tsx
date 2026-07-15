"use client";
import {
  Shield, Users, Store, Building2, CheckCircle,
  ShoppingCart, Navigation, MessageSquare, Truck,
  Package, Star, Wallet, Bell, FileText, HelpCircle,
  Map, BarChart2, Settings, DollarSign, Eye,
} from "lucide-react";
import { cn } from "@/lib/utils";
import { useT } from "@/contexts/LanguageContext";

// ─── Role definitions ─────────────────────────────────────────────────────────

interface RoleFunction {
  icon: React.ElementType;
  text: string;
}

interface RoleDef {
  id: string;
  name: string;
  badge: string;
  badgeColor: string;
  headerColor: string;
  iconColor: string;
  borderColor: string;
  icon: React.ElementType;
  functions: RoleFunction[];
}

const ROLES: RoleDef[] = [
  {
    id: "admin",
    name: "Admin",
    badge: "Full Access",
    badgeColor: "bg-indigo-100 text-indigo-700",
    headerColor: "bg-indigo-50 border-indigo-200",
    iconColor: "text-indigo-600",
    borderColor: "border-indigo-200",
    icon: Shield,
    functions: [
      { icon: ShoppingCart, text: "Manage all orders (view, cancel, track)" },
      { icon: Truck, text: "Manage couriers (approvals, offices, vehicles, live map)" },
      { icon: Store, text: "Manage suppliers (approvals, products, offers)" },
      { icon: Users, text: "Manage customers and users" },
      { icon: Package, text: "Manage catalogue (categories, products, brands)" },
      { icon: Bell, text: "Manage marketing (promotions, coupons, badges, notifications)" },
      { icon: Map, text: "Manage geography (areas, zones)" },
      { icon: Wallet, text: "Financial oversight (wallet, transactions, statistics)" },
      { icon: MessageSquare, text: "Chat & call any user" },
      { icon: FileText, text: "Manage content (articles, FAQs, onboarding)" },
      { icon: Settings, text: "System settings (roles, logs, translations, about app)" },
      { icon: CheckCircle, text: "Cancellation reasons management" },
      { icon: BarChart2, text: "View all analytics and statistics" },
    ],
  },
  {
    id: "seller",
    name: "Seller (Support Agent)",
    badge: "Support",
    badgeColor: "bg-amber-100 text-amber-700",
    headerColor: "bg-amber-50 border-amber-200",
    iconColor: "text-amber-600",
    borderColor: "border-amber-200",
    icon: Users,
    functions: [
      { icon: ShoppingCart, text: "View and monitor all active orders" },
      { icon: Navigation, text: "Live courier map view" },
      { icon: MessageSquare, text: "Chat with customers and couriers (support)" },
      { icon: Users, text: "Manage user accounts (view, support)" },
      { icon: Truck, text: "Manage courier profiles (view, support)" },
      { icon: Bell, text: "Send notifications" },
      { icon: FileText, text: "Manage content (articles, FAQs)" },
    ],
  },
  {
    id: "supplier",
    name: "Supplier",
    badge: "Supplier",
    badgeColor: "bg-green-100 text-green-700",
    headerColor: "bg-green-50 border-green-200",
    iconColor: "text-green-600",
    borderColor: "border-green-200",
    icon: Store,
    functions: [
      { icon: ShoppingCart, text: "View own orders and their statuses" },
      { icon: Package, text: "Manage own products and offers" },
      { icon: Wallet, text: "View own earnings and wallet" },
      { icon: Star, text: "View customer reviews" },
      { icon: MessageSquare, text: "Chat with support team (admin/seller only)" },
      { icon: CheckCircle, text: "View cancellation reasons" },
      { icon: Eye, text: "Request new cancellation reasons" },
      { icon: Settings, text: "Manage own profile and notifications" },
    ],
  },
  {
    id: "office",
    name: "Courier Office",
    badge: "Courier Office",
    badgeColor: "bg-blue-100 text-blue-700",
    headerColor: "bg-blue-50 border-blue-200",
    iconColor: "text-blue-600",
    borderColor: "border-blue-200",
    icon: Building2,
    functions: [
      { icon: Truck, text: "Manage their assigned couriers (view, approve)" },
      { icon: Navigation, text: "Live map showing their couriers" },
      { icon: ShoppingCart, text: "View orders assigned to their couriers" },
      { icon: DollarSign, text: "View office earnings and payouts" },
      { icon: MessageSquare, text: "Chat with their couriers and admin" },
      { icon: Building2, text: "Manage office profile" },
    ],
  },
];

// ─── Role card ────────────────────────────────────────────────────────────────

function RoleCard({ role }: { role: RoleDef }) {
  const Icon = role.icon;
  return (
    <div
      className={cn(
        "bg-white rounded-2xl border shadow-sm overflow-hidden flex flex-col",
        role.borderColor,
      )}
    >
      {/* Header */}
      <div className={cn("px-6 py-5 border-b", role.headerColor)}>
        <div className="flex items-center gap-3 mb-3">
          <div
            className={cn(
              "w-10 h-10 rounded-xl flex items-center justify-center",
              role.badgeColor,
            )}
          >
            <Icon size={20} className={role.iconColor} />
          </div>
          <div>
            <h3 className="font-bold text-gray-900 text-base">{role.name}</h3>
            <span
              className={cn(
                "text-xs font-medium px-2 py-0.5 rounded-full",
                role.badgeColor,
              )}
            >
              {role.badge}
            </span>
          </div>
        </div>
      </div>

      {/* Functions */}
      <div className="px-6 py-5 flex-1">
        <ul className="space-y-3">
          {role.functions.map((fn, i) => {
            const FnIcon = fn.icon;
            return (
              <li key={i} className="flex items-start gap-2.5">
                <FnIcon
                  size={14}
                  className={cn("flex-shrink-0 mt-0.5", role.iconColor)}
                />
                <span className="text-sm text-gray-700 leading-snug">{fn.text}</span>
              </li>
            );
          })}
        </ul>
      </div>
    </div>
  );
}

// ─── Main page ────────────────────────────────────────────────────────────────

export default function RolesOverviewPage() {
  const { isRTL } = useT();

  return (
    <div className="p-6 space-y-6" dir={isRTL ? "rtl" : "ltr"}>
      {/* Header */}
      <div>
        <div className="flex items-center gap-2 mb-1">
          <Shield size={22} className="text-indigo-600" />
          <h1 className="text-2xl font-bold text-gray-900">Roles Overview</h1>
        </div>
        <p className="text-sm text-gray-500">
          A summary of each role&apos;s responsibilities and access in the system.
        </p>
      </div>

      {/* Grid */}
      <div className="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-4 gap-5">
        {ROLES.map((role) => (
          <RoleCard key={role.id} role={role} />
        ))}
      </div>

      {/* Footer note */}
      <div className="bg-gray-50 border border-gray-200 rounded-xl px-5 py-4 flex items-start gap-3">
        <Shield size={16} className="text-gray-400 flex-shrink-0 mt-0.5" />
        <p className="text-sm text-gray-500">
          Access is enforced server-side on each API request. This overview is for informational
          purposes only. Contact system administration to change a user&apos;s role.
        </p>
      </div>
    </div>
  );
}
