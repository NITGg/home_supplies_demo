// ── Global file-upload allow-list ──────────────────────────────────────────
// Single source of truth for which file types image/file pickers accept across
// the whole app. To allow more (or fewer) types everywhere, edit this list.
//
// By default only JPEG, JPG, PNG and WEBP images are allowed.
import toast from "react-hot-toast";

export const ALLOWED_IMAGE_EXTENSIONS = ["jpeg", "jpg", "png", "webp"] as const;

// Value for the <input type="file" accept="…"> attribute. The OS file-picker
// uses this to only show/select files with these extensions.
export const ALLOWED_IMAGE_ACCEPT = ALLOWED_IMAGE_EXTENSIONS.map(
  (ext) => `.${ext}`,
).join(",");

// Human-readable label for upload hints, e.g. "JPEG, JPG, PNG, WEBP".
export const ALLOWED_IMAGE_LABEL = ALLOWED_IMAGE_EXTENSIONS.map((ext) =>
  ext.toUpperCase(),
).join(", ");

// Returns true when the given File's extension is in the allow-list. Use this
// to reject files chosen via the picker's "All files" escape hatch.
export function isAllowedImageFile(file: File): boolean {
  const ext = file.name.split(".").pop()?.toLowerCase() ?? "";
  return (ALLOWED_IMAGE_EXTENSIONS as readonly string[]).includes(ext);
}

// Message shown when a disallowed file is picked. Centralised here so the
// wording is consistent everywhere.
export const DISALLOWED_FILE_MESSAGE = `Only ${ALLOWED_IMAGE_LABEL} files are allowed`;

// Guards a single picked file. On rejection it shows a toast, clears the input
// (so the same file can be re-picked after the user converts it), and returns
// false. Returns true when the file is allowed. Use in single-file onChange
// handlers: `if (!validateImageFile(file, e.target)) return;`
export function validateImageFile(
  file: File,
  input?: HTMLInputElement | null,
): boolean {
  if (isAllowedImageFile(file)) return true;
  toast.error(DISALLOWED_FILE_MESSAGE);
  if (input) input.value = "";
  return false;
}

// Filters a list of picked files down to the allowed ones, showing a toast if
// any were rejected. Use in multi-file onChange handlers.
export function filterAllowedImageFiles(files: File[]): File[] {
  const accepted = files.filter(isAllowedImageFile);
  if (accepted.length < files.length) toast.error(DISALLOWED_FILE_MESSAGE);
  return accepted;
}
