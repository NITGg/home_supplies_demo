"use client";

import { useState, useMemo } from "react";
import { useQuery } from "@tanstack/react-query";
import { fetchUsers, fetchRoles, type User, type Role } from "@/lib/users";
import { useT } from "@/contexts/LanguageContext";
import { BarChart2, PieChart as PieChartIcon, RefreshCw, Users } from "lucide-react";
import { cn } from "@/lib/utils";
import {
  BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, Legend,
  PieChart, Pie, Cell,
} from "recharts";

type Period = "all" | "month" | "week";

const ROLE_COLORS = [
  "#6366f1", "#10b981", "#f59e0b", "#ef4444", "#8b5cf6", "#06b6d4", "#84cc16",
];
const STATUS_COLORS = { active: "#10b981", inactive: "#ef4444", archived: "#94a3b8" };
const GENDER_COLORS = { MALE: "#6366f1", FEMALE: "#f472b6", unknown: "#94a3b8" };

function filterByPeriod(users: User[], period: Period): User[] {
  if (period === "all") return users;
  const now = new Date();
  const cutoff = new Date();
  if (period === "week") cutoff.setDate(now.getDate() - 7);
  else cutoff.setMonth(now.getMonth() - 1);
  return users.filter((u) => new Date(u.created_at) >= cutoff);
}

function PieLabel({ cx, cy, midAngle, outerRadius, percent, name }: any) {
  if (percent < 0.05) return null;
  const RADIAN = Math.PI / 180;
  const x = cx + (outerRadius + 16) * Math.cos(-midAngle * RADIAN);
  const y = cy + (outerRadius + 16) * Math.sin(-midAngle * RADIAN);
  return (
    <text x={x} y={y} fill="#374151" fontSize={11} textAnchor={x > cx ? "start" : "end"} dominantBaseline="central">
      {`${name} (${(percent * 100).toFixed(0)}%)`}
    </text>
  );
}

// ── Shared card wrapper ───────────────────────────────────────────────────────
function ChartCard({ title, children, action }: { title: string; children: React.ReactNode; action?: React.ReactNode }) {
  return (
    <div className="bg-white rounded-xl border border-gray-200 p-5">
      <div className="flex items-center justify-between mb-4">
        <p className="text-sm font-semibold text-gray-800">{title}</p>
        {action}
      </div>
      {children}
    </div>
  );
}

// ── Main component ────────────────────────────────────────────────────────────
export default function UserStatsCharts() {
  const { t } = useT();
  const [period, setPeriod] = useState<Period>("all");

  const { data: usersData, isLoading, refetch, isFetching } = useQuery({
    queryKey: ["users-chart-all"],
    queryFn: () => fetchUsers({ limit: 10000, skip: 0, includes: "role" }),
    staleTime: 5 * 60 * 1000,
  });

  const { data: rolesData } = useQuery({
    queryKey: ["roles"],
    queryFn: fetchRoles,
    staleTime: 10 * 60 * 1000,
  });

  const allUsers: User[] = usersData?.users ?? [];
  const roles: Role[] = rolesData ?? [];
  const filtered = useMemo(() => filterByPeriod(allUsers, period), [allUsers, period]);

  // ── Bar chart: by role ──────────────────────────────────────────────────────
  const roleData = useMemo(() => {
    const map: Record<string, number> = {};
    for (const u of filtered) {
      const name = u.role?.name ?? roles.find((r) => r.id === u.role_id)?.name ?? `Role ${u.role_id}`;
      map[name] = (map[name] ?? 0) + 1;
    }
    return Object.entries(map)
      .map(([name, count]) => ({ name, count }))
      .sort((a, b) => b.count - a.count);
  }, [filtered, roles]);

  // ── Pie chart: by status ───────────────────────────────────────────────────
  const statusData = useMemo(() => {
    const active = filtered.filter((u) => u.is_active && !u.deleted_at).length;
    const inactive = filtered.filter((u) => !u.is_active && !u.deleted_at).length;
    const archived = filtered.filter((u) => !!u.deleted_at).length;
    return [
      { name: t("users.active"), value: active, color: STATUS_COLORS.active },
      { name: t("users.inactive"), value: inactive, color: STATUS_COLORS.inactive },
      { name: t("users.archived"), value: archived, color: STATUS_COLORS.archived },
    ].filter((d) => d.value > 0);
  }, [filtered, t]);

  // ── Pie chart: by gender ───────────────────────────────────────────────────
  const genderData = useMemo(() => {
    const male = filtered.filter((u) => u.gender === "MALE").length;
    const female = filtered.filter((u) => u.gender === "FEMALE").length;
    const unknown = filtered.filter((u) => !u.gender).length;
    return [
      { name: t("filters.male"), value: male, color: GENDER_COLORS.MALE },
      { name: t("filters.female"), value: female, color: GENDER_COLORS.FEMALE },
      { name: "—", value: unknown, color: GENDER_COLORS.unknown },
    ].filter((d) => d.value > 0);
  }, [filtered, t]);

  // ── Bar chart: verification ────────────────────────────────────────────────
  const verifyData = useMemo(() => {
    const emailYes = filtered.filter((u) => u.is_email_verified).length;
    const emailNo = filtered.filter((u) => !u.is_email_verified).length;
    const phoneYes = filtered.filter((u) => u.is_phone_verified).length;
    const phoneNo = filtered.filter((u) => !u.is_phone_verified).length;
    return [
      { name: t("users.emailVerified"), verified: emailYes, unverified: emailNo },
      { name: t("users.phoneVerified"), verified: phoneYes, unverified: phoneNo },
    ];
  }, [filtered, t]);

  const PERIODS: { key: Period; label: string }[] = [
    { key: "all", label: t("users.filterAll") },
    { key: "month", label: t("users.filterMonth") },
    { key: "week", label: t("users.filterWeek") },
  ];

  if (isLoading) {
    return (
      <div className="bg-white rounded-xl border border-gray-200 p-8 flex items-center justify-center gap-3 text-gray-400">
        <RefreshCw size={18} className="animate-spin" />
        <span className="text-sm">Loading analytics…</span>
      </div>
    );
  }

  return (
    <div className="space-y-4">
      {/* Header */}
      <div className="flex items-center justify-between flex-wrap gap-3">
        <div className="flex items-center gap-2">
          <BarChart2 size={20} className="text-indigo-600" />
          <div>
            <h2 className="text-base font-bold text-gray-900">{t("users.chartsTitle")}</h2>
            <p className="text-xs text-gray-500">{t("users.chartsSubtitle")}</p>
          </div>
        </div>
        <div className="flex items-center gap-2">
          {/* Period filter */}
          <div className="flex bg-gray-100 rounded-lg p-0.5 gap-0.5">
            {PERIODS.map(({ key, label }) => (
              <button key={key} onClick={() => setPeriod(key)}
                className={cn("px-3 py-1.5 text-xs font-medium rounded-md transition",
                  period === key ? "bg-white text-indigo-700 shadow-sm" : "text-gray-500 hover:text-gray-700"
                )}>
                {label}
              </button>
            ))}
          </div>
          <button onClick={() => refetch()} disabled={isFetching}
            className="p-2 border border-gray-200 rounded-lg text-gray-500 hover:bg-gray-50 disabled:opacity-50">
            <RefreshCw size={14} className={isFetching ? "animate-spin" : ""} />
          </button>
        </div>
      </div>

      {/* Summary stat strip */}
      <div className="grid grid-cols-2 sm:grid-cols-4 gap-3">
        {[
          { label: t("users.total"), value: filtered.length, color: "text-indigo-600 bg-indigo-50" },
          { label: t("users.active"), value: filtered.filter((u) => u.is_active).length, color: "text-green-600 bg-green-50" },
          { label: t("users.inactive"), value: filtered.filter((u) => !u.is_active).length, color: "text-red-600 bg-red-50" },
          { label: t("users.archived"), value: filtered.filter((u) => !!u.deleted_at).length, color: "text-gray-600 bg-gray-100" },
        ].map(({ label, value, color }) => (
          <div key={label} className="bg-white rounded-xl border border-gray-200 p-4 flex items-center gap-3">
            <div className={cn("w-9 h-9 rounded-lg flex items-center justify-center shrink-0", color)}>
              <Users size={16} />
            </div>
            <div>
              <p className="text-xl font-bold text-gray-900">{value.toLocaleString()}</p>
              <p className="text-xs text-gray-500">{label}</p>
            </div>
          </div>
        ))}
      </div>

      {/* Top row: Bar by role + Pie by status */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
        {/* Bar: by role */}
        <ChartCard title={t("users.byRole")}>
          {roleData.length === 0 ? (
            <p className="text-center text-gray-400 text-sm py-12">No data</p>
          ) : (
            <ResponsiveContainer width="100%" height={220}>
              <BarChart data={roleData} margin={{ top: 4, right: 8, left: -20, bottom: 0 }}>
                <CartesianGrid strokeDasharray="3 3" stroke="#f3f4f6" />
                <XAxis dataKey="name" tick={{ fontSize: 12, fill: "#6b7280" }} />
                <YAxis tick={{ fontSize: 11, fill: "#9ca3af" }} allowDecimals={false} />
                <Tooltip
                  contentStyle={{ borderRadius: 8, border: "1px solid #e5e7eb", fontSize: 12 }}
                />
                <Bar dataKey="count" radius={[4, 4, 0, 0]} maxBarSize={48}>
                  {roleData.map((_, i) => (
                    <Cell key={i} fill={ROLE_COLORS[i % ROLE_COLORS.length]} />
                  ))}
                </Bar>
              </BarChart>
            </ResponsiveContainer>
          )}
        </ChartCard>

        {/* Pie: by status */}
        <ChartCard title={t("users.byStatus")}>
          {statusData.length === 0 ? (
            <p className="text-center text-gray-400 text-sm py-12">No data</p>
          ) : (
            <ResponsiveContainer width="100%" height={230}>
              <PieChart>
                <Pie data={statusData} cx="50%" cy="50%" outerRadius={80}
                  dataKey="value" labelLine={false} label={PieLabel}>
                  {statusData.map((entry, i) => (
                    <Cell key={i} fill={entry.color} />
                  ))}
                </Pie>
                <Tooltip contentStyle={{ borderRadius: 8, border: "1px solid #e5e7eb", fontSize: 12 }} />
                <Legend iconType="circle" iconSize={8}
                  formatter={(v) => <span className="text-xs text-gray-600">{v}</span>} />
              </PieChart>
            </ResponsiveContainer>
          )}
        </ChartCard>
      </div>

      {/* Bottom row: Pie by gender + Bar verification */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
        {/* Pie: by gender */}
        <ChartCard title={t("users.byGender")}>
          {genderData.length === 0 ? (
            <p className="text-center text-gray-400 text-sm py-12">No data</p>
          ) : (
            <ResponsiveContainer width="100%" height={230}>
              <PieChart>
                <Pie data={genderData} cx="50%" cy="50%" outerRadius={80}
                  dataKey="value" labelLine={false} label={PieLabel}>
                  {genderData.map((entry, i) => (
                    <Cell key={i} fill={entry.color} />
                  ))}
                </Pie>
                <Tooltip contentStyle={{ borderRadius: 8, border: "1px solid #e5e7eb", fontSize: 12 }} />
                <Legend iconType="circle" iconSize={8}
                  formatter={(v) => <span className="text-xs text-gray-600">{v}</span>} />
              </PieChart>
            </ResponsiveContainer>
          )}
        </ChartCard>

        {/* Bar: verification */}
        <ChartCard title={t("users.byVerification")}>
          <ResponsiveContainer width="100%" height={220}>
            <BarChart data={verifyData} margin={{ top: 4, right: 8, left: -20, bottom: 0 }}>
              <CartesianGrid strokeDasharray="3 3" stroke="#f3f4f6" />
              <XAxis dataKey="name" tick={{ fontSize: 11, fill: "#6b7280" }} />
              <YAxis tick={{ fontSize: 11, fill: "#9ca3af" }} allowDecimals={false} />
              <Tooltip
                contentStyle={{ borderRadius: 8, border: "1px solid #e5e7eb", fontSize: 12 }}
              />
              <Legend iconType="circle" iconSize={8}
                formatter={(v) => <span className="text-xs text-gray-600">{v === "verified" ? "✓ Verified" : "✗ Unverified"}</span>} />
              <Bar dataKey="verified" fill="#10b981" radius={[4, 4, 0, 0]} maxBarSize={36} />
              <Bar dataKey="unverified" fill="#f59e0b" radius={[4, 4, 0, 0]} maxBarSize={36} />
            </BarChart>
          </ResponsiveContainer>
        </ChartCard>
      </div>
    </div>
  );
}
