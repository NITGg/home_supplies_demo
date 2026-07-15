"use client";
import { useState } from "react";
import { X, Upload, User as UserIcon, CheckCircle, Building, Loader2, Eye, EyeOff } from "lucide-react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import {
  createUser,
  updateUser,
  fetchRoles,
  fetchBadgesByRoleId,
  type User,
  type UserBadge,
} from "@/lib/users";
import { fetchCourierOffices, assignCourierToOffice } from "@/lib/courier-offices";
import { approveCourier } from "@/lib/courier-approvals";
import { sendCourierApprovalNotification } from "@/lib/notifications";
import toast from "react-hot-toast";
import { cn } from "@/lib/utils";
import { useT } from "@/contexts/LanguageContext";
import { ALLOWED_IMAGE_ACCEPT, validateImageFile } from "@/lib/file-upload";

interface Props {
  user?: User;
  onClose: () => void;
  /** Pre-selected, locked role for create flows (e.g. Create Customer / Courier). */
  presetRoleId?: number;
  /** TEMP DEBUG — fires with the raw server response after an edit succeeds. */
  onUpdated?: (data: unknown) => void;
}

/**
 * Appends a boolean to FormData so the API's `z.coerce.boolean()` parser reads
 * it correctly. That parser runs JS `Boolean()` on the raw multipart string, so
 * any non-empty string (including "false") becomes `true` — the only string it
 * reads as `false` is "". So we send "true" for true and "" (empty) for false.
 */
function appendBool(fd: FormData, key: string, value: boolean) {
  fd.append(key, value ? "true" : "");
}

/** TEMP DEBUG — dumps every FormData field. Remove once the update flow is verified. */
function logFormData(fd: FormData, label: string) {
  const entries: Record<string, string> = {};
  for (const [k, v] of fd.entries()) {
    entries[k] =
      v instanceof File ? `File(${v.name}, ${v.size}b)` : JSON.stringify(v);
  }
  console.log(`[UserForm][${label}] outgoing FormData →`, entries);
}

export default function UserForm({ user, onClose, presetRoleId, onUpdated }: Props) {
  const qc = useQueryClient();
  const { t } = useT();
  const isEdit = !!user;
  // When a role is preset (Create Customer / Courier), hide & lock the role select.
  const roleLocked = !isEdit && presetRoleId != null;

  const [form, setForm] = useState({
    full_name: user?.full_name || "",
    email: user?.email || "",
    phone: user?.phone || "",
    password: "",
    gender: user?.gender || "",
    role_id: user?.role_id?.toString() || (presetRoleId != null ? String(presetRoleId) : ""),
    badge_id: user?.badge_id?.toString() || "",
    is_active: user?.is_active ?? true,
    is_email_verified: user?.is_email_verified ?? false,
    is_phone_verified: user?.is_phone_verified ?? false,
    lang: user?.lang || "EN",
  });
  const [photoFile, setPhotoFile] = useState<File | null>(null);
  const [photoPreview, setPhotoPreview] = useState<string | null>(
    user?.personal_photo || null,
  );
  const [deletePhoto, setDeletePhoto] = useState(false);
  const [showPassword, setShowPassword] = useState(false);

  // Courier-specific state
  const courierId = user?.courier?.id ?? null;
  const [selectedOfficeId, setSelectedOfficeId] = useState<string>(
    user?.courier?.courier_office_id ? String(user.courier.courier_office_id) : ""
  );
  const [isApproved, setIsApproved] = useState(user?.courier?.is_approved ?? false);

  const { data: rolesData } = useQuery({
    queryKey: ["roles"],
    queryFn: fetchRoles,
  });
  const roles = Array.isArray(rolesData) ? rolesData : [];

  // Courier offices (only fetched when editing a courier)
  const isCourierRole = roles.find(r => String(r.id) === form.role_id)?.name?.toLowerCase() === "courier";
  const { data: officesData } = useQuery({
    queryKey: ["courier-offices-form"],
    queryFn: () => fetchCourierOffices({ limit: 200 }),
    enabled: isEdit && isCourierRole,
    staleTime: 5 * 60_000,
  });
  const offices = officesData?.couriers ?? [];

  // Fetch badges based on selected role
  const { data: badgesData } = useQuery({
    queryKey: ["badges", form.role_id],
    queryFn: () => fetchBadgesByRoleId(Number(form.role_id)),
    enabled: !!form.role_id,
  });
  const availableBadges: UserBadge[] = Array.isArray(badgesData)
    ? badgesData
    : [];

  const approveMut = useMutation({
    mutationFn: (cid: number) => approveCourier(cid),
    onSuccess: () => {
      setIsApproved(true);
      qc.invalidateQueries({ queryKey: ["users"] });
      toast.success("Courier approved!");
      if (user) sendCourierApprovalNotification(user.id).catch(() => {});
    },
    onError: (e: any) => toast.error(e?.response?.data?.message ?? "Approval failed"),
  });

  const assignOfficeMut = useMutation({
    mutationFn: ({ cid, oid }: { cid: number; oid: number }) => assignCourierToOffice(cid, oid),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["users"] });
      toast.success("Office assigned!");
    },
    onError: (e: any) => toast.error(e?.response?.data?.message ?? "Office assignment failed"),
  });

  const mutation = useMutation({
    mutationFn: (fd: FormData) =>
      isEdit ? updateUser(user!.id, fd) : createUser(fd),
    onSuccess: (data) => {
      console.log("[UserForm] server response →", data);
      if (isEdit) onUpdated?.(data);
      qc.invalidateQueries({ queryKey: ["users"] });
      toast.success(isEdit ? t("userForm.updated") : t("userForm.created"));
      onClose();
    },
    onError: (err: any) => {
      console.error("[UserForm] request failed →", err?.response?.data ?? err);
      toast.error(err.response?.data?.message || "Error");
    },
  });

  function handlePhoto(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0];
    if (!file) return;
    if (!validateImageFile(file, e.target)) return;
    setPhotoFile(file);
    setPhotoPreview(URL.createObjectURL(file));
    setDeletePhoto(false);
  }

  function removePhoto() {
    setPhotoFile(null);
    setPhotoPreview(null);
    setDeletePhoto(true);
  }

  function handleRoleChange(e: React.ChangeEvent<HTMLSelectElement>) {
    const newRoleId = e.target.value;
    setForm((f) => ({ ...f, role_id: newRoleId, badge_id: "" }));
  }

  function normalizeEgPhone(raw: string): string {
    let p = raw.trim().replace(/[\s\-()]/g, "");
    if (!p) return p;
    if (p.startsWith("+20")) p = p.slice(3);
    else if (p.startsWith("0020")) p = p.slice(4);
    else if (p.startsWith("20")) p = p.slice(2);
    else if (p.startsWith("0")) p = p.slice(1);
    return `+20${p}`;
  }

  const handlePhoneBlur = () => {
    setForm((f) => ({ ...f, phone: normalizeEgPhone(f.phone) }));
  };

  function handleSubmit(e: React.FormEvent) {
    e.preventDefault();

    // ── Update (PUT /users/:id) — only the fields the update schema accepts ──
    if (isEdit) {
      const fd = new FormData();
      fd.append("full_name", form.full_name);
      if (form.gender) fd.append("gender", form.gender);
      if (form.badge_id) fd.append("badge_id", form.badge_id);
      appendBool(fd, "is_active", form.is_active);
      fd.append("lang", form.lang);
      if (photoFile) fd.append("photo", photoFile);
      if (deletePhoto) fd.append("deleteImage", "true");
      console.log("[UserForm][edit] state →", {
        userId: user!.id,
        is_active: form.is_active,
        deletePhoto,
        hasPhotoFile: !!photoFile,
      });
      logFormData(fd, "edit");
      mutation.mutate(fd);
      return;
    }

    // ── Create (POST /users) ─────────────────────────────────────────────────
    if (!form.role_id) {
      toast.error(t("userForm.roleRequired"));
      return;
    }
    if (!form.password) {
      toast.error(t("userForm.passwordRequired"));
      return;
    }
    if (!form.phone) {
      toast.error(t("userForm.phoneRequired"));
      return;
    }

    const normalizedPhone = normalizeEgPhone(form.phone);

    const fd = new FormData();
    fd.append("full_name", form.full_name);
    if (form.email) fd.append("email", form.email);
    fd.append("phone", normalizedPhone);
    fd.append("password", form.password);
    if (form.gender) fd.append("gender", form.gender);
    fd.append("role_id", form.role_id);
    if (form.badge_id) fd.append("badge_id", form.badge_id);
    appendBool(fd, "is_active", form.is_active);
    appendBool(fd, "is_email_verified", form.is_email_verified);
    appendBool(fd, "is_phone_verified", form.is_phone_verified);
    fd.append("lang", form.lang);
    if (photoFile) fd.append("photo", photoFile);
    logFormData(fd, "create");
    mutation.mutate(fd);
  }

  const set =
    (k: string) =>
    (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement>) =>
      setForm((f) => ({ ...f, [k]: e.target.value }));

  // Submit stays disabled until the form has the data it needs.
  const canSubmit =
    !!form.full_name.trim() &&
    !!form.role_id &&
    (isEdit || (!!form.password && !!form.phone.trim()));

  const inputCls =
    "w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-indigo-500 outline-none";
  const labelCls = "block text-sm font-medium text-gray-700 mb-1";

  return (
    <div className="fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-4">
      <div className="bg-white rounded-2xl shadow-2xl w-full max-w-xl max-h-[90vh] overflow-y-auto">
        {/* Header */}
        <div className="flex items-center justify-between px-6 py-4 border-b sticky top-0 bg-white z-10">
          <h2 className="text-lg font-semibold text-gray-900">
            {isEdit ? t("users.edit") : t("users.new")}
          </h2>
          <button
            onClick={onClose}
            className="p-1.5 hover:bg-gray-100 rounded-lg"
          >
            <X size={18} />
          </button>
        </div>

        <form onSubmit={handleSubmit} className="p-6 space-y-5">
          {/* Photo */}
          <div className="flex items-center gap-4">
            <div className="relative w-16 h-16 rounded-full overflow-hidden bg-gray-100 flex items-center justify-center border-2 border-gray-200">
              {photoPreview ? (
                <img
                  src={photoPreview}
                  alt="photo"
                  className="absolute inset-0 w-full h-full object-cover"
                />
              ) : (
                <UserIcon size={28} className="text-gray-400" />
              )}
            </div>
            <div className="flex gap-2">
              <label className="cursor-pointer flex items-center gap-1.5 px-3 py-1.5 border border-gray-300 rounded-lg text-sm hover:bg-gray-50 transition">
                <Upload size={14} /> {t("common.uploadPhoto")}
                <input
                  type="file"
                  accept={ALLOWED_IMAGE_ACCEPT}
                  className="hidden"
                  onChange={handlePhoto}
                />
              </label>
              {photoPreview && (
                <button
                  type="button"
                  onClick={removePhoto}
                  className="px-3 py-1.5 border border-red-200 text-red-500 rounded-lg text-sm hover:bg-red-50 transition"
                >
                  {t("common.remove")}
                </button>
              )}
            </div>
          </div>

          {/* Full Name */}
          <div>
            <label className={labelCls}>{t("userForm.fullName")} *</label>
            <input
              required
              value={form.full_name}
              onChange={set("full_name")}
              className={inputCls}
              placeholder="John Doe"
            />
          </div>

          {/* Phone & Email — hidden when editing */}
          {!isEdit && (
            <div className="grid grid-cols-2 gap-4">
              <div>
                <label className={labelCls}>
                  {t("userForm.phone")} *
                </label>
                <input
                  value={form.phone}
                  onChange={set("phone")}
                  onBlur={handlePhoneBlur}
                  required
                  className={inputCls}
                  placeholder="+201012345678"
                />
              </div>
              <div>
                <label className={labelCls}>{t("userForm.email")}</label>
                <input
                  type="email"
                  value={form.email}
                  onChange={set("email")}
                  className={inputCls}
                  placeholder="user@example.com"
                />
              </div>
            </div>
          )}

          {/* Password — hidden when editing */}
          {!isEdit && (
            <div>
              <label className={labelCls}>
                {t("userForm.password")} *
              </label>
              <div className="relative">
                <input
                  type={showPassword ? "text" : "password"}
                  value={form.password}
                  onChange={set("password")}
                  required
                  className={cn(inputCls, "pr-10")}
                  placeholder="Min 6 characters"
                />
                <button
                  type="button"
                  onClick={() => setShowPassword((p) => !p)}
                  className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400 hover:text-gray-600 transition"
                >
                  {showPassword ? <EyeOff size={16} /> : <Eye size={16} />}
                </button>
              </div>
            </div>
          )}

          {/* Role & Badge — role hidden when editing or preset */}
          <div className="grid grid-cols-2 gap-4">
            {!isEdit && !roleLocked && (
              <div>
                <label className={labelCls}>{t("userForm.role")} *</label>
                <select
                  required
                  value={form.role_id}
                  onChange={handleRoleChange}
                  className={inputCls}
                >
                  <option value="">{t("userForm.selectRole")}</option>
                  {roles.map((r) => (
                    <option key={r.id} value={r.id}>
                      {r.name}
                    </option>
                  ))}
                </select>
              </div>
            )}
            <div>
              <label className={labelCls}>{t("userForm.badge")}</label>
              <select
                value={form.badge_id}
                onChange={set("badge_id")}
                disabled={!form.role_id}
                className={cn(
                  inputCls,
                  !form.role_id && "opacity-50 cursor-not-allowed",
                )}
              >
                <option value="">
                  {!form.role_id
                    ? t("userForm.selectRoleFirst")
                    : t("userForm.selectBadge")}
                </option>
                {availableBadges.map((b) => (
                  <option key={b.id} value={b.id}>
                    {b.name}
                  </option>
                ))}
              </select>
            </div>
          </div>

          {/* Gender & Language */}
          <div className="grid grid-cols-2 gap-4">
            <div>
              <label className={labelCls}>{t("userForm.gender")}</label>
              <select
                value={form.gender}
                onChange={set("gender")}
                className={inputCls}
              >
                <option value="">{t("userForm.notSpecified")}</option>
                <option value="MALE">{t("userForm.male")}</option>
                <option value="FEMALE">{t("userForm.female")}</option>
              </select>
            </div>
            <div>
              <label className={labelCls}>{t("userForm.language")}</label>
              <select
                value={form.lang}
                onChange={set("lang")}
                className={inputCls}
              >
                <option value="EN">{t("userForm.english")}</option>
                <option value="AR">{t("userForm.arabic")}</option>
              </select>
            </div>
          </div>

          {/* Status & Verification Checkboxes */}
          <div className="space-y-3">
            {/* Status is only settable on create (hidden in edit customer/courier modals) */}
            {!isEdit && (
              <div>
                <label className={labelCls}>{t("userForm.status")}</label>
                <select
                  value={String(form.is_active)}
                  onChange={(e) =>
                    setForm((f) => ({
                      ...f,
                      is_active: e.target.value === "true",
                    }))
                  }
                  className={inputCls}
                >
                  <option value="true">{t("common.active")}</option>
                  <option value="false">{t("common.inactive")}</option>
                </select>
              </div>
            )}
            {/* Verification flags are only settable on create (not in the update schema) */}
            {!isEdit && (
              <div className="flex flex-wrap gap-4">
                <label className="flex items-center gap-2 text-sm text-gray-700">
                  <input
                    type="checkbox"
                    checked={form.is_email_verified}
                    onChange={(e) =>
                      setForm((f) => ({
                        ...f,
                        is_email_verified: e.target.checked,
                      }))
                    }
                    className="rounded border-gray-300 text-indigo-600 focus:ring-indigo-500"
                  />
                  {t("userForm.emailVerified")}
                </label>
                <label className="flex items-center gap-2 text-sm text-gray-700">
                  <input
                    type="checkbox"
                    checked={form.is_phone_verified}
                    onChange={(e) =>
                      setForm((f) => ({
                        ...f,
                        is_phone_verified: e.target.checked,
                      }))
                    }
                    className="rounded border-gray-300 text-indigo-600 focus:ring-indigo-500"
                  />
                  {t("userForm.phoneVerified")}
                </label>
              </div>
            )}
          </div>

          {/* ── Courier Settings (only when editing a courier with a courier record) ── */}
          {isEdit && isCourierRole && courierId && (
            <div className="border border-green-200 rounded-xl bg-green-50 p-4 space-y-4">
              <p className="text-sm font-semibold text-green-800 flex items-center gap-2">
                <CheckCircle size={15} className="text-green-600" />
                Courier Settings
              </p>

              {/* Approval */}
              <div className="flex items-center justify-between">
                <div>
                  <p className="text-sm font-medium text-gray-700">Approval Status</p>
                  <p className="text-xs text-gray-500 mt-0.5">
                    {isApproved ? "This courier is approved to work" : "Pending — not yet approved"}
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
                    {approveMut.isPending ? <Loader2 size={12} className="animate-spin" /> : <CheckCircle size={12} />}
                    Approve Now
                  </button>
                )}
              </div>

              {/* Office Assignment */}
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1.5">
                  <Building size={13} className="inline mr-1 text-gray-400" />
                  Courier Office
                </label>
                <div className="flex gap-2">
                  <select
                    value={selectedOfficeId}
                    onChange={e => setSelectedOfficeId(e.target.value)}
                    className="flex-1 border border-gray-300 rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-indigo-500 outline-none bg-white"
                  >
                    <option value="">— No office —</option>
                    {offices.map(o => (
                      <option key={o.id} value={o.id}>{o.name}</option>
                    ))}
                  </select>
                  <button
                    type="button"
                    disabled={!selectedOfficeId || assignOfficeMut.isPending}
                    onClick={() => {
                      if (selectedOfficeId)
                        assignOfficeMut.mutate({ cid: courierId, oid: Number(selectedOfficeId) });
                    }}
                    className="px-3 py-2 bg-indigo-600 hover:bg-indigo-700 text-white rounded-lg text-xs font-semibold transition disabled:opacity-50"
                  >
                    {assignOfficeMut.isPending ? <Loader2 size={13} className="animate-spin" /> : "Assign"}
                  </button>
                </div>
              </div>
            </div>
          )}

          {/* Actions */}
          <div className="flex gap-3 pt-2">
            <button
              type="button"
              onClick={onClose}
              className="flex-1 border border-gray-300 rounded-lg py-2.5 text-sm font-medium hover:bg-gray-50 transition"
            >
              {t("common.cancel")}
            </button>
            <button
              type="submit"
              disabled={mutation.isPending || !canSubmit}
              className="flex-1 bg-indigo-600 hover:bg-indigo-700 text-white rounded-lg py-2.5 text-sm font-medium disabled:opacity-60 disabled:cursor-not-allowed transition"
            >
              {mutation.isPending
                ? t("common.saving")
                : isEdit
                  ? t("common.update") + " " + t("users.edit").split(" ")[1]
                  : t("users.new")}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
