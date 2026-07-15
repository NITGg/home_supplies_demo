"use client";
import { useState, useRef } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { fetchBadges, createBadge, updateBadge, deleteBadge, type Badge } from "@/lib/badges";
import { fetchRoles, type Role } from "@/lib/users";
import { useT } from "@/contexts/LanguageContext";
import { Award, Plus, Pencil, Trash2, RefreshCw, X, Upload } from "lucide-react";
import toast from "react-hot-toast";
import { ALLOWED_IMAGE_ACCEPT, validateImageFile } from "@/lib/file-upload";
import { DataTable, type Column } from "@/components/ui/DataTable";
import { TableToolbar } from "@/components/ui/TableToolbar";
import { TablePagination } from "@/components/ui/TablePagination";
import { DateRangeFilter } from "@/components/ui/DateRangeFilter";
import { ColumnToggle, type ColumnOption } from "@/components/ui/ColumnToggle";
import { useColumnVisibility } from "@/hooks/useColumnVisibility";

const ALL_COLUMN_KEYS = ["image", "name", "name_ar", "role_id", "min_count", "max_count", "created_at", "updated_at", "actions"] as const;

export default function BadgesPage() {
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
  const [editing, setEditing] = useState<Badge | null>(null);

  const { visible, setVisible } = useColumnVisibility("cols:badges", [...ALL_COLUMN_KEYS]);

  const { data: roles = [] } = useQuery({
    queryKey: ["roles"],
    queryFn: fetchRoles,
  });
  const roleLabels = Object.fromEntries(roles.map(r => [r.id, r.name]));

  const params: Record<string, string | number> = { page, limit: 20 };
  if (search) params.keyword = search;

  const { data, isLoading, refetch, isFetching } = useQuery({
    queryKey: ["badges", params],
    queryFn: () => fetchBadges(params),
  });

  const allBadges = data?.badges ?? [];
  const badges = allBadges.filter(b => {
    if (createdFrom && new Date(b.created_at) < new Date(createdFrom)) return false;
    if (createdTo   && new Date(b.created_at) > new Date(createdTo + "T23:59:59")) return false;
    if (updatedFrom && new Date(b.updated_at) < new Date(updatedFrom)) return false;
    if (updatedTo   && new Date(b.updated_at) > new Date(updatedTo + "T23:59:59")) return false;
    return true;
  });

  const total = data?.totalBadges ?? 0;
  const totalPages = data?.totalPages ?? 1;
  const displayTotal = (createdFrom || createdTo || updatedFrom || updatedTo) ? badges.length : total;

  const deleteMut = useMutation({
    mutationFn: (id: number) => deleteBadge(id),
    onSuccess: () => { toast.success(t("badges.deleted")); qc.invalidateQueries({ queryKey: ["badges"] }); setDelConfirm(null); },
    onError: () => toast.error(t("badges.deleteError")),
  });

  const allColumns: Column<Badge>[] = [
    {
      key: "image",
      label: t("badges.image"),
      render: b => b.image
        ? <img src={b.image} alt={b.name} className="w-10 h-10 rounded-lg object-cover" />
        : <div className="w-10 h-10 rounded-lg bg-gray-100 flex items-center justify-center"><Award size={18} className="text-gray-400" /></div>,
    },
    {
      key: "name",
      label: t("badges.nameEn"),
      sortable: true,
      getValue: b => b.name,
      render: b => <span className="font-medium text-gray-900">{b.name}</span>,
    },
    {
      key: "name_ar",
      label: t("badges.nameAr"),
      render: b => <span className="text-gray-700" dir="rtl">{b.name_ar}</span>,
    },
    {
      key: "role_id",
      label: t("badges.roleId"),
      sortable: true,
      getValue: b => b.role_id,
      render: b => (
        <span className="text-xs px-2.5 py-1 rounded-full bg-indigo-100 text-indigo-700 font-medium">
          {roleLabels[b.role_id] ?? `Role ${b.role_id}`}
        </span>
      ),
    },
    {
      key: "min_count",
      label: t("badges.minCount"),
      sortable: true,
      getValue: b => b.min_count ?? 0,
      render: b => <span className="text-gray-600">{b.min_count ?? "—"}</span>,
    },
    {
      key: "max_count",
      label: t("badges.maxCount"),
      sortable: true,
      getValue: b => b.max_count ?? 0,
      render: b => <span className="text-gray-600">{b.max_count ?? "—"}</span>,
    },
    {
      key: "created_at",
      label: t("common.createdAt"),
      sortable: true,
      getValue: b => new Date(b.created_at),
      render: b => (
        <span className="text-xs text-gray-500">
          {new Date(b.created_at).toLocaleDateString(undefined, { year: "numeric", month: "short", day: "numeric" })}
        </span>
      ),
    },
    {
      key: "updated_at",
      label: t("common.updatedAt"),
      sortable: true,
      getValue: b => new Date(b.updated_at),
      render: b => (
        <span className="text-xs text-gray-500">
          {new Date(b.updated_at).toLocaleDateString(undefined, { year: "numeric", month: "short", day: "numeric" })}
        </span>
      ),
    },
    {
      key: "actions",
      label: t("common.actions"),
      align: "right",
      render: b => (
        <div className="flex items-center justify-end gap-2">
          {delConfirm === b.id ? (
            <>
              <span className="text-xs text-gray-600">Delete?</span>
              <button onClick={() => deleteMut.mutate(b.id)} disabled={deleteMut.isPending} className="px-3 py-1.5 text-xs bg-red-600 text-white rounded-lg disabled:opacity-50">{t("common.yes")}</button>
              <button onClick={() => setDelConfirm(null)} className="px-3 py-1.5 text-xs border border-gray-300 rounded-lg">{t("common.cancel")}</button>
            </>
          ) : (
            <>
              <button onClick={() => { setEditing(b); setModalOpen(true); }} className="p-2 rounded-lg text-gray-400 hover:text-indigo-600 hover:bg-indigo-50"><Pencil size={15} /></button>
              <button onClick={() => setDelConfirm(b.id)} className="p-2 rounded-lg text-gray-400 hover:text-red-600 hover:bg-red-50"><Trash2 size={15} /></button>
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
            <Award size={22} className="text-indigo-600" />
            <h1 className="text-2xl font-bold text-gray-900">{t("badges.title")}</h1>
          </div>
          <p className="text-sm text-gray-500">{t("badges.subtitle")}</p>
        </div>
        <button onClick={() => refetch()} disabled={isFetching} className="flex items-center gap-2 px-4 py-2 border border-gray-300 rounded-xl text-sm text-gray-600 hover:bg-gray-50 disabled:opacity-50">
          <RefreshCw size={15} className={isFetching ? "animate-spin" : ""} /> {t("common.refresh")}
        </button>
      </div>

      <div className="bg-indigo-50 border border-indigo-100 rounded-2xl px-5 py-4 text-center w-40">
        <p className="text-3xl font-bold text-indigo-700">{total}</p>
        <p className="text-xs text-indigo-400 mt-1">{t("badges.total")}</p>
      </div>

      <TableToolbar
        total={displayTotal}
        totalLabel="badge"
        search={search}
        onSearch={v => { setSearch(v); setPage(1); }}
        searchPlaceholder={t("badges.searchPlaceholder")}
        action={
          <div className="flex items-center gap-2">
            <ColumnToggle columns={columnOptions} visible={visible} onChange={setVisible} />
            <button onClick={() => { setEditing(null); setModalOpen(true); }} className="flex items-center gap-2 px-4 py-2 bg-indigo-600 text-white rounded-xl text-sm hover:bg-indigo-700">
              <Plus size={16} /> {t("badges.new")}
            </button>
          </div>
        }
      >
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

      <DataTable
        columns={columns}
        rows={badges}
        keyExtractor={b => b.id}
        isLoading={isLoading}
        emptyText={t("badges.noResults")}
        emptyIcon={<Award size={36} className="text-gray-300" />}
      />

      <TablePagination
        page={page}
        totalPages={totalPages}
        total={displayTotal}
        limit={20}
        onPageChange={setPage}
      />

      {modalOpen && (
        <BadgeModal badge={editing} onClose={() => { setModalOpen(false); setEditing(null); }}
          onSaved={() => { setModalOpen(false); setEditing(null); qc.invalidateQueries({ queryKey: ["badges"] }); }} t={t} />
      )}
    </div>
  );
}

function BadgeModal({ badge, onClose, onSaved, t }: { badge: Badge | null; onClose: () => void; onSaved: () => void; t: (k: string) => string }) {
  const [form, setForm] = useState({
    name: badge?.name ?? "",
    name_ar: badge?.name_ar ?? "",
    description: badge?.description ?? "",
    description_ar: badge?.description_ar ?? "",
    role_id: badge?.role_id ?? 1,
    min_count: badge?.min_count?.toString() ?? "0",
    max_count: badge?.max_count?.toString() ?? "0",
    ratio: badge?.ratio?.toString() ?? "0",
  });
  const [imgFile, setImgFile] = useState<File | null>(null);
  const [previewUrl, setPreviewUrl] = useState<string | null>(badge?.image ?? null);
  const fileRef = useRef<HTMLInputElement>(null);

  const { data: roles = [] } = useQuery({
    queryKey: ["roles"],
    queryFn: fetchRoles,
  });

  const saveMut = useMutation({
    mutationFn: () => {
      const fd = new FormData();
      Object.entries(form).forEach(([k, v]) => fd.append(k, String(v)));
      if (imgFile) fd.append("image", imgFile);
      return badge ? updateBadge(badge.id, fd) : createBadge(fd);
    },
    onSuccess: () => { toast.success(badge ? t("badges.updated") : t("badges.created")); onSaved(); },
    onError: () => toast.error("Save failed"),
  });

  const set = (k: keyof typeof form, v: string | number) => setForm(p => ({ ...p, [k]: v }));

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4">
      <div className="bg-white rounded-2xl shadow-2xl w-full max-w-lg max-h-[90vh] overflow-y-auto">
        <div className="flex items-center justify-between px-6 py-5 border-b border-gray-100">
          <h2 className="text-lg font-bold text-gray-900">{badge ? t("common.edit") : t("badges.new")}</h2>
          <button onClick={onClose} className="p-2 rounded-xl hover:bg-gray-100 text-gray-400"><X size={18} /></button>
        </div>
        <form onSubmit={e => { e.preventDefault(); saveMut.mutate(); }} className="px-6 py-5 space-y-4">
          <div className="space-y-1.5">
            <label className="text-xs font-semibold text-gray-600 uppercase">{t("badges.roleId")}</label>
            <select value={form.role_id} onChange={e => set("role_id", Number(e.target.value))} className="input">
              {roles.map((r: Role) => (
                <option key={r.id} value={r.id}>{r.name}</option>
              ))}
            </select>
          </div>
          <div className="grid grid-cols-2 gap-4">
            <div className="space-y-1.5">
              <label className="text-xs font-semibold text-gray-600 uppercase">{t("badges.nameEn")}</label>
              <input required value={form.name} onChange={e => set("name", e.target.value)} className="input" />
            </div>
            <div className="space-y-1.5">
              <label className="text-xs font-semibold text-gray-600 uppercase">{t("badges.nameAr")}</label>
              <input required value={form.name_ar} onChange={e => set("name_ar", e.target.value)} dir="rtl" className="input text-right" />
            </div>
          </div>
          <div className="grid grid-cols-2 gap-4">
            <div className="space-y-1.5">
              <label className="text-xs font-semibold text-gray-600 uppercase">{t("badges.descEn")}</label>
              <textarea value={form.description} onChange={e => set("description", e.target.value)} rows={2}
                className="w-full border border-gray-300 rounded-xl px-3 py-2 text-sm focus:ring-2 focus:ring-indigo-500 outline-none resize-none" />
            </div>
            <div className="space-y-1.5">
              <label className="text-xs font-semibold text-gray-600 uppercase">{t("badges.descAr")}</label>
              <textarea value={form.description_ar} onChange={e => set("description_ar", e.target.value)} rows={2} dir="rtl"
                className="w-full border border-gray-300 rounded-xl px-3 py-2 text-sm focus:ring-2 focus:ring-indigo-500 outline-none resize-none text-right" />
            </div>
          </div>
          <div className="grid grid-cols-3 gap-4">
            <div className="space-y-1.5">
              <label className="text-xs font-semibold text-gray-600 uppercase">{t("badges.minCount")}</label>
              <input type="number" min="0" value={form.min_count} onChange={e => set("min_count", e.target.value)} className="input" />
            </div>
            <div className="space-y-1.5">
              <label className="text-xs font-semibold text-gray-600 uppercase">{t("badges.maxCount")}</label>
              <input type="number" min="0" value={form.max_count} onChange={e => set("max_count", e.target.value)} className="input" />
            </div>
            <div className="space-y-1.5">
              <label className="text-xs font-semibold text-gray-600 uppercase">{t("badges.ratio")}</label>
              <input type="number" step="0.01" value={form.ratio} onChange={e => set("ratio", e.target.value)} className="input" />
            </div>
          </div>
          <div className="space-y-1.5">
            <label className="text-xs font-semibold text-gray-600 uppercase">{t("badges.image")}</label>
            <div className="flex items-center gap-4">
              {previewUrl && <img src={previewUrl} alt="preview" className="w-16 h-16 rounded-xl object-cover border border-gray-200" />}
              <button type="button" onClick={() => fileRef.current?.click()}
                className="flex items-center gap-2 px-4 py-2.5 border-2 border-dashed border-gray-300 rounded-xl text-sm text-gray-500 hover:border-indigo-400 hover:text-indigo-600 transition">
                <Upload size={16} /> {t("common.uploadPhoto")}
              </button>
              <input ref={fileRef} type="file" accept={ALLOWED_IMAGE_ACCEPT} className="hidden" onChange={e => {
                const f = e.target.files?.[0]; if (!f) return;
                if (!validateImageFile(f, e.target)) return;
                setImgFile(f); setPreviewUrl(URL.createObjectURL(f));
              }} />
            </div>
          </div>
          <div className="flex justify-end gap-3 pt-2 border-t border-gray-100">
            <button type="button" onClick={onClose} className="px-5 py-2.5 border border-gray-300 rounded-xl text-sm text-gray-700 hover:bg-gray-50">{t("common.cancel")}</button>
            <button type="submit" disabled={saveMut.isPending} className="px-6 py-2.5 bg-indigo-600 text-white rounded-xl text-sm font-medium hover:bg-indigo-700 disabled:opacity-60">
              {saveMut.isPending ? t("common.saving") : badge ? t("common.save") : t("common.create")}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
