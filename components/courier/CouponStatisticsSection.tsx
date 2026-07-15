"use client";

import React, { useEffect, useState } from "react";
import axiosInstance from "@/lib/axios";
import { AxiosError } from "axios";
import { format } from "date-fns";
// Next.js Navigation
import { useRouter } from "next/navigation";
/* 
  Commenting out react-i18next. 
  Replace with your Next.js i18n solution (e.g., next-intl) when ready.
*/
// import { useTranslation } from "react-i18next";
import {
  Ticket,
  TrendingUp,
  Banknote,
  Gift,
  Clock,
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

interface CouponStatsData {
  used: number;
  totalSpent: number;
  totalBonusEarned: number;
  roiRatio: number;
  avgDurationDays: number;
  activeCoupon: unknown | null;
  points: {
    balance: number;
    completedOrdersCount: number;
    fourStarRatingsCount: number;
    fiveStarRatingsCount: number;
  };
}

interface CouponDetail {
  usageId: number;
  couponId: number;
  title: string;
  spent: number;
  bonusEarned: number;
  startDate: string;
  endDate: string | null;
  isActive: boolean;
}

export function CouponStatisticsSection({ courierId }: { courierId: number }) {
  // const { t } = useTranslation();
  const router = useRouter();
  
  // Temporary translation helper
  const t = (key: string, fallback: string) => fallback;

  const [isOpen, setIsOpen] = useState(false);
  const [fromDate, setFromDate] = useState("");
  const [toDate, setToDate] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const [stats, setStats] = useState<CouponStatsData | null>(null);
  const [details, setDetails] = useState<CouponDetail[]>([]);

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
        setStats(response.data.data.coupons || null);
        setDetails(response.data.data.details?.coupons || []);
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
      <div className="flex flex-col sm:flex-row items-center justify-between gap-4 bg-muted/40 p-4 border-b">
        <CollapsibleTrigger asChild>
          <Button variant="ghost" className="flex items-center gap-2 text-foreground font-semibold p-0 hover:bg-transparent px-2">
            <div className="p-2 bg-pink-500/10 rounded-lg text-pink-600">
              <Ticket className="h-5 w-5" />
            </div>
            <h2 className="text-xl">{t("couponsStatistics", "Coupons Statistics")}</h2>
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
        <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-5 gap-4">
          {[...Array(5)].map((_, i) => (
            <Skeleton key={i} className="h-[100px] rounded-xl" />
          ))}
        </div>
      ) : stats ? (
        <div className="space-y-6">
          <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-5 gap-4">
            <StatCard
              title={t("couponsUsed", "Coupons Used")}
              value={stats.used}
              icon={<Ticket className="h-5 w-5" />}
              colorClass="bg-pink-500/10 text-pink-600 dark:text-pink-400"
            />
            <StatCard
              title={t("totalSpent", "Total Spent")}
              value={`${(stats.totalSpent / 100).toFixed(2)} EGP`}
              icon={<Banknote className="h-5 w-5" />}
              colorClass="bg-emerald-500/10 text-emerald-600 dark:text-emerald-400"
            />
            <StatCard
              title={t("totalBonus", "Total Bonus")}
              value={`${(stats.totalBonusEarned / 100).toFixed(2)} EGP`}
              icon={<Gift className="h-5 w-5" />}
              colorClass="bg-violet-500/10 text-violet-600 dark:text-violet-400"
            />
            <StatCard
              title={t("roiRatio", "ROI Ratio")}
              value={stats.roiRatio.toFixed(2)}
              icon={<TrendingUp className="h-5 w-5" />}
              colorClass="bg-blue-500/10 text-blue-600 dark:text-blue-400"
            />
            <StatCard
              title={t("avgDuration", "Avg Duration (Days)")}
              value={stats.avgDurationDays}
              icon={<Clock className="h-5 w-5" />}
              colorClass="bg-amber-500/10 text-amber-600 dark:text-amber-400"
            />
          </div>

          {details.length > 0 && (
            <div className="bg-card border rounded-xl overflow-hidden shadow-sm">
              <div className="px-5 py-4 border-b bg-muted/20 flex justify-between items-center">
                <h3 className="font-semibold text-lg">{t("recentCoupons", "Recent Coupons")}</h3>
                <span className="text-xs bg-pink-500/10 text-pink-600 px-2 py-1 rounded-full font-medium">
                  {details.length} {t("entries", "Entries")}
                </span>
              </div>
              <div className="divide-y">
                {details.map((coupon) => (
                  <div
                    key={coupon.usageId}
                    className="p-4 flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4 hover:bg-muted/30 transition-colors"
                  >
                    <div className="flex flex-col gap-1">
                      <span className="font-semibold text-base flex items-center gap-2">
                        {coupon.title}
                        {coupon.isActive ? (
                          <span className="text-[10px] bg-emerald-100 text-emerald-700 px-2 py-0.5 rounded-full uppercase font-bold tracking-wider">
                            {t("active", "Active")}
                          </span>
                        ) : (
                          <span className="text-[10px] bg-muted text-muted-foreground px-2 py-0.5 rounded-full uppercase font-bold tracking-wider">
                            {t("expired", "Expired")}
                          </span>
                        )}
                      </span>
                      <span className="text-sm text-muted-foreground">
                        {format(new Date(coupon.startDate), "PP")} - {coupon.endDate ? format(new Date(coupon.endDate), "PP") : t("present", "Present")}
                      </span>
                    </div>
                    <div className="flex items-center gap-6">
                      <div className="flex flex-col text-right">
                        <span className="text-sm font-semibold">{t("spent", "Spent")}: {(coupon.spent / 100).toFixed(2)} EGP</span>
                        <span className="text-xs text-muted-foreground text-emerald-600">{t("bonus", "Bonus")}: +{(coupon.bonusEarned / 100).toFixed(2)} EGP</span>
                      </div>
                      <Button
                        variant="secondary"
                        size="sm"
                        onClick={() => router.push(`/coupons/courier/${coupon.couponId}`)}
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
      <CardContent className="p-5 flex flex-col items-center justify-center text-center gap-3">
        <div className={`p-3 rounded-full ${colorClass}`}>
          {icon}
        </div>
        <div className="flex flex-col">
          <span className="text-2xl font-bold mb-1">
            {value}
          </span>
          <span className="text-xs font-medium text-muted-foreground uppercase tracking-wider">
            {title}
          </span>
        </div>
      </CardContent>
    </Card>
  );
}