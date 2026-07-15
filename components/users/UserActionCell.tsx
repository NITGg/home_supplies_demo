"use client";

import { useState } from "react";
// import { useTranslation } from "react-i18next";
import { useToast } from "@/hooks/use-toast";
import { userService } from "@/services/userService";
import { Button } from "@/components/ui/button";
import {
  AlertDialog,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
} from "@/components/ui/alert-dialog";
import { Pencil, Trash2 } from "lucide-react";
// import EditUserModal from "@/pages/UserManagement/EditUserModal";
import { User } from "@/types/user";

/**
 * Mock translation function
 */
const t = (key: string, fallback?: string) => fallback || key;

interface UserActionCellProps {
  readonly userId: number;
  readonly user?: User;
  readonly onRefresh: () => void;
  readonly roles?: any[];
}

export default function UserActionCell({
  userId,
  user,
  onRefresh,
  roles = [],
}: UserActionCellProps) {
  const { toast } = useToast();

  const [isDeleteAlertOpen, setIsDeleteAlertOpen] = useState(false);
  // const [isEditModalOpen, setIsEditModalOpen] = useState(false); // Enable when EditUserModal is uncommented
  const [isDeleting, setIsDeleting] = useState(false);

  const stopRowClick = (event: React.MouseEvent | React.TouchEvent) => {
    event.preventDefault();
    event.stopPropagation();
  };

  const handleDelete = async (archived: boolean) => {
    setIsDeleting(true);
    try {
      await userService.deleteUser(userId, { archived });
      toast({
        title: t("success", "Success"),
        description: archived
          ? t("userArchivedSuccess", "User archived successfully")
          : t("userDeletedSuccess", "User deleted successfully"),
      });
      onRefresh();
      setIsDeleteAlertOpen(false);
    } catch (err: any) {
      toast({
        variant: "destructive",
        title: t("error", "Error"),
        description:
          err?.response?.data?.message ||
          t("failedToDeleteUser", "Failed to delete user"),
      });
    } finally {
      setIsDeleting(false);
      setIsDeleteAlertOpen(false);
    }
  };

  return (
    <>
      <div className="flex items-center justify-end gap-2">
        <Button
          type="button"
          variant="ghost"
          size="icon"
          className="h-8 w-8"
          onClick={(e) => {
            stopRowClick(e);
            // setIsEditModalOpen(true);
          }}
          aria-label={t("edit", "Edit")}
        >
          <Pencil className="h-4 w-4" />
        </Button>

        <Button
          type="button"
          variant="ghost"
          size="icon"
          className="h-8 w-8 text-destructive hover:text-destructive hover:bg-destructive/10"
          onClick={(e) => {
            stopRowClick(e);
            setIsDeleteAlertOpen(true);
          }}
          aria-label={t("delete", "Delete")}
        >
          <Trash2 className="h-4 w-4" />
        </Button>
      </div>

      {/* EditUserModal Placeholder - matches your previous pattern */}
      {/* <EditUserModal
        userId={userId}
        initialUser={user}
        isOpen={isEditModalOpen}
        onClose={() => setIsEditModalOpen(false)}
        onSuccess={() => {
          setIsEditModalOpen(false);
          onRefresh();
        }}
        roles={roles}
      /> */}

      <AlertDialog open={isDeleteAlertOpen} onOpenChange={setIsDeleteAlertOpen}>
        <AlertDialogContent onClick={(e) => e.stopPropagation()}>
          <AlertDialogHeader>
            <AlertDialogTitle>
              {t("deleteUser", "Delete User")}
            </AlertDialogTitle>
            <AlertDialogDescription>
              {t(
                "deleteUserWarning",
                "Choose how you want to delete this user. Permanent delete cannot be undone."
              )}
            </AlertDialogDescription>
          </AlertDialogHeader>
          
          <AlertDialogFooter className="flex-col sm:flex-row gap-2">
            <AlertDialogCancel disabled={isDeleting} className="mt-0">
              {t("cancel", "Cancel")}
            </AlertDialogCancel>
            
            <Button
              variant="outline"
              disabled={isDeleting}
              onClick={() => handleDelete(true)}
            >
              {isDeleting ? t("processing", "...") : t("archive", "Soft Delete")}
            </Button>

            <Button
              variant="destructive"
              disabled={isDeleting}
              onClick={() => handleDelete(false)}
            >
              {isDeleting ? t("processing", "...") : t("deletePermanently", "Hard Delete")}
            </Button>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </>
  );
}