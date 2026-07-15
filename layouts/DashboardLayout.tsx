// import { useEffect, useState } from "react";
// import { Outlet } from "react-router-dom";
// import { useTranslation } from "react-i18next";
// import { Menu, PanelLeftClose, PanelLeft, Bell } from "lucide-react";
// import { Button } from "@/components/ui/button";
// import { Sheet, SheetContent, SheetTitle } from "@/components/ui/sheet";
// import { Separator } from "@/components/ui/separator";
// import { ThemeToggle } from "@/components/layout/ThemeToggle";
// import { LanguageSwitcher } from "@/components/layout/LanguageSwitcher";
// import { UserAvatarDropdown } from "@/components/layout/UserAvatarDropdown";
// import { AppBreadcrumb } from "@/components/layout/AppBreadcrumb";
// import { SidebarNav } from "@/components/layout/SidebarNav";
// import { cn } from "@/lib/utils";
// import { useFirebaseMessaging } from "@/hooks/useFirebaseMessaging";
// import { useFirestoreNotifications } from "@/hooks/useFirestoreNotifications";
// import { NavLink } from "@/components/NavLink";

// export default function DashboardLayout() {
//   const { t, i18n } = useTranslation();
//   const [collapsed, setCollapsed] = useState(false);
//   const [mobileOpen, setMobileOpen] = useState(false);
//   const isRtl = i18n.language === "ar";
//   const { permissionStatus, requestPermissionAndGetToken } =
//     useFirebaseMessaging();
//   const { unreadCount } = useFirestoreNotifications();

//   // ── Permission request ──────────────────────────────────────────────────────
//   useEffect(() => {
//     if (permissionStatus === "default") {
//       requestPermissionAndGetToken();
//     }
//   }, [permissionStatus]);
//   return (
//     <div className="flex h-screen overflow-hidden">
//       {/* Desktop sidebar */}
//       <aside
//         className={cn(
//           "hidden md:flex flex-col border-e border-border bg-card transition-all duration-200",
//           collapsed ? "w-[60px]" : "w-60",
//         )}
//       >
//         <SidebarNav collapsed={collapsed} />
//       </aside>

//       {/* Mobile sidebar via Sheet */}
//       <Sheet open={mobileOpen} onOpenChange={setMobileOpen}>
//         <SheetContent side={isRtl ? "right" : "left"} className="w-60 p-0">
//           <SheetTitle className="sr-only">{t("navigation")}</SheetTitle>
//           <SidebarNav onNavigate={() => setMobileOpen(false)} />
//         </SheetContent>
//       </Sheet>

//       {/* Main area */}
//       <div className="flex flex-1 flex-col overflow-hidden">
//         {/* Top navbar */}
//         <header className="flex h-14 items-center gap-2 border-b border-border px-4">
//           {/* Mobile menu trigger */}
//           <Button
//             variant="ghost"
//             size="icon"
//             className="md:hidden"
//             onClick={() => setMobileOpen(true)}
//           >
//             <Menu className="h-5 w-5" />
//             <span className="sr-only">{t("menu")}</span>
//           </Button>

//           {/* Desktop collapse toggle */}
//           <Button
//             variant="ghost"
//             size="icon"
//             className="hidden md:inline-flex"
//             onClick={() => setCollapsed(!collapsed)}
//           >
//             {collapsed ? (
//               <PanelLeft className="h-4 w-4" />
//             ) : (
//               <PanelLeftClose className="h-4 w-4" />
//             )}
//             <span className="sr-only">
//               {collapsed ? t("openSidebar") : t("closeSidebar")}
//             </span>
//           </Button>

//           <Separator orientation="vertical" className="mx-1 h-6" />

//           <AppBreadcrumb />

//           {/* Spacer */}
//           <div className="flex-1" />
//           <Button variant="ghost" size="icon" className="relative" asChild>
//             <NavLink to="/notifications">
//               <Bell className="h-5 w-5" />
//               {unreadCount > 0 && (
//                 <span className="absolute -top-0.5 -right-0.5 h-4 w-4 rounded-full bg-destructive text-destructive-foreground text-[10px] font-bold flex items-center justify-center">
//                   {unreadCount > 9 ? "9+" : unreadCount}
//                 </span>
//               )}
//             </NavLink>
//           </Button>
//           <LanguageSwitcher />
//           <ThemeToggle />
//           <UserAvatarDropdown />
//         </header>

//         {/* Page content */}
//         <main className="flex-1 overflow-auto p-6">
//           <Outlet />
//         </main>
//       </div>
//     </div>
//   );
// }
