"use client";
import { useState, useRef } from "react";
import { useMutation, useQueryClient } from "@tanstack/react-query";
import { createBrand, updateBrand, type Brand } from "@/lib/products";
import { X, Upload, Trash2 } from "lucide-react";
import toast from "react-hot-toast";
import { useT } from "@/contexts/LanguageContext";
import { cn } from "@/lib/utils";
import { ALLOWED_IMAGE_ACCEPT, validateImageFile } from "@/lib/file-upload";

interface Props {
  brand?: Brand;
  onClose: () => void;
}

export default function BrandForm({ brand, onClose }: Props) {
  const qc = useQueryClient();
  const { t } = useT();
  const isEdit = !!brand;

  const logoRef  = useRef<HTMLInputElement>(null);
  const coverRef = useRef<HTMLInputElement>(null);

  const [name,           setName]           = useState(brand?.name ?? "");
  const [nameAr,         setNameAr]         = useState(brand?.name_ar ?? "");
  const [description,    setDescription]    = useState(brand?.description ?? "");
  const [descriptionAr,  setDescriptionAr]  = useState(brand?.description_ar ?? "");
  const [synonyms,       setSynonyms]       = useState(brand?.synonyms ?? "");
  const [isActive,       setIsActive]       = useState(brand?.is_active ?? true);
  const [isPopular,      setIsPopular]      = useState(brand?.is_popular ?? false);

  const [logoFile,       setLogoFile]       = useState<File | null>(null);
  const [logoPreview,    setLogoPreview]    = useState<string | null>(brand?.logo_url ?? null);
  const [removeLogo,     setRemoveLogo]     = useState(false);

  const [coverFile,      setCoverFile]      = useState<File | null>(null);
  const [coverPreview,   setCoverPreview]   = useState<string | null>(brand?.cover_url ?? null);
  const [removeCover,    setRemoveCover]    = useState(false);

  function onLogoChange(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0];
    if (!file) return;
    if (!validateImageFile(file, e.target)) return;
    setLogoFile(file);
    setLogoPreview(URL.createObjectURL(file));
    setRemoveLogo(false);
  }

  function onCoverChange(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0];
    if (!file) return;
    if (!validateImageFile(file, e.target)) return;
    setCoverFile(file);
    setCoverPreview(URL.createObjectURL(file));
    setRemoveCover(false);
  }

  const mut = useMutation({
    mutationFn: () => {
      const fd = new FormData();
      fd.append("name", name.trim());
      if (nameAr.trim())        fd.append("name_ar",        nameAr.trim());
      if (description.trim())   fd.append("description",    description.trim());
      if (descriptionAr.trim()) fd.append("description_ar", descriptionAr.trim());
      if (synonyms.trim())      fd.append("synonyms",       synonyms.trim());
      fd.append("is_active",  String(isActive));
      fd.append("is_popular", String(isPopular));
      if (logoFile)  fd.append("logo_url",  logoFile);
      if (coverFile) fd.append("cover_url", coverFile);
      if (isEdit) {
        if (removeLogo)  fd.append("deleteLogoUrl",  "true");
        if (removeCover) fd.append("deleteCoverUrl", "true");
        return updateBrand(brand!.id, fd);
      }
      return createBrand(fd);
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["brands"] });
      toast.success(t(isEdit ? "brandForm.updated" : "brandForm.created"));
      onClose();
    },
    onError: (e: any) => toast.error(e.response?.data?.message || "Error"),
  });

  function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (!name.trim()) { toast.error(t("brandForm.nameEn") + " required"); return; }
    mut.mutate();
  }

  const inp  = "w-full border border-gray-300 rounded-xl px-3 py-2.5 text-sm focus:ring-2 focus:ring-indigo-500 outline-none";
  const lbl  = "block text-xs font-semibold text-gray-600 mb-1.5 uppercase tracking-wide";

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/40 backdrop-blur-sm">
      <div className="bg-white rounded-2xl shadow-2xl w-full max-w-lg max-h-[90vh] flex flex-col">
        {/* Header */}
        <div className="flex items-center justify-between px-6 py-4 border-b border-gray-100">
          <h2 className="text-lg font-bold text-gray-900">
            {isEdit ? `${t("common.edit")} — ${brand!.name}` : t("brands.new")}
          </h2>
          <button onClick={onClose} className="p-2 hover:bg-gray-100 rounded-lg transition">
            <X size={18} />
          </button>
        </div>

        {/* Body */}
        <form onSubmit={handleSubmit} className="flex-1 overflow-y-auto px-6 py-5 space-y-5">

          {/* Names */}
          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className={lbl}>{t("brandForm.nameEn")} *</label>
              <input value={name} onChange={e => setName(e.target.value)}
                placeholder="Nike" className={inp} required />
            </div>
            <div>
              <label className={lbl}>{t("brandForm.nameAr")}</label>
              <input value={nameAr} onChange={e => setNameAr(e.target.value)}
                placeholder="نايكي" className={cn(inp, "text-right")} dir="rtl" />
            </div>
          </div>

          {/* Descriptions */}
          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className={lbl}>{t("brandForm.descEn")}</label>
              <textarea value={description} onChange={e => setDescription(e.target.value)}
                rows={3} className={inp} placeholder="Brand description…" />
            </div>
            <div>
              <label className={lbl}>{t("brandForm.descAr")}</label>
              <textarea value={descriptionAr} onChange={e => setDescriptionAr(e.target.value)}
                rows={3} className={cn(inp, "text-right")} dir="rtl" placeholder="وصف الماركة…" />
            </div>
          </div>

          {/* Synonyms */}
          <div>
            <label className={lbl}>{t("brandForm.synonyms")}</label>
            <input value={synonyms} onChange={e => setSynonyms(e.target.value)}
              placeholder="nike, نايكي, swoosh" className={inp} />
          </div>

          {/* Logo */}
          <div>
            <label className={lbl}>{t("brandForm.logo")}</label>
            {logoPreview && !removeLogo ? (
              <div className="flex items-center gap-3">
                {/* eslint-disable-next-line @next/next/no-img-element */}
                <img src={logoPreview} alt="logo" className="w-16 h-16 object-contain rounded-xl border border-gray-200 bg-gray-50" />
                <button type="button" onClick={() => { setRemoveLogo(true); setLogoPreview(null); setLogoFile(null); }}
                  className="flex items-center gap-1.5 text-xs text-red-500 hover:text-red-700 border border-red-200 rounded-lg px-2.5 py-1.5 transition">
                  <Trash2 size={12} /> {t("brandForm.removeLogo")}
                </button>
              </div>
            ) : (
              <>
                <input ref={logoRef} type="file" accept={ALLOWED_IMAGE_ACCEPT} className="hidden" onChange={onLogoChange} />
                <button type="button" onClick={() => logoRef.current?.click()}
                  className="flex items-center gap-2 border-2 border-dashed border-gray-300 rounded-xl px-4 py-3 text-sm text-gray-500 hover:border-indigo-400 hover:text-indigo-600 transition w-full justify-center">
                  <Upload size={16} /> {t("common.uploadPhoto")}
                </button>
              </>
            )}
          </div>

          {/* Cover */}
          <div>
            <label className={lbl}>{t("brandForm.cover")}</label>
            {coverPreview && !removeCover ? (
              <div className="flex items-center gap-3">
                {/* eslint-disable-next-line @next/next/no-img-element */}
                <img src={coverPreview} alt="cover" className="w-full h-24 object-cover rounded-xl border border-gray-200" />
                <button type="button" onClick={() => { setRemoveCover(true); setCoverPreview(null); setCoverFile(null); }}
                  className="flex items-center gap-1.5 text-xs text-red-500 hover:text-red-700 border border-red-200 rounded-lg px-2.5 py-1.5 transition shrink-0">
                  <Trash2 size={12} /> {t("brandForm.removeCover")}
                </button>
              </div>
            ) : (
              <>
                <input ref={coverRef} type="file" accept={ALLOWED_IMAGE_ACCEPT} className="hidden" onChange={onCoverChange} />
                <button type="button" onClick={() => coverRef.current?.click()}
                  className="flex items-center gap-2 border-2 border-dashed border-gray-300 rounded-xl px-4 py-3 text-sm text-gray-500 hover:border-indigo-400 hover:text-indigo-600 transition w-full justify-center">
                  <Upload size={16} /> {t("common.uploadPhoto")}
                </button>
              </>
            )}
          </div>

          {/* Toggles */}
          <div className="flex gap-6">
            <label className="flex items-center gap-2 cursor-pointer select-none">
              <input type="checkbox" checked={isActive} onChange={e => setIsActive(e.target.checked)}
                className="rounded border-gray-300 text-indigo-600 focus:ring-indigo-500" />
              <span className="text-sm text-gray-700">{t("brandForm.isActive")}</span>
            </label>
            <label className="flex items-center gap-2 cursor-pointer select-none">
              <input type="checkbox" checked={isPopular} onChange={e => setIsPopular(e.target.checked)}
                className="rounded border-gray-300 text-yellow-500 focus:ring-yellow-400" />
              <span className="text-sm text-gray-700">{t("brandForm.isPopular")}</span>
            </label>
          </div>
        </form>

        {/* Footer */}
        <div className="flex gap-3 px-6 py-4 border-t border-gray-100">
          <button onClick={onClose}
            className="flex-1 border border-gray-300 rounded-xl py-2.5 text-sm font-medium hover:bg-gray-50 transition">
            {t("common.cancel")}
          </button>
          <button onClick={handleSubmit} disabled={mut.isPending}
            className="flex-1 bg-indigo-600 hover:bg-indigo-700 text-white rounded-xl py-2.5 text-sm font-medium disabled:opacity-60 transition">
            {mut.isPending ? t("common.saving") : isEdit ? t("common.saveChanges") : t("brands.new")}
          </button>
        </div>
      </div>
    </div>
  );
}
