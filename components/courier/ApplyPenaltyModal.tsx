"use client";

import { useState } from "react";
// import { useTranslation } from "react-i18next";
import { useToast } from "@/hooks/use-toast";
import axiosInstance from "@/lib/axios";
import { AxiosError } from "axios";
import { egpToCents } from "@/utils/money";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogFooter,
} from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";

interface ApplyPenaltyModalProps {
  isOpen: boolean;
  onClose: () => void;
  userId: number;
  onSuccess: () => void;
}

export function ApplyPenaltyModal({
  isOpen,
  onClose,
  userId,
  onSuccess,
}: ApplyPenaltyModalProps) {
  // const { t } = useTranslation();
  const { toast } = useToast();

  const [isLoading, setIsLoading] = useState(false);
  const [amount, setAmount] = useState("");
  const [reason, setReason] = useState("");
  const [apiError, setApiError] = useState<string | null>(null);

  // Temporary mock for translation
  const t = (key: string, fallback?: string) => fallback || key;

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();

    // Validation
    if (!amount || isNaN(Number(amount)) || Number(amount) <= 0) {
      toast({
        variant: "destructive",
        title: t("error", "Error"),
        description: t(
          "invalidAmount",
          "Please enter a valid amount greater than 0.",
        ),
      });
      return;
    }

    if (!reason.trim()) {
      toast({
        variant: "destructive",
        title: t("error", "Error"),
        description: t("reasonRequired", "Penalty reason is required."),
      });
      return;
    }

    const amountCents = egpToCents(amount);
    if (amountCents === undefined || amountCents <= 0) {
      toast({
        variant: "destructive",
        title: t("error", "Error"),
        description: t(
          "invalidAmount",
          "Please enter a valid amount greater than 0.",
        ),
      });
      return;
    }

    setIsLoading(true);
    setApiError(null);

    try {
      await axiosInstance.post(`/admin/wallet/apply-penalty/${userId}`, {
        amount: amountCents,
        reason,
      });

      toast({
        title: t("success", "Success"),
        description: t(
          "penaltyApplied",
          "Penalty has been applied successfully.",
        ),
      });

      onSuccess();
      onClose();

      // Reset form
      setAmount("");
      setReason("");
    } catch (err: unknown) {
      const errorMsg =
        (err as AxiosError<{ message: string }>)?.response?.data?.message ||
        t("failedToApplyPenalty", "Failed to apply penalty");
      setApiError(errorMsg);
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <Dialog open={isOpen} onOpenChange={(open) => !open && onClose()}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>{t("applyPenalty", "Apply Penalty")}</DialogTitle>
        </DialogHeader>
        <form onSubmit={handleSubmit} className="py-4 space-y-4">
          {apiError && (
            <div className="p-3 text-sm text-destructive bg-destructive/10 rounded-md border border-destructive/20">
              {apiError}
            </div>
          )}

          <div className="space-y-2">
            <label className="text-sm font-medium">
              {t("penaltyAmount", "Penalty Amount")}{" "}
              <span className="text-red-500">*</span>
            </label>
            <Input
              type="number"
              min="0.01"
              step="any"
              value={amount}
              onChange={(e) => setAmount(e.target.value)}
              placeholder="0.00"
              required
            />
          </div>

          <div className="space-y-2">
            <label className="text-sm font-medium">
              {t("penaltyReason", "Reason for Penalty")}{" "}
              <span className="text-red-500">*</span>
            </label>
            <Textarea
              value={reason}
              onChange={(e) => setReason(e.target.value)}
              placeholder={t("enterPenaltyReason", "Enter reason for penalty")}
              required
            />
          </div>

          <DialogFooter className="pt-4">
            <Button
              type="button"
              variant="outline"
              onClick={onClose}
              disabled={isLoading}
            >
              {t("cancel", "Cancel")}
            </Button>
            <Button variant="destructive" type="submit" disabled={isLoading}>
              {isLoading
                ? t("processing", "Processing...")
                : t("submitPenalty", "Apply Penalty")}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}
