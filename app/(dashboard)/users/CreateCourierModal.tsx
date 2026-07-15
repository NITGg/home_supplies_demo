"use client";

import { useState, useRef, ChangeEvent } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { X, Loader2, Upload, FileText, Eye, EyeOff, Truck } from "lucide-react";
import { isAxiosError } from "axios";
import toast from "react-hot-toast";
import { cn } from "@/lib/utils";
import { fetchVehicles, type Vehicle } from "@/lib/vehicles";
import { registerCourier } from "@/lib/courier-register";
import { ALLOWED_IMAGE_ACCEPT, validateImageFile } from "@/lib/file-upload";

interface CreateCourierModalProps {
  isOpen: boolean;
  onClose: () => void;
}

interface FilePreview {
  file: File;
  preview: string;
}

type FileField =
  | "personal_photo"
  | "national_id_photo_front"
  | "national_id_photo_back"
  | "vehicle_license_front"
  | "vehicle_license_back"
  | "courier_license_front"
  | "courier_license_back"
  | "courier_criminal_record";

const passwordRules = [
  { test: (p: string) => p.length >= 8, label: "At least 8 characters" },
  { test: (p: string) => /[A-Z]/.test(p), label: "One uppercase letter" },
  { test: (p: string) => /[a-z]/.test(p), label: "One lowercase letter" },
  { test: (p: string) => /[0-9]/.test(p), label: "One number" },
];

function normalizeEgPhone(raw: string): string {
  let p = raw.trim().replace(/[\s\-()]/g, "");
  if (!p) return p;
  if (p.startsWith("+20")) p = p.slice(3);
  else if (p.startsWith("0020")) p = p.slice(4);
  else if (p.startsWith("20")) p = p.slice(2);
  else if (p.startsWith("0")) p = p.slice(1);
  return `+20${p}`;
}

/** Bikes and on-foot couriers don't need vehicle/courier licenses or a plate. */
function vehicleNeedsLicense(vehicle: Vehicle | undefined): boolean {
  if (!vehicle) return false;
  const n = vehicle.name.toLowerCase();
  const noLicense =
    n.includes("bike") || n.includes("foot") || n.includes("cycle");
  return !noLicense;
}

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

export default function CreateCourierModal({
  isOpen,
  onClose,
}: CreateCourierModalProps) {
  const queryClient = useQueryClient();

  const [fullName, setFullName] = useState("");
  const [phone, setPhone] = useState("");
  const [password, setPassword] = useState("");
  const [confirmPassword, setConfirmPassword] = useState("");
  const [showPassword, setShowPassword] = useState(false);
  const [gender, setGender] = useState<"" | "MALE" | "FEMALE">("");
  const [nationalId, setNationalId] = useState("");
  const [vehicleId, setVehicleId] = useState("");
  const [vehiclePlate, setVehiclePlate] = useState("");
  const [files, setFiles] = useState<Partial<Record<FileField, FilePreview>>>({});

  const { data: vehiclesData } = useQuery({
    queryKey: ["vehicles", "courier-create"],
    queryFn: () => fetchVehicles({ limit: 1000 }),
    enabled: isOpen,
  });
  const vehicles = vehiclesData?.vehicles ?? [];
  const selectedVehicle = vehicles.find((v) => String(v.id) === vehicleId);
  const needsLicense = vehicleNeedsLicense(selectedVehicle);

  const fileRefs: Record<FileField, React.RefObject<HTMLInputElement | null>> = {
    personal_photo: useRef<HTMLInputElement>(null),
    national_id_photo_front: useRef<HTMLInputElement>(null),
    national_id_photo_back: useRef<HTMLInputElement>(null),
    vehicle_license_front: useRef<HTMLInputElement>(null),
    vehicle_license_back: useRef<HTMLInputElement>(null),
    courier_license_front: useRef<HTMLInputElement>(null),
    courier_license_back: useRef<HTMLInputElement>(null),
    courier_criminal_record: useRef<HTMLInputElement>(null),
  };

  function reset() {
    setFullName("");
    setPhone("");
    setPassword("");
    setConfirmPassword("");
    setShowPassword(false);
    setGender("");
    setNationalId("");
    setVehicleId("");
    setVehiclePlate("");
    Object.values(files).forEach((f) => f?.preview && URL.revokeObjectURL(f.preview));
    setFiles({});
  }

  const createMutation = useMutation({
    mutationFn: () => {
      const fd = new FormData();
      fd.append("full_name", fullName.trim());
      fd.append("phone", normalizeEgPhone(phone));
      fd.append("password", password);
      if (gender) fd.append("gender", gender);
      fd.append("national_id_number", nationalId.trim());
      fd.append("vehicle_id", vehicleId);
      if (needsLicense && vehiclePlate.trim())
        fd.append("vehicle_plate", vehiclePlate.trim());
      (Object.keys(files) as FileField[]).forEach((field) => {
        const f = files[field];
        if (f) fd.append(field, f.file);
      });
      return registerCourier(fd);
    },
    onSuccess: () => {
      toast.success("Courier created successfully");
      queryClient.invalidateQueries({ queryKey: ["users"] });
      reset();
      onClose();
    },
    onError: (error: unknown) =>
      toast.error(apiErrorMessage(error, "Failed to create courier")),
  });

  function handleFileChange(field: FileField, e: ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0];
    if (!file) return;
    if (!validateImageFile(file, e.target)) return;
    setFiles((prev) => {
      if (prev[field]?.preview) URL.revokeObjectURL(prev[field]!.preview);
      return {
        ...prev,
        [field]: {
          file,
          preview: file.type.startsWith("image/") ? URL.createObjectURL(file) : "",
        },
      };
    });
  }

  function removeFile(field: FileField) {
    setFiles((prev) => {
      const next = { ...prev };
      if (next[field]?.preview) URL.revokeObjectURL(next[field]!.preview);
      delete next[field];
      return next;
    });
  }

  // ── Validation ────────────────────────────────────────────────────────────
  const passwordValid = passwordRules.every((r) => r.test(password));
  const confirmValid = confirmPassword.length > 0 && confirmPassword === password;
  const nationalIdValid = /^\d{14}$/.test(nationalId.trim());
  const licenseDocsValid =
    !needsLicense ||
    (!!files.vehicle_license_front &&
      !!files.vehicle_license_back &&
      !!files.courier_license_front &&
      !!files.courier_license_back &&
      !!vehiclePlate.trim());

  const isValid =
    fullName.trim().length >= 3 &&
    fullName.trim().length <= 50 &&
    phone.trim().length > 0 &&
    passwordValid &&
    confirmValid &&
    nationalIdValid &&
    !!files.national_id_photo_front &&
    !!files.national_id_photo_back &&
    !!vehicleId &&
    licenseDocsValid;

  function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (!isValid || createMutation.isPending) return;
    createMutation.mutate();
  }

  if (!isOpen) return null;

  const inputCls =
    "w-full px-3 py-2 border rounded-lg text-sm text-gray-900 focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500 outline-none transition";
  const labelCls = "block text-sm font-medium text-gray-700 mb-1";
  const busy = createMutation.isPending;

  const renderFileUpload = (label: string, field: FileField, required = false) => (
    <div className="space-y-1.5">
      <label className="block text-sm font-medium text-gray-700">
        {label}
        {required && <span className="text-red-500 ml-1">*</span>}
      </label>
      {files[field] ? (
        <div className="flex items-center gap-3 p-3 bg-gray-50 rounded-lg border border-gray-200">
          {files[field]?.preview ? (
            // eslint-disable-next-line @next/next/no-img-element
            <img
              src={files[field]?.preview}
              alt={label}
              className="w-14 h-14 object-cover rounded-lg"
            />
          ) : (
            <div className="w-14 h-14 bg-gray-200 rounded-lg flex items-center justify-center">
              <FileText size={22} className="text-gray-500" />
            </div>
          )}
          <div className="flex-1 min-w-0">
            <p className="text-sm font-medium text-gray-900 truncate">
              {files[field]?.file.name}
            </p>
            <p className="text-xs text-gray-500">
              {(files[field]!.file.size / 1024 / 1024).toFixed(2)} MB
            </p>
          </div>
          <button
            type="button"
            onClick={() => removeFile(field)}
            className="p-1.5 text-red-500 hover:bg-red-50 rounded-lg transition"
            disabled={busy}
          >
            <X size={16} />
          </button>
        </div>
      ) : (
        <button
          type="button"
          onClick={() => fileRefs[field].current?.click()}
          className="w-full p-3 border-2 border-dashed border-gray-300 rounded-lg hover:border-indigo-500 hover:bg-indigo-50 transition flex flex-col items-center gap-1.5"
          disabled={busy}
        >
          <Upload size={18} className="text-gray-400" />
          <span className="text-sm text-gray-600">Upload {label}</span>
        </button>
      )}
      <input
        ref={fileRefs[field]}
        type="file"
        accept={ALLOWED_IMAGE_ACCEPT}
        onChange={(e) => handleFileChange(field, e)}
        className="hidden"
      />
    </div>
  );

  return (
    <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
      <div className="bg-white rounded-2xl shadow-2xl w-full max-w-3xl max-h-[90vh] overflow-y-auto">
        {/* Header */}
        <div className="flex items-center justify-between px-6 py-4 border-b border-gray-200 sticky top-0 bg-white z-10">
          <h2 className="text-lg font-semibold text-gray-900 flex items-center gap-2">
            <Truck size={18} className="text-green-600" />
            Create Courier
          </h2>
          <button
            onClick={onClose}
            disabled={busy}
            className="p-1.5 hover:bg-gray-100 rounded-lg transition disabled:opacity-50"
          >
            <X size={18} />
          </button>
        </div>

        <form onSubmit={handleSubmit} className="p-6 space-y-6">
          <p className="text-sm text-gray-500">
            Fields marked with <span className="text-red-500">*</span> are required
          </p>

          {/* Basic info */}
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div>
              <label className={labelCls}>
                Full Name <span className="text-red-500">*</span>
              </label>
              <input
                type="text"
                value={fullName}
                onChange={(e) => setFullName(e.target.value)}
                className={cn(inputCls, "border-gray-300")}
                placeholder="John Doe"
                disabled={busy}
              />
            </div>

            <div>
              <label className={labelCls}>
                Phone <span className="text-red-500">*</span>
              </label>
              <input
                type="text"
                value={phone}
                onChange={(e) => setPhone(e.target.value)}
                onBlur={() => setPhone((p) => (p.trim() ? normalizeEgPhone(p) : p))}
                className={cn(inputCls, "border-gray-300")}
                placeholder="+201012345678"
                disabled={busy}
              />
            </div>

            <div>
              <label className={labelCls}>
                Password <span className="text-red-500">*</span>
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

            <div>
              <label className={labelCls}>
                Confirm Password <span className="text-red-500">*</span>
              </label>
              <input
                type={showPassword ? "text" : "password"}
                value={confirmPassword}
                onChange={(e) => setConfirmPassword(e.target.value)}
                className={cn(
                  inputCls,
                  confirmPassword.length > 0 && !confirmValid
                    ? "border-red-400 focus:ring-red-500 focus:border-red-500"
                    : "border-gray-300",
                )}
                placeholder="••••••••"
                disabled={busy}
              />
              {confirmPassword.length > 0 && !confirmValid && (
                <p className="mt-1 text-xs text-red-600">Passwords do not match</p>
              )}
            </div>

            <div>
              <label className={labelCls}>Gender</label>
              <select
                value={gender}
                onChange={(e) => setGender(e.target.value as "" | "MALE" | "FEMALE")}
                className={cn(inputCls, "border-gray-300 bg-white")}
                disabled={busy}
              >
                <option value="">Not specified</option>
                <option value="MALE">Male</option>
                <option value="FEMALE">Female</option>
              </select>
            </div>

            <div>
              <label className={labelCls}>
                National ID Number <span className="text-red-500">*</span>
              </label>
              <input
                type="text"
                inputMode="numeric"
                value={nationalId}
                onChange={(e) => setNationalId(e.target.value.replace(/\D/g, "").slice(0, 14))}
                className={cn(
                  inputCls,
                  nationalId.length > 0 && !nationalIdValid
                    ? "border-red-400 focus:ring-red-500 focus:border-red-500"
                    : "border-gray-300",
                )}
                placeholder="14 digits"
                disabled={busy}
              />
              {nationalId.length > 0 && !nationalIdValid && (
                <p className="mt-1 text-xs text-red-600">
                  National ID must be exactly 14 digits
                </p>
              )}
            </div>
          </div>

          {/* National ID documents */}
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            {renderFileUpload("National ID — Front", "national_id_photo_front", true)}
            {renderFileUpload("National ID — Back", "national_id_photo_back", true)}
          </div>

          {/* Vehicle */}
          <div>
            <label className={labelCls}>
              Vehicle <span className="text-red-500">*</span>
            </label>
            <select
              value={vehicleId}
              onChange={(e) => setVehicleId(e.target.value)}
              className={cn(inputCls, "border-gray-300 bg-white")}
              disabled={busy}
            >
              <option value="">Select vehicle</option>
              {vehicles.map((v) => (
                <option key={v.id} value={v.id}>
                  {v.name}
                </option>
              ))}
            </select>
          </div>

          {/* Vehicle / courier licenses — only for motorized vehicles */}
          {needsLicense && (
            <div className="border border-gray-200 rounded-xl p-4 space-y-4">
              <p className="text-sm font-semibold text-gray-700">
                Vehicle &amp; License Details
              </p>
              <div>
                <label className={labelCls}>
                  Vehicle Plate <span className="text-red-500">*</span>
                </label>
                <input
                  type="text"
                  value={vehiclePlate}
                  onChange={(e) => setVehiclePlate(e.target.value)}
                  className={cn(inputCls, "border-gray-300")}
                  placeholder="ABC 1234"
                  disabled={busy}
                />
              </div>
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                {renderFileUpload("Vehicle License — Front", "vehicle_license_front", true)}
                {renderFileUpload("Vehicle License — Back", "vehicle_license_back", true)}
                {renderFileUpload("Courier License — Front", "courier_license_front", true)}
                {renderFileUpload("Courier License — Back", "courier_license_back", true)}
              </div>
            </div>
          )}

          {/* Optional documents */}
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            {renderFileUpload("Personal Photo", "personal_photo")}
            {renderFileUpload("Criminal Record", "courier_criminal_record")}
          </div>

          {/* Actions */}
          <div className="flex justify-end gap-3 pt-2 border-t border-gray-200">
            <button
              type="button"
              onClick={onClose}
              disabled={busy}
              className="px-4 py-2 text-gray-700 bg-gray-100 hover:bg-gray-200 rounded-lg font-medium transition disabled:opacity-50"
            >
              Cancel
            </button>
            <button
              type="submit"
              disabled={!isValid || busy}
              className="flex items-center gap-2 px-4 py-2 bg-indigo-600 hover:bg-indigo-700 text-white rounded-lg font-medium transition disabled:opacity-50 disabled:cursor-not-allowed"
            >
              {busy && <Loader2 size={16} className="animate-spin" />}
              {busy ? "Creating..." : "Create Courier"}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
