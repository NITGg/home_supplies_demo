"use client";
import { useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { supplierApi } from "@/lib/api";
import { useT } from "@/contexts/LanguageContext";
import { Star, RefreshCw, User, Truck, X, MessageSquare, Eye } from "lucide-react";
import Link from "next/link";
import { cn } from "@/lib/utils";
import { TablePagination } from "@/components/ui/TablePagination";
import { DateRangeFilter } from "@/components/ui/DateRangeFilter";

interface Reviewer {
  id?: number;
  full_name?: string;
  phone?: string;
  personal_photo?: string | null;
}
interface SupplierReview {
  id: number;
  rating?: number;
  comment?: string | null;
  created_at?: string;
  customer?: Reviewer | null;
  courier?: Reviewer | null;
  user?: Reviewer | null;
  courier_id?: number | null;
  customer_id?: number | null;
  order_id?: number | null;
}
interface Pagination {
  total: number;
  page: number;
  limit: number;
  total_pages: number;
  has_next: boolean;
  has_prev: boolean;
}

type Tab = "customer" | "courier";
const LIMIT = 20;

function Stars({ rating }: { rating: number }) {
  return (
    <div className="flex items-center gap-0.5">
      {Array.from({ length: 5 }).map((_, i) => (
        <Star
          key={i}
          size={13}
          className={i < rating ? "fill-yellow-400 text-yellow-400" : "text-gray-200"}
        />
      ))}
    </div>
  );
}

/** Rating range filter (1–5), styled to sit alongside <DateRangeFilter>. */
function RatingRangeFilter({
  from,
  to,
  onFromChange,
  onToChange,
  label,
}: {
  from: string;
  to: string;
  onFromChange: (v: string) => void;
  onToChange: (v: string) => void;
  label: string;
}) {
  const hasValue = from || to;
  const selectClass =
    "border border-gray-200 rounded-lg px-3 py-2 text-sm outline-none focus:ring-2 focus:ring-indigo-500 text-gray-700 bg-white w-full";
  return (
    <div className="space-y-2">
      <div className="flex items-center gap-1 text-xs text-gray-500 whitespace-nowrap">
        <Star size={13} className="text-gray-400" />
        {label}
      </div>
      <div className="grid grid-cols-2 gap-3">
        <div>
          <label className="block text-xs text-gray-600 mb-1">From</label>
          <select value={from} onChange={(e) => onFromChange(e.target.value)} className={selectClass}>
            <option value="">Any</option>
            {[1, 2, 3, 4, 5].map((n) => (
              <option key={n} value={n}>{`${n} ★`}</option>
            ))}
          </select>
        </div>
        <div>
          <label className="block text-xs text-gray-600 mb-1">To</label>
          <select value={to} onChange={(e) => onToChange(e.target.value)} className={selectClass}>
            <option value="">Any</option>
            {[1, 2, 3, 4, 5].map((n) => (
              <option key={n} value={n}>{`${n} ★`}</option>
            ))}
          </select>
        </div>
      </div>
      {hasValue && (
        <div className="flex justify-center">
          <button
            type="button"
            onClick={() => {
              onFromChange("");
              onToChange("");
            }}
            className="p-1.5 rounded-lg text-gray-400 hover:text-red-500 hover:bg-red-50 transition"
            title="Clear rating"
          >
            <X size={14} />
          </button>
        </div>
      )}
    </div>
  );
}

function ReviewCard({
  review,
  source,
  roleLabel,
}: {
  review: SupplierReview;
  source: Tab;
  roleLabel: string;
}) {
  // Reviewer identity (name / photo) is intentionally hidden — show a neutral
  // role label + icon so customers and couriers are anonymized consistently.
  const isCustomer = source === "customer";
  const Icon = isCustomer ? User : Truck;

  return (
    <div className="bg-white rounded-xl border border-gray-200 p-4">
      <div className="flex items-start justify-between gap-3">
        <div className="flex items-center gap-3">
          <div
            className={cn(
              "w-9 h-9 rounded-full flex items-center justify-center shrink-0",
              isCustomer ? "bg-indigo-100 text-indigo-600" : "bg-purple-100 text-purple-600",
            )}
          >
            <Icon size={15} />
          </div>
          <div>
            <p className="text-sm font-medium text-gray-900">{roleLabel}</p>
            <Stars rating={review.rating ?? 0} />
          </div>
        </div>
        <p className="text-xs text-gray-400 shrink-0">
          {review.created_at ? new Date(review.created_at).toLocaleDateString() : "—"}
        </p>
      </div>
      {review.comment && (
        <div className="mt-2 text-sm text-gray-600 leading-relaxed">
          {review.comment}
        </div>
      )}
      {(() => {
        const orderId = review.order_id || (review as any).orderId || (review as any).order?.id;
        if (orderId) {
          return (
            <div className="mt-2">
              <button
                type="button"
                onClick={(e) => { 
                  e.preventDefault(); 
                  e.stopPropagation(); 
                  window.location.href = `/orders?id=${orderId}`; 
                }}
                className="inline-flex items-center gap-1.5 px-3 py-1.5 text-xs font-medium text-indigo-600 bg-indigo-50 border border-indigo-200 rounded-lg hover:bg-indigo-100 hover:text-indigo-700 transition cursor-pointer"
              >
                <Eye size={13} />
                View Order #{orderId}
              </button>
            </div>
          );
        }
        return null;
      })()}
    </div>
  );
}

export default function SupplierReviewsPage() {
  const { t, isRTL } = useT();
  const [tab, setTab] = useState<Tab>("customer");
  const [page, setPage] = useState(1);
  const [ratingFrom, setRatingFrom] = useState("");
  const [ratingTo, setRatingTo] = useState("");
  const [createdFrom, setCreatedFrom] = useState("");
  const [createdTo, setCreatedTo] = useState("");

  const params: Record<string, string | number> = { page, limit: LIMIT };
  if (ratingFrom) params.ratingFrom = ratingFrom;
  if (ratingTo) params.ratingTo = ratingTo;
  if (createdFrom) params.created_atFrom = createdFrom;
  if (createdTo) params.created_atTo = createdTo;

  const { data, isLoading, isFetching, refetch } = useQuery({
    queryKey: ["supplier-reviews", params],
    queryFn: async () => {
      const res = await supplierApi.get("/review/all-reviews", { params });
      return res.data?.data ?? res.data;
    },
    staleTime: 60 * 1000,
  });

  const customerReviews: SupplierReview[] = Array.isArray(data?.supplierReviewFromCustomer)
    ? data.supplierReviewFromCustomer
    : [];
  const courierReviews: SupplierReview[] = Array.isArray(data?.supplierReviewFromCourier)
    ? data.supplierReviewFromCourier
    : [];
  const customerPagination: Partial<Pagination> = data?.customerPagination ?? {};
  const courierPagination: Partial<Pagination> = data?.courierPagination ?? {};

  const isCustomer = tab === "customer";
  const reviews = isCustomer ? customerReviews : courierReviews;
  const pagination = isCustomer ? customerPagination : courierPagination;
  const totalPages = pagination.total_pages ?? 1;
  const tabTotal = pagination.total ?? reviews.length;

  const customerTotal = customerPagination.total ?? customerReviews.length;
  const courierTotal = courierPagination.total ?? courierReviews.length;
  const grandTotal = customerTotal + courierTotal;

  function switchTab(next: Tab) {
    if (next === tab) return;
    setTab(next);
    setPage(1);
  }

  // Wrap a setter so any filter change also resets pagination to page 1.
  const onFilterChange =
    (setter: (v: string) => void) =>
    (v: string) => {
      setter(v);
      setPage(1);
    };

  const summary = [
    { label: t("sp.reviews.totalReviews"), value: grandTotal, icon: Star, color: "bg-yellow-50 text-yellow-600" },
    { label: t("sp.reviews.fromCustomers"), value: customerTotal, icon: User, color: "bg-indigo-50 text-indigo-600" },
    { label: t("sp.reviews.fromCouriers"), value: courierTotal, icon: Truck, color: "bg-purple-50 text-purple-600" },
  ];

  const tabs: { key: Tab; label: string; icon: typeof User; count: number }[] = [
    { key: "customer", label: t("sp.reviews.customerReviews"), icon: User, count: customerTotal },
    { key: "courier", label: t("sp.reviews.courierReviews"), icon: Truck, count: courierTotal },
  ];

  return (
    <div className="p-6 space-y-6" dir={isRTL ? "rtl" : "ltr"}>
      {/* Header */}
      <div className="flex items-center justify-between flex-wrap gap-3">
        <div className="flex items-center gap-3">
          <Star size={20} className="text-yellow-500" />
          <div>
            <h1 className="text-xl font-bold text-gray-900">{t("sp.reviews.title")}</h1>
            <p className="text-xs text-gray-500">{t("sp.reviews.subtitle")}</p>
          </div>
        </div>
        <button
          onClick={() => refetch()}
          disabled={isFetching}
          className="p-2 border border-gray-200 rounded-lg text-gray-500 hover:bg-gray-50 disabled:opacity-50"
        >
          <RefreshCw size={14} className={isFetching ? "animate-spin" : ""} />
        </button>
      </div>

      {/* Summary cards */}
      <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
        {summary.map(({ label, value, icon: Icon, color }) => (
          <div key={label} className="bg-white rounded-xl border border-gray-200 p-5 flex items-center gap-4">
            <div className={cn("w-11 h-11 rounded-xl flex items-center justify-center shrink-0", color)}>
              <Icon size={20} />
            </div>
            <div>
              <p className="text-xl font-bold text-gray-900">{isLoading ? "…" : value}</p>
              <p className="text-sm text-gray-500 capitalize">{label}</p>
            </div>
          </div>
        ))}
      </div>

      {/* Filters */}
      <div className="bg-white rounded-xl border border-gray-200 p-4 flex flex-wrap items-start gap-6">
        <RatingRangeFilter
          label={t("sp.reviews.rating")}
          from={ratingFrom}
          to={ratingTo}
          onFromChange={onFilterChange(setRatingFrom)}
          onToChange={onFilterChange(setRatingTo)}
        />
        <DateRangeFilter
          label={t("common.createdAt")}
          from={createdFrom}
          to={createdTo}
          onFromChange={onFilterChange(setCreatedFrom)}
          onToChange={onFilterChange(setCreatedTo)}
        />
      </div>

      {/* Tabs */}
      <div className="flex border-b border-gray-200 gap-1">
        {tabs.map(({ key, label, icon: Icon, count }) => (
          <button
            key={key}
            onClick={() => switchTab(key)}
            className={cn(
              "flex items-center gap-2 px-5 py-2.5 text-sm font-medium border-b-2 transition",
              tab === key
                ? "border-indigo-600 text-indigo-600"
                : "border-transparent text-gray-500 hover:text-gray-700",
            )}
          >
            <Icon size={15} />
            {label}
            <span
              className={cn(
                "text-xs px-1.5 py-0.5 rounded-full",
                tab === key ? "bg-indigo-100 text-indigo-700" : "bg-gray-100 text-gray-500",
              )}
            >
              {count}
            </span>
          </button>
        ))}
      </div>

      {/* List */}
      {isLoading ? (
        <div className="space-y-3">
          {Array.from({ length: 4 }).map((_, i) => (
            <div key={i} className="bg-white rounded-xl border border-gray-200 p-4 h-24 animate-pulse" />
          ))}
        </div>
      ) : reviews.length === 0 ? (
        <div className="bg-white rounded-xl border border-gray-200 p-12 text-center">
          <MessageSquare size={40} className="mx-auto mb-3 text-gray-200" />
          <p className="text-sm text-gray-400">{t("sp.reviews.noReviews")}</p>
        </div>
      ) : (
        <div className={cn("space-y-3", isFetching && "opacity-60 transition-opacity")}>
          {reviews.map((r) => (
            <ReviewCard
              key={r.id}
              review={r}
              source={tab}
              roleLabel={isCustomer ? t("sp.reviews.customer") : t("sp.reviews.courier")}
            />
          ))}
        </div>
      )}

      {/* Pagination (per active tab) */}
      <TablePagination
        page={page}
        totalPages={totalPages}
        total={tabTotal}
        limit={LIMIT}
        onPageChange={setPage}
      />
    </div>
  );
}
