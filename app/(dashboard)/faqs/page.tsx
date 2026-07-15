"use client";
import { useState } from "react";
import { useRouter } from "next/navigation";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { faqService } from "@/services/faqService";
import type { FaqItem, FaqTargetUser, FaqLanguage, FaqFilter } from "@/types/faq";
import { useT } from "@/contexts/LanguageContext";
import { HelpCircle, Plus, Pencil, Trash2, RefreshCw, X, CheckCircle, XCircle } from "lucide-react";
import { DataTable, type Column } from "@/components/ui/DataTable";
import { TableToolbar } from "@/components/ui/TableToolbar";
import { TablePagination } from "@/components/ui/TablePagination";
import { DateRangeFilter } from "@/components/ui/DateRangeFilter";
import { ColumnToggle, type ColumnOption } from "@/components/ui/ColumnToggle";
import { useColumnVisibility } from "@/hooks/useColumnVisibility";
import toast from "react-hot-toast";

const ALL_COLUMN_KEYS = ["id", "question", "target_user", "language", "sort_id", "is_active", "created_at", "updated_at", "actions"] as const;

export default function FaqsPage() {
  const { t } = useT();
  const router = useRouter();
  const qc = useQueryClient();
  const [page, setPage] = useState(1);
  const [search, setSearch] = useState("");
  const [filterTarget, setFilterTarget] = useState<"all" | FaqTargetUser>("all");
  const [filterStatus, setFilterStatus] = useState<"all" | "active" | "inactive">("all");
  const [createdFrom, setCreatedFrom] = useState("");
  const [createdTo, setCreatedTo] = useState("");
  const [updatedFrom, setUpdatedFrom] = useState("");
  const [updatedTo, setUpdatedTo] = useState("");
  const [delConfirm, setDelConfirm] = useState<number | null>(null);
  const [modalOpen, setModalOpen] = useState(false);
  const [editing, setEditing] = useState<FaqItem | null>(null);

  const { visible, setVisible } = useColumnVisibility("cols:faqs", [...ALL_COLUMN_KEYS]);

  const filters: Partial<FaqFilter> = {};
  if (search) filters.question = search;
  if (filterTarget !== "all") filters.target_user = filterTarget as FaqTargetUser;
  if (filterStatus === "active") filters.is_active = "true";
  if (filterStatus === "inactive") filters.is_active = "false";
  if (createdFrom) filters.created_from = createdFrom;
  if (createdTo) filters.created_to = createdTo;
  if (updatedFrom) filters.updated_from = updatedFrom;
  if (updatedTo) filters.updated_to = updatedTo;

  const { data, isLoading, refetch, isFetching } = useQuery({
    queryKey: ["faqs", page, 20, "id", filters],
    queryFn: () => faqService.fetchFaqs(page, 20, "id", filters),
  });

  const allFaqs = data?.faqs ?? [];
  const faqs = allFaqs.filter(f => {
    if (createdFrom && new Date(f.created_at) < new Date(createdFrom)) return false;
    if (createdTo   && new Date(f.created_at) > new Date(createdTo + "T23:59:59")) return false;
    if (updatedFrom && new Date(f.updated_at) < new Date(updatedFrom)) return false;
    if (updatedTo   && new Date(f.updated_at) > new Date(updatedTo + "T23:59:59")) return false;
    return true;
  });

  const total = data?.totalFaqs ?? 0;
  const totalPages = data?.totalPages ?? 1;
  const displayTotal = (createdFrom || createdTo || updatedFrom || updatedTo) ? faqs.length : total;

  const deleteMut = useMutation({
    mutationFn: (id: number) => faqService.deleteFaq(id),
    onSuccess: () => { toast.success(t("faqs.deleted")); qc.invalidateQueries({ queryKey: ["faqs"] }); setDelConfirm(null); },
    onError: () => toast.error(t("faqs.deleteError")),
  });

  const allColumns: Column<FaqItem>[] = [
    {
      key: "id",
      label: t("common.id"),
      sortable: true,
      getValue: f => f.id,
      render: f => <span className="text-xs font-mono text-gray-400">#{f.id}</span>,
    },
    {
      key: "question",
      label: t("faqs.question"),
      sortable: true,
      getValue: f => f.question,
      render: f => (
        <div className="max-w-xs">
          <p className="font-medium text-gray-900 truncate">{f.question}</p>
          <p className="text-xs text-gray-400 truncate">{f.answer}</p>
        </div>
      ),
    },
    {
      key: "target_user",
      label: t("faqs.targetUser"),
      sortable: true,
      getValue: f => f.target_user ?? "ALL",
      render: f => (
        <span className="text-xs px-2.5 py-1 rounded-full bg-indigo-100 text-indigo-700 font-medium">{f.target_user ?? "ALL"}</span>
      ),
    },
    {
      key: "language",
      label: t("faqs.language"),
      sortable: true,
      getValue: f => f.language ?? "",
      render: f => <span className="text-gray-600 text-xs">{f.language ?? "—"}</span>,
    },
    {
      key: "sort_id",
      label: t("common.sort"),
      sortable: true,
      getValue: f => f.sort_id ?? 0,
      render: f => <span className="text-gray-600">{f.sort_id ?? "—"}</span>,
    },
    {
      key: "is_active",
      label: t("common.status"),
      sortable: true,
      getValue: f => f.is_active ? 1 : 0,
      render: f => f.is_active
        ? <span className="inline-flex items-center gap-1 text-xs px-2.5 py-1 rounded-full bg-green-100 text-green-700"><CheckCircle size={11} /> {t("common.active")}</span>
        : <span className="inline-flex items-center gap-1 text-xs px-2.5 py-1 rounded-full bg-gray-100 text-gray-500"><XCircle size={11} /> {t("common.inactive")}</span>,
    },
    {
      key: "created_at",
      label: t("common.createdAt"),
      sortable: true,
      getValue: f => new Date(f.created_at),
      render: f => (
        <span className="text-xs text-gray-500">
          {new Date(f.created_at).toLocaleDateString(undefined, { year: "numeric", month: "short", day: "numeric" })}
        </span>
      ),
    },
    {
      key: "updated_at",
      label: t("common.updatedAt"),
      sortable: true,
      getValue: f => new Date(f.updated_at),
      render: f => (
        <span className="text-xs text-gray-500">
          {new Date(f.updated_at).toLocaleDateString(undefined, { year: "numeric", month: "short", day: "numeric" })}
        </span>
      ),
    },
    {
      key: "actions",
      label: t("common.actions"),
      align: "right",
      render: f => (
        <div className="flex items-center justify-end gap-2">
          {delConfirm === f.id ? (
            <>
              <span className="text-xs text-gray-600">Delete?</span>
              <button onClick={() => deleteMut.mutate(f.id)} disabled={deleteMut.isPending} className="px-3 py-1.5 text-xs bg-red-600 text-white rounded-lg disabled:opacity-50">{t("common.yes")}</button>
              <button onClick={() => setDelConfirm(null)} className="px-3 py-1.5 text-xs border border-gray-300 rounded-lg">{t("common.cancel")}</button>
            </>
          ) : (
            <>
              <button onClick={() => { setEditing(f); setModalOpen(true); }} className="p-2 rounded-lg text-gray-400 hover:text-indigo-600 hover:bg-indigo-50"><Pencil size={15} /></button>
              <button onClick={() => setDelConfirm(f.id)} className="p-2 rounded-lg text-gray-400 hover:text-red-600 hover:bg-red-50"><Trash2 size={15} /></button>
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
            <HelpCircle size={22} className="text-indigo-600" />
            <h1 className="text-2xl font-bold text-gray-900">{t("faqs.title")}</h1>
          </div>
          <p className="text-sm text-gray-500">{t("faqs.subtitle")}</p>
        </div>
        <button onClick={() => refetch()} disabled={isFetching} className="flex items-center gap-2 px-4 py-2 border border-gray-300 rounded-xl text-sm text-gray-600 hover:bg-gray-50 disabled:opacity-50">
          <RefreshCw size={15} className={isFetching ? "animate-spin" : ""} /> {t("common.refresh")}
        </button>
      </div>

      <div className="bg-indigo-50 border border-indigo-100 rounded-2xl px-5 py-4 text-center w-40">
        <p className="text-3xl font-bold text-indigo-700">{total}</p>
        <p className="text-xs text-indigo-400 mt-1">{t("faqs.total")}</p>
      </div>

      <TableToolbar
        total={displayTotal}
        totalLabel="FAQ"
        search={search}
        onSearch={v => { setSearch(v); setPage(1); }}
        searchPlaceholder={t("faqs.searchPlaceholder")}
        action={
          <div className="flex items-center gap-2">
            <ColumnToggle columns={columnOptions} visible={visible} onChange={setVisible} />
            <button onClick={() => { setEditing(null); setModalOpen(true); }} className="flex items-center gap-2 px-4 py-2 bg-indigo-600 text-white rounded-xl text-sm hover:bg-indigo-700">
              <Plus size={16} /> {t("faqs.new")}
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
        <select value={filterStatus} onChange={e => { setFilterStatus(e.target.value as typeof filterStatus); setPage(1); }} className="input w-auto">
          <option value="all">{t("common.all")}</option>
          <option value="active">{t("common.active")}</option>
          <option value="inactive">{t("common.inactive")}</option>
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
        rows={faqs}
        keyExtractor={f => f.id}
        isLoading={isLoading}
        emptyText={t("faqs.noResults")}
        emptyIcon={<HelpCircle size={36} className="text-gray-300" />}
        onRowClick={(row) => router.push(`/faqs/${row.id}`)}
      />

      <TablePagination page={page} totalPages={totalPages} total={displayTotal} limit={20} onPageChange={setPage} />

      {modalOpen && (
        <FaqModal faq={editing} onClose={() => { setModalOpen(false); setEditing(null); }}
          onSaved={() => { setModalOpen(false); setEditing(null); qc.invalidateQueries({ queryKey: ["faqs"] }); }} t={t} />
      )}
    </div>
  );
}

function FaqModal({ faq, onClose, onSaved, t }: { faq: FaqItem | null; onClose: () => void; onSaved: () => void; t: (k: string) => string }) {
  const [form, setForm] = useState({
    question: faq?.question ?? "",
    answer: faq?.answer ?? "",
    language: faq?.language ?? "EN" as FaqLanguage,
    target_user: faq?.target_user ?? "ALL" as FaqTargetUser,
    is_active: faq?.is_active ?? true,
    sort_id: faq?.sort_id?.toString() ?? "",
  });

  const saveMut = useMutation({
    mutationFn: (d: typeof form) => {
      const payload: any = {
        question: d.question,
        answer: d.answer,
        language: d.language,
        target_user: d.target_user,
        is_active: d.is_active,
        sort_id: Number(d.sort_id) || 0,
      };
      return faq
        ? faqService.updateFaq(faq.id, payload)
        : faqService.createFaq(payload);
    },
    onSuccess: () => { toast.success(faq ? t("faqs.updated") : t("faqs.created")); onSaved(); },
    onError: () => toast.error("Save failed"),
  });

  const set = (k: keyof typeof form, v: string | boolean) => setForm(p => ({ ...p, [k]: v }));

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4">
      <div className="bg-white rounded-2xl shadow-2xl w-full max-w-lg max-h-[90vh] overflow-y-auto">
        <div className="flex items-center justify-between px-6 py-5 border-b border-gray-100">
          <h2 className="text-lg font-bold text-gray-900">{faq ? t("common.edit") : t("faqs.new")}</h2>
          <button onClick={onClose} className="p-2 rounded-xl hover:bg-gray-100 text-gray-400"><X size={18} /></button>
        </div>
        <form onSubmit={e => { e.preventDefault(); saveMut.mutate(form); }} className="px-6 py-5 space-y-4">
          <div className="grid grid-cols-2 gap-4">
            <div className="space-y-1.5">
              <label className="text-xs font-semibold text-gray-600 uppercase">{t("faqs.language")}</label>
              <select value={form.language} onChange={e => set("language", e.target.value)} className="input">
                <option value="EN">English</option>
                <option value="AR">Arabic</option>
              </select>
            </div>
            <div className="space-y-1.5">
              <label className="text-xs font-semibold text-gray-600 uppercase">{t("faqs.targetUser")}</label>
              <select value={form.target_user} onChange={e => set("target_user", e.target.value)} className="input">
                <option value="ALL">All Users</option>
                <option value="CUSTOMER">Customer</option>
                <option value="COURIER">Courier</option>
              </select>
            </div>
          </div>
          <div className="space-y-1.5">
            <label className="text-xs font-semibold text-gray-600 uppercase">{t("faqs.question")}</label>
            <input required value={form.question} onChange={e => set("question", e.target.value)}
              dir={form.language === "AR" ? "rtl" : undefined} className={`input ${form.language === "AR" ? "text-right" : ""}`} />
          </div>
          <div className="space-y-1.5">
            <label className="text-xs font-semibold text-gray-600 uppercase">{t("faqs.answer")}</label>
            <textarea required value={form.answer} onChange={e => set("answer", e.target.value)} rows={4}
              dir={form.language === "AR" ? "rtl" : undefined}
              className={`w-full border border-gray-300 rounded-xl px-3 py-2 text-sm focus:ring-2 focus:ring-indigo-500 outline-none resize-none ${form.language === "AR" ? "text-right" : ""}`} />
          </div>
          <div className="grid grid-cols-2 gap-4">
            <div className="space-y-1.5">
              <label className="text-xs font-semibold text-gray-600 uppercase">{t("faqs.sortId")}</label>
              <input type="number" min="0" value={form.sort_id} onChange={e => set("sort_id", e.target.value)} className="input" />
            </div>
          </div>
          <label className="flex items-center gap-2 text-sm text-gray-700 cursor-pointer">
            <input type="checkbox" checked={form.is_active} onChange={e => set("is_active", e.target.checked)} className="w-4 h-4 rounded border-gray-300 text-indigo-600" />
            {t("faqs.isActive")}
          </label>
          <div className="flex justify-end gap-3 pt-2 border-t border-gray-100">
            <button type="button" onClick={onClose} className="px-5 py-2.5 border border-gray-300 rounded-xl text-sm text-gray-700 hover:bg-gray-50">{t("common.cancel")}</button>
            <button type="submit" disabled={saveMut.isPending} className="px-6 py-2.5 bg-indigo-600 text-white rounded-xl text-sm font-medium hover:bg-indigo-700 disabled:opacity-60">
              {saveMut.isPending ? t("common.saving") : faq ? t("common.save") : t("common.create")}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
