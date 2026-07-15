"use client";

import { usePathname, useRouter } from "next/navigation";
import Link from "next/link";
// import { useTranslation } from "react-i18next";
import {
  Users,
  Settings,
  LogOut,
  Wallet,
  Info,
  Map,
  Award,
  Car,
  Bell,
  Ticket,
  FileText,
  ShoppingBag,
  BarChart3,
  Shield,
  FileX,
  Building2,
  MessageSquare,
  LogsIcon,
  Clock,
} from "lucide-react";
import { Button } from "@/components/ui/button";
import { Separator } from "@/components/ui/separator";
import { cn } from "@/lib/utils";
import { useAuthContext } from "@/contexts/AuthContext";

const navItems = [
  { path: "/users", labelKey: "User Management", icon: Users },
  { path: "/area-management", labelKey: "areaManagement", icon: Map },
  { path: "/badges", labelKey: "Badge Management", icon: Award },
  { path: "/roles", labelKey: "Role Management", icon: Shield },
  { path: "/reviews", labelKey: "Reviews Management", icon: MessageSquare },
  {
    path: "/courier-offices",
    labelKey: "Courier Office Management",
    icon: Building2,
  },
  {
    path: "/cancellation-reasons",
    labelKey: "Cancellation Reason Management",
    icon: FileX,
  },
  { path: "/orders", labelKey: "Order Management", icon: ShoppingBag },
  { path: "/logs", labelKey: "Log Management", icon: LogsIcon },
  {
    path: "/on-boarding-management",
    labelKey: "On Boarding Management",
    icon: FileText,
  },
  { path: "/coupons", labelKey: "Coupon Management", icon: Ticket },
  { path: "/vehicles", labelKey: "Vehicle Management", icon: Car },
  {
    path: "/manage-notifications",
    labelKey: "notificationManagement",
    icon: Bell,
  },
  { path: "/statistics", labelKey: "Statistics", icon: BarChart3 },
  { path: "/settings", labelKey: "App Settings Management", icon: Settings },
  { path: "/peak-time", labelKey: "Peak Time Management", icon: Clock },
  { path: "/about-app", labelKey: "About App Management", icon: Info },
  { path: "/payments", labelKey: "Payment Management", icon: Wallet },
  {
    path: "/unavailable-area-requests",
    labelKey: "unavailableAreaRequest.title",
    icon: Map,
  },
];

interface SidebarNavProps {
  collapsed?: boolean;
  onNavigate?: () => void;
}

export function SidebarNav({ collapsed = false, onNavigate }: SidebarNavProps) {
  // const { t } = useTranslation();
  const { logout } = useAuthContext();
  const router = useRouter();
  const pathname = usePathname();

  // Temporary mock for translation
  const t = (key: string) => key;

  const handleLogout = () => {
    logout();
    router.push("/login");
  };

  return (
    <div className="flex h-full flex-col">
      {/* Logo / brand */}
      <div
        className={cn(
          "flex h-14 items-center border-b border-border px-4",
          collapsed && "justify-center",
        )}
      >
        {!collapsed && (
          <span className="text-lg font-semibold text-foreground">
            {t("appName")}
          </span>
        )}
        {collapsed && <span className="text-lg font-bold text-primary">T</span>}
      </div>

      {/* Nav links */}
      <nav className="flex-1 space-y-1 overflow-y-auto p-2">
        {navItems.map((item) => {
          // More precise active state check to avoid matching similar route names
          const isActive = pathname === item.path || 
            (pathname.startsWith(item.path) && 
             (pathname.length === item.path.length || pathname[item.path.length] === '/'));

          return (
            <Link
              key={item.path}
              href={item.path}
              onClick={onNavigate}
              className={cn(
                "flex items-center gap-3 rounded-md px-3 py-2 text-sm font-medium transition-colors",
                collapsed && "justify-center px-2",
                isActive
                  ? "bg-accent text-accent-foreground"
                  : "text-muted-foreground hover:bg-accent hover:text-accent-foreground",
              )}
            >
              <item.icon className="h-4 w-4 shrink-0" />
              {!collapsed && <span>{t(item.labelKey)}</span>}
            </Link>
          );
        })}
      </nav>

      <Separator />

      {/* Logout */}
      <div className="p-2">
        <Button
          variant="ghost"
          className={cn(
            "w-full gap-3 text-muted-foreground",
            collapsed ? "justify-center px-2" : "justify-start",
          )}
          onClick={() => {
            handleLogout();
            onNavigate?.();
          }}
        >
          <LogOut className="h-4 w-4 shrink-0" />
          {!collapsed && <span>{t("logout")}</span>}
        </Button>
      </div>
    </div>
  );
}