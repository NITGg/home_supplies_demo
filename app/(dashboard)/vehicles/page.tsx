"use client";
import { useState, useRef } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { fetchVehicles, createVehicle, updateVehicle, deleteVehicle, type Vehicle } from "@/lib/vehicles";
import { useT } from "@/contexts/LanguageContext";
import { Car, Plus, Pencil, Trash2, RefreshCw, X, Upload, Percent, MapPin, HardDrive, UserCheck } from "lucide-react";
import toast from "react-hot-toast";
import { ALLOWED_IMAGE_ACCEPT, validateImageFile } from "@/lib/file-upload";
import { DataTable, type Column } from "@/components/ui/DataTable";
import { TableToolbar } from "@/components/ui/TableToolbar";
import { TablePagination } from "@/components/ui/TablePagination";
import { DateRangeFilter } from "@/components/ui/DateRangeFilter";
import { ColumnToggle, type ColumnOption } from "@/components/ui/ColumnToggle";
import { useColumnVisibility } from "@/hooks/useColumnVisibility";

// Updated column keys to include new fields
const ALL_COLUMN_KEYS = [
  "icon", "name", "name_ar", "price_per_km", 
  "fee_base_distance_km", "fee_extra_platform_per_km", "fee_extra_courier_per_km", "peak_time_fee_ratio",
  "created_at", "updated_at", "actions"
] as const;

export default function VehiclesPage() {
  const { t } = useT();
  const qc = useQueryClient();
  const [page, setPage] = useState(1);
  const [search, setSearch] = useState("");
  const [createdFrom, setCreatedFrom] = useState("");
  const [createdTo, setCreatedTo] = useState("");
  const [updatedFrom, setUpdatedFrom] = useState("");
  const [updatedTo, setUpdatedTo] = useState("");
  const [delConfirm, setDelConfirm] = useState<number | null>(null);
  const [modalOpen, setModalOpen] = useState(false);
  const [editing, setEditing] = useState<Vehicle | null>(null);

  const { visible, setVisible } = useColumnVisibility("cols:vehicles", [...ALL_COLUMN_KEYS]);

  const params: Record<string, string | number> = { page, limit: 20 };
  if (search) params.keyword = search;

  const { data, isLoading, refetch, isFetching } = useQuery({
    queryKey: ["vehicles", params],
    queryFn: () => fetchVehicles(params),
  });

  const allVehicles = data?.vehicles ?? [];
  const vehicles = allVehicles.filter(v => {
    if (createdFrom && new Date(v.created_at) < new Date(createdFrom)) return false;
    if (createdTo && new Date(v.created_at) > new Date(createdTo + "T23:59:59")) return false;
    if (updatedFrom && new Date(v.updated_at) < new Date(updatedFrom)) return false;
    if (updatedTo && new Date(v.updated_at) > new Date(updatedTo + "T23:59:59")) return false;
    return true;
  });

  const total = data?.pagination?.total ?? 0;
  const totalPages = data?.pagination?.total_pages ?? 1;
  const displayTotal = (createdFrom || createdTo || updatedFrom || updatedTo) ? vehicles.length : total;

  const deleteMut = useMutation({
    mutationFn: (id: number) => deleteVehicle(id),
    onSuccess: () => { toast.success(t("vehicles.deleted")); qc.invalidateQueries({ queryKey: ["vehicles"] }); setDelConfirm(null); },
    onError: () => toast.error(t("vehicles.deleteError")),
  });

  const allColumns: Column<Vehicle>[] = [
    {
      key: "icon",
      label: t("vehicles.icon"),
      render: v => v.icon
        ? <img src={v.icon} alt={v.name} className="w-10 h-10 rounded-lg object-cover" />
        : <div className="w-10 h-10 rounded-lg bg-gray-100 flex items-center justify-center"><Car size={18} className="text-gray-400" /></div>,
    },
    {
      key: "name",
      label: t("vehicles.nameEn"),
      sortable: true,
      getValue: v => v.name,
      render: v => <span className="font-medium text-gray-900">{v.name}</span>,
    },
    {
      key: "name_ar",
      label: t("vehicles.nameAr"),
      render: v => <span className="text-gray-700" dir="rtl">{v.name_ar}</span>,
    },
    {
      key: "price_per_km",
      label: t("vehicles.pricePerKm"),
      sortable: true,
      getValue: v => v.price_per_km ?? 0,
      render: v => <span className="text-gray-600">{v.price_per_km != null ? `${v.price_per_km} EGP` : "—"}</span>,
    },
    // NEW COLUMNS IN TABLE
    {
        key: "fee_base_distance_km",
        label: "Base KM",
        render: v => <span className="text-gray-600 font-mono">{v.fee_base_distance_km}km</span>
    },
    {
        key: "peak_time_fee_ratio",
        label: "Peak %",
        render: v => <span className="text-indigo-600 font-medium">{v.peak_time_fee_ratio}%</span>
    },
    {
      key: "created_at",
      label: t("common.createdAt"),
      sortable: true,
      getValue: v => new Date(v.created_at),
      render: v => (
        <span className="text-xs text-gray-500">
          {new Date(v.created_at).toLocaleDateString(undefined, { year: "numeric", month: "short", day: "numeric" })}
        </span>
      ),
    },
    {
      key: "actions",
      label: t("common.actions"),
      align: "right",
      render: v => (
        <div className="flex items-center justify-end gap-2">
          {delConfirm === v.id ? (
            <>
              <button onClick={() => deleteMut.mutate(v.id)} disabled={deleteMut.isPending} className="px-3 py-1.5 text-xs bg-red-600 text-white rounded-lg disabled:opacity-50">{t("common.yes")}</button>
              <button onClick={() => setDelConfirm(null)} className="px-3 py-1.5 text-xs border border-gray-300 rounded-lg">{t("common.cancel")}</button>
            </>
          ) : (
            <>
              <button onClick={() => { setEditing(v); setModalOpen(true); }} className="p-2 rounded-lg text-gray-400 hover:text-indigo-600 hover:bg-indigo-50"><Pencil size={15} /></button>
              <button onClick={() => setDelConfirm(v.id)} className="p-2 rounded-lg text-gray-400 hover:text-red-600 hover:bg-red-50"><Trash2 size={15} /></button>
            </>
          )}
        </div>
      ),
    },
  ];

  const columns = allColumns.filter(c => visible.includes(c.key));
  const columnOptions: ColumnOption[] = allColumns.map(c => ({ key: c.key, label: c.label, alwaysVisible: c.key === "actions" }));

  return (
    <div className="p-6 space-y-6">
      <div className="flex items-start justify-between flex-wrap gap-3">
        <div>
          <div className="flex items-center gap-2 mb-1">
            <Car size={22} className="text-indigo-600" />
            <h1 className="text-2xl font-bold text-gray-900">{t("vehicles.title")}</h1>
          </div>
          <p className="text-sm text-gray-500">{t("vehicles.subtitle")}</p>
        </div>
        <button onClick={() => refetch()} disabled={isFetching} className="flex items-center gap-2 px-4 py-2 border border-gray-300 rounded-xl text-sm text-gray-600 hover:bg-gray-50 disabled:opacity-50">
          <RefreshCw size={15} className={isFetching ? "animate-spin" : ""} /> {t("common.refresh")}
        </button>
      </div>

      <TableToolbar
        total={displayTotal}
        totalLabel="vehicle"
        search={search}
        onSearch={v => { setSearch(v); setPage(1); }}
        searchPlaceholder={t("vehicles.searchPlaceholder")}
        action={
          <div className="flex items-center gap-2">
            <ColumnToggle columns={columnOptions} visible={visible} onChange={setVisible} />
            <button onClick={() => { setEditing(null); setModalOpen(true); }} className="flex items-center gap-2 px-4 py-2 bg-indigo-600 text-white rounded-xl text-sm hover:bg-indigo-700">
              <Plus size={16} /> {t("vehicles.new")}
            </button>
          </div>
        }
      >
        <DateRangeFilter label={t("common.createdAt")} from={createdFrom} to={createdTo} onFromChange={v => { setCreatedFrom(v); setPage(1); }} onToChange={v => { setCreatedTo(v); setPage(1); }} />
      </TableToolbar>

      <DataTable columns={columns} rows={vehicles} keyExtractor={v => v.id} isLoading={isLoading} emptyText={t("vehicles.noResults")} emptyIcon={<Car size={36} className="text-gray-300" />} />

      <TablePagination page={page} totalPages={totalPages} total={displayTotal} limit={20} onPageChange={setPage} />

      {modalOpen && (
        <VehicleModal vehicle={editing} onClose={() => { setModalOpen(false); setEditing(null); }}
          onSaved={() => { setModalOpen(false); setEditing(null); qc.invalidateQueries({ queryKey: ["vehicles"] }); }} t={t} />
      )}
    </div>
  );
}

function VehicleModal({ vehicle, onClose, onSaved, t }: Readonly<{ vehicle: Vehicle | null; onClose: () => void; onSaved: () => void; t: (k: string) => string }>) {
  const [form, setForm] = useState({
    name: vehicle?.name ?? "",
    name_ar: vehicle?.name_ar ?? "",
    price_per_km: vehicle?.price_per_km?.toString() ?? "",
    min_distance_per_km: vehicle?.min_distance_per_km?.toString() ?? "",
    max_distance_per_km: vehicle?.max_distance_per_km?.toString() ?? "",
    min_delivery_fee: vehicle?.min_delivery_fee?.toString() ?? "",
    delivery_price_for_each_1m: vehicle?.delivery_price_for_each_1m?.toString() ?? "",
    delivery_fee_ratio: vehicle?.delivery_fee_ratio?.toString() ?? "",
    // New fields added to state
    fee_base_distance_km: vehicle?.fee_base_distance_km?.toString() ?? "2",
    fee_extra_platform_per_km: vehicle?.fee_extra_platform_per_km?.toString() ?? "100",
    fee_extra_courier_per_km: vehicle?.fee_extra_courier_per_km?.toString() ?? "100",
    peak_time_fee_ratio: vehicle?.peak_time_fee_ratio?.toString() ?? "20",
  });
  
  const [iconFile, setIconFile] = useState<File | null>(null);
  const [previewUrl, setPreviewUrl] = useState<string | null>(vehicle?.icon ?? null);
  const fileRef = useRef<HTMLInputElement>(null);

  const saveMut = useMutation({
    mutationFn: () => {
      const fd = new FormData();
      Object.entries(form).forEach(([k, v]) => { if (v !== "") fd.append(k, v); });
      if (iconFile) fd.append("icon", iconFile);
      return vehicle ? updateVehicle(vehicle.id, fd) : createVehicle(fd);
    },
    onSuccess: () => { toast.success(vehicle ? t("vehicles.updated") : t("vehicles.created")); onSaved(); },
    onError: () => toast.error("Save failed"),
  });

  const set = (k: keyof typeof form, v: string) => setForm(p => ({ ...p, [k]: v }));

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4">
      <div className="bg-white rounded-2xl shadow-2xl w-full max-w-xl max-h-[95vh] overflow-y-auto">
        <div className="flex items-center justify-between px-6 py-5 border-b border-gray-100 sticky top-0 bg-white z-10">
          <h2 className="text-lg font-bold text-gray-900">{vehicle ? t("common.edit") : t("vehicles.new")}</h2>
          <button onClick={onClose} className="p-2 rounded-xl hover:bg-gray-100 text-gray-400"><X size={18} /></button>
        </div>
        
        <form onSubmit={e => { e.preventDefault(); saveMut.mutate(); }} className="px-6 py-5 space-y-6">
          {/* Basic Info */}
          <section className="space-y-4">
            <h3 className="text-xs font-bold text-indigo-500 uppercase tracking-wider">Basic Information</h3>
            <div className="grid grid-cols-2 gap-4">
              <div className="space-y-1.5">
                <label className="text-xs font-semibold text-gray-600 uppercase">{t("vehicles.nameEn")}</label>
                <input required value={form.name} onChange={e => set("name", e.target.value)} className="input" />
              </div>
              <div className="space-y-1.5">
                <label className="text-xs font-semibold text-gray-600 uppercase">{t("vehicles.nameAr")}</label>
                <input required value={form.name_ar} onChange={e => set("name_ar", e.target.value)} dir="rtl" className="input text-right" />
              </div>
            </div>
          </section>

          {/* Pricing Config */}
          <section className="space-y-4">
            <h3 className="text-xs font-bold text-indigo-500 uppercase tracking-wider">Distance & Base Pricing</h3>
            <div className="grid grid-cols-2 gap-4">
              <div className="space-y-1.5">
                <label className="text-xs font-semibold text-gray-600 uppercase">{t("vehicles.pricePerKm")}</label>
                <input type="number" step="0.001" value={form.price_per_km} onChange={e => set("price_per_km", e.target.value)} className="input" />
              </div>
              <div className="space-y-1.5">
                <label className="text-xs font-semibold text-gray-600 uppercase">Min Fee</label>
                <input type="number" step="0.01" value={form.min_delivery_fee} onChange={e => set("min_delivery_fee", e.target.value)} className="input" />
              </div>
              <div className="space-y-1.5">
                <label className="text-xs font-semibold text-gray-600 uppercase">Min KM</label>
                <input type="number" step="0.1" value={form.min_distance_per_km} onChange={e => set("min_distance_per_km", e.target.value)} className="input" />
              </div>
              <div className="space-y-1.5">
                <label className="text-xs font-semibold text-gray-600 uppercase">Max KM</label>
                <input type="number" step="0.1" value={form.max_distance_per_km} onChange={e => set("max_distance_per_km", e.target.value)} className="input" />
              </div>
            </div>
          </section>

          {/* NEW: Advanced Pricing & Thresholds */}
          <section className="space-y-4 p-4 bg-gray-50 rounded-xl border border-gray-100">
            <h3 className="text-xs font-bold text-gray-500 uppercase tracking-wider">Advanced Fee Rules</h3>
            <div className="grid grid-cols-2 gap-4">
              <div className="space-y-1.5">
                <label className="flex items-center gap-1 text-xs font-semibold text-gray-600 uppercase">
                    <MapPin size={12}/> Base Threshold (km)
                </label>
                <input type="number" value={form.fee_base_distance_km} onChange={e => set("fee_base_distance_km", e.target.value)} className="input bg-white" />
              </div>
              <div className="space-y-1.5">
                <label className="flex items-center gap-1 text-xs font-semibold text-gray-600 uppercase">
                    <Percent size={12}/> Peak Ratio (%)
                </label>
                <input type="number" value={form.peak_time_fee_ratio} onChange={e => set("peak_time_fee_ratio", e.target.value)} className="input bg-white" />
              </div>
              <div className="space-y-1.5">
                <label className="flex items-center gap-1 text-xs font-semibold text-gray-600 uppercase">
                    <HardDrive size={12}/> Extra Platform/km
                </label>
                <input type="number" value={form.fee_extra_platform_per_km} onChange={e => set("fee_extra_platform_per_km", e.target.value)} className="input bg-white" />
              </div>
              <div className="space-y-1.5">
                <label className="flex items-center gap-1 text-xs font-semibold text-gray-600 uppercase">
                    <UserCheck size={12}/> Extra Courier/km
                </label>
                <input type="number" value={form.fee_extra_courier_per_km} onChange={e => set("fee_extra_courier_per_km", e.target.value)} className="input bg-white" />
              </div>
            </div>
          </section>

          <div className="space-y-1.5">
            <label className="text-xs font-semibold text-gray-600 uppercase">{t("vehicles.icon")}</label>
            <div className="flex items-center gap-4">
              {previewUrl && <img src={previewUrl} alt="preview" className="w-16 h-16 rounded-xl object-cover border border-gray-200" />}
              <button type="button" onClick={() => fileRef.current?.click()}
                className="flex items-center gap-2 px-4 py-2.5 border-2 border-dashed border-gray-300 rounded-xl text-sm text-gray-500 hover:border-indigo-400 hover:text-indigo-600 transition">
                <Upload size={16} /> {t("common.uploadPhoto")}
              </button>
              <input ref={fileRef} type="file" accept={ALLOWED_IMAGE_ACCEPT} className="hidden" onChange={e => {
                const f = e.target.files?.[0]; if (!f) return;
                if (!validateImageFile(f, e.target)) return;
                setIconFile(f); setPreviewUrl(URL.createObjectURL(f));
              }} />
            </div>
          </div>

          <div className="flex justify-end gap-3 pt-4 border-t border-gray-100">
            <button type="button" onClick={onClose} className="px-5 py-2.5 border border-gray-300 rounded-xl text-sm text-gray-700 hover:bg-gray-50">{t("common.cancel")}</button>
            <button type="submit" disabled={saveMut.isPending} className="px-6 py-2.5 bg-indigo-600 text-white rounded-xl text-sm font-medium hover:bg-indigo-700 disabled:opacity-60">
              {saveMut.isPending ? t("common.saving") : vehicle ? t("common.save") : t("common.create")}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}