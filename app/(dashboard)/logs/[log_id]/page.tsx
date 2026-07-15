"use client";

import { useQuery } from "@tanstack/react-query";
import { useParams, useRouter } from "next/navigation";
import axiosInstance from "@/lib/axios";
import { LogEntry } from "@/types/logs.types";
import { ArrowLeft, Database, Globe, User, Clock } from "lucide-react";
import { getStatusColor, getMethodColor } from "@/lib/logs.helpers";

export default function LogDetailPage() {
  const { log_id } = useParams();
  const router = useRouter();

  const { data: log, isLoading } = useQuery({
    queryKey: ["logs", log_id],
    queryFn: async () => {
      const { data: { log } } = await axiosInstance.get<{log: LogEntry}>(`/logs/${log_id}`);
      return log;
    },
  });

  if (isLoading) return <div className="p-10 text-center text-gray-500">Loading details...</div>;
  if (!log) return <div className="p-10 text-center text-red-500">Log not found.</div>;

  return (
    <div className="p-6 max-w-5xl mx-auto space-y-6">
      {/* Navigation Header */}
      <div className="flex items-center gap-4">
        <button 
          onClick={() => router.back()}
          className="p-2 hover:bg-gray-100 rounded-full transition"
        >
          <ArrowLeft size={20} />
        </button>
        <div>
          <h1 className="text-2xl font-bold">Log Details</h1>
          <p className="text-sm text-gray-500">Log ID: #{log.id}</p>
        </div>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        {/* Basic Info Card */}
        <div className="md:col-span-2 space-y-6">
          <section className="bg-white border rounded-xl p-6 shadow-sm">
            <h2 className="text-sm font-semibold text-gray-400 uppercase tracking-wider mb-4 flex items-center gap-2">
              <Globe size={14} /> Request Information
            </h2>
            <div className="grid grid-cols-2 gap-y-4 text-sm">
              <div>
                <p className="text-gray-500">Method</p>
                <span className={`font-mono font-bold px-2 py-0.5 rounded ${getMethodColor(log.method)}`}>
                  {log.method}
                </span>
              </div>
              <div>
                <p className="text-gray-500">Status</p>
                <span className={`font-bold px-2 py-0.5 rounded ${getStatusColor(log.status_code)}`}>
                  {log.status_code}
                </span>
              </div>
              <div className="col-span-2">
                <p className="text-gray-500">Path</p>
                <p className="font-mono bg-gray-50 p-2 rounded mt-1 border">{log.path}</p>
              </div>
            </div>
          </section>

          {/* JSON Data Sections */}
          <JsonBlock title="Query Parameters" data={log.query} />
          <JsonBlock title="Request Body" data={log.body} />
        </div>

        {/* Sidebar Info */}
        <div className="space-y-6">
          <section className="bg-white border rounded-xl p-6 shadow-sm space-y-4">
            <h2 className="text-sm font-semibold text-gray-400 uppercase tracking-wider flex items-center gap-2">
              <Clock size={14} /> Meta
            </h2>
            <div>
              <p className="text-xs text-gray-500">Timestamp</p>
              <p className="text-sm">{new Date(log.created_at).toLocaleString()}</p>
            </div>
            <div>
              <p className="text-xs text-gray-500">Duration</p>
              <p className="text-sm font-mono">{log.duration}ms</p>
            </div>
            <div>
              <p className="text-xs text-gray-500">IP Address</p>
              <p className="text-sm font-mono">{log.ip ?? "Unknown"}</p>
            </div>
            <hr />
            <h2 className="text-sm font-semibold text-gray-400 uppercase tracking-wider flex items-center gap-2 pt-2">
              <User size={14} /> User Context
            </h2>
            <p className="text-sm">
              {log.user ? `${log.user.full_name} (#${log.user.id})` : "Guest / System"}
            </p>
          </section>
        </div>
      </div>
    </div>
  );
}

// Reusable component for JSON display
function JsonBlock({ title, data }: Readonly<{ title: string; data: any }>) {
  if (!data || Object.keys(data).length === 0) return null;

  return (
    <section className="bg-white border rounded-xl p-6 shadow-sm overflow-hidden">
      <h2 className="text-sm font-semibold text-gray-400 uppercase tracking-wider mb-4 flex items-center gap-2">
        <Database size={14} /> {title}
      </h2>
      <pre className="text-xs bg-gray-900 text-green-400 p-4 rounded-lg overflow-x-auto font-mono leading-relaxed">
        {JSON.stringify(data, null, 2)}
      </pre>
    </section>
  );
}