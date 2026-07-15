"use client";
import { useState } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { fetchContactMessages, updateContactMessage, deleteContactMessage, type ContactMessage } from "@/lib/contact";
import { useT } from "@/contexts/LanguageContext";
import { Mail, Trash2, RefreshCw, X, MessageSquare, CheckCircle } from "lucide-react";
import { DataTable, type Column } from "@/components/ui/DataTable";
import { TableToolbar } from "@/components/ui/TableToolbar";
import { TablePagination } from "@/components/ui/TablePagination";
import { DateRangeFilter } from "@/components/ui/DateRangeFilter";
import { ColumnToggle, type ColumnOption } from "@/components/ui/ColumnToggle";
import { useColumnVisibility } from "@/hooks/useColumnVisibility";
import toast from "react-hot-toast";

function fmtDate(d: string) { return new Date(d).toLocaleDateString("en-GB", { day: "2-digit", month: "short", year: "numeric", hour: "2-digit", minute: "2-digit" }); }

const ALL_COLUMN_KEYS = ["id", "from", "message", "created_at", "is_read", "updated_at", "actions"] as const;

export default function ContactPage() {
  const { t } = useT();
  const qc = useQueryClient();
  const [page, setPage] = useState(1);
  const [search, setSearch] = useState("");
  const [createdFrom, setCreatedFrom] = useState("");
  const [createdTo, setCreatedTo] = useState("");
  const [updatedFrom, setUpdatedFrom] = useState("");
  const [updatedTo, setUpdatedTo] = useState("");
  const [delConfirm, setDelConfirm] = useState<number | null>(null);
  const [viewModal, setViewModal] = useState<ContactMessage | null>(null);

  const { visible, setVisible } = useColumnVisibility("cols:contact", [...ALL_COLUMN_KEYS]);

  const params: Record<string, string | number> = { page, limit: 20 };
  if (search) params.keyword = search;

  const { data, isLoading, refetch, isFetching } = useQuery({
    queryKey: ["contact-messages", params],
    queryFn: () => fetchContactMessages(params),
  });

  const allMessages = data?.messages ?? [];
  const messages = allMessages.filter(m => {
    if (createdFrom && new Date(m.created_at) < new Date(createdFrom)) return false;
    if (createdTo   && new Date(m.created_at) > new Date(createdTo + "T23:59:59")) return false;
    if (updatedFrom && new Date(m.updated_at) < new Date(updatedFrom)) return false;
    if (updatedTo   && new Date(m.updated_at) > new Date(updatedTo + "T23:59:59")) return false;
    return true;
  });

  const total = data?.totalMessages ?? 0;
  const totalPages = data?.totalPages ?? 1;
  const unreadCount = messages.filter(m => !m.read).length;
  const displayTotal = (createdFrom || createdTo || updatedFrom || updatedTo) ? messages.length : total;

  const deleteMut = useMutation({
    mutationFn: (id: number) => deleteContactMessage(id),
    onSuccess: () => { toast.success(t("contact.deleted")); qc.invalidateQueries({ queryKey: ["contact-messages"] }); setDelConfirm(null); },
    onError: () => toast.error(t("contact.deleteError")),
  });

  const markReadMut = useMutation({
    mutationFn: (id: number) => updateContactMessage(id, { read: true }),
    onSuccess: () => { qc.invalidateQueries({ queryKey: ["contact-messages"] }); },
  });

  const allColumns: Column<ContactMessage>[] = [
    {
      key: "id",
      label: t("common.id"),
      sortable: true,
      getValue: m => m.id,
      render: m => <span className="text-xs font-mono text-gray-400">#{m.id}</span>,
    },
    {
      key: "from",
      label: t("contact.from"),
      sortable: true,
      getValue: m => m.name,
      render: m => (
        <div>
          <p className="font-medium text-gray-900">{m.name}</p>
          <p className="text-xs text-gray-400">{m.email}</p>
        </div>
      ),
    },
    {
      key: "message",
      label: t("contact.message"),
      render: m => (
        <div className="max-w-xs">
          <p className="text-gray-700 truncate">{m.message}</p>
          {m.response && <p className="text-xs text-green-600 truncate mt-0.5">↳ {m.response}</p>}
        </div>
      ),
    },
    {
      key: "created_at",
      label: t("contact.receivedAt"),
      sortable: true,
      getValue: m => new Date(m.created_at),
      render: m => <span className="text-gray-500 text-xs">{fmtDate(m.created_at)}</span>,
    },
    {
      key: "is_read",
      label: t("common.status"),
      sortable: true,
      getValue: m => m.read ? 1 : 0,
      render: m => m.read
        ? <span className="inline-flex items-center gap-1 text-xs px-2.5 py-1 rounded-full bg-green-100 text-green-700"><CheckCircle size={11} /> Read</span>
        : <span className="text-xs px-2.5 py-1 rounded-full bg-amber-100 text-amber-700 font-medium">Unread</span>,
    },
    {
      key: "updated_at",
      label: t("common.updatedAt"),
      sortable: true,
      getValue: m => new Date(m.updated_at),
      render: m => (
        <span className="text-xs text-gray-500">
          {new Date(m.updated_at).toLocaleDateString(undefined, { year: "numeric", month: "short", day: "numeric" })}
        </span>
      ),
    },
    {
      key: "actions",
      label: t("common.actions"),
      align: "right",
      render: m => (
        <div className="flex items-center justify-end gap-2">
          <button onClick={() => { setViewModal(m); if (!m.read) markReadMut.mutate(m.id); }}
            className="p-2 rounded-lg text-gray-400 hover:text-indigo-600 hover:bg-indigo-50">
            <MessageSquare size={15} />
          </button>
          {delConfirm === m.id ? (
            <>
              <button onClick={() => deleteMut.mutate(m.id)} disabled={deleteMut.isPending} className="px-3 py-1.5 text-xs bg-red-600 text-white rounded-lg disabled:opacity-50">{t("common.yes")}</button>
              <button onClick={() => setDelConfirm(null)} className="px-3 py-1.5 text-xs border border-gray-300 rounded-lg">{t("common.cancel")}</button>
            </>
          ) : (
            <button onClick={() => setDelConfirm(m.id)} className="p-2 rounded-lg text-gray-400 hover:text-red-600 hover:bg-red-50"><Trash2 size={15} /></button>
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
            <Mail size={22} className="text-indigo-600" />
            <h1 className="text-2xl font-bold text-gray-900">{t("contact.title")}</h1>
          </div>
          <p className="text-sm text-gray-500">{t("contact.subtitle")}</p>
        </div>
        <button onClick={() => refetch()} disabled={isFetching} className="flex items-center gap-2 px-4 py-2 border border-gray-300 rounded-xl text-sm text-gray-600 hover:bg-gray-50 disabled:opacity-50">
          <RefreshCw size={15} className={isFetching ? "animate-spin" : ""} /> {t("common.refresh")}
        </button>
      </div>

      <div className="flex gap-4">
        <div className="bg-indigo-50 border border-indigo-100 rounded-2xl px-5 py-4 text-center">
          <p className="text-3xl font-bold text-indigo-700">{total}</p>
          <p className="text-xs text-indigo-400 mt-1">{t("contact.total")}</p>
        </div>
        <div className="bg-amber-50 border border-amber-100 rounded-2xl px-5 py-4 text-center">
          <p className="text-3xl font-bold text-amber-700">{unreadCount}</p>
          <p className="text-xs text-amber-400 mt-1">{t("contact.unread")}</p>
        </div>
      </div>

      <TableToolbar
        total={displayTotal}
        totalLabel="message"
        search={search}
        onSearch={v => { setSearch(v); setPage(1); }}
        searchPlaceholder={t("contact.searchPlaceholder")}
        action={
          <div className="flex items-center gap-2">
            <ColumnToggle columns={columnOptions} visible={visible} onChange={setVisible} />
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
        rows={messages}
        keyExtractor={m => m.id}
        isLoading={isLoading}
        emptyText={t("contact.noResults")}
        emptyIcon={<Mail size={36} className="text-gray-300" />}
      />

      <TablePagination page={page} totalPages={totalPages} total={displayTotal} limit={20} onPageChange={setPage} />

      {viewModal && (
        <MessageModal message={viewModal} onClose={() => setViewModal(null)}
          onSaved={() => { setViewModal(null); qc.invalidateQueries({ queryKey: ["contact-messages"] }); }} t={t} />
      )}
    </div>
  );
}

function MessageModal({ message, onClose, onSaved, t }: { message: ContactMessage; onClose: () => void; onSaved: () => void; t: (k: string) => string }) {
  const [response, setResponse] = useState(message.response ?? "");
  const saveMut = useMutation({
    mutationFn: () => updateContactMessage(message.id, { response, read: true }),
    onSuccess: () => { toast.success(t("contact.responded")); onSaved(); },
    onError: () => toast.error("Failed to send"),
  });

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4">
      <div className="bg-white rounded-2xl shadow-2xl w-full max-w-lg">
        <div className="flex items-center justify-between px-6 py-5 border-b border-gray-100">
          <h2 className="text-lg font-bold text-gray-900">{t("contact.message")}</h2>
          <button onClick={onClose} className="p-2 rounded-xl hover:bg-gray-100 text-gray-400"><X size={18} /></button>
        </div>
        <div className="px-6 py-5 space-y-4">
          <div>
            <p className="text-xs font-semibold text-gray-500 uppercase mb-1">{t("contact.from")}</p>
            <p className="text-gray-900 font-medium">{message.name} — {message.email}</p>
          </div>
          <div>
            <p className="text-xs font-semibold text-gray-500 uppercase mb-1">{t("contact.message")}</p>
            <p className="text-gray-700 bg-gray-50 rounded-xl px-4 py-3 text-sm">{message.message}</p>
          </div>
          <div className="space-y-1.5">
            <label className="text-xs font-semibold text-gray-600 uppercase">{t("contact.response")}</label>
            <textarea value={response} onChange={e => setResponse(e.target.value)} rows={4}
              placeholder={t("contact.respond")}
              className="w-full border border-gray-300 rounded-xl px-3 py-2 text-sm focus:ring-2 focus:ring-indigo-500 outline-none resize-none" />
          </div>
          <div className="flex justify-end gap-3 pt-2 border-t border-gray-100">
            <button type="button" onClick={onClose} className="px-5 py-2.5 border border-gray-300 rounded-xl text-sm text-gray-700 hover:bg-gray-50">{t("common.cancel")}</button>
            <button onClick={() => saveMut.mutate()} disabled={saveMut.isPending || !response.trim()}
              className="px-6 py-2.5 bg-indigo-600 text-white rounded-xl text-sm font-medium hover:bg-indigo-700 disabled:opacity-60">
              {saveMut.isPending ? t("common.saving") : t("contact.sendResponse")}
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}
