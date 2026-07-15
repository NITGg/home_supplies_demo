"use client";

import { useState, useRef, useEffect, ChangeEvent } from "react";
import { useMutation, useQueryClient } from "@tanstack/react-query";
import {
  X,
  Loader2,
  Upload,
  Eye,
  EyeOff,
  ShieldCheck,
  Trash2,
} from "lucide-react";
import { isAxiosError } from "axios";
import toast from "react-hot-toast";
import { cn } from "@/lib/utils";
import { updateUser, type User } from "@/lib/users";
import { ALLOWED_IMAGE_ACCEPT, validateImageFile } from "@/lib/file-upload";

interface EditAdminModalProps {
  isOpen: boolean;
  onClose: () => void;
  user: User;
  /** Label for the role being edited — Admin, Seller, or Customer Support all share this modal. */
  roleLabel?: string;
  /** Whether to show the password field (hidden for Customer rows). */
  showPasswordField?: boolean;
}

const passwordRules = [
  { test: (p: string) => p.length >= 8, label: "At least 8 characters" },
  { test: (p: string) => /[A-Z]/.test(p), label: "One uppercase letter" },
  { test: (p: string) => /[a-z]/.test(p), label: "One lowercase letter" },
  { test: (p: string) => /[0-9]/.test(p), label: "One number" },
];

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

export default function EditAdminModal({
  isOpen,
  onClose,
  user,
  roleLabel = "Admin",
  showPasswordField = true,
}: EditAdminModalProps) {
  const queryClient = useQueryClient();
  const photoRef = useRef<HTMLInputElement>(null);

  // ── Form state ────────────────────────────────────────────────────────────
  const [fullName, setFullName] = useState(user.full_name);
  const [password, setPassword] = useState("");
  const [showPassword, setShowPassword] = useState(false);
  const [gender, setGender] = useState<"" | "MALE" | "FEMALE">(
    user.gender ?? "",
  );
  const [isActive, setIsActive] = useState(user.is_active);
  const [lang, setLang] = useState<"EN" | "AR">(user.lang ?? "EN");

  // Photo
  const [photoFile, setPhotoFile] = useState<File | null>(null);
  const [photoPreview, setPhotoPreview] = useState<string>(
    user.personal_photo ?? "",
  );
  const [deleteImage, setDeleteImage] = useState(false);

  // Reset form when user changes
  useEffect(() => {
    setFullName(user.full_name);
    setPassword("");
    setShowPassword(false);
    setGender(user.gender ?? "");
    setIsActive(user.is_active);
    setLang(user.lang ?? "EN");
    setPhotoFile(null);
    setPhotoPreview(user.personal_photo ?? "");
    setDeleteImage(false);
  }, [user]);

  // ── Validation ────────────────────────────────────────────────────────────
  const nameValid = fullName.trim().length >= 2 && fullName.trim().length <= 100;
  const passwordValid =
    password.length === 0 || passwordRules.every((r) => r.test(password));
  const isFormDirty =
    fullName.trim() !== user.full_name ||
    password.length > 0 ||
    gender !== (user.gender ?? "") ||
    isActive !== user.is_active ||
    lang !== (user.lang ?? "EN") ||
    photoFile !== null ||
    deleteImage;
  const canSubmit = nameValid && passwordValid && isFormDirty;

  // ── Photo handlers ────────────────────────────────────────────────────────
  function handlePhotoChange(e: ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0];
    if (!file) return;
    if (!validateImageFile(file, e.target)) return;
    setPhotoFile(file);
    setPhotoPreview(URL.createObjectURL(file));
    setDeleteImage(false);
  }

  function handleRemovePhoto() {
    if (photoFile) {
      URL.revokeObjectURL(photoPreview);
      setPhotoFile(null);
    }
    setPhotoPreview("");
    setDeleteImage(true);
  }

  // ── Submit ────────────────────────────────────────────────────────────────
  const updateMutation = useMutation({
    mutationFn: () => {
      // With a photo we must use multipart (file field name "photo"); without
      // one we send JSON so the backend actually reads the fields (its sanitize
      // middleware drops multipart text fields — see updateUser docs).
      if (photoFile) {
        const fd = new FormData();
        fd.append("full_name", fullName.trim());
        if (password) fd.append("password", password);
        if (gender) fd.append("gender", gender);
        // Backend coerces multipart booleans via Boolean(string): "" = false.
        fd.append("is_active", isActive ? "true" : "");
        fd.append("lang", lang);
        if (deleteImage) fd.append("deleteImage", "true");
        fd.append("photo", photoFile);
        return updateUser(user.id, fd);
      }

      const body: Record<string, unknown> = {
        full_name: fullName.trim(),
        is_active: isActive,
        lang,
      };
      if (password) body.password = password;
      if (gender) body.gender = gender;
      if (deleteImage) body.deleteImage = true;
      return updateUser(user.id, body);
    },
    onSuccess: (data) => {
      console.log("[EditAdminModal] update admin response →", {
        userId: user.id,
        data,
      });
      toast.success(`${roleLabel} updated successfully`);
      queryClient.invalidateQueries({ queryKey: ["users"] });
      onClose();
    },
    onError: (error: unknown) => {
      console.error("[EditAdminModal] update admin failed →", {
        userId: user.id,
        error: isAxiosError(error) ? error.response?.data : error,
      });
      toast.error(apiErrorMessage(error, `Failed to update ${roleLabel.toLowerCase()}`));
    },
  });

  function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (!canSubmit || updateMutation.isPending) return;
    updateMutation.mutate();
  }

  if (!isOpen) return null;

  const inputCls =
    "w-full px-3 py-2 border rounded-lg text-sm text-gray-900 focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500 outline-none transition";
  const labelCls = "block text-sm font-medium text-gray-700 mb-1";
  const busy = updateMutation.isPending;

  return (
    <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
      <div className="bg-white rounded-2xl shadow-2xl w-full max-w-lg max-h-[90vh] overflow-y-auto">
        {/* Header */}
        <div className="flex items-center justify-between px-6 py-4 border-b border-gray-200 sticky top-0 bg-white z-10">
          <h2 className="text-lg font-semibold text-gray-900 flex items-center gap-2">
            <ShieldCheck size={18} className="text-indigo-600" />
            Edit {roleLabel}
          </h2>
          <button
            onClick={onClose}
            disabled={busy}
            className="p-1.5 hover:bg-gray-100 rounded-lg transition disabled:opacity-50"
          >
            <X size={18} />
          </button>
        </div>

        <form onSubmit={handleSubmit} className="p-6 space-y-5">
          {/* User info banner */}
          <div className="flex items-center gap-3 p-3 bg-gray-50 rounded-xl border border-gray-200">
            {photoPreview ? (
              // eslint-disable-next-line @next/next/no-img-element
              <img
                src={photoPreview}
                alt={user.full_name}
                className="w-12 h-12 rounded-full object-cover border-2 border-gray-200"
              />
            ) : (
              <div className="w-12 h-12 rounded-full bg-indigo-100 flex items-center justify-center text-indigo-700 text-sm font-bold">
                {user.full_name
                  .split(" ")
                  .map((n) => n[0])
                  .slice(0, 2)
                  .join("")
                  .toUpperCase()}
              </div>
            )}
            <div>
              <p className="text-sm font-semibold text-gray-900">
                {user.full_name}
              </p>
              <p className="text-xs text-gray-500">
                ID: {user.id} · {user.email || user.phone}
              </p>
            </div>
          </div>

          {/* Photo upload */}
          <div>
            <label className={labelCls}>Profile Photo</label>
            <div className="flex items-center gap-3">
              {photoPreview ? (
                <div className="relative">
                  {/* eslint-disable-next-line @next/next/no-img-element */}
                  <img
                    src={photoPreview}
                    alt="Preview"
                    className="w-20 h-20 rounded-xl object-cover border-2 border-gray-200"
                  />
                  <button
                    type="button"
                    onClick={handleRemovePhoto}
                    disabled={busy}
                    className="absolute -top-2 -right-2 p-1 bg-red-500 text-white rounded-full hover:bg-red-600 transition disabled:opacity-50"
                  >
                    <Trash2 size={12} />
                  </button>
                </div>
              ) : (
                <button
                  type="button"
                  onClick={() => photoRef.current?.click()}
                  disabled={busy}
                  className="w-20 h-20 border-2 border-dashed border-gray-300 rounded-xl hover:border-indigo-500 hover:bg-indigo-50 transition flex flex-col items-center justify-center gap-1 disabled:opacity-50"
                >
                  <Upload size={18} className="text-gray-400" />
                  <span className="text-[10px] text-gray-500">Upload</span>
                </button>
              )}
              {photoPreview && (
                <button
                  type="button"
                  onClick={() => photoRef.current?.click()}
                  disabled={busy}
                  className="text-sm text-indigo-600 hover:text-indigo-700 font-medium transition disabled:opacity-50"
                >
                  Change photo
                </button>
              )}
            </div>
            <input
              ref={photoRef}
              type="file"
              accept={ALLOWED_IMAGE_ACCEPT}
              onChange={handlePhotoChange}
              className="hidden"
            />
          </div>

          {/* Full name */}
          <div>
            <label className={labelCls}>
              Full Name <span className="text-red-500">*</span>
            </label>
            <input
              type="text"
              value={fullName}
              onChange={(e) => setFullName(e.target.value)}
              className={cn(
                inputCls,
                fullName.length > 0 && !nameValid
                  ? "border-red-400 focus:ring-red-500 focus:border-red-500"
                  : "border-gray-300",
              )}
              placeholder="Full name"
              disabled={busy}
            />
            {fullName.length > 0 && !nameValid && (
              <p className="mt-1 text-xs text-red-600">
                Name must be between 2 and 100 characters
              </p>
            )}
          </div>

          {/* Password (optional) — hidden for Customer rows */}
          {showPasswordField && (
          <div>
            <label className={labelCls}>
              Password{" "}
              <span className="text-xs text-gray-400 font-normal">
                (leave blank to keep current)
              </span>
            </label>
            <div className="relative">
              <input
                type={showPassword ? "text" : "password"}
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                className={cn(inputCls, "pr-10 border-gray-300")}
                placeholder="••••••••"
                disabled={busy}
              />
              <button
                type="button"
                onClick={() => setShowPassword((p) => !p)}
                className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400 hover:text-gray-600 transition"
                tabIndex={-1}
              >
                {showPassword ? <EyeOff size={16} /> : <Eye size={16} />}
              </button>
            </div>
            {password.length > 0 && (
              <ul className="mt-2 space-y-0.5">
                {passwordRules.map((r) => {
                  const ok = r.test(password);
                  return (
                    <li
                      key={r.label}
                      className={cn(
                        "text-xs flex items-center gap-1.5",
                        ok ? "text-green-600" : "text-gray-400",
                      )}
                    >
                      <span>{ok ? "✓" : "•"}</span>
                      {r.label}
                    </li>
                  );
                })}
              </ul>
            )}
          </div>
          )}

          {/* Gender + Language + Active row */}
          <div className="grid grid-cols-3 gap-4">
            <div>
              <label className={labelCls}>Gender</label>
              <select
                value={gender}
                onChange={(e) =>
                  setGender(e.target.value as "" | "MALE" | "FEMALE")
                }
                className={cn(inputCls, "border-gray-300 bg-white")}
                disabled={busy}
              >
                <option value="">Not specified</option>
                <option value="MALE">Male</option>
                <option value="FEMALE">Female</option>
              </select>
            </div>

            <div>
              <label className={labelCls}>Language</label>
              <select
                value={lang}
                onChange={(e) => setLang(e.target.value as "EN" | "AR")}
                className={cn(inputCls, "border-gray-300 bg-white")}
                disabled={busy}
              >
                <option value="EN">English</option>
                <option value="AR">Arabic</option>
              </select>
            </div>

            <div>
              <label className={labelCls}>Status</label>
              <select
                value={isActive ? "true" : "false"}
                onChange={(e) => setIsActive(e.target.value === "true")}
                className={cn(inputCls, "border-gray-300 bg-white")}
                disabled={busy}
              >
                <option value="true">Active</option>
                <option value="false">Inactive</option>
              </select>
            </div>
          </div>

          {/* Actions */}
          <div className="flex gap-3 pt-2 border-t border-gray-200">
            <button
              type="button"
              onClick={onClose}
              disabled={busy}
              className="flex-1 border border-gray-300 rounded-lg py-2.5 text-sm font-medium hover:bg-gray-50 transition disabled:opacity-50"
            >
              Cancel
            </button>
            <button
              type="submit"
              disabled={!canSubmit || busy}
              className="flex-1 flex items-center justify-center gap-2 bg-indigo-600 hover:bg-indigo-700 text-white rounded-lg py-2.5 text-sm font-medium disabled:opacity-50 disabled:cursor-not-allowed transition"
            >
              {busy && <Loader2 size={16} className="animate-spin" />}
              {busy ? "Updating..." : `Update ${roleLabel}`}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
