"use client";
import React from "react";
import { useQuery } from "@tanstack/react-query";
import { fetchPeakTimeDetails, type PeakTime } from "@/lib/peak-time";
import { useT } from "@/contexts/LanguageContext";
import { Clock, ArrowLeft, Calendar, Clock as TimeIcon, CheckCircle, XCircle } from "lucide-react";
import { useRouter } from "next/navigation";
import { Button } from "@/components/ui/button";

const DAY_LABELS: Record<number, string> = {
  0: "Sunday",
  1: "Monday",
  2: "Tuesday",
  3: "Wednesday",
  4: "Thursday",
  5: "Friday",
  6: "Saturday",
};

export default function PeakTimeDetailsPage({ params }: { params: Promise<{ id: string }> }) {
  const { t } = useT();
  const router = useRouter();
  const { id } = React.use(params);

  const { data: peakTime, isLoading, error } = useQuery({
    queryKey: ["peak-time-details", id],
    queryFn: () => fetchPeakTimeDetails(Number(id)),
    enabled: !!id,
  });

  if (isLoading) {
    return (
      <div className="p-6">
        <div className="animate-pulse space-y-4">
          <div className="h-8 bg-gray-200 rounded w-1/3" />
          <div className="h-4 bg-gray-200 rounded w-1/2" />
          <div className="h-32 bg-gray-200 rounded" />
        </div>
      </div>
    );
  }

  if (error || !peakTime) {
    return (
      <div className="p-6">
        <div className="bg-red-50 border border-red-200 rounded-xl p-6 text-center">
          <div className="flex items-center justify-center mb-4">
            <XCircle size={24} className="text-red-500" />
          </div>
          <h2 className="text-lg font-semibold text-red-700 mb-2">Failed to load peak time details</h2>
          <p className="text-red-600 mb-4">The requested peak time could not be found or an error occurred.</p>
          <button 
            onClick={() => router.back()} 
            className="px-4 py-2 bg-indigo-600 text-white rounded-lg hover:bg-indigo-700"
          >
            Go Back
          </button>
        </div>
      </div>
    );
  }

  return (
    <div className="p-6 space-y-6">
      <div className="flex items-center gap-4">
        <button
          onClick={() => router.back()}
          className="p-2 rounded-lg hover:bg-gray-100 text-gray-600"
        >
          <ArrowLeft size={20} />
        </button>
        <div>
          <div className="flex items-center gap-2 mb-1">
            <Clock size={22} className="text-indigo-600" />
            <h1 className="text-2xl font-bold text-gray-900">Peak Time Details</h1>
          </div>
          <p className="text-sm text-gray-500">View peak time information</p>
        </div>
      </div>

      <div className="bg-white rounded-2xl border border-gray-200 shadow-sm overflow-hidden">
        <div className="grid grid-cols-1 md:grid-cols-2 gap-6 p-6">
          <DetailItem
            icon={<Calendar size={18} className="text-indigo-600" />}
            label="Day"
            value={DAY_LABELS[peakTime.day] ?? `Day ${peakTime.day}`}
          />
          <DetailItem
            icon={<TimeIcon size={18} className="text-indigo-600" />}
            label="Start Time"
            value={peakTime.start_time}
          />
          <DetailItem
            icon={<TimeIcon size={18} className="text-indigo-600" />}
            label="End Time"
            value={peakTime.end_time}
          />
          <DetailItem
            icon={peakTime.is_active ? <CheckCircle size={18} className="text-green-600" /> : <XCircle size={18} className="text-red-600" />}
            label="Status"
            value={peakTime.is_active ? "Active" : "Inactive"}
            valueClassName={peakTime.is_active ? "text-green-700" : "text-red-700"}
          />
          <DetailItem
            icon={<Calendar size={18} className="text-indigo-600" />}
            label="Created At"
            value={new Date(peakTime.created_at).toLocaleString(undefined, {
              year: "numeric",
              month: "short",
              day: "numeric",
              hour: "2-digit",
              minute: "2-digit",
            })}
          />
          <DetailItem
            icon={<Calendar size={18} className="text-indigo-600" />}
            label="Updated At"
            value={new Date(peakTime.updated_at).toLocaleString(undefined, {
              year: "numeric",
              month: "short",
              day: "numeric",
              hour: "2-digit",
              minute: "2-digit",
            })}
          />
        </div>
      </div>

      <div className="flex justify-end gap-3">
        <Button
          variant="outline"
          onClick={() => router.push(`/peak-time`)}
        >
          Back to List
        </Button>
        <Button
          onClick={() => router.push(`/peak-time?edit=${id}`)}
          className="bg-indigo-600 hover:bg-indigo-700"
        >
          Edit Peak Time
        </Button>
      </div>
    </div>
  );
}

function DetailItem({
  icon,
  label,
  value,
  valueClassName = "text-gray-900",
}: {
  icon: React.ReactNode;
  label: string;
  value: string;
  valueClassName?: string;
}) {
  return (
    <div className="flex items-start gap-3">
      <div className="p-2 rounded-lg bg-indigo-50 text-indigo-600 shrink-0">
        {icon}
      </div>
      <div className="flex-1 min-w-0">
        <p className="text-xs font-semibold text-gray-500 uppercase mb-1">{label}</p>
        <p className={`text-sm font-medium ${valueClassName}`}>{value}</p>
      </div>
    </div>
  );
}
