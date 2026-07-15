import type { Request } from "express";

type Primitive = string | number | boolean | null | Date;
type JsonValue = Primitive | JsonObject | JsonValue[];
type JsonObject = { [key: string]: JsonValue };

type PrismaQuery = {
  where?: JsonObject;
  orderBy?: any;
  select?: JsonObject;
  include?: JsonObject;
  take?: number;
  skip?: number;
  distinct?: string | string[];
};

type AnyReq = Request<any, any, any, Record<string, unknown>>;

const OMIT_QUERY_KEYS = new Set([
  "fields",
  "includes",
  "sort",
  "limit",
  "keyword",
  "select",
  "page",
  "skip",
  "items",
  "lang",
  "op",
]);

const RELATION_PREFIXES = ["every_", "where_", "some_"] as const;
type RelationOp = "every" | "where" | "some";

function isParsableArrayString(v: unknown): v is string {
  if (typeof v !== "string") return false;
  const trimmed = v.trim();
  if (!trimmed.startsWith("[") || !trimmed.endsWith("]")) return false;
  try {
    const parsed = JSON.parse(trimmed);
    return Array.isArray(parsed);
  } catch {
    return false;
  }
}

function isIsoDateString(v: unknown): v is string {
  if (typeof v !== "string") return false;
  if (!Number.isNaN(Number(v))) return false;
  // Strict ISO format: YYYY-MM-DD or YYYY-MM-DDTHH:mm:ss...
  const isoPattern =
    /^\d{4}-\d{2}-\d{2}(T\d{2}:\d{2}:\d{2}(\.\d+)?(Z|[+-]\d{2}:\d{2})?)?$/;
  if (!isoPattern.test(v)) return false;
  const d = new Date(v);
  return !Number.isNaN(d.getTime());
}

function isNumericString(v: unknown): v is string {
  return (
    typeof v === "string" && v.trim() !== "" && /^-?\d+(\.\d+)?$/.test(v.trim())
  );
}

function shouldPreserveString(v: unknown): boolean {
  if (typeof v !== "string") return false;

  const s = v.trim();

  // preserve values that look like phone numbers / identifiers
  if (s.startsWith("+")) return true;
  if (/^0\d+$/.test(s)) return true; // leading zero
  if (/^\d{11,}$/.test(s)) return true; // long digit strings, often phone/id
  return false;
}

function parsePrimitive(v: unknown): Primitive | unknown {
  if (v === "true") return true;
  if (v === "false") return false;
  if (v === "null") return null;
  if (v === "{}") return {};
  if (isIsoDateString(v)) return new Date(v);

  if (!shouldPreserveString(v) && isNumericString(v)) {
    return Number(v);
  }

  return v;
}

function normalize(value: unknown): JsonValue {
  // Arrays (already)
  if (Array.isArray(value)) return value.map(normalize);

  // Stringified array
  if (isParsableArrayString(value)) {
    const arr = JSON.parse(value) as unknown[];
    return arr.map(normalize);
  }

  // Plain object
  if (value && typeof value === "object" && !(value instanceof Date)) {
    const out: JsonObject = {};
    for (const [k, v] of Object.entries(value as Record<string, unknown>)) {
      out[k] = normalize(v);
    }
    return out;
  }

  // Primitive-ish string conversions
  return parsePrimitive(value) as JsonValue;
}

function stripQuery(query: Record<string, unknown>): Record<string, unknown> {
  const out: Record<string, unknown> = {};
  for (const [k, v] of Object.entries(query)) {
    if (!OMIT_QUERY_KEYS.has(k)) out[k] = v;
  }
  return out;
}

/**
 * Converts values like:
 *   key="roleId=1" -> { roleId: { equals: 1 } } or your previous form
 *
 * Your original `transformToNestedObject` expected:
 *   [firstKey, secondKey, value]
 * We keep that same behavior here.
 */
function transformToNestedObject(parts: string[]): JsonObject {
  const result: JsonObject = {};
  const [firstKey, secondKey, rawValue] = parts;

  const numericValue = Number.isNaN(Number(rawValue))
    ? rawValue
    : Number(rawValue);

  // relation prefixes on firstKey (every_/where_/some_)
  const matched = RELATION_PREFIXES.find((p) => firstKey.startsWith(p));
  if (matched) {
    const nestedKey = firstKey.slice(matched.length);
    const operation = matched.split("_")[0] as RelationOp;

    result[nestedKey] = {
      [operation]: {
        [secondKey]: numericValue as JsonValue,
      },
    };
    return result;
  }

  result[firstKey] = { [secondKey]: numericValue as JsonValue };
  return result;
}

/**
 * Handles query keys with relation prefixes:
 *   some_roles="name=Admin"  -> { roles: { some: { name: "Admin" } } }
 *   where_role="name=eq=Admin" (nested) -> { role: { where: { name: { eq: "Admin" } } } }
 *
 * Your previous logic supported:
 * - "field=value"
 * - "nestedField=nestedSubField=value" (3 parts)
 */
function parseRelationPrefixedFilter(
  key: string,
  raw: unknown,
): { newKey: string; value: JsonValue } | null {
  const prefix = RELATION_PREFIXES.find((p) => key.startsWith(p));
  if (!prefix) return null;
  if (typeof raw !== "string" || !raw.includes("=")) return null;

  const op = prefix.split("_")[0] as RelationOp;
  const nestedKey = key.slice(prefix.length);

  const parts = raw.split("=");
  // role=name=value  => parts length >=3
  if (parts.length >= 3) {
    const nestedField = parts[0];
    const nestedSubField = parts[1];
    const fieldValue = normalize(parts.slice(2).join("=")); // allow '=' inside value

    return {
      newKey: nestedKey,
      value: {
        [op]: {
          [nestedField]: {
            [nestedSubField]: fieldValue,
          },
        },
      },
    };
  }

  // roleId=1 => parts length 2
  const fieldName = parts[0];
  const fieldValue = normalize(parts[1]);

  return {
    newKey: nestedKey,
    value: {
      [op]: {
        [fieldName]: fieldValue,
      },
    },
  };
}

function mergeDeep(target: JsonObject, source: JsonObject): JsonObject {
  for (const [k, v] of Object.entries(source)) {
    const tv = target[k];
    if (
      tv &&
      typeof tv === "object" &&
      !Array.isArray(tv) &&
      v &&
      typeof v === "object" &&
      !Array.isArray(v)
    ) {
      target[k] = mergeDeep(tv as JsonObject, v as JsonObject);
    } else {
      target[k] = v;
    }
  }
  return target;
}

class FeatureApi {
  private readonly req: AnyReq;
  public data: PrismaQuery = {};

  constructor(req: AnyReq) {
    this.req = req;
  }

  filter(
    filterData?: Record<string, unknown>,
    options?: { allowKeys?: string[] },
  ) {
    const rawQuery = structuredClone(this.req.sanitized.query ?? {});

    // remove reserved keys (fields, includes, etc.)
    let query = stripQuery(rawQuery);

    // ✅ if allowKeys provided, keep ONLY these keys from query
    if (options?.allowKeys) {
      const allowed = new Set(options.allowKeys);
      query = Object.fromEntries(
        Object.entries(query).filter(([k]) => allowed.has(k)),
      );
    }

    let merged: Record<string, unknown> = mergeDeep(
      query as JsonObject,
      (filterData ?? {}) as JsonObject,
    );

    // relation-prefix parse ...
    for (const [k, v] of Object.entries({ ...merged })) {
      const parsed = parseRelationPrefixedFilter(k, v);
      if (parsed) {
        delete merged[k];
        merged[parsed.newKey] = parsed.value;
      }
    }

    const where = normalize(merged) as JsonObject;

    for (const [k, v] of Object.entries(where)) {
      if (typeof v === "string" && v.includes("=")) {
        where[k] = transformToNestedObject(v.split("="));
      }
    }

    this.data.where = where;
    return this;
  }

  sort(sortData?: string) {
    const sortRaw =
      (this.req.sanitized.query.sort as string | undefined) ?? sortData;
    if (!sortRaw) return this;

    const sortFields = sortRaw
      .split(",")
      .map((s) => s.trim())
      .filter(Boolean);

    const orderBy = sortFields.map((field) => {
      const order = field.startsWith("-") ? "desc" : "asc";
      const fieldName = field.replace(/^-/, "");

      // nested sort: user.profile.name
      if (fieldName.includes(".")) {
        const parts = fieldName.split(".");
        const root: JsonObject = {};
        let cur: JsonObject = root;

        parts.forEach((p, idx) => {
          if (idx === parts.length - 1) cur[p] = order;
          else {
            cur[p] = {};
            cur = cur[p] as JsonObject;
          }
        });

        return root;
      }

      return { [fieldName]: order };
    });

    this.data.orderBy = orderBy as unknown as JsonValue;
    return this;
  }

  // ---------- SELECT/INCLUDE HELPERS ----------
  private buildSelectObject(parts: string[], index = 0): JsonObject {
    const key = parts[index].trim();
    if (index === parts.length - 1) return { [key]: true };
    return { [key]: { select: this.buildSelectObject(parts, index + 1) } };
  }

  private buildDotNotationSelect(parts: string[], index = 0): JsonObject {
    if (index === parts.length - 1) return { [parts[index]]: true };
    return {
      [parts[index]]: { select: this.buildDotNotationSelect(parts, index + 1) },
    };
  }

  private processField(field: string): JsonObject {
    const trimmed = field.trim();

    // wallet=user=id-fullname (nested assignment)
    if (trimmed.includes("=")) {
      const [key, ...rest] = trimmed.split("=");
      const path = rest.join("=");
      return { [key.trim()]: { select: this.buildNestedSelectFromPath(path) } };
    }

    // user.profile.name
    if (trimmed.includes(".")) {
      return this.buildSelectObject(trimmed.split("."));
    }

    return { [trimmed]: true };
  }

  private buildNestedSelect(fieldPath: string): JsonObject {
    // dash separated list: id-fullname
    const fields = fieldPath
      .split("-")
      .map((s) => s.trim())
      .filter(Boolean);
    return fields.reduce<JsonObject>(
      (acc, f) => mergeDeep(acc, this.processField(f)),
      {},
    );
  }

  private buildNestedSelectFromPath(path: string): JsonObject {
    if (!path.includes("=")) return this.buildNestedSelect(path);

    const firstEq = path.indexOf("=");
    const before = path.slice(0, firstEq).trim();
    const after = path.slice(firstEq + 1);

    // if before has "-", treat as: id-fullname-GiftCardFrom=QR
    if (before.includes("-")) {
      const dashParts = before
        .split("-")
        .map((s) => s.trim())
        .filter(Boolean);
      const last = dashParts.pop(); // last is nested key
      const base: JsonObject = {};
      for (const p of dashParts) base[p] = true;

      if (!last) return base;

      const nested = this.processField(`${last}=${after}`);
      return mergeDeep(base, nested);
    }

    return { [before]: { select: this.buildNestedSelectFromPath(after) } };
  }

  private parseFields(fieldsString: string): JsonObject {
    const fields = fieldsString
      .split(",")
      .map((s) => s.trim())
      .filter(Boolean);

    return fields.reduce<JsonObject>((acc, field) => {
      const obj = this.processField(field);

      // If dot notation causes overlap, merge
      return mergeDeep(acc, obj);
    }, {});
  }

  fields(select?: string, dataSelect?: JsonObject) {
    const queryFields = this.req.sanitized.query.fields as string | undefined;
    const fieldsString = queryFields ?? select;
    const parsed = fieldsString ? this.parseFields(fieldsString) : undefined;

    if (parsed) {
      this.data.select = mergeDeep({ ...(dataSelect ?? {}) }, parsed);
    }

    return this;
  }

  includes(selectData?: string) {
    const queryIncludes = this.req.sanitized.query.includes as
      | string
      | undefined;
    const includesString = queryIncludes ?? selectData;
    const parsed = includesString
      ? this.parseFields(includesString)
      : undefined;

    if (parsed) {
      // Prisma: include and select can't coexist on same level
      if (this.data.select) delete this.data.select;

      this.data.include = this.data.include
        ? mergeDeep(this.data.include, parsed)
        : parsed;
    }

    return this;
  }

  limit(limitData?: number) {
    const q = this.req.sanitized.query.limit;
    const take = Number.parseInt(String(q ?? "")) || limitData;
    if (take) this.data.take = take;
    return this;
  }

  keyword(itemsData?: string[], opData: string = "OR") {
    const keyword = this.req.sanitized.query.keyword as string | undefined;
    const op = (this.req.sanitized.query.op as string | undefined) ?? opData;
    const items =
      (this.req.sanitized.query.items as string | undefined)
        ?.split(",")
        .map((s) => s.trim())
        .filter(Boolean) ??
      itemsData ??
      [];

    if (!keyword || items.length === 0) return this;

    const conditions: JsonObject[] = [];

    const buildNestedContains = (parts: string[], idx = 0): JsonObject => {
      if (idx === parts.length - 1) return { contains: keyword };
      return { [parts[idx + 1]]: buildNestedContains(parts, idx + 1) };
    };

    for (const field of items) {
      if (field.includes(".enum")) {
        const [fieldName] = field.split(".enum");
        if (keyword === keyword.toUpperCase() && !keyword.includes(" ")) {
          conditions.push({ [fieldName]: { equals: keyword } });
        }
        continue;
      }

      if (field.includes(".")) {
        const parts = field.split(".");
        conditions.push({ [parts[0]]: buildNestedContains(parts) });
        continue;
      }

      conditions.push({ [field]: { contains: keyword } });
    }

    if (conditions.length) {
      this.data.where = this.data.where ?? {};
      (this.data.where as JsonObject)[op] = conditions;
    }

    return this;
  }

  skip(skipData?: number) {
    const q = this.req.sanitized.query.skip;
    const skip = Number.parseInt(String(q ?? "")) || skipData;
    if (skip) this.data.skip = skip;
    return this;
  }

  distinct(field?: string | string[]) {
    const q = this.req.sanitized.query.distinct as string | undefined;
    this.data.distinct = q ?? field;
    return this;
  }
}

export default FeatureApi;
