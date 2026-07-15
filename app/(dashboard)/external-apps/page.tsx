"use client";
import { useState } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { fetchExternalApps, deleteExternalApp } from "@/lib/external-apps";
import { useT } from "@/contexts/LanguageContext";
import { Globe, Plus, Pencil, Trash2, Webhook } from "lucide-react";
import toast from "react-hot-toast";
import { DataTable, type Column } from "@/components/ui/DataTable";
import { TableToolbar } from "@/components/ui/TableToolbar";
import { TablePagination } from "@/components/ui/TablePagination";
import { Badge } from "@/components/ui/badge";
import { ExternalAppModal } from "./_components/ExternalAppModal";
import type { ExternalApp } from "@/types/external-apps";

export default function ExternalAppsPage() {
  const { t } = useT();
  const qc = useQueryClient();
  const [page, setPage] = useState(1);
  const [search, setSearch] = useState("");
  const [modalOpen, setModalOpen] = useState(false);
  const [editing, setEditing] = useState<ExternalApp | null>(null);

  const { data, isLoading } = useQuery({
    queryKey: ["external-apps", { page, search }],
    queryFn: () =>
      fetchExternalApps({
        page,
        limit: 10,
        keyword: search,
        includes: "contracts=id-external_app_id-start_date-end_date-is_active-can_receive_courier_offers-vehicle_configs=id-contract_id-vehicle_id-min_fee-m_min-m_max-extra_m_price-fee_per_m-splits,wallet",
      }),
  });

  const apps = data?.apps ?? [];
  const total = data?.totalCount ?? 0;
  const totalPages = data?.totalPages ?? 1;

  const deleteMut = useMutation({
    mutationFn: (id: number) => deleteExternalApp(id),
    onSuccess: () => {
      toast.success("App deleted successfully");
      qc.invalidateQueries({ queryKey: ["external-apps"] });
    },
  });

  const columns: Column<ExternalApp>[] = [
    {
      key: "name",
      label: "Application",
      render: (app) => (
        <div className="flex flex-col">
          <span className="font-bold text-gray-900">{app.name}</span>
          <span className="text-xs font-mono text-gray-400">
            {app.client_id}
          </span>
        </div>
      ),
    },
    {
      key: "environment",
      label: "Env",
      render: (app) => (
        <Badge
          variant={app.environment === "PRODUCTION" ? "default" : "secondary"}
        >
          {app.environment}
        </Badge>
      ),
    },
    {
      key: "webhook_url",
      label: "Webhook",
      render: (app) =>
        app.webhook_url ? (
          <div className="flex items-center gap-1 text-xs text-blue-600">
            <Webhook size={12} /> {app.webhook_url.substring(0, 30)}...
          </div>
        ) : (
          <span className="text-gray-300">Disabled</span>
        ),
    },
    {
      key: "is_active",
      label: "Status",
      render: (app) => (
        <Badge className={app.is_active ? "bg-emerald-500" : "bg-gray-400"}>
          {app.is_active ? "Active" : "Inactive"}
        </Badge>
      ),
    },
    {
      key: "actions",
      label: "",
      align: "right",
      render: (app) => (
        <div className="flex justify-end gap-2">
          <button
            onClick={() => {
              setEditing(app);
              setModalOpen(true);
            }}
            className="p-2 hover:bg-indigo-50 text-indigo-600 rounded-lg"
          >
            <Pencil size={16} />
          </button>
          <button
            onClick={() => {
              if (confirm("Are you sure?")) deleteMut.mutate(app.id);
            }}
            className="p-2 hover:bg-red-50 text-red-600 rounded-lg"
          >
            <Trash2 size={16} />
          </button>
        </div>
      ),
    },
  ];

  return (
    <div className="p-6 space-y-6">
      <div className="flex justify-between items-center">
        <div>
          <h1 className="text-2xl font-bold flex items-center gap-2">
            <Globe className="text-indigo-600" /> External Integrations
          </h1>
          <p className="text-gray-500">
            Manage 3rd party API access and fee contracts
          </p>
        </div>
        <button
          onClick={() => {
            setEditing(null);
            setModalOpen(true);
          }}
          className="bg-indigo-600 text-white px-4 py-2 rounded-xl flex items-center gap-2 hover:bg-indigo-700 transition"
        >
          <Plus size={18} /> New Integration
        </button>
      </div>

      <TableToolbar
        total={total}
        search={search}
        onSearch={setSearch}
        searchPlaceholder="Search by name or client_id..."
      />

      <DataTable
        keyExtractor={(app) => app.id}
        isLoading={isLoading}
        emptyText={t("externalApps.noResults")}
        columns={columns}
        rows={apps}
      />

      <TablePagination
        limit={10}
        page={page}
        totalPages={totalPages}
        total={total}
        onPageChange={setPage}
      />

      <ExternalAppModal
        open={modalOpen}
        onOpenChange={setModalOpen}
        app={editing}
        onSaved={() => qc.invalidateQueries({ queryKey: ["external-apps"] })}
      />
    </div>
  );
}
