"use client";

import { useEffect, useRef, useCallback } from "react";
// Next.js equivalents for navigation
import { useRouter, usePathname } from "next/navigation";
/* 
  Commenting out react-i18next. 
  If you use next-intl, you'd import { useTranslations } from 'next-intl';
*/
// import { useTranslation } from "react-i18next";
import { useAuthContext } from "@/contexts/AuthContext";
import { useFirebaseMessaging } from "@/hooks/useFirebaseMessaging";
import {
  useFirestoreNotifications,
  type NotificationRecord,
} from "@/hooks/useFirestoreNotifications";
import { Button } from "@/components/ui/button";
import { Skeleton } from "@/components/ui/skeleton";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import {
  Bell,
  BellOff,
  Check,
  CheckCheck,
  Trash2,
  MoreHorizontal,
  Inbox,
  Loader2,
} from "lucide-react";
import toast from "react-hot-toast";

export function NotificationCenter() {
  const { isAuthenticated } = useAuthContext();
  
  // Next.js Navigation hooks
  const router = useRouter();
  const pathname = usePathname();

  // Placeholder for translation logic
  const t = (key: string, fallback: string) => fallback;

  const { permissionStatus, foregroundMessage } = useFirebaseMessaging();

  const {
    notifications,
    unreadCount,
    totalCount,
    loading,
    loadingMore,
    hasMore,
    lang,
    markAsRead,
    markAllAsRead,
    deleteNotification,
    deleteAllNotifications,
    loadMore,
    getLabel,
  } = useFirestoreNotifications({ limitCount: 20 });

  const isRtl = lang === "ar";
  const scrollRef = useRef<HTMLDivElement>(null);
  const isOnNotifPage = pathname === "/notifications";

  // ── Foreground toast ───────────────────────────────────────────────────────
  useEffect(() => {
    if (!foregroundMessage) return;
    if (isOnNotifPage) return;

    toast(foregroundMessage.title)
    // , {
    //   description: foregroundMessage.body,
    //   icon: <Bell className="h-4 w-4 text-primary" />,
    //   action: {
    //     label: t("notifications.view", "View"),
    //     onClick: () => router.push("/notifications"), // navigate -> router.push
    //   },
    //   duration: 6000,
    // });
  }, [foregroundMessage, isOnNotifPage, router]);

  // ── Infinite scroll ─────────────────────────────────────────────────────────
  const handleScroll = useCallback(() => {
    const el = scrollRef.current;
    if (!el) return;
    if (
      el.scrollHeight - el.scrollTop - el.clientHeight < 120 &&
      hasMore &&
      !loadingMore
    ) {
      loadMore();
    }
  }, [hasMore, loadingMore, loadMore]);

  // ── Handlers ────────────────────────────────────────────────────────────────
  const handleClick = async (notif: NotificationRecord) => {
    if (!notif.is_read) await markAsRead(notif.id);
    if (notif.data?.page && typeof notif.data.page === "string") {
      router.push(notif.data.page); // navigate -> router.push
    }
  };

  const formatDate = (ts: any) => {
    if (!ts?.toDate) return "";
    const date = ts.toDate();
    const now = new Date();
    const diffMs = now.getTime() - date.getTime();
    const diffMins = Math.floor(diffMs / 60000);
    const diffHours = Math.floor(diffMins / 60);
    const diffDays = Math.floor(diffHours / 24);

    if (diffMins < 1) return isRtl ? "الآن" : "Just now";
    if (diffMins < 60)
      return isRtl ? `منذ ${diffMins} دقيقة` : `${diffMins}m ago`;
    if (diffHours < 24)
      return isRtl ? `منذ ${diffHours} ساعة` : `${diffHours}h ago`;
    if (diffDays < 7)
      return isRtl ? `منذ ${diffDays} أيام` : `${diffDays}d ago`;

    return date.toLocaleDateString(isRtl ? "ar-EG" : "en-US", {
      day: "numeric",
      month: "short",
      year: date.getFullYear() !== now.getFullYear() ? "numeric" : undefined,
    });
  };

  if (!isAuthenticated) return null;

  return (
    <div
      dir={isRtl ? "rtl" : "ltr"}
      className="flex flex-col h-screen bg-background"
    >
      {/* ── Header ── */}
      <div className="sticky top-0 z-10 bg-background/95 backdrop-blur-sm border-b border-border px-6 py-4">
        <div className="max-w-2xl mx-auto flex items-center justify-between">
          <div className="flex items-center gap-3">
            <div className="relative">
              <Bell className="h-6 w-6 text-foreground" />
              {unreadCount > 0 && (
                <span className="absolute -top-1.5 -right-1.5 h-4 w-4 rounded-full bg-destructive text-destructive-foreground text-[10px] font-bold flex items-center justify-center">
                  {unreadCount > 9 ? "9+" : unreadCount}
                </span>
              )}
            </div>
            <div>
              <h1 className="text-xl font-semibold text-foreground leading-tight">
                {t("notifications.title", "Notifications")}
              </h1>
              {totalCount > 0 && (
                <p className="text-xs text-muted-foreground">
                  {isRtl
                    ? `${totalCount} إشعار${unreadCount > 0 ? ` · ${unreadCount} غير مقروء` : ""}`
                    : `${totalCount} total${unreadCount > 0 ? ` · ${unreadCount} unread` : ""}`}
                </p>
              )}
            </div>
          </div>

          <div className="flex items-center gap-2">
            {permissionStatus === "denied" && (
              <div className="flex items-center gap-1.5 text-xs text-muted-foreground bg-muted rounded-full px-3 py-1.5">
                <BellOff className="h-3.5 w-3.5" />
                <span>{isRtl ? "الإشعارات محظورة" : "Push disabled"}</span>
              </div>
            )}

            {notifications.length > 0 && (
              <DropdownMenu>
                <DropdownMenuTrigger asChild>
                  <Button
                    variant="ghost"
                    size="sm"
                    className="h-9 w-9 p-0 rounded-full"
                  >
                    <MoreHorizontal className="h-4 w-4" />
                  </Button>
                </DropdownMenuTrigger>
                <DropdownMenuContent
                  align={isRtl ? "start" : "end"}
                  className="w-48"
                >
                  {unreadCount > 0 && (
                    <DropdownMenuItem onClick={markAllAsRead}>
                      <CheckCheck
                        className={`h-4 w-4 ${isRtl ? "ml-2" : "mr-2"}`}
                      />
                      {t("notifications.markAllAsRead", "Mark all as read")}
                    </DropdownMenuItem>
                  )}
                  <DropdownMenuSeparator />
                  <DropdownMenuItem
                    onClick={deleteAllNotifications}
                    className="text-destructive focus:text-destructive"
                  >
                    <Trash2 className={`h-4 w-4 ${isRtl ? "ml-2" : "mr-2"}`} />
                    {t("notifications.deleteAll", "Delete all")}
                  </DropdownMenuItem>
                </DropdownMenuContent>
              </DropdownMenu>
            )}
          </div>
        </div>
      </div>

      {/* ── Body ── */}
      <div
        ref={scrollRef}
        onScroll={handleScroll}
        className="flex-1 overflow-y-auto"
      >
        <div className="max-w-2xl mx-auto px-4 py-4 space-y-1">
          {loading && (
            <>
              {Array.from({ length: 6 }).map((_, i) => (
                <div
                  key={i}
                  className="flex gap-3 p-4 rounded-xl"
                  style={{ animationDelay: `${i * 60}ms` }}
                >
                  <Skeleton className="h-10 w-10 rounded-full shrink-0" />
                  <div className="flex-1 space-y-2 pt-1">
                    <Skeleton className="h-4 w-2/3" />
                    <Skeleton className="h-3 w-full" />
                    <Skeleton className="h-3 w-1/3" />
                  </div>
                </div>
              ))}
            </>
          )}

          {!loading && notifications.length === 0 && (
            <div className="flex flex-col items-center justify-center py-24 px-4 text-center">
              <div className="relative mb-6">
                <div className="h-20 w-20 rounded-full bg-muted flex items-center justify-center">
                  <Inbox className="h-9 w-9 text-muted-foreground" />
                </div>
                <div className="absolute -bottom-1 -right-1 h-7 w-7 rounded-full bg-background border-2 border-muted flex items-center justify-center">
                  <Check className="h-3.5 w-3.5 text-muted-foreground" />
                </div>
              </div>
              <p className="text-base font-medium text-foreground">
                {t("notifications.emptyTitle", "You're all caught up")}
              </p>
              <p className="text-sm text-muted-foreground mt-1 max-w-xs">
                {t(
                  "notifications.emptyDesc",
                  "No notifications yet. We'll let you know when something happens.",
                )}
              </p>
            </div>
          )}

          {!loading &&
            notifications.map((notif, index) => {
              const { title, desc } = getLabel(notif);
              return (
                <div
                  key={notif.id}
                  role="button"
                  tabIndex={0}
                  className={`
                    group relative flex gap-4 p-4 rounded-xl cursor-pointer
                    transition-all duration-150
                    hover:bg-muted/70
                    focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring
                    ${!notif.is_read ? "bg-primary/5" : ""}
                  `}
                  style={{ animationDelay: `${index * 30}ms` }}
                  onClick={() => handleClick(notif)}
                  onKeyDown={(e) => {
                    if (e.key === "Enter" || e.key === " ") {
                      e.preventDefault();
                      handleClick(notif);
                    }
                  }}
                >
                  {!notif.is_read && (
                    <div
                      className={`absolute top-1/2 -translate-y-1/2 w-1.5 h-1.5 rounded-full bg-primary ${isRtl ? "right-2" : "left-2"}`}
                    />
                  )}

                  <div
                    className={`
                      shrink-0 h-10 w-10 rounded-full flex items-center justify-center
                      ${notif.is_read ? "bg-muted text-muted-foreground" : "bg-primary/10 text-primary"}
                    `}
                  >
                    <Bell className="h-4.5 w-4.5" />
                  </div>

                  <div className={`flex-1 min-w-0 ${isRtl ? "pr-2" : "pl-1"}`}>
                    <div className="flex items-start justify-between gap-2">
                      <div className="flex-1 min-w-0">
                        <p
                          className={`text-sm leading-snug truncate ${
                            notif.is_read
                              ? "font-normal text-muted-foreground"
                              : "font-semibold text-foreground"
                          }`}
                        >
                          {title}
                        </p>
                        <p className="text-sm text-muted-foreground line-clamp-2 mt-0.5 leading-relaxed">
                          {desc}
                        </p>
                        <time className="text-xs text-muted-foreground/70 mt-1.5 block">
                          {formatDate(notif.created_at)}
                        </time>
                      </div>

                      <DropdownMenu>
                        <DropdownMenuTrigger asChild>
                          <Button
                            variant="ghost"
                            size="sm"
                            className="opacity-0 group-hover:opacity-100 focus:opacity-100 h-8 w-8 p-0 shrink-0 rounded-full transition-opacity"
                            onClick={(e) => e.stopPropagation()}
                          >
                            <MoreHorizontal className="h-4 w-4" />
                          </Button>
                        </DropdownMenuTrigger>
                        <DropdownMenuContent
                          align={isRtl ? "start" : "end"}
                          className="w-44"
                        >
                          {!notif.is_read && (
                            <DropdownMenuItem
                              onClick={(e) => {
                                e.stopPropagation();
                                markAsRead(notif.id);
                              }}
                            >
                              <Check
                                className={`h-4 w-4 ${isRtl ? "ml-2" : "mr-2"}`}
                              />
                              {t("notifications.markAsRead", "Mark as read")}
                            </DropdownMenuItem>
                          )}
                          <DropdownMenuItem
                            onClick={(e) => {
                              e.stopPropagation();
                              deleteNotification(notif.id);
                            }}
                            className="text-destructive focus:text-destructive"
                          >
                            <Trash2
                              className={`h-4 w-4 ${isRtl ? "ml-2" : "mr-2"}`}
                            />
                            {t("notifications.delete", "Delete")}
                          </DropdownMenuItem>
                        </DropdownMenuContent>
                      </DropdownMenu>
                    </div>
                  </div>
                </div>
              );
            })}

          {loadingMore && (
            <div className="flex items-center justify-center py-6 gap-2 text-muted-foreground">
              <Loader2 className="h-4 w-4 animate-spin" />
              <span className="text-sm">
                {t("notifications.loadingMore", "Loading more…")}
              </span>
            </div>
          )}

          {!loading && !hasMore && notifications.length > 0 && (
            <div className="py-8 text-center">
              <p className="text-xs text-muted-foreground/60">
                {t("notifications.allLoaded", "You've seen all notifications")}
              </p>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}