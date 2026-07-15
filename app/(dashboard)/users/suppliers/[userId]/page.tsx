"use client";

import { useState } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { useParams, useRouter } from "next/navigation";
import {
  fetchUser,
  fetchSupplier,
  fetchSupplierProducts,
  approveSupplier,
  rejectSupplier,
  resetSupplierProductPrice,
  type SupplierDetail,
  type SupplierProductItem,
  type WorkingHours,
} from "@/lib/users";
import {
  fetchSupplierProfile,
  fetchSupplierBadgeProgress,
  updateSupplierProfile,
  updateSupplierDocuments,
  type SupplierProfileUser,
  type Badge,
} from "@/lib/supplier-api";
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
  Store,
  Package,
  CreditCard,
  Wallet,
  Building,
  FileText,
  DollarSign,
  Gift,
  Snowflake,
  Edit,
  Upload,
  Clock,
  Award,
  Image,
  X,
  Navigation,
  CheckSquare,
  CheckCircle2,
  RefreshCw,
  Pencil,
  ExternalLink,
  BarChart2,
  Tag,
  Star,
  TrendingUp,
  ShoppingBag,
  Plus,
  Eye,
} from "lucide-react";
import toast from "react-hot-toast";
import { cn } from "@/lib/utils";
import UpdateProfileModal from "./UpdateProfileModal";
import UpdateDocumentsModal from "./UpdateDocumentsModal";
import SettleBalanceModal from "@/components/users/SettleBalanceModal";
import UserWalletSection from "@/components/users/UserWalletSection";

export default function SupplierUserDetailPage() {
  const { t } = useT();
  const router = useRouter();
  const params = useParams();
  const userId = Number(params.userId);
  const queryClient = useQueryClient();

  const [isUpdateProfileOpen, setIsUpdateProfileOpen] = useState(false);
  const [isUpdateDocumentsOpen, setIsUpdateDocumentsOpen] = useState(false);
  const [showSettle, setShowSettle] = useState(false);
  const [detailTab, setDetailTab] = useState<"details" | "products">("details");
  const [confirming, setConfirming] = useState<{ id: number; action: "approve" | "reject" } | null>(null);

  const { data: user, isLoading: userLoading } = useQuery({
    queryKey: ["user", userId, "details"],
    queryFn: () => fetchUser(userId, "role,badge,courier,wallet"),
    enabled: !!userId,
  });

  const {
    data: supplierProfile,
    isLoading: profileLoading,
    error: profileError,
  } = useQuery({
    queryKey: ["supplier", userId, "profile"],
    queryFn: () => fetchSupplierProfile(userId),
    enabled: !!userId,
  });

  const {
    data: badgeProgress,
    isLoading: badgeLoading,
    error: badgeError,
  } = useQuery({
    queryKey: ["supplier", userId, "badge-progress"],
    queryFn: () => fetchSupplierBadgeProgress(userId),
    enabled: !!userId,
  });

  const updateProfileMutation = useMutation({
    mutationFn: (data: Parameters<typeof updateSupplierProfile>[1]) =>
      updateSupplierProfile(userId, data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["supplier", userId] });
      setIsUpdateProfileOpen(false);
    },
  });

  const updateDocumentsMutation = useMutation({
    mutationFn: (data: FormData) => updateSupplierDocuments(userId, data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["supplier", userId] });
      setIsUpdateDocumentsOpen(false);
    },
  });

  const supplierId = supplierProfile?.supplier?.id;

  const { data: supplierDetail, isLoading: detailLoading } = useQuery({
    queryKey: ["supplier", supplierId],
    queryFn: () => fetchSupplier(supplierId!),
    enabled: !!supplierId,
  });

  const { data: supplierProducts = [], isLoading: productsLoading } = useQuery({
    queryKey: ["supplier-products", supplierId],
    queryFn: () => fetchSupplierProducts(supplierId!),
    enabled: !!supplierId && detailTab === "products",
  });

  const approveMut = useMutation({
    mutationFn: (id: number) => approveSupplier(id),
    onSuccess: () => {
      toast.success(t("suppliers.approveSuccess"));
      queryClient.invalidateQueries({ queryKey: ["supplier", supplierId] });
      queryClient.invalidateQueries({ queryKey: ["supplier", userId, "profile"] });
      setConfirming(null);
    },
    onError: () => toast.error("Failed to approve"),
  });

  const rejectMut = useMutation({
    mutationFn: (id: number) => rejectSupplier(id),
    onSuccess: () => {
      toast.success(t("suppliers.rejectSuccess"));
      queryClient.invalidateQueries({ queryKey: ["supplier", supplierId] });
      queryClient.invalidateQueries({ queryKey: ["supplier", userId, "profile"] });
      setConfirming(null);
    },
    onError: () => toast.error("Failed to reject"),
  });

  if (userLoading) {
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
            <div className="w-12 h-12 rounded-full bg-orange-100 flex items-center justify-center border-2 border-gray-200">
              <Store size={24} className="text-orange-600" />
            </div>
          )}
          <div>
            <h1 className="text-2xl font-bold text-gray-900">
              {user.full_name}
            </h1>
            <p className="text-sm text-gray-500">Supplier Details</p>
          </div>
        </div>
      </div>

      {/* Actions Block */}
      <div className="bg-white rounded-xl border border-gray-200 p-6">
        <h2 className="text-lg font-semibold text-gray-900 mb-4">Actions</h2>
        <div className="flex flex-wrap items-center gap-3">
          <button
            onClick={() => setIsUpdateProfileOpen(true)}
            className="flex items-center gap-2 px-4 py-2 bg-indigo-600 hover:bg-indigo-700 text-white rounded-lg text-sm font-medium transition"
          >
            <UserIcon size={16} />
            Update Profile
          </button>
          <button
            onClick={() => setIsUpdateDocumentsOpen(true)}
            className="flex items-center gap-2 px-4 py-2 bg-orange-600 hover:bg-orange-700 text-white rounded-lg text-sm font-medium transition"
          >
            <FileText size={16} />
            Update Documents
          </button>
          <button
            onClick={() => setShowSettle(true)}
            className="flex items-center gap-2 px-4 py-2 bg-emerald-600 hover:bg-emerald-700 text-white rounded-lg text-sm font-medium transition"
          >
            <DollarSign size={16} />
            Settle Balance
          </button>

          {supplierProfile?.supplier && (
            <>
              {!supplierProfile.supplier.is_approved && (
                <button
                  onClick={() => setConfirming({ id: supplierProfile.supplier.id, action: "approve" })}
                  className="flex items-center gap-2 px-4 py-2 bg-green-600 hover:bg-green-700 text-white rounded-lg text-sm font-medium transition"
                >
                  <CheckCircle2 size={16} /> {t("suppliers.approve")}
                </button>
              )}
              <button
                onClick={() => setConfirming({ id: supplierProfile.supplier.id, action: "reject" })}
                className="flex items-center gap-2 px-4 py-2 border border-red-200 text-red-600 hover:bg-red-50 rounded-lg text-sm font-medium transition"
              >
                <XCircle size={16} /> {t("suppliers.reject")}
              </button>
            </>
          )}
        </div>

        {confirming && (
          <div className="mt-4 flex items-center gap-3 p-4 bg-gray-50 border border-gray-200 rounded-lg">
            <span className="text-sm text-gray-700">
              {confirming.action === "approve" ? t("suppliers.approveConfirm") : t("suppliers.rejectConfirm")}
            </span>
            <button
              disabled={approveMut.isPending || rejectMut.isPending}
              onClick={() => {
                if (confirming.action === "approve") approveMut.mutate(confirming.id);
                else rejectMut.mutate(confirming.id);
              }}
              className={cn(
                "px-4 py-2 text-sm font-medium text-white rounded-lg transition disabled:opacity-50",
                confirming.action === "approve" ? "bg-green-600 hover:bg-green-700" : "bg-red-600 hover:bg-red-700"
              )}>
              {t("common.yes")}
            </button>
            <button onClick={() => setConfirming(null)} className="px-4 py-2 text-sm font-medium border border-gray-300 rounded-lg hover:bg-gray-50">
              {t("common.cancel")}
            </button>
          </div>
        )}
      </div>

      {/* User Information Block */}
      <div className="bg-white rounded-xl border border-gray-200 p-6">
        <h2 className="text-lg font-semibold text-gray-900 mb-4">
          User Information
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
                <span className="text-sm font-medium text-gray-900">
                  {user.phone}
                </span>
                {user.is_phone_verified && (
                  <CheckCircle size={14} className="text-green-500" />
                )}
              </div>
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
              <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-xs font-medium bg-orange-100 text-orange-700">
                <Store size={10} />
                {user.role?.name || "Supplier"}
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

      {/* Supplier Information Section */}
      {profileError && (
        <div className="bg-white rounded-xl border border-gray-200 p-6">
          <h2 className="text-lg font-semibold text-gray-900 mb-4">
            Supplier Information
          </h2>
          <p className="text-red-600">
            Failed to load supplier data. Please check if supplier API is
            running.
          </p>
        </div>
      )}
      {!profileError && supplierProfile?.supplier && (
        <div className="bg-white rounded-xl border border-gray-200 p-6">
          <h2 className="text-lg font-semibold text-gray-900 mb-4">
            Supplier Information
          </h2>
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            {/* Supplier ID */}
            <div className="flex items-start gap-3">
              <div className="w-10 h-10 rounded-lg bg-gray-100 flex items-center justify-center shrink-0">
                <span className="text-xs font-bold text-gray-600">SID</span>
              </div>
              <div>
                <p className="text-xs text-gray-500 uppercase tracking-wide">
                  Supplier ID
                </p>
                <p className="text-sm font-medium text-gray-900">
                  {supplierProfile.supplier.id}
                </p>
              </div>
            </div>

            {/* User ID */}
            <div className="flex items-start gap-3">
              <div className="w-10 h-10 rounded-lg bg-gray-100 flex items-center justify-center shrink-0">
                <span className="text-xs font-bold text-gray-600">UID</span>
              </div>
              <div>
                <p className="text-xs text-gray-500 uppercase tracking-wide">
                  User ID
                </p>
                <p className="text-sm font-medium text-gray-900">
                  {supplierProfile.supplier.user_id}
                </p>
              </div>
            </div>

            {/* Supplier Type ID */}
            <div className="flex items-start gap-3">
              <div className="w-10 h-10 rounded-lg bg-blue-50 flex items-center justify-center shrink-0">
                <Store size={18} className="text-blue-600" />
              </div>
              <div>
                <p className="text-xs text-gray-500 uppercase tracking-wide">
                  Supplier Type ID
                </p>
                <p className="text-sm font-medium text-gray-900">
                  {supplierProfile.supplier.type_id}
                </p>
              </div>
            </div>

            {/* National ID */}
            <div className="flex items-start gap-3">
              <div className="w-10 h-10 rounded-lg bg-gray-100 flex items-center justify-center shrink-0">
                <span className="text-xs font-bold text-gray-600">ID</span>
              </div>
              <div>
                <p className="text-xs text-gray-500 uppercase tracking-wide">
                  National ID Number
                </p>
                <p className="text-sm font-medium text-gray-900">
                  {supplierProfile.supplier.national_id_number || "—"}
                </p>
              </div>
            </div>

            {/* Tax Card */}
            <div className="flex items-start gap-3">
              <div className="w-10 h-10 rounded-lg bg-orange-50 flex items-center justify-center shrink-0">
                <FileText size={18} className="text-orange-600" />
              </div>
              <div>
                <p className="text-xs text-gray-500 uppercase tracking-wide">
                  Tax Card
                </p>
                <p className="text-sm font-medium text-gray-900">
                  {supplierProfile.supplier.tax_card || "—"}
                </p>
              </div>
            </div>

            {/* Commercial Register */}
            <div className="flex items-start gap-3">
              <div className="w-10 h-10 rounded-lg bg-purple-50 flex items-center justify-center shrink-0">
                <Building size={18} className="text-purple-600" />
              </div>
              <div>
                <p className="text-xs text-gray-500 uppercase tracking-wide">
                  Commercial Register
                </p>
                <p className="text-sm font-medium text-gray-900">
                  {supplierProfile.supplier.commercial_register || "—"}
                </p>
              </div>
            </div>

            {/* Synonyms */}
            <div className="flex items-start gap-3">
              <div className="w-10 h-10 rounded-lg bg-cyan-50 flex items-center justify-center shrink-0">
                <span className="text-sm font-bold text-cyan-600">SYN</span>
              </div>
              <div>
                <p className="text-xs text-gray-500 uppercase tracking-wide">
                  Synonyms
                </p>
                <p className="text-sm font-medium text-gray-900">
                  {supplierProfile.supplier.synonyms || "—"}
                </p>
              </div>
            </div>

            {/* Min Price For One Order */}
            <div className="flex items-start gap-3">
              <div className="w-10 h-10 rounded-lg bg-emerald-50 flex items-center justify-center shrink-0">
                <DollarSign size={18} className="text-emerald-600" />
              </div>
              <div>
                <p className="text-xs text-gray-500 uppercase tracking-wide">
                  Min Price For One Order
                </p>
                <p className="text-sm font-medium text-gray-900">
                  {supplierProfile.supplier.min_price_for_one_order != null
                    ? `${supplierProfile.supplier.min_price_for_one_order / 100} EGP`
                    : "—"}
                </p>
              </div>
            </div>

            {/* Max Price For One Order */}
            <div className="flex items-start gap-3">
              <div className="w-10 h-10 rounded-lg bg-emerald-50 flex items-center justify-center shrink-0">
                <DollarSign size={18} className="text-emerald-600" />
              </div>
              <div>
                <p className="text-xs text-gray-500 uppercase tracking-wide">
                  Max Price For One Order
                </p>
                <p className="text-sm font-medium text-gray-900">
                  {supplierProfile.supplier.max_price_for_one_order != null
                    ? `${supplierProfile.supplier.max_price_for_one_order / 100} EGP`
                    : "—"}
                </p>
              </div>
            </div>

            {/* Shopping Min Price For One Order */}
            <div className="flex items-start gap-3">
              <div className="w-10 h-10 rounded-lg bg-emerald-50 flex items-center justify-center shrink-0">
                <DollarSign size={18} className="text-emerald-600" />
              </div>
              <div>
                <p className="text-xs text-gray-500 uppercase tracking-wide">
                  Shopping Min Price For One Order
                </p>
                <p className="text-sm font-medium text-gray-900">
                  {supplierProfile.supplier.shopping_min_price_for_one_order !=
                  null
                    ? `${supplierProfile.supplier.shopping_min_price_for_one_order / 100} EGP`
                    : "—"}
                </p>
              </div>
            </div>

            {/* Shopping Max Price For One Order */}
            <div className="flex items-start gap-3">
              <div className="w-10 h-10 rounded-lg bg-emerald-50 flex items-center justify-center shrink-0">
                <DollarSign size={18} className="text-emerald-600" />
              </div>
              <div>
                <p className="text-xs text-gray-500 uppercase tracking-wide">
                  Shopping Max Price For One Order
                </p>
                <p className="text-sm font-medium text-gray-900">
                  {supplierProfile.supplier.shopping_max_price_for_one_order !=
                  null
                    ? `${supplierProfile.supplier.shopping_max_price_for_one_order / 100} EGP`
                    : "—"}
                </p>
              </div>
            </div>

            {/* Shopping Budget Fee */}
            <div className="flex items-start gap-3">
              <div className="w-10 h-10 rounded-lg bg-emerald-50 flex items-center justify-center shrink-0">
                <DollarSign size={18} className="text-emerald-600" />
              </div>
              <div>
                <p className="text-xs text-gray-500 uppercase tracking-wide">
                  Shopping Budget Fee
                </p>
                <p className="text-sm font-medium text-gray-900">
                  {supplierProfile.supplier.shopping_budget_fee != null
                    ? `${supplierProfile.supplier.shopping_budget_fee}%`
                    : "—"}
                </p>
              </div>
            </div>

            {/* Approval Status */}
            <div className="flex items-start gap-3">
              <div className="w-10 h-10 rounded-lg bg-gray-100 flex items-center justify-center shrink-0">
                <CheckCircle
                  size={18}
                  className={
                    supplierProfile.supplier.is_approved
                      ? "text-green-600"
                      : "text-red-600"
                  }
                />
              </div>
              <div>
                <p className="text-xs text-gray-500 uppercase tracking-wide">
                  Approval Status
                </p>
                <span
                  className={cn(
                    "inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-xs font-medium",
                    supplierProfile.supplier.is_approved
                      ? "bg-green-100 text-green-700"
                      : "bg-red-100 text-red-700",
                  )}
                >
                  {supplierProfile.supplier.is_approved ? (
                    <>
                      <CheckCircle size={10} />
                      Approved
                    </>
                  ) : (
                    <>
                      <XCircle size={10} />
                      Not Approved
                    </>
                  )}
                </span>
              </div>
            </div>

            {/* Supplier Created At */}
            <div className="flex items-start gap-3">
              <div className="w-10 h-10 rounded-lg bg-gray-100 flex items-center justify-center shrink-0">
                <Calendar size={18} className="text-gray-600" />
              </div>
              <div>
                <p className="text-xs text-gray-500 uppercase tracking-wide">
                  Supplier Created
                </p>
                <p className="text-sm font-medium text-gray-900">
                  {new Date(
                    supplierProfile.supplier.created_at,
                  ).toLocaleDateString()}
                </p>
              </div>
            </div>

            {/* Supplier Updated At */}
            <div className="flex items-start gap-3">
              <div className="w-10 h-10 rounded-lg bg-gray-100 flex items-center justify-center shrink-0">
                <Calendar size={18} className="text-gray-600" />
              </div>
              <div>
                <p className="text-xs text-gray-500 uppercase tracking-wide">
                  Supplier Updated
                </p>
                <p className="text-sm font-medium text-gray-900">
                  {new Date(
                    supplierProfile.supplier.updated_at,
                  ).toLocaleDateString()}
                </p>
              </div>
            </div>

            {/* Address */}
            {supplierProfile.supplier.addresses?.[0] && (
              <>
                <div className="flex items-start gap-3">
                  <div className="w-10 h-10 rounded-lg bg-indigo-50 flex items-center justify-center shrink-0">
                    <MapPin size={18} className="text-indigo-600" />
                  </div>
                  <div>
                    <p className="text-xs text-gray-500 uppercase tracking-wide">
                      Address
                    </p>
                    <p className="text-sm font-medium text-gray-900">
                      {supplierProfile.supplier.addresses[0].address_line_1}
                      {supplierProfile.supplier.addresses[0].address_line_2 &&
                        `, ${supplierProfile.supplier.addresses[0].address_line_2}`}
                    </p>
                    <p className="text-xs text-gray-500">
                      {supplierProfile.supplier.addresses[0].city},{" "}
                      {supplierProfile.supplier.addresses[0].state}
                    </p>
                  </div>
                </div>

                <div className="flex items-start gap-3">
                  <div className="w-10 h-10 rounded-lg bg-gray-100 flex items-center justify-center shrink-0">
                    <Navigation size={18} className="text-gray-600" />
                  </div>
                  <div>
                    <p className="text-xs text-gray-500 uppercase tracking-wide">
                      Coordinates
                    </p>
                    <p className="text-sm font-medium text-gray-900">
                      {supplierProfile.supplier.addresses[0].latitude},{" "}
                      {supplierProfile.supplier.addresses[0].longitude}
                    </p>
                  </div>
                </div>

                <div className="flex items-start gap-3">
                  <div className="w-10 h-10 rounded-lg bg-teal-50 flex items-center justify-center shrink-0">
                    <Clock size={18} className="text-teal-600" />
                  </div>
                  <div>
                    <p className="text-xs text-gray-500 uppercase tracking-wide">
                      Timezone
                    </p>
                    <p className="text-sm font-medium text-gray-900">
                      {supplierProfile.supplier.addresses[0].working_hours
                        ?.timezone || "—"}
                    </p>
                  </div>
                </div>

                {/* Google Map Link */}
                {supplierProfile.supplier.addresses[0].google_map_link && (
                  <div className="flex items-start gap-3 md:col-span-2 lg:col-span-3">
                    <div className="w-10 h-10 rounded-lg bg-green-50 flex items-center justify-center shrink-0">
                      <Navigation size={18} className="text-green-600" />
                    </div>
                    <div>
                      <p className="text-xs text-gray-500 uppercase tracking-wide">
                        Google Map
                      </p>
                      <a
                        href={
                          supplierProfile.supplier.addresses[0].google_map_link
                        }
                        target="_blank"
                        rel="noopener noreferrer"
                        className="text-sm font-medium text-indigo-600 hover:underline"
                      >
                        View on Map
                      </a>
                    </div>
                  </div>
                )}
              </>
            )}

            {/* Document Photos Section */}
            {(supplierProfile.supplier.national_id_photo_front ||
              supplierProfile.supplier.national_id_photo_back ||
              supplierProfile.supplier.supplier_criminal_record) && (
              <div className="md:col-span-2 lg:col-span-3 mt-4">
                <h3 className="text-sm font-medium text-gray-900 mb-3">
                  Documents
                </h3>
                <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
                  {/* National ID Front */}
                  {supplierProfile.supplier.national_id_photo_front && (
                    <div className="space-y-2">
                      <p className="text-xs text-gray-500 uppercase tracking-wide">
                        National ID Front
                      </p>
                      <a
                        href={supplierProfile.supplier.national_id_photo_front}
                        target="_blank"
                        rel="noopener noreferrer"
                        className="block relative group"
                      >
                        <img
                          src={supplierProfile.supplier.national_id_photo_front}
                          alt="National ID Front"
                          className="w-full h-32 object-cover rounded-lg border border-gray-200"
                        />
                        <div className="absolute inset-0 bg-black/50 opacity-0 group-hover:opacity-100 transition rounded-lg flex items-center justify-center">
                          <span className="text-white text-sm font-medium">
                            View
                          </span>
                        </div>
                      </a>
                    </div>
                  )}

                  {/* National ID Back */}
                  {supplierProfile.supplier.national_id_photo_back && (
                    <div className="space-y-2">
                      <p className="text-xs text-gray-500 uppercase tracking-wide">
                        National ID Back
                      </p>
                      <a
                        href={supplierProfile.supplier.national_id_photo_back}
                        target="_blank"
                        rel="noopener noreferrer"
                        className="block relative group"
                      >
                        <img
                          src={supplierProfile.supplier.national_id_photo_back}
                          alt="National ID Back"
                          className="w-full h-32 object-cover rounded-lg border border-gray-200"
                        />
                        <div className="absolute inset-0 bg-black/50 opacity-0 group-hover:opacity-100 transition rounded-lg flex items-center justify-center">
                          <span className="text-white text-sm font-medium">
                            View
                          </span>
                        </div>
                      </a>
                    </div>
                  )}

                  {/* Criminal Record */}
                  {supplierProfile.supplier.supplier_criminal_record && (
                    <div className="space-y-2">
                      <p className="text-xs text-gray-500 uppercase tracking-wide">
                        Criminal Record
                      </p>
                      <a
                        href={supplierProfile.supplier.supplier_criminal_record}
                        target="_blank"
                        rel="noopener noreferrer"
                        className="block relative group"
                      >
                        <img
                          src={
                            supplierProfile.supplier.supplier_criminal_record
                          }
                          alt="Criminal Record"
                          className="w-full h-32 object-cover rounded-lg border border-gray-200"
                        />
                        <div className="absolute inset-0 bg-black/50 opacity-0 group-hover:opacity-100 transition rounded-lg flex items-center justify-center">
                          <span className="text-white text-sm font-medium">
                            View
                          </span>
                        </div>
                      </a>
                    </div>
                  )}
                </div>
              </div>
            )}

            {/* Working Hours */}
            {supplierProfile.supplier.addresses?.[0]?.working_hours?.days && (
              <div className="md:col-span-2 lg:col-span-3 mt-4">
                <h3 className="text-sm font-medium text-gray-900 mb-3">
                  Working Hours
                </h3>
                <div className="grid grid-cols-2 md:grid-cols-4 lg:grid-cols-7 gap-2">
                  {Object.entries(
                    supplierProfile.supplier.addresses[0].working_hours.days,
                  ).map(([dayIndex, dayData]) => {
                    const dayNames = [
                      "Sun",
                      "Mon",
                      "Tue",
                      "Wed",
                      "Thu",
                      "Fri",
                      "Sat",
                    ];
                    return (
                      <div
                        key={dayIndex}
                        className={cn(
                          "p-2 rounded-lg border text-center",
                          dayData.is_closed
                            ? "bg-gray-50 border-gray-200"
                            : "bg-green-50 border-green-200",
                        )}
                      >
                        <p className="text-xs font-medium text-gray-700">
                          {dayNames[parseInt(dayIndex)]}
                        </p>
                        {dayData.is_closed ? (
                          <p className="text-xs text-gray-500">Closed</p>
                        ) : (
                          <div className="space-y-0.5">
                            {dayData.slots.map((slot, idx) => (
                              <p key={idx} className="text-xs text-green-700">
                                {slot.open} - {slot.close}
                              </p>
                            ))}
                          </div>
                        )}
                      </div>
                    );
                  })}
                </div>
              </div>
            )}
          </div>
        </div>
      )}

      {/* Badge Progress Section */}
      {badgeError && (
        <div className="bg-white rounded-xl border border-gray-200 p-6">
          <h2 className="text-lg font-semibold text-gray-900 mb-4">
            Badge Progress
          </h2>
          <p className="text-red-600">
            Failed to load badge progress. Please check if supplier API is
            running.
          </p>
        </div>
      )}
      {!badgeError && badgeProgress && (
        <div className="bg-white rounded-xl border border-gray-200 p-6">
          <h2 className="text-lg font-semibold text-gray-900 mb-4">
            Badge Progress
          </h2>

          {/* Current Badge */}
          {badgeProgress.current_badge && (
            <div className="mb-6 p-4 bg-linear-to-r from-indigo-50 to-purple-50 rounded-lg border border-indigo-100">
              <div className="flex items-center gap-4">
                {badgeProgress.current_badge.image && (
                  <img
                    src={badgeProgress.current_badge.image}
                    alt={badgeProgress.current_badge.name}
                    className="w-16 h-16 rounded-full object-cover border-2 border-indigo-200"
                  />
                )}
                <div>
                  <p className="text-xs text-indigo-600 font-medium uppercase tracking-wide">
                    Current Badge
                  </p>
                  <p className="text-lg font-bold text-gray-900">
                    {badgeProgress.current_badge.name}
                  </p>
                  <p className="text-sm text-gray-600">
                    {badgeProgress.current_badge.name_ar}
                  </p>
                  <p className="text-xs text-gray-500 mt-1">
                    {badgeProgress.current_badge.description}
                  </p>
                </div>
              </div>
            </div>
          )}

          {/* All Badges */}
          <div className="space-y-3">
            <p className="text-sm font-medium text-gray-700 mb-2">
              Available Badges
            </p>
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-3">
              {badgeProgress.all_badges?.map((badge) => (
                <div
                  key={badge.id}
                  className={cn(
                    "p-3 rounded-lg border transition",
                    badge.id === badgeProgress.current_badge?.id
                      ? "bg-indigo-50 border-indigo-200 ring-1 ring-indigo-300"
                      : "bg-gray-50 border-gray-200 hover:bg-gray-100",
                  )}
                >
                  <div className="flex items-center gap-3">
                    {badge.image ? (
                      <img
                        src={badge.image}
                        alt={badge.name}
                        className="w-10 h-10 rounded-full object-cover"
                      />
                    ) : (
                      <div className="w-10 h-10 rounded-full bg-gray-200 flex items-center justify-center">
                        <Award size={20} className="text-gray-500" />
                      </div>
                    )}
                    <div className="flex-1 min-w-0">
                      <p className="text-sm font-medium text-gray-900 truncate">
                        {badge.name}
                      </p>
                      <p className="text-xs text-gray-500 truncate">
                        {badge.name_ar}
                      </p>
                      <p className="text-xs text-gray-400 mt-0.5">
                        {badge.min_count} -{" "}
                        {badge.max_count === 999999 ? "∞" : badge.max_count}
                      </p>
                    </div>
                    {badge.id === badgeProgress.current_badge?.id && (
                      <CheckCircle
                        size={16}
                        className="text-indigo-600 shrink-0"
                      />
                    )}
                  </div>
                </div>
              ))}
            </div>
          </div>
        </div>
      )}

      {/* Detailed Supplier Information Tabs */}
      {supplierId && (
        <div className="bg-white rounded-xl border border-gray-200 overflow-hidden">
          <div className="flex border-b border-gray-200 px-6 bg-gray-50">
            {(["details", "products"] as const).map(tab => (
              <button
                key={tab}
                onClick={() => setDetailTab(tab)}
                className={cn(
                  "py-4 px-6 text-sm font-medium border-b-2 -mb-px transition-colors",
                  detailTab === tab
                    ? "border-indigo-600 text-indigo-600 bg-white"
                    : "border-transparent text-gray-500 hover:text-gray-700"
                )}>
                {tab === "details" ? t("suppliers.tabDetails") : (
                  <span className="flex items-center gap-2"><ShoppingBag size={16} />{t("suppliers.tabProducts")}</span>
                )}
              </button>
            ))}
          </div>

          {detailLoading ? (
            <div className="p-8 flex items-center justify-center text-gray-400">{t("common.loading")}</div>
          ) : supplierDetail ? (
            <div>
              {detailTab === "products" ? (
                <div className="p-6 space-y-4">
                  {productsLoading ? (
                    <div className="text-center py-16 text-gray-400">{t("common.loading")}</div>
                  ) : supplierProducts.length === 0 ? (
                    <div className="text-center py-16 border-2 border-dashed border-gray-200 rounded-2xl">
                      <ShoppingBag size={32} className="text-gray-300 mx-auto mb-3" />
                      <p className="text-gray-400 text-sm">{t("suppliers.noProducts")}</p>
                    </div>
                  ) : (
                    supplierProducts.map(sp => <SupplierProductCard key={sp.id} sp={sp} supplierId={supplierId!} t={t} />)
                  )}
                </div>
              ) : (
                <div className="p-6 space-y-6">
                  {/* Supplier Info */}
                  <Section title={t("suppliers.supplierInfo")}>
                    <Row label="ID" value={`#${supplierDetail.id}`} />
                    <Row label={t("suppliers.nationalId")} value={supplierDetail.national_id_number} />
                    <Row label={t("suppliers.synonyms")} value={supplierDetail.synonyms} />
                    {supplierDetail.type && <Row label={t("suppliers.type")} value={supplierDetail.type.name} />}
                    <Row label={t("suppliers.registeredAt")} value={fmtDate(supplierDetail.created_at)} />
                    <div className="flex justify-between items-center py-1.5 border-b border-gray-50 last:border-0">
                      <span className="text-sm text-gray-500">Markup Ratio</span>
                      <span className="text-sm text-right">
                        {supplierDetail.markup_ratio != null ? (
                          <span className="font-semibold text-indigo-700">
                            {supplierDetail.markup_ratio}×
                            <span className="text-xs text-gray-400 ml-1">
                              (+{((supplierDetail.markup_ratio - 1) * 100).toFixed(0)}% margin)
                            </span>
                          </span>
                        ) : "—"}
                      </span>
                    </div>
                  </Section>

                  {/* Documents */}
                  <Section title={t("suppliers.documents")}>
                    <DocRow label={t("suppliers.taxCard")} url={supplierDetail.tax_card} />
                    <DocRow label={t("suppliers.commercialRegister")} url={supplierDetail.commercial_register} />
                    <DocRow label={t("suppliers.nationalIdFront")} url={supplierDetail.national_id_photo_front} />
                    <DocRow label={t("suppliers.nationalIdBack")} url={supplierDetail.national_id_photo_back} />
                    <DocRow label={t("suppliers.criminalRecord")} url={supplierDetail.supplier_criminal_record} />
                  </Section>

                  {/* Stats */}
                  {supplierDetail.stats && (
                    <Section title={t("suppliers.stats")} icon={<BarChart2 size={16} />}>
                      <div className="grid grid-cols-2 md:grid-cols-5 gap-3">
                        {[
                          { label: t("suppliers.totalOrders"),     value: supplierDetail.stats.total_orders },
                          { label: t("suppliers.totalCustomers"),  value: supplierDetail.stats.total_customers },
                          { label: t("orders.delivered"),          value: supplierDetail.stats.total_delivered_orders },
                          { label: t("orders.cancelled"),          value: supplierDetail.stats.total_cancelled_orders },
                          { label: t("suppliers.activeProducts"),  value: supplierDetail.stats.total_active_products },
                        ].map(({ label, value }) => (
                          <div key={label} className="bg-gray-50 rounded-xl p-3 text-center">
                            <p className="text-xl font-bold text-gray-800">{value ?? "—"}</p>
                            <p className="text-xs text-gray-400 mt-0.5">{label}</p>
                          </div>
                        ))}
                      </div>
                      {supplierDetail.stats.last_order_date && (
                        <p className="text-xs text-gray-400 mt-2">Last order: {fmtDate(supplierDetail.stats.last_order_date)}</p>
                      )}
                    </Section>
                  )}

                  {/* Categories */}
                  {supplierDetail.categories && supplierDetail.categories.length > 0 && (
                    <Section title={t("suppliers.categories")} icon={<Tag size={16} />}>
                      <div className="flex flex-wrap gap-2">
                        {supplierDetail.categories.map(({ category }) => (
                          <span key={category.id} className="text-sm px-3 py-1 bg-indigo-50 text-indigo-700 rounded-full">{category.name}</span>
                        ))}
                      </div>
                    </Section>
                  )}

                  {/* Addresses */}
                  <Section title={t("suppliers.addresses")} icon={<MapPin size={16} />}>
                    {supplierDetail.addresses.length === 0 && (
                      <p className="text-sm text-gray-400 py-2">No store addresses yet.</p>
                    )}
                    {supplierDetail.addresses.map((addr) => (
                      <div key={addr.id} className="bg-gray-50 rounded-xl p-4 space-y-2 text-sm">
                        <div className="flex items-start justify-between gap-2">
                          <div className="flex-1 min-w-0 space-y-0.5">
                            <p className="font-medium text-gray-800 text-base">{[addr.address_line_1, addr.address_line_2].filter(Boolean).join(", ") || "—"}</p>
                            <p className="text-sm text-gray-500">{[addr.city, addr.state, addr.country].filter(Boolean).join(", ")}</p>
                            {addr.contact_name && <p className="text-sm text-gray-400">{addr.contact_name} · {addr.contact_phone}</p>}
                            {addr.google_map_link && (
                              <a href={addr.google_map_link} target="_blank" rel="noreferrer" className="inline-flex items-center gap-1 text-sm text-indigo-500 hover:underline mt-1">
                                <ExternalLink size={14} /> View on map
                              </a>
                            )}
                          </div>
                        </div>
                        {addr.working_hours && (
                          <div className="mt-3 pt-3 border-t border-gray-200">
                            <p className="text-sm font-medium text-gray-500 mb-2">Working Hours</p>
                            <div className="grid grid-cols-1 md:grid-cols-2 gap-2">
                              {Object.entries(addr.working_hours as WorkingHours).map(([day, h]) => (
                                <div key={day} className="flex items-center gap-3 text-sm">
                                  <span className={cn("capitalize w-24", h.is_open ? "text-gray-700 font-medium" : "text-gray-400")}>{day}</span>
                                  {h.is_open
                                    ? <span className="text-gray-600">{h.open} – {h.close}</span>
                                    : <span className="text-gray-400">Closed</span>}
                                </div>
                              ))}
                            </div>
                          </div>
                        )}
                      </div>
                    ))}
                  </Section>

                </div>
              )}
            </div>
          ) : null}
        </div>
      )}

      {/* Update Profile Modal */}
      {isUpdateProfileOpen && supplierProfile && (
        <UpdateProfileModal
          isOpen={isUpdateProfileOpen}
          onClose={() => setIsUpdateProfileOpen(false)}
          profile={supplierProfile}
          onSubmit={(data: Parameters<typeof updateSupplierProfile>[1]) =>
            updateProfileMutation.mutate(data)
          }
          isLoading={updateProfileMutation.isPending}
        />
      )}

      {/* Update Documents Modal */}
      {isUpdateDocumentsOpen && (
        <UpdateDocumentsModal
          isOpen={isUpdateDocumentsOpen}
          onClose={() => setIsUpdateDocumentsOpen(false)}
          profile={supplierProfile}
          onSubmit={(data: FormData) => updateDocumentsMutation.mutate(data)}
          isLoading={updateDocumentsMutation.isPending}
        />
      )}

      {/* Settle Balance Modal */}
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

function fmtDate(d: string) {
  return new Date(d).toLocaleDateString("en-GB", { day: "2-digit", month: "short", year: "numeric" });
}

function SupplierProductCard({ sp, supplierId, t }: { sp: SupplierProductItem; supplierId: number; t: (k: string) => string }) {
  const qc = useQueryClient();
  const [resetting, setResetting] = useState(false);
  const images = (() => { try { return JSON.parse(sp.product.images ?? "[]"); } catch { return []; } })();
  const thumb = images[0] ?? null;

  async function handleReset() {
    setResetting(true);
    try {
      await resetSupplierProductPrice(sp.product.id, sp.id);
      toast.success("Price reset to markup default");
      qc.invalidateQueries({ queryKey: ["supplier-products", supplierId] });
    } catch {
      toast.error("Failed to reset price");
    } finally {
      setResetting(false);
    }
  }

  return (
    <div className="border border-gray-200 rounded-xl p-4 flex gap-3 hover:border-gray-300 transition-colors">
      {thumb ? (
        <img src={thumb} alt={sp.product.name} className="w-[64px] h-[64px] rounded-lg object-cover shrink-0 border" />
      ) : (
        <div className="w-[64px] h-[64px] rounded-lg bg-gray-100 flex items-center justify-center shrink-0">
          <Package size={24} className="text-gray-400" />
        </div>
      )}
      <div className="flex-1 min-w-0">
        <p className="text-base font-semibold text-gray-900 truncate">{sp.product.name}</p>
        {sp.product.name_ar && <p className="text-sm text-gray-400 truncate">{sp.product.name_ar}</p>}
        <div className="flex flex-wrap items-center gap-2 mt-2">
          {sp.product.category && (
            <span className="text-xs px-2 py-0.5 bg-indigo-50 text-indigo-600 rounded-full">{sp.product.category.name}</span>
          )}
          <span className={cn("text-xs px-2 py-0.5 rounded-full font-medium",
            sp.is_active ? "bg-green-100 text-green-700" : "bg-red-100 text-red-700")}>
            {sp.is_active ? t("common.active") : t("common.inactive")}
          </span>
          {sp.is_featured && <span className="flex items-center gap-1 text-xs px-2 py-0.5 bg-yellow-50 text-yellow-700 rounded-full"><Star size={12} /> {t("supplierProd.isFeatured")}</span>}
          {sp.is_best_seller && <span className="flex items-center gap-1 text-xs px-2 py-0.5 bg-orange-50 text-orange-700 rounded-full"><TrendingUp size={12} /> {t("supplierProd.isBestSeller")}</span>}
        </div>
      </div>
      <div className="text-right shrink-0 flex flex-col items-end gap-2">
        <div>
          {sp.price != null && <p className="text-base font-bold text-gray-800">{sp.price} EGP</p>}
          {sp.cost_price != null && <p className="text-sm text-gray-400">Cost: {sp.cost_price} EGP</p>}
          <p className="text-sm text-gray-400 flex items-center gap-1 justify-end"><Package size={14} />{sp.stock}</p>
        </div>
        <button
          onClick={handleReset}
          disabled={resetting || sp.cost_price == null}
          title={sp.cost_price == null ? "No cost price set" : "Reset to cost × markup ratio"}
          className="flex items-center gap-1 text-xs px-3 py-1.5 border border-indigo-200 text-indigo-600 rounded-lg hover:bg-indigo-50 disabled:opacity-40 disabled:cursor-not-allowed transition">
          <RefreshCw size={14} className={resetting ? "animate-spin" : ""} />
          Reset price
        </button>
      </div>
    </div>
  );
}

function Section({ title, icon, children }: { title: string; icon?: React.ReactNode; children: React.ReactNode }) {
  return (
    <div>
      <div className="flex items-center gap-2 mb-4">
        {icon && <span className="text-indigo-500">{icon}</span>}
        <p className="text-sm font-semibold text-gray-400 uppercase tracking-wide">{title}</p>
      </div>
      <div className="space-y-3">{children}</div>
    </div>
  );
}

function Row({ label, value }: { label: string; value?: string | null }) {
  return (
    <div className="flex justify-between items-start py-2 border-b border-gray-50 last:border-0">
      <span className="text-sm text-gray-500 shrink-0 mr-4">{label}</span>
      <span className="text-sm text-gray-800 text-right">{value ?? "—"}</span>
    </div>
  );
}

function DocRow({ label, url, viewLabel = "View file" }: { label: string; url?: string | null; viewLabel?: string }) {
  return (
    <div className="flex justify-between items-center py-2 border-b border-gray-50 last:border-0">
      <span className="text-sm text-gray-500">{label}</span>
      {url ? (
        <a href={url} target="_blank" rel="noreferrer" className="inline-flex items-center gap-1 text-sm text-indigo-500 hover:underline">
          <ExternalLink size={14} /> {viewLabel}
        </a>
      ) : <span className="text-sm text-gray-300">—</span>}
    </div>
  );
}
