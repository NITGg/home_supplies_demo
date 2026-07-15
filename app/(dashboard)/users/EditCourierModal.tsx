"use client";

import { useState, useRef, ChangeEvent } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import {
  X,
  Loader2,
  User as UserIcon,
  FileText,
  Truck,
  Upload,
  CheckCircle,
} from "lucide-react";
import toast from "react-hot-toast";
import { isAxiosError } from "axios";
import { cn } from "@/lib/utils";
import { useT } from "@/contexts/LanguageContext";
import type { User } from "@/lib/users";
import { fetchVehicles, type Vehicle } from "@/lib/vehicles";
import { approveCourier } from "@/lib/courier-approvals";
import { ALLOWED_IMAGE_ACCEPT, validateImageFile } from "@/lib/file-upload";
import { sendCourierApprovalNotification } from "@/lib/notifications";
import {
  fetchCourierProfile,
  updateCourierProfile,
  updateCourierDocuments,
  type UpdateCourierProfileData,
} from "@/lib/courier-profile";

interface Props {
  user: User;
  onClose: () => void;
}

type Tab = "profile" | "documents";

/** File fields accepted by PATCH /profile/update-documents. */
const DOCUMENT_FIELDS = [
  "personal_photo",
  "national_id_photo_front",
  "national_id_photo_back",
  "vehicle_license_front",
  "vehicle_license_back",
  "courier_license_front",
  "courier_license_back",
  "courier_criminal_record",
] as const;
type DocField = (typeof DOCUMENT_FIELDS)[number];

const DOC_LABELS: Record<DocField, string> = {
  personal_photo: "Personal Photo",
  national_id_photo_front: "National ID — Front",
  national_id_photo_back: "National ID — Back",
  vehicle_license_front: "Vehicle License — Front",
  vehicle_license_back: "Vehicle License — Back",
  courier_license_front: "Courier License — Front",
  courier_license_back: "Courier License — Back",
  courier_criminal_record: "Criminal Record",
};

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

/** EGP (display) → cents (API). */
function egpToCents(v: string): number | undefined {
  const n = Number(v);
  if (!v.trim() || Number.isNaN(n)) return undefined;
  return Math.round(n * 100);
}

export default function EditCourierModal({ user, onClose }: Props) {
  const qc = useQueryClient();
  const { t } = useT();
  const [tab, setTab] = useState<Tab>("profile");

  const courierId = user.courier?.id ?? null;

  // Full courier profile — enriches prefill (vehicle_id, prices) beyond what the
  // users table row carries. Falls back to the row data if it fails to load.
  const { data: profile, isLoading: profileLoading } = useQuery({
    queryKey: ["courier-profile", user.id],
    queryFn: () => fetchCourierProfile(user.id),
    enabled: !!user.id,
  });
  const courier = profile?.courier ?? user.courier ?? null;

  // Existing document image URLs — read from the admin-API user/courier (the
  // same source the Courier Details "Documents" section uses); the courier-API
  // profile may omit them. personal_photo lives on the user, not the courier.
  const documentUrls: Partial<Record<DocField, string | null | undefined>> = {
    personal_photo: user.personal_photo ?? profile?.personal_photo,
    national_id_photo_front:
      user.courier?.national_id_photo_front ??
      profile?.courier?.national_id_photo_front,
    national_id_photo_back:
      user.courier?.national_id_photo_back ??
      profile?.courier?.national_id_photo_back,
    vehicle_license_front:
      user.courier?.vehicle_license_front ??
      profile?.courier?.vehicle_license_front,
    vehicle_license_back:
      user.courier?.vehicle_license_back ??
      profile?.courier?.vehicle_license_back,
    courier_license_front:
      user.courier?.courier_license_front ??
      profile?.courier?.courier_license_front,
    courier_license_back:
      user.courier?.courier_license_back ??
      profile?.courier?.courier_license_back,
    courier_criminal_record:
      user.courier?.courier_criminal_record ??
      profile?.courier?.courier_criminal_record,
  };

  const { data: vehiclesData } = useQuery({
    queryKey: ["vehicles"],
    queryFn: () => fetchVehicles({ limit: 1000 }),
  });
  const vehicles = vehiclesData?.vehicles ?? [];

  const invalidate = () => {
    qc.invalidateQueries({ queryKey: ["users"] });
    qc.invalidateQueries({ queryKey: ["courier-profile", user.id] });
  };

  // ── Approval (preserved from the previous edit modal) ──────────────────────
  const [isApproved, setIsApproved] = useState(user.courier?.is_approved ?? false);
  const approveMut = useMutation({
    mutationFn: (cid: number) => approveCourier(cid),
    onSuccess: () => {
      setIsApproved(true);
      invalidate();
      toast.success("Courier approved!");
      sendCourierApprovalNotification(user.id).catch(() => {});
    },
    onError: (e) => toast.error(apiErrorMessage(e, "Approval failed")),
  });

  const profileMut = useMutation({
    mutationFn: (data: UpdateCourierProfileData) =>
      updateCourierProfile(user.id, data),
    onSuccess: (data) => {
      console.log("[EditCourierModal] update profile response →", {
        userId: user.id,
        data,
      });
      toast.success(t("userForm.updated"));
      invalidate();
      onClose();
    },
    onError: (e) => {
      console.error("[EditCourierModal] update profile failed →", {
        userId: user.id,
        error: isAxiosError(e) ? e.response?.data : e,
      });
      toast.error(apiErrorMessage(e, "Failed to update profile"));
    },
  });

  const documentsMut = useMutation({
    mutationFn: (data: FormData) => updateCourierDocuments(user.id, data),
    onSuccess: (data) => {
      console.log("[EditCourierModal] update documents response →", {
        userId: user.id,
        data,
      });
      toast.success("Documents updated successfully");
      invalidate();
      onClose();
    },
    onError: (e) => {
      console.error("[EditCourierModal] update documents failed →", {
        userId: user.id,
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
      <div className="bg-white rounded-xl w-full max-w-3xl max-h-[90vh] overflow-y-auto">
        {/* Header */}
        <div className="flex items-center justify-between p-6 border-b border-gray-200 sticky top-0 bg-white z-10">
          <h2 className="text-xl font-semibold text-gray-900 flex items-center gap-2">
            <Truck size={20} className="text-green-600" />
            Edit Courier
            <span className="text-base font-normal text-gray-500">
              · {user.full_name}
            </span>
          </h2>
          <button
            onClick={onClose}
            className="p-2 hover:bg-gray-100 rounded-lg transition"
            disabled={profileMut.isPending || documentsMut.isPending}
          >
            <X size={20} />
          </button>
        </div>

        {/* Approval banner */}
        {courierId && (
          <div className="flex items-center justify-between px-6 py-3 bg-green-50 border-b border-green-100">
            <div>
              <p className="text-sm font-medium text-gray-700">Approval Status</p>
              <p className="text-xs text-gray-500">
                {isApproved
                  ? "This courier is approved to work"
                  : "Pending — not yet approved"}
              </p>
            </div>
            {isApproved ? (
              <span className="inline-flex items-center gap-1 px-3 py-1.5 rounded-lg text-xs font-semibold bg-green-100 text-green-700">
                <CheckCircle size={12} /> Approved
              </span>
            ) : (
              <button
                type="button"
                onClick={() => approveMut.mutate(courierId)}
                disabled={approveMut.isPending}
                className="flex items-center gap-1.5 px-3 py-1.5 bg-green-600 hover:bg-green-700 text-white rounded-lg text-xs font-semibold transition disabled:opacity-60"
              >
                {approveMut.isPending ? (
                  <Loader2 size={12} className="animate-spin" />
                ) : (
                  <CheckCircle size={12} />
                )}
                Approve Now
              </button>
            )}
          </div>
        )}

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

        {profileLoading ? (
          <div className="p-12 flex items-center justify-center">
            <Loader2 size={28} className="animate-spin text-indigo-600" />
          </div>
        ) : (
          <>
            <div className={cn(tab !== "profile" && "hidden")}>
              <ProfileTab
                user={user}
                courier={courier}
                vehicles={vehicles}
                isLoading={profileMut.isPending}
                onSubmit={(data) => profileMut.mutate(data)}
                onCancel={onClose}
              />
            </div>
            <div className={cn(tab !== "documents" && "hidden")}>
              <DocumentsTab
                currentUrls={documentUrls}
                isLoading={documentsMut.isPending}
                onSubmit={(data) => documentsMut.mutate(data)}
                onCancel={onClose}
              />
            </div>
          </>
        )}
      </div>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Profile tab — PATCH /profile/update-profile/:userId
// ─────────────────────────────────────────────────────────────────────────────
function ProfileTab({
  user,
  courier,
  vehicles,
  isLoading,
  onSubmit,
  onCancel,
}: {
  user: User;
  courier: { vehicle_id?: number | null; vehicle_plate?: string | null; min_order_price?: number | null; max_order_price?: number | null } | null;
  vehicles: Vehicle[];
  isLoading: boolean;
  onSubmit: (data: UpdateCourierProfileData) => void;
  onCancel: () => void;
}) {
  const { lang } = useT();
  const centsToEgp = (v?: number | null) =>
    v != null ? String(v / 100) : "";

  const [form, setForm] = useState({
    full_name: user.full_name ?? "",
    gender: user.gender ?? "",
    language: user.lang ?? "EN",
    vehicle_id: courier?.vehicle_id != null ? String(courier.vehicle_id) : "",
    vehicle_plate: courier?.vehicle_plate ?? "",
    min_order_price: centsToEgp(courier?.min_order_price),
    max_order_price: centsToEgp(courier?.max_order_price),
  });

  const set =
    (k: keyof typeof form) =>
    (e: ChangeEvent<HTMLInputElement | HTMLSelectElement>) =>
      setForm((f) => ({ ...f, [k]: e.target.value }));

  const inputCls =
    "w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-indigo-500 outline-none bg-white";
  const labelCls = "block text-sm font-medium text-gray-700 mb-1";

  function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    const data: UpdateCourierProfileData = {};
    if (form.full_name.trim()) data.full_name = form.full_name.trim();
    if (form.gender === "MALE" || form.gender === "FEMALE")
      data.gender = form.gender;
    if (form.language === "AR" || form.language === "EN") {
      data.language = form.language;
      data.lang = form.language;
    }
    if (form.vehicle_id) data.vehicle_id = form.vehicle_id;
    if (form.vehicle_plate.trim()) data.vehicle_plate = form.vehicle_plate.trim();
    const min = egpToCents(form.min_order_price);
    if (min !== undefined) data.min_order_price = min;
    const max = egpToCents(form.max_order_price);
    if (max !== undefined) data.max_order_price = max;
    onSubmit(data);
  }

  return (
    <form onSubmit={handleSubmit} className="p-6 space-y-5">
      <div>
        <label className={labelCls}>Full Name</label>
        <input value={form.full_name} onChange={set("full_name")} className={inputCls} />
      </div>

      <div className="grid grid-cols-2 gap-4">
        <div>
          <label className={labelCls}>Gender</label>
          <select value={form.gender} onChange={set("gender")} className={inputCls}>
            <option value="">Not specified</option>
            <option value="MALE">Male</option>
            <option value="FEMALE">Female</option>
          </select>
        </div>
        <div>
          <label className={labelCls}>Language</label>
          <select value={form.language} onChange={set("language")} className={inputCls}>
            <option value="EN">English</option>
            <option value="AR">Arabic</option>
          </select>
        </div>
      </div>

      <div className="grid grid-cols-2 gap-4">
        <div>
          <label className={labelCls}>Vehicle</label>
          <select value={form.vehicle_id} onChange={set("vehicle_id")} className={inputCls}>
            <option value="">— Select vehicle —</option>
            {vehicles.map((v) => (
              <option key={v.id} value={v.id}>
                {lang === "AR" ? v.name_ar : v.name}
              </option>
            ))}
          </select>
        </div>
        <div>
          <label className={labelCls}>Vehicle Plate</label>
          <input value={form.vehicle_plate} onChange={set("vehicle_plate")} className={inputCls} />
        </div>
      </div>

      <div className="grid grid-cols-2 gap-4">
        <div>
          <label className={labelCls}>Min Order Price (EGP)</label>
          <input
            type="number"
            step="0.01"
            min="0"
            value={form.min_order_price}
            onChange={set("min_order_price")}
            className={inputCls}
            placeholder="0.00"
          />
        </div>
        <div>
          <label className={labelCls}>Max Order Price (EGP)</label>
          <input
            type="number"
            step="0.01"
            min="0"
            value={form.max_order_price}
            onChange={set("max_order_price")}
            className={inputCls}
            placeholder="0.00"
          />
        </div>
      </div>

      <div className="flex justify-end gap-3 pt-4 border-t border-gray-200">
        <button
          type="button"
          onClick={onCancel}
          disabled={isLoading}
          className="px-4 py-2 text-gray-700 bg-gray-100 hover:bg-gray-200 rounded-lg font-medium transition"
        >
          Cancel
        </button>
        <button
          type="submit"
          disabled={isLoading}
          className="flex items-center gap-2 px-4 py-2 bg-indigo-600 hover:bg-indigo-700 text-white rounded-lg font-medium transition disabled:opacity-50"
        >
          {isLoading && <Loader2 size={16} className="animate-spin" />}
          {isLoading ? "Saving..." : "Update Profile"}
        </button>
      </div>
    </form>
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Documents tab — PATCH /profile/update-documents/:userId (multipart)
// ─────────────────────────────────────────────────────────────────────────────
function DocumentsTab({
  currentUrls,
  isLoading,
  onSubmit,
  onCancel,
}: {
  currentUrls: Partial<Record<DocField, string | null | undefined>>;
  isLoading: boolean;
  onSubmit: (data: FormData) => void;
  onCancel: () => void;
}) {
  const [files, setFiles] = useState<Partial<Record<DocField, File>>>({});
  const inputRefs = useRef<Record<DocField, HTMLInputElement | null>>(
    {} as Record<DocField, HTMLInputElement | null>,
  );

  const hasChanges = Object.keys(files).length > 0;

  const pick = (field: DocField) => (e: ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (file && validateImageFile(file, e.target))
      setFiles((prev) => ({ ...prev, [field]: file }));
  };
  const remove = (field: DocField) =>
    setFiles((prev) => {
      const next = { ...prev };
      delete next[field];
      return next;
    });

  function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    const fd = new FormData();
    for (const field of DOCUMENT_FIELDS) {
      const f = files[field];
      if (f) fd.append(field, f);
    }
    onSubmit(fd);
  }

  return (
    <form onSubmit={handleSubmit} className="p-6 space-y-6">
      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        {DOCUMENT_FIELDS.map((field) => {
          const selected = files[field];
          const currentUrl = currentUrls[field];
          return (
            <div key={field} className="space-y-2">
              <label className="block text-sm font-medium text-gray-700">
                {DOC_LABELS[field]}
              </label>

              {selected ? (
                <div className="flex items-center gap-3 p-3 bg-amber-50 rounded-lg border border-amber-200">
                  {/* eslint-disable-next-line @next/next/no-img-element */}
                  <img
                    src={URL.createObjectURL(selected)}
                    alt={DOC_LABELS[field]}
                    className="w-16 h-16 object-cover rounded-lg"
                  />
                  <div className="flex-1 min-w-0">
                    <p className="text-xs font-medium text-amber-700">New file</p>
                    <p className="text-sm font-medium text-gray-900 truncate">
                      {selected.name}
                    </p>
                  </div>
                  <button
                    type="button"
                    onClick={() => remove(field)}
                    className="p-1.5 text-red-500 hover:bg-red-50 rounded-lg transition"
                    disabled={isLoading}
                  >
                    <X size={16} />
                  </button>
                </div>
              ) : (
                <div className="space-y-2">
                  {currentUrl && (
                    <div className="flex items-center gap-3 p-3 bg-gray-50 rounded-lg border border-gray-200">
                      {/* eslint-disable-next-line @next/next/no-img-element */}
                      <img
                        src={currentUrl}
                        alt={`Current ${DOC_LABELS[field]}`}
                        className="w-16 h-16 object-cover rounded-lg border border-gray-200"
                      />
                      <div className="flex-1 min-w-0">
                        <p className="text-xs text-gray-500">Current</p>
                        <a
                          href={currentUrl}
                          target="_blank"
                          rel="noopener noreferrer"
                          className="text-sm font-medium text-indigo-600 hover:underline"
                        >
                          View file
                        </a>
                      </div>
                    </div>
                  )}
                  <button
                    type="button"
                    onClick={() => inputRefs.current[field]?.click()}
                    className="w-full p-4 border-2 border-dashed border-gray-300 rounded-lg hover:border-indigo-500 hover:bg-indigo-50 transition flex flex-col items-center gap-2"
                    disabled={isLoading}
                  >
                    <Upload size={20} className="text-gray-400" />
                    <span className="text-sm text-gray-600">
                      {currentUrl ? "Replace file" : "Click to upload"}
                    </span>
                  </button>
                </div>
              )}

              <input
                ref={(el) => {
                  inputRefs.current[field] = el;
                }}
                type="file"
                accept={ALLOWED_IMAGE_ACCEPT}
                onChange={pick(field)}
                className="hidden"
              />
            </div>
          );
        })}
      </div>

      <div className="flex justify-end gap-3 pt-4 border-t border-gray-200">
        <button
          type="button"
          onClick={onCancel}
          disabled={isLoading}
          className="px-4 py-2 text-gray-700 bg-gray-100 hover:bg-gray-200 rounded-lg font-medium transition"
        >
          Cancel
        </button>
        <button
          type="submit"
          disabled={isLoading || !hasChanges}
          className="flex items-center gap-2 px-4 py-2 bg-indigo-600 hover:bg-indigo-700 text-white rounded-lg font-medium transition disabled:opacity-50 disabled:cursor-not-allowed"
        >
          {isLoading && <Loader2 size={16} className="animate-spin" />}
          {isLoading ? "Uploading..." : "Update Documents"}
        </button>
      </div>
    </form>
  );
}
