"use client";
import { useState } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import {
  fetchRoles, createRole, updateRole, deleteRole, type Role,
} from "@/lib/roles";
import { useT } from "@/contexts/LanguageContext";
import {
  Shield, RefreshCw, Plus, Pencil, Trash2, X,
} from "lucide-react";
import toast from "react-hot-toast";
import { DataTable, type Column } from "@/components/ui/DataTable";
import { TableToolbar } from "@/components/ui/TableToolbar";
import { TablePagination } from "@/components/ui/TablePagination";
import { DateRangeFilter } from "@/components/ui/DateRangeFilter";
import { ColumnToggle, type ColumnOption } from "@/components/ui/ColumnToggle";
import { useColumnVisibility } from "@/hooks/useColumnVisibility";

const ALL_COLUMN_KEYS = ["id", "name", "name_ar", "created_at", "updated_at", "actions"] as const;

export default function RolesPage() {
  const { t } = useT();
  const qc = useQueryClient();
  const [page, setPage] = useState(1);
  const [search, setSearch] = useState("");
  const [createdFrom, setCreatedFrom] = useState("");
  const [createdTo, setCreatedTo] = useState("");
  const [updatedFrom, setUpdatedFrom] = useState("");
  const [updatedTo, setUpdatedTo] = useState("");
  const [createModal, setCreateModal] = useState(false);
  const [editRole, setEditRole] = useState<Role | null>(null);
  const [deleteId, setDeleteId] = useState<number | null>(null);

  const { visible, setVisible } = useColumnVisibility("cols:roles", [...ALL_COLUMN_KEYS]);

  const { data, isLoading, isFetching, refetch } = useQuery({
    queryKey: ["roles", page, search],
    queryFn: () => fetchRoles({ page, limit: 20, search }),
    staleTime: 30_000,
  });

  const allRoles = data?.roles ?? [];
  const roles = allRoles.filter(r => {
    if (createdFrom && new Date(r.created_at) < new Date(createdFrom)) return false;
    if (createdTo   && new Date(r.created_at) > new Date(createdTo + "T23:59:59")) return false;
    if (updatedFrom && new Date(r.updated_at) < new Date(updatedFrom)) return false;
    if (updatedTo   && new Date(r.updated_at) > new Date(updatedTo + "T23:59:59")) return false;
    return true;
  });

  const totalPages = data?.totalPages ?? 1;
  const totalRoles = data?.totalRoles ?? 0;
  const displayTotal = (createdFrom || createdTo || updatedFrom || updatedTo) ? roles.length : totalRoles;

  const deleteMut = useMutation({
    mutationFn: deleteRole,
    onSuccess: () => { toast.success(t("roles.deleted")); qc.invalidateQueries({ queryKey: ["roles"] }); setDeleteId(null); },
    onError: () => toast.error(t("roles.deleteFailed")),
  });

  const allColumns: Column<Role>[] = [
    {
      key: "id",
      label: t("common.id"),
      sortable: true,
      getValue: role => role.id,
      render: role => <span className="text-xs font-mono text-gray-400">#{role.id}</span>,
    },
    {
      key: "name",
      label: t("common.name"),
      sortable: true,
      getValue: role => role.name,
      render: role => <span className="font-medium text-gray-900">{role.name}</span>,
    },
    {
      key: "name_ar",
      label: t("common.arabic"),
      sortable: true,
      getValue: role => role.name_ar,
      render: role => <span className="text-gray-600" dir="rtl">{role.name_ar}</span>,
    },
    {
      key: "created_at",
      label: t("common.createdAt"),
      sortable: true,
      getValue: role => new Date(role.created_at),
      render: role => (
        <span className="text-xs text-gray-500">
          {new Date(role.created_at).toLocaleDateString(undefined, { year: "numeric", month: "short", day: "numeric" })}
        </span>
      ),
    },
    {
      key: "updated_at",
      label: t("common.updatedAt"),
      sortable: true,
      getValue: role => new Date(role.updated_at),
      render: role => (
        <span className="text-xs text-gray-500">
          {new Date(role.updated_at).toLocaleDateString(undefined, { year: "numeric", month: "short", day: "numeric" })}
        </span>
      ),
    },
    {
      key: "actions",
      label: t("common.actions"),
      align: "right",
      render: role => (
        <div className="flex items-center justify-end gap-2">
          <button onClick={() => setEditRole(role)}
            className="p-1.5 text-gray-400 hover:text-indigo-600 hover:bg-indigo-50 rounded-lg transition">
            <Pencil size={14} />
          </button>
          <button onClick={() => setDeleteId(role.id)}
            className="p-1.5 text-gray-400 hover:text-red-600 hover:bg-red-50 rounded-lg transition">
            <Trash2 size={14} />
          </button>
        </div>
      ),
    },
  ];

  const columns = allColumns.filter(c => visible.includes(c.key));
  const columnOptions: ColumnOption[] = allColumns.map(c => ({ key: c.key, label: c.label, alwaysVisible: c.key === "actions" }));

  return (
    <div className="p-6 space-y-6">
      {/* Header */}
      <div className="flex items-start justify-between flex-wrap gap-3">
        <div>
          <div className="flex items-center gap-2 mb-1">
            <Shield size={22} className="text-indigo-600" />
            <h1 className="text-2xl font-bold text-gray-900">{t("roles.title")}</h1>
          </div>
          <p className="text-sm text-gray-500">{t("roles.subtitle")}</p>
        </div>
        <button onClick={() => refetch()} disabled={isFetching}
          className="flex items-center gap-2 px-4 py-2 border border-gray-300 rounded-xl text-sm text-gray-600 hover:bg-gray-50 disabled:opacity-50">
          <RefreshCw size={15} className={isFetching ? "animate-spin" : ""} />
          {t("common.refresh")}
        </button>
      </div>

      <TableToolbar
        total={displayTotal}
        totalLabel={t("common.results")}
        search={search}
        onSearch={v => { setSearch(v); setPage(1); }}
        searchPlaceholder={t("roles.searchPlaceholder")}
        action={
          <div className="flex items-center gap-2">
            <ColumnToggle columns={columnOptions} visible={visible} onChange={setVisible} />
            <button onClick={() => setCreateModal(true)}
              className="flex items-center gap-2 px-4 py-2 bg-indigo-600 text-white rounded-xl text-sm font-medium hover:bg-indigo-700">
              <Plus size={15} />
              {t("roles.new")}
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
        rows={roles}
        keyExtractor={role => role.id}
        isLoading={isLoading}
        emptyText={t("common.noResults")}
        emptyIcon={<Shield size={36} className="text-gray-300" />}
      />

      <TablePagination page={page} totalPages={totalPages} total={displayTotal} limit={20} onPageChange={setPage} />

      {createModal && (
        <RoleModal
          onClose={() => setCreateModal(false)}
          onSaved={() => { setCreateModal(false); qc.invalidateQueries({ queryKey: ["roles"] }); }}
          t={t}
        />
      )}
      {editRole && (
        <RoleModal
          role={editRole}
          onClose={() => setEditRole(null)}
          onSaved={() => { setEditRole(null); qc.invalidateQueries({ queryKey: ["roles"] }); }}
          t={t}
        />
      )}
      {deleteId !== null && (
        <ConfirmDelete
          onConfirm={() => deleteMut.mutate(deleteId!)}
          onCancel={() => setDeleteId(null)}
          isPending={deleteMut.isPending}
          t={t}
        />
      )}
    </div>
  );
}

function RoleModal({
  role, onClose, onSaved, t,
}: { role?: Role; onClose: () => void; onSaved: () => void; t: (k: string) => string }) {
  const [form, setForm] = useState({
    name: role?.name ?? "",
    name_ar: role?.name_ar ?? "",
    description: role?.description ?? "",
    description_ar: role?.description_ar ?? "",
  });

  const mut = useMutation({
    mutationFn: () =>
      role
        ? updateRole(role.id, form)
        : createRole(form),
    onSuccess: () => { toast.success(role ? t("roles.updated") : t("roles.created")); onSaved(); },
    onError: () => toast.error(t("common.saving")),
  });

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4">
      <div className="bg-white rounded-2xl shadow-2xl w-full max-w-lg">
        <div className="flex items-center justify-between px-6 py-5 border-b border-gray-100">
          <h2 className="text-lg font-bold text-gray-900">{role ? t("roles.edit") : t("roles.new")}</h2>
          <button onClick={onClose} className="p-2 rounded-xl hover:bg-gray-100 text-gray-400"><X size={18} /></button>
        </div>
        <form onSubmit={e => { e.preventDefault(); mut.mutate(); }} className="px-6 py-5 space-y-4">
          <div className="grid grid-cols-2 gap-4">
            <Field label={t("roles.nameEn")} value={form.name} onChange={v => setForm(p => ({ ...p, name: v }))} required />
            <Field label={t("roles.nameAr")} value={form.name_ar} onChange={v => setForm(p => ({ ...p, name_ar: v }))} required dir="rtl" />
          </div>
          <div className="grid grid-cols-2 gap-4">
            <Field label={t("roles.descriptionEn")} value={form.description} onChange={v => setForm(p => ({ ...p, description: v }))} />
            <Field label={t("roles.descriptionAr")} value={form.description_ar} onChange={v => setForm(p => ({ ...p, description_ar: v }))} dir="rtl" />
          </div>
          <div className="flex justify-end gap-3 pt-2 border-t border-gray-100">
            <button type="button" onClick={onClose} className="px-5 py-2.5 border border-gray-300 rounded-xl text-sm text-gray-700 hover:bg-gray-50">
              {t("common.cancel")}
            </button>
            <button type="submit" disabled={mut.isPending || !form.name || !form.name_ar}
              className="px-6 py-2.5 bg-indigo-600 text-white rounded-xl text-sm font-medium hover:bg-indigo-700 disabled:opacity-60">
              {mut.isPending ? t("common.saving") : role ? t("common.update") : t("common.create")}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}

function Field({ label, value, onChange, required, dir }: { label: string; value: string; onChange: (v: string) => void; required?: boolean; dir?: string }) {
  return (
    <div className="space-y-1.5">
      <label className="text-xs font-semibold text-gray-600 uppercase">{label}</label>
      <input required={required} value={value} onChange={e => onChange(e.target.value)} dir={dir}
        className="input w-full" />
    </div>
  );
}

function ConfirmDelete({ onConfirm, onCancel, isPending, t }: { onConfirm: () => void; onCancel: () => void; isPending: boolean; t: (k: string) => string }) {
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4">
      <div className="bg-white rounded-2xl shadow-2xl w-full max-w-sm p-6 space-y-4">
        <h2 className="text-lg font-bold text-gray-900">{t("common.sure")}</h2>
        <p className="text-sm text-gray-500">{t("roles.deleteConfirm")}</p>
        <div className="flex justify-end gap-3">
          <button onClick={onCancel} className="px-5 py-2.5 border border-gray-300 rounded-xl text-sm text-gray-700 hover:bg-gray-50">
            {t("common.cancel")}
          </button>
          <button onClick={onConfirm} disabled={isPending}
            className="px-6 py-2.5 bg-red-600 text-white rounded-xl text-sm font-medium hover:bg-red-700 disabled:opacity-60">
            {isPending ? t("common.saving") : t("common.delete")}
          </button>
        </div>
      </div>
    </div>
  );
}
