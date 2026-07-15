"use client";

import { useState } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { useParams, useSearchParams, useRouter } from "next/navigation";
import { fetchUser, type User } from "@/lib/users";
import { fetchRoles, type Role } from "@/lib/roles";
import {
  fetchCourierOffices,
  assignCourierToOffice,
  type CourierOffice,
} from "@/lib/courier-offices";
import { useT } from "@/contexts/LanguageContext";
import api from "@/lib/api";
import {
  ArrowLeft,
  Loader2,
  User as UserIcon,
  Mail,
  Phone,
  Shield,
  CheckCircle,
  XCircle,
  Pencil,
  X,
  Check,
  Building2,
} from "lucide-react";
import { cn } from "@/lib/utils";
import toast from "react-hot-toast";

function ChangeRoleModal({
  user,
  onClose,
}: {
  user: User;
  onClose: () => void;
}) {
  const qc = useQueryClient();
  const [selected, setSelected] = useState<number | null>(null);

  const { data: rolesData, isLoading } = useQuery({
    queryKey: ["roles-list"],
    queryFn: () => fetchRoles({ limit: 50 }),
    staleTime: 60_000,
  });

  const mut = useMutation({
    mutationFn: (roleId: number) =>
      api.put(`/users/${user.id}`, { role_id: roleId }),
    onSuccess: () => {
      toast.success("Role updated");
      qc.invalidateQueries({ queryKey: ["user", user.id] });
      onClose();
    },
    onError: (e: any) =>
      toast.error(e?.response?.data?.message ?? "Failed to update role"),
  });

  const roles: Role[] = rolesData?.roles ?? [];

  return (
    <div className="fixed inset-0 z-50 bg-black/40 flex items-center justify-center p-4">
      <div className="bg-white rounded-2xl shadow-2xl w-full max-w-sm">
        <div className="flex items-center justify-between p-5 border-b border-gray-100">
          <h2 className="text-base font-semibold text-gray-900">
            Change Role — {user.full_name}
          </h2>
          <button
            onClick={onClose}
            className="p-1.5 hover:bg-gray-100 rounded-lg"
          >
            <X size={16} />
          </button>
        </div>
        <div className="p-4 space-y-2 max-h-72 overflow-y-auto">
          {isLoading ? (
            <div className="flex justify-center py-6">
              <Loader2 size={20} className="animate-spin text-indigo-400" />
            </div>
          ) : (
            roles.map((r) => (
              <button
                key={r.id}
                onClick={() => setSelected(r.id)}
                className={cn(
                  "w-full flex items-center justify-between px-4 py-3 rounded-xl border text-left transition",
                  selected === r.id
                    ? "border-indigo-500 bg-indigo-50"
                    : user.role?.id === r.id
                      ? "border-green-300 bg-green-50"
                      : "border-gray-200 hover:border-indigo-300 hover:bg-gray-50",
                )}
              >
                <div>
                  <p className="text-sm font-medium text-gray-900">{r.name}</p>
                  {r.description && (
                    <p className="text-xs text-gray-400 mt-0.5">
                      {r.description}
                    </p>
                  )}
                </div>
                {user.role?.id === r.id && (
                  <span className="text-xs text-green-600 font-medium">
                    Current
                  </span>
                )}
                {selected === r.id && user.role?.id !== r.id && (
                  <Check size={14} className="text-indigo-600" />
                )}
              </button>
            ))
          )}
        </div>
        <div className="flex justify-end gap-2 p-4 border-t border-gray-100">
          <button
            onClick={onClose}
            className="px-4 py-2 text-sm border border-gray-200 rounded-xl hover:bg-gray-50"
          >
            Cancel
          </button>
          <button
            onClick={() => selected && mut.mutate(selected)}
            disabled={!selected || selected === user.role?.id || mut.isPending}
            className="flex items-center gap-2 px-4 py-2 text-sm bg-indigo-600 text-white rounded-xl hover:bg-indigo-700 disabled:opacity-50"
          >
            {mut.isPending && <Loader2 size={13} className="animate-spin" />}
            Save
          </button>
        </div>
      </div>
    </div>
  );
}

function ChangeOfficeModal({
  user,
  onClose,
}: {
  user: User;
  onClose: () => void;
}) {
  const qc = useQueryClient();
  const [selected, setSelected] = useState<number | null>(null);

  const { data: officesData, isLoading } = useQuery({
    queryKey: ["courier-offices-list"],
    queryFn: () => fetchCourierOffices({ limit: 50 }),
    staleTime: 60_000,
  });

  const mut = useMutation({
    mutationFn: (officeId: number) =>
      assignCourierToOffice(user.courier!.id!, officeId),
    onSuccess: () => {
      toast.success("Office assigned");
      qc.invalidateQueries({ queryKey: ["user", user.id] });
      onClose();
    },
    onError: (e: any) =>
      toast.error(e?.response?.data?.message ?? "Failed to assign office"),
  });

  const removeMut = useMutation({
    mutationFn: () =>
      api.post("/admin/courier-office/append-courier-to-office", {
        courierId: String(user.courier!.id!),
      }),
    onSuccess: () => {
      toast.success("Removed from office");
      qc.invalidateQueries({ queryKey: ["user", user.id] });
      onClose();
    },
    onError: (e: any) => toast.error(e?.response?.data?.message ?? "Failed"),
  });

  const offices: CourierOffice[] = officesData?.couriers ?? [];

  return (
    <div className="fixed inset-0 z-50 bg-black/40 flex items-center justify-center p-4">
      <div className="bg-white rounded-2xl shadow-2xl w-full max-w-sm">
        <div className="flex items-center justify-between p-5 border-b border-gray-100">
          <h2 className="text-base font-semibold text-gray-900">
            Assign Office — {user.full_name}
          </h2>
          <button
            onClick={onClose}
            className="p-1.5 hover:bg-gray-100 rounded-lg"
          >
            <X size={16} />
          </button>
        </div>
        <div className="p-4 space-y-2 max-h-72 overflow-y-auto">
          {isLoading ? (
            <div className="flex justify-center py-6">
              <Loader2 size={20} className="animate-spin text-indigo-400" />
            </div>
          ) : (
            offices.map((o) => (
              <button
                key={o.id}
                onClick={() => setSelected(o.id)}
                className={cn(
                  "w-full flex items-center justify-between px-4 py-3 rounded-xl border text-left transition",
                  selected === o.id
                    ? "border-indigo-500 bg-indigo-50"
                    : user.courier?.courier_office_id === o.id
                      ? "border-green-300 bg-green-50"
                      : "border-gray-200 hover:border-indigo-300 hover:bg-gray-50",
                )}
              >
                <div>
                  <p className="text-sm font-medium text-gray-900">{o.name}</p>
                  {o.address && (
                    <p className="text-xs text-gray-400 mt-0.5">{o.address}</p>
                  )}
                </div>
                {user.courier?.courier_office_id === o.id && (
                  <span className="text-xs text-green-600 font-medium">
                    Current
                  </span>
                )}
                {selected === o.id &&
                  user.courier?.courier_office_id !== o.id && (
                    <Check size={14} className="text-indigo-600" />
                  )}
              </button>
            ))
          )}
        </div>
        <div className="flex justify-between gap-2 p-4 border-t border-gray-100">
          {user.courier?.courier_office_id && (
            <button
              onClick={() => removeMut.mutate()}
              disabled={removeMut.isPending || mut.isPending}
              className="px-4 py-2 text-sm border border-red-200 text-red-600 rounded-xl hover:bg-red-50 disabled:opacity-50"
            >
              Remove from office
            </button>
          )}
          <div className="flex gap-2 ml-auto">
            <button
              onClick={onClose}
              className="px-4 py-2 text-sm border border-gray-200 rounded-xl hover:bg-gray-50"
            >
              Cancel
            </button>
            <button
              onClick={() => selected && mut.mutate(selected)}
              disabled={
                !selected ||
                selected === user.courier?.courier_office_id ||
                mut.isPending
              }
              className="flex items-center gap-2 px-4 py-2 text-sm bg-indigo-600 text-white rounded-xl hover:bg-indigo-700 disabled:opacity-50"
            >
              {mut.isPending && <Loader2 size={13} className="animate-spin" />}
              Save
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}

// Role ID mapping - adjust these based on your actual role IDs
const ROLE_IDS = {
  ADMIN: 1,
  COURIER: 2,
  CUSTOMER: 3,
  SELLER: 4, // or SUPPLIER
};

export default function UserDetailPage() {
  const { t } = useT();
  const router = useRouter();
  const params = useParams();
  const searchParams = useSearchParams();
  const userId = Number(params.userId);
  const roleId = Number(searchParams.get("roleId"));
  const [showChangeRole, setShowChangeRole] = useState(false);
  const [showChangeOffice, setShowChangeOffice] = useState(false);

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

  // Determine which detail view to show based on role
  const roleName = user.role?.name || "";
  const isAdmin =
    roleId === ROLE_IDS.ADMIN || roleName.toLowerCase().includes("admin");
  const isCustomer =
    roleId === ROLE_IDS.CUSTOMER || roleName.toLowerCase().includes("customer");
  const isSeller =
    roleId === ROLE_IDS.SELLER ||
    roleName.toLowerCase().includes("supplier") ||
    roleName.toLowerCase().includes("seller");
  const isCourier =
    roleId === ROLE_IDS.COURIER ||
    (roleName.toLowerCase().includes("courier") &&
      !roleName.toLowerCase().includes("office"));
  const isCourierOffice =
    roleName.toLowerCase().includes("courieroffice") ||
    roleName.toLowerCase().replace(/\s/g, "").includes("courieroffice") ||
    roleName.toLowerCase().includes("courier office");
  const hasCourierRecord =
    !!(isCourier || isCourierOffice) && !!user.courier?.id;

  return (
    <div className="p-6 space-y-6">
      {showChangeRole && (
        <ChangeRoleModal user={user} onClose={() => setShowChangeRole(false)} />
      )}
      {showChangeOffice && hasCourierRecord && (
        <ChangeOfficeModal
          user={user}
          onClose={() => setShowChangeOffice(false)}
        />
      )}
      {/* Header */}
      <div className="flex items-center gap-4">
        <button
          onClick={() => router.push("/users")}
          className="p-2 hover:bg-gray-100 rounded-lg transition"
          title={t("common.back")}
        >
          <ArrowLeft size={20} />
        </button>
        <div>
          <h1 className="text-2xl font-bold text-gray-900">{user.full_name}</h1>
          <p className="text-sm text-gray-500">{t("users.userDetails")}</p>
        </div>
      </div>

      {/* User Info Card */}
      <div className="bg-white rounded-xl border border-gray-200 p-6">
        <div className="flex items-start gap-6">
          {/* Avatar */}
          <div className="relative">
            {user.personal_photo ? (
              <img
                src={user.personal_photo}
                alt={user.full_name}
                className="w-24 h-24 rounded-full object-cover border-4 border-gray-100"
              />
            ) : (
              <div className="w-24 h-24 rounded-full bg-indigo-100 flex items-center justify-center border-4 border-gray-100">
                <UserIcon size={40} className="text-indigo-600" />
              </div>
            )}
          </div>

          {/* Basic Info */}
          <div className="flex-1 grid grid-cols-2 md:grid-cols-3 gap-4">
            <div>
              <p className="text-xs text-gray-500 uppercase tracking-wide">
                ID
              </p>
              <p className="text-sm font-medium text-gray-900">{user.id}</p>
            </div>
            <div>
              <p className="text-xs text-gray-500 uppercase tracking-wide">
                {t("users.role")}
              </p>
              <div className="flex items-center gap-2">
                <Shield size={14} className="text-indigo-500" />
                <span className="text-sm font-medium text-gray-900">
                  {user.role?.name || "—"}
                </span>
                <button
                  onClick={() => setShowChangeRole(true)}
                  className="p-1 hover:bg-indigo-50 text-indigo-500 rounded-md transition"
                  title="Change role"
                >
                  <Pencil size={12} />
                </button>
              </div>
            </div>
            <div>
              <p className="text-xs text-gray-500 uppercase tracking-wide">
                {t("common.status")}
              </p>
              <span
                className={cn(
                  "inline-flex items-center gap-1 px-2 py-1 rounded-full text-xs font-medium",
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
            <div>
              <p className="text-xs text-gray-500 uppercase tracking-wide">
                {t("users.email")}
              </p>
              <div className="flex items-center gap-1">
                <Mail size={14} className="text-gray-400" />
                <span className="text-sm text-gray-900">
                  {user.email || "—"}
                </span>
                {user.is_email_verified && (
                  <CheckCircle size={12} className="text-green-500" />
                )}
              </div>
            </div>
            <div>
              <p className="text-xs text-gray-500 uppercase tracking-wide">
                {t("users.phone")}
              </p>
              <div className="flex items-center gap-1">
                <Phone size={14} className="text-gray-400" />
                <span className="text-sm text-gray-900">{user.phone}</span>
                {user.is_phone_verified && (
                  <CheckCircle size={12} className="text-green-500" />
                )}
              </div>
            </div>
            <div>
              <p className="text-xs text-gray-500 uppercase tracking-wide">
                {t("users.gender")}
              </p>
              <p className="text-sm text-gray-900">
                {user.gender === "MALE"
                  ? t("filters.male")
                  : user.gender === "FEMALE"
                    ? t("filters.female")
                    : "—"}
              </p>
            </div>
            <div>
              <p className="text-xs text-gray-500 uppercase tracking-wide">
                {t("users.badge")}
              </p>
              <p className="text-sm text-gray-900">{user.badge?.name || "—"}</p>
            </div>
            <div>
              <p className="text-xs text-gray-500 uppercase tracking-wide">
                {t("users.language")}
              </p>
              <p className="text-sm text-gray-900">{user.lang || "—"}</p>
            </div>
            <div>
              <p className="text-xs text-gray-500 uppercase tracking-wide">
                {t("users.joined")}
              </p>
              <p className="text-sm text-gray-900">
                {new Date(user.created_at).toLocaleDateString()}
              </p>
            </div>
          </div>
        </div>
      </div>

      {/* Role-specific sections placeholder */}
      {isAdmin && (
        <div className="bg-white rounded-xl border border-gray-200 p-6">
          <h3 className="text-lg font-medium text-gray-900 mb-4">
            {t("users.adminDetails")}
          </h3>
          <p className="text-gray-500">{t("users.adminDetailsDesc")}</p>
        </div>
      )}

      {isCustomer && (
        <div className="bg-white rounded-xl border border-gray-200 p-6">
          <h3 className="text-lg font-medium text-gray-900 mb-4">
            {t("users.customerDetails")}
          </h3>
          <p className="text-gray-500">{t("users.customerDetailsDesc")}</p>
          {/* TODO: Add wallet, commissions, penalties, escrows, payment methods, transactions */}
        </div>
      )}

      {isSeller && (
        <div className="bg-white rounded-xl border border-gray-200 p-6">
          <h3 className="text-lg font-medium text-gray-900 mb-4">
            {t("users.sellerDetails")}
          </h3>
          <p className="text-gray-500">{t("users.sellerDetailsDesc")}</p>
          {/* TODO: Add seller info, wallet, commissions, penalties, escrows, payment methods, transactions */}
        </div>
      )}

      {(isCourier || isCourierOffice) && (
        <div className="bg-white rounded-xl border border-gray-200 p-6">
          <div className="flex items-center justify-between mb-4">
            <h3 className="text-lg font-medium text-gray-900">
              {isCourierOffice
                ? "Office Manager Details"
                : t("users.courierDetails")}
            </h3>
          </div>
          <div className="grid grid-cols-2 md:grid-cols-3 gap-4">
            {user.courier?.vehicle_type && (
              <div>
                <p className="text-xs text-gray-500 uppercase tracking-wide">
                  Vehicle
                </p>
                <p className="text-sm text-gray-900 capitalize">
                  {user.courier.vehicle_type}
                </p>
              </div>
            )}
            {user.courier?.vehicle_plate && (
              <div>
                <p className="text-xs text-gray-500 uppercase tracking-wide">
                  Plate
                </p>
                <p className="text-sm text-gray-900">
                  {user.courier.vehicle_plate}
                </p>
              </div>
            )}
            {user.courier?.national_id_number && (
              <div>
                <p className="text-xs text-gray-500 uppercase tracking-wide">
                  National ID
                </p>
                <p className="text-sm text-gray-900">
                  {user.courier.national_id_number}
                </p>
              </div>
            )}
            <div>
              <p className="text-xs text-gray-500 uppercase tracking-wide">
                Courier Office
              </p>
              <div className="flex items-center gap-2 mt-0.5">
                <Building2 size={14} className="text-indigo-500" />
                <span className="text-sm text-gray-900">
                  {user.courier?.courierOffice?.name ?? "Not assigned"}
                </span>
                <button
                  onClick={() => setShowChangeOffice(true)}
                  disabled={!user.courier?.id}
                  className="p-1 hover:bg-indigo-50 text-indigo-500 rounded-md transition disabled:opacity-40"
                  title="Change office"
                >
                  <Pencil size={12} />
                </button>
              </div>
              {!user.courier?.id && (
                <p className="text-xs text-amber-500 mt-1">
                  No courier record — cannot assign office
                </p>
              )}
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

/*

import {
  useParams,
  Navigate,
  useSearchParams,
  useNavigate,
} from "react-router-dom";
import { useEffect, useState } from "react";
import axiosInstance from "@/lib/axios";
import { Skeleton } from "@/components/ui/skeleton";

export default function UserDetailsPage() {
  const { userId } = useParams();
  const [searchParams] = useSearchParams();
  const roleId = searchParams.get("roleId") || searchParams.get("role_id");
  const navigate = useNavigate();

  const [isLoading, setIsLoading] = useState(false);

  useEffect(() => {
    if (!userId || !roleId) return;

    if (roleId === "2") {
      // Courier: fetch courier ID then navigate
      setIsLoading(true);
      axiosInstance
        .get(`/users/${userId}?includes=courier`)
        .then((res) => {
          const courierId =
            res.data?.user?.courier?.id || res.data?.courier?.id;
          if (courierId) {
            navigate(`/users/couriers/${courierId}`, { replace: true });
          } else {
            navigate("/users", { replace: true });
          }
        })
        .catch((err) => {
          console.error("Failed to fetch courier details for routing", err);
          navigate("/users", { replace: true });
        })
        .finally(() => {
          setIsLoading(false);
        });
    } else if (roleId === "3") {
      // Customer: navigate directly
      navigate(`/users/customers/${userId}`, { replace: true });
    } else if (roleId === "4") {
      // Seller: navigate directly
      navigate(`/users/sellers/${userId}`, { replace: true });
    } else {
      // Admin (roleId "1" or other): navigate directly
      navigate(`/users/admins/${userId}`, { replace: true });
    }
  }, [userId, roleId, navigate]);

  if (isLoading) {
    return (
      <div className="p-6 space-y-6 flex flex-col h-full">
        <Skeleton className="h-10 w-1/4" />
        <Skeleton className="h-[400px] w-full" />
      </div>
    );
  }

  // Show loader while redirecting
  if (userId && roleId) {
    return (
      <div className="p-6 space-y-6 flex flex-col h-full">
        <Skeleton className="h-10 w-1/4" />
        <Skeleton className="h-[400px] w-full" />
      </div>
    );
  }

  return <Navigate to="/users" replace />;
}



*/
