"use client";
import { useState } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import api from "@/lib/api";
import { fetchCourierOffices } from "@/lib/courier-offices";
import { useRole } from "@/hooks/useRole";
import {
  Building2,
  Phone,
  Mail,
  MapPin,
  Globe,
  Pencil,
  Loader2,
  Check,
  Percent,
  Coins,
} from "lucide-react";
import toast from "react-hot-toast";

export default function OfficeProfilePage() {
  const { user } = useRole();
  const qc = useQueryClient();
  const [editing, setEditing] = useState(false);
  const [form, setForm] = useState<Record<string, string>>({});

  const { data: officesData, isLoading } = useQuery({
    queryKey: ["my-office", user?.id],
    queryFn: () =>
      fetchCourierOffices({ includes: "couriers", limit: 100 } as any),
    enabled: !!user?.id,
    staleTime: 5 * 60 * 1000,
  });

  const office =
    officesData?.couriers?.find((o: any) =>
      (o.couriers as any[])?.some((c: any) => c.user_id === user?.id),
    ) ?? null;

  const updateMut = useMutation({
    mutationFn: async (data: Record<string, string>) => {
      if (!office?.id) throw new Error("Office context missing");
      await api.put(
        `/admin/courier-office/update-courier-office/${office.id}`,
        data,
      );
    },
    onSuccess: () => {
      toast.success("Office profile updated");
      qc.invalidateQueries({ queryKey: ["my-office"] });
      setEditing(false);
    },
    onError: (e: any) =>
      toast.error(e?.response?.data?.message ?? "Update failed"),
  });

  if (isLoading) {
    return (
      <div className="flex items-center justify-center min-h-100">
        <Loader2 className="animate-spin text-indigo-600" size={32} />
      </div>
    );
  }

  if (!office) return null;

  const startEdit = () => {
    setForm({
      name: office.name ?? "",
      phone: office.phone ?? "",
      email: office.email ?? "",
      address: office.address ?? "",
      website: office.website ?? "",
      description: office.description ?? "",
    });
    setEditing(true);
  };

  const fields = [
    { label: "Office Name", key: "name", icon: Building2 },
    { label: "Phone", key: "phone", icon: Phone },
    { label: "Email", key: "email", icon: Mail },
    { label: "Address", key: "address", icon: MapPin },
    { label: "Website", key: "website", icon: Globe },
    {
      label: "Description",
      key: "description",
      icon: Building2,
      multiline: true,
    },
  ];

  const formatCommissionType = (type: string) => {
    if (type === "FIXED_PER_ORDER") return "Fixed Rate (Per Order)";
    if (type === "PERCENTAGE") return "Percentage Split (%)";
    return type || "—";
  };

  // ── Updated Value Formatter ───────────────────────────────────────────
  const formatCommissionValue = (value: any, type: string) => {
    const numValue = Number(value);
    if (isNaN(numValue) || numValue === 0) return "0.00";

    if (type === "PERCENTAGE") {
      return `${numValue}%`;
    }

    // If it's FIXED_PER_ORDER or anything else, treat input as cents and convert to EGP
    return `${(numValue / 100).toFixed(2)} EGP`;
  };

  return (
    <div className="p-6 space-y-6">
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-3">
          <Building2 size={20} className="text-indigo-600" />
          <h1 className="text-xl font-bold text-gray-900">Office Profile</h1>
        </div>
        {!editing ? (
          <button
            onClick={startEdit}
            className="flex items-center gap-2 px-4 py-2 bg-indigo-600 text-white rounded-xl text-sm font-medium hover:bg-indigo-700"
          >
            <Pencil size={14} /> Edit
          </button>
        ) : (
          <div className="flex gap-2">
            <button
              onClick={() => setEditing(false)}
              className="px-4 py-2 border border-gray-200 rounded-xl text-sm hover:bg-gray-50"
            >
              Cancel
            </button>
            <button
              onClick={() => updateMut.mutate(form)}
              disabled={updateMut.isPending}
              className="flex items-center gap-2 px-4 py-2 bg-indigo-600 text-white rounded-xl text-sm hover:bg-indigo-700 disabled:opacity-60"
            >
              {updateMut.isPending ? (
                <Loader2 size={14} className="animate-spin" />
              ) : (
                <Check size={14} />
              )}
              Save
            </button>
          </div>
        )}
      </div>

      <div className="bg-white rounded-xl border border-gray-200 p-6">
        <div className="flex items-center gap-4 mb-6 pb-6 border-b border-gray-100">
          <div className="w-16 h-16 rounded-2xl bg-indigo-100 flex items-center justify-center text-indigo-600">
            <Building2 size={28} />
          </div>
          <div>
            <h2 className="text-xl font-bold text-gray-900">{office.name}</h2>
            <p className="text-sm text-gray-500">
              {office.address ?? "No address set"}
            </p>
            <p className="text-xs text-gray-400 mt-0.5">
              Office ID: #{office.id}
            </p>
          </div>
        </div>

        {/* Info Fields Grid */}
        <div className="grid grid-cols-1 md:grid-cols-2 gap-5">
          {fields.map(({ label, key, icon: Icon, multiline }) => (
            <div key={key} className={multiline ? "md:col-span-2" : ""}>
              <div className="flex items-start gap-3">
                <div className="w-9 h-9 rounded-lg bg-gray-100 flex items-center justify-center shrink-0 mt-0.5">
                  <Icon size={15} className="text-gray-600" />
                </div>
                <div className="flex-1">
                  <p className="text-xs text-gray-500 uppercase tracking-wide">
                    {label}
                  </p>
                  {editing ? (
                    multiline ? (
                      <textarea
                        value={form[key] ?? ""}
                        rows={3}
                        onChange={(e) =>
                          setForm((f) => ({ ...f, [key]: e.target.value }))
                        }
                        className="mt-0.5 w-full border border-gray-200 rounded-lg px-3 py-2 text-sm outline-none focus:ring-2 focus:ring-indigo-500 resize-none"
                      />
                    ) : (
                      <input
                        value={form[key] ?? ""}
                        onChange={(e) =>
                          setForm((f) => ({ ...f, [key]: e.target.value }))
                        }
                        className="mt-0.5 w-full border border-gray-200 rounded-lg px-3 py-2 text-sm outline-none focus:ring-2 focus:ring-indigo-500"
                      />
                    )
                  ) : (
                    <p className="text-sm font-medium text-gray-900 mt-0.5">
                      {(office as any)[key] || "—"}
                    </p>
                  )}
                </div>
              </div>
            </div>
          ))}

          {/* ── Read-Only Commission Plan Section ───────────────── */}
          <div className="md:col-span-2 border-t border-gray-100 pt-5 mt-2">
            <h3 className="text-sm font-semibold text-gray-900 mb-4">
              Financial Configuration
            </h3>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-5">
              {/* Commission Type */}
              <div className="flex items-start gap-3 bg-gray-50/50 p-3 rounded-xl border border-gray-100">
                <div className="w-9 h-9 rounded-lg bg-gray-100 flex items-center justify-center shrink-0">
                  <Percent size={15} className="text-gray-500" />
                </div>
                <div>
                  <p className="text-xs text-gray-500 uppercase tracking-wide">
                    Commission Ruleset
                  </p>
                  <p className="text-sm font-semibold text-gray-800 mt-0.5">
                    {formatCommissionType(office.commission_type)}
                  </p>
                  <span className="text-[10px] text-amber-600 bg-amber-50 px-1.5 py-0.5 rounded mt-1 inline-block border border-amber-100">
                    Locked — Admin View Only
                  </span>
                </div>
              </div>

              {/* Commission Value */}
              <div className="flex items-start gap-3 bg-gray-50/50 p-3 rounded-xl border border-gray-100">
                <div className="w-9 h-9 rounded-lg bg-gray-100 flex items-center justify-center shrink-0">
                  <Coins size={15} className="text-gray-500" />
                </div>
                <div>
                  <p className="text-xs text-gray-500 uppercase tracking-wide">
                    Settlement Valuation
                  </p>
                  <p className="text-sm font-bold text-indigo-700 mt-0.5">
                    {formatCommissionValue(
                      office.commission_value,
                      office.commission_type,
                    )}
                  </p>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
