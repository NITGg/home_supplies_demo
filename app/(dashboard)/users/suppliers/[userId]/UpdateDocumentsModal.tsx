"use client";

import { useState, useRef, useEffect, ChangeEvent } from "react";
import { X, Loader2, Upload, FileText } from "lucide-react";
import { cn } from "@/lib/utils";
import type { SupplierProfileUser } from "@/lib/supplier-api";
import {
  ALLOWED_IMAGE_ACCEPT,
  ALLOWED_IMAGE_LABEL,
  validateImageFile,
} from "@/lib/file-upload";

interface UpdateDocumentsModalProps {
  isOpen: boolean;
  onClose: () => void;
  onSubmit: (data: FormData) => void;
  isLoading: boolean;
  /** Current supplier profile — used to preview existing documents and to
   *  prefill the national ID number. Optional for backward compatibility. */
  profile?: SupplierProfileUser;
  /** When true, renders only the form body (no overlay/header). */
  embedded?: boolean;
}

interface FilePreview {
  file: File;
  preview: string;
  type: "image" | "document";
}

type FileField =
  | "personal_photo"
  | "national_id_photo_front"
  | "national_id_photo_back"
  | "supplier_criminal_record";

function ChangedBadge() {
  return (
    <span className="ml-2 inline-flex items-center text-[10px] font-medium text-amber-700 bg-amber-50 border border-amber-200 px-1.5 py-0.5 rounded-full align-middle">
      Changed
    </span>
  );
}

export default function UpdateDocumentsModal({
  isOpen,
  onClose,
  onSubmit,
  isLoading,
  profile,
  embedded = false,
}: UpdateDocumentsModalProps) {
  const [files, setFiles] = useState<Partial<Record<FileField, FilePreview>>>(
    {},
  );

  const initialNationalId = profile?.supplier?.national_id_number ?? "";
  const [nationalId, setNationalId] = useState(initialNationalId);

  const personalPhotoRef = useRef<HTMLInputElement>(null);
  const nationalIdFrontRef = useRef<HTMLInputElement>(null);
  const nationalIdBackRef = useRef<HTMLInputElement>(null);
  const criminalRecordRef = useRef<HTMLInputElement>(null);

  // Reset/prefill whenever opened or the profile changes.
  useEffect(() => {
    if (isOpen) {
      setFiles({});
      setNationalId(profile?.supplier?.national_id_number ?? "");
    }
  }, [isOpen, profile]);

  // Existing (already-uploaded) document URLs, by field.
  const currentUrls: Record<FileField, string | null | undefined> = {
    personal_photo: profile?.personal_photo,
    national_id_photo_front: profile?.supplier?.national_id_photo_front,
    national_id_photo_back: profile?.supplier?.national_id_photo_back,
    supplier_criminal_record: profile?.supplier?.supplier_criminal_record,
  };

  const nationalIdChanged = nationalId.trim() !== initialNationalId.trim();
  const hasChanges = Object.keys(files).length > 0 || nationalIdChanged;

  const handleFileChange = (
    field: FileField,
    e: ChangeEvent<HTMLInputElement>,
  ) => {
    const file = e.target.files?.[0];
    if (file) {
      if (!validateImageFile(file, e.target)) return;
      const isImage = file.type.startsWith("image/");
      setFiles((prev) => ({
        ...prev,
        [field]: {
          file,
          preview: isImage ? URL.createObjectURL(file) : "",
          type: isImage ? "image" : "document",
        },
      }));
    }
  };

  const handleRemoveFile = (field: FileField) => {
    setFiles((prev) => {
      const newFiles = { ...prev };
      if (newFiles[field]?.preview) {
        URL.revokeObjectURL(newFiles[field]!.preview);
      }
      delete newFiles[field];
      return newFiles;
    });
  };

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    const formData = new FormData();

    if (files.personal_photo) {
      formData.append("personal_photo", files.personal_photo.file);
    }
    if (files.national_id_photo_front) {
      formData.append(
        "national_id_photo_front",
        files.national_id_photo_front.file,
      );
    }
    if (files.national_id_photo_back) {
      formData.append(
        "national_id_photo_back",
        files.national_id_photo_back.file,
      );
    }
    if (files.supplier_criminal_record) {
      formData.append(
        "supplier_criminal_record",
        files.supplier_criminal_record.file,
      );
    }
    // national_id_number is a plain text field (not a file).
    if (nationalIdChanged && nationalId.trim()) {
      formData.append("national_id_number", nationalId.trim());
    }

    onSubmit(formData);
  };

  const renderFileUpload = (
    label: string,
    field: FileField,
    inputRef: React.RefObject<HTMLInputElement | null>,
  ) => {
    const selected = files[field];
    const currentUrl = currentUrls[field];
    return (
      <div className="space-y-2">
        <label className="block text-sm font-medium text-gray-700">
          {label}
          {selected && <ChangedBadge />}
        </label>

        {selected ? (
          // A new file has been chosen — preview it with a "New" marker.
          <div className="flex items-center gap-3 p-3 bg-amber-50 rounded-lg border border-amber-200">
            {selected.type === "image" && selected.preview ? (
              // eslint-disable-next-line @next/next/no-img-element
              <img
                src={selected.preview}
                alt={label}
                className="w-16 h-16 object-cover rounded-lg"
              />
            ) : (
              <div className="w-16 h-16 bg-gray-200 rounded-lg flex items-center justify-center">
                <FileText size={24} className="text-gray-500" />
              </div>
            )}
            <div className="flex-1 min-w-0">
              <p className="text-xs font-medium text-amber-700">New file</p>
              <p className="text-sm font-medium text-gray-900 truncate">
                {selected.file.name}
              </p>
              <p className="text-xs text-gray-500">
                {(selected.file.size / 1024 / 1024).toFixed(2)} MB
              </p>
            </div>
            <button
              type="button"
              onClick={() => handleRemoveFile(field)}
              className="p-1.5 text-red-500 hover:bg-red-50 rounded-lg transition"
              disabled={isLoading}
              title="Remove new file"
            >
              <X size={16} />
            </button>
          </div>
        ) : (
          <div className="space-y-2">
            {/* Current document (if any) */}
            {currentUrl && (
              <div className="flex items-center gap-3 p-3 bg-gray-50 rounded-lg border border-gray-200">
                {/* eslint-disable-next-line @next/next/no-img-element */}
                <img
                  src={currentUrl}
                  alt={`Current ${label}`}
                  className="w-16 h-16 object-cover rounded-lg border border-gray-200"
                />
                <div className="flex-1 min-w-0">
                  <p className="text-xs text-gray-500">Current</p>
                  <a
                    href={currentUrl}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="text-sm font-medium text-indigo-600 hover:underline"
                  >
                    View file
                  </a>
                </div>
              </div>
            )}
            <button
              type="button"
              onClick={() => inputRef.current?.click()}
              className="w-full p-4 border-2 border-dashed border-gray-300 rounded-lg hover:border-indigo-500 hover:bg-indigo-50 transition flex flex-col items-center gap-2"
              disabled={isLoading}
            >
              <Upload size={20} className="text-gray-400" />
              <span className="text-sm text-gray-600">
                {currentUrl ? `Replace ${label}` : `Click to upload ${label}`}
              </span>
              <span className="text-xs text-gray-400">
                {ALLOWED_IMAGE_LABEL} up to 10MB
              </span>
            </button>
          </div>
        )}

        <input
          ref={inputRef}
          type="file"
          accept={ALLOWED_IMAGE_ACCEPT}
          onChange={(e) => handleFileChange(field, e)}
          className="hidden"
        />
      </div>
    );
  };

  if (!isOpen) return null;

  const formBody = (
    <form onSubmit={handleSubmit} className="p-6 space-y-6">
      {/* National ID Number (text field) */}
      <div>
        <label className="block text-sm font-medium text-gray-700 mb-1">
          National ID Number
          {nationalIdChanged && <ChangedBadge />}
        </label>
        <input
          type="text"
          value={nationalId}
          onChange={(e) => setNationalId(e.target.value)}
          placeholder="e.g., 29801011234567"
          className={cn(
            "w-full px-3 py-2 border rounded-lg focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500",
            nationalIdChanged ? "border-amber-400 bg-amber-50" : "border-gray-300",
          )}
          disabled={isLoading}
        />
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        {renderFileUpload("Personal Photo", "personal_photo", personalPhotoRef)}
        {renderFileUpload(
          "National ID Front",
          "national_id_photo_front",
          nationalIdFrontRef,
        )}
        {renderFileUpload(
          "National ID Back",
          "national_id_photo_back",
          nationalIdBackRef,
        )}
        {renderFileUpload(
          "Criminal Record",
          "supplier_criminal_record",
          criminalRecordRef,
        )}
      </div>

      <div className="flex justify-end gap-3 pt-4 border-t border-gray-200">
        <button
          type="button"
          onClick={onClose}
          disabled={isLoading}
          className="px-4 py-2 text-gray-700 bg-gray-100 hover:bg-gray-200 rounded-lg font-medium transition"
        >
          Cancel
        </button>
        <button
          type="submit"
          disabled={isLoading || !hasChanges}
          className="flex items-center gap-2 px-4 py-2 bg-orange-600 hover:bg-orange-700 text-white rounded-lg font-medium transition disabled:opacity-50 disabled:cursor-not-allowed"
        >
          {isLoading && <Loader2 size={16} className="animate-spin" />}
          {isLoading ? "Uploading..." : "Update Documents"}
        </button>
      </div>
    </form>
  );

  if (embedded) return formBody;

  return (
    <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
      <div className="bg-white rounded-xl w-full max-w-2xl max-h-[90vh] overflow-y-auto">
        <div className="flex items-center justify-between p-6 border-b border-gray-200">
          <h2 className="text-xl font-semibold text-gray-900">
            Update Documents
          </h2>
          <button
            onClick={onClose}
            className="p-2 hover:bg-gray-100 rounded-lg transition"
            disabled={isLoading}
          >
            <X size={20} />
          </button>
        </div>

        {formBody}
      </div>
    </div>
  );
}
