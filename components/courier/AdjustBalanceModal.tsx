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
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { Textarea } from "@/components/ui/textarea";

interface AdjustBalanceModalProps {
  isOpen: boolean;
  onClose: () => void;
  walletId: number;
  onSuccess: () => void;
}

export function AdjustBalanceModal({
  isOpen,
  onClose,
  walletId,
  onSuccess,
}: AdjustBalanceModalProps) {
  // const { t } = useTranslation();
  const { toast } = useToast();

  const [isLoading, setIsLoading] = useState(false);
  const [type, setType] = useState<"MANUAL_INCREASE" | "MANUAL_DECREASE">(
    "MANUAL_INCREASE",
  );
  const [amount, setAmount] = useState("");
  const [description, setDescription] = useState("");
  const [relatedOrderId, setRelatedOrderId] = useState("");
  const [apiError, setApiError] = useState<string | null>(null);

  // Temporary mock for translation
  const t = (key: string, fallback?: string) => fallback || key;

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();

    // Validation Logic
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

    if (!description.trim()) {
      toast({
        variant: "destructive",
        title: t("error", "Error"),
        description: t("descriptionRequired", "Description is required."),
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
      await axiosInstance.post(`/admin/wallet/adjust-balance`, {
        wallet_id: walletId,
        type,
        amount: amountCents,
        description,
        ...(relatedOrderId ? { related_order_id: Number(relatedOrderId) } : {}),
      });

      toast({
        title: t("success", "Success"),
        description: t(
          "balanceAdjusted",
          "Balance has been adjusted successfully.",
        ),
      });

      onSuccess();
      onClose();

      // Reset form
      setAmount("");
      setDescription("");
      setRelatedOrderId("");
      setType("MANUAL_INCREASE");
    } catch (err: unknown) {
      const errorMsg =
        (err as AxiosError<{ message: string }>)?.response?.data?.message ||
        t("failedToAdjustBalance", "Failed to adjust balance");
      setApiError(errorMsg);
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <Dialog open={isOpen} onOpenChange={(open) => !open && onClose()}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>{t("adjustBalance", "Adjust Balance")}</DialogTitle>
        </DialogHeader>
        <form onSubmit={handleSubmit} className="py-4 space-y-4">
          {apiError && (
            <div className="p-3 text-sm text-destructive bg-destructive/10 rounded-md border border-destructive/20">
              {apiError}
            </div>
          )}

          <div className="space-y-2">
            <label className="text-sm font-medium">
              {t("adjustmentType", "Adjustment Type")}
            </label>
            <Select
              value={type}
              onValueChange={(val: "MANUAL_INCREASE" | "MANUAL_DECREASE") =>
                setType(val)
              }
            >
              <SelectTrigger>
                <SelectValue placeholder={t("selectType", "Select type")} />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="MANUAL_INCREASE">
                  {t("manualIncrease", "Manual Increase (Add)")}
                </SelectItem>
                <SelectItem value="MANUAL_DECREASE">
                  {t("manualDecrease", "Manual Decrease (Deduct)")}
                </SelectItem>
              </SelectContent>
            </Select>
          </div>

          <div className="space-y-2">
            <label className="text-sm font-medium">
              {t("amount", "Amount")} <span className="text-red-500">*</span>
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
              {t("description", "Description")}{" "}
              <span className="text-red-500">*</span>
            </label>
            <Textarea
              value={description}
              onChange={(e) => setDescription(e.target.value)}
              placeholder={t("enterDescription", "Enter reason for adjustment")}
              required
            />
          </div>

          <div className="space-y-2">
            <label className="text-sm font-medium">
              {t("relatedOrderId", "Related Order ID (Optional)")}
            </label>
            <Input
              type="number"
              value={relatedOrderId}
              onChange={(e) => setRelatedOrderId(e.target.value)}
              placeholder={t("optional", "Optional")}
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
            <Button type="submit" disabled={isLoading}>
              {isLoading
                ? t("processing", "Processing...")
                : t("submit", "Submit")}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}
