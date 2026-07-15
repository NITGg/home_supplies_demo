"use client";
import { useRef, useState } from "react";
import { Upload, X } from "lucide-react";
import { ALLOWED_IMAGE_ACCEPT, validateImageFile } from "@/lib/file-upload";

interface Props {
  label: string;
  value?: string;
  onChange: (file: File | null) => void;
}

export default function ImageUpload({ label, value, onChange }: Props) {
  const ref = useRef<HTMLInputElement>(null);
  const [preview, setPreview] = useState<string | null>(value || null);

  function handleFile(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0];
    if (!file) return;
    if (!validateImageFile(file, e.target)) return;
    setPreview(URL.createObjectURL(file));
    onChange(file);
  }

  function clear() {
    setPreview(null);
    onChange(null);
    if (ref.current) ref.current.value = "";
  }

  return (
    <div>
      <label className="block text-sm font-medium text-gray-700 mb-1">{label}</label>
      <div
        onClick={() => ref.current?.click()}
        className="relative border-2 border-dashed border-gray-300 rounded-xl h-36 flex items-center justify-center cursor-pointer hover:border-indigo-400 transition overflow-hidden bg-gray-50"
      >
        {preview ? (
          <>
            <img src={preview} alt="preview" className="absolute inset-0 w-full h-full object-cover rounded-xl" />
            <button
              type="button"
              onClick={(e) => { e.stopPropagation(); clear(); }}
              className="absolute top-2 right-2 bg-white rounded-full p-1 shadow hover:bg-red-50"
            >
              <X size={14} className="text-red-500" />
            </button>
          </>
        ) : (
          <div className="text-center text-gray-400">
            <Upload size={24} className="mx-auto mb-1" />
            <p className="text-xs">Click to upload</p>
            <p className="text-xs">PNG, JPG, WEBP</p>
          </div>
        )}
      </div>
      <input ref={ref} type="file" accept={ALLOWED_IMAGE_ACCEPT} className="hidden" onChange={handleFile} />
    </div>
  );
}
