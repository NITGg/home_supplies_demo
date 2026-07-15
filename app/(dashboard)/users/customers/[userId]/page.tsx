"use client";

import { useState } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { useParams, useRouter } from "next/navigation";
import { fetchUser, deleteUser } from "@/lib/users";
import { useT } from "@/contexts/LanguageContext";
import {
  ArrowLeft,
  Loader2,
  User as UserIcon,
  Mail,
  Phone,
  Shield,
  CheckCircle,
  XCircle,
  Calendar,
  MapPin,
  Pencil,
  Trash2,
  MessageSquare,
  PhoneCall,
  Archive,
  DollarSign,
} from "lucide-react";
import { cn } from "@/lib/utils";
import UserWalletSection from "@/components/users/UserWalletSection";
import UserForm from "@/components/users/UserForm";
import SettleBalanceModal from "@/components/users/SettleBalanceModal";
import toast from "react-hot-toast";

export default function CustomerDetailPage() {
  const { t } = useT();
  const router = useRouter();
  const qc = useQueryClient();
  const params = useParams();
  const userId = Number(params.userId);

  const [showEdit, setShowEdit] = useState(false);
  const [deleteMode, setDeleteMode] = useState<"archive" | "hard" | null>(null);
  const [showSettle, setShowSettle] = useState(false);

  const { data: user, isLoading } = useQuery({
    queryKey: ["user", userId, "details"],
    queryFn: () => fetchUser(userId, "role,badge,courier,wallet"),
    enabled: !!userId,
  });

  const archiveMut = useMutation({
    mutationFn: () => deleteUser(userId, true),
    onSuccess: () => {
      toast.success(t("users.userArchived"));
      router.push("/users");
    },
    onError: (e: any) =>
      toast.error(e?.response?.data?.message ?? t("users.deleteError")),
  });
  const hardDeleteMut = useMutation({
    mutationFn: () => deleteUser(userId, false),
    onSuccess: () => {
      toast.success(t("users.userDeleted"));
      router.push("/users");
    },
    onError: (e: any) =>
      toast.error(e?.response?.data?.message ?? t("users.deleteError")),
  });

  if (isLoading) {
    return (
      <div className="p-6 flex items-center justify-center min-h-[400px]">
        <Loader2 className="animate-spin text-indigo-600" size={32} />
      </div>
    );
  }

  if (!user) {
    return (
      <div className="p-6">
        <div className="bg-white rounded-xl border border-gray-200 p-8 text-center">
          <UserIcon size={48} className="text-gray-300 mx-auto mb-4" />
          <h2 className="text-lg font-medium text-gray-900">
            {t("users.notFound")}
          </h2>
          <p className="text-gray-500 mt-2">{t("users.userNotFoundDesc")}</p>
          <button
            onClick={() => router.push("/users")}
            className="mt-4 px-4 py-2 bg-indigo-600 text-white rounded-lg text-sm font-medium hover:bg-indigo-700 transition"
          >
            {t("common.back")}
          </button>
        </div>
      </div>
    );
  }

  return (
    <div className="p-6 space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between flex-wrap gap-4">
        <div className="flex items-center gap-4">
          <button
            onClick={() => router.push("/users")}
            className="p-2 hover:bg-gray-100 rounded-lg transition"
            title={t("common.back")}
          >
            <ArrowLeft size={20} />
          </button>
          <div className="flex items-center gap-3">
            {user.personal_photo ? (
              <img
                src={user.personal_photo}
                alt={user.full_name}
                className="w-12 h-12 rounded-full object-cover border-2 border-gray-200"
              />
            ) : (
              <div className="w-12 h-12 rounded-full bg-indigo-100 flex items-center justify-center border-2 border-gray-200">
                <UserIcon size={24} className="text-indigo-600" />
              </div>
            )}
            <div>
              <h1 className="text-2xl font-bold text-gray-900">
                {user.full_name}
              </h1>
              <p className="text-sm text-gray-500">
                {t("users.customerDetails")}
              </p>
            </div>
          </div>
        </div>

        {/* Action buttons */}
        <div className="flex flex-wrap items-center gap-2">
          {/* Phone call */}
          {user.phone && (
            <a
              href={`tel:${user.phone}`}
              className="flex items-center gap-2 px-4 py-2 bg-green-50 text-green-700 border border-green-200 rounded-xl text-sm font-medium hover:bg-green-100 transition"
              title={t("users.callUser")}
            >
              <PhoneCall size={15} />
              {user.phone}
            </a>
          )}
          {/* Chat */}
          <a
            href={`/chat?userId=${user.id}`}
            className="flex items-center gap-2 px-4 py-2 bg-indigo-50 text-indigo-700 border border-indigo-200 rounded-xl text-sm font-medium hover:bg-indigo-100 transition"
            title={t("users.chatUser")}
          >
            <MessageSquare size={15} />
            {t("users.chatUser")}
          </a>
          {/* Settle Balance */}
          <button
            onClick={() => setShowSettle(true)}
            className="flex items-center gap-2 px-4 py-2 bg-emerald-50 text-emerald-700 border border-emerald-200 rounded-xl text-sm font-medium hover:bg-emerald-100 transition"
            title="Settle Balance"
          >
            <DollarSign size={15} />
            Settle Balance
          </button>
          {/* Edit */}
          <button
            onClick={() => setShowEdit(true)}
            className="flex items-center gap-2 px-4 py-2 bg-white text-gray-700 border border-gray-300 rounded-xl text-sm font-medium hover:bg-gray-50 transition"
          >
            <Pencil size={15} />
            {t("users.editUser")}
          </button>
          {/* Delete dropdown */}
          {deleteMode === null ? (
            <button
              onClick={() => setDeleteMode("archive")}
              className="flex items-center gap-2 px-4 py-2 bg-red-50 text-red-700 border border-red-200 rounded-xl text-sm font-medium hover:bg-red-100 transition"
            >
              <Trash2 size={15} />
              {t("users.deleteUser")}
            </button>
          ) : (
            <div className="flex items-center gap-1 bg-white border border-gray-200 rounded-xl p-1">
              <button
                onClick={() => archiveMut.mutate()}
                disabled={archiveMut.isPending}
                className="flex items-center gap-1.5 px-3 py-1.5 bg-amber-500 text-white rounded-lg text-xs font-medium hover:bg-amber-600 disabled:opacity-60"
              >
                <Archive size={13} /> {t("common.archive")}
              </button>
              <button
                onClick={() => hardDeleteMut.mutate()}
                disabled={hardDeleteMut.isPending}
                className="flex items-center gap-1.5 px-3 py-1.5 bg-red-600 text-white rounded-lg text-xs font-medium hover:bg-red-700 disabled:opacity-60"
              >
                <Trash2 size={13} /> {t("common.deleteForever")}
              </button>
              <button
                onClick={() => setDeleteMode(null)}
                className="px-3 py-1.5 text-gray-500 rounded-lg text-xs hover:bg-gray-100"
              >
                {t("common.cancel")}
              </button>
            </div>
          )}
        </div>
      </div>

      {/* User Information Block */}
      <div className="bg-white rounded-xl border border-gray-200 p-6">
        <h2 className="text-lg font-semibold text-gray-900 mb-4">
          {t("users.userDetails")}
        </h2>
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          {/* ID */}
          <div className="flex items-start gap-3">
            <div className="w-10 h-10 rounded-lg bg-gray-100 flex items-center justify-center shrink-0">
              <span className="text-xs font-bold text-gray-600">ID</span>
            </div>
            <div>
              <p className="text-xs text-gray-500 uppercase tracking-wide">
                User ID
              </p>
              <p className="text-sm font-medium text-gray-900">{user.id}</p>
            </div>
          </div>

          {/* Full Name */}
          <div className="flex items-start gap-3">
            <div className="w-10 h-10 rounded-lg bg-indigo-50 flex items-center justify-center shrink-0">
              <UserIcon size={18} className="text-indigo-600" />
            </div>
            <div>
              <p className="text-xs text-gray-500 uppercase tracking-wide">
                {t("users.fullName")}
              </p>
              <p className="text-sm font-medium text-gray-900">
                {user.full_name}
              </p>
            </div>
          </div>

          {/* Email */}
          <div className="flex items-start gap-3">
            <div className="w-10 h-10 rounded-lg bg-blue-50 flex items-center justify-center shrink-0">
              <Mail size={18} className="text-blue-600" />
            </div>
            <div>
              <p className="text-xs text-gray-500 uppercase tracking-wide">
                {t("users.email")}
              </p>
              <div className="flex items-center gap-1">
                <span className="text-sm font-medium text-gray-900">
                  {user.email || "—"}
                </span>
                {user.is_email_verified && (
                  <CheckCircle size={14} className="text-green-500" />
                )}
              </div>
              <p className="text-xs text-gray-400 mt-0.5">
                {user.is_email_verified
                  ? t("filters.verified")
                  : t("filters.notVerified")}
              </p>
            </div>
          </div>

          {/* Phone */}
          <div className="flex items-start gap-3">
            <div className="w-10 h-10 rounded-lg bg-green-50 flex items-center justify-center shrink-0">
              <Phone size={18} className="text-green-600" />
            </div>
            <div>
              <p className="text-xs text-gray-500 uppercase tracking-wide">
                {t("users.phone")}
              </p>
              <div className="flex items-center gap-1">
                <a
                  href={`tel:${user.phone}`}
                  className="text-sm font-medium text-gray-900 hover:text-green-600"
                >
                  {user.phone}
                </a>
                {user.is_phone_verified && (
                  <CheckCircle size={14} className="text-green-500" />
                )}
              </div>
              <p className="text-xs text-gray-400 mt-0.5">
                {user.is_phone_verified
                  ? t("filters.verified")
                  : t("filters.notVerified")}
              </p>
            </div>
          </div>

          {/* Role */}
          <div className="flex items-start gap-3">
            <div className="w-10 h-10 rounded-lg bg-purple-50 flex items-center justify-center shrink-0">
              <Shield size={18} className="text-purple-600" />
            </div>
            <div>
              <p className="text-xs text-gray-500 uppercase tracking-wide">
                {t("users.role")}
              </p>
              <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-xs font-medium bg-blue-100 text-blue-700">
                <Shield size={10} /> {user.role?.name || "Customer"}
              </span>
            </div>
          </div>

          {/* Badge */}
          <div className="flex items-start gap-3">
            <div className="w-10 h-10 rounded-lg bg-yellow-50 flex items-center justify-center shrink-0">
              <CheckCircle size={18} className="text-yellow-600" />
            </div>
            <div>
              <p className="text-xs text-gray-500 uppercase tracking-wide">
                {t("users.badge")}
              </p>
              <p className="text-sm font-medium text-gray-900">
                {user.badge?.name || "—"}
              </p>
            </div>
          </div>

          {/* Gender */}
          <div className="flex items-start gap-3">
            <div className="w-10 h-10 rounded-lg bg-pink-50 flex items-center justify-center shrink-0">
              <UserIcon size={18} className="text-pink-600" />
            </div>
            <div>
              <p className="text-xs text-gray-500 uppercase tracking-wide">
                {t("users.gender")}
              </p>
              <p className="text-sm font-medium text-gray-900">
                {user.gender === "MALE"
                  ? t("filters.male")
                  : user.gender === "FEMALE"
                    ? t("filters.female")
                    : "—"}
              </p>
            </div>
          </div>

          {/* Status */}
          <div className="flex items-start gap-3">
            <div className="w-10 h-10 rounded-lg bg-gray-100 flex items-center justify-center shrink-0">
              <CheckCircle
                size={18}
                className={user.is_active ? "text-green-600" : "text-red-600"}
              />
            </div>
            <div>
              <p className="text-xs text-gray-500 uppercase tracking-wide">
                {t("common.status")}
              </p>
              <span
                className={cn(
                  "inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-xs font-medium",
                  user.is_active
                    ? "bg-green-100 text-green-700"
                    : "bg-red-100 text-red-700",
                )}
              >
                {user.is_active ? (
                  <CheckCircle size={10} />
                ) : (
                  <XCircle size={10} />
                )}
                {user.is_active ? t("common.active") : t("common.inactive")}
              </span>
            </div>
          </div>

          {/* Referral Code */}
          <div className="flex items-start gap-3">
            <div className="w-10 h-10 rounded-lg bg-orange-50 flex items-center justify-center shrink-0">
              <MapPin size={18} className="text-orange-600" />
            </div>
            <div>
              <p className="text-xs text-gray-500 uppercase tracking-wide">
                {t("users.referralCode")}
              </p>
              <p className="text-sm font-medium text-gray-900">
                {user.referral_code || "—"}
              </p>
            </div>
          </div>

          {/* Language */}
          <div className="flex items-start gap-3">
            <div className="w-10 h-10 rounded-lg bg-cyan-50 flex items-center justify-center shrink-0">
              <span className="text-sm font-bold text-cyan-600">LANG</span>
            </div>
            <div>
              <p className="text-xs text-gray-500 uppercase tracking-wide">
                {t("users.language")}
              </p>
              <p className="text-sm font-medium text-gray-900">
                {user.lang || "—"}
              </p>
            </div>
          </div>

          {/* Created At */}
          <div className="flex items-start gap-3">
            <div className="w-10 h-10 rounded-lg bg-gray-100 flex items-center justify-center shrink-0">
              <Calendar size={18} className="text-gray-600" />
            </div>
            <div>
              <p className="text-xs text-gray-500 uppercase tracking-wide">
                {t("users.joined")}
              </p>
              <p className="text-sm font-medium text-gray-900">
                {new Date(user.created_at).toLocaleDateString()}
              </p>
            </div>
          </div>

          {/* Updated At */}
          <div className="flex items-start gap-3">
            <div className="w-10 h-10 rounded-lg bg-gray-100 flex items-center justify-center shrink-0">
              <Calendar size={18} className="text-gray-600" />
            </div>
            <div>
              <p className="text-xs text-gray-500 uppercase tracking-wide">
                {t("users.updated")}
              </p>
              <p className="text-sm font-medium text-gray-900">
                {user.updated_at
                  ? new Date(user.updated_at).toLocaleDateString()
                  : "—"}
              </p>
            </div>
          </div>
        </div>
      </div>

      {/* Wallet Section */}
      <UserWalletSection userId={userId} />

      {/* Edit modal */}
      {showEdit && (
        <UserForm
          user={user}
          onClose={() => {
            setShowEdit(false);
            qc.invalidateQueries({ queryKey: ["user", userId, "details"] });
          }}
        />
      )}

      {/* Settle Balance modal */}
      {showSettle && (
        <SettleBalanceModal
          userId={userId}
          userName={user.full_name}
          onClose={() => setShowSettle(false)}
        />
      )}
    </div>
  );
}
