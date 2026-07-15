"use client";
import { useState, useEffect, useRef } from "react";
import { useQuery } from "@tanstack/react-query";
import { useT } from "@/contexts/LanguageContext";
import { fetchRefundReasons } from "@/lib/personalOrders";
import toast from "react-hot-toast";
import { X, Loader2, RotateCcw, ImagePlus } from "lucide-react";
import { ALLOWED_IMAGE_ACCEPT, filterAllowedImageFiles } from "@/lib/file-upload";

interface Evidence {
  file: File;
  url: string;
}

export default function RefundDialog({
  orderId,
  open,
  onClose,
  onSubmitted,
}: {
  orderId: number;
  open: boolean;
  onClose: () => void;
  onSubmitted?: () => void;
}) {
  const { t, isRTL, lang } = useT();
  const [selected, setSelected] = useState<number | null>(null);
  const [images, setImages] = useState<Evidence[]>([]);
  const [submitting, setSubmitting] = useState(false);
  const fileRef = useRef<HTMLInputElement>(null);

  const { data: reasons = [], isLoading } = useQuery({
    queryKey: ["refund-reasons", lang],
    queryFn: () => fetchRefundReasons(lang),
    enabled: open,
  });

  // Revoke object URLs on unmount
  useEffect(() => {
    return () => {
      images.forEach((i) => URL.revokeObjectURL(i.url));
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  if (!open) return null;

  function addImages(e: React.ChangeEvent<HTMLInputElement>) {
    const files = filterAllowedImageFiles(Array.from(e.target.files ?? []));
    if (!files.length) return;
    setImages((prev) => [...prev, ...files.map((file) => ({ file, url: URL.createObjectURL(file) }))]);
    if (fileRef.current) fileRef.current.value = "";
  }

  function removeImage(idx: number) {
    setImages((prev) => {
      const next = [...prev];
      URL.revokeObjectURL(next[idx].url);
      next.splice(idx, 1);
      return next;
    });
  }

  async function handleSubmit() {
    if (selected == null) {
      toast.error(t("sp.refund.pickReason"));
      return;
    }
    setSubmitting(true);
    try {
      // TODO(API): wire the create-refund endpoint once confirmed. Expected a
      // multipart POST /refunds with { order_id, refund_reason_id, evidence_images[] }.
      // Endpoint/payload were not provided, so the submit is stubbed for now.
      const reason = reasons.find((r) => r.id === selected);
      // eslint-disable-next-line no-console
      console.warn("[RefundDialog] stubbed submit", {
        order_id: orderId,
        refund_reason_id: selected,
        reason: reason ? (isRTL ? reason.reason_ar : reason.reason_en) : undefined,
        evidence_images: images.map((i) => i.file.name),
      });
      await new Promise((r) => setTimeout(r, 300));
      toast.success(t("sp.refund.success"));
      onSubmitted?.();
      onClose();
    } catch (err: any) {
      toast.error(err?.response?.data?.message ?? t("sp.refund.error"));
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4"
      dir={isRTL ? "rtl" : "ltr"}
    >
      <div className="bg-white rounded-2xl shadow-2xl w-full max-w-md max-h-[88vh] flex flex-col">
        <div className="flex items-center justify-between px-6 py-4 border-b border-gray-100">
          <h2 className="text-lg font-bold text-gray-900 flex items-center gap-2">
            <RotateCcw className="w-5 h-5 text-indigo-500" />
            {t("sp.refund.title")}
          </h2>
          <button onClick={onClose} className="p-2 rounded-xl hover:bg-gray-100 text-gray-400">
            <X size={18} />
          </button>
        </div>

        <div className="px-6 py-4 overflow-y-auto flex-1 space-y-4">
          {/* Reasons */}
          <div>
            <p className="text-sm font-medium text-gray-700 mb-2">{t("sp.refund.chooseReason")}</p>
            {isLoading ? (
              <div className="flex items-center gap-2 text-gray-400 py-4 justify-center">
                <Loader2 className="w-4 h-4 animate-spin" />
                {t("common.loading")}
              </div>
            ) : reasons.length === 0 ? (
              <p className="text-sm text-gray-400 py-4 text-center">{t("sp.refund.noReasons")}</p>
            ) : (
              <div className="space-y-2">
                {reasons.map((r) => {
                  const active = selected === r.id;
                  return (
                    <button
                      key={r.id}
                      type="button"
                      onClick={() => setSelected(r.id)}
                      className={`w-full text-start flex items-center gap-3 p-3 rounded-xl border-2 transition ${
                        active
                          ? "border-indigo-400 bg-indigo-50"
                          : "border-gray-200 hover:border-gray-300"
                      }`}
                    >
                      <span
                        className={`w-4 h-4 rounded-full border-2 flex items-center justify-center shrink-0 ${
                          active ? "border-indigo-500" : "border-gray-300"
                        }`}
                      >
                        {active && <span className="w-2 h-2 rounded-full bg-indigo-500" />}
                      </span>
                      <span className="text-sm text-gray-800">
                        {isRTL ? r.reason_ar : r.reason_en}
                      </span>
                    </button>
                  );
                })}
              </div>
            )}
          </div>

          {/* Evidence images */}
          <div>
            <p className="text-sm font-medium text-gray-700 mb-2">{t("sp.refund.evidence")}</p>
            <div className="flex flex-wrap gap-2">
              {images.map((img, idx) => (
                <div key={img.url} className="relative">
                  {/* eslint-disable-next-line @next/next/no-img-element */}
                  <img
                    src={img.url}
                    alt="evidence"
                    className="w-20 h-20 rounded-lg object-cover border border-gray-200"
                  />
                  <button
                    type="button"
                    onClick={() => removeImage(idx)}
                    className="absolute -top-2 -end-2 w-5 h-5 rounded-full bg-red-500 text-white flex items-center justify-center shadow"
                  >
                    <X className="w-3 h-3" />
                  </button>
                </div>
              ))}
              <label className="w-20 h-20 flex flex-col items-center justify-center gap-1 border-2 border-dashed border-gray-300 rounded-lg cursor-pointer hover:border-indigo-400 hover:bg-indigo-50/40 transition">
                <ImagePlus className="w-5 h-5 text-gray-400" />
                <span className="text-[10px] text-gray-400">{t("sp.refund.addImage")}</span>
                <input
                  ref={fileRef}
                  type="file"
                  accept={ALLOWED_IMAGE_ACCEPT}
                  multiple
                  onChange={addImages}
                  className="hidden"
                />
              </label>
            </div>
          </div>
        </div>

        <div className="flex gap-2 px-6 py-4 border-t border-gray-100">
          <button
            onClick={handleSubmit}
            disabled={submitting || selected == null}
            className="flex-1 flex items-center justify-center gap-2 px-4 py-2.5 bg-indigo-600 text-white rounded-xl font-semibold hover:bg-indigo-700 disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {submitting ? <Loader2 className="w-4 h-4 animate-spin" /> : null}
            {t("common.confirm")}
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
