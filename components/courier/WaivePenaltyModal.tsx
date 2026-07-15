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
  DialogDescription,
} from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import { AlertCircle, Loader2 } from "lucide-react";

interface WaivePenaltyModalProps {
  isOpen: boolean;
  onClose: () => void;
  penaltyId: number;
  onSuccess: () => void;
}

export function WaivePenaltyModal({
  isOpen,
  onClose,
  penaltyId,
  onSuccess,
}: WaivePenaltyModalProps) {
  // const { t } = useTranslation();
  const t = (key: string, fallback: string) => fallback;
  const { toast } = useToast();
  const [isLoading, setIsLoading] = useState(false);

  const handleWaive = async () => {
    setIsLoading(true);
    try {
      await axiosInstance.post(`/admin/wallet/waive-penalty/${penaltyId}`);

      toast({
        title: t("success", "Success"),
        description: t(
          "penaltyWaived",
          "Penalty has been waived successfully.",
        ),
      });

      onSuccess();
      onClose();
    } catch (err: unknown) {
      const axiosErr = err as AxiosError<{ message: string }>;
      const errorMsg =
        axiosErr?.response?.data?.message ||
        t("failedToWaivePenalty", "Failed to waive penalty");

      toast({
        variant: "destructive",
        title: t("error", "Error"),
        description: errorMsg,
      });
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <Dialog
      open={isOpen}
      onOpenChange={(open) => !open && !isLoading && onClose()}
    >
      <DialogContent className="sm:max-w-[400px]">
        <DialogHeader>
          <DialogTitle className="flex items-center gap-2">
            <AlertCircle className="h-5 w-5 text-destructive" />
            {t("waivePenalty", "Waive Penalty")}
          </DialogTitle>
          <DialogDescription className="pt-2">
            {t(
              "confirmWaivePenalty",
              "Are you sure you want to waive this penalty? This action will restore the amount to the courier's balance and cannot be undone.",
            )}
          </DialogDescription>
        </DialogHeader>

        <DialogFooter className="mt-4 gap-2 sm:gap-0">
          <Button variant="outline" onClick={onClose} disabled={isLoading}>
            {t("cancel", "Cancel")}
          </Button>
          <Button
            variant="destructive"
            onClick={handleWaive}
            disabled={isLoading}
            className="min-w-[120px]"
          >
            {isLoading ? (
              <>
                <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                {t("processing", "Processing...")}
              </>
            ) : (
              t("confirmWaive", "Waive Penalty")
            )}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
