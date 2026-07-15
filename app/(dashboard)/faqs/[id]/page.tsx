"use client";
import { useParams, useRouter } from "next/navigation";
import { useQuery } from "@tanstack/react-query";
import { faqService } from "@/services/faqService";
import { useT } from "@/contexts/LanguageContext";
import { ArrowLeft, HelpCircle } from "lucide-react";

export default function FaqDetailsPage() {
  const { t } = useT();
  const params = useParams();
  const router = useRouter();
  const id = Number(params.id);

  const { data, isLoading, isError } = useQuery({
    queryKey: ["faqs", id],
    queryFn: async () => {
      const res = await faqService.fetchFaqs(1, 1, "id", { id: id.toString() });
      if (!res.faqs || res.faqs.length === 0) throw new Error("Not found");
      return res.faqs[0];
    },
    retry: false,
  });

  if (isLoading) return <div className="p-8 text-center text-gray-500">Loading details...</div>;
  if (isError || !data) return <div className="p-8 text-center text-red-500">Failed to load details or not found.</div>;

  return (
    <div className="p-6 max-w-3xl mx-auto space-y-6">
      <button onClick={() => router.back()} className="flex items-center gap-2 text-gray-500 hover:text-indigo-600 transition">
        <ArrowLeft size={18} />
        <span>Back to FAQs</span>
      </button>

      <div className="bg-white border border-gray-200 rounded-2xl p-8 shadow-sm">
        <div className="flex items-center gap-4 mb-6 pb-6 border-b border-gray-100">
          <div className="w-14 h-14 rounded-2xl bg-indigo-50 flex items-center justify-center text-indigo-600 shrink-0">
            <HelpCircle size={28} />
          </div>
          <div>
            <h1 className="text-xl font-bold text-gray-900 leading-snug">{data.question}</h1>
            <p className="text-sm text-gray-500 mt-1">Language: <span className="font-medium text-gray-700">{data.language}</span></p>
          </div>
        </div>

        <div className="space-y-4">
          <div>
            <span className="text-xs font-bold text-gray-400 uppercase tracking-widest">Answer</span>
            <div className="mt-2 text-gray-700 bg-gray-50 p-5 rounded-xl border border-gray-100 leading-relaxed whitespace-pre-wrap">
              {data.answer}
            </div>
          </div>
        </div>

        <div className="mt-8 pt-6 border-t border-gray-100 grid grid-cols-1 sm:grid-cols-3 gap-6">
          <div>
            <span className="text-xs font-bold text-gray-400 uppercase tracking-widest block mb-1">Target User</span>
            <span className="inline-flex items-center px-2.5 py-1 rounded-md bg-indigo-50 text-indigo-700 text-xs font-semibold">
              {data.target_user}
            </span>
          </div>
          <div>
            <span className="text-xs font-bold text-gray-400 uppercase tracking-widest block mb-1">Status</span>
            <span className={`inline-flex items-center px-2.5 py-1 rounded-md text-xs font-semibold ${data.is_active ? 'bg-green-50 text-green-700' : 'bg-gray-100 text-gray-600'}`}>
              {data.is_active ? 'Active' : 'Inactive'}
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
