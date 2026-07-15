"use client";

import { useState } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { useParams, useRouter } from "next/navigation";
import { fetchUser, deleteUser } from "@/lib/users";
import { fetchCourierOffices, assignCourierToOffice, type CourierOffice } from "@/lib/courier-offices";
import { fetchVehicles } from "@/lib/vehicles";
import { approveCourier } from "@/lib/courier-approvals";
import { sendCourierApprovalNotification } from "@/lib/notifications";
import {
  fetchProfileUpdateRequests,
  approveProfileUpdateRequest,
  rejectProfileUpdateRequest,
  type ProfileUpdateRequest,
} from "@/lib/profile-update-requests";
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
  Truck,
  Building,
  Navigation,
  Star,
  Pencil,
  Trash2,
  MessageSquare,
  PhoneCall,
  Archive,
  DollarSign,
  X,
  Check,
  FileImage,
  FileWarning,
  ExternalLink,
} from "lucide-react";

import { cn } from "@/lib/utils";
import UserWalletSection from "@/components/users/UserWalletSection";
import UserForm from "@/components/users/UserForm";
import SettleBalanceModal from "@/components/users/SettleBalanceModal";
import api from "@/lib/api";
import toast from "react-hot-toast";

// ── Document image thumbnail with lightbox ────────────────────────────────────
function DocImage({ label, url }: { label: string; url?: string | null }) {
  const [open, setOpen] = useState(false);
  if (!url) {
    return (
      <div className="flex flex-col items-center justify-center border border-dashed border-gray-200 rounded-xl p-4 bg-gray-50 min-h-[110px]">
        <FileImage size={22} className="text-gray-300 mb-1" />
        <p className="text-xs text-gray-400 text-center font-medium">{label}</p>
        <p className="text-xs text-gray-300 mt-0.5">Not uploaded</p>
      </div>
    );
  }
  return (
    <>
      <div className="cursor-pointer group rounded-xl overflow-hidden border border-gray-200 hover:border-indigo-300 transition" onClick={() => setOpen(true)}>
        <img src={url} alt={label} className="w-full h-28 object-cover group-hover:opacity-90 transition" />
        <p className="text-xs text-gray-500 text-center py-1.5 px-2 truncate bg-white">{label}</p>
      </div>
      {open && (
        <div className="fixed inset-0 z-[200] bg-black/85 flex items-center justify-center p-4" onClick={() => setOpen(false)}>
          <div className="relative max-w-3xl w-full" onClick={e => e.stopPropagation()}>
            <p className="text-white text-sm font-medium mb-3 text-center">{label}</p>
            <img src={url} alt={label} className="w-full max-h-[80vh] object-contain rounded-xl shadow-2xl" />
            <div className="flex justify-center gap-3 mt-4">
              <a href={url} target="_blank" rel="noreferrer" className="flex items-center gap-2 px-4 py-2 bg-white/20 hover:bg-white/30 text-white rounded-xl text-sm transition" onClick={e => e.stopPropagation()}>
                <ExternalLink size={14} /> Open original
              </a>
              <button onClick={() => setOpen(false)} className="flex items-center gap-2 px-4 py-2 bg-white/20 hover:bg-white/30 text-white rounded-xl text-sm transition">
                <X size={14} /> Close
              </button>
            </div>
          </div>
        </div>
      )}
    </>
  );
}

const PROFILE_UPDATE_FIELD_LABELS: Record<string, string> = {
  personal_photo: "Personal Photo",
  national_id_photo_front: "National ID (Front)",
  national_id_photo_back: "National ID (Back)",
  vehicle_license_front: "Vehicle License (Front)",
  vehicle_license_back: "Vehicle License (Back)",
  courier_license_front: "Driver License (Front)",
  courier_license_back: "Driver License (Back)",
  courier_criminal_record: "Criminal Record",
  national_id_number: "National ID Number",
  vehicle_plate: "Vehicle Plate",
};

function isImageUrl(value: unknown): value is string {
  return typeof value === "string" && /^https?:\/\//.test(value);
}

function RejectReasonModal({
  onClose,
  onConfirm,
}: Readonly<{ onClose: () => void; onConfirm: (reason: string) => void }>) {
  const { t } = useT();
  const [reason, setReason] = useState("");

  return (
    <div className="fixed inset-0 z-50 bg-black/40 flex items-center justify-center p-4">
      <div className="bg-white rounded-2xl shadow-2xl w-full max-w-sm">
        <div className="flex items-center justify-between p-5 border-b border-gray-100">
          <h2 className="text-base font-semibold text-gray-900">
            {t("users.profileUpdateReject")}
          </h2>
          <button
            onClick={onClose}
            className="p-1.5 hover:bg-gray-100 rounded-lg"
          >
            <X size={16} />
          </button>
        </div>
        <div className="p-4">
          <p className="text-sm text-gray-500 mb-2">
            {t("users.profileUpdateRejectReasonPrompt")}
          </p>
          <textarea
            value={reason}
            onChange={(e) => setReason(e.target.value)}
            rows={3}
            maxLength={255}
            className="w-full text-sm border border-gray-300 rounded-xl px-3 py-2 resize-none focus:ring-2 focus:ring-indigo-500 outline-none"
          />
        </div>
        <div className="flex justify-end gap-2 p-4 border-t border-gray-100">
          <button
            onClick={onClose}
            className="px-4 py-2 text-sm border border-gray-200 rounded-xl hover:bg-gray-50"
          >
            {t("common.cancel")}
          </button>
          <button
            onClick={() => reason.trim() && onConfirm(reason.trim())}
            disabled={!reason.trim()}
            className="px-4 py-2 text-sm bg-red-600 text-white rounded-xl hover:bg-red-700 disabled:opacity-50"
          >
            {t("users.profileUpdateReject")}
          </button>
        </div>
      </div>
    </div>
  );
}

function ProfileUpdateRequestsCard({ userId }: { userId: number }) {
  const { t } = useT();
  const qc = useQueryClient();
  const [rejectingId, setRejectingId] = useState<number | null>(null);

  const { data, isLoading } = useQuery({
    queryKey: ["profile-update-requests", userId, "PENDING"],
    queryFn: () =>
      fetchProfileUpdateRequests({
        user_id: userId,
        status: "PENDING",
        limit: 10,
      }),
    enabled: !!userId,
  });

  const invalidate = () => {
    qc.invalidateQueries({
      queryKey: ["profile-update-requests", userId, "PENDING"],
    });
    qc.invalidateQueries({ queryKey: ["user", userId, "details"] });
  };

  const approveMut = useMutation({
    mutationFn: (requestId: number) => approveProfileUpdateRequest(requestId),
    onSuccess: () => {
      toast.success(t("users.profileUpdateApproved"));
      invalidate();
    },
    onError: (e: any) => toast.error(e?.response?.data?.message ?? "Failed"),
  });

  const rejectMut = useMutation({
    mutationFn: ({
      requestId,
      reason,
    }: {
      requestId: number;
      reason: string;
    }) => rejectProfileUpdateRequest(requestId, reason),
    onSuccess: () => {
      toast.success(t("users.profileUpdateRejected"));
      setRejectingId(null);
      invalidate();
    },
    onError: (e: any) => toast.error(e?.response?.data?.message ?? "Failed"),
  });

  const requests: ProfileUpdateRequest[] = data?.requests ?? [];

  return (
    <>
      {rejectingId !== null && (
        <RejectReasonModal
          onClose={() => setRejectingId(null)}
          onConfirm={(reason) =>
            rejectMut.mutate({ requestId: rejectingId, reason })
          }
        />
      )}
      <div className="bg-white rounded-xl border border-amber-200 p-6">
        <div className="flex items-center gap-2 mb-1">
          <FileWarning size={18} className="text-amber-500" />
          <h3 className="text-lg font-medium text-gray-900">
            {t("users.profileUpdateRequests")}
          </h3>
          {requests.length > 0 && (
            <span className="text-xs bg-amber-100 text-amber-700 px-2 py-0.5 rounded-full font-medium">
              {requests.length}
            </span>
          )}
        </div>
        <p className="text-sm text-gray-500 mb-4">
          {t("users.profileUpdateRequestsDesc")}
        </p>

        {isLoading ? (
          <div className="flex justify-center py-6">
            <Loader2 size={20} className="animate-spin text-amber-400" />
          </div>
        ) : requests.length === 0 ? (
          <div className="text-center py-8 text-sm text-gray-400">
            No pending document updates.
          </div>
        ) : (
          <div className="space-y-4">
          {requests.map((request) => (
            <div
              key={request.id}
              className="border border-gray-200 rounded-xl p-4"
            >
              <div className="flex items-center justify-between mb-3">
                <p className="text-xs text-gray-400">
                  {t("users.profileUpdateSubmittedAt")}:{" "}
                  {new Date(request.created_at).toLocaleString()}
                </p>
                <div className="flex items-center gap-2">
                  <button
                    onClick={() => approveMut.mutate(request.id)}
                    disabled={approveMut.isPending}
                    className="flex items-center gap-1.5 px-3 py-1.5 bg-green-600 text-white text-xs rounded-lg hover:bg-green-700 disabled:opacity-50 transition"
                  >
                    {approveMut.isPending &&
                    approveMut.variables === request.id ? (
                      <Loader2 size={12} className="animate-spin" />
                    ) : (
                      <Check size={12} />
                    )}
                    {t("users.profileUpdateApprove")}
                  </button>
                  <button
                    onClick={() => setRejectingId(request.id)}
                    className="flex items-center gap-1.5 px-3 py-1.5 border border-red-200 text-red-600 text-xs rounded-lg hover:bg-red-50 transition"
                  >
                    <X size={12} />
                    {t("users.profileUpdateReject")}
                  </button>
                </div>
              </div>

              <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
                {Object.entries(request.data ?? {}).map(([key, value]) => (
                  <div key={key}>
                    <p className="text-xs text-gray-500 uppercase tracking-wide mb-1">
                      {PROFILE_UPDATE_FIELD_LABELS[key] ?? key}
                    </p>
                    {isImageUrl(value) ? (
                      <a
                        href={value}
                        target="_blank"
                        rel="noopener noreferrer"
                        className="flex items-center gap-1 text-xs text-indigo-600 hover:underline"
                      >
                        <img
                          src={value}
                          alt={key}
                          className="w-full h-20 object-cover rounded-lg border border-gray-100 mb-1"
                        />
                        <ExternalLink size={11} />
                        {t("users.viewImage")}
                      </a>
                    ) : (
                      <p className="text-sm text-gray-900">{String(value)}</p>
                    )}
                  </div>
                ))}
              </div>
            </div>
          ))}
          </div>
        )}
      </div>
    </>
  );
}

function ChangeOfficeModal({ courierId, currentOfficeId, onClose }: { courierId: number; currentOfficeId: number | null | undefined; onClose: () => void }) {
  const qc = useQueryClient();
  const [selected, setSelected] = useState<number | null>(null);

  const { data: officesData, isLoading } = useQuery({
    queryKey: ["courier-offices-list"],
    queryFn: () => fetchCourierOffices({ limit: 50 }),
    staleTime: 60_000,
  });

  const mut = useMutation({
    mutationFn: (officeId: number) => assignCourierToOffice(courierId, officeId),
    onSuccess: () => {
      toast.success("Office assigned");
      qc.invalidateQueries({ queryKey: ["user"] });
      onClose();
    },
    onError: (e: any) => toast.error(e?.response?.data?.message ?? "Failed to assign office"),
  });

  const removeMut = useMutation({
    mutationFn: () => api.post("/admin/courier-office/append-courier-to-office", { courierId: String(courierId) }),
    onSuccess: () => {
      toast.success("Removed from office");
      qc.invalidateQueries({ queryKey: ["user"] });
      onClose();
    },
    onError: (e: any) => toast.error(e?.response?.data?.message ?? "Failed"),
  });

  const offices: CourierOffice[] = officesData?.couriers ?? [];

  return (
    <div className="fixed inset-0 z-50 bg-black/40 flex items-center justify-center p-4">
      <div className="bg-white rounded-2xl shadow-2xl w-full max-w-sm">
        <div className="flex items-center justify-between p-5 border-b border-gray-100">
          <h2 className="text-base font-semibold text-gray-900">Assign to Office</h2>
          <button onClick={onClose} className="p-1.5 hover:bg-gray-100 rounded-lg"><X size={16} /></button>
        </div>
        <div className="p-4 space-y-2 max-h-72 overflow-y-auto">
          {isLoading ? (
            <div className="flex justify-center py-6"><Loader2 size={20} className="animate-spin text-indigo-400" /></div>
          ) : offices.length === 0 ? (
            <p className="text-center text-sm text-gray-400 py-4">No offices found</p>
          ) : (
            offices.map((o) => (
              <button
                key={o.id}
                onClick={() => setSelected(o.id)}
                className={cn(
                  "w-full flex items-center justify-between px-4 py-3 rounded-xl border text-left transition",
                  selected === o.id
                    ? "border-indigo-500 bg-indigo-50"
                    : currentOfficeId === o.id
                    ? "border-green-300 bg-green-50"
                    : "border-gray-200 hover:border-indigo-300 hover:bg-gray-50"
                )}
              >
                <div>
                  <p className="text-sm font-medium text-gray-900">{o.name}</p>
                  {o.address && <p className="text-xs text-gray-400 mt-0.5">{o.address}</p>}
                </div>
                {currentOfficeId === o.id && <span className="text-xs text-green-600 font-medium">Current</span>}
                {selected === o.id && currentOfficeId !== o.id && <Check size={14} className="text-indigo-600" />}
              </button>
            ))
          )}
        </div>
        <div className="flex justify-between gap-2 p-4 border-t border-gray-100">
          {currentOfficeId && (
            <button
              onClick={() => removeMut.mutate()}
              disabled={removeMut.isPending || mut.isPending}
              className="px-4 py-2 text-sm border border-red-200 text-red-600 rounded-xl hover:bg-red-50 disabled:opacity-50"
            >
              Remove
            </button>
          )}
          <div className="flex gap-2 ml-auto">
            <button onClick={onClose} className="px-4 py-2 text-sm border border-gray-200 rounded-xl hover:bg-gray-50">Cancel</button>
            <button
              onClick={() => selected && mut.mutate(selected)}
              disabled={!selected || selected === currentOfficeId || mut.isPending}
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

export default function CourierDetailPage() {
  const { t } = useT();
  const router = useRouter();
  const qc = useQueryClient();
  const params = useParams();
  const userId = Number(params.userId);

  const [showEdit, setShowEdit] = useState(false);
  const [deleteMode, setDeleteMode] = useState<"archive" | "hard" | null>(null);
  const [showSettle, setShowSettle] = useState(false);
  const [showChangeOffice, setShowChangeOffice] = useState(false);

  const archiveMut = useMutation({
    mutationFn: () => deleteUser(userId, true),
    onSuccess: () => {
      toast.success(t("users.userArchived"));
      router.push("/users");
    },
    onError: (e: any) =>
      toast.error(e?.response?.data?.message ?? t("users.deleteError")),
  });
  const hardDeleteMut = useMutation({
    mutationFn: () => deleteUser(userId, false),
    onSuccess: () => {
      toast.success(t("users.userDeleted"));
      router.push("/users");
    },
    onError: (e: any) =>
      toast.error(e?.response?.data?.message ?? t("users.deleteError")),
  });

  const { data: user, isLoading } = useQuery({
    queryKey: ["user", userId, "details"],
    queryFn: () => fetchUser(userId, "role,badge,courier,wallet"),
    enabled: !!userId,
  });

  // Resolve vehicle name (vehicle_id → name) and office name (courier_office_id → name)
  const { data: vehiclesData } = useQuery({
    queryKey: ["admin-vehicles-all"],
    queryFn: () => fetchVehicles({ limit: 100 }),
    staleTime: 10 * 60_000,
  });
  const { data: officesData } = useQuery({
    queryKey: ["courier-offices-list-all"],
    queryFn: () => fetchCourierOffices({ limit: 100 }),
    staleTime: 5 * 60_000,
  });

  const approveMut = useMutation({
    mutationFn: (courierId: number) => approveCourier(courierId),
    onSuccess: () => {
      toast.success("Courier approved successfully!");
      qc.invalidateQueries({ queryKey: ["user", userId, "details"] });
      // Send bilingual push notification to the courier's device (fire-and-forget)
      sendCourierApprovalNotification(userId).catch(() => {});
    },
    onError: (e: any) => toast.error(e?.response?.data?.message ?? "Failed to approve"),
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

  const courier = user.courier;

  // Resolved display values (from separately-fetched lists)
  const allVehicles = vehiclesData?.vehicles ?? [];
  // Coerce to Number in case vehicle_id comes back as a string from the API
  const resolvedVehicle = allVehicles.find(v => v.id === Number((courier as any)?.vehicle_id));
  const vehicleName = resolvedVehicle
    ? `${resolvedVehicle.name}${resolvedVehicle.name_ar ? ` / ${resolvedVehicle.name_ar}` : ""}`
    : "—";

  const allOffices = officesData?.couriers ?? [];
  // courier_office_id can be returned as a string by the API (Prisma BigInt serialisation),
  // so we coerce both sides to Number for comparison. Also fall back to the nested
  // courierOffice relation if it happens to be included in the user response.
  const resolvedOfficeName =
    courier?.courierOffice?.name ??
    allOffices.find(o => o.id === Number(courier?.courier_office_id))?.name;
  const officeName = resolvedOfficeName ?? "Not assigned";

  return (
    <div className="p-6 space-y-6">
      {showChangeOffice && courier?.id && (
        <ChangeOfficeModal
          courierId={courier.id}
          currentOfficeId={courier.courier_office_id}
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
        <div className="flex items-center gap-3">
          {user.personal_photo ? (
            <img
              src={user.personal_photo}
              alt={user.full_name}
              className="w-12 h-12 rounded-full object-cover border-2 border-gray-200"
            />
          ) : (
            <div className="w-12 h-12 rounded-full bg-green-100 flex items-center justify-center border-2 border-gray-200">
              <Truck size={24} className="text-green-600" />
            </div>
          )}
          <div>
            <h1 className="text-2xl font-bold text-gray-900">
              {user.full_name}
            </h1>
            <p className="text-sm text-gray-500">{t("users.courierDetails")}</p>
          </div>
        </div>
      </div>

      {/* Actions Block */}
      <div className="bg-white rounded-xl border border-gray-200 p-4">
        <div className="flex flex-wrap items-center gap-2">
          {/* ── Courier-specific primary actions ─────────────────── */}
          {courier?.id && !courier?.is_approved && (
            <button
              onClick={() => approveMut.mutate(courier.id!)}
              disabled={approveMut.isPending}
              className="flex items-center gap-2 px-4 py-2 bg-green-600 hover:bg-green-700 text-white rounded-xl text-sm font-semibold transition shadow-sm"
            >
              {approveMut.isPending ? <Loader2 size={15} className="animate-spin" /> : <CheckCircle size={15} />}
              Approve Courier
            </button>
          )}
          {courier?.id && (
            <button
              onClick={() => setShowChangeOffice(true)}
              className="flex items-center gap-2 px-4 py-2 bg-indigo-600 hover:bg-indigo-700 text-white rounded-xl text-sm font-semibold transition shadow-sm"
            >
              <Building size={15} />
              {courier.courier_office_id ? "Change Office" : "Assign to Office"}
            </button>
          )}

          {/* Track location */}
          <button
            onClick={() => router.push(`/couriers-map?courier_id=${user.id}`)}
            className="flex items-center gap-2 px-4 py-2 bg-blue-600 hover:bg-blue-700 text-white rounded-xl text-sm font-medium transition"
          >
            <Navigation size={15} /> Track Location
          </button>
          {/* Phone */}
          {user.phone && (
            <a
              href={`tel:${user.phone}`}
              className="flex items-center gap-2 px-4 py-2 bg-green-50 text-green-700 border border-green-200 rounded-xl text-sm font-medium hover:bg-green-100 transition"
            >
              <PhoneCall size={15} /> {user.phone}
            </a>
          )}
          {/* Chat */}
          <a
            href={`/chat?userId=${user.id}`}
            className="flex items-center gap-2 px-4 py-2 bg-indigo-50 text-indigo-700 border border-indigo-200 rounded-xl text-sm font-medium hover:bg-indigo-100 transition"
          >
            <MessageSquare size={15} /> {t("users.chatUser")}
          </a>
          {/* Settle Balance */}
          <button
            onClick={() => setShowSettle(true)}
            className="flex items-center gap-2 px-4 py-2 bg-emerald-50 text-emerald-700 border border-emerald-200 rounded-xl text-sm font-medium hover:bg-emerald-100 transition"
          >
            <DollarSign size={15} /> Settle Balance
          </button>
          {/* Edit */}
          <button
            onClick={() => setShowEdit(true)}
            className="flex items-center gap-2 px-4 py-2 bg-white text-gray-700 border border-gray-300 rounded-xl text-sm font-medium hover:bg-gray-50 transition"
          >
            <Pencil size={15} /> {t("users.editUser")}
          </button>
          {/* Delete */}
          {deleteMode === null ? (
            <button
              onClick={() => setDeleteMode("archive")}
              className="flex items-center gap-2 px-4 py-2 bg-red-50 text-red-700 border border-red-200 rounded-xl text-sm font-medium hover:bg-red-100 transition"
            >
              <Trash2 size={15} /> {t("users.deleteUser")}
            </button>
          ) : (
            <div className="flex items-center gap-1 bg-white border border-gray-200 rounded-xl p-1">
              <button
                onClick={() => archiveMut.mutate()}
                disabled={archiveMut.isPending}
                className="flex items-center gap-1.5 px-3 py-1.5 bg-amber-500 text-white rounded-lg text-xs font-medium hover:bg-amber-600 disabled:opacity-60"
              >
                <Archive size={13} /> {t("common.archive")}
              </button>
              <button
                onClick={() => hardDeleteMut.mutate()}
                disabled={hardDeleteMut.isPending}
                className="flex items-center gap-1.5 px-3 py-1.5 bg-red-600 text-white rounded-lg text-xs font-medium hover:bg-red-700 disabled:opacity-60"
              >
                <Trash2 size={13} /> {t("common.deleteForever")}
              </button>
              <button
                onClick={() => setDeleteMode(null)}
                className="px-3 py-1.5 text-gray-500 rounded-lg text-xs hover:bg-gray-100"
              >
                {t("common.cancel")}
              </button>
            </div>
          )}
        </div>
      </div>

      {/* No courier profile notice */}
      {!courier && (
        <div className="flex items-start gap-3 bg-amber-50 border border-amber-200 rounded-xl p-4">
          <XCircle size={18} className="text-amber-500 shrink-0 mt-0.5" />
          <div>
            <p className="text-sm font-semibold text-amber-800">No courier profile yet</p>
            <p className="text-xs text-amber-600 mt-0.5">
              This user has the Courier role but hasn't registered a courier profile through the app.
              Approval and office assignment will be available once they complete their registration.
              You can also approve them from the <a href="/courier-approvals" className="underline font-medium hover:text-amber-800">Courier Approvals</a> page.
            </p>
          </div>
        </div>
      )}

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
              <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-700">
                <Truck size={10} />
                {user.role?.name || "Courier"}
              </span>
            </div>
          </div>

          {/* Badge */}
          <div className="flex items-start gap-3">
            <div className="w-10 h-10 rounded-lg bg-yellow-50 flex items-center justify-center shrink-0">
              <Star size={18} className="text-yellow-600" />
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

          {/* Approval Status */}
          <div className="flex items-start gap-3">
            <div className="w-10 h-10 rounded-lg bg-orange-50 flex items-center justify-center shrink-0">
              <CheckCircle
                size={18}
                className={courier?.is_approved ? "text-green-600" : "text-orange-600"}
              />
            </div>
            <div>
              <p className="text-xs text-gray-500 uppercase tracking-wide">Approval Status</p>
              <div className="flex items-center gap-2 mt-0.5 flex-wrap">
                <span className={cn(
                  "inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-xs font-medium",
                  courier?.is_approved ? "bg-green-100 text-green-700" : "bg-orange-100 text-orange-700",
                )}>
                  {courier?.is_approved ? <CheckCircle size={10} /> : <XCircle size={10} />}
                  {courier?.is_approved ? "Approved" : "Pending Approval"}
                </span>
                {courier?.id && !courier?.is_approved && (
                  <button
                    onClick={() => approveMut.mutate(courier.id!)}
                    disabled={approveMut.isPending}
                    className="flex items-center gap-1 px-2.5 py-1 text-xs bg-green-600 text-white rounded-lg hover:bg-green-700 disabled:opacity-50 transition"
                  >
                    {approveMut.isPending
                      ? <Loader2 size={10} className="animate-spin" />
                      : <Check size={10} />}
                    Approve
                  </button>
                )}
              </div>
            </div>
          </div>

          {/* Vehicle Type */}
          <div className="flex items-start gap-3">
            <div className="w-10 h-10 rounded-lg bg-cyan-50 flex items-center justify-center shrink-0">
              <Truck size={18} className="text-cyan-600" />
            </div>
            <div>
              <p className="text-xs text-gray-500 uppercase tracking-wide">Vehicle Type</p>
              <p className="text-sm font-medium text-gray-900">{vehicleName}</p>
            </div>
          </div>

          {/* Vehicle Plate */}
          <div className="flex items-start gap-3">
            <div className="w-10 h-10 rounded-lg bg-gray-100 flex items-center justify-center shrink-0">
              <MapPin size={18} className="text-gray-600" />
            </div>
            <div>
              <p className="text-xs text-gray-500 uppercase tracking-wide">
                Vehicle Plate
              </p>
              <p className="text-sm font-medium text-gray-900">
                {courier?.vehicle_plate || "—"}
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
                National ID
              </p>
              <p className="text-sm font-medium text-gray-900">
                {courier?.national_id_number || "—"}
              </p>
            </div>
          </div>

          {/* Courier Office */}
          <div className="flex items-start gap-3">
            <div className="w-10 h-10 rounded-lg bg-blue-50 flex items-center justify-center shrink-0">
              <Building size={18} className="text-blue-600" />
            </div>
            <div>
              <p className="text-xs text-gray-500 uppercase tracking-wide">
                Courier Office
              </p>
              <div className="flex items-center gap-2 mt-0.5">
                <p className="text-sm font-medium text-gray-900">
                  {officeName}
                </p>
                {courier?.id && (
                  <button
                    onClick={() => setShowChangeOffice(true)}
                    className="p-1 hover:bg-indigo-50 text-indigo-500 rounded-md transition"
                    title="Change office"
                  >
                    <Pencil size={12} />
                  </button>
                )}
              </div>
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

          {/* Last Location */}
          {(courier?.lat != null || courier?.lng != null) && (
            <div className="flex items-start gap-3">
              <div className="w-10 h-10 rounded-lg bg-blue-50 flex items-center justify-center shrink-0">
                <Navigation size={18} className="text-blue-600" />
              </div>
              <div>
                <p className="text-xs text-gray-500 uppercase tracking-wide">Last Location</p>
                <p className="text-sm font-mono text-gray-900">
                  {Number(courier.lat).toFixed(4)}, {Number(courier.lng).toFixed(4)}
                </p>
              </div>
            </div>
          )}

          {/* Reject Reason (if any) */}
          {courier?.reject_reason && (
            <div className="col-span-full flex items-start gap-3">
              <div className="w-10 h-10 rounded-lg bg-red-50 flex items-center justify-center shrink-0">
                <XCircle size={18} className="text-red-500" />
              </div>
              <div>
                <p className="text-xs text-gray-500 uppercase tracking-wide">Rejection Reason</p>
                <p className="text-sm text-red-600 font-medium">{courier.reject_reason}</p>
              </div>
            </div>
          )}

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

      {/* Location Section */}
      {(courier?.lat != null || courier?.lng != null) && (
        <div className="bg-white rounded-xl border border-gray-200 p-6">
          <div className="flex items-center justify-between mb-4">
            <h2 className="text-lg font-semibold text-gray-900 flex items-center gap-2">
              <Navigation size={18} className="text-blue-600" /> Last Known Location
            </h2>
            {courier.last_location_update && (
              <span className="text-xs text-gray-400">
                Updated: {new Date(courier.last_location_update).toLocaleString()}
              </span>
            )}
          </div>
          <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
            <div className="flex items-start gap-3">
              <div className="w-10 h-10 rounded-lg bg-blue-50 flex items-center justify-center shrink-0">
                <span className="text-xs font-bold text-blue-600">LAT</span>
              </div>
              <div>
                <p className="text-xs text-gray-500 uppercase tracking-wide">Latitude</p>
                <p className="text-sm font-mono font-medium text-gray-900">{Number(courier.lat).toFixed(6)}</p>
              </div>
            </div>
            <div className="flex items-start gap-3">
              <div className="w-10 h-10 rounded-lg bg-blue-50 flex items-center justify-center shrink-0">
                <span className="text-xs font-bold text-blue-600">LNG</span>
              </div>
              <div>
                <p className="text-xs text-gray-500 uppercase tracking-wide">Longitude</p>
                <p className="text-sm font-mono font-medium text-gray-900">{Number(courier.lng).toFixed(6)}</p>
              </div>
            </div>
            <div className="flex items-center gap-2">
              <a
                href={`https://www.google.com/maps?q=${courier.lat},${courier.lng}`}
                target="_blank" rel="noreferrer"
                className="flex items-center gap-2 px-4 py-2 bg-blue-50 text-blue-700 border border-blue-200 rounded-xl text-sm font-medium hover:bg-blue-100 transition"
              >
                <ExternalLink size={14} /> View on Google Maps
              </a>
            </div>
          </div>
        </div>
      )}

      {/* Documents Section */}
      {courier && (
        <div className="bg-white rounded-xl border border-gray-200 p-6">
          <h2 className="text-lg font-semibold text-gray-900 mb-4 flex items-center gap-2">
            <FileImage size={18} className="text-indigo-600" /> Documents
          </h2>

          {/* Rejection reason banner */}
          {courier.reject_reason && (
            <div className="mb-4 p-3 bg-red-50 border border-red-200 rounded-xl text-sm text-red-700">
              <span className="font-semibold">Rejection reason: </span>{courier.reject_reason}
            </div>
          )}

          <div className="space-y-4">
            <p className="text-xs font-semibold text-gray-400 uppercase tracking-wide">National ID</p>
            <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 gap-3">
              <DocImage label="National ID — Front" url={courier.national_id_photo_front} />
              <DocImage label="National ID — Back" url={courier.national_id_photo_back} />
            </div>

            <p className="text-xs font-semibold text-gray-400 uppercase tracking-wide pt-2">Vehicle License</p>
            <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 gap-3">
              <DocImage label="Vehicle License — Front" url={courier.vehicle_license_front} />
              <DocImage label="Vehicle License — Back" url={courier.vehicle_license_back} />
            </div>

            <p className="text-xs font-semibold text-gray-400 uppercase tracking-wide pt-2">Courier License & Record</p>
            <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 gap-3">
              <DocImage label="Courier License — Front" url={courier.courier_license_front} />
              <DocImage label="Courier License — Back" url={courier.courier_license_back} />
              <DocImage label="Criminal Record" url={courier.courier_criminal_record} />
              <DocImage label="Personal Photo" url={user.personal_photo} />
            </div>
          </div>
        </div>
      )}

      {/* Wallet Section */}
      <UserWalletSection userId={userId} />

      {/* Pending Document Updates */}
      <ProfileUpdateRequestsCard userId={user.id} />

      {/* Edit modal */}
      {showEdit && (
        <UserForm
          user={user}
          onClose={() => {
            setShowEdit(false);
            qc.invalidateQueries({ queryKey: ["user", userId, "details"] });
          }}
        />
      )}

      {/* Settle Balance modal */}
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
