"use client";

import React, { useEffect, useState, useCallback } from "react";
import axiosInstance from "@/lib/axios";
import { AxiosError } from "axios";
import { format } from "date-fns";
// import { useTranslation } from "react-i18next";
import {
  Star,
  MessageSquare,
  ThumbsUp,
  ThumbsDown,
  CalendarDays,
  AlertTriangle,
  RefreshCw,
  User,
  ChevronDown,
  ChevronUp,
} from "lucide-react";
import { Input } from "@/components/ui/input";
import { Button } from "@/components/ui/button";
import { Skeleton } from "@/components/ui/skeleton";
import { Card, CardContent } from "@/components/ui/card";
import { Collapsible, CollapsibleTrigger, CollapsibleContent } from "@/components/ui/collapsible";
import { cn } from "@/lib/utils";

interface ReviewRatingStats {
  count: number;
  avgRating: number;
  fiveStarCount?: number;
  fourStarCount?: number;
  threeStarOrBelow?: number;
}

interface ReviewStatsData {
  received: ReviewRatingStats;
  given: ReviewRatingStats;
}

interface ReviewDetail {
  id: number;
  orderId: number;
  customerId: number;
  rating: number;
  comment: string | null;
  createdAt: string;
}

export function ReviewStatisticsSection({ courierId }: { courierId: number }) {
  // const { t } = useTranslation();
  const t = (key: string, fallback: string, options?: any) => {
    if (options && key === "givenStatsMsg") {
        return fallback.replace("{{count}}", options.count).replace("{{rating}}", options.rating);
    }
    return fallback;
  };

  const [isOpen, setIsOpen] = useState(false);
  const [fromDate, setFromDate] = useState("");
  const [toDate, setToDate] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const [stats, setStats] = useState<ReviewStatsData | null>(null);
  const [receivedReviews, setReceivedReviews] = useState<ReviewDetail[]>([]);
  const [givenReviews, setGivenReviews] = useState<ReviewDetail[]>([]);

  const fetchStats = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const response = await axiosInstance.get(
        `/admin/courier-stat/courier-stat/${courierId}`,
        {
          params: { 
            ...(fromDate && { fromDate }), 
            ...(toDate && { toDate }) 
          },
        }
      );
      
      const data = response.data?.data;
      if (data) {
        setStats(data.reviews || null);
        setReceivedReviews(data.details?.receivedReviews || []);
        setGivenReviews(data.details?.givenReviews || []);
      }
    } catch (err) {
      const axiosErr = err as AxiosError<{ message: string }>;
      setError(
        axiosErr.response?.data?.message || t("failedToFetch", "Failed to fetch statistics.")
      );
    } finally {
      setLoading(false);
    }
  }, [courierId, fromDate, toDate]);

  useEffect(() => {
    if (isOpen && !stats && !loading) {
      fetchStats();
    }
  }, [isOpen, fetchStats, stats, loading]);

  return (
    <Collapsible
      open={isOpen}
      onOpenChange={setIsOpen}
      className="bg-card border rounded-xl overflow-hidden shadow-sm"
    >
      <div className="flex flex-col sm:flex-row items-center justify-between gap-4 bg-muted/30 p-4 border-b">
        <CollapsibleTrigger asChild>
          <button className="flex items-center gap-3 text-foreground font-semibold hover:opacity-80 transition-opacity">
            <div className="p-2 bg-yellow-500/10 rounded-lg text-yellow-600">
              <Star className={cn("h-5 w-5", isOpen && "fill-current")} />
            </div>
            <h2 className="text-lg">{t("reviewsStatistics", "Reviews Statistics")}</h2>
            {isOpen ? <ChevronUp className="h-4 w-4" /> : <ChevronDown className="h-4 w-4" />}
          </button>
        </CollapsibleTrigger>
        
        {isOpen && (
          <div className="flex items-center gap-2 w-full sm:w-auto">
            <CalendarDays className="h-4 w-4 text-muted-foreground hidden sm:block" />
            <Input
              type="date"
              value={fromDate}
              onChange={(e) => setFromDate(e.target.value)}
              className="h-9 w-full sm:w-[150px] text-xs"
            />
            <Input
              type="date"
              value={toDate}
              onChange={(e) => setToDate(e.target.value)}
              className="h-9 w-full sm:w-[150px] text-xs"
            />
            <Button onClick={fetchStats} disabled={loading} size="sm" className="h-9 px-4">
              {loading ? <RefreshCw className="h-4 w-4 animate-spin" /> : t("apply", "Apply")}
            </Button>
          </div>
        )}
      </div>

      <CollapsibleContent className="p-6 space-y-6">
        {error ? (
          <div className="bg-destructive/10 text-destructive p-4 rounded-lg flex items-center justify-between border border-destructive/20">
            <div className="flex items-center gap-2 text-sm font-medium">
              <AlertTriangle className="h-4 w-4" />
              {error}
            </div>
            <Button variant="outline" size="sm" onClick={fetchStats}>
              {t("retry", "Retry")}
            </Button>
          </div>
        ) : loading && !stats ? (
          <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
            {[...Array(4)].map((_, i) => (
              <Skeleton key={i} className="h-24 rounded-xl" />
            ))}
          </div>
        ) : stats ? (
          <div className="space-y-6 animate-in fade-in slide-in-from-top-2 duration-300">
            <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
              <StatCard
                title={t("receivedReviewsCount", "Received")}
                value={stats.received.count}
                icon={<MessageSquare className="h-5 w-5" />}
                colorClass="bg-blue-500/10 text-blue-600 dark:text-blue-400"
              />
              <StatCard
                title={t("receivedAvgRating", "Avg Rating")}
                value={stats.received.avgRating.toFixed(1)}
                icon={<Star className="h-5 w-5 fill-yellow-500 text-yellow-500" />}
                colorClass="bg-yellow-500/10 text-yellow-600 dark:text-yellow-400"
              />
              <StatCard
                title={t("fiveStarReceived", "5 Stars")}
                value={stats.received.fiveStarCount || 0}
                icon={<ThumbsUp className="h-5 w-5" />}
                colorClass="bg-emerald-500/10 text-emerald-600 dark:text-emerald-400"
              />
              <StatCard
                title={t("threeStarOrBelow", "Low Ratings")}
                value={stats.received.threeStarOrBelow || 0}
                icon={<ThumbsDown className="h-5 w-5" />}
                colorClass="bg-rose-500/10 text-rose-600 dark:text-rose-400"
              />
            </div>

            <div className="flex items-center gap-3 bg-muted/30 border p-4 rounded-xl text-sm font-medium">
              <User className="h-4 w-4 text-muted-foreground" />
              <span>
                {t("givenStatsMsg", "The courier has given {{count}} reviews with an average rating of {{rating}}.", {
                  count: stats.given.count,
                  rating: stats.given.avgRating.toFixed(1)
                })}
              </span>
            </div>

            <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
              <ReviewList 
                title={t("recentReceivedReviews", "Received Reviews")} 
                reviews={receivedReviews} 
                accentColor="yellow"
              />
              <ReviewList 
                title={t("recentGivenReviews", "Given Reviews")} 
                reviews={givenReviews} 
                accentColor="blue"
              />
            </div>
          </div>
        ) : (
          <div className="text-center py-10 text-muted-foreground">
            {t("noStatsAvailable", "No review data available for this period.")}
          </div>
        )}
      </CollapsibleContent>
    </Collapsible>
  );
}

function ReviewList({ title, reviews, accentColor }: { title: string; reviews: ReviewDetail[]; accentColor: 'yellow' | 'blue' }) {
  const accentClasses = accentColor === 'yellow' 
    ? "bg-yellow-500/10 text-yellow-600" 
    : "bg-blue-500/10 text-blue-600";

  return (
    <div className="bg-card border rounded-xl overflow-hidden">
      <div className="px-5 py-3 border-b bg-muted/20 flex justify-between items-center">
        <h3 className="font-semibold text-sm">{title}</h3>
        <span className={cn("text-[10px] px-2 py-0.5 rounded-full font-bold", accentClasses)}>
          {reviews.length}
        </span>
      </div>
      <div className="divide-y max-h-[350px] overflow-y-auto">
        {reviews.length > 0 ? (
          reviews.map((review) => <ReviewListItem key={review.id} review={review} />)
        ) : (
          <div className="p-8 text-center text-xs text-muted-foreground italic">
            No reviews found.
          </div>
        )}
      </div>
    </div>
  );
}

function StatCard({ title, value, icon, colorClass }: { title: string; value: React.ReactNode; icon: React.ReactNode; colorClass: string }) {
  return (
    <Card className="border-none shadow-none bg-muted/20">
      <CardContent className="p-4 flex items-center justify-between">
        <div className="space-y-1">
          <p className="text-[10px] font-bold text-muted-foreground uppercase tracking-tight">{title}</p>
          <p className="text-2xl font-bold tracking-tighter">{value}</p>
        </div>
        <div className={cn("p-3 rounded-xl", colorClass)}>{icon}</div>
      </CardContent>
    </Card>
  );
}

function ReviewListItem({ review }: { review: ReviewDetail }) {
  return (
    <div className="p-4 space-y-2 hover:bg-muted/10 transition-colors">
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-2">
          <div className="flex items-center gap-1 bg-yellow-50 text-yellow-700 border border-yellow-100 px-1.5 py-0.5 rounded text-[11px] font-bold">
            <Star className="h-2.5 w-2.5 fill-current" />
            {review.rating}
          </div>
          <span className="text-[10px] text-muted-foreground font-medium">#{review.orderId}</span>
        </div>
        <span className="text-[10px] text-muted-foreground">
          {format(new Date(review.createdAt), "MMM d, yyyy")}
        </span>
      </div>
      {review.comment && (
        <p className="text-xs text-foreground leading-relaxed pl-2 border-l-2 border-muted italic">
          {review.comment}
        </p>
      )}
    </div>
  );
}