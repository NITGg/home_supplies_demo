"use client";

import React, { useEffect, useState } from "react";
import axiosInstance from "@/lib/axios";
import { AxiosError } from "axios";
import { format } from "date-fns";
import { useRouter } from "next/navigation";
// import { useTranslation } from "react-i18next";
import {
  Package,
  CheckCircle,
  XCircle,
  Banknote,
  Navigation,
  Clock,
  PieChart,
  CalendarDays,
  AlertTriangle,
  RefreshCw,
  ChevronDown,
  ChevronUp,
} from "lucide-react";
import { Input } from "@/components/ui/input";
import { Button } from "@/components/ui/button";
import { Skeleton } from "@/components/ui/skeleton";
import { Card, CardContent } from "@/components/ui/card";
import { Collapsible, CollapsibleTrigger, CollapsibleContent } from "@/components/ui/collapsible";

interface OrderStatsData {
  total: number;
  completed: number;
  cancelled: number;
  expired: number;
  searchFailed: number;
  active: number;
  pending: number;
  completionRate: number;
  cancellationRate: number;
  totalCourierFee: number;
  totalActualPrice: number;
  avgOrderValue: number;
  avgDeliveryTime: number;
  proposals: { total: number; accepted: number; acceptanceRate: number };
  issues: { total: number; open: number; resolved: number; dismissed: number };
  unpaidCommissions: { count: number; totalAmount: number };
  penalties: {
    total: number;
    paid: number;
    waived: number;
    unpaid: number;
    totalAmount: number;
    paidAmount: number;
    waivedAmount: number;
    unpaidAmount: number;
  };
}

interface OrderDetail {
  id: number;
  orderNumber: string;
  status: string;
  courierFee: number;
  actualPrice: number;
  createdAt: string;
  deliveredAt: string | null;
}

export function OrderStatisticsSection({ courierId }: { courierId: number }) {
  // const { t } = useTranslation();
  const router = useRouter();

  // Temporary translation mock
  const t = (key: string, fallback: string) => fallback;

  const [isOpen, setIsOpen] = useState(false);
  const [fromDate, setFromDate] = useState("");
  const [toDate, setToDate] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const [stats, setStats] = useState<OrderStatsData | null>(null);
  const [details, setDetails] = useState<OrderDetail[]>([]);

  const fetchStats = async () => {
    setLoading(true);
    setError(null);
    try {
      const response = await axiosInstance.get(
        `/admin/courier-stat/courier-stat/${courierId}`,
        {
          params: { ...(fromDate && { fromDate }), ...(toDate && { toDate }) },
        }
      );
      if (response.data?.data) {
        setStats(response.data.data.orders || null);
        setDetails(response.data.data.details?.orders || []);
      }
    } catch (err) {
      const axiosErr = err as AxiosError<{ message: string }>;
      setError(
        axiosErr.response?.data?.message || t("failedToFetch", "Failed to fetch statistics.")
      );
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    if (isOpen && !stats && !loading && !error) {
      fetchStats();
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [isOpen, courierId]);

  if (error && isOpen) {
    return (
      <div className="bg-destructive/10 text-destructive p-4 rounded-lg flex items-center justify-between border border-destructive/20">
        <div className="flex items-center gap-2">
          <AlertTriangle className="h-5 w-5" />
          <p className="font-medium text-sm">{error}</p>
        </div>
        <Button variant="outline" size="sm" onClick={fetchStats}>
          <RefreshCw className="mr-2 h-4 w-4" />
          {t("retry", "Retry")}
        </Button>
      </div>
    );
  }

  return (
    <Collapsible
      open={isOpen}
      onOpenChange={setIsOpen}
      className="space-y-6 bg-card border rounded-xl overflow-hidden shadow-sm"
    >
      {/* Filters Header */}
      <div className="flex flex-col sm:flex-row items-center justify-between gap-4 bg-muted/40 p-4 border-b">
        <CollapsibleTrigger asChild>
          <Button variant="ghost" className="flex items-center gap-2 text-foreground font-semibold p-0 hover:bg-transparent px-2">
            <div className="p-2 bg-primary/10 rounded-lg text-primary">
              <Package className="h-5 w-5" />
            </div>
            <h2 className="text-xl">{t("orderStatistics", "Order Statistics")}</h2>
            {isOpen ? <ChevronUp className="h-5 w-5 ml-2" /> : <ChevronDown className="h-5 w-5 ml-2" />}
          </Button>
        </CollapsibleTrigger>
        
        {isOpen && (
          <div className="flex items-center gap-2 w-full sm:w-auto">
          <CalendarDays className="h-4 w-4 text-muted-foreground mr-1" />
          <Input
            type="date"
            value={fromDate}
            onChange={(e) => setFromDate(e.target.value)}
            className="w-full sm:w-[140px] text-sm"
          />
          <span className="text-muted-foreground text-sm">-</span>
          <Input
            type="date"
            value={toDate}
            onChange={(e) => setToDate(e.target.value)}
            className="w-full sm:w-[140px] text-sm"
          />
          <Button onClick={fetchStats} disabled={loading} size="default" className="shadow-sm">
            {loading ? <RefreshCw className="h-4 w-4 animate-spin" /> : t("apply", "Apply")}
          </Button>
        </div>
        )}
      </div>

      <CollapsibleContent className="p-6 pt-2 space-y-6">
      {loading && !stats ? (
        <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-4 gap-4">
          {[...Array(8)].map((_, i) => (
            <Skeleton key={i} className="h-[100px] rounded-xl" />
          ))}
        </div>
      ) : stats ? (
        <div className="space-y-6">
          {/* Main Stat Grid */}
          <div className="grid grid-cols-2 sm:grid-cols-2 lg:grid-cols-4 gap-4">
            <StatCard
              title={t("totalOrders", "Total Orders")}
              value={stats.total}
              icon={<Package className="h-5 w-5" />}
              colorClass="bg-blue-500/10 text-blue-600 dark:text-blue-400"
            />
            <StatCard
              title={t("completed", "Completed")}
              value={stats.completed}
              icon={<CheckCircle className="h-5 w-5" />}
              colorClass="bg-emerald-500/10 text-emerald-600 dark:text-emerald-400"
            />
            <StatCard
              title={t("cancelled", "Cancelled")}
              value={stats.cancelled}
              icon={<XCircle className="h-5 w-5" />}
              colorClass="bg-rose-500/10 text-rose-600 dark:text-rose-400"
            />
            <StatCard
              title={t("completionRate", "Completion Rate (%)")}
              value={`${stats.completionRate}%`}
              icon={<PieChart className="h-5 w-5" />}
              colorClass="bg-violet-500/10 text-violet-600 dark:text-violet-400"
            />
            <StatCard
              title={t("totalCourierFee", "Total Courier Fee")}
              value={`${(stats.totalCourierFee / 100).toFixed(2)} EGP`}
              icon={<Banknote className="h-5 w-5" />}
              colorClass="bg-amber-500/10 text-amber-600 dark:text-amber-400"
            />
            <StatCard
              title={t("avgDeliveryTime", "Avg Delivery (Mins)")}
              value={stats.avgDeliveryTime}
              icon={<Clock className="h-5 w-5" />}
              colorClass="bg-cyan-500/10 text-cyan-600 dark:text-cyan-400"
            />
            <StatCard
              title={t("proposalsAccepted", "Proposals Accepted")}
              value={`${stats.proposals.accepted} / ${stats.proposals.total}`}
              icon={<Navigation className="h-5 w-5" />}
              colorClass="bg-indigo-500/10 text-indigo-600 dark:text-indigo-400"
            />
            <StatCard
              title={t("penaltiesUnpaid", "Unpaid Penalties")}
              value={stats.penalties.unpaid}
              icon={<AlertTriangle className="h-5 w-5" />}
              colorClass="bg-red-500/10 text-red-600 dark:text-red-400"
            />
          </div>

          {/* Detailed Lists */}
          {details.length > 0 && (
            <div className="bg-card border rounded-xl overflow-hidden shadow-sm">
              <div className="px-5 py-4 border-b bg-muted/20 flex justify-between items-center">
                <h3 className="font-semibold text-lg">{t("recentOrders", "Recent Orders")}</h3>
                <span className="text-xs bg-primary/10 text-primary px-2 py-1 rounded-full font-medium">
                  {details.length} {t("entries", "Entries")}
                </span>
              </div>
              <div className="divide-y">
                {details.map((order) => (
                  <div
                    key={order.id}
                    className="p-4 flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4 hover:bg-muted/30 transition-colors"
                  >
                    <div className="flex flex-col gap-1">
                      <span className="font-semibold text-base flex items-center gap-2">
                        {order.orderNumber}
                        <span className={`text-[10px] px-2 py-0.5 rounded-full uppercase font-bold tracking-wider ${
                          order.status === 'DELIVERED' ? 'bg-emerald-100 text-emerald-700' :
                          order.status === 'CANCELLED' ? 'bg-rose-100 text-rose-700' :
                          'bg-primary/10 text-primary'
                        }`}>
                          {order.status}
                        </span>
                      </span>
                      <span className="text-sm text-muted-foreground">
                        {format(new Date(order.createdAt), "PPP p")}
                      </span>
                    </div>
                    <div className="flex items-center gap-6">
                      <div className="flex flex-col text-right">
                        <span className="text-sm font-semibold">{t("fee", "Fee")}: {(order.courierFee / 100).toFixed(2)} EGP</span>
                        <span className="text-xs text-muted-foreground">{t("actual", "Actual")}: {(order.actualPrice / 100).toFixed(2)} EGP</span>
                      </div>
                      <Button
                        variant="secondary"
                        size="sm"
                        onClick={() => router.push(`/orders/${order.id}`)}
                        className="shadow-sm"
                      >
                        {t("viewDetails", "View Details")}
                      </Button>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          )}
        </div>
      ) : null}
      </CollapsibleContent>
    </Collapsible>
  );
}

function StatCard({ title, value, icon, colorClass }: { title: string; value: React.ReactNode; icon: React.ReactNode; colorClass: string }) {
  return (
    <Card className="overflow-hidden border-none shadow-sm bg-muted/30 hover:bg-muted/50 transition-colors">
      <CardContent className="p-5 flex items-center gap-4">
        <div className={`p-3 rounded-2xl ${colorClass}`}>
          {icon}
        </div>
        <div className="flex flex-col">
          <span className="text-sm font-medium text-muted-foreground">
            {title}
          </span>
          <span className="text-2xl font-bold">
            {value}
          </span>
        </div>
      </CardContent>
    </Card>
  );
}