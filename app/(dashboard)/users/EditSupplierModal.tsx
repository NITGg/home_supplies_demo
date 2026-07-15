"use client";

import { useState } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { X, Loader2, User as UserIcon, FileText, Store } from "lucide-react";
import toast from "react-hot-toast";
import { isAxiosError } from "axios";
import { cn } from "@/lib/utils";
import {
  fetchSupplierProfile,
  updateSupplierProfile,
  updateSupplierDocuments,
  type UpdateSupplierProfileData,
} from "@/lib/supplier-api";
import UpdateProfileModal from "./suppliers/[userId]/UpdateProfileModal";
import UpdateDocumentsModal from "./suppliers/[userId]/UpdateDocumentsModal";

interface EditSupplierModalProps {
  userId: number;
  userName?: string;
  onClose: () => void;
}

type Tab = "profile" | "documents";

function apiErrorMessage(error: unknown, fallback: string): string {
  if (isAxiosError(error)) {
    const data = error.response?.data as
      | { message?: string; errors?: { message?: string }[] }
      | undefined;
    if (data?.errors?.length && data.errors[0]?.message) {
      return data.errors[0].message;
    }
    return data?.message || fallback;
  }
  return error instanceof Error ? error.message : fallback;
}

export default function EditSupplierModal({
  userId,
  userName,
  onClose,
}: EditSupplierModalProps) {
  const queryClient = useQueryClient();
  const [tab, setTab] = useState<Tab>("profile");

  const {
    data: profile,
    isLoading,
    error,
  } = useQuery({
    queryKey: ["supplier", userId, "profile"],
    queryFn: () => fetchSupplierProfile(userId),
    enabled: !!userId,
  });

  const invalidate = () => {
    queryClient.invalidateQueries({ queryKey: ["supplier", userId] });
    queryClient.invalidateQueries({ queryKey: ["users"] });
  };

  const profileMutation = useMutation({
    mutationFn: (data: UpdateSupplierProfileData) =>
      updateSupplierProfile(userId, data),
    onSuccess: (data) => {
      console.log("[EditSupplierModal] update profile response →", {
        userId,
        data,
      });
      toast.success("Supplier profile updated successfully");
      invalidate();
      onClose();
    },
    onError: (e: unknown) => {
      console.error("[EditSupplierModal] update profile failed →", {
        userId,
        error: isAxiosError(e) ? e.response?.data : e,
      });
      toast.error(apiErrorMessage(e, "Failed to update profile"));
    },
  });

  const documentsMutation = useMutation({
    mutationFn: (data: FormData) => updateSupplierDocuments(userId, data),
    onSuccess: (data) => {
      console.log("[EditSupplierModal] update documents response →", {
        userId,
        data,
      });
      toast.success("Supplier documents updated successfully");
      invalidate();
      onClose();
    },
    onError: (e: unknown) => {
      console.error("[EditSupplierModal] update documents failed →", {
        userId,
        error: isAxiosError(e) ? e.response?.data : e,
      });
      toast.error(apiErrorMessage(e, "Failed to update documents"));
    },
  });

  const tabs: { key: Tab; label: string; icon: React.ReactNode }[] = [
    { key: "profile", label: "Update Profile", icon: <UserIcon size={16} /> },
    { key: "documents", label: "Update Documents", icon: <FileText size={16} /> },
  ];

  return (
    <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
      <div className="bg-white rounded-xl w-full max-w-4xl max-h-[90vh] overflow-y-auto">
        {/* Header */}
        <div className="flex items-center justify-between p-6 border-b border-gray-200 sticky top-0 bg-white z-10">
          <h2 className="text-xl font-semibold text-gray-900 flex items-center gap-2">
            <Store size={20} className="text-orange-600" />
            Edit Supplier
            {userName && (
              <span className="text-base font-normal text-gray-500">
                · {userName}
              </span>
            )}
          </h2>
          <button
            onClick={onClose}
            className="p-2 hover:bg-gray-100 rounded-lg transition"
            disabled={profileMutation.isPending || documentsMutation.isPending}
          >
            <X size={20} />
          </button>
        </div>

        {/* Tabs */}
        <div className="flex border-b border-gray-200 px-6 bg-gray-50 sticky top-[73px] z-10">
          {tabs.map(({ key, label, icon }) => (
            <button
              key={key}
              onClick={() => setTab(key)}
              className={cn(
                "py-3 px-5 text-sm font-medium border-b-2 -mb-px transition-colors flex items-center gap-2",
                tab === key
                  ? "border-indigo-600 text-indigo-600 bg-white"
                  : "border-transparent text-gray-500 hover:text-gray-700",
              )}
            >
              {icon}
              {label}
            </button>
          ))}
        </div>

        {/* Body */}
        {isLoading ? (
          <div className="p-12 flex items-center justify-center">
            <Loader2 size={28} className="animate-spin text-indigo-600" />
          </div>
        ) : error || !profile ? (
          <div className="p-8 text-center">
            <p className="text-red-600">
              Failed to load supplier data. Please check that the supplier API
              is running and try again.
            </p>
          </div>
        ) : (
          <>
            {/* Both forms stay mounted so edits aren't lost when switching tabs */}
            <div className={cn(tab !== "profile" && "hidden")}>
              <UpdateProfileModal
                embedded
                isOpen
                profile={profile}
                onClose={onClose}
                onSubmit={(data) => profileMutation.mutate(data)}
                isLoading={profileMutation.isPending}
              />
            </div>
            <div className={cn(tab !== "documents" && "hidden")}>
              <UpdateDocumentsModal
                embedded
                isOpen
                profile={profile}
                onClose={onClose}
                onSubmit={(data) => documentsMutation.mutate(data)}
                isLoading={documentsMutation.isPending}
              />
            </div>
          </>
        )}
      </div>
    </div>
  );
}
