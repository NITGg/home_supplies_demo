"use client";
import { useState } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { supplierApi } from "@/lib/api";
import { useRole } from "@/hooks/useRole";
import { getCurrentUserId } from "@/lib/auth";
import {
  User, Phone, Mail, MapPin, Clock, FileText, CheckCircle,
  XCircle, Pencil, Loader2, RefreshCw, Award, TrendingUp,
} from "lucide-react";
import { cn } from "@/lib/utils";
import toast from "react-hot-toast";
import { WorkingHoursSection } from "./WorkingHoursSection";

export default function SupplierProfilePage() {
  const { user } = useRole();
  const userId = user?.id ?? getCurrentUserId();
  const qc = useQueryClient();
  const [editing, setEditing] = useState(false);
  const [form, setForm] = useState<Record<string, string>>({});

  const { data: profile, isLoading } = useQuery({
    queryKey: ["supplier-profile", userId],
    queryFn: async () => {
      const res = await supplierApi.get(`/profile/get-profile/${userId}`);
      return res.data?.data?.user ?? res.data?.data;
    },
    enabled: !!userId,
  });

  const { data: badgeData } = useQuery({
    queryKey: ["supplier-badge", userId],
    queryFn: async () => {
      const res = await supplierApi.get(`/profile/badge-progress/${userId}`);
      return res.data?.data;
    },
    enabled: !!userId,
  });

  const updateMut = useMutation({
    mutationFn: async (data: Record<string, string>) => {
      await supplierApi.patch(`/profile/update-profile/${userId}`, data);
    },
    onSuccess: () => {
      toast.success("Profile updated successfully");
      qc.invalidateQueries({ queryKey: ["supplier-profile", userId] });
      setEditing(false);
    },
    onError: (e: any) => toast.error(e?.response?.data?.message ?? "Update failed"),
  });

  if (isLoading) {
    return (
      <div className="flex items-center justify-center min-h-[400px]">
        <Loader2 className="animate-spin text-indigo-600" size={32} />
      </div>
    );
  }

  if (!profile) return null;

  const startEdit = () => {
    setForm({
      full_name: profile.full_name ?? "",
      phone: profile.phone ?? "",
      gender: profile.gender ?? "",
      synonyms: profile.supplier?.synonyms ?? "",
    });
    setEditing(true);
  };

  return (
    <div className="p-6 space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-bold text-gray-900">My Profile</h1>
        {!editing ? (
          <button onClick={startEdit}
            className="flex items-center gap-2 px-4 py-2 bg-indigo-600 text-white rounded-xl text-sm font-medium hover:bg-indigo-700 transition">
            <Pencil size={14} /> Edit Profile
          </button>
        ) : (
          <div className="flex gap-2">
            <button onClick={() => setEditing(false)}
              className="px-4 py-2 border border-gray-200 rounded-xl text-sm text-gray-600 hover:bg-gray-50">
              Cancel
            </button>
            <button onClick={() => updateMut.mutate(form)} disabled={updateMut.isPending}
              className="flex items-center gap-2 px-4 py-2 bg-indigo-600 text-white rounded-xl text-sm font-medium hover:bg-indigo-700 disabled:opacity-60">
              {updateMut.isPending ? <Loader2 size={14} className="animate-spin" /> : null}
              Save Changes
            </button>
          </div>
        )}
      </div>

      {/* Avatar + basic info */}
      <div className="bg-white rounded-xl border border-gray-200 p-6">
        <div className="flex items-center gap-4 mb-6">
          {profile.personal_photo ? (
            <img src={profile.personal_photo} alt={profile.full_name}
              className="w-20 h-20 rounded-2xl object-cover border-2 border-gray-200" />
          ) : (
            <div className="w-20 h-20 rounded-2xl bg-indigo-100 flex items-center justify-center text-indigo-600 font-bold text-3xl border-2 border-gray-200">
              {profile.full_name?.[0] ?? "S"}
            </div>
          )}
          <div>
            <h2 className="text-xl font-bold text-gray-900">{profile.full_name}</h2>
            <p className="text-sm text-gray-500">{profile.phone}</p>
            <span className={cn("inline-flex items-center gap-1 text-xs px-2 py-0.5 rounded-full font-medium mt-1",
              profile.supplier?.is_approved ? "bg-green-100 text-green-700" : "bg-amber-100 text-amber-700")}>
              {profile.supplier?.is_approved ? <CheckCircle size={10} /> : <XCircle size={10} />}
              {profile.supplier?.is_approved ? "Approved" : "Pending Approval"}
            </span>
          </div>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 gap-5">
          {[
            { label: "Full Name", value: profile.full_name, field: "full_name", icon: User },
            { label: "Phone", value: profile.phone, field: "phone", icon: Phone },
            { label: "Email", value: profile.email ?? "—", field: "email", icon: Mail },
            { label: "Gender", value: profile.gender ?? "—", field: "gender", icon: User },
            { label: "Store Synonyms", value: profile.supplier?.synonyms ?? "—", field: "synonyms", icon: FileText },
            { label: "National ID", value: profile.supplier?.national_id_number ?? "—", field: null, icon: FileText },
          ].map(({ label, value, field, icon: Icon }) => (
            <div key={label} className="flex items-start gap-3">
              <div className="w-9 h-9 rounded-lg bg-gray-100 flex items-center justify-center shrink-0">
                <Icon size={16} className="text-gray-600" />
              </div>
              <div className="flex-1">
                <p className="text-xs text-gray-500 uppercase tracking-wide">{label}</p>
                {editing && field ? (
                  <input
                    value={form[field] ?? ""}
                    onChange={(e) => setForm((f) => ({ ...f, [field]: e.target.value }))}
                    className="mt-0.5 w-full border border-gray-200 rounded-lg px-3 py-1.5 text-sm outline-none focus:ring-2 focus:ring-indigo-500"
                  />
                ) : (
                  <p className="text-sm font-medium text-gray-900 mt-0.5">{value ?? "—"}</p>
                )}
              </div>
            </div>
          ))}
        </div>
      </div>

      {/* Document status */}
      <div className="bg-white rounded-xl border border-gray-200 p-5">
        <h2 className="text-base font-semibold text-gray-900 mb-4">Document Status</h2>
        <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
          {[
            { label: "National ID (Front)", value: profile.supplier?.national_id_photo_front },
            { label: "National ID (Back)", value: profile.supplier?.national_id_photo_back },
            { label: "Criminal Record", value: profile.supplier?.supplier_criminal_record },
          ].map(({ label, value }) => (
            <div key={label} className={cn("rounded-xl border p-3 flex items-center gap-3",
              value ? "border-green-200 bg-green-50" : "border-gray-200 bg-gray-50")}>
              {value ? <CheckCircle size={16} className="text-green-600 shrink-0" /> : <XCircle size={16} className="text-gray-400 shrink-0" />}
              <div>
                <p className="text-xs font-medium text-gray-700">{label}</p>
                <p className="text-xs text-gray-500">{value ? "Uploaded" : "Not uploaded"}</p>
              </div>
            </div>
          ))}
        </div>
      </div>

      {/* Markup ratio + store addresses */}
      {(profile.supplier?.markup_ratio != null || (profile.supplier?.addresses ?? []).length > 0) && (
        <div className="bg-white rounded-xl border border-gray-200 p-5 space-y-4">
          <h2 className="text-base font-semibold text-gray-900 flex items-center gap-2">
            <MapPin size={16} className="text-indigo-500" /> Store Info
          </h2>

          {/* Markup ratio */}
          {profile.supplier?.markup_ratio != null && (
            <div className="flex items-center gap-3 p-3 bg-indigo-50 rounded-xl">
              <div className="w-9 h-9 rounded-lg bg-indigo-100 flex items-center justify-center shrink-0">
                <TrendingUp size={16} className="text-indigo-600" />
              </div>
              <div>
                <p className="text-xs text-gray-500 uppercase tracking-wide">Agreed Markup Ratio</p>
                <p className="text-sm font-bold text-indigo-700">
                  {profile.supplier.markup_ratio}×
                  <span className="text-xs font-normal text-gray-500 ml-1.5">
                    (+{((profile.supplier.markup_ratio - 1) * 100).toFixed(0)}% above cost price)
                  </span>
                </p>
                <p className="text-xs text-gray-400 mt-0.5">Selling price = your cost × this ratio</p>
              </div>
            </div>
          )}

          {/* Store addresses */}
          {(profile.supplier?.addresses ?? []).map((addr: any, i: number) => (
            <div key={addr.id ?? i} className="border border-gray-200 rounded-xl p-4 space-y-2">
              <div className="flex items-center gap-2 mb-1">
                <MapPin size={13} className="text-gray-400" />
                <p className="text-sm font-medium text-gray-800">
                  {[addr.address_line_1, addr.address_line_2].filter(Boolean).join(", ") || "Store Address"}
                </p>
              </div>
              <p className="text-xs text-gray-500">
                {[addr.city, addr.state, addr.country].filter(Boolean).join(", ")}
              </p>
              {addr.contact_name && (
                <p className="text-xs text-gray-400">{addr.contact_name} · {addr.contact_phone}</p>
              )}
              {addr.google_map_link && (
                <a href={addr.google_map_link} target="_blank" rel="noreferrer"
                  className="inline-flex items-center gap-1 text-xs text-indigo-500 hover:underline">
                  <MapPin size={11} /> View on map
                </a>
              )}
            </div>
          ))}
        </div>
      )}

      {/* Badge progress */}
      {badgeData && (
        <div className="bg-white rounded-xl border border-gray-200 p-5">
          <div className="flex items-center gap-2 mb-4">
            <Award size={18} className="text-yellow-600" />
            <h2 className="text-base font-semibold text-gray-900">Badge Progress</h2>
          </div>
          <div className="flex items-center gap-4">
            {badgeData.current_badge?.image && (
              <img src={badgeData.current_badge.image} alt={badgeData.current_badge.name}
                className="w-14 h-14 object-contain" />
            )}
            <div>
              <p className="text-lg font-bold text-gray-900">{badgeData.current_badge?.name ?? "—"}</p>
              <p className="text-xs text-gray-500">
                {badgeData.current_badge?.min_count} – {badgeData.current_badge?.max_count} orders
              </p>
            </div>
          </div>
          <div className="mt-4 flex gap-2 flex-wrap">
            {badgeData.all_badges?.map((b: any) => (
              <div key={b.id} className={cn("px-3 py-1.5 rounded-full text-xs font-medium border",
                b.id === badgeData.current_badge?.id
                  ? "bg-indigo-600 text-white border-indigo-600"
                  : "bg-white text-gray-500 border-gray-200")}>
                {b.name}
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Working Hours Editor Section */}
      <WorkingHoursSection />
    </div>
  );
}
