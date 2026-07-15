"use client";
import { useParams, useRouter } from "next/navigation";
import { useQuery } from "@tanstack/react-query";
import { onBoardingService } from "@/services/onBoardingService";
import { useT } from "@/contexts/LanguageContext";
import { ArrowLeft, Smartphone, FileText, Image as ImageIcon } from "lucide-react";
import toast from "react-hot-toast";

export default function OnboardingDetailsPage() {
  const { t } = useT();
  const params = useParams();
  const router = useRouter();
  const id = Number(params.id);

  const { data, isLoading, isError } = useQuery({
    queryKey: ["onboarding", id],
    queryFn: async () => {
      const res = await onBoardingService.fetchOnBoardingItems(1, 1, "id", { id: id.toString() });
      if (!res.items || res.items.length === 0) throw new Error("Not found");
      return res.items[0];
    },
    retry: false,
  });

  if (isLoading) return <div className="p-8 text-center text-gray-500">Loading details...</div>;
  if (isError || !data) return <div className="p-8 text-center text-red-500">Failed to load details or not found.</div>;

  return (
    <div className="p-6 max-w-4xl mx-auto space-y-6">
      <button onClick={() => router.back()} className="flex items-center gap-2 text-gray-500 hover:text-indigo-600 transition">
        <ArrowLeft size={18} />
        <span>Back to Onboarding</span>
      </button>

      <div className="bg-white border border-gray-200 rounded-2xl p-8 shadow-sm">
        <div className="flex items-center gap-4 mb-6 pb-6 border-b border-gray-100">
          <div className="w-16 h-16 rounded-2xl bg-indigo-50 flex items-center justify-center text-indigo-600 shrink-0">
            {data.image_url ? <img src={data.image_url} alt={data.title} className="w-full h-full object-cover rounded-2xl" /> : <ImageIcon size={32} />}
          </div>
          <div>
            <h1 className="text-2xl font-bold text-gray-900">{data.title}</h1>
            <p className="text-gray-500">{data.subtitle}</p>
          </div>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 gap-8">
          <div className="space-y-4">
            <h3 className="text-lg font-semibold text-gray-900">English Content</h3>
            <div className="space-y-3">
              <div><span className="text-xs font-bold text-gray-400 uppercase tracking-widest">Title</span><p className="font-medium text-gray-900 mt-1">{data.title}</p></div>
              <div><span className="text-xs font-bold text-gray-400 uppercase tracking-widest">Subtitle</span><p className="text-gray-700 mt-1">{data.subtitle}</p></div>
              <div><span className="text-xs font-bold text-gray-400 uppercase tracking-widest">Content</span><p className="text-gray-700 bg-gray-50 p-4 rounded-xl mt-2 leading-relaxed border border-gray-100">{data.content}</p></div>
            </div>
          </div>

          <div className="space-y-4" dir="rtl">
            <h3 className="text-lg font-semibold text-gray-900">المحتوى العربي</h3>
            <div className="space-y-3">
              <div><span className="text-xs font-bold text-gray-400 uppercase tracking-widest block font-sans">العنوان</span><p className="font-medium text-gray-900 mt-1">{data.title_ar}</p></div>
              <div><span className="text-xs font-bold text-gray-400 uppercase tracking-widest block font-sans">العنوان الفرعي</span><p className="text-gray-700 mt-1">{data.subtitle_ar}</p></div>
              <div><span className="text-xs font-bold text-gray-400 uppercase tracking-widest block font-sans">المحتوى</span><p className="text-gray-700 bg-gray-50 p-4 rounded-xl mt-2 leading-relaxed border border-gray-100">{data.content_ar}</p></div>
            </div>
          </div>
        </div>

        <div className="mt-8 pt-6 border-t border-gray-100 grid grid-cols-1 sm:grid-cols-2 gap-6">
          <div>
            <span className="text-xs font-bold text-gray-400 uppercase tracking-widest block mb-1">Target User</span>
            <span className="inline-flex items-center px-2.5 py-1 rounded-md bg-indigo-50 text-indigo-700 text-xs font-semibold">
              {data.target_user}
            </span>
          </div>
          <div>
            <span className="text-xs font-bold text-gray-400 uppercase tracking-widest block mb-1">Sort Order</span>
            <p className="font-medium text-gray-900">{data.sort_id}</p>
          </div>
        </div>
      </div>
    </div>
  );
}
