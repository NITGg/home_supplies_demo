"use client";
import { useState } from "react";
import { useT } from "@/contexts/LanguageContext";
import StarRating from "./StarRating";
import toast from "react-hot-toast";
import { X, Loader2, Star } from "lucide-react";

export default function RateSupplierDialog({
  orderId,
  supplierId,
  supplierName,
  open,
  onClose,
  onSubmitted,
}: {
  orderId: number;
  supplierId: number;
  supplierName?: string | null;
  open: boolean;
  onClose: () => void;
  onSubmitted?: () => void;
}) {
  const { t, isRTL } = useT();
  const [rating, setRating] = useState(0);
  const [comment, setComment] = useState("");
  const [submitting, setSubmitting] = useState(false);

  if (!open) return null;

  async function handleSubmit() {
    if (rating < 1) {
      toast.error(t("sp.rate.pickRating"));
      return;
    }
    setSubmitting(true);
    try {
      // TODO(API): wire the customer→supplier rating endpoint once confirmed.
      // Expected something like:
      //   await api.post("/supplier-reviews", { order_id: orderId, supplier_id: supplierId, rating, comment });
      // Endpoint/payload were not provided, so the submit is stubbed for now.
      // eslint-disable-next-line no-console
      console.warn("[RateSupplierDialog] stubbed submit", {
        order_id: orderId,
        supplier_id: supplierId,
        rating,
        comment: comment.trim() || undefined,
      });
      await new Promise((r) => setTimeout(r, 300));
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
            {t("sp.rate.supplierTitle")}
          </h2>
          <button onClick={onClose} className="p-2 rounded-xl hover:bg-gray-100 text-gray-400">
            <X size={18} />
          </button>
        </div>

        <div className="px-6 py-5 space-y-4">
          {supplierName && (
            <p className="text-sm text-gray-500 text-center">
              {t("sp.rate.howWas")}{" "}
              <span className="font-semibold text-gray-800">{supplierName}</span>?
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
            {t("common.cancel")}
          </button>
        </div>
      </div>
    </div>
  );
}
