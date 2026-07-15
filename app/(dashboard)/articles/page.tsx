"use client";
import { useState, useRef } from "react";
import { useRouter } from "next/navigation";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { articleService } from "@/services/articleService";
import type { ArticleItem, ArticleFilter } from "@/types/article";
import { useT } from "@/contexts/LanguageContext";
import RichTextEditor from "@/components/ui/rich-text-editor";
import { ALLOWED_IMAGE_ACCEPT, validateImageFile } from "@/lib/file-upload";
import { FileText, Plus, Pencil, Trash2, RefreshCw, X, Upload, CheckCircle, XCircle } from "lucide-react";
import { DataTable, type Column } from "@/components/ui/DataTable";
import { TableToolbar } from "@/components/ui/TableToolbar";
import { TablePagination } from "@/components/ui/TablePagination";
import { DateRangeFilter } from "@/components/ui/DateRangeFilter";
import { ColumnToggle, type ColumnOption } from "@/components/ui/ColumnToggle";
import { useColumnVisibility } from "@/hooks/useColumnVisibility";
import toast from "react-hot-toast";

function fmtDate(d?: string | null) { return d ? new Date(d).toLocaleDateString("en-GB", { day: "2-digit", month: "short", year: "numeric" }) : "—"; }

const ALL_COLUMN_KEYS = ["cover_image", "title", "author", "published_at", "created_at", "updated_at", "actions"] as const;

export default function ArticlesPage() {
  const { t } = useT();
  const router = useRouter();
  const qc = useQueryClient();
  const [page, setPage] = useState(1);
  const [search, setSearch] = useState("");
  const [createdFrom, setCreatedFrom] = useState("");
  const [createdTo, setCreatedTo] = useState("");
  const [updatedFrom, setUpdatedFrom] = useState("");
  const [updatedTo, setUpdatedTo] = useState("");
  const [delConfirm, setDelConfirm] = useState<number | null>(null);
  const [modalOpen, setModalOpen] = useState(false);
  const [editing, setEditing] = useState<ArticleItem | null>(null);

  const { visible, setVisible } = useColumnVisibility("cols:articles", [...ALL_COLUMN_KEYS]);

  const filters: Partial<ArticleFilter> = {};
  if (search) filters.title = search;
  if (createdFrom) filters.created_from = createdFrom;
  if (createdTo) filters.created_to = createdTo;
  if (updatedFrom) filters.updated_from = updatedFrom;
  if (updatedTo) filters.updated_to = updatedTo;

  const { data, isLoading, refetch, isFetching } = useQuery({
    queryKey: ["articles", page, 12, "id", filters],
    queryFn: () => articleService.fetchArticles(page, 12, "id", filters),
  });

  const allArticles = data?.articles ?? [];
  const articles = allArticles.filter(a => {
    if (createdFrom && new Date(a.created_at) < new Date(createdFrom)) return false;
    if (createdTo   && new Date(a.created_at) > new Date(createdTo + "T23:59:59")) return false;
    if (updatedFrom && new Date(a.updated_at) < new Date(updatedFrom)) return false;
    if (updatedTo   && new Date(a.updated_at) > new Date(updatedTo + "T23:59:59")) return false;
    return true;
  });

  const total = data?.totalArticles ?? 0;
  const totalPages = data?.totalPages ?? 1;
  const displayTotal = (createdFrom || createdTo || updatedFrom || updatedTo) ? articles.length : total;

  const deleteMut = useMutation({
    mutationFn: (id: number) => articleService.deleteArticle(id),
    onSuccess: () => { toast.success(t("articles.deleted")); qc.invalidateQueries({ queryKey: ["articles"] }); setDelConfirm(null); },
    onError: () => toast.error(t("articles.deleteError")),
  });

  const allColumns: Column<ArticleItem>[] = [
    {
      key: "cover_image",
      label: "Cover",
      render: a => a.cover_image
        ? <img src={a.cover_image} alt={a.title} className="w-14 h-10 rounded-lg object-cover" />
        : <div className="w-14 h-10 rounded-lg bg-gray-100 flex items-center justify-center"><FileText size={16} className="text-gray-400" /></div>,
    },
    {
      key: "title",
      label: t("articles.titleLabel"),
      sortable: true,
      getValue: a => a.title,
      render: a => (
        <div>
          <p className="font-medium text-gray-900">{a.title}</p>
          <p className="text-xs text-gray-400 font-mono">{a.slug}</p>
        </div>
      ),
    },
    {
      key: "author",
      label: t("articles.author"),
      sortable: true,
      getValue: a => a.author,
      render: a => <span className="text-gray-600">{a.author}</span>,
    },
    {
      key: "published_at",
      label: t("articles.publishedAt"),
      sortable: true,
      getValue: a => a.published_at ? new Date(a.published_at) : undefined,
      render: a => <span className="text-gray-500 text-xs">{fmtDate(a.published_at)}</span>,
    },

    {
      key: "created_at",
      label: t("common.createdAt"),
      sortable: true,
      getValue: a => new Date(a.created_at),
      render: a => (
        <span className="text-xs text-gray-500">
          {new Date(a.created_at).toLocaleDateString(undefined, { year: "numeric", month: "short", day: "numeric" })}
        </span>
      ),
    },
    {
      key: "updated_at",
      label: t("common.updatedAt"),
      sortable: true,
      getValue: a => new Date(a.updated_at),
      render: a => (
        <span className="text-xs text-gray-500">
          {new Date(a.updated_at).toLocaleDateString(undefined, { year: "numeric", month: "short", day: "numeric" })}
        </span>
      ),
    },
    {
      key: "actions",
      label: t("common.actions"),
      align: "right",
      render: a => (
        <div className="flex items-center justify-end gap-2">
          {delConfirm === a.id ? (
            <>
              <span className="text-xs text-gray-600">Delete?</span>
              <button onClick={() => deleteMut.mutate(a.id)} disabled={deleteMut.isPending} className="px-3 py-1.5 text-xs bg-red-600 text-white rounded-lg disabled:opacity-50">{t("common.yes")}</button>
              <button onClick={() => setDelConfirm(null)} className="px-3 py-1.5 text-xs border border-gray-300 rounded-lg">{t("common.cancel")}</button>
            </>
          ) : (
            <>
              <button onClick={() => { setEditing(a); setModalOpen(true); }} className="p-2 rounded-lg text-gray-400 hover:text-indigo-600 hover:bg-indigo-50"><Pencil size={15} /></button>
              <button onClick={() => setDelConfirm(a.id)} className="p-2 rounded-lg text-gray-400 hover:text-red-600 hover:bg-red-50"><Trash2 size={15} /></button>
            </>
          )}
        </div>
      ),
    },
  ];

  const columns = allColumns.filter(c => visible.includes(c.key));
  const columnOptions: ColumnOption[] = allColumns.map(c => ({ key: c.key, label: c.label, alwaysVisible: c.key === "actions" }));

  return (
    <div className="p-6 space-y-6">
      <div className="flex items-start justify-between flex-wrap gap-3">
        <div>
          <div className="flex items-center gap-2 mb-1">
            <FileText size={22} className="text-indigo-600" />
            <h1 className="text-2xl font-bold text-gray-900">{t("articles.title")}</h1>
          </div>
          <p className="text-sm text-gray-500">{t("articles.subtitle")}</p>
        </div>
        <div className="flex gap-2">
          <button onClick={() => refetch()} disabled={isFetching} className="flex items-center gap-2 px-4 py-2 border border-gray-300 rounded-xl text-sm text-gray-600 hover:bg-gray-50 disabled:opacity-50">
            <RefreshCw size={15} className={isFetching ? "animate-spin" : ""} /> {t("common.refresh")}
          </button>
        </div>
      </div>

      <div className="bg-indigo-50 border border-indigo-100 rounded-2xl px-5 py-4 text-center w-40">
        <p className="text-3xl font-bold text-indigo-700">{total}</p>
        <p className="text-xs text-indigo-400 mt-1">{t("articles.total")}</p>
      </div>

      <TableToolbar
        total={displayTotal}
        totalLabel="article"
        search={search}
        onSearch={v => { setSearch(v); setPage(1); }}
        searchPlaceholder={t("articles.searchPlaceholder")}
        action={
          <div className="flex items-center gap-2">
            <ColumnToggle columns={columnOptions} visible={visible} onChange={setVisible} />
            <button onClick={() => { setEditing(null); setModalOpen(true); }} className="flex items-center gap-2 px-4 py-2 bg-indigo-600 text-white rounded-xl text-sm hover:bg-indigo-700">
              <Plus size={16} /> {t("articles.new")}
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
        rows={articles}
        keyExtractor={a => a.id}
        isLoading={isLoading}
        emptyText={t("articles.noResults")}
        emptyIcon={<FileText size={36} className="text-gray-300" />}
        onRowClick={(row) => router.push(`/articles/${row.id}`)}
      />

      <TablePagination page={page} totalPages={totalPages} total={displayTotal} limit={12} onPageChange={setPage} />

      {modalOpen && (
        <ArticleModal article={editing} onClose={() => { setModalOpen(false); setEditing(null); }}
          onSaved={() => { setModalOpen(false); setEditing(null); qc.invalidateQueries({ queryKey: ["articles"] }); }} t={t} />
      )}
    </div>
  );
}

function ArticleModal({ article, onClose, onSaved, t }: { article: ArticleItem | null; onClose: () => void; onSaved: () => void; t: (k: string) => string }) {
  const [form, setForm] = useState({
    title: article?.title ?? "",
    slug: article?.slug ?? "",
    summary: article?.summary ?? "",
    content: article?.content ?? "",
    author: article?.author ?? "",
    keywords: article?.keywords ? (function() {
      try {
        const parsed = JSON.parse(article.keywords);
        return Array.isArray(parsed) ? parsed.join(", ") : article.keywords;
      } catch (e) {
        return article.keywords;
      }
    })() : "",
    published_at: article?.published_at ? article.published_at.slice(0, 10) : "",
  });
  const [imgFile, setImgFile] = useState<File | null>(null);
  const [previewUrl, setPreviewUrl] = useState<string | null>(article?.cover_image ?? null);
  const fileRef = useRef<HTMLInputElement>(null);

  const saveMut = useMutation({
    mutationFn: () => {
      const payload: any = {
        title: form.title,
        summary: form.summary,
        content: form.content,
        keywords: JSON.stringify(form.keywords.split(",").map(k => k.trim()).filter(k => k !== "")),
        published_at: form.published_at,
        author: form.author,
        cover_image: imgFile || null,
      };
      return article 
        ? articleService.updateArticle(article.id, payload) 
        : articleService.createArticle(payload);
    },
    onSuccess: () => { toast.success(article ? t("articles.updated") : t("articles.created")); onSaved(); },
    onError: () => toast.error("Save failed"),
  });

  const set = (k: keyof typeof form, v: string | boolean) => setForm(p => ({ ...p, [k]: v }));

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4">
      <div className="bg-white rounded-2xl shadow-2xl w-full max-w-2xl max-h-[90vh] overflow-y-auto">
        <div className="flex items-center justify-between px-6 py-5 border-b border-gray-100">
          <h2 className="text-lg font-bold text-gray-900">{article ? t("common.edit") : t("articles.new")}</h2>
          <button onClick={onClose} className="p-2 rounded-xl hover:bg-gray-100 text-gray-400"><X size={18} /></button>
        </div>
        <form onSubmit={e => { e.preventDefault(); saveMut.mutate(); }} className="px-6 py-5 space-y-4">
          <div className="grid grid-cols-2 gap-4">
            <div className="space-y-1.5 col-span-2">
              <label className="text-xs font-semibold text-gray-600 uppercase">{t("articles.titleLabel")}</label>
              <input required value={form.title} onChange={e => set("title", e.target.value)} className="input" />
            </div>
          </div>
          <div className="grid grid-cols-2 gap-4">
            <div className="space-y-1.5">
              <label className="text-xs font-semibold text-gray-600 uppercase">{t("articles.slug")}</label>
              <input value={form.slug} onChange={e => set("slug", e.target.value)} className="input font-mono" />
            </div>
            <div className="space-y-1.5">
              <label className="text-xs font-semibold text-gray-600 uppercase">{t("articles.author")}</label>
              <input required value={form.author} onChange={e => set("author", e.target.value)} className="input" />
            </div>
          </div>
          <div className="space-y-1.5">
            <label className="text-xs font-semibold text-gray-600 uppercase">{t("articles.summary")}</label>
            <textarea value={form.summary} onChange={e => set("summary", e.target.value)} rows={2}
              className="w-full border border-gray-300 rounded-xl px-3 py-2 text-sm focus:ring-2 focus:ring-indigo-500 outline-none resize-none" />
          </div>
          <div className="space-y-1.5">
            <label className="text-xs font-semibold text-gray-600 uppercase">{t("articles.content")}</label>
            <RichTextEditor
              value={form.content}
              onChange={v => set("content", v)}
              minHeight={200}
              placeholder="—"
              dir="ltr"
            />
          </div>
          <div className="grid grid-cols-2 gap-4">
            <div className="space-y-1.5">
              <label className="text-xs font-semibold text-gray-600 uppercase">{t("articles.keywords")}</label>
              <input value={form.keywords} onChange={e => set("keywords", e.target.value)} className="input" />
            </div>
            <div className="space-y-1.5">
              <label className="text-xs font-semibold text-gray-600 uppercase">{t("articles.publishedAt")}</label>
              <input type="date" value={form.published_at} onChange={e => set("published_at", e.target.value)} className="input" />
            </div>
          </div>
          <div className="space-y-1.5">
            <label className="text-xs font-semibold text-gray-600 uppercase">{t("articles.coverImage")}</label>
            <div className="flex items-center gap-4">
              {previewUrl && <img src={previewUrl} alt="preview" className="w-20 h-14 rounded-xl object-cover border border-gray-200" />}
              <button type="button" onClick={() => fileRef.current?.click()}
                className="flex items-center gap-2 px-4 py-2.5 border-2 border-dashed border-gray-300 rounded-xl text-sm text-gray-500 hover:border-indigo-400 hover:text-indigo-600 transition">
                <Upload size={16} /> {t("common.uploadPhoto")}
              </button>
              <input ref={fileRef} type="file" accept={ALLOWED_IMAGE_ACCEPT} className="hidden" onChange={e => {
                const f = e.target.files?.[0]; if (!f) return;
                if (!validateImageFile(f, e.target)) return;
                setImgFile(f); setPreviewUrl(URL.createObjectURL(f));
              }} />
            </div>
          </div>
          <div className="flex justify-end gap-3 pt-2 border-t border-gray-100">
            <button type="button" onClick={onClose} className="px-5 py-2.5 border border-gray-300 rounded-xl text-sm text-gray-700 hover:bg-gray-50">{t("common.cancel")}</button>
            <button type="submit" disabled={saveMut.isPending} className="px-6 py-2.5 bg-indigo-600 text-white rounded-xl text-sm font-medium hover:bg-indigo-700 disabled:opacity-60">
              {saveMut.isPending ? t("common.saving") : article ? t("common.save") : t("common.create")}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
