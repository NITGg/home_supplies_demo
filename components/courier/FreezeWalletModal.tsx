"use client";

import { useState } from "react";
// import { useTranslation } from "react-i18next";
import { useToast } from "@/hooks/use-toast";
import axiosInstance from "@/lib/axios";
import { AxiosError } from "axios";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogFooter,
} from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import { Textarea } from "@/components/ui/textarea";

interface FreezeWalletModalProps {
  isOpen: boolean;
  onClose: () => void;
  walletId: number;
  onSuccess: () => void;
}

export function FreezeWalletModal({
  isOpen,
  onClose,
  walletId,
  onSuccess,
}: FreezeWalletModalProps) {
  // const { t } = useTranslation();
  const t = (key: string, fallback: string) => fallback;
  const { toast } = useToast();

  const [isLoading, setIsLoading] = useState(false);
  const [freezeReason, setFreezeReason] = useState("");
  const [apiError, setApiError] = useState<string | null>(null);

  /**
   * Reset local state when closing the modal to ensure
   * a clean state if reopened for the same or different wallet.
   */
  const handleClose = () => {
    setFreezeReason("");
    setApiError(null);
    onClose();
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();

    const trimmedReason = freezeReason.trim();
    if (!trimmedReason) {
      toast({
        variant: "destructive",
        title: t("error", "Error"),
        description: t("reasonRequired", "Freeze reason is required."),
      });
      return;
    }

    setIsLoading(true);
    setApiError(null);

    try {
      await axiosInstance.post(`/admin/wallet/freeze/${walletId}`, {
        freeze_reason: trimmedReason,
      });

      toast({
        title: t("success", "Success"),
        description: t("walletFrozen", "Wallet has been frozen successfully."),
      });

      onSuccess();
      handleClose();
    } catch (err: unknown) {
      const axiosErr = err as AxiosError<{ message: string }>;
      const errorMsg =
        axiosErr?.response?.data?.message ||
        t("failedToFreezeWallet", "Failed to freeze wallet");
      setApiError(errorMsg);
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <Dialog open={isOpen} onOpenChange={(open) => !open && handleClose()}>
      <DialogContent className="sm:max-w-[425px]">
        <DialogHeader>
          <DialogTitle>{t("freezeWallet", "Freeze Wallet")}</DialogTitle>
        </DialogHeader>

        <form onSubmit={handleSubmit} className="space-y-4 pt-4">
          {apiError && (
            <div className="p-3 text-sm text-destructive bg-destructive/10 rounded-md border border-destructive/20 animate-in fade-in zoom-in duration-200">
              {apiError}
            </div>
          )}

          <div className="space-y-2">
            <label className="text-sm font-semibold text-foreground/90">
              {t("freezeReason", "Freeze Reason")}{" "}
              <span className="text-destructive">*</span>
            </label>
            <Textarea
              value={freezeReason}
              onChange={(e) => setFreezeReason(e.target.value)}
              placeholder={t(
                "enterFreezeReason",
                "Enter reason for freezing the wallet",
              )}
              className="min-h-[100px] resize-none"
              required
            />
            <p className="text-[12px] text-muted-foreground">
              {t(
                "freezeWarning",
                "This will prevent the courier from making any new transactions.",
              )}
            </p>
          </div>

          <DialogFooter className="gap-2 sm:gap-0">
            <Button
              type="button"
              variant="ghost"
              onClick={handleClose}
              disabled={isLoading}
            >
              {t("cancel", "Cancel")}
            </Button>
            <Button variant="destructive" type="submit" disabled={isLoading}>
              {isLoading
                ? t("processing", "Processing...")
                : t("confirmFreeze", "Confirm Freeze")}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}
