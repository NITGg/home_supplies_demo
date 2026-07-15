I have a universal filter & pagination utility in my Node.js + Express + Prisma + TypeScript project. I need you to apply it to my API endpoints. Here's how the system works:

## The Utility File: src/utils/filter.ts
```typescript
export type FilterType = "range" | "dateRange" | "exact" | "string";

export type FilterConfig = {
  [key: string]: FilterType;
};

export interface FilterResult {
  filters: Record<string, any>;
  pagination: {
    skip: number;
    take: number;
  };
  paginationMeta: {
    page: number;
    limit: number;
  };
}

export function applyFilters(
  params: Record<string, any>,
  config: FilterConfig,
): FilterResult {
  const filters: Record<string, any> = {};

  for (const [field, type] of Object.entries(config)) {
    switch (type) {
      case "range":
        applyRangeFilter(filters, params, field);
        break;
      case "dateRange":
        applyDateRangeFilter(filters, params, field);
        break;
      case "exact":
        applyExactFilter(filters, params, field);
        break;
      case "string":
        applyStringFilter(filters, params, field);
        break;
    }
  }

  const page = parseInt(params.page as string) || 1;
  const limit = parseInt(params.limit as string) || 20;

  return {
    filters,
    pagination: {
      skip: (page - 1) * limit,
      take: limit,
    },
    paginationMeta: {
      page,
      limit,
    },
  };
}

// range: looks for fieldFrom & fieldTo → creates { field: { gte: X, lte: Y } }
function applyRangeFilter(filters: Record<string, any>, params: Record<string, any>, field: string): void {
  const fromValue = params[`${field}From`] ? parseFloat(params[`${field}From`]) : undefined;
  const toValue = params[`${field}To`] ? parseFloat(params[`${field}To`]) : undefined;
  if (fromValue !== undefined || toValue !== undefined) {
    filters[field] = {};
    if (fromValue !== undefined) filters[field].gte = fromValue;
    if (toValue !== undefined) filters[field].lte = toValue;
  }
}

// dateRange: looks for fieldFrom & fieldTo → creates { field: { gte: Date, lte: Date } }
function applyDateRangeFilter(filters: Record<string, any>, params: Record<string, any>, field: string): void {
  const fromValue = params[`${field}From`] ? new Date(params[`${field}From`]) : undefined;
  const toValue = params[`${field}To`] ? new Date(params[`${field}To`]) : undefined;
  const isValidFromDate = fromValue && !isNaN(fromValue.getTime());
  const isValidToDate = toValue && !isNaN(toValue.getTime());
  if (isValidFromDate || isValidToDate) {
    filters[field] = {};
    if (isValidFromDate) filters[field].gte = fromValue;
    if (isValidToDate) filters[field].lte = toValue;
  }
}

// exact: looks for field → creates { field: value }
// use for Int/Decimal fields — value comes pre-typed from Zod (already a number)
function applyExactFilter(filters: Record<string, any>, params: Record<string, any>, field: string): void {
  const value = params[field];
  if (value !== undefined && value !== null && value !== "") {
    filters[field] = value; // no coercion — Zod already handled the type
  }
}

// string: looks for field → creates { field: value } always as string
// use for String fields in Prisma (e.g. order_number, status, enums)
function applyStringFilter(filters: Record<string, any>, params: Record<string, any>, field: string): void {
  const value = params[field];
  if (value !== undefined && value !== null && value !== "") {
    filters[field] = String(value);
  }
}

export function buildPaginationResponse(
  paginationMeta: { page: number; limit: number },
  total: number,
) {
  const total_pages = Math.ceil(total / paginationMeta.limit);
  return {
    total,
    page: paginationMeta.page,
    limit: paginationMeta.limit,
    total_pages,
    has_next: paginationMeta.page < total_pages,
    has_prev: paginationMeta.page > 1,
  };
}
```

## Validation Middleware: src/core/middlewares/validation.middleware.ts
```typescript
import { NextFunction, Request, Response } from "express";
import { ZodObject } from "zod";
import { HttpStatusCode } from "../http/http.status.code";
import { AppError } from "../errors/app.error";

export const validation = (schema: ZodObject) => {
  return (req: Request, res: Response, next: NextFunction) => {
    const data = {
      ...req.body,
      ...req.params,
      ...req.query,
    };
    const result = schema.safeParse(data);
    if (!result.success) {
      const issues = result.error?.issues;
      let messages = "";
      for (let item of issues) {
        messages += item.message + " ||&&|| ";
      }
      throw new AppError(HttpStatusCode.BAD_REQUEST, messages);
    }

    // Save Zod-transformed data so services can use correctly typed values
    res.locals.validatedQuery = result.data;
    next();
  };
};
```

> **Important:** Always pass `res.locals.validatedQuery` (not `req.query`) to `applyFilters`.
> This ensures Zod's type transformations (e.g. `"1"` → `1`) are applied before filtering.

## How to Use It (Real Example)

### 1. Import
```typescript
import { applyFilters, buildPaginationResponse } from "../../utils/filter";
```

### 2. In the service method
```typescript
availableOrders = async (req: Request, res: Response, next: NextFunction) => {
  const user = res.locals.user;

  // Step 1: Apply filters using validated+transformed data (NOT req.query)
  const { filters, pagination, paginationMeta } = applyFilters(
    res.locals.validatedQuery, // ← always use this, never req.query
    {
      budget: "range",       // Decimal → budgetFrom & budgetTo
    }
  );

  // Step 2: Add custom business logic filters (not from user input)
  filters.status = OrderStatus.PENDING;
  filters.courier_id = null;

  // Step 3: Use in Prisma query
  const [orders, total] = await Promise.all([
    prisma.order.findMany({
      where: filters,
      include: { pickup_area: true, delivery_area: true },
      orderBy: { created_at: "desc" },
      ...pagination,
    }),
    prisma.order.count({ where: filters }),
  ]);

  // Step 4: Return response with pagination
  return responseHandler({
    res,
    message: res.__("messages.available_orders_retrieved"),
    data: {
      orders,
      pagination: buildPaginationResponse(paginationMeta, total),
    },
  });
};
```

### 3. Validation schema (Zod)
```typescript
export const availableOrdersQuerySchema = z
  .object({
    page: z.string().regex(/^\d+$/).transform(Number).optional().default(1),
    limit: z.string().regex(/^\d+$/).transform(Number).optional().default(20),
    budgetFrom: z
      .string()
      .regex(/^\d+(\.\d+)?$/)
      .transform(Number)
      .optional(),
    budgetTo: z
      .string()
      .regex(/^\d+(\.\d+)?$/)
      .transform(Number)
      .optional(),
  })
```

## Filter Types Reference

| Type        | Use for (Prisma type)         | Config Key     | Request Params                   | Prisma Output                              |
|-------------|-------------------------------|----------------|----------------------------------|--------------------------------------------|
| `range`     | `Decimal` / `Float` fields    | `budget`       | `budgetFrom`, `budgetTo`         | `{ budget: { gte: 20, lte: 2000 } }`       |
| `dateRange` | `DateTime` fields             | `created_at`   | `created_atFrom`, `created_atTo` | `{ created_at: { gte: Date, lte: Date } }` |
| `exact`     | `Int` / `Decimal` fields      | `area_id`      | `area_id`                        | `{ area_id: 1 }`                           |
| `string`    | `String` / `Enum` fields      | `order_number` | `order_number`                   | `{ order_number: "ORD-001" }`              |

## Zod Schema Rules Per Prisma Type

| Prisma Type  | Zod Schema                                          | Filter Type |
|--------------|-----------------------------------------------------|-------------|
| `String`     | `z.string().optional()`                             | `"string"`  |
| `Enum`       | `z.nativeEnum(YourEnum).optional()`                 | `"string"`  |
| `Int`        | `z.string().regex(/^\d+$/).transform(Number)`       | `"exact"`   |
| `Decimal`    | `z.string().regex(/^\d+(\.\d+)?$/).transform(Number)` | `"exact"` or `"range"` |
| `DateTime`   | `z.string().regex(/^\d{4}-\d{2}-\d{2}$/)`          | `"dateRange"` |

## Rules to Follow

1. Always pass `res.locals.validatedQuery` to `applyFilters`, never `req.query`
2. Use `"string"` filter type for any `String` or `Enum` field in Prisma
3. Use `"exact"` filter type for `Int` or `Decimal` fields (Zod transforms them to numbers)
4. Use `"range"` for `Decimal` fields where range filtering makes sense (prices, fees, budgets)
5. Use `"dateRange"` for all `DateTime` fields
6. Pagination response MUST use `buildPaginationResponse(paginationMeta, total)`
7. Custom business logic filters are added AFTER `applyFilters()` on the `filters` object
8. Always use `Promise.all` to run `findMany` and `count` in parallel
9. The response pagination format is:
```json
{
  "total": 100,
  "page": 1,
  "limit": 10,
  "total_pages": 10,
  "has_next": true,
  "has_prev": false
}
```

## Your Task

Apply this filter & pagination pattern to the following API: [DESCRIBE YOUR API HERE]

The Prisma model is: [PASTE YOUR PRISMA MODEL HERE]

The filters I need are: [LIST YOUR FILTERS HERE]

Follow the exact same pattern shown above. Update:

1. The service method (use `applyFilters` with `res.locals.validatedQuery` + `buildPaginationResponse`)
2. The controller route (if needed)