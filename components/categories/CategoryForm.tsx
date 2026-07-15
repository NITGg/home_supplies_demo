"use client";
import { useState } from "react";
import { X } from "lucide-react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { createCategory, updateCategory, fetchCategories, type Category } from "@/lib/categories";
import ImageUpload from "./ImageUpload";
import toast from "react-hot-toast";
import { useT } from "@/contexts/LanguageContext";

interface Props {
  category?: Category;
  onClose: () => void;
}

export default function CategoryForm({ category, onClose }: Props) {
  const qc = useQueryClient();
  const { t } = useT();
  const isEdit = !!category;

  const [form, setForm] = useState({
    name: category?.name || "",
    name_ar: category?.name_ar || "",
    description: category?.description || "",
    description_ar: category?.description_ar || "",
    synonyms: category?.synonyms || "",
    parent_id: category?.parent_id?.toString() || "",
    is_active: category?.is_active ?? true,
    has_window: category?.has_window ?? false,
  });
  const [imageFile, setImageFile] = useState<File | null>(null);
  const [iconFile, setIconFile] = useState<File | null>(null);

  const { data: parentsData } = useQuery({
    queryKey: ["categories-parents"],
    queryFn: () => fetchCategories({ limit: 100 }),
  });
  const parents = parentsData?.categories.filter(c => !c.parent_id && c.id !== category?.id) || [];

  const mutation = useMutation({
    mutationFn: (fd: FormData) =>
      isEdit ? updateCategory(category!.id, fd) : createCategory(fd),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["categories"] });
      toast.success(isEdit ? t("catForm.updated") : t("catForm.created"));
      onClose();
    },
    onError: (err: any) => toast.error(err.response?.data?.message || "Error"),
  });

  function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    const fd = new FormData();
    fd.append("name", form.name);
    fd.append("name_ar", form.name_ar);
    if (form.description) fd.append("description", form.description);
    if (form.description_ar) fd.append("description_ar", form.description_ar);
    if (form.synonyms) fd.append("synonyms", form.synonyms);
    if (form.parent_id) fd.append("parent_id", form.parent_id);
    fd.append("is_active", String(form.is_active));
    fd.append("has_window", String(form.has_window));
    if (imageFile) fd.append("image_url", imageFile);
    if (iconFile) fd.append("icon_url", iconFile);
    mutation.mutate(fd);
  }

  const inputCls = "w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-indigo-500 outline-none";
  const labelCls = "block text-sm font-medium text-gray-700 mb-1";

  return (
    <div className="fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-4">
      <div className="bg-white rounded-2xl w-full max-w-2xl max-h-[90vh] overflow-y-auto shadow-2xl">
        {/* Header */}
        <div className="flex items-center justify-between px-6 py-4 border-b sticky top-0 bg-white z-10">
          <h2 className="text-lg font-semibold">
            {isEdit ? t("categories.edit") : t("categories.new")}
          </h2>
          <button onClick={onClose} className="p-2 hover:bg-gray-100 rounded-lg">
            <X size={18} />
          </button>
        </div>

        <form onSubmit={handleSubmit} className="p-6 space-y-5">
          {/* Names */}
          <div className="grid grid-cols-2 gap-4">
            <div>
              <label className={labelCls}>{t("catForm.nameEn")} *</label>
              <input required value={form.name}
                onChange={e => setForm(f => ({ ...f, name: e.target.value }))}
                className={inputCls} />
            </div>
            <div>
              <label className={labelCls}>{t("catForm.nameAr")} *</label>
              <input required dir="rtl" value={form.name_ar}
                onChange={e => setForm(f => ({ ...f, name_ar: e.target.value }))}
                className={inputCls} />
            </div>
          </div>

          {/* Descriptions */}
          <div className="grid grid-cols-2 gap-4">
            <div>
              <label className={labelCls}>{t("catForm.descEn")}</label>
              <textarea rows={3} value={form.description}
                onChange={e => setForm(f => ({ ...f, description: e.target.value }))}
                className={`${inputCls} resize-none`} />
            </div>
            <div>
              <label className={labelCls}>{t("catForm.descAr")}</label>
              <textarea rows={3} dir="rtl" value={form.description_ar}
                onChange={e => setForm(f => ({ ...f, description_ar: e.target.value }))}
                className={`${inputCls} resize-none`} />
            </div>
          </div>

          {/* Parent & Synonyms */}
          <div className="grid grid-cols-2 gap-4">
            <div>
              <label className={labelCls}>{t("catForm.parent")}</label>
              <select value={form.parent_id}
                onChange={e => setForm(f => ({ ...f, parent_id: e.target.value }))}
                className={inputCls}>
                <option value="">{t("catForm.noParent")}</option>
                {parents.map(p => (
                  <option key={p.id} value={p.id}>{p.name} / {p.name_ar}</option>
                ))}
              </select>
            </div>
            <div>
              <label className={labelCls}>{t("catForm.synonyms")}</label>
              <input value={form.synonyms}
                onChange={e => setForm(f => ({ ...f, synonyms: e.target.value }))}
                placeholder="grocery,market,بقالة"
                className={inputCls} />
            </div>
          </div>

          {/* Status */}
          <div className="flex items-center gap-6">
            <div className="flex items-center gap-3">
              <input type="checkbox" id="is_active" checked={form.is_active}
                onChange={e => setForm(f => ({ ...f, is_active: e.target.checked }))}
                className="w-4 h-4 text-indigo-600 rounded" />
              <label htmlFor="is_active" className="text-sm font-medium text-gray-700">
                {t("catForm.isActive")}
              </label>
            </div>
            <div className="flex items-center gap-3">
              <input type="checkbox" id="has_window" checked={form.has_window}
                onChange={e => setForm(f => ({ ...f, has_window: e.target.checked }))}
                className="w-4 h-4 text-indigo-600 rounded" />
              <label htmlFor="has_window" className="text-sm font-medium text-gray-700">
                {t("catForm.hasWindow")}
              </label>
            </div>
          </div>

          {/* Images */}
          <div className="grid grid-cols-2 gap-4">
            <ImageUpload label={t("catForm.image")} value={category?.image_url} onChange={setImageFile} />
            <ImageUpload label={t("catForm.icon")} value={category?.icon_url} onChange={setIconFile} />
          </div>

          {/* Actions */}
          <div className="flex gap-3 justify-end pt-2">
            <button type="button" onClick={onClose}
              className="px-5 py-2 border border-gray-300 rounded-lg text-sm font-medium hover:bg-gray-50 transition">
              {t("common.cancel")}
            </button>
            <button type="submit" disabled={mutation.isPending}
              className="px-5 py-2 bg-indigo-600 hover:bg-indigo-700 disabled:opacity-60 text-white rounded-lg text-sm font-medium transition">
              {mutation.isPending ? t("common.saving") : isEdit ? t("common.saveChanges") : t("common.create")}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
