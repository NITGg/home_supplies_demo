"use client";
import { useState, useRef } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import {
  fetchAds, createAd, updateAd, deleteAd,
  type Ad, type AdStatus, type AdPlacement,
} from "@/lib/ads";
import { useT } from "@/contexts/LanguageContext";
import { ALLOWED_IMAGE_ACCEPT, validateImageFile } from "@/lib/file-upload";
import {
  Megaphone, Plus, Pencil, Trash2, RefreshCw,
  X, Upload, ExternalLink,
} from "lucide-react";
import { TableToolbar } from "@/components/ui/TableToolbar";
import { TablePagination } from "@/components/ui/TablePagination";
import { DateRangeFilter } from "@/components/ui/DateRangeFilter";
import { cn } from "@/lib/utils";
import toast from "react-hot-toast";

function fmtDate(d?: string | null) {
  if (!d) return "—";
  return new Date(d).toLocaleDateString("en-GB", { day: "2-digit", month: "short", year: "numeric" });
}

const STATUS_COLORS: Record<AdStatus, string> = {
  ACTIVE:    "bg-green-100 text-green-700",
  INACTIVE:  "bg-gray-100 text-gray-500",
  SCHEDULED: "bg-blue-100 text-blue-700",
  PAUSED:    "bg-amber-100 text-amber-700",
};

// ── Page ─────────────────────────────────────────────────────────────────────
export default function AdsPage() {
  const { t } = useT();
  const qc = useQueryClient();

  const [page, setPage]           = useState(1);
  const [limit]                   = useState(12);
  const [search, setSearch]       = useState("");
  const [filterStatus, setFilter] = useState<"all" | AdStatus>("all");
  const [delConfirm, setDelConf]  = useState<number | null>(null);
  const [modalOpen, setModalOpen] = useState(false);
  const [editing, setEditing]     = useState<Ad | null>(null);

  const [createdFrom, setCreatedFrom] = useState("");
  const [createdTo,   setCreatedTo]   = useState("");
  const [updatedFrom, setUpdatedFrom] = useState("");
  const [updatedTo,   setUpdatedTo]   = useState("");

  const params: Record<string, string | number> = { page, limit };
  if (search)              params.search = search;
  if (filterStatus !== "all") params.status = filterStatus;

  const { data, isLoading, refetch, isFetching } = useQuery({
    queryKey: ["ads", params],
    queryFn: () => fetchAds(params),
  });

  const allAds     = data?.ads        ?? [];
  const ads        = allAds.filter(r => {
    if (createdFrom && r.created_at && new Date(r.created_at) < new Date(createdFrom)) return false;
    if (createdTo   && r.created_at && new Date(r.created_at) > new Date(createdTo + "T23:59:59")) return false;
    if (updatedFrom && r.updated_at && new Date(r.updated_at) < new Date(updatedFrom)) return false;
    if (updatedTo   && r.updated_at && new Date(r.updated_at) > new Date(updatedTo + "T23:59:59")) return false;
    return true;
  });
  const totalPages = data?.totalPages ?? 1;
  const total      = data?.totalCount ?? 0;
  const displayTotal = (createdFrom || createdTo || updatedFrom || updatedTo) ? ads.length : total;

  const deleteMut = useMutation({
    mutationFn: (id: number) => deleteAd(id, true),
    onSuccess: () => { toast.success(t("ads.deleted")); qc.invalidateQueries({ queryKey: ["ads"] }); setDelConf(null); },
    onError:   () => toast.error(t("ads.deleteError")),
  });

  function openCreate() { setEditing(null); setModalOpen(true); }
  function openEdit(a: Ad) { setEditing(a); setModalOpen(true); }
  function closeModal() { setModalOpen(false); setEditing(null); }

  const activeCount   = ads.filter(a => a.status === "ACTIVE").length;
  const inactiveCount = ads.filter(a => a.status === "INACTIVE").length;

  return (
    <div className="p-6 space-y-6">

      {/* ── Header ── */}
      <div className="flex items-start justify-between flex-wrap gap-3">
        <div>
          <div className="flex items-center gap-2 mb-1">
            <Megaphone size={22} className="text-indigo-600" />
            <h1 className="text-2xl font-bold text-gray-900">{t("ads.title")}</h1>
          </div>
          <p className="text-sm text-gray-500">{t("ads.subtitle")}</p>
        </div>
        <div className="flex gap-2">
          <button onClick={() => refetch()} disabled={isFetching}
            className="flex items-center gap-2 px-4 py-2 border border-gray-300 rounded-xl text-sm text-gray-600 hover:bg-gray-50 transition disabled:opacity-50">
            <RefreshCw size={15} className={isFetching ? "animate-spin" : ""} />
            {t("common.refresh")}
          </button>
          <button onClick={openCreate}
            className="flex items-center gap-2 px-4 py-2 bg-indigo-600 text-white rounded-xl text-sm hover:bg-indigo-700 transition">
            <Plus size={16} /> {t("ads.new")}
          </button>
        </div>
      </div>

      {/* ── Stats ── */}
      <div className="grid grid-cols-3 gap-4">
        <StatCard label={t("ads.total")}    value={total}        color="indigo" />
        <StatCard label={t("ads.active")}   value={activeCount}  color="green" />
        <StatCard label={t("ads.inactive")} value={inactiveCount} color="gray" />
      </div>

      {/* ── Filters ── */}
      <TableToolbar
        total={displayTotal}
        totalLabel="ad"
        search={search}
        onSearch={(v) => { setSearch(v); setPage(1); }}
        searchPlaceholder={t("ads.searchPlaceholder")}
        action={
          <button onClick={openCreate}
            className="flex items-center gap-2 px-4 py-2 bg-indigo-600 text-white rounded-xl text-sm hover:bg-indigo-700 transition">
            <Plus size={16} /> {t("ads.new")}
          </button>
        }
      >
        <select
          value={filterStatus}
          onChange={e => { setFilter(e.target.value as "all" | AdStatus); setPage(1); }}
          className="border border-gray-300 rounded-xl px-3 py-2.5 text-sm outline-none focus:ring-2 focus:ring-indigo-500">
          <option value="all">{t("ads.allStatuses")}</option>
          <option value="ACTIVE">Active</option>
          <option value="INACTIVE">Inactive</option>
          <option value="SCHEDULED">Scheduled</option>
          <option value="PAUSED">Paused</option>
        </select>
        <DateRangeFilter
          label={t("common.createdAt")}
          from={createdFrom} to={createdTo}
          onFromChange={v => { setCreatedFrom(v); setPage(1); }}
          onToChange={v => { setCreatedTo(v); setPage(1); }}
        />
        <DateRangeFilter
          label={t("common.updatedAt")}
          from={updatedFrom} to={updatedTo}
          onFromChange={v => { setUpdatedFrom(v); setPage(1); }}
          onToChange={v => { setUpdatedTo(v); setPage(1); }}
        />
      </TableToolbar>

      {/* ── Loading ── */}
      {isLoading && <div className="text-center py-20 text-gray-400">{t("common.loading")}</div>}

      {/* ── Empty ── */}
      {!isLoading && ads.length === 0 && (
        <div className="text-center py-20 border-2 border-dashed border-gray-200 rounded-2xl">
          <Megaphone size={36} className="text-gray-300 mx-auto mb-3" />
          <p className="text-gray-400">{t("ads.noResults")}</p>
        </div>
      )}

      {/* ── Grid ── */}
      {!isLoading && ads.length > 0 && (
        <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-5">
          {ads.map(ad => (
            <AdCard
              key={ad.id}
              ad={ad}
              delConfirm={delConfirm === ad.id}
              onEdit={() => openEdit(ad)}
              onDeleteClick={() => setDelConf(ad.id)}
              onDeleteConfirm={() => deleteMut.mutate(ad.id)}
              onDeleteCancel={() => setDelConf(null)}
              isDeleting={deleteMut.isPending}
              t={t}
            />
          ))}
        </div>
      )}

      {/* ── Pagination ── */}
      <TablePagination page={page} totalPages={totalPages} total={displayTotal} limit={limit} onPageChange={setPage} />

      {/* ── Modal ── */}
      {modalOpen && (
        <AdModal
          ad={editing}
          onClose={closeModal}
          onSaved={() => { closeModal(); qc.invalidateQueries({ queryKey: ["ads"] }); }}
          t={t}
        />
      )}
    </div>
  );
}

// ── AdCard ────────────────────────────────────────────────────────────────────
function AdCard({ ad, delConfirm, onEdit, onDeleteClick, onDeleteConfirm, onDeleteCancel, isDeleting, t }: {
  ad: Ad;
  delConfirm: boolean;
  onEdit: () => void;
  onDeleteClick: () => void;
  onDeleteConfirm: () => void;
  onDeleteCancel: () => void;
  isDeleting: boolean;
  t: (k: string) => string;
}) {
  return (
    <div className="bg-white border border-gray-200 rounded-2xl overflow-hidden shadow-sm hover:shadow-md transition-shadow">
      {/* Image */}
      <div className="relative h-40 bg-gray-100">
        {ad.image_url ? (
          <img src={ad.image_url} alt={ad.title ?? "Ad"} className="absolute inset-0 w-full h-full object-cover" />
        ) : (
          <div className="absolute inset-0 flex items-center justify-center">
            <Megaphone size={32} className="text-gray-300" />
          </div>
        )}
        {/* Status badge */}
        <div className="absolute top-3 left-3">
          <span className={cn("text-xs px-2.5 py-1 rounded-full font-semibold", STATUS_COLORS[ad.status])}>
            {ad.status}
          </span>
        </div>
        {/* Sort badge */}
        <div className="absolute top-3 right-3 bg-black/50 text-white text-xs px-2 py-0.5 rounded-full">
          #{ad.sort_id}
        </div>
      </div>

      {/* Body */}
      <div className="p-4 space-y-2">
        <div className="flex items-start justify-between gap-2">
          <div className="flex-1 min-w-0">
            <p className="font-semibold text-gray-900 truncate">{ad.title ?? "Untitled"}</p>
            {ad.title_ar && (
              <p className="text-xs text-gray-400 truncate" dir="rtl">{ad.title_ar}</p>
            )}
          </div>
          {ad.placement && (
            <span className="text-xs bg-slate-100 text-slate-600 px-2 py-0.5 rounded-full shrink-0">{ad.placement}</span>
          )}
        </div>

        {/* Dates */}
        <div className="flex items-center gap-3 text-xs text-gray-400">
          <span>{fmtDate(ad.start_date)}</span>
          <span>→</span>
          <span>{fmtDate(ad.end_date)}</span>
        </div>

        {/* Target URL */}
        {ad.target_url && (
          <a href={ad.target_url} target="_blank" rel="noreferrer"
            className="flex items-center gap-1 text-xs text-indigo-600 hover:underline truncate">
            <ExternalLink size={11} /> {ad.target_url}
          </a>
        )}
      </div>

      {/* Actions */}
      <div className="px-4 pb-4">
        {delConfirm ? (
          <div className="flex items-center gap-2">
            <span className="text-xs text-gray-600 flex-1">{t("ads.deleteConfirm")}</span>
            <button onClick={onDeleteConfirm} disabled={isDeleting}
              className="px-3 py-1.5 text-xs bg-red-600 text-white rounded-lg hover:bg-red-700 disabled:opacity-50">
              {t("common.yes")}
            </button>
            <button onClick={onDeleteCancel} className="px-3 py-1.5 text-xs border border-gray-300 rounded-lg hover:bg-gray-50">
              {t("common.cancel")}
            </button>
          </div>
        ) : (
          <div className="flex gap-2">
            <button onClick={onEdit}
              className="flex-1 flex items-center justify-center gap-1.5 py-2 text-xs border border-gray-300 rounded-xl text-gray-600 hover:bg-gray-50 transition">
              <Pencil size={13} /> {t("common.edit")}
            </button>
            <button onClick={onDeleteClick}
              className="flex items-center justify-center gap-1.5 px-3 py-2 text-xs border border-red-200 rounded-xl text-red-600 hover:bg-red-50 transition">
              <Trash2 size={13} />
            </button>
          </div>
        )}
      </div>
    </div>
  );
}

// ── StatCard ──────────────────────────────────────────────────────────────────
function StatCard({ label, value, color }: { label: string; value: number; color: "indigo" | "green" | "gray" }) {
  const styles: Record<string, { card: string; val: string; lbl: string }> = {
    indigo: { card: "bg-indigo-50 border-indigo-100", val: "text-indigo-700", lbl: "text-indigo-400" },
    green:  { card: "bg-green-50 border-green-100",   val: "text-green-700",  lbl: "text-green-400" },
    gray:   { card: "bg-gray-50 border-gray-200",     val: "text-gray-600",   lbl: "text-gray-400" },
  };
  const s = styles[color] ?? styles.indigo;
  return (
    <div className={cn("border rounded-2xl px-5 py-4 text-center", s.card)}>
      <p className={cn("text-3xl font-bold", s.val)}>{value}</p>
      <p className={cn("text-xs mt-1", s.lbl)}>{label}</p>
    </div>
  );
}

// ── AdModal ───────────────────────────────────────────────────────────────────
interface AdForm {
  title: string; title_ar: string;
  description: string; description_ar: string;
  status: AdStatus; placement: string; ad_type: string;
  target_url: string; sort_id: string; priority: string;
  start_date: string; end_date: string;
}

const DEFAULT_AD: AdForm = {
  title: "", title_ar: "", description: "", description_ar: "",
  status: "ACTIVE", placement: "", ad_type: "",
  target_url: "", sort_id: "0", priority: "",
  start_date: "", end_date: "",
};

function AdModal({ ad, onClose, onSaved, t }: {
  ad: Ad | null;
  onClose: () => void;
  onSaved: () => void;
  t: (k: string) => string;
}) {
  const [form, setForm] = useState<AdForm>(() => ad ? {
    title: ad.title ?? "",
    title_ar: ad.title_ar ?? "",
    description: ad.description ?? "",
    description_ar: ad.description_ar ?? "",
    status: ad.status,
    placement: ad.placement ?? "",
    ad_type: ad.ad_type ?? "",
    target_url: ad.target_url ?? "",
    sort_id: ad.sort_id?.toString() ?? "0",
    priority: ad.priority?.toString() ?? "",
    start_date: ad.start_date ? ad.start_date.slice(0, 10) : "",
    end_date: ad.end_date ? ad.end_date.slice(0, 10) : "",
  } : DEFAULT_AD);

  const [imageFile, setImageFile] = useState<File | null>(null);
  const [previewUrl, setPreviewUrl] = useState<string | null>(ad?.image_url ?? null);
  const fileRef = useRef<HTMLInputElement>(null);

  const set = (k: keyof AdForm, v: string) => setForm(prev => ({ ...prev, [k]: v }));

  const saveMut = useMutation({
    mutationFn: (fd: FormData) => ad ? updateAd(ad.id, fd) : createAd(fd),
    onSuccess: () => {
      toast.success(ad ? t("adForm.updated") : t("adForm.created"));
      onSaved();
    },
    onError: () => toast.error("Save failed"),
  });

  function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    const fd = new FormData();
    Object.entries(form).forEach(([k, v]) => {
      if (v !== "" && v !== null) fd.append(k, String(v));
    });
    if (imageFile) fd.append("image_url", imageFile);
    saveMut.mutate(fd);
  }

  function handleImage(e: React.ChangeEvent<HTMLInputElement>) {
    const f = e.target.files?.[0];
    if (!f) return;
    if (!validateImageFile(f, e.target)) return;
    setImageFile(f);
    setPreviewUrl(URL.createObjectURL(f));
  }

  const PLACEMENTS: AdPlacement[] = ["HOME", "CATEGORY", "PRODUCT", "CHECKOUT", "SPLASH"];
  const STATUSES: AdStatus[] = ["ACTIVE", "INACTIVE", "SCHEDULED", "PAUSED"];

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4">
      <div className="bg-white rounded-2xl shadow-2xl w-full max-w-2xl max-h-[90vh] overflow-y-auto">
        {/* Header */}
        <div className="flex items-center justify-between px-6 py-5 border-b border-gray-100">
          <h2 className="text-lg font-bold text-gray-900">{ad ? t("common.edit") : t("ads.new")}</h2>
          <button onClick={onClose} className="p-2 rounded-xl hover:bg-gray-100 text-gray-400 hover:text-gray-700 transition">
            <X size={18} />
          </button>
        </div>

        <form onSubmit={handleSubmit} className="px-6 py-5 space-y-5">
          {/* Image upload */}
          <Field label={t("adForm.image")}>
            <div className="flex items-center gap-4">
              {previewUrl && (
                <div className="relative w-28 h-16 rounded-xl overflow-hidden border border-gray-200">
                  <img src={previewUrl} alt="preview" className="absolute inset-0 w-full h-full object-cover" />
                </div>
              )}
              <button type="button" onClick={() => fileRef.current?.click()}
                className="flex items-center gap-2 px-4 py-2.5 border-2 border-dashed border-gray-300 rounded-xl text-sm text-gray-500 hover:border-indigo-400 hover:text-indigo-600 transition">
                <Upload size={16} /> {t("common.uploadPhoto")}
              </button>
              <input ref={fileRef} type="file" accept={ALLOWED_IMAGE_ACCEPT} className="hidden" onChange={handleImage} />
            </div>
          </Field>

          {/* Titles */}
          <div className="grid grid-cols-2 gap-4">
            <Field label={t("adForm.titleEn")}>
              <input value={form.title} onChange={e => set("title", e.target.value)} className="input" placeholder="Summer Banner" />
            </Field>
            <Field label={t("adForm.titleAr")}>
              <input value={form.title_ar} onChange={e => set("title_ar", e.target.value)} dir="rtl" className="input" placeholder="بانر الصيف" />
            </Field>
          </div>

          {/* Descriptions */}
          <div className="grid grid-cols-2 gap-4">
            <Field label={t("adForm.descEn")}>
              <textarea value={form.description} onChange={e => set("description", e.target.value)} rows={2} className="input resize-none" />
            </Field>
            <Field label={t("adForm.descAr")}>
              <textarea value={form.description_ar} onChange={e => set("description_ar", e.target.value)} rows={2} dir="rtl" className="input resize-none text-right" />
            </Field>
          </div>

          {/* Status + Placement + Type */}
          <div className="grid grid-cols-3 gap-4">
            <Field label={t("adForm.status")}>
              <select value={form.status} onChange={e => set("status", e.target.value as AdStatus)} className="input">
                {STATUSES.map(s => <option key={s} value={s}>{s}</option>)}
              </select>
            </Field>
            <Field label={t("adForm.placement")}>
              <select value={form.placement} onChange={e => set("placement", e.target.value)} className="input">
                <option value="">— None —</option>
                {PLACEMENTS.map(p => <option key={p} value={p}>{p}</option>)}
              </select>
            </Field>
            <Field label={t("adForm.adType")}>
              <input value={form.ad_type} onChange={e => set("ad_type", e.target.value)} className="input" placeholder="BANNER" />
            </Field>
          </div>

          {/* Target URL */}
          <Field label={t("adForm.targetUrl")}>
            <input value={form.target_url} onChange={e => set("target_url", e.target.value)} className="input" placeholder="https://…" />
          </Field>

          {/* Dates */}
          <div className="grid grid-cols-2 gap-4">
            <Field label={t("adForm.startDate")}>
              <input type="date" value={form.start_date} onChange={e => set("start_date", e.target.value)} className="input" />
            </Field>
            <Field label={t("adForm.endDate")}>
              <input type="date" value={form.end_date} onChange={e => set("end_date", e.target.value)} className="input" />
            </Field>
          </div>

          {/* Sort + Priority */}
          <div className="grid grid-cols-2 gap-4">
            <Field label={t("adForm.sortId")}>
              <input type="number" min="0" value={form.sort_id} onChange={e => set("sort_id", e.target.value)} className="input" />
            </Field>
            <Field label={t("adForm.priority")}>
              <input type="number" min="0" value={form.priority} onChange={e => set("priority", e.target.value)} className="input" placeholder="—" />
            </Field>
          </div>

          {/* Footer */}
          <div className="flex justify-end gap-3 pt-2 border-t border-gray-100">
            <button type="button" onClick={onClose}
              className="px-5 py-2.5 border border-gray-300 rounded-xl text-sm text-gray-700 hover:bg-gray-50 transition">
              {t("common.cancel")}
            </button>
            <button type="submit" disabled={saveMut.isPending}
              className="px-6 py-2.5 bg-indigo-600 text-white rounded-xl text-sm font-medium hover:bg-indigo-700 disabled:opacity-60 transition">
              {saveMut.isPending ? t("common.saving") : ad ? t("common.save") : t("common.create")}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}

function Field({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div className="space-y-1.5">
      <label className="text-xs font-semibold text-gray-600 uppercase tracking-wide">{label}</label>
      {children}
    </div>
  );
}
