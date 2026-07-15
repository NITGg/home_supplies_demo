import DOMPurify from "isomorphic-dompurify";

/**
 * Converts null-prototype objects (from multer) to plain objects recursively.
 */
function toPlainObject<T>(val: T): T {
  if (Array.isArray(val)) {
    return val.map(toPlainObject) as T;
  }

  if (val !== null && typeof val === "object") {
    return Object.assign(Object.create(Object.prototype), val) as T;
  }

  return val;
}

/**
 * Safe HTML tags allowed in rich-text content fields (about-app, articles, etc.).
 */
const RICH_TEXT_ALLOWED_TAGS = [
  "p", "br", "strong", "b", "em", "i", "u",
  "h1", "h2", "h3", "h4", "h5", "h6",
  "ul", "ol", "li",
  "blockquote", "a", "pre", "code", "hr",
];

const RICH_TEXT_ALLOWED_ATTR = ["href", "target", "rel", "dir"];

/**
 * Recursively sanitizes any input.
 * - Converts null-prototype objects to plain objects first (multer compat).
 * - Strings are sanitized and trimmed.
 * - Objects and Arrays are traversed to sanitize nested string values.
 * - Other types (numbers, booleans, null, undefined) are returned as-is.
 */
export function sanitizeInput<T>(val: T): T {
  // Normalize null-prototype objects before anything else
  const normalized = toPlainObject(val);

  if (typeof normalized === "string") {
    return DOMPurify.sanitize(normalized, { ALLOWED_TAGS: [] }).trim() as T;
  }

  if (Array.isArray(normalized)) {
    return normalized.map((item) => sanitizeInput(item)) as T;
  }

  if (normalized !== null && typeof normalized === "object") {
    const sanitizedObj: any = {};
    for (const [key, value] of Object.entries(normalized)) {
      sanitizedObj[key] = sanitizeInput(value);
    }
    return sanitizedObj as T;
  }

  return normalized;
}

/**
 * Sanitizes an object while preserving safe HTML in specified keys.
 * Keys listed in `htmlKeys` are cleaned with DOMPurify (allowing safe tags).
 * All other keys are stripped of all HTML (same as sanitizeInput).
 */
export function sanitizeWithHtmlFields<T extends Record<string, unknown>>(
  obj: T,
  htmlKeys: Set<string>,
): T {
  const normalized = toPlainObject(obj);
  const result: any = {};

  for (const [key, value] of Object.entries(normalized)) {
    if (htmlKeys.has(key) && typeof value === "string") {
      // Allow safe HTML tags for rich-text fields
      result[key] = DOMPurify.sanitize(value, {
        ALLOWED_TAGS: RICH_TEXT_ALLOWED_TAGS,
        ALLOWED_ATTR: RICH_TEXT_ALLOWED_ATTR,
      }).trim();
    } else {
      result[key] = sanitizeInput(value);
    }
  }

  return result as T;
}