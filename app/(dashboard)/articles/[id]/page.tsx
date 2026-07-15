"use client";
import { useParams, useRouter } from "next/navigation";
import { useQuery } from "@tanstack/react-query";
import { articleService } from "@/services/articleService";
import { useT } from "@/contexts/LanguageContext";
import { ArrowLeft, FileText, Image as ImageIcon, Calendar, User } from "lucide-react";

export default function ArticleDetailsPage() {
  const { t } = useT();
  const params = useParams();
  const router = useRouter();
  const id = Number(params.id);

  const { data, isLoading, isError } = useQuery({
    queryKey: ["articles", id],
    queryFn: async () => {
      const res = await articleService.fetchArticles(1, 1, "id", { id: id.toString() });
      if (!res.articles || res.articles.length === 0) throw new Error("Not found");
      return res.articles[0];
    },
    retry: false,
  });

  if (isLoading) return <div className="p-8 text-center text-gray-500">Loading details...</div>;
  if (isError || !data) return <div className="p-8 text-center text-red-500">Failed to load details or not found.</div>;

  let keywords = "";
  try {
    const parsed = JSON.parse(data.keywords);
    keywords = Array.isArray(parsed) ? parsed.join(", ") : data.keywords;
  } catch (e) {
    keywords = data.keywords;
  }

  return (
    <div className="p-6 max-w-5xl mx-auto space-y-6">
      <button onClick={() => router.back()} className="flex items-center gap-2 text-gray-500 hover:text-indigo-600 transition">
        <ArrowLeft size={18} />
        <span>Back to Articles</span>
      </button>

      <div className="bg-white border border-gray-200 rounded-3xl overflow-hidden shadow-sm">
        {data.cover_image ? (
          <div className="w-full h-64 bg-gray-100 relative">
            <img src={data.cover_image} alt={data.title} className="w-full h-full object-cover" />
            <div className="absolute inset-0 bg-gradient-to-t from-black/60 to-transparent"></div>
            <div className="absolute bottom-6 left-8 right-8">
              <h1 className="text-3xl font-bold text-white mb-2">{data.title}</h1>
              <div className="flex items-center gap-4 text-white/80 text-sm font-medium">
                <div className="flex items-center gap-1.5"><User size={16} /> {data.author}</div>
                <div className="flex items-center gap-1.5"><Calendar size={16} /> {data.published_at ? new Date(data.published_at).toLocaleDateString() : '—'}</div>
              </div>
            </div>
          </div>
        ) : (
          <div className="p-8 border-b border-gray-100 bg-gray-50">
            <h1 className="text-3xl font-bold text-gray-900 mb-4">{data.title}</h1>
            <div className="flex items-center gap-4 text-gray-500 text-sm font-medium">
              <div className="flex items-center gap-1.5"><User size={16} /> {data.author}</div>
              <div className="flex items-center gap-1.5"><Calendar size={16} /> {data.published_at ? new Date(data.published_at).toLocaleDateString() : '—'}</div>
            </div>
          </div>
        )}

        <div className="p-8 space-y-8">
          <div>
            <span className="text-xs font-bold text-indigo-500 uppercase tracking-widest block mb-3">Summary</span>
            <p className="text-xl font-medium text-gray-800 leading-relaxed">
              {data.summary}
            </p>
          </div>

          <div>
            <span className="text-xs font-bold text-gray-400 uppercase tracking-widest block mb-4 border-b border-gray-100 pb-2">Content</span>
            <div 
              className="prose prose-indigo max-w-none prose-headings:font-bold prose-a:text-indigo-600 prose-img:rounded-xl"
              dangerouslySetInnerHTML={{ __html: data.content }}
            />
          </div>

          <div className="pt-6 border-t border-gray-100">
            <span className="text-xs font-bold text-gray-400 uppercase tracking-widest block mb-3">Tags & Keywords</span>
            <div className="flex flex-wrap gap-2">
              {keywords.split(",").filter(Boolean).map((k, i) => (
                <span key={i} className="px-3 py-1.5 bg-gray-100 text-gray-700 text-xs font-semibold rounded-lg border border-gray-200">
                  {k.trim()}
                </span>
              ))}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
