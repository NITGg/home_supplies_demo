export function slugifyTitle(title: string) {
  return title
    .toLowerCase()
    .trim()
    .normalize("NFKD") // handles accents better
    .replaceAll(/[\u0300-\u036f]/g, "")
    .replaceAll(/[^a-z0-9\s-]/g, "")
    .replaceAll(/\s+/g, "-")
    .replaceAll(/-+/g, "-")
    .replaceAll(/(^-|-$)/g, "");
}
