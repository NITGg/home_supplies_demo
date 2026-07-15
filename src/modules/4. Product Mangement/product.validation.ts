import z from "zod";

// step: claude: shared HH:mm + window schemas (reused by create/update supplier product)
const hhmm = z
  .string()
  .regex(/^([01]\d|2[0-3]):[0-5]\d$/, "Invalid time format, expected HH:mm");

const orderWindowSchema = z
  .object({
    day_of_week: z.number().int().min(0).max(6),
    time_from: hhmm,
    time_to: hhmm,
  })
  .refine((d) => d.time_from < d.time_to, {
    message: "time_from must be before time_to",
    path: ["time_to"],
  });

const deliveryWindowSchema = z
  .object({
    day_of_week: z.number().int().min(0).max(6),
    time_from: hhmm,
    time_to: hhmm,
    max_orders: z.number().int().positive().optional(),
  })
  .refine((d) => d.time_from < d.time_to, {
    message: "time_from must be before time_to",
    path: ["time_to"],
  });

export const createSupplierProductSchema = z.object({
  product_id: z.number(),
  price: z.number(),
  cost_price: z.number(),
  stock: z.number(),
  min_stock: z.number(),
  is_active: z.boolean().optional(),
  // is_featured: z.boolean().optional(),
  max_amount_for_one_order: z.number().optional(),
  max_amount_for_one_user: z.number().optional(),
  min_amount_for_one_order: z.number().optional(),
  min_amount_for_one_user: z.number().optional(),
  reserved_in_carts_amount: z.number().optional(),
  pickup_ready_duration: z.number().optional(),
  // step: claude: type-3 windows — required at runtime when the product's category has_window=true.
  // requires_delivery_windows is NOT accepted here; it's derived from the category's has_window flag.
  order_windows: z.array(orderWindowSchema).optional(),
  delivery_windows: z.array(deliveryWindowSchema).optional(),
});

export const updateSupplierProductSchema = z
  .object({
    price: z.number().optional(),
    cost_price: z.number().optional(),
    stock: z.number().optional(),
    min_stock: z.number().optional(),
    is_active: z.boolean().optional(),
    // is_featured: z.boolean().optional(),
    max_amount_for_one_order: z.number().optional(),
    max_amount_for_one_user: z.number().optional(),
    min_amount_for_one_order: z.number().optional(),
    min_amount_for_one_user: z.number().optional(),
    reserved_in_carts_amount: z.number().optional(),
    pickup_ready_duration: z.number().optional(),
    estimated_time_from: z.number().optional(),
    estimated_time_to: z.number().optional(),
    // step: claude: type-3 windows — required at runtime when the product's category has_window=true.
    // requires_delivery_windows is NOT accepted here; it's derived from the category's has_window flag.
    order_windows: z.array(orderWindowSchema).optional(),
    delivery_windows: z.array(deliveryWindowSchema).optional(),
  })
  .refine((data) => Object.values(data).some((v) => v !== undefined), {
    message: "At least one field must be provided for update",
  });

// step: claude: schema for setting a product's type-3 ORDER + DELIVERY windows (replaces the whole set)
export const setDeliveryWindowsSchema = z.object({
  order_windows: z.array(orderWindowSchema).min(1),
  delivery_windows: z.array(deliveryWindowSchema).min(1),
});

// ─── Supplier Offer Schemas ───────────────────────────────────────────────────
// Supplier offers require both price + cost_price so the SupplierProduct record
// is updated atomically with the offer. Admins only need offer_type/offer_value
// (they use whatever price is already on the product).

export const createSupplierOfferSchema = z
  .object({
    supplier_product_id: z.coerce.number().int().positive(),
    offer_type: z.enum(["PERCENT", "FIXED_CENTS"]),
    offer_value: z.coerce.number().positive(),
    // price updates SupplierProduct.price; cost_price is stored for the supplier's
    // margin visibility only — no restriction on effective price vs cost.
    start_date: z.coerce.date(),
    end_date: z.coerce.date(),
    is_active: z.coerce.boolean().optional().default(true),
  })
  .refine((d) => d.end_date > d.start_date, {
    message: "end_date must be after start_date",
    path: ["end_date"],
  });

export const updateSupplierOfferSchema = z
  .object({
    offer_type: z.enum(["PERCENT", "FIXED_CENTS"]).optional(),
    offer_value: z.coerce.number().positive().optional(),
    start_date: z.coerce.date().optional(),
    end_date: z.coerce.date().optional(),
    is_active: z.coerce.boolean().optional(),
  })
  .refine((d) => Object.values(d).some((v) => v !== undefined), {
    message: "At least one field must be provided for update",
  })
  .refine(
    (d) => {
      if (d.start_date && d.end_date) return d.end_date > d.start_date;
      return true;
    },
    { message: "end_date must be after start_date", path: ["end_date"] },
  );

export const createProductSchema = z.object({
  name: z.string(),
  name_ar: z.string(),
  description: z.string(),
  description_ar: z.string(),
  sku: z.string(),
  barcode: z.string().optional(),
  slug: z.string().optional(),
  synonyms: z.string().optional(),
  images: z.string().optional(),
  weight: z.number().optional(),
  dimensions: z.string().optional(),
  category_id: z.number(),
  brand_id: z.number().optional(),
  sort_id: z.number().optional(),
  color: z.string().optional(),
  refund_policy: z.string().optional(),
  refundable: z.boolean().optional(),
  refundable_period: z.number().optional(),
});

export const updateProductSchema = z
  .object({
    name: z.string().optional(),
    name_ar: z.string().optional(),
    description: z.string().optional(),
    description_ar: z.string().optional(),
    sku: z.string().optional(),
    barcode: z.string().optional(),
    slug: z.string().optional(),
    synonyms: z.string().optional(),
    images: z.string().optional(),
    weight: z.number().optional(),
    dimensions: z.string().optional(),
    category_id: z.number().optional(),
    brand_id: z.number().optional(),
    sort_id: z.number().optional(),
    color: z.string().optional(),
    refund_policy: z.string().optional(),
    refundable: z.boolean().optional(),
    refundable_period: z.number().optional(),
  })
  .refine((data) => Object.values(data).some((v) => v !== undefined), {
    message: "At least one field must be provided for update",
  });
