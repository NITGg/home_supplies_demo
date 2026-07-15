/**
 * Universal Filter & Pagination Utility
 *
 * This utility provides database-level filtering and pagination for any API endpoint.
 * It converts request parameters into Prisma-compatible query objects.
 *
 * @example
 * // Define filter configuration
 * const filterConfig = {
 *   budget: 'range',
 *   createdAt: 'dateRange',
 *   status: 'exact'
 * };
 *
 * // Apply filters
 * const { filters, pagination } = applyFilters(req.query, filterConfig);
 *
 * // Use in Prisma query
 * const orders = await prisma.order.findMany({
 *   where: filters,
 *   ...pagination
 * });
 */

export type FilterType = "range" | "dateRange" | "exact" | "contains";

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

/**
 * Apply filters and pagination to request parameters
 *
 * @param params - Request query/body parameters (camelCase)
 * @param config - Filter configuration defining field types
 * @returns Object containing filters and pagination for Prisma
 */
export function applyFilters(
  params: Record<string, any>,
  config: FilterConfig,
): FilterResult {
  const filters: Record<string, any> = {};

  // Process each configured filter
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

      case "contains":
        applyContainsFilter(filters, params, field);
        break;
    }
  }

  // Handle pagination
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

/**
 * Apply range filter (e.g., budgetFrom, budgetTo)
 * Creates: { field: { gte: X, lte: Y } }
 */
function applyRangeFilter(
  filters: Record<string, any>,
  params: Record<string, any>,
  field: string,
): void {
  const fromKey = `${field}From`;
  const toKey = `${field}To`;

  const fromValue = params[fromKey] ? parseFloat(params[fromKey]) : undefined;
  const toValue = params[toKey] ? parseFloat(params[toKey]) : undefined;

  if (fromValue !== undefined || toValue !== undefined) {
    filters[field] = {};
    if (fromValue !== undefined) filters[field].gte = fromValue;
    if (toValue !== undefined) filters[field].lte = toValue;
  }
}

/**
 * Apply date range filter (e.g., createdAtFrom, createdAtTo)
 * Creates: { field: { gte: Date, lte: Date } }
 */
function applyDateRangeFilter(
  filters: Record<string, any>,
  params: Record<string, any>,
  field: string,
): void {
  const fromKey = `${field}From`;
  const toKey = `${field}To`;

  const fromValue = params[fromKey] ? new Date(params[fromKey]) : undefined;
  const toValue = params[toKey] ? new Date(params[toKey]) : undefined;

  // Validate dates
  const isValidFromDate = fromValue && !isNaN(fromValue.getTime());
  const isValidToDate = toValue && !isNaN(toValue.getTime());

  if (isValidFromDate || isValidToDate) {
    filters[field] = {};
    if (isValidFromDate) filters[field].gte = fromValue;
    if (isValidToDate) filters[field].lte = toValue;
  }
}

/**
 * Apply exact match filter (e.g., status, orderNumber)
 * Creates: { field: value }
 */
function applyExactFilter(
  filters: Record<string, any>,
  params: Record<string, any>,
  field: string,
): void {
  const value = params[field];

  if (value !== undefined && value !== null && value !== "") {
    filters[field] = value;
  }
}

/**
 * Apply contains filter (case-insensitive partial match)
 * Creates: { field: { contains: value, mode: 'insensitive' } }
 */
function applyContainsFilter(
  filters: Record<string, any>,
  params: Record<string, any>,
  field: string,
): void {
  const value = params[field];

  if (value !== undefined && value !== null && value !== "") {
    filters[field] = {
      contains: value,
    };
  }
}

/**
 * Helper to build pagination response metadata
 *
 * @param paginationMeta - Pagination metadata from applyFilters
 * @param total - Total count from database
 * @returns Pagination metadata for response
 */
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
