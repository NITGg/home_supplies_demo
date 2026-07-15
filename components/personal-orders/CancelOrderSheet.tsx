"use client";
import { useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { useT } from "@/contexts/LanguageContext";
import { fetchCustomerCancellationReasons, cancelOrder } from "@/lib/personalOrders";
import toast from "react-hot-toast";
import { X, Loader2, AlertTriangle } from "lucide-react";

export default function CancelOrderSheet({
  orderId,
  open,
  onClose,
  onCancelled,
}: {
  orderId: number;
  open: boolean;
  onClose: () => void;
  onCancelled: () => void;
}) {
  const { t, isRTL, lang } = useT();
  const [selected, setSelected] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState(false);

  const { data: reasons = [], isLoading } = useQuery({
    queryKey: ["customer-cancellation-reasons"],
    queryFn: fetchCustomerCancellationReasons,
    enabled: open,
  });

  if (!open) return null;

  async function handleConfirm() {
    if (!selected) return;
    setSubmitting(true);
    try {
      await cancelOrder(orderId, selected, lang);
      toast.success(t("sp.activeOrders.cancelSuccess"));
      onCancelled();
      onClose();
    } catch (err: any) {
      toast.error(err?.response?.data?.message ?? t("sp.activeOrders.cancelError"));
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4"
      dir={isRTL ? "rtl" : "ltr"}
    >
      <div className="bg-white rounded-2xl shadow-2xl w-full max-w-md max-h-[85vh] flex flex-col">
        <div className="flex items-center justify-between px-6 py-4 border-b border-gray-100">
          <h2 className="text-lg font-bold text-gray-900 flex items-center gap-2">
            <AlertTriangle className="w-5 h-5 text-red-500" />
            {t("sp.activeOrders.cancelTitle")}
          </h2>
          <button onClick={onClose} className="p-2 rounded-xl hover:bg-gray-100 text-gray-400">
            <X size={18} />
          </button>
        </div>

        <div className="px-6 py-4 overflow-y-auto flex-1">
          <p className="text-sm text-gray-500 mb-3">{t("sp.activeOrders.cancelChooseReason")}</p>
          {isLoading ? (
            <div className="flex items-center gap-2 text-gray-400 py-6 justify-center">
              <Loader2 className="w-4 h-4 animate-spin" />
              {t("common.loading")}
            </div>
          ) : reasons.length === 0 ? (
            <p className="text-sm text-gray-400 py-6 text-center">
              {t("sp.activeOrders.noReasons")}
            </p>
          ) : (
            <div className="space-y-2">
              {reasons.map((r) => {
                const label = isRTL ? r.reason_ar : r.reason_en;
                const active = selected === label;
                return (
                  <button
                    key={r.id}
                    type="button"
                    onClick={() => setSelected(label)}
                    className={`w-full text-start flex items-center gap-3 p-3 rounded-xl border-2 transition ${
                      active ? "border-red-400 bg-red-50" : "border-gray-200 hover:border-gray-300"
                    }`}
                  >
                    <span
                      className={`w-4 h-4 rounded-full border-2 flex items-center justify-center shrink-0 ${
                        active ? "border-red-500" : "border-gray-300"
                      }`}
                    >
                      {active && <span className="w-2 h-2 rounded-full bg-red-500" />}
                    </span>
                    <span className="text-sm text-gray-800">{label}</span>
                  </button>
                );
              })}
            </div>
          )}
        </div>

        <div className="flex gap-2 px-6 py-4 border-t border-gray-100">
          <button
            onClick={handleConfirm}
            disabled={!selected || submitting}
            className="flex-1 flex items-center justify-center gap-2 px-4 py-2.5 bg-red-600 text-white rounded-xl font-semibold hover:bg-red-700 disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {submitting ? <Loader2 className="w-4 h-4 animate-spin" /> : null}
            {t("sp.activeOrders.confirmCancel")}
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
