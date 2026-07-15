"use client";
import { useState } from "react";
import { useT } from "@/contexts/LanguageContext";
import { submitCourierReview, giveCourierPoints } from "@/lib/personalOrders";
import StarRating from "./StarRating";
import toast from "react-hot-toast";
import { X, Loader2, Star } from "lucide-react";

export default function RateCourierDialog({
  orderId,
  courierId,
  courierUserId,
  courierName,
  open,
  onClose,
  onSubmitted,
  existingReview,
}: {
  orderId: number;
  courierId: number;
  courierUserId?: number | null;
  courierName?: string | null;
  open: boolean;
  onClose: () => void;
  onSubmitted?: () => void;
  /** When provided, the dialog shows the already-submitted review read-only. */
  existingReview?: { rating?: number | null; comment?: string | null } | null;
}) {
  const { t, isRTL } = useT();
  const [rating, setRating] = useState(0);
  const [comment, setComment] = useState("");
  const [submitting, setSubmitting] = useState(false);

  if (!open) return null;

  const viewing = !!existingReview;

  if (viewing) {
    return (
      <div
        className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4"
        dir={isRTL ? "rtl" : "ltr"}
      >
        <div className="bg-white rounded-2xl shadow-2xl w-full max-w-md">
          <div className="flex items-center justify-between px-6 py-4 border-b border-gray-100">
            <h2 className="text-lg font-bold text-gray-900 flex items-center gap-2">
              <Star className="w-5 h-5 text-amber-400 fill-amber-400" />
              {t("sp.rate.yourReview")}
            </h2>
            <button onClick={onClose} className="p-2 rounded-xl hover:bg-gray-100 text-gray-400">
              <X size={18} />
            </button>
          </div>

          <div className="px-6 py-5 space-y-4">
            {courierName && (
              <p className="text-sm text-gray-500 text-center">
                <span className="font-semibold text-gray-800">{courierName}</span>
              </p>
            )}

            <div className="flex justify-center py-2">
              <StarRating value={existingReview?.rating ?? 0} readOnly />
            </div>

            <p className="w-full text-sm text-gray-700 bg-gray-50 border border-gray-200 rounded-lg px-3 py-2 min-h-[3rem] whitespace-pre-wrap">
              {existingReview?.comment?.trim() || (
                <span className="text-gray-400">{t("sp.rate.noComment")}</span>
              )}
            </p>
          </div>

          <div className="flex px-6 py-4 border-t border-gray-100">
            <button
              onClick={onClose}
              className="flex-1 px-4 py-2.5 border border-gray-200 rounded-xl text-gray-600 hover:bg-gray-50"
            >
              {t("sp.rate.close")}
            </button>
          </div>
        </div>
      </div>
    );
  }

  async function handleSubmit() {
    if (rating < 1) {
      toast.error(t("sp.rate.pickRating"));
      return;
    }
    setSubmitting(true);
    try {
      await submitCourierReview({
        order_id: orderId,
        courier_id: courierId,
        rating,
        comment: comment.trim() || undefined,
      });
      // Loyalty points are always awarded to the courier on rating (no opt-in).
      if (courierUserId) {
        await giveCourierPoints(courierUserId).catch(() => {});
      }
      toast.success(t("sp.rate.thanks"));
      onSubmitted?.();
      onClose();
    } catch (err: any) {
      toast.error(err?.response?.data?.message ?? t("sp.rate.error"));
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4"
      dir={isRTL ? "rtl" : "ltr"}
    >
      <div className="bg-white rounded-2xl shadow-2xl w-full max-w-md">
        <div className="flex items-center justify-between px-6 py-4 border-b border-gray-100">
          <h2 className="text-lg font-bold text-gray-900 flex items-center gap-2">
            <Star className="w-5 h-5 text-amber-400" />
            {t("sp.rate.courierTitle")}
          </h2>
          <button onClick={onClose} className="p-2 rounded-xl hover:bg-gray-100 text-gray-400">
            <X size={18} />
          </button>
        </div>

        <div className="px-6 py-5 space-y-4">
          {courierName && (
            <p className="text-sm text-gray-500 text-center">
              {t("sp.rate.howWas")} <span className="font-semibold text-gray-800">{courierName}</span>?
            </p>
          )}

          <div className="flex justify-center py-2">
            <StarRating value={rating} onChange={setRating} />
          </div>

          <textarea
            rows={3}
            value={comment}
            onChange={(e) => setComment(e.target.value)}
            placeholder={t("sp.rate.commentPlaceholder")}
            className="w-full text-sm border border-gray-300 rounded-lg px-3 py-2 focus:ring-2 focus:ring-indigo-400 focus:border-indigo-400 resize-none"
          />
        </div>

        <div className="flex gap-2 px-6 py-4 border-t border-gray-100">
          <button
            onClick={handleSubmit}
            disabled={submitting}
            className="flex-1 flex items-center justify-center gap-2 px-4 py-2.5 bg-indigo-600 text-white rounded-xl font-semibold hover:bg-indigo-700 disabled:opacity-50"
          >
            {submitting ? <Loader2 className="w-4 h-4 animate-spin" /> : null}
            {t("sp.rate.submit")}
          </button>
          <button
            onClick={onClose}
            className="px-4 py-2.5 border border-gray-200 rounded-xl text-gray-600 hover:bg-gray-50"
          >
            {t("sp.rate.later")}
          </button>
        </div>
      </div>
    </div>
  );
}
