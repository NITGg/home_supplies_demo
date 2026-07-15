"use client";
import { useState, useEffect, Suspense } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import {
  fetchPeakTimes,
  createPeakTime,
  updatePeakTime,
  deletePeakTime,
  type PeakTime,
} from "@/lib/peak-time";
import { useT } from "@/contexts/LanguageContext";
import { Clock, Plus, Pencil, Trash2, RefreshCw, X, Eye } from "lucide-react";
import toast from "react-hot-toast";
import { DataTable, type Column } from "@/components/ui/DataTable";
import { TableToolbar } from "@/components/ui/TableToolbar";
import { TablePagination } from "@/components/ui/TablePagination";
import { DateRangeFilter } from "@/components/ui/DateRangeFilter";
import { ColumnToggle, type ColumnOption } from "@/components/ui/ColumnToggle";
import { useColumnVisibility } from "@/hooks/useColumnVisibility";
import { useRouter, useSearchParams } from "next/navigation";

const DAY_LABELS: Record<number, string> = {
  0: "Sunday",
  1: "Monday",
  2: "Tuesday",
  3: "Wednesday",
  4: "Thursday",
  5: "Friday",
  6: "Saturday",
};

const ALL_COLUMN_KEYS = [
  "id",
  "day",
  "start_time",
  "end_time",
  "is_active",
  "created_at",
  "updated_at",
  "actions",
] as const;

export default function PeakTimePage() {
  return (
    <Suspense>
      <PeakTimeContent />
    </Suspense>
  );
}

function PeakTimeContent() {
  const { t } = useT();
  const qc = useQueryClient();
  const router = useRouter();
  const [page, setPage] = useState(1);
  const [day, setDay] = useState("");
  const [startTimeFrom, setStartTimeFrom] = useState("");
  const [startTimeTo, setStartTimeTo] = useState("");
  const [endTimeFrom, setEndTimeFrom] = useState("");
  const [endTimeTo, setEndTimeTo] = useState("");
  const [isActive, setIsActive] = useState("");
  const [createdFrom, setCreatedFrom] = useState("");
  const [createdTo, setCreatedTo] = useState("");
  const [updatedFrom, setUpdatedFrom] = useState("");
  const [updatedTo, setUpdatedTo] = useState("");
  const [delConfirm, setDelConfirm] = useState<number | null>(null);
  const [modalOpen, setModalOpen] = useState(false);
  const [editing, setEditing] = useState<PeakTime | null>(null);

  const { visible, setVisible } = useColumnVisibility("cols:peak-time-v1", [
    ...ALL_COLUMN_KEYS,
  ]);
  const searchParams = useSearchParams();

  const params: Record<string, string | number> = {
    limit: 10,
    skip: (page - 1) * 10,
  };
  if (day) params.day = day;
  if (startTimeFrom) params["start_time[gte]"] = startTimeFrom;
  if (startTimeTo) params["start_time[lte]"] = startTimeTo;
  if (endTimeFrom) params["end_time[gte]"] = endTimeFrom;
  if (endTimeTo) params["end_time[lte]"] = endTimeTo;
  if (isActive !== "") params.is_active = isActive;
  if (createdFrom) params["created_at[gte]"] = createdFrom;
  if (createdTo) params["created_at[lte]"] = createdTo;
  if (updatedFrom) params["updated_at[gte]"] = updatedFrom;
  if (updatedTo) params["updated_at[lte]"] = updatedTo;

  const { data, isLoading, refetch, isFetching } = useQuery({
    queryKey: ["peak-times", params],
    queryFn: () => fetchPeakTimes(params),
  });

  const allPeakTimes = data?.peakTimes ?? [];
  const total = data?.totalPeakTimes ?? 0;
  const totalPages = data?.totalPages ?? 1;

  useEffect(() => {
    const editId = searchParams.get("edit");
    if (editId && allPeakTimes.length > 0) {
      const pt = allPeakTimes.find((p: any) => p.id === Number(editId));
      if (pt) {
        setEditing(pt);
        setModalOpen(true);
      }
    }
  }, [searchParams, allPeakTimes]);

  const deleteMut = useMutation({
    mutationFn: (id: number) => deletePeakTime(id),
    onSuccess: () => {
      toast.success("Peak time deleted successfully");
      qc.invalidateQueries({ queryKey: ["peak-times"] });
      setDelConfirm(null);
    },
    onError: () => toast.error("Failed to delete peak time"),
  });

  const allColumns: Column<PeakTime>[] = [
    {
      key: "id",
      label: "ID",
      sortable: true,
      getValue: (pt) => pt.id,
      render: (pt) => <span className="text-gray-500 font-mono">#{pt.id}</span>,
    },
    {
      key: "day",
      label: "Day",
      sortable: true,
      getValue: (pt) => pt.day,
      render: (pt) => (
        <span className="font-medium text-gray-900">
          {DAY_LABELS[pt.day] ?? `Day ${pt.day}`}
        </span>
      ),
    },
    {
      key: "start_time",
      label: "Start Time",
      sortable: true,
      getValue: (pt) => pt.start_time,
      render: (pt) => <span className="text-gray-700">{pt.start_time}</span>,
    },
    {
      key: "end_time",
      label: "End Time",
      sortable: true,
      getValue: (pt) => pt.end_time,
      render: (pt) => <span className="text-gray-700">{pt.end_time}</span>,
    },
    {
      key: "is_active",
      label: "Status",
      sortable: true,
      getValue: (pt) => (pt.is_active ? 1 : 0),
      render: (pt) => (
        <span
          className={`text-xs px-2.5 py-1 rounded-full font-medium ${pt.is_active ? "bg-green-100 text-green-700" : "bg-red-100 text-red-700"}`}
        >
          {pt.is_active ? "Active" : "Inactive"}
        </span>
      ),
    },
    {
      key: "created_at",
      label: "Created At",
      sortable: true,
      getValue: (pt) => new Date(pt.created_at),
      render: (pt) => (
        <span className="text-xs text-gray-500">
          {new Date(pt.created_at).toLocaleDateString(undefined, {
            year: "numeric",
            month: "short",
            day: "numeric",
            hour: "2-digit",
            minute: "2-digit",
          })}
        </span>
      ),
    },
    {
      key: "updated_at",
      label: "Updated At",
      sortable: true,
      getValue: (pt) => new Date(pt.updated_at),
      render: (pt) => (
        <span className="text-xs text-gray-500">
          {new Date(pt.updated_at).toLocaleDateString(undefined, {
            year: "numeric",
            month: "short",
            day: "numeric",
            hour: "2-digit",
            minute: "2-digit",
          })}
        </span>
      ),
    },
    {
      key: "actions",
      label: "Actions",
      align: "right",
      render: (pt) => (
        <div className="flex items-center justify-end gap-2">
          {delConfirm === pt.id ? (
            <>
              <span className="text-xs text-gray-600">Delete?</span>
              <button
                onClick={(e) => {
                  e.stopPropagation();
                  deleteMut.mutate(pt.id);
                }}
                disabled={deleteMut.isPending}
                className="px-3 py-1.5 text-xs bg-red-600 text-white rounded-lg disabled:opacity-50"
              >
                Yes
              </button>
              <button
                onClick={(e) => {
                  e.stopPropagation();
                  setDelConfirm(null);
                }}
                className="px-3 py-1.5 text-xs border border-gray-300 rounded-lg"
              >
                Cancel
              </button>
            </>
          ) : (
            <>
              <button
                onClick={() => router.push(`/peak-time/${pt.id}`)}
                className="p-2 rounded-lg text-gray-400 hover:text-indigo-600 hover:bg-indigo-50"
                title="View Details"
              >
                <Eye size={15} />
              </button>
              <button
                onClick={(e) => {
                  e.stopPropagation();
                  setEditing(pt);
                  setModalOpen(true);
                }}
                className="p-2 rounded-lg text-gray-400 hover:text-indigo-600 hover:bg-indigo-50"
              >
                <Pencil size={15} />
              </button>
              <button
                onClick={(e) => {
                  e.stopPropagation();
                  setDelConfirm(pt.id);
                }}
                className="p-2 rounded-lg text-gray-400 hover:text-red-600 hover:bg-red-50"
              >
                <Trash2 size={15} />
              </button>
            </>
          )}
        </div>
      ),
    },
  ];

  const columns = allColumns.filter((c) => visible.includes(c.key));
  const alwaysVisibleColumns = [
    "id",
    "day",
    "start_time",
    "end_time",
    "is_active",
    "actions",
  ];
  const columnOptions: ColumnOption[] = allColumns.map((c) => ({
    key: c.key,
    label: c.label,
    alwaysVisible: alwaysVisibleColumns.includes(c.key),
  }));

  return (
    <div className="p-6 space-y-6">
      <div className="flex items-start justify-between flex-wrap gap-3">
        <div>
          <div className="flex items-center gap-2 mb-1">
            <Clock size={22} className="text-indigo-600" />
            <h1 className="text-2xl font-bold text-gray-900">
              Peak Time Management
            </h1>
          </div>
          <p className="text-sm text-gray-500">
            Manage peak time periods for delivery operations
          </p>
        </div>
        <div className="flex items-center gap-2">
          <button
            onClick={() => refetch()}
            disabled={isFetching}
            className="flex items-center gap-2 px-4 py-2 border border-gray-300 rounded-xl text-sm text-gray-600 hover:bg-gray-50 disabled:opacity-50"
          >
            <RefreshCw size={15} className={isFetching ? "animate-spin" : ""} />
            Refresh
          </button>
          <button
            onClick={() => {
              setEditing(null);
              setModalOpen(true);
            }}
            className="flex items-center gap-2 px-5 py-2 bg-indigo-600 text-white rounded-xl text-sm hover:bg-indigo-700"
          >
            <Plus size={16} /> New Peak Time
          </button>
        </div>
      </div>

      <div className="bg-indigo-50 border border-indigo-100 rounded-2xl px-5 py-4 text-center w-40">
        <p className="text-3xl font-bold text-indigo-700">{total}</p>
        <p className="text-xs text-indigo-400 mt-1">Total Peak Times</p>
      </div>

      <TableToolbar
        total={total}
        totalLabel="peak time"
        action={
          <div className="flex items-center gap-2">
            <ColumnToggle
              columns={columnOptions}
              visible={visible}
              onChange={setVisible}
            />
          </div>
        }
      >
        <div className="space-y-1.5">
          <label className="text-xs font-semibold text-gray-600 uppercase">
            Day
          </label>
          <select
            value={day}
            onChange={(e) => {
              setDay(e.target.value);
              setPage(1);
            }}
            className="input"
          >
            <option value="">All Days</option>
            <option value="0">Sunday</option>
            <option value="1">Monday</option>
            <option value="2">Tuesday</option>
            <option value="3">Wednesday</option>
            <option value="4">Thursday</option>
            <option value="5">Friday</option>
            <option value="6">Saturday</option>
          </select>
        </div>
        <div className="space-y-1.5">
          <label className="text-xs font-semibold text-gray-600 uppercase">
            Status
          </label>
          <select
            value={isActive}
            onChange={(e) => {
              setIsActive(e.target.value);
              setPage(1);
            }}
            className="input"
          >
            <option value="">All</option>
            <option value="true">Active</option>
            <option value="false">Inactive</option>
          </select>
        </div>
        <div className="space-y-1.5">
          <label className="text-xs font-semibold text-gray-600 uppercase">
            Start Time From
          </label>
          <input
            type="time"
            value={startTimeFrom}
            onChange={(e) => {
              setStartTimeFrom(e.target.value);
              setPage(1);
            }}
            className="input"
          />
        </div>
        <div className="space-y-1.5">
          <label className="text-xs font-semibold text-gray-600 uppercase">
            Start Time To
          </label>
          <input
            type="time"
            value={startTimeTo}
            onChange={(e) => {
              setStartTimeTo(e.target.value);
              setPage(1);
            }}
            className="input"
          />
        </div>
        <div className="space-y-1.5">
          <label className="text-xs font-semibold text-gray-600 uppercase">
            End Time From
          </label>
          <input
            type="time"
            value={endTimeFrom}
            onChange={(e) => {
              setEndTimeFrom(e.target.value);
              setPage(1);
            }}
            className="input"
          />
        </div>
        <div className="space-y-1.5">
          <label className="text-xs font-semibold text-gray-600 uppercase">
            End Time To
          </label>
          <input
            type="time"
            value={endTimeTo}
            onChange={(e) => {
              setEndTimeTo(e.target.value);
              setPage(1);
            }}
            className="input"
          />
        </div>
        <DateRangeFilter
          label="Created At"
          from={createdFrom}
          to={createdTo}
          onFromChange={(v) => {
            setCreatedFrom(v);
            setPage(1);
          }}
          onToChange={(v) => {
            setCreatedTo(v);
            setPage(1);
          }}
        />
        <DateRangeFilter
          label="Updated At"
          from={updatedFrom}
          to={updatedTo}
          onFromChange={(v) => {
            setUpdatedFrom(v);
            setPage(1);
          }}
          onToChange={(v) => {
            setUpdatedTo(v);
            setPage(1);
          }}
        />
      </TableToolbar>

      <DataTable
        columns={columns}
        rows={allPeakTimes}
        keyExtractor={(pt) => pt.id}
        isLoading={isLoading}
        emptyText="No peak times found"
        emptyIcon={<Clock size={36} className="text-gray-300" />}
      />

      <TablePagination
        page={page}
        totalPages={totalPages}
        total={total}
        limit={10}
        onPageChange={setPage}
      />

      {modalOpen && (
        <PeakTimeModal
          peakTime={editing}
          onClose={() => {
            setModalOpen(false);
            setEditing(null);
          }}
          onSaved={() => {
            setModalOpen(false);
            setEditing(null);
            qc.invalidateQueries({ queryKey: ["peak-times"] });
          }}
        />
      )}
    </div>
  );
}

function PeakTimeModal({
  peakTime,
  onClose,
  onSaved,
}: {
  peakTime: PeakTime | null;
  onClose: () => void;
  onSaved: () => void;
}) {
  const [form, setForm] = useState({
    day: peakTime?.day ?? 0,
    start_time: peakTime?.start_time ?? "",
    end_time: peakTime?.end_time ?? "",
    is_active: peakTime?.is_active ?? false,
  });

  const saveMut = useMutation({
    mutationFn: (d: typeof form) =>
      peakTime ? updatePeakTime(peakTime.id, d) : createPeakTime(d),
    onSuccess: () => {
      toast.success(
        peakTime
          ? "Peak time updated successfully"
          : "Peak time created successfully",
      );
      onSaved();
    },
    onError: () => toast.error("Failed to save peak time"),
  });

  const set = (k: keyof typeof form, v: string | number | boolean) =>
    setForm((p) => ({ ...p, [k]: v }));

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4">
      <div className="bg-white rounded-2xl shadow-2xl w-full max-w-md">
        <div className="flex items-center justify-between px-6 py-5 border-b border-gray-100">
          <h2 className="text-lg font-bold text-gray-900">
            {peakTime ? "Edit Peak Time" : "New Peak Time"}
          </h2>
          <button
            onClick={onClose}
            className="p-2 rounded-xl hover:bg-gray-100 text-gray-400"
          >
            <X size={18} />
          </button>
        </div>
        <form
          onSubmit={(e) => {
            e.preventDefault();
            saveMut.mutate(form);
          }}
          className="px-6 py-5 space-y-4"
        >
          <div className="space-y-1.5">
            <label className="text-xs font-semibold text-gray-600 uppercase">
              Day
            </label>
            <select
              value={form.day}
              onChange={(e) => set("day", Number(e.target.value))}
              className="input"
            >
              <option value={0}>Sunday</option>
              <option value={1}>Monday</option>
              <option value={2}>Tuesday</option>
              <option value={3}>Wednesday</option>
              <option value={4}>Thursday</option>
              <option value={5}>Friday</option>
              <option value={6}>Saturday</option>
            </select>
          </div>
          <div className="space-y-1.5">
            <label className="text-xs font-semibold text-gray-600 uppercase">
              Start Time (24h format)
            </label>
            <input
              required
              type="time"
              value={form.start_time}
              onChange={(e) => set("start_time", e.target.value)}
              className="input"
            />
          </div>
          <div className="space-y-1.5">
            <label className="text-xs font-semibold text-gray-600 uppercase">
              End Time (24h format)
            </label>
            <input
              required
              type="time"
              value={form.end_time}
              onChange={(e) => set("end_time", e.target.value)}
              className="input"
            />
          </div>
          <div className="space-y-1.5">
            <label className="text-xs font-semibold text-gray-600 uppercase">
              Status
            </label>
            <select
              value={form.is_active ? "true" : "false"}
              onChange={(e) => set("is_active", e.target.value === "true")}
              className="input"
            >
              <option value="false">Inactive</option>
              <option value="true">Active</option>
            </select>
          </div>
          <div className="flex justify-end gap-3 pt-2 border-t border-gray-100">
            <button
              type="button"
              onClick={onClose}
              className="px-5 py-2.5 border border-gray-300 rounded-xl text-sm text-gray-700 hover:bg-gray-50"
            >
              Cancel
            </button>
            <button
              type="submit"
              disabled={saveMut.isPending}
              className="px-6 py-2.5 bg-indigo-600 text-white rounded-xl text-sm font-medium hover:bg-indigo-700 disabled:opacity-60"
            >
              {saveMut.isPending ? "Saving..." : peakTime ? "Save" : "Create"}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
