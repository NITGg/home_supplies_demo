"use client";

import { useState } from "react";
import { useMutation, useQueryClient } from "@tanstack/react-query";
import { X, Calendar, Loader2, DollarSign } from "lucide-react";
import api from "@/lib/api";
import toast from "react-hot-toast";

interface SettleBalanceModalProps {
  userId: number;
  userName: string;
  onClose: () => void;
}

export default function SettleBalanceModal({
  userId,
  userName,
  onClose,
}: SettleBalanceModalProps) {
  const queryClient = useQueryClient();

  const getTodayString = () => {
    const d = new Date();
    const year = d.getFullYear();
    const month = String(d.getMonth() + 1).padStart(2, "0");
    const day = String(d.getDate()).padStart(2, "0");
    return `${year}-${month}-${day}`;
  };

  const getYesterdayString = () => {
    const d = new Date();
    d.setDate(d.getDate() - 1); // Get yesterday's date
    const year = d.getFullYear();
    const month = String(d.getMonth() + 1).padStart(2, "0");
    const day = String(d.getDate()).padStart(2, "0");
    return `${year}-${month}-${day}`;
  };

  const [periodFrom, setPeriodFrom] = useState("");
  const [periodTo, setPeriodTo] = useState("");

  const settleMutation = useMutation({
    mutationFn: async () => {
      const payload: any = {
        target_user_id: userId,
      };
      if (periodFrom) payload.period_from = periodFrom;
      if (periodTo) payload.period_to = periodTo;

      const response = await api.post(
        "/admin/wallet/settling-balance",
        payload,
      );
      return response.data;
    },
    onSuccess: (data) => {
      const successMessage = data.message || "Balance settled successfully";
      toast.success(successMessage);

      // Invalidate queries to refresh the page/wallet details in real-time
      queryClient.invalidateQueries({ queryKey: ["user", userId, "details"] });
      queryClient.invalidateQueries({ queryKey: ["user-wallet", userId] });
      queryClient.invalidateQueries({
        queryKey: ["user-transactions", userId],
      });

      onClose();
    },
    onError: (err: any) => {
      const errorMessage =
        err.response?.data?.message ||
        err.message ||
        "Failed to settle balance";
      toast.error(errorMessage);
    },
  });

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    settleMutation.mutate();
  };

  return (
    <div className="fixed inset-0 bg-black/60 backdrop-blur-sm z-50 flex items-center justify-center p-4 transition-all duration-300">
      <div
        className="bg-white rounded-2xl shadow-2xl w-full max-w-md max-h-[90vh] overflow-y-auto transform scale-100 transition-all"
        onClick={(e) => e.stopPropagation()}
      >
        {/* Header */}
        <div className="flex items-center justify-between px-6 py-4 border-b border-gray-100 sticky top-0 bg-white z-10">
          <div className="flex items-center gap-2">
            <div className="w-8 h-8 rounded-lg bg-emerald-50 flex items-center justify-center text-emerald-600">
              <DollarSign size={18} />
            </div>
            <h2 className="text-lg font-semibold text-gray-900">
              Settle Balance
            </h2>
          </div>
          <button
            onClick={onClose}
            className="p-1.5 text-gray-400 hover:text-gray-600 hover:bg-gray-100 rounded-lg transition"
          >
            <X size={18} />
          </button>
        </div>

        {/* Form */}
        <form onSubmit={handleSubmit} className="p-6 space-y-6">
          {/* User Info Card */}
          <div className="p-4 bg-gray-50 border border-gray-100 rounded-xl space-y-1">
            <p className="text-xs font-semibold text-gray-400 uppercase tracking-wider">
              Target User
            </p>
            <p className="text-sm font-bold text-gray-800">{userName}</p>
            <p className="text-xs text-gray-500">
              User ID:{" "}
              <span className="font-mono bg-gray-200/60 px-1 py-0.5 rounded text-gray-700">
                {userId}
              </span>
            </p>
          </div>

          <div className="space-y-4">
            {/* Period From */}
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1.5 flex items-center gap-1.5">
                <Calendar size={14} className="text-gray-400" />
                Period From{" "}
                <span className="text-xs text-gray-400 font-normal">
                  (Optional)
                </span>
              </label>
              <input
                type="date"
                value={periodFrom}
                onChange={(e) => setPeriodFrom(e.target.value)}
                max={getYesterdayString()}
                className="w-full border border-gray-300 rounded-xl px-3 py-2.5 text-sm focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500 outline-none transition"
              />
            </div>

            {/* Period To */}
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1.5 flex items-center gap-1.5">
                <Calendar size={14} className="text-gray-400" />
                Period To{" "}
                <span className="text-xs text-gray-400 font-normal">
                  (Optional)
                </span>
              </label>
              <input
                type="date"
                value={periodTo}
                onChange={(e) => setPeriodTo(e.target.value)}
                max={getYesterdayString()}
                className="w-full border border-gray-300 rounded-xl px-3 py-2.5 text-sm focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500 outline-none transition"
              />
            </div>
          </div>

          {/* Action buttons */}
          <div className="flex gap-3 pt-2">
            <button
              type="button"
              onClick={onClose}
              className="flex-1 border border-gray-300 rounded-xl py-2.5 text-sm font-medium text-gray-700 hover:bg-gray-50 transition"
              disabled={settleMutation.isPending}
            >
              Cancel
            </button>
            <button
              type="submit"
              disabled={settleMutation.isPending}
              className="flex-1 bg-emerald-600 hover:bg-emerald-700 text-white rounded-xl py-2.5 text-sm font-medium disabled:opacity-60 transition flex items-center justify-center gap-1.5"
            >
              {settleMutation.isPending ? (
                <>
                  <Loader2 className="animate-spin" size={16} />
                  Settling...
                </>
              ) : (
                "Settle Balance"
              )}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
