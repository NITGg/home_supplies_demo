"use client";

import { useQuery } from "@tanstack/react-query";
import { useParams, useRouter } from "next/navigation";
import { fetchUser } from "@/lib/users";
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
  Lock,
  Settings,
  LogOut,
  Activity,
  DollarSign,
  Gift,
  Snowflake,
  Wallet,
} from "lucide-react";
import { cn } from "@/lib/utils";
import UserWalletSection from "@/components/users/UserWalletSection";


export default function AdminDetailPage() {
  const { t } = useT();
  const router = useRouter();
  const params = useParams();
  const userId = Number(params.userId);

  const { data: user, isLoading } = useQuery({
    queryKey: ["user", userId, "details"],
    queryFn: () => fetchUser(userId, "role,badge,courier,wallet"),
    enabled: !!userId,
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
            <div className="w-12 h-12 rounded-full bg-red-100 flex items-center justify-center border-2 border-gray-200">
              <Shield size={24} className="text-red-600" />
            </div>
          )}
          <div>
            <h1 className="text-2xl font-bold text-gray-900">
              {user.full_name}
            </h1>
            <p className="text-sm text-gray-500">{t("users.adminDetails")}</p>
          </div>
        </div>
      </div>

      {/* Actions Block */}
      <div className="bg-white rounded-xl border border-gray-200 p-6">
        <h2 className="text-lg font-semibold text-gray-900 mb-4">Actions</h2>
        <div className="flex flex-wrap gap-3">
          {/* Actions will be added here in the future */}
        </div>
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
            <div className="w-10 h-10 rounded-lg bg-red-50 flex items-center justify-center shrink-0">
              <Shield size={18} className="text-red-600" />
            </div>
            <div>
              <p className="text-xs text-gray-500 uppercase tracking-wide">
                {t("users.role")}
              </p>
              <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-xs font-medium bg-red-100 text-red-700">
                <Shield size={10} />
                {user.role?.name || "Admin"}
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

          {/* Login Type */}
          <div className="flex items-start gap-3">
            <div className="w-10 h-10 rounded-lg bg-purple-50 flex items-center justify-center shrink-0">
              <Lock size={18} className="text-purple-600" />
            </div>
            <div>
              <p className="text-xs text-gray-500 uppercase tracking-wide">
                Login Type
              </p>
              <p className="text-sm font-medium text-gray-900">
                {user.login_type || "EMAIL"}
              </p>
            </div>
          </div>

          {/* Last Login */}
          <div className="flex items-start gap-3">
            <div className="w-10 h-10 rounded-lg bg-orange-50 flex items-center justify-center shrink-0">
              <LogOut size={18} className="text-orange-600" />
            </div>
            <div>
              <p className="text-xs text-gray-500 uppercase tracking-wide">
                Last Login
              </p>
              <p className="text-sm font-medium text-gray-900">
                {user.last_login_at
                  ? new Date(user.last_login_at).toLocaleDateString()
                  : "—"}
              </p>
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
    </div>
  );
}
