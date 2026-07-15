"use client";
import { useState, useRef } from "react";
import { useRouter } from "next/navigation";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { onBoardingService } from "@/services/onBoardingService";
import type { OnBoardingItem, OnBoardingTargetUser, OnBoardingFilter } from "@/types/onBoarding";
import { useT } from "@/contexts/LanguageContext";
import { Smartphone, Plus, Pencil, Trash2, RefreshCw, X, Upload } from "lucide-react";
import toast from "react-hot-toast";
import { ALLOWED_IMAGE_ACCEPT, validateImageFile } from "@/lib/file-upload";
import { DataTable, type Column } from "@/components/ui/DataTable";
import { TableToolbar } from "@/components/ui/TableToolbar";
import { TablePagination } from "@/components/ui/TablePagination";
import { DateRangeFilter } from "@/components/ui/DateRangeFilter";
import { ColumnToggle, type ColumnOption } from "@/components/ui/ColumnToggle";
import { useColumnVisibility } from "@/hooks/useColumnVisibility";

const ALL_COLUMN_KEYS = ["image", "title", "title_ar", "target_user", "sort_id", "created_at", "updated_at", "actions"] as const;

export default function OnboardingPage() {
  const { t } = useT();
  const router = useRouter();
  const qc = useQueryClient();
  const [page, setPage] = useState(1);
  const [search, setSearch] = useState("");
  const [filterTarget, setFilterTarget] = useState<"all" | OnBoardingTargetUser>("all");
  const [createdFrom, setCreatedFrom] = useState("");
  const [createdTo, setCreatedTo] = useState("");
  const [updatedFrom, setUpdatedFrom] = useState("");
  const [updatedTo, setUpdatedTo] = useState("");
  const [delConfirm, setDelConfirm] = useState<number | null>(null);
  const [modalOpen, setModalOpen] = useState(false);
  const [editing, setEditing] = useState<OnBoardingItem | null>(null);

  const { visible, setVisible } = useColumnVisibility("cols:onboarding", [...ALL_COLUMN_KEYS]);

  const filters: Partial<OnBoardingFilter> = {};
  if (search) {
    filters.title = search;
  }
  if (filterTarget !== "all") filters.target_user = filterTarget as OnBoardingTargetUser;

  const { data, isLoading, refetch, isFetching } = useQuery({
    queryKey: ["onboarding", page, 20, filters],
    queryFn: () => onBoardingService.fetchOnBoardingItems(page, 20, "id", filters),
  });

  const allItems = data?.items ?? [];
  const items = allItems.filter(item => {
    if (createdFrom && new Date(item.created_at) < new Date(createdFrom)) return false;
    if (createdTo   && new Date(item.created_at) > new Date(createdTo + "T23:59:59")) return false;
    if (updatedFrom && new Date(item.updated_at) < new Date(updatedFrom)) return false;
    if (updatedTo   && new Date(item.updated_at) > new Date(updatedTo + "T23:59:59")) return false;
    return true;
  });

  const total = data?.totalItems ?? 0;
  const totalPages = data?.totalPages ?? 1;
  const displayTotal = (createdFrom || createdTo || updatedFrom || updatedTo) ? items.length : total;

  const deleteMut = useMutation({
    mutationFn: (id: number) => onBoardingService.deleteOnBoardingItem(id),
    onSuccess: () => { toast.success(t("onboarding.deleted")); qc.invalidateQueries({ queryKey: ["onboarding"] }); setDelConfirm(null); },
    onError: () => toast.error(t("onboarding.deleteError")),
  });

  const allColumns: Column<OnBoardingItem>[] = [
    {
      key: "image",
      label: "Image",
      render: item => item.image_url
        ? <img src={item.image_url} alt={item.title} className="w-14 h-14 rounded-lg object-cover" />
        : <div className="w-14 h-14 rounded-lg bg-gray-100 flex items-center justify-center"><Smartphone size={18} className="text-gray-400" /></div>,
    },
    {
      key: "title",
      label: t("onboarding.titleEn"),
      sortable: true,
      getValue: item => item.title,
      render: item => <span className="font-medium text-gray-900">{item.title}</span>,
    },
    {
      key: "title_ar",
      label: t("onboarding.titleAr"),
      sortable: true,
      getValue: item => item.title_ar ?? "",
      render: item => <span className="text-gray-700" dir="rtl">{item.title_ar ?? "—"}</span>,
    },
    {
      key: "target_user",
      label: t("onboarding.targetUser"),
      sortable: true,
      getValue: item => item.target_user ?? "ALL",
      render: item => (
        <span className="text-xs px-2.5 py-1 rounded-full bg-indigo-100 text-indigo-700 font-medium">{item.target_user ?? "ALL"}</span>
      ),
    },
    {
      key: "sort_id",
      label: t("common.sort"),
      sortable: true,
      getValue: item => item.sort_id ?? 0,
      render: item => <span className="text-gray-600">{item.sort_id ?? "—"}</span>,
    },
    {
      key: "created_at",
      label: t("common.createdAt"),
      sortable: true,
      getValue: item => new Date(item.created_at),
      render: item => (
        <span className="text-xs text-gray-500">
          {new Date(item.created_at).toLocaleDateString(undefined, { year: "numeric", month: "short", day: "numeric" })}
        </span>
      ),
    },
    {
      key: "updated_at",
      label: t("common.updatedAt"),
      sortable: true,
      getValue: item => new Date(item.updated_at),
      render: item => (
        <span className="text-xs text-gray-500">
          {new Date(item.updated_at).toLocaleDateString(undefined, { year: "numeric", month: "short", day: "numeric" })}
        </span>
      ),
    },
    {
      key: "actions",
      label: t("common.actions"),
      align: "right",
      render: item => (
        <div className="flex items-center justify-end gap-2">
          {delConfirm === item.id ? (
            <>
              <span className="text-xs text-gray-600">Delete?</span>
              <button onClick={() => deleteMut.mutate(item.id)} disabled={deleteMut.isPending} className="px-3 py-1.5 text-xs bg-red-600 text-white rounded-lg disabled:opacity-50">{t("common.yes")}</button>
              <button onClick={() => setDelConfirm(null)} className="px-3 py-1.5 text-xs border border-gray-300 rounded-lg">{t("common.cancel")}</button>
            </>
          ) : (
            <>
              <button onClick={() => { setEditing(item); setModalOpen(true); }} className="p-2 rounded-lg text-gray-400 hover:text-indigo-600 hover:bg-indigo-50"><Pencil size={15} /></button>
              <button onClick={() => setDelConfirm(item.id)} className="p-2 rounded-lg text-gray-400 hover:text-red-600 hover:bg-red-50"><Trash2 size={15} /></button>
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
            <Smartphone size={22} className="text-indigo-600" />
            <h1 className="text-2xl font-bold text-gray-900">{t("onboarding.title")}</h1>
          </div>
          <p className="text-sm text-gray-500">{t("onboarding.subtitle")}</p>
        </div>
        <button onClick={() => refetch()} disabled={isFetching} className="flex items-center gap-2 px-4 py-2 border border-gray-300 rounded-xl text-sm text-gray-600 hover:bg-gray-50 disabled:opacity-50">
          <RefreshCw size={15} className={isFetching ? "animate-spin" : ""} /> {t("common.refresh")}
        </button>
      </div>

      <TableToolbar
        total={displayTotal}
        totalLabel={t("onboarding.total")}
        search={search}
        onSearch={v => { setSearch(v); setPage(1); }}
        searchPlaceholder={t("onboarding.searchPlaceholder")}
        action={
          <div className="flex items-center gap-2">
            <ColumnToggle columns={columnOptions} visible={visible} onChange={setVisible} />
            <button onClick={() => { setEditing(null); setModalOpen(true); }} className="flex items-center gap-2 px-4 py-2 bg-indigo-600 text-white rounded-xl text-sm hover:bg-indigo-700">
              <Plus size={16} /> {t("onboarding.new")}
            </button>
          </div>
        }
      >
        <select value={filterTarget} onChange={e => { setFilterTarget(e.target.value as typeof filterTarget); setPage(1); }} className="input w-auto">
          <option value="all">{t("common.all")}</option>
          <option value="CUSTOMER">Customer</option>
          <option value="COURIER">Courier</option>
          <option value="ALL">All Users</option>
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

      <DataTable
        columns={columns}
        rows={items}
        keyExtractor={item => item.id}
        isLoading={isLoading}
        emptyText={t("onboarding.noResults")}
        emptyIcon={<Smartphone size={36} className="text-gray-300" />}
        onRowClick={(row) => router.push(`/onboarding/${row.id}`)}
      />

      <TablePagination page={page} totalPages={totalPages} total={displayTotal} limit={20} onPageChange={setPage} />

      {modalOpen && (
        <OnboardingModal item={editing} onClose={() => { setModalOpen(false); setEditing(null); }}
          onSaved={() => { setModalOpen(false); setEditing(null); qc.invalidateQueries({ queryKey: ["onboarding"] }); }} t={t} />
      )}
    </div>
  );
}

function OnboardingModal({ item, onClose, onSaved, t }: { item: OnBoardingItem | null; onClose: () => void; onSaved: () => void; t: (k: string) => string }) {
  const [form, setForm] = useState({
    title: item?.title ?? "",
    title_ar: item?.title_ar ?? "",
    subtitle: item?.subtitle ?? "",
    subtitle_ar: item?.subtitle_ar ?? "",
    content: item?.content ?? "",
    content_ar: item?.content_ar ?? "",
    target_user: item?.target_user ?? "ALL" as OnBoardingTargetUser,
    sort_id: item?.sort_id?.toString() ?? "",
  });
  const [imgFile, setImgFile] = useState<File | null>(null);
  const [previewUrl, setPreviewUrl] = useState<string | null>(item?.image_url ?? null);
  const fileRef = useRef<HTMLInputElement>(null);

  const saveMut = useMutation({
    mutationFn: () => {
      const payload: any = {
        title: form.title,
        title_ar: form.title_ar,
        subtitle: form.subtitle,
        subtitle_ar: form.subtitle_ar,
        content: form.content,
        content_ar: form.content_ar,
        target_user: form.target_user,
        sort_id: Number(form.sort_id) || 0,
        image: imgFile || null,
      };
      return item 
        ? onBoardingService.updateOnBoardingItem(item.id, payload) 
        : onBoardingService.createOnBoardingItem(payload);
    },
    onSuccess: () => { toast.success(item ? t("onboarding.updated") : t("onboarding.created")); onSaved(); },
    onError: () => toast.error("Save failed"),
  });

  const set = (k: keyof typeof form, v: string) => setForm(p => ({ ...p, [k]: v }));

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4">
      <div className="bg-white rounded-2xl shadow-2xl w-full max-w-2xl max-h-[90vh] overflow-y-auto">
        <div className="flex items-center justify-between px-6 py-5 border-b border-gray-100">
          <h2 className="text-lg font-bold text-gray-900">{item ? t("common.edit") : t("onboarding.new")}</h2>
          <button onClick={onClose} className="p-2 rounded-xl hover:bg-gray-100 text-gray-400"><X size={18} /></button>
        </div>
        <form onSubmit={e => { e.preventDefault(); saveMut.mutate(); }} className="px-6 py-5 space-y-4">
          <div className="grid grid-cols-2 gap-4">
            <div className="space-y-1.5">
              <label className="text-xs font-semibold text-gray-600 uppercase">{t("onboarding.targetUser")}</label>
              <select value={form.target_user} onChange={e => set("target_user", e.target.value)} className="input">
                <option value="ALL">All Users</option>
                <option value="CUSTOMER">Customer</option>
                <option value="COURIER">Courier</option>
              </select>
            </div>
            <div className="space-y-1.5">
              <label className="text-xs font-semibold text-gray-600 uppercase">{t("onboarding.sortId")}</label>
              <input type="number" min="0" value={form.sort_id} onChange={e => set("sort_id", e.target.value)} className="input" />
            </div>
          </div>
          <div className="grid grid-cols-2 gap-4">
            <div className="space-y-1.5">
              <label className="text-xs font-semibold text-gray-600 uppercase">{t("onboarding.titleEn")}</label>
              <input required value={form.title} onChange={e => set("title", e.target.value)} className="input" />
            </div>
            <div className="space-y-1.5">
              <label className="text-xs font-semibold text-gray-600 uppercase">{t("onboarding.titleAr")}</label>
              <input value={form.title_ar} onChange={e => set("title_ar", e.target.value)} dir="rtl" className="input text-right" />
            </div>
          </div>
          <div className="grid grid-cols-2 gap-4">
            <div className="space-y-1.5">
              <label className="text-xs font-semibold text-gray-600 uppercase">{t("onboarding.subtitleEn")}</label>
              <input value={form.subtitle} onChange={e => set("subtitle", e.target.value)} className="input" />
            </div>
            <div className="space-y-1.5">
              <label className="text-xs font-semibold text-gray-600 uppercase">{t("onboarding.subtitleAr")}</label>
              <input value={form.subtitle_ar} onChange={e => set("subtitle_ar", e.target.value)} dir="rtl" className="input text-right" />
            </div>
          </div>
          <div className="grid grid-cols-2 gap-4">
            <div className="space-y-1.5">
              <label className="text-xs font-semibold text-gray-600 uppercase">{t("onboarding.contentEn")}</label>
              <textarea value={form.content} onChange={e => set("content", e.target.value)} rows={3}
                className="w-full border border-gray-300 rounded-xl px-3 py-2 text-sm focus:ring-2 focus:ring-indigo-500 outline-none resize-none" />
            </div>
            <div className="space-y-1.5">
              <label className="text-xs font-semibold text-gray-600 uppercase">{t("onboarding.contentAr")}</label>
              <textarea value={form.content_ar} onChange={e => set("content_ar", e.target.value)} rows={3} dir="rtl"
                className="w-full border border-gray-300 rounded-xl px-3 py-2 text-sm focus:ring-2 focus:ring-indigo-500 outline-none resize-none text-right" />
            </div>
          </div>
          <div className="space-y-1.5">
            <label className="text-xs font-semibold text-gray-600 uppercase">{t("onboarding.image")}</label>
            <div className="flex items-center gap-4">
              {previewUrl && <img src={previewUrl} alt="preview" className="w-20 h-20 rounded-xl object-cover border border-gray-200" />}
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
              {saveMut.isPending ? t("common.saving") : item ? t("common.save") : t("common.create")}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
