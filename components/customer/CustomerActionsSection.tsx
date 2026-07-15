"use client";

import { useState } from "react";
// import { useTranslation } from "react-i18next";
import { AxiosError } from "axios";
import axiosInstance from "@/lib/axios";
import { useToast } from "@/hooks/use-toast";
import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogContent,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import {
  Tooltip,
  TooltipContent,
  TooltipProvider,
  TooltipTrigger,
} from "@/components/ui/tooltip";
import { useRouter } from "next/navigation";
import { Wallet, Lock, Unlock, AlertTriangle, Bell, Store } from "lucide-react";
import { AdjustBalanceModal } from "@/components/courier/AdjustBalanceModal";
import { FreezeWalletModal } from "@/components/courier/FreezeWalletModal";
import { ApplyPenaltyModal } from "@/components/courier/ApplyPenaltyModal";
import { SendNotificationModal } from "@/components/shared/SendNotificationModal";

export interface CustomerWallet {
  id: number;
  status: string;
  balance: number;
}

interface CustomerActionsSectionProps {
  userId: number;
  wallet: CustomerWallet | null;
  onSuccess: () => void;
  showConvertToSeller?: boolean;
}

function ActionButton({
  icon: Icon,
  label,
  onClick,
  disabled,
  variant = "default",
  className = "",
  tooltipMessage = "Action unavailable",
}: {
  icon: React.ElementType;
  label: string;
  onClick: () => void;
  disabled: boolean;
  variant?:
    | "default"
    | "destructive"
    | "outline"
    | "secondary"
    | "ghost"
    | "link";
  className?: string;
  tooltipMessage?: string;
}) {
  const button = (
    <Button
      variant={variant}
      onClick={onClick}
      disabled={disabled}
      className={className}
    >
      <Icon className="mr-2 h-4 w-4" />
      {label}
    </Button>
  );

  if (disabled) {
    return (
      <TooltipProvider>
        <Tooltip>
          <TooltipTrigger asChild>
            <div className="cursor-not-allowed">{button}</div>
          </TooltipTrigger>
          <TooltipContent>
            <p>{tooltipMessage}</p>
          </TooltipContent>
        </Tooltip>
      </TooltipProvider>
    );
  }

  return button;
}

export function CustomerActionsSection({
  userId,
  wallet,
  onSuccess,
  showConvertToSeller = false,
}: CustomerActionsSectionProps) {
  // const { t } = useTranslation();
  const { toast } = useToast();
  const router = useRouter();

  // Temporary mock for translation if i18next is not set up in Next.js yet
  const t = (key: string, fallback: string) => fallback;

  const genericUnavailableText = t("actionUnavailable", "Action unavailable");
  const [isAdjustBalanceOpen, setIsAdjustBalanceOpen] = useState(false);
  const [isFreezeWalletOpen, setIsFreezeWalletOpen] = useState(false);
  const [isApplyPenaltyOpen, setIsApplyPenaltyOpen] = useState(false);
  const [isUnfreezeOpen, setIsUnfreezeOpen] = useState(false);
  const [isSendNotificationOpen, setIsSendNotificationOpen] = useState(false);
  const [isConvertToSellerOpen, setIsConvertToSellerOpen] = useState(false);
  const [isLoading, setIsLoading] = useState(false);

  const status = wallet?.status ? String(wallet.status).toLowerCase() : null;
  const hasWallet = !!wallet;
  const canFreeze = hasWallet && status !== "frozen";
  const canUnfreeze = hasWallet && status === "frozen";

  const noWalletTooltip = t(
    "noWalletAssociated",
    "No wallet associated with this customer.",
  );

  const handleUnfreeze = async () => {
    if (!wallet) return;
    setIsLoading(true);
    try {
      await axiosInstance.post(`/admin/wallet/unfreeze/${wallet.id}`);
      toast({
        title: t("success", "Success"),
        description: t(
          "walletUnfrozen",
          "Wallet has been unfrozen successfully.",
        ),
      });
      setIsUnfreezeOpen(false);
      onSuccess();
    } catch (err: unknown) {
      toast({
        variant: "destructive",
        title: t("error", "Error"),
        description:
          (err as AxiosError<{ message: string }>)?.response?.data?.message ||
          t("failedToUnfreeze", "Failed to unfreeze wallet"),
      });
    } finally {
      setIsLoading(false);
    }
  };

  const handleConvertToSeller = async () => {
    setIsLoading(true);
    try {
      await axiosInstance.post(
        `/admin/manage-seller/convert-customer-to-seller/${userId}`,
      );
      toast({
        title: t("success", "Success"),
        description: t(
          "convertedToSeller",
          "Customer has been converted to seller successfully.",
        ),
      });
      setIsConvertToSellerOpen(false);
      // Next.js router used here instead of useNavigate
      router.push(`/users/sellers/${userId}`);
    } catch (err: unknown) {
      toast({
        variant: "destructive",
        title: t("error", "Error"),
        description:
          (err as AxiosError<{ message: string }>)?.response?.data?.message ||
          t("failedToConvert", "Failed to convert customer to seller"),
      });
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className="bg-card border rounded-lg shadow-sm overflow-hidden mb-6">
      <div className="px-6 py-4 border-b bg-muted/30">
        <h2 className="font-semibold text-lg">{t("actions", "Actions")}</h2>
      </div>
      <div className="p-6 flex flex-wrap gap-4">
        <ActionButton
          icon={Wallet}
          label={t("adjustBalance", "Adjust Balance")}
          onClick={() => setIsAdjustBalanceOpen(true)}
          disabled={!hasWallet}
          variant="outline"
          tooltipMessage={noWalletTooltip}
        />
        <ActionButton
          icon={Lock}
          label={t("freezeWallet", "Freeze")}
          onClick={() => setIsFreezeWalletOpen(true)}
          disabled={!canFreeze}
          variant="outline"
          tooltipMessage={!hasWallet ? noWalletTooltip : genericUnavailableText}
        />
        <ActionButton
          icon={Unlock}
          label={t("unfreezeWallet", "Unfreeze")}
          onClick={() => setIsUnfreezeOpen(true)}
          disabled={!canUnfreeze}
          variant="outline"
          tooltipMessage={!hasWallet ? noWalletTooltip : genericUnavailableText}
        />
        <ActionButton
          icon={AlertTriangle}
          label={t("applyPenalty", "Apply Penalty")}
          onClick={() => setIsApplyPenaltyOpen(true)}
          disabled={!Number.isFinite(userId)}
          variant="outline"
          tooltipMessage={genericUnavailableText}
        />
        <ActionButton
          icon={Bell}
          label={t("sendNotification", "Send Notification")}
          onClick={() => setIsSendNotificationOpen(true)}
          disabled={!Number.isFinite(userId)}
          variant="outline"
          tooltipMessage={genericUnavailableText}
        />
        {showConvertToSeller && (
          <ActionButton
            icon={Store}
            label={t("convertToSeller", "Convert to Seller")}
            onClick={() => setIsConvertToSellerOpen(true)}
            disabled={!Number.isFinite(userId)}
            variant="default"
            className="bg-blue-600 hover:bg-blue-700 text-white"
            tooltipMessage={genericUnavailableText}
          />
        )}
      </div>

      {/* Convert to Seller Confirmation Modal */}
      {showConvertToSeller && (
        <Dialog
          open={isConvertToSellerOpen}
          onOpenChange={setIsConvertToSellerOpen}
        >
          <DialogContent>
            <DialogHeader>
              <DialogTitle>
                {t("confirmConvertToSellerTitle", "Convert Customer to Seller")}
              </DialogTitle>
            </DialogHeader>
            <div className="py-4">
              <p className="text-sm text-muted-foreground">
                {t(
                  "confirmConvertToSellerDescription",
                  "Are you sure you want to convert this customer to a seller? This action will change their role and cannot be undone.",
                )}
              </p>
            </div>
            <DialogFooter>
              <Button
                variant="outline"
                onClick={() => setIsConvertToSellerOpen(false)}
              >
                {t("cancel", "Cancel")}
              </Button>
              <Button
                onClick={handleConvertToSeller}
                disabled={isLoading}
                className="bg-blue-600 hover:bg-blue-700"
              >
                {isLoading
                  ? t("processing", "Processing...")
                  : t("confirmConvert", "Confirm Convert")}
              </Button>
            </DialogFooter>
          </DialogContent>
        </Dialog>
      )}

      {/* Unfreeze Confirmation Modal */}
      <Dialog open={isUnfreezeOpen} onOpenChange={setIsUnfreezeOpen}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>
              {t("confirmUnfreezeTitle", "Confirm Wallet Unfreeze")}
            </DialogTitle>
          </DialogHeader>
          <div className="py-4">
            <p className="text-sm text-muted-foreground">
              {t(
                "confirmUnfreezeDescription",
                "Are you sure you want to unfreeze this wallet? The customer will be able to perform transactions again.",
              )}
            </p>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setIsUnfreezeOpen(false)}>
              {t("cancel", "Cancel")}
            </Button>
            <Button
              onClick={handleUnfreeze}
              disabled={isLoading}
              className="bg-green-600 hover:bg-green-700"
            >
              {isLoading
                ? t("processing", "Processing...")
                : t("confirmUnfreeze", "Confirm Unfreeze")}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Wallet Modals */}
      {wallet && (
        <>
          <AdjustBalanceModal
            isOpen={isAdjustBalanceOpen}
            onClose={() => setIsAdjustBalanceOpen(false)}
            walletId={wallet.id}
            onSuccess={onSuccess}
          />
          <FreezeWalletModal
            isOpen={isFreezeWalletOpen}
            onClose={() => setIsFreezeWalletOpen(false)}
            walletId={wallet.id}
            onSuccess={onSuccess}
          />
        </>
      )}
      <ApplyPenaltyModal
        isOpen={isApplyPenaltyOpen}
        onClose={() => setIsApplyPenaltyOpen(false)}
        userId={userId}
        onSuccess={onSuccess}
      />
      <SendNotificationModal
        isOpen={isSendNotificationOpen}
        onClose={() => setIsSendNotificationOpen(false)}
        userId={userId}
        userType="customer"
      />
    </div>
  );
}
