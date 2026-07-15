"use client";

import { useState, useRef, useCallback, ChangeEvent } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import {
  X,
  Loader2,
  Plus,
  Trash2,
  Clock,
  Upload,
  Image,
  FileText,
  MapPin,
  Eye,
  EyeOff,
} from "lucide-react";
import { cn } from "@/lib/utils";
import { ALLOWED_IMAGE_ACCEPT, validateImageFile } from "@/lib/file-upload";
import toast from "react-hot-toast";
import { isAxiosError } from "axios";
import { supplierApi } from "@/lib/api";
import { fetchAllAreas, type Area } from "@/lib/governorates";
import { fetchBadgesByRoleId, type UserBadge } from "@/lib/users";
import LocationPickerMap from "@/components/maps/LocationPickerMap";

interface CreateSupplierModalProps {
  isOpen: boolean;
  onClose: () => void;
}

interface FilePreview {
  file: File;
  preview: string;
}

interface ApiFieldError {
  field: string;
  message: string;
  code?: string;
}

interface ApiErrorResponse {
  status?: number;
  message?: string;
  errors?: ApiFieldError[];
}

const FIELD_LABELS: Record<string, string> = {
  full_name: "Full Name",
  phone: "Phone",
  password: "Password",
  gender: "Gender",
  language: "Language",
  badge_id: "Badge",
  national_id_number: "National ID Number",
  tax_card: "Tax Card",
  commercial_register: "Commercial Register",
  area_id: "Area",
  address_line_1: "Address Line 1",
  address_line_2: "Address Line 2",
  city: "City",
  state: "State",
  country: "Country",
  google_map_link: "Google Map Link",
  latitude: "Latitude",
  longitude: "Longitude",
  contact_name: "Contact Name",
  contact_phone: "Contact Phone",
  working_hours: "Working Hours",
  personal_photo: "Personal Photo",
  national_id_photo_front: "National ID Front",
  national_id_photo_back: "National ID Back",
  supplier_criminal_record: "Criminal Record",
};

const DAYS_OF_WEEK = [
  "Sunday",
  "Monday",
  "Tuesday",
  "Wednesday",
  "Thursday",
  "Friday",
  "Saturday",
];

interface FormData {
  full_name: string;
  phone: string;
  password: string;
  gender: "MALE" | "FEMALE";
  language: "AR" | "EN";
  badge_id: string;
  national_id_number: string;
  tax_card: string;
  commercial_register: string;
  area_id: string;
  address_line_1: string;
  address_line_2: string;
  city: string;
  state: string;
  country: string;
  google_map_link: string;
  latitude: string;
  longitude: string;
  contact_name: string;
  contact_phone: string;
  working_hours: {
    timezone: string;
    days: Record<
      string,
      {
        is_closed: boolean;
        slots: Array<{ open: string; close: string }>;
      }
    >;
  };
}

const initialFormData: FormData = {
  full_name: "",
  phone: "",
  password: "",
  gender: "MALE",
  language: "AR",
  badge_id: "",
  national_id_number: "",
  tax_card: "",
  commercial_register: "",
  area_id: "",
  address_line_1: "",
  address_line_2: "",
  city: "",
  state: "",
  country: "Egypt",
  google_map_link: "",
  latitude: "",
  longitude: "",
  contact_name: "",
  contact_phone: "",
  working_hours: {
    timezone: "Africa/Cairo",
    days: Object.fromEntries(
      DAYS_OF_WEEK.map((_, index) => [
        String(index),
        {
          is_closed: false,
          slots: [{ open: "09:00", close: "22:00" }],
        },
      ]),
    ),
  },
};

function normalizeEgPhone(raw: string): string {
  let p = raw.trim().replace(/[\s\-()]/g, "");
  if (!p) return p;
  if (p.startsWith("+20")) p = p.slice(3);
  else if (p.startsWith("0020")) p = p.slice(4);
  else if (p.startsWith("20")) p = p.slice(2);
  else if (p.startsWith("0")) p = p.slice(1);
  return `+20${p}`;
}

async function createSupplier(
  data: FormData,
  files: Record<string, File | undefined>,
) {
  const formData = new FormData();

  // Add text fields
  Object.entries(data).forEach(([key, value]) => {
    if (key === "working_hours") {
      formData.append(key, JSON.stringify(value));
    } else if (key === "phone" || key === "contact_phone") {
      formData.append(key, normalizeEgPhone(value as string));
    } else {
      formData.append(key, value);
    }
  });

  // Add file fields
  if (files.personal_photo) {
    formData.append("personal_photo", files.personal_photo);
  }
  if (files.national_id_photo_front) {
    formData.append("national_id_photo_front", files.national_id_photo_front);
  }
  if (files.national_id_photo_back) {
    formData.append("national_id_photo_back", files.national_id_photo_back);
  }
  if (files.supplier_criminal_record) {
    formData.append("supplier_criminal_record", files.supplier_criminal_record);
  }

  const res = await supplierApi.post("/auth/register", formData, {
    headers: { "Content-Type": "multipart/form-data" },
  });
  return res.data;
}

export default function CreateSupplierModal({
  isOpen,
  onClose,
}: CreateSupplierModalProps) {
  const queryClient = useQueryClient();
  const [formData, setFormData] = useState<FormData>(initialFormData);
  const [fieldErrors, setFieldErrors] = useState<ApiFieldError[]>([]);
  const [showPassword, setShowPassword] = useState(false);
  const [files, setFiles] = useState<{
    personal_photo?: FilePreview;
    national_id_photo_front?: FilePreview;
    national_id_photo_back?: FilePreview;
    supplier_criminal_record?: FilePreview;
  }>({});

  const personalPhotoRef = useRef<HTMLInputElement>(null);
  const nationalIdFrontRef = useRef<HTMLInputElement>(null);
  const nationalIdBackRef = useRef<HTMLInputElement>(null);
  const criminalRecordRef = useRef<HTMLInputElement>(null);

  const { data: areasData } = useQuery({
    queryKey: ["areas"],
    queryFn: fetchAllAreas,
  });

  const { data: badgesData } = useQuery({
    queryKey: ["badges", "role", 6],
    queryFn: () => fetchBadgesByRoleId(6), // 6 is the Supplier role_id
  });

  const createMutation = useMutation({
    mutationFn: () =>
      createSupplier(formData, {
        personal_photo: files.personal_photo?.file,
        national_id_photo_front: files.national_id_photo_front?.file,
        national_id_photo_back: files.national_id_photo_back?.file,
        supplier_criminal_record: files.supplier_criminal_record?.file,
      }),
    onSuccess: () => {
      toast.success("Supplier created successfully");
      queryClient.invalidateQueries({ queryKey: ["users"] });
      onClose();
      setFormData(initialFormData);
      setFiles({});
      setFieldErrors([]);
      setShowPassword(false);
    },
    onError: (error: unknown) => {
      if (isAxiosError(error)) {
        const data = error.response?.data as ApiErrorResponse | undefined;
        if (data?.errors?.length) {
          setFieldErrors(data.errors);
          toast.error("Please fix the highlighted fields below");
          return;
        }
        toast.error(data?.message || "Failed to create supplier");
        return;
      }
      toast.error(
        error instanceof Error ? error.message : "Failed to create supplier",
      );
    },
  });

  const handleChange = (field: keyof FormData, value: string) => {
    setFormData((prev) => ({ ...prev, [field]: value }));
    // Clear any server error for this field once the user edits it
    setFieldErrors((prev) => prev.filter((e) => e.field !== field));
  };

  const handlePhoneBlur = (field: "phone" | "contact_phone") => () => {
    setFormData((prev) => ({
      ...prev,
      [field]: normalizeEgPhone(prev[field]),
    }));
  };

  const handleMapLocationChange = useCallback((lat: number, lng: number) => {
    const latStr = lat.toFixed(6);
    const lngStr = lng.toFixed(6);
    setFormData((prev) => ({
      ...prev,
      latitude: latStr,
      longitude: lngStr,
      google_map_link: `https://www.google.com/maps?q=${latStr},${lngStr}`,
    }));
    setFieldErrors((prev) =>
      prev.filter(
        (e) =>
          e.field !== "latitude" &&
          e.field !== "longitude" &&
          e.field !== "google_map_link",
      ),
    );
  }, []);

  const getFieldErrors = (field: string) =>
    fieldErrors.filter((e) => e.field === field);

  const fieldBorderClass = (field: string) =>
    getFieldErrors(field).length
      ? "border-red-400 focus:ring-red-500 focus:border-red-500"
      : "border-gray-300 focus:ring-indigo-500 focus:border-indigo-500";

  const FieldError = ({ field }: { field: string }) => {
    const errs = getFieldErrors(field);
    if (!errs.length) return null;
    return (
      <div className="mt-1 space-y-0.5">
        {errs.map((e, i) => (
          <p key={i} className="text-xs text-red-600">
            {e.message}
          </p>
        ))}
      </div>
    );
  };

  const handleFileChange = (
    field: keyof typeof files,
    e: ChangeEvent<HTMLInputElement>,
  ) => {
    const file = e.target.files?.[0];
    if (file) {
      if (!validateImageFile(file, e.target)) return;
      const isImage = file.type.startsWith("image/");
      setFiles((prev) => ({
        ...prev,
        [field]: {
          file,
          preview: isImage ? URL.createObjectURL(file) : "",
        },
      }));
    }
  };

  const handleRemoveFile = (field: keyof typeof files) => {
    setFiles((prev) => {
      const newFiles = { ...prev };
      if (newFiles[field]?.preview) {
        URL.revokeObjectURL(newFiles[field]!.preview);
      }
      delete newFiles[field];
      return newFiles;
    });
  };

  const handleWorkingHoursChange = (
    workingHours: FormData["working_hours"],
  ) => {
    setFormData((prev) => ({ ...prev, working_hours: workingHours }));
  };

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    setFieldErrors([]);

    const passwordErrors: ApiFieldError[] = [];
    const pw = formData.password;
    if (pw.length < 8)
      passwordErrors.push({ field: "password", message: "Password must be at least 8 characters" });
    if (pw.length > 100)
      passwordErrors.push({ field: "password", message: "Password must not exceed 100 characters" });
    if (!/[A-Z]/.test(pw))
      passwordErrors.push({ field: "password", message: "Requires uppercase" });
    if (!/[a-z]/.test(pw))
      passwordErrors.push({ field: "password", message: "Requires lowercase" });
    if (!/[0-9]/.test(pw))
      passwordErrors.push({ field: "password", message: "Requires number" });

    if (passwordErrors.length) {
      setFieldErrors(passwordErrors);
      toast.error("Please fix the highlighted fields below");
      return;
    }

    setFormData((prev) => ({
      ...prev,
      phone: normalizeEgPhone(prev.phone),
      contact_phone: normalizeEgPhone(prev.contact_phone),
    }));
    createMutation.mutate();
  };

  const isFormValid = () => {
    return (
      formData.full_name.trim() &&
      formData.phone.trim() &&
      formData.password.trim() &&
      formData.national_id_number.trim() &&
      formData.tax_card.trim()
    );
  };

  const renderFileUpload = (
    label: string,
    field: keyof typeof files,
    inputRef: React.RefObject<HTMLInputElement | null>,
    required = false,
  ) => (
    <div className="space-y-2">
      <label className="block text-sm font-medium text-gray-700">
        {label}
        {required && <span className="text-red-500 ml-1">*</span>}
      </label>
      {files[field] ? (
        <div className="flex items-center gap-3 p-3 bg-gray-50 rounded-lg border border-gray-200">
          {files[field]?.preview ? (
            <img
              src={files[field]?.preview}
              alt={label}
              className="w-16 h-16 object-cover rounded-lg"
            />
          ) : (
            <div className="w-16 h-16 bg-gray-200 rounded-lg flex items-center justify-center">
              <FileText size={24} className="text-gray-500" />
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
            onClick={() => handleRemoveFile(field)}
            className="p-1.5 text-red-500 hover:bg-red-50 rounded-lg transition"
            disabled={createMutation.isPending}
          >
            <X size={16} />
          </button>
        </div>
      ) : (
        <button
          type="button"
          onClick={() => inputRef.current?.click()}
          className="w-full p-4 border-2 border-dashed border-gray-300 rounded-lg hover:border-indigo-500 hover:bg-indigo-50 transition flex flex-col items-center gap-2"
          disabled={createMutation.isPending}
        >
          <Upload size={20} className="text-gray-400" />
          <span className="text-sm text-gray-600">Click to upload {label}</span>
          <span className="text-xs text-gray-400">PNG, JPG up to 10MB</span>
        </button>
      )}
      <input
        ref={inputRef}
        type="file"
        accept={ALLOWED_IMAGE_ACCEPT}
        onChange={(e) => handleFileChange(field, e)}
        className="hidden"
      />
    </div>
  );

  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
      <div className="bg-white rounded-xl w-full max-w-5xl max-h-[90vh] overflow-y-auto">
        <div className="flex items-center justify-between p-6 border-b border-gray-200">
          <h2 className="text-xl font-semibold text-gray-900">
            Create Supplier
          </h2>
          <button
            onClick={onClose}
            className="p-2 hover:bg-gray-100 rounded-lg transition"
            disabled={createMutation.isPending}
          >
            <X size={20} />
          </button>
        </div>

        <form onSubmit={handleSubmit} className="p-6 space-y-6">
          {/* Required Fields Note */}
          <p className="text-sm text-gray-500">
            Fields marked with <span className="text-red-500">*</span> are
            required
          </p>

          {/* Validation Error Summary */}
          {fieldErrors.length > 0 && (
            <div className="rounded-lg border border-red-200 bg-red-50 p-4">
              <p className="text-sm font-semibold text-red-700 mb-2">
                Please fix the following {fieldErrors.length} error
                {fieldErrors.length > 1 ? "s" : ""}:
              </p>
              <ul className="list-disc ps-5 space-y-1">
                {fieldErrors.map((err, i) => (
                  <li key={i} className="text-sm text-red-600">
                    <span className="font-medium">
                      {FIELD_LABELS[err.field] ?? err.field}:
                    </span>{" "}
                    {err.message}
                  </li>
                ))}
              </ul>
            </div>
          )}

          {/* Basic Information */}
          <div>
            <h3 className="text-sm font-medium text-gray-900 mb-3">
              Basic Information
            </h3>
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Full Name <span className="text-red-500">*</span>
                </label>
                <input
                  type="text"
                  value={formData.full_name}
                  onChange={(e) => handleChange("full_name", e.target.value)}
                  className={cn(
                    "w-full px-3 py-2 border rounded-lg focus:ring-2",
                    fieldBorderClass("full_name"),
                  )}
                  disabled={createMutation.isPending}
                  required
                />
                <FieldError field="full_name" />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Phone <span className="text-red-500">*</span>
                </label>
                <input
                  type="text"
                  value={formData.phone}
                  onChange={(e) => handleChange("phone", e.target.value)}
                  onBlur={handlePhoneBlur("phone")}
                  placeholder="+201001001003"
                  className={cn(
                    "w-full px-3 py-2 border rounded-lg focus:ring-2",
                    fieldBorderClass("phone"),
                  )}
                  disabled={createMutation.isPending}
                  required
                />
                <FieldError field="phone" />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Password <span className="text-red-500">*</span>
                </label>
                <div className="relative">
                  <input
                    type={showPassword ? "text" : "password"}
                    value={formData.password}
                    onChange={(e) => handleChange("password", e.target.value)}
                    className={cn(
                      "w-full px-3 py-2 pr-10 border rounded-lg focus:ring-2",
                      fieldBorderClass("password"),
                    )}
                    disabled={createMutation.isPending}
                    required
                  />
                  <button
                    type="button"
                    onClick={() => setShowPassword((p) => !p)}
                    className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400 hover:text-gray-600 transition"
                    disabled={createMutation.isPending}
                  >
                    {showPassword ? <EyeOff size={16} /> : <Eye size={16} />}
                  </button>
                </div>
                <FieldError field="password" />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Gender
                </label>
                <select
                  value={formData.gender}
                  onChange={(e) => handleChange("gender", e.target.value)}
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500"
                  disabled={createMutation.isPending}
                >
                  <option value="MALE">Male</option>
                  <option value="FEMALE">Female</option>
                </select>
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Language
                </label>
                <select
                  value={formData.language}
                  onChange={(e) => handleChange("language", e.target.value)}
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500"
                  disabled={createMutation.isPending}
                >
                  <option value="AR">Arabic</option>
                  <option value="EN">English</option>
                </select>
              </div>
            </div>
          </div>

          {/* Supplier Details */}
          <div>
            <h3 className="text-sm font-medium text-gray-900 mb-3">
              Supplier Details
            </h3>
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Badge
                </label>
                <select
                  value={formData.badge_id}
                  onChange={(e) => handleChange("badge_id", e.target.value)}
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500"
                  disabled={createMutation.isPending}
                >
                  <option value="">Select Badge</option>
                  {badgesData?.map((badge: UserBadge) => (
                    <option key={badge.id} value={badge.id}>
                      {badge.name} ({badge.name_ar})
                    </option>
                  ))}
                </select>
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  National ID Number <span className="text-red-500">*</span>
                </label>
                <input
                  type="text"
                  value={formData.national_id_number}
                  onChange={(e) =>
                    handleChange("national_id_number", e.target.value)
                  }
                  className={cn(
                    "w-full px-3 py-2 border rounded-lg focus:ring-2",
                    fieldBorderClass("national_id_number"),
                  )}
                  disabled={createMutation.isPending}
                  required
                />
                <FieldError field="national_id_number" />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Tax Card <span className="text-red-500">*</span>
                </label>
                <input
                  type="text"
                  value={formData.tax_card}
                  onChange={(e) => handleChange("tax_card", e.target.value)}
                  className={cn(
                    "w-full px-3 py-2 border rounded-lg focus:ring-2",
                    fieldBorderClass("tax_card"),
                  )}
                  disabled={createMutation.isPending}
                  required
                />
                <FieldError field="tax_card" />
              </div>
              <div className="md:col-span-2 lg:col-span-2">
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Commercial Register
                </label>
                <input
                  type="text"
                  value={formData.commercial_register}
                  onChange={(e) =>
                    handleChange("commercial_register", e.target.value)
                  }
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500"
                  disabled={createMutation.isPending}
                />
              </div>
            </div>
          </div>

          {/* Address */}
          <div>
            <h3 className="text-sm font-medium text-gray-900 mb-3">Address</h3>
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Area
                </label>
                <select
                  value={formData.area_id}
                  onChange={(e) => handleChange("area_id", e.target.value)}
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500"
                  disabled={createMutation.isPending}
                >
                  <option value="">Select Area</option>
                  {areasData?.map((area: Area) => (
                    <option key={area.id} value={area.id}>
                      {area.name} ({area.name_ar})
                    </option>
                  ))}
                </select>
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Address Line 1
                </label>
                <input
                  type="text"
                  value={formData.address_line_1}
                  onChange={(e) =>
                    handleChange("address_line_1", e.target.value)
                  }
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500"
                  disabled={createMutation.isPending}
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Address Line 2
                </label>
                <input
                  type="text"
                  value={formData.address_line_2}
                  onChange={(e) =>
                    handleChange("address_line_2", e.target.value)
                  }
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500"
                  disabled={createMutation.isPending}
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  City
                </label>
                <input
                  type="text"
                  value={formData.city}
                  onChange={(e) => handleChange("city", e.target.value)}
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500"
                  disabled={createMutation.isPending}
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  State
                </label>
                <input
                  type="text"
                  value={formData.state}
                  onChange={(e) => handleChange("state", e.target.value)}
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500"
                  disabled={createMutation.isPending}
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Country
                </label>
                <input
                  type="text"
                  value={formData.country}
                  onChange={(e) => handleChange("country", e.target.value)}
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500"
                  disabled={createMutation.isPending}
                />
              </div>
              {/* Location Picker Map — auto-fills lat, lng & google map link */}
              <div className="md:col-span-2 lg:col-span-3">
                <label className="block text-sm font-medium text-gray-700 mb-2 flex items-center gap-1.5">
                  <MapPin size={15} className="text-indigo-500" />
                  Pick Location on Map
                </label>
                <LocationPickerMap
                  lat={formData.latitude ? parseFloat(formData.latitude) : null}
                  long={formData.longitude ? parseFloat(formData.longitude) : null}
                  onChange={handleMapLocationChange}
                  heightClassName="h-64"
                  disabled={createMutation.isPending}
                />
                {formData.latitude && formData.longitude && (
                  <p className="mt-2 text-xs text-gray-500">
                    📍 Lat: {formData.latitude}, Lng: {formData.longitude}
                  </p>
                )}
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Contact Name
                </label>
                <input
                  type="text"
                  value={formData.contact_name}
                  onChange={(e) => handleChange("contact_name", e.target.value)}
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500"
                  disabled={createMutation.isPending}
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Contact Phone
                </label>
                <input
                  type="text"
                  value={formData.contact_phone}
                  onChange={(e) =>
                    handleChange("contact_phone", e.target.value)
                  }
                  onBlur={handlePhoneBlur("contact_phone")}
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500"
                  disabled={createMutation.isPending}
                />
              </div>
            </div>
          </div>

          {/* Working Hours */}
          <div>
            <h3 className="text-sm font-medium text-gray-900 mb-3 flex items-center gap-2">
              <Clock size={16} />
              Working Hours
            </h3>
            <div className="space-y-3">
              {/* Timezone */}
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Timezone
                </label>
                <input
                  type="text"
                  value={formData.working_hours.timezone}
                  onChange={(e) =>
                    handleWorkingHoursChange({
                      ...formData.working_hours,
                      timezone: e.target.value,
                    })
                  }
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500"
                  disabled={createMutation.isPending}
                />
              </div>

              {/* Days */}
              <div className="grid grid-cols-1 gap-3">
                {DAYS_OF_WEEK.map((dayName, dayIndex) => {
                  const dayKey = String(dayIndex);
                  const dayData = formData.working_hours.days[dayKey] || {
                    is_closed: false,
                    slots: [{ open: "09:00", close: "22:00" }],
                  };
                  return (
                    <div
                      key={dayKey}
                      className="flex items-start gap-3 p-3 bg-gray-50 rounded-lg"
                    >
                      <div className="w-24 shrink-0">
                        <label className="flex items-center gap-2">
                          <input
                            type="checkbox"
                            checked={!dayData.is_closed}
                            onChange={(e) => {
                              const newDays = {
                                ...formData.working_hours.days,
                                [dayKey]: {
                                  ...dayData,
                                  is_closed: !e.target.checked,
                                },
                              };
                              handleWorkingHoursChange({
                                ...formData.working_hours,
                                days: newDays,
                              });
                            }}
                            className="w-4 h-4 text-indigo-600 rounded border-gray-300"
                            disabled={createMutation.isPending}
                          />
                          <span className="text-sm font-medium text-gray-700">
                            {dayName}
                          </span>
                        </label>
                      </div>

                      {!dayData.is_closed && (
                        <div className="flex-1 space-y-2">
                          {dayData.slots.map((slot, slotIndex) => (
                            <div
                              key={slotIndex}
                              className="flex items-center gap-2"
                            >
                              <input
                                type="time"
                                value={slot.open}
                                onChange={(e) => {
                                  const newSlots = [...dayData.slots];
                                  newSlots[slotIndex] = {
                                    ...slot,
                                    open: e.target.value,
                                  };
                                  const newDays = {
                                    ...formData.working_hours.days,
                                    [dayKey]: {
                                      ...dayData,
                                      slots: newSlots,
                                    },
                                  };
                                  handleWorkingHoursChange({
                                    ...formData.working_hours,
                                    days: newDays,
                                  });
                                }}
                                className="px-2 py-1 border border-gray-300 rounded text-sm"
                                disabled={createMutation.isPending}
                              />
                              <span className="text-gray-500">-</span>
                              <input
                                type="time"
                                value={slot.close}
                                onChange={(e) => {
                                  const newSlots = [...dayData.slots];
                                  newSlots[slotIndex] = {
                                    ...slot,
                                    close: e.target.value,
                                  };
                                  const newDays = {
                                    ...formData.working_hours.days,
                                    [dayKey]: {
                                      ...dayData,
                                      slots: newSlots,
                                    },
                                  };
                                  handleWorkingHoursChange({
                                    ...formData.working_hours,
                                    days: newDays,
                                  });
                                }}
                                className="px-2 py-1 border border-gray-300 rounded text-sm"
                                disabled={createMutation.isPending}
                              />
                              {dayData.slots.length > 1 && (
                                <button
                                  type="button"
                                  onClick={() => {
                                    const newSlots = dayData.slots.filter(
                                      (_, i) => i !== slotIndex,
                                    );
                                    const newDays = {
                                      ...formData.working_hours.days,
                                      [dayKey]: {
                                        ...dayData,
                                        slots: newSlots,
                                      },
                                    };
                                    handleWorkingHoursChange({
                                      ...formData.working_hours,
                                      days: newDays,
                                    });
                                  }}
                                  className="p-1 text-red-500 hover:bg-red-50 rounded"
                                  disabled={createMutation.isPending}
                                >
                                  <Trash2 size={14} />
                                </button>
                              )}
                            </div>
                          ))}
                          <button
                            type="button"
                            onClick={() => {
                              const newSlots = [
                                ...dayData.slots,
                                { open: "09:00", close: "22:00" },
                              ];
                              const newDays = {
                                ...formData.working_hours.days,
                                [dayKey]: {
                                  ...dayData,
                                  slots: newSlots,
                                },
                              };
                              handleWorkingHoursChange({
                                ...formData.working_hours,
                                days: newDays,
                              });
                            }}
                            className="flex items-center gap-1 text-xs text-indigo-600 hover:text-indigo-700 font-medium"
                            disabled={createMutation.isPending}
                          >
                            <Plus size={12} />
                            Add Slot
                          </button>
                        </div>
                      )}

                      {dayData.is_closed && (
                        <span className="text-sm text-gray-500 italic">
                          Closed
                        </span>
                      )}
                    </div>
                  );
                })}
              </div>
            </div>
          </div>

          {/* Documents */}
          <div>
            <h3 className="text-sm font-medium text-gray-900 mb-3">
              Documents
            </h3>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              {renderFileUpload(
                "Personal Photo",
                "personal_photo",
                personalPhotoRef,
              )}
              {renderFileUpload(
                "National ID Front",
                "national_id_photo_front",
                nationalIdFrontRef,
              )}
              {renderFileUpload(
                "National ID Back",
                "national_id_photo_back",
                nationalIdBackRef,
              )}
              {renderFileUpload(
                "Criminal Record",
                "supplier_criminal_record",
                criminalRecordRef,
              )}
            </div>
          </div>

          <div className="flex justify-end gap-3 pt-4 border-t border-gray-200">
            <button
              type="button"
              onClick={onClose}
              disabled={createMutation.isPending}
              className="px-4 py-2 text-gray-700 bg-gray-100 hover:bg-gray-200 rounded-lg font-medium transition"
            >
              Cancel
            </button>
            <button
              type="submit"
              disabled={createMutation.isPending || !isFormValid()}
              className="flex items-center gap-2 px-4 py-2 bg-indigo-600 hover:bg-indigo-700 text-white rounded-lg font-medium transition disabled:opacity-50 disabled:cursor-not-allowed"
            >
              {createMutation.isPending && (
                <Loader2 size={16} className="animate-spin" />
              )}
              {createMutation.isPending ? "Creating..." : "Create Supplier"}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
