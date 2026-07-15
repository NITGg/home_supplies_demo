"use client";
import { useState, useRef } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import api from "@/lib/api";
import { fetchCourierOffices } from "@/lib/courier-offices";
import { useRole } from "@/hooks/useRole";
import { useT } from "@/contexts/LanguageContext";
import {
  Truck,
  RefreshCw,
  Plus,
  Trash2,
  X,
  Check,
  Search,
  ChevronLeft,
  ChevronRight,
  CheckCircle,
  XCircle,
  Phone,
  Loader2,
  Building2,
  Upload,
  Eye,
  EyeOff,
  ShoppingBag,
} from "lucide-react";
import { cn } from "@/lib/utils";
import { ALLOWED_IMAGE_ACCEPT } from "@/lib/file-upload";
import toast from "react-hot-toast";
import axios from "axios";

const courierApi = axios.create({ baseURL: "/api/courier" });

// ── Courier-API bearer prefix (must match BEARER_KEY on the courier server) ──
const COURIER_BEARER =
  process.env.NEXT_PUBLIC_COURIER_BEARER_PREFIX ??
  "tawreedat-courier-bearer-key-2026";

// ── Allowed image types & max size ────────────────────────────────────────────
const ALLOWED_IMAGE_TYPES = ["image/jpeg", "image/png", "image/webp"];
const MAX_FILE_BYTES = 1 * 1024 * 1024; // 1 MB

// ── Normalise Egyptian phone → +20XXXXXXXXXX ─────────────────────────────────
function normalizeEgPhone(raw: string): string {
  let p = raw.trim().replace(/[\s\-()]/g, "");
  if (!p) return p;
  if (p.startsWith("+20")) p = p.slice(3);
  else if (p.startsWith("20")) p = p.slice(2);
  else if (p.startsWith("0")) p = p.slice(1);
  return `+20${p}`;
}

// ── Motorized vehicle detection ───────────────────────────────────────────────
// Returns true if the vehicle requires a vehicle license + driver's license
function isMotorizedVehicle(name: string): boolean {
  const n = name.toLowerCase();
  return (
    n.includes("موتو") ||
    n.includes("سيار") || // Arabic: motorcycle / car
    n.includes("motor") ||
    n.includes("moto") || // English
    n.includes("car") ||
    n.includes("truck") ||
    n.includes("van") ||
    n.includes("pickup")
  );
}

// ── Add Courier Modal ──────────────────────────────────────────────────────────
function AddCourierModal({
  officeId,
  onClose,
}: {
  officeId: number;
  onClose: () => void;
}) {
  const { t } = useT();
  const qc = useQueryClient();
  const [step, setStep] = useState<"form" | "submitting" | "done">("form");
  const [showPass, setShowPass] = useState(false);

  const [form, setForm] = useState({
    full_name: "",
    phone: "",
    password: "",
    gender: "",
    national_id_number: "",
    vehicle_id: "",
    vehicle_plate: "",
  });

  const [files, setFiles] = useState<{
    national_id_photo_front?: File;
    national_id_photo_back?: File;
    personal_photo?: File;
    vehicle_license_front?: File;
    vehicle_license_back?: File;
    courier_license_front?: File;
    courier_license_back?: File;
    courier_criminal_record?: File;
  }>({});

  const frontRef = useRef<HTMLInputElement>(null);
  const backRef = useRef<HTMLInputElement>(null);
  const photoRef = useRef<HTMLInputElement>(null);
  const vLicFrontRef = useRef<HTMLInputElement>(null);
  const vLicBackRef = useRef<HTMLInputElement>(null);
  const licenseFrontRef = useRef<HTMLInputElement>(null);
  const licenseBackRef = useRef<HTMLInputElement>(null);
  const criminalRef = useRef<HTMLInputElement>(null);

  // Load available vehicles
  const { data: vehiclesData } = useQuery({
    queryKey: ["courier-vehicles"],
    queryFn: async () => {
      const res = await courierApi.get("/auth/available-vehicles");
      return (res.data?.data?.vehicles ?? res.data?.vehicles ?? []) as {
        id: number;
        name: string;
      }[];
    },
    staleTime: 10 * 60_000,
  });
  const vehicles = vehiclesData ?? [];

  // Whether the selected vehicle requires vehicle license + driver's license
  const selectedVehicle = vehicles.find(
    (v) => String(v.id) === form.vehicle_id,
  );
  const needsLicense = selectedVehicle
    ? isMotorizedVehicle(selectedVehicle.name)
    : false;

  const set =
    (k: keyof typeof form) =>
    (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement>) =>
      setForm((f) => ({ ...f, [k]: e.target.value }));

  // Normalize phone on blur
  const handlePhoneBlur = () => {
    if (form.phone)
      setForm((f) => ({ ...f, phone: normalizeEgPhone(f.phone) }));
  };

  // Validate and pick file — enforces type whitelist + 100 KB limit
  const pickFile =
    (k: keyof typeof files) => (e: React.ChangeEvent<HTMLInputElement>) => {
      const f = e.target.files?.[0];
      if (!f) return;

      if (!ALLOWED_IMAGE_TYPES.includes(f.type)) {
        toast.error(`Only JPG, PNG and WEBP images are allowed`);
        e.target.value = "";
        return;
      }
      if (f.size > MAX_FILE_BYTES) {
        toast.error(
          `Image must be under 1 MB — this file is ${(f.size / 1024 / 1024).toFixed(1)} MB`,
        );
        e.target.value = "";
        return;
      }
      setFiles((prev) => ({ ...prev, [k]: f }));
    };

  const renderFileField = (
    label: string,
    k: keyof typeof files,
    fRef: React.RefObject<HTMLInputElement | null>,
    required?: boolean,
  ) => (
    <div key={k}>
      <p className="text-xs text-gray-500 mb-1">
        {label}
        {required && <span className="text-red-500 ml-0.5">*</span>}
        <span className="text-gray-400 font-normal ml-1">
          JPG/PNG/WEBP · max 1 MB
        </span>
      </p>
      <button
        type="button"
        onClick={() => fRef.current?.click()}
        className={cn(
          "w-full flex items-center gap-2 px-3 py-2 border rounded-lg text-sm transition",
          files[k]
            ? "border-green-400 bg-green-50 text-green-700"
            : "border-gray-200 text-gray-500 hover:border-indigo-300",
        )}
      >
        <Upload size={14} />
        {files[k]
          ? `${files[k]!.name} (${(files[k]!.size / 1024 / 1024).toFixed(1)}MB)`
          : t("addCourier.chooseFile")}
      </button>
      <input
        ref={fRef}
        type="file"
        accept={ALLOWED_IMAGE_ACCEPT}
        className="hidden"
        onChange={pickFile(k)}
      />
    </div>
  );

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (!files.national_id_photo_front || !files.national_id_photo_back) {
      toast.error(t("addCourier.errorNationalId"));
      return;
    }
    if (!form.vehicle_id) {
      toast.error(t("addCourier.errorVehicle"));
      return;
    }

    // Extra validation for motorized vehicles
    if (
      needsLicense &&
      (!files.vehicle_license_front || !files.courier_license_front)
    ) {
      toast.error(t("addCourier.errorLicense"));
      return;
    }

    setStep("submitting");
    try {
      // 1. Register via Courier API
      const fd = new FormData();
      fd.append("full_name", form.full_name);
      fd.append("phone", normalizeEgPhone(form.phone)); // always +20XXXXXXXXXX
      fd.append("password", form.password);
      fd.append("national_id_number", form.national_id_number);
      fd.append("vehicle_id", form.vehicle_id);
      if (form.gender) fd.append("gender", form.gender);
      if (form.vehicle_plate) fd.append("vehicle_plate", form.vehicle_plate);
      fd.append("national_id_photo_front", files.national_id_photo_front);
      fd.append("national_id_photo_back", files.national_id_photo_back);
      if (files.personal_photo)
        fd.append("personal_photo", files.personal_photo);
      if (files.vehicle_license_front)
        fd.append("vehicle_license_front", files.vehicle_license_front);
      if (files.vehicle_license_back)
        fd.append("vehicle_license_back", files.vehicle_license_back);
      if (files.courier_license_front)
        fd.append("courier_license_front", files.courier_license_front);
      if (files.courier_license_back)
        fd.append("courier_license_back", files.courier_license_back);
      if (files.courier_criminal_record)
        fd.append("courier_criminal_record", files.courier_criminal_record);

      const regRes = await courierApi.post("/auth/register", fd, {
        headers: { "Content-Type": "multipart/form-data" },
      });
      const accessToken: string =
        regRes.data?.data?.accessToken ?? regRes.data?.accessToken;
      if (!accessToken)
        throw new Error("Registration failed: no token returned");

      // 2. Fetch courier profile to get courier.id
      //    Courier API requires: "<BEARER_KEY> <token>", NOT "Bearer <token>"
      const profileRes = await courierApi.get("/profile/get-profile", {
        headers: { Authorization: `${COURIER_BEARER} ${accessToken}` },
      });
      const courierId: number | undefined =
        profileRes.data?.data?.user?.courier?.id ??
        profileRes.data?.user?.courier?.id;
      if (!courierId)
        throw new Error("Could not retrieve courier ID after registration");

      // 3. Link courier to this office
      await api.post("/admin/courier-office/append-courier-to-office", {
        courierId: String(courierId),
        courierOfficeId: String(officeId),
      });

      toast.success(t("addCourier.successMsg"));
      qc.invalidateQueries({ queryKey: ["office-couriers"] });
      setStep("done");
      setTimeout(onClose, 1200);
    } catch (err: any) {
      setStep("form");
      const msg =
        err?.response?.data?.message ?? err?.message ?? "Registration failed";
      toast.error(msg);
    }
  }

  return (
    <div className="fixed inset-0 z-50 bg-black/40 flex items-center justify-center p-4">
      <div className="bg-white rounded-2xl shadow-2xl w-full max-w-lg max-h-[90vh] flex flex-col">
        <div className="flex items-center justify-between p-5 border-b border-gray-100 shrink-0">
          <h2 className="text-lg font-semibold text-gray-900">
            {t("addCourier.title")}
          </h2>
          <button
            onClick={onClose}
            className="p-1.5 hover:bg-gray-100 rounded-lg"
          >
            <X size={18} />
          </button>
        </div>

        {step === "done" ? (
          <div className="flex flex-col items-center justify-center py-12 gap-3">
            <CheckCircle size={48} className="text-green-500" />
            <p className="text-lg font-semibold text-gray-800">
              {t("addCourier.successTitle")}
            </p>
            <p className="text-sm text-gray-500">
              {t("addCourier.successDesc")}
            </p>
          </div>
        ) : (
          <form onSubmit={handleSubmit} className="overflow-y-auto flex-1">
            <div className="p-5 space-y-4">
              {/* Personal info */}
              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="text-xs text-gray-500 block mb-1">
                    {t("common.fullName")}
                    <span className="text-red-500 ml-0.5">*</span>
                  </label>
                  <input
                    required
                    value={form.full_name}
                    onChange={set("full_name")}
                    placeholder={t("common.fullName")}
                    className="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-indigo-500"
                  />
                </div>
                <div>
                  <label className="text-xs text-gray-500 block mb-1">
                    {t("common.phone")}
                    <span className="text-red-500 ml-0.5">*</span>
                  </label>
                  <input
                    required
                    value={form.phone}
                    onChange={set("phone")}
                    onBlur={handlePhoneBlur}
                    placeholder="01XXXXXXXXXX"
                    className="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-indigo-500"
                  />
                </div>
                <div>
                  <label className="text-xs text-gray-500 block mb-1">
                    {t("addCourier.password")}
                    <span className="text-red-500 ml-0.5">*</span>
                  </label>
                  <div className="relative">
                    <input
                      required
                      type={showPass ? "text" : "password"}
                      value={form.password}
                      onChange={set("password")}
                      minLength={6}
                      placeholder={t("addCourier.passwordHint")}
                      className="w-full px-3 py-2 pr-9 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-indigo-500"
                    />
                    <button
                      type="button"
                      onClick={() => setShowPass((p) => !p)}
                      className="absolute right-2.5 top-1/2 -translate-y-1/2 text-gray-400"
                    >
                      {showPass ? <EyeOff size={14} /> : <Eye size={14} />}
                    </button>
                  </div>
                </div>
                <div>
                  <label className="text-xs text-gray-500 block mb-1">
                    {t("addCourier.gender")}
                  </label>
                  <select
                    value={form.gender}
                    onChange={set("gender")}
                    className="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-indigo-500 bg-white"
                  >
                    <option value="">{t("addCourier.optional")}</option>
                    <option value="MALE">{t("addCourier.male")}</option>
                    <option value="FEMALE">{t("addCourier.female")}</option>
                  </select>
                </div>
                <div>
                  <label className="text-xs text-gray-500 block mb-1">
                    {t("addCourier.nationalIdNumber")}
                    <span className="text-red-500 ml-0.5">*</span>
                  </label>
                  <input
                    required
                    value={form.national_id_number}
                    onChange={set("national_id_number")}
                    placeholder={t("addCourier.nationalIdHint")}
                    maxLength={14}
                    className="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-indigo-500"
                  />
                </div>
                <div>
                  <label className="text-xs text-gray-500 block mb-1">
                    {t("addCourier.vehicleType")}
                    <span className="text-red-500 ml-0.5">*</span>
                  </label>
                  <select
                    required
                    value={form.vehicle_id}
                    onChange={set("vehicle_id")}
                    className="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-indigo-500 bg-white"
                  >
                    <option value="">{t("addCourier.selectVehicle")}</option>
                    {vehicles.map((v) => (
                      <option key={v.id} value={v.id}>
                        {v.name}
                      </option>
                    ))}
                  </select>
                </div>
                <div className="col-span-2">
                  <label className="text-xs text-gray-500 block mb-1">
                    {t("addCourier.vehiclePlate")}
                  </label>
                  <input
                    value={form.vehicle_plate}
                    onChange={set("vehicle_plate")}
                    placeholder={t("addCourier.optional")}
                    className="w-full px-3 py-2 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-indigo-500"
                  />
                </div>
              </div>

              {/* Documents */}
              <div className="border-t border-gray-100 pt-4">
                <p className="text-sm font-medium text-gray-700 mb-1">
                  {t("addCourier.documents")}
                </p>

                {/* Required notice for motorized vehicles */}
                {needsLicense && (
                  <p className="text-xs text-amber-600 bg-amber-50 border border-amber-200 rounded-lg px-2 py-1 mb-3">
                    {t("addCourier.licenseNotice")}
                  </p>
                )}

                <div className="grid grid-cols-2 gap-3">
                  {/* Always required */}
                  {renderFileField(
                    t("addCourier.nationalIdFront"),
                    "national_id_photo_front",
                    frontRef,
                    true,
                  )}
                  {renderFileField(
                    t("addCourier.nationalIdBack"),
                    "national_id_photo_back",
                    backRef,
                    true,
                  )}
                  {renderFileField(
                    t("addCourier.personalPhoto"),
                    "personal_photo",
                    photoRef,
                  )}
                  {/* Required only for motorized vehicles */}
                  {renderFileField(
                    t("addCourier.vehicleLicenseFront"),
                    "vehicle_license_front",
                    vLicFrontRef,
                    needsLicense,
                  )}
                  {renderFileField(
                    t("addCourier.vehicleLicenseBack"),
                    "vehicle_license_back",
                    vLicBackRef,
                  )}
                  {renderFileField(
                    t("addCourier.courierLicenseFront"),
                    "courier_license_front",
                    licenseFrontRef,
                    needsLicense,
                  )}
                  {renderFileField(
                    t("addCourier.courierLicenseBack"),
                    "courier_license_back",
                    licenseBackRef,
                  )}
                  {renderFileField(
                    t("addCourier.criminalRecord"),
                    "courier_criminal_record",
                    criminalRef,
                  )}
                </div>
              </div>
            </div>

            <div className="flex justify-end gap-2 p-4 border-t border-gray-100 shrink-0">
              <button
                type="button"
                onClick={onClose}
                className="px-4 py-2 text-sm border border-gray-200 rounded-xl hover:bg-gray-50"
              >
                {t("common.cancel")}
              </button>
              <button
                type="submit"
                disabled={step === "submitting"}
                className="flex items-center gap-2 px-5 py-2 text-sm bg-indigo-600 text-white rounded-xl hover:bg-indigo-700 disabled:opacity-50"
              >
                {step === "submitting" && (
                  <Loader2 size={13} className="animate-spin" />
                )}
                {step === "submitting"
                  ? t("addCourier.submitting")
                  : t("addCourier.submit")}
              </button>
            </div>
          </form>
        )}
      </div>
    </div>
  );
}

// ── Main Page ─────────────────────────────────────────────────────────────────
export default function OfficeCouriersPage() {
  const { t } = useT();
  const { user } = useRole();
  const qc = useQueryClient();
  const [search, setSearch] = useState("");
  const [page, setPage] = useState(1);
  const [showAssign, setShowAssign] = useState(false);
  const [removeId, setRemoveId] = useState<number | null>(null); // courier.id (Courier table)
  const limit = 20;

  // Find which office this user manages by fetching all offices with their couriers
  // and matching by user_id. Uses /admin/courier-office/all-courier-offices (requireAuth only).
  const { data: officesData, isLoading: officesLoading } = useQuery({
    queryKey: ["my-office", user?.id],
    queryFn: () =>
      fetchCourierOffices({ includes: "couriers", limit: 100 } as any),
    enabled: !!user?.id,
    staleTime: 5 * 60 * 1000,
  });

  const myOffice =
    officesData?.couriers?.find((o: any) =>
      (o.couriers as any[])?.some((c: any) => c.user_id === user?.id),
    ) ?? null;

  console.log("myOffice", myOffice);

  const officeId = myOffice?.id ?? null;
  const officeName = myOffice?.name ?? "My Office";

  // List couriers using the office endpoint (requireAuth only — no Admin role needed)
  const { data, isLoading, refetch, isFetching } = useQuery({
    queryKey: ["office-couriers", officeId, page, search],
    queryFn: async () => {
      const res = await fetchCourierOffices({
        id: officeId!,
        includes: "couriers=id-user",
      } as any);
      const office = (res.couriers as any[])?.[0];
      let list: any[] = office?.couriers ?? [];
    
      if (user?.id) {
        list = list.filter(
          (c: any) => c.user_id !== user.id && c.user?.id !== user.id,
        );
      }

      if (search) {
        const kw = search.toLowerCase();
        list = list.filter(
          (c: any) =>
            c.user?.full_name?.toLowerCase().includes(kw) ||
            c.user?.phone?.includes(kw),
        );
      }
      return list;
    },
    enabled: !!officeId,
    staleTime: 30_000,
  });

  const removeMut = useMutation({
    mutationFn: (courierId: number) =>
      api.post("/admin/courier-office/append-courier-to-office", {
        courierId: String(courierId),
      }),
    onSuccess: () => {
      toast.success(t("officeCouriers.removed"));
      qc.invalidateQueries({ queryKey: ["office-couriers"] });
      setRemoveId(null);
    },
    onError: (e: any) => toast.error(e?.response?.data?.message ?? "Failed"),
  });

  // data is now a Courier[] with nested user object
  const couriers: any[] = Array.isArray(data) ? data : [];
  const total = couriers.length;
  const totalPages = Math.ceil(total / limit);

  // Still discovering which office this user manages
  if (officesLoading) {
    return (
      <div className="flex items-center justify-center h-full py-24">
        <Loader2 size={32} className="animate-spin text-indigo-400" />
      </div>
    );
  }

  // No office found for this user
  if (!officeId) {
    return (
      <div className="flex flex-col items-center justify-center h-full py-24 text-center">
        <Building2 size={48} className="text-gray-300 mb-4" />
        <h2 className="text-lg font-semibold text-gray-700">
          {t("officeCouriers.noOffice")}
        </h2>
        <p className="text-sm text-gray-400 mt-1">
          {t("officeCouriers.noOfficeDesc")}
        </p>
      </div>
    );
  }

  return (
    <div className="p-6 space-y-5">
      {showAssign && officeId && (
        <AddCourierModal
          officeId={officeId}
          onClose={() => setShowAssign(false)}
        />
      )}

      {/* Header */}
      <div className="flex items-center justify-between flex-wrap gap-3">
        <div className="flex items-center gap-3">
          <Truck size={20} className="text-indigo-600" />
          <div>
            <h1 className="text-xl font-bold text-gray-900">{officeName}</h1>
            <p className="text-xs text-gray-500">
              {total} {t("officeCouriers.couriersCount")}
            </p>
          </div>
        </div>
        <div className="flex items-center gap-2">
          <button
            onClick={() => refetch()}
            disabled={isFetching}
            className="p-2 border border-gray-200 rounded-lg text-gray-500 hover:bg-gray-50 disabled:opacity-50"
          >
            <RefreshCw size={14} className={isFetching ? "animate-spin" : ""} />
          </button>
          <button
            onClick={() => setShowAssign(true)}
            disabled={!officeId}
            className="flex items-center gap-2 px-4 py-2 bg-indigo-600 text-white rounded-xl text-sm font-medium hover:bg-indigo-700 disabled:opacity-50"
          >
            <Plus size={15} /> {t("officeCouriers.addCourier")}
          </button>
        </div>
      </div>

      {/* Search */}
      <div className="relative w-64">
        <Search
          size={14}
          className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400"
        />
        <input
          value={search}
          onChange={(e) => {
            setSearch(e.target.value);
            setPage(1);
          }}
          placeholder={t("officeCouriers.searchPlaceholder")}
          className="pl-9 pr-4 py-2 border border-gray-200 rounded-lg text-sm outline-none focus:ring-2 focus:ring-indigo-500 w-full"
        />
      </div>

      {/* Table */}
      <div className="bg-white rounded-xl border border-gray-200 overflow-hidden">
        {isLoading ? (
          <div className="flex items-center justify-center py-16">
            <RefreshCw size={24} className="animate-spin text-indigo-400" />
          </div>
        ) : couriers.length === 0 ? (
          <div className="text-center py-16 text-gray-400">
            <Truck size={40} className="mx-auto mb-3 opacity-30" />
            <p className="text-sm">{t("officeCouriers.noCouriers")}</p>
            <button
              onClick={() => setShowAssign(true)}
              className="mt-3 text-xs text-indigo-600 hover:underline"
            >
              {t("officeCouriers.addFirst")}
            </button>
          </div>
        ) : (
          <table className="w-full text-sm">
            <thead className="bg-gray-50 border-b border-gray-200">
              <tr>
                {[
                  t("officeCouriers.colCourier"),
                  t("officeCouriers.colPhone"),
                  t("officeCouriers.colVehicle"),
                  t("officeCouriers.colStatus"),
                  t("officeCouriers.colActions"),
                ].map((h) => (
                  <th
                    key={h}
                    className="px-4 py-3 text-left text-xs font-semibold text-gray-500 uppercase tracking-wide"
                  >
                    {h}
                  </th>
                ))}
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-100">
              {couriers.map((c, idx) => {
                // c is a Courier record; c.user is the linked User
                const courierId = c.id;
                const u = c.user ?? {};
                return (
                  <tr
                    key={c.id ?? `courier-${idx}`}
                    className="hover:bg-gray-50 transition"
                  >
                    <td className="px-4 py-3">
                      <div className="flex items-center gap-2">
                        {u.personal_photo ? (
                          <img
                            src={u.personal_photo}
                            alt={u.full_name}
                            className="w-8 h-8 rounded-full object-cover"
                            onError={(e) => {
                              (e.target as HTMLImageElement).style.display =
                                "none";
                            }}
                          />
                        ) : (
                          <div className="w-8 h-8 rounded-full bg-indigo-100 flex items-center justify-center text-indigo-600 font-bold text-xs">
                            {u.full_name?.[0]}
                          </div>
                        )}
                        <div>
                          <p className="font-medium text-gray-900">
                            {u.full_name ?? "—"}
                          </p>
                          <p className="text-xs text-gray-400">#{u.id}</p>
                        </div>
                      </div>
                    </td>
                    <td className="px-4 py-3">
                      <a
                        href={`tel:${u.phone}`}
                        className="flex items-center gap-1 text-sm text-gray-700 hover:text-green-600"
                      >
                        <Phone size={12} /> {u.phone ?? "—"}
                      </a>
                    </td>
                    <td className="px-4 py-3 text-gray-600 capitalize">
                      {c.vehicle_type ?? "—"}
                    </td>
                    <td className="px-4 py-3">
                      <span
                        className={cn(
                          "flex items-center gap-1 text-xs font-medium w-fit",
                          c.is_approved ? "text-green-600" : "text-amber-600",
                        )}
                      >
                        {c.is_approved ? (
                          <CheckCircle size={12} />
                        ) : (
                          <XCircle size={12} />
                        )}
                        {c.is_approved
                          ? t("officeCouriers.approved")
                          : t("officeCouriers.pending")}
                      </span>
                    </td>
                    <td className="px-4 py-3">
                      <div className="flex items-center gap-1">
                        <a
                          href={`/office/orders?courier_id=${courierId}`}
                          className="p-1.5 hover:bg-indigo-50 text-indigo-500 rounded-lg transition"
                          title={t("officeCouriers.viewOrders")}
                        >
                          <ShoppingBag size={13} />
                        </a>
                        {removeId === courierId ? (
                          <>
                            <button
                              onClick={() => removeMut.mutate(courierId)}
                              disabled={removeMut.isPending}
                              className="p-1.5 bg-red-600 text-white rounded-lg hover:bg-red-700 disabled:opacity-60"
                            >
                              <Check size={13} />
                            </button>
                            <button
                              onClick={() => setRemoveId(null)}
                              className="p-1.5 border border-gray-200 rounded-lg hover:bg-gray-50"
                            >
                              <X size={13} />
                            </button>
                          </>
                        ) : (
                          <button
                            onClick={() => setRemoveId(courierId)}
                            className="p-1.5 hover:bg-red-50 text-red-500 rounded-lg transition"
                            title={t("officeCouriers.removeFromOffice")}
                          >
                            <Trash2 size={13} />
                          </button>
                        )}
                      </div>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        )}
      </div>

      {totalPages > 1 && (
        <div className="flex items-center justify-between">
          <p className="text-sm text-gray-500">
            {t("common.page")} {page} {t("common.of")} {totalPages}
          </p>
          <div className="flex gap-2">
            <button
              onClick={() => setPage((p) => Math.max(1, p - 1))}
              disabled={page === 1}
              className="p-2 border border-gray-200 rounded-lg disabled:opacity-40 hover:bg-gray-50"
            >
              <ChevronLeft size={16} />
            </button>
            <button
              onClick={() => setPage((p) => Math.min(totalPages, p + 1))}
              disabled={page === totalPages}
              className="p-2 border border-gray-200 rounded-lg disabled:opacity-40 hover:bg-gray-50"
            >
              <ChevronRight size={16} />
            </button>
          </div>
        </div>
      )}
    </div>
  );
}
