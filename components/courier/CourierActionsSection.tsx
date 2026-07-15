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
import { Input } from "@/components/ui/input";
import {
  FileWarning,
  CheckCircle,
  Ban,
  Wallet,
  Lock,
  Unlock,
  AlertTriangle,
  Bell,
  MapPin,
  Store,
} from "lucide-react";
import {
  getActionAvailability,
  WalletStatus,
} from "@/utils/courierActionRules";
import {
  Tooltip,
  TooltipContent,
  TooltipProvider,
  TooltipTrigger,
} from "@/components/ui/tooltip";

// Local Components
import { AdjustBalanceModal } from "./AdjustBalanceModal";
import { FreezeWalletModal } from "./FreezeWalletModal";
import { ApplyPenaltyModal } from "./ApplyPenaltyModal";
import { SendNotificationModal } from "@/components/shared/SendNotificationModal";

export interface CourierWallet {
  id: number;
  status: WalletStatus;
  balance: number;
}

interface CourierOfficeOption {
  id: number;
  name: string;
}

interface CourierActionsSectionProps {
  courierId: number;
  userId: number;
  isApproved: boolean | null;
  wallet: CourierWallet | null;
  existingCourierOfficeId?: number | null;
  onSuccess: () => void;
  onTrackCourier?: () => void;
}

/**
 * ActionButton sub-component
 */
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

export function CourierActionsSection({
  courierId,
  userId,
  isApproved,
  wallet,
  existingCourierOfficeId,
  onSuccess,
  onTrackCourier,
}: CourierActionsSectionProps) {
  // const { t } = useTranslation();
  const { toast } = useToast();
  const t = (key: string, fallback?: string) => fallback || key;

  // --- States ---
  const [isLoading, setIsLoading] = useState(false);
  const [isApproveOpen, setIsApproveOpen] = useState(false);
  const [isRejectOpen, setIsRejectOpen] = useState(false);
  const [rejectReason, setRejectReason] = useState("");

  const [isAdjustBalanceOpen, setIsAdjustBalanceOpen] = useState(false);
  const [isFreezeWalletOpen, setIsFreezeWalletOpen] = useState(false);
  const [isApplyPenaltyOpen, setIsApplyPenaltyOpen] = useState(false);
  const [isUnfreezeOpen, setIsUnfreezeOpen] = useState(false);
  const [isSendNotificationOpen, setIsSendNotificationOpen] = useState(false);
  const [isAppendToOfficeOpen, setIsAppendToOfficeOpen] = useState(false);

  const [isLoadingCourierOffices, setIsLoadingCourierOffices] = useState(false);
  const [isAppendingToOffice, setIsAppendingToOffice] = useState(false);
  const [courierOfficeId, setCourierOfficeId] = useState("");
  const [courierOffices, setCourierOffices] = useState<CourierOfficeOption[]>(
    [],
  );
  const [removeFromOffice, setRemoveFromOffice] = useState(false);

  const walletStatus = wallet ? wallet.status : null;
  const availability = getActionAvailability(isApproved, walletStatus);
  const genericUnavailableText = t("actionUnavailable", "Action unavailable");

  // --- Handlers ---

  const handleApprove = async () => {
    setIsLoading(true);
    try {
      await axiosInstance.post(`/admin/approval/approve-courier/${courierId}`);
      toast({
        title: t("success", "Success"),
        description: t(
          "courierApproved",
          "Courier has been approved successfully.",
        ),
      });
      setIsApproveOpen(false);
      onSuccess();
    } catch (err: unknown) {
      toast({
        variant: "destructive",
        title: t("error", "Error"),
        description:
          (err as AxiosError<{ message: string }>)?.response?.data?.message ||
          t("failedToApprove", "Failed to approve courier"),
      });
    } finally {
      setIsLoading(false);
    }
  };

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

  const handleReject = async () => {
    if (!rejectReason.trim()) return;
    setIsLoading(true);
    try {
      await axiosInstance.post(`/admin/approval/reject-courier/${courierId}`, {
        reject_reason: rejectReason,
      });
      toast({
        title: t("success", "Success"),
        description: t(
          "courierRejected",
          "Courier has been rejected successfully.",
        ),
      });
      setIsRejectOpen(false);
      setRejectReason("");
      onSuccess();
    } catch (err: unknown) {
      toast({
        variant: "destructive",
        title: t("error", "Error"),
        description:
          (err as AxiosError<{ message: string }>)?.response?.data?.message ||
          t("failedToReject", "Failed to reject courier"),
      });
    } finally {
      setIsLoading(false);
    }
  };

  const loadCourierOffices = async () => {
    setIsLoadingCourierOffices(true);
    try {
      const response = await axiosInstance.get(
        "/admin/courier-office/all-courier-offices",
      );
      const offices = response.data?.data?.couriers;
      if (Array.isArray(offices)) {
        setCourierOffices(
          offices.map((office) => ({
            id: Number(office.id),
            name: office.name ?? String(office.id),
          })),
        );
      }
    } catch (err) {
      toast({
        variant: "destructive",
        title: t("error", "Error"),
        description: t(
          "failedToLoadCourierOffices",
          "Failed to load courier offices",
        ),
      });
    } finally {
      setIsLoadingCourierOffices(false);
    }
  };

  const handleOpenAppendToOfficeModal = async () => {
    setRemoveFromOffice(false);
    setCourierOfficeId("");
    setIsAppendToOfficeOpen(true);
    if (!courierOffices.length) {
      await loadCourierOffices();
    }
  };

  const handleAppendToOffice = async () => {
    if (!removeFromOffice && !courierOfficeId) return;

    setIsAppendingToOffice(true);
    try {
      const requestBody: { courierId: string; courierOfficeId?: string } = {
        courierId: String(courierId),
      };
      if (!removeFromOffice && courierOfficeId) {
        requestBody.courierOfficeId = courierOfficeId;
      }

      await axiosInstance.post(
        "/admin/courier-office/append-courier-to-office",
        requestBody,
      );
      toast({
        title: t("success", "Success"),
        description: removeFromOffice
          ? t("courierRemoved", "Removed from office")
          : t("courierAppended", "Appended to office"),
      });
      setIsAppendToOfficeOpen(false);
      onSuccess();
    } catch (err) {
      toast({
        variant: "destructive",
        title: t("error", "Error"),
        description: t("failedToProcess", "Failed to process assignment"),
      });
    } finally {
      setIsAppendingToOffice(false);
    }
  };

  return (
    <div className="bg-card border rounded-lg shadow-sm overflow-hidden mb-6">
      <div className="px-6 py-4 border-b bg-muted/30">
        <h2 className="font-semibold text-lg">{t("actions", "Actions")}</h2>
      </div>

      <div className="p-6 flex flex-wrap gap-4">
        {/* Core Actions */}
        <ActionButton
          icon={CheckCircle}
          label={t("approve", "Approve")}
          onClick={() => setIsApproveOpen(true)}
          disabled={!availability.canApprove}
          className="bg-green-600 hover:bg-green-700 text-white"
        />
        <ActionButton
          icon={Ban}
          label={t("reject", "Reject")}
          onClick={() => setIsRejectOpen(true)}
          disabled={!availability.canReject}
          variant="destructive"
        />

        <div className="w-px h-10 bg-border mx-2 hidden sm:block"></div>

        {/* Wallet & Notifications */}
        <ActionButton
          icon={Wallet}
          label={t("adjustBalance", "Adjust Balance")}
          onClick={() => setIsAdjustBalanceOpen(true)}
          disabled={!availability.canAdjustBalance}
          variant="outline"
          tooltipMessage={
            wallet === null
              ? t("noWallet", "No wallet associated")
              : genericUnavailableText
          }
        />
        <ActionButton
          icon={Lock}
          label={t("freezeWallet", "Freeze")}
          onClick={() => setIsFreezeWalletOpen(true)}
          disabled={!availability.canFreeze}
          variant="outline"
        />
        <ActionButton
          icon={Unlock}
          label={t("unfreezeWallet", "Unfreeze")}
          onClick={() => setIsUnfreezeOpen(true)}
          disabled={!availability.canUnfreeze}
          variant="outline"
        />
        <ActionButton
          icon={AlertTriangle}
          label={t("applyPenalty", "Penalty")}
          onClick={() => setIsApplyPenaltyOpen(true)}
          disabled={!availability.canApplyPenalty}
          variant="outline"
        />
        <ActionButton
          icon={Bell}
          label={t("notify", "Notify")}
          onClick={() => setIsSendNotificationOpen(true)}
          disabled={!Number.isFinite(userId)}
          variant="outline"
        />
        <ActionButton
          icon={Store}
          label={t("assignOffice", "Assign Office")}
          onClick={handleOpenAppendToOfficeModal}
          disabled={!Number.isFinite(courierId)}
          variant="outline"
        />
        <ActionButton
          icon={MapPin}
          label={t("track", "Track")}
          onClick={() => onTrackCourier?.()}
          disabled={!onTrackCourier}
          variant="outline"
        />
      </div>

      {/* --- Dialogs --- */}

      {/* Approve */}
      <Dialog open={isApproveOpen} onOpenChange={setIsApproveOpen}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>
              {t("confirmApproval", "Confirm Approval")}
            </DialogTitle>
          </DialogHeader>
          <p className="text-sm text-muted-foreground">
            {t("approveWarning", "Are you sure? This grants privileges.")}
          </p>
          <DialogFooter>
            <Button variant="outline" onClick={() => setIsApproveOpen(false)}>
              {t("cancel", "Cancel")}
            </Button>
            <Button
              onClick={handleApprove}
              disabled={isLoading}
              className="bg-green-600 hover:bg-green-700"
            >
              {isLoading
                ? t("approving", "Approving...")
                : t("confirm", "Confirm")}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Reject */}
      <Dialog open={isRejectOpen} onOpenChange={setIsRejectOpen}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>{t("rejectCourier", "Reject Courier")}</DialogTitle>
          </DialogHeader>
          <div className="space-y-2">
            <label className="text-sm font-medium">
              {t("reason", "Reason")} *
            </label>
            <Input
              value={rejectReason}
              onChange={(e) => setRejectReason(e.target.value)}
              required
            />
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setIsRejectOpen(false)}>
              {t("cancel", "Cancel")}
            </Button>
            <Button
              variant="destructive"
              onClick={handleReject}
              disabled={isLoading || !rejectReason.trim()}
            >
              {t("submit", "Reject")}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Unfreeze */}
      <Dialog open={isUnfreezeOpen} onOpenChange={setIsUnfreezeOpen}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>{t("unfreezeWallet", "Unfreeze Wallet")}</DialogTitle>
          </DialogHeader>
          <p className="text-sm text-muted-foreground">
            {t("unfreezeConfirm", "Enable transactions for this courier?")}
          </p>
          <DialogFooter>
            <Button variant="outline" onClick={() => setIsUnfreezeOpen(false)}>
              {t("cancel", "Cancel")}
            </Button>
            <Button
              onClick={handleUnfreeze}
              disabled={isLoading}
              className="bg-green-600"
            >
              {t("confirm", "Unfreeze")}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Office Assignment */}
      <Dialog
        open={isAppendToOfficeOpen}
        onOpenChange={setIsAppendToOfficeOpen}
      >
        <DialogContent>
          <DialogHeader>
            <DialogTitle>
              {t("officeAssignment", "Office Assignment")}
            </DialogTitle>
          </DialogHeader>
          <div className="space-y-4 py-2">
            {existingCourierOfficeId && (
              <div className="flex items-center gap-2">
                <input
                  type="checkbox"
                  id="rm-office"
                  checked={removeFromOffice}
                  onChange={(e) => setRemoveFromOffice(e.target.checked)}
                />
                <label htmlFor="rm-office" className="text-sm font-medium">
                  {t("removeFromCurrent", "Remove from current office")}
                </label>
              </div>
            )}
            {!removeFromOffice && (
              <div className="space-y-2">
                <label className="text-sm font-medium">
                  {t("selectOffice", "Select Office")}
                </label>
                <select
                  value={courierOfficeId}
                  onChange={(e) => setCourierOfficeId(e.target.value)}
                  className="w-full p-2 border rounded-md bg-transparent text-sm"
                  disabled={isLoadingCourierOffices}
                >
                  <option value="">
                    {isLoadingCourierOffices ? "Loading..." : "Select..."}
                  </option>
                  {courierOffices.map((o) => (
                    <option key={o.id} value={o.id}>
                      {o.name}
                    </option>
                  ))}
                </select>
              </div>
            )}
          </div>
          <DialogFooter>
            <Button
              variant="outline"
              onClick={() => setIsAppendToOfficeOpen(false)}
            >
              {t("cancel", "Cancel")}
            </Button>
            <Button
              onClick={handleAppendToOffice}
              disabled={
                isAppendingToOffice || (!removeFromOffice && !courierOfficeId)
              }
            >
              {t("submit", "Save Changes")}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Linked Modals */}
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
        userType="courier"
      />
    </div>
  );
}
