"use client";
import { useQuery } from "@tanstack/react-query";
import { supplierApi } from "@/lib/api";
import { useT } from "@/contexts/LanguageContext";
import { Bell, RefreshCw, Loader2 } from "lucide-react";
import { cn } from "@/lib/utils";

export default function SupplierNotificationsPage() {
  const { t, isRTL } = useT();

  const { data, isLoading, refetch, isFetching } = useQuery({
    queryKey: ["supplier-notification-settings"],
    queryFn: async () => {
      const res = await supplierApi.get("/notification/get-settings");
      return res.data?.data ?? res.data;
    },
    staleTime: 5 * 60 * 1000,
  });

  // Determine if it's a settings object or a notification list
  const isList = Array.isArray(data);
  const notifications: any[] = isList ? data : [];
  const settings: Record<string, any> = !isList && data ? data : {};

  return (
    <div className="p-6 space-y-5" dir={isRTL ? "rtl" : "ltr"}>
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-3">
          <Bell size={20} className="text-indigo-600" />
          <h1 className="text-xl font-bold text-gray-900">{t("sp.notifications.title")}</h1>
        </div>
        <button onClick={() => refetch()} disabled={isFetching}
          className="p-2 border border-gray-200 rounded-lg text-gray-500 hover:bg-gray-50 disabled:opacity-50">
          <RefreshCw size={14} className={isFetching ? "animate-spin" : ""} />
        </button>
      </div>

      {isLoading ? (
        <div className="flex items-center justify-center min-h-[200px]">
          <Loader2 className="animate-spin text-indigo-400" size={28} />
        </div>
      ) : isList && notifications.length > 0 ? (
        /* Notification list */
        <div className="space-y-2">
          {notifications.map((n: any) => (
            <div key={n.id} className={cn(
              "bg-white rounded-xl border p-4 flex items-start gap-3",
              n.is_read ? "border-gray-200" : "border-indigo-200 bg-indigo-50/30",
            )}>
              <div className={cn("w-2 h-2 rounded-full mt-2 shrink-0",
                n.is_read ? "bg-gray-300" : "bg-indigo-600")} />
              <div className="flex-1">
                <p className="text-sm font-medium text-gray-900">{n.title}</p>
                {n.body && <p className="text-xs text-gray-500 mt-0.5">{n.body}</p>}
              </div>
              <p className="text-xs text-gray-400 shrink-0">
                {n.created_at ? new Date(n.created_at).toLocaleDateString() : "—"}
              </p>
            </div>
          ))}
        </div>
      ) : Object.keys(settings).length > 0 ? (
        /* Settings object */
        <div className="bg-white rounded-xl border border-gray-200 overflow-hidden">
          <div className="px-5 py-4 border-b border-gray-100">
            <h2 className="text-sm font-semibold text-gray-900">{t("sp.notifications.preferences")}</h2>
            <p className="text-xs text-gray-500 mt-0.5">{t("sp.notifications.preferencesDesc")}</p>
          </div>
          <div className="divide-y divide-gray-100">
            {Object.entries(settings).map(([key, value]) => (
              <div key={key} className="px-5 py-3.5 flex items-center justify-between">
                <p className="text-sm text-gray-700 capitalize">{key.replace(/_/g, " ")}</p>
                {typeof value === "boolean" ? (
                  <span className={cn("text-xs px-2 py-0.5 rounded-full font-medium",
                    value ? "bg-green-100 text-green-700" : "bg-gray-100 text-gray-500")}>
                    {value ? t("sp.notifications.enabled") : t("sp.notifications.disabled")}
                  </span>
                ) : (
                  <span className="text-xs text-gray-500">{String(value ?? "—")}</span>
                )}
              </div>
            ))}
          </div>
        </div>
      ) : (
        <div className="bg-white rounded-xl border border-gray-200 p-16 text-center">
          <Bell size={40} className="mx-auto mb-3 text-gray-200" />
          <p className="text-sm text-gray-400">{t("sp.notifications.empty")}</p>
        </div>
      )}
    </div>
  );
}
