"use client";

import { useState } from "react";
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
} from "@/components/ui/alert-dialog";
import { useToast } from "@/hooks/use-toast";
import axiosInstance from "@/lib/axios";
import type { User } from "@/types/user";

/**
 * Mock translation function
 */
const t = (key: string, fallback?: string) => fallback || key;

interface UserDeleteDialogProps {
  readonly user: User | null;
  readonly open: boolean;
  readonly onOpenChange: (open: boolean) => void;
  readonly onSuccess: () => void;
}

export function UserDeleteDialog({
  user,
  open,
  onOpenChange,
  onSuccess,
}: UserDeleteDialogProps) {
  const { toast } = useToast();
  const [isLoading, setIsLoading] = useState(false);

  const handleDelete = async (e: React.MouseEvent) => {
    if (!user) return;

    // Prevent the default Radix behavior of closing immediately
    // so we can manage the loading state and close manually on success.
    e.preventDefault();
    setIsLoading(true);

    try {
      await axiosInstance.delete(`/users/${user.id}`);

      toast({
        title: t("userDeleted", "User deleted successfully"),
      });

      onSuccess();
      onOpenChange(false);
    } catch (err: any) {
      toast({
        variant: "destructive",
        title: t("deleteFailed", "Failed to delete user"),
        description: err?.response?.data?.message,
      });
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <AlertDialog open={open} onOpenChange={onOpenChange}>
      <AlertDialogContent>
        <AlertDialogHeader>
          <AlertDialogTitle>
            {t("confirmDelete", "Confirm Deletion")}
          </AlertDialogTitle>
          <AlertDialogDescription>
            {t(
              "confirmDeleteUserDesc",
              `Are you sure you want to delete ${user?.full_name || "this user"}? This action cannot be undone.`,
            )}
          </AlertDialogDescription>
        </AlertDialogHeader>
        <AlertDialogFooter>
          <AlertDialogCancel disabled={isLoading}>
            {t("cancel", "Cancel")}
          </AlertDialogCancel>
          <AlertDialogAction
            onClick={handleDelete}
            disabled={isLoading}
            className="bg-destructive text-destructive-foreground hover:bg-destructive/90"
          >
            {isLoading ? t("deleting", "Deleting...") : t("delete", "Delete")}
          </AlertDialogAction>
        </AlertDialogFooter>
      </AlertDialogContent>
    </AlertDialog>
  );
}
