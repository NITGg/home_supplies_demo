import type { Request, Response } from "express";
import FeatureApi from "@/lib/featureApi";
import type { AuthedRequest } from "@/types/authedRequest";
import {
  createProductSchema,
  updateProductSchema,
  reorderProductsSchema,
  deleteProductsSchema,
  productIdParamSchema,
  supplierProductSchema,
  // updateSupplierProductSchema,
  supplierProductParamSchema,
  listProductsLocationSchema,
} from "./products.schema";
import {
  createProductService,
  updateProductService,
  listProductsService,
  getProductByIdService,
  reorderProductsService,
  deleteProductsService,
  deleteProductService,
  supplierProductService,
  // updateSupplierProductService,
  deleteSupplierProductService,
  listSupplierProductsService,
  getSupplierProductByIdService,
  getProductSuppliersService,
  updateSupplierProductService,
  listLastBoughtSupplierProductsService,
  listBestSellerSupplierProductsService,
  resetSupplierProductPriceService,
  listAllSupplierProductsService,
} from "./products.service";
import { bus } from "@/events/bus";
import { Prisma } from "@prisma/client";
import { activeOfferWhere } from "@/lib/catalogHelpers";

// ─── Public / Shared ──────────────────────────────────────────────────────────

export async function listProducts(req: Request, res: Response) {
  const isAdmin = (req as AuthedRequest).user?.role?.name === "Admin";
  const supplierId = req.sanitized.query.supplier_id
    ? Number(req.sanitized.query.supplier_id)
    : null;
  const lastBought = req.sanitized.query.last_bought === "true";
  const bestSeller = req.sanitized.query.best_seller === "true";
  const hasOffers = req.sanitized.query.has_offers === "true";
  const api = new FeatureApi(req);

  const keywordFields = [
    "product.name",
    "product.name_ar",
    "product.sku",
    "product.barcode",
    "product.slug",
    "product.synonyms",
  ];

  // has_offers=true → only supplier-products with an active offer
  const offersFilter = hasOffers
    ? { offers: { some: activeOfferWhere() } }
    : {};

  if (isAdmin) {
    api.filter(offersFilter);
  } else if (supplierId) {
    api.filter(
      {
        deleted_at: null,
        is_active: true,
        supplier_id: supplierId,
        supplier: {
          is_approved: true,
          deleted_at: null,
        },
        product: {
          category: {
            is_active: true,
            deleted_at: null,
          },
        },
        ...offersFilter,
      },
      {
        allowKeys: [
          "product",
          "is_featured",
          "is_best_seller",
          "category_id",
          "offers",
        ],
      },
    );
  } else {
    api.filter(
      {
        deleted_at: null,
        is_active: true,
        supplier: {
          is_approved: true,
          deleted_at: null,
        },
        ...offersFilter,
      },
      { allowKeys: ["suppliers", "category_id", "product"] },
    );
  }

  const data = api
    .fields()
    .skip()
    .sort()
    .limit(10)
    .includes()
    .keyword(keywordFields, "OR").data;

  // current customer location from body (radius / governorate / cheapest
  // behaviour is controlled globally via ApplicationSetting).
  const locationOptions = listProductsLocationSchema.parse(
    req.sanitized.body ?? {},
  );
  delete data?.where?.has_offers;

  // last_bought=true → override to last-bought query
  // (supplier-scoped when supplier_id is set, otherwise across all suppliers)
  if (lastBought) {
    const customerId = req.user?.id;
    if (!customerId)
      return res.status(401).json({
        message: req.t("auth:errors.unauthorized"),
        code: "UNAUTHORIZED",
      });

    // extract product-level filters from the parsed where
    const where = data.where as Prisma.SupplierProductWhereInput;

    let productWhere: Prisma.ProductWhereInput | undefined;

    if (where.OR) {
      productWhere = {
        OR: where.OR.filter((item: any) => item.product).map(
          (item: any) => item.product,
        ),
      };
    } else {
      productWhere = where.product as Prisma.ProductWhereInput;
    }

    const result = await listLastBoughtSupplierProductsService(
      supplierId,
      customerId,
      productWhere,
    );
    return res.json(result);
  }

  if (bestSeller) {
    const where = data.where as Prisma.SupplierProductWhereInput;

    let productWhere: Prisma.ProductWhereInput | undefined;

    if (where.OR) {
      productWhere = {
        OR: where.OR.filter((item: any) => item.product).map(
          (item: any) => item.product,
        ),
      };
    } else {
      productWhere = where.product as Prisma.ProductWhereInput;
    }

    const result = await listBestSellerSupplierProductsService(
      supplierId,
      productWhere,
      locationOptions,
    );

    return res.json(result);
  }

  if (supplierId) {
    const result = await listSupplierProductsService(data);
    return res.json(result);
  }

  // const result = await listProductsService(data);
  const result = await listAllSupplierProductsService(data, locationOptions);
  return res.json(result);
}

export async function listBaseProducts(req: Request, res: Response) {
  const api = new FeatureApi(req);

  const keywordFields = [
    "name",
    "name_ar",
    "sku",
    "barcode",
    "slug",
    "synonyms",
  ];

  api.filter({ deleted_at: null });

  const data = api
    .fields()
    .skip()
    .sort()
    .limit(10)
    .includes()
    .keyword(keywordFields, "OR").data;

  const result = await listProductsService(data);
  return res.json(result);
}

export async function getProduct(req: Request, res: Response) {
  const isAdmin = (req as AuthedRequest).user?.role?.name === "Admin";
  const { id } = productIdParamSchema.parse(req.sanitized.params);
  const supplierId = req.sanitized.query.supplier_id
    ? Number(req.sanitized.query.supplier_id)
    : null;

  const api = new FeatureApi(req);

  if (isAdmin) {
    api.filter({ id });
  } else {
    api.filter({ id, deleted_at: null }, { allowKeys: [] });
  }

  const data = api.fields().includes().data;

  // ✅ IF supplier_id → use supplierProduct flow
  if (supplierId) {
    const product = await getSupplierProductByIdService(id, supplierId);
    return res.json({
      message: req.t("products:messages.success"),
      product,
    });
  }

  // ✅ default
  const product = await getProductByIdService(data);

  return res.json({
    message: req.t("products:messages.success"),
    product,
  });
}

// ─── Admin: Product CRUD ──────────────────────────────────────────────────────

export async function adminCreateProduct(
  req: AuthedRequest<"Admin">,
  res: Response,
) {
  const admin = req.user;
  const data = createProductSchema.parse(req.sanitized.body);
  const query = new FeatureApi(req).fields().data;
  const files = req.files as { [fieldname: string]: Express.Multer.File[] };

  const product = await createProductService(data, query, files);
  bus.emit("syncProduct", { action: "create", product, admin });

  return res.status(201).json({
    message: req.t("products:messages.created"),
    product,
  });
}

export async function adminUpdateProduct(
  req: AuthedRequest<"Admin">,
  res: Response,
) {
  const admin = req.user;
  const { id } = productIdParamSchema.parse(req.sanitized.params);
  const data = updateProductSchema.parse(req.sanitized.body);
  const query = new FeatureApi(req).fields().data;
  const files = req.files as { [fieldname: string]: Express.Multer.File[] };

  const product = await updateProductService({ id, data, query, files });
  bus.emit("syncProduct", { action: "update", product, admin });

  return res.json({
    message: req.t("products:messages.updated"),
    product,
  });
}

export async function adminDeleteSingleProduct(
  req: AuthedRequest,
  res: Response,
) {
  const { id } = productIdParamSchema.parse(req.sanitized.params);
  const archived = req.sanitized.query.archived === "true";
  const permanent = req.sanitized.query.permanent === "true";

  await deleteProductService({ id, archived, permanent });

  return res.json({
    message: archived
      ? req.t("products:messages.archived")
      : req.t("products:messages.deleted"),
  });
}

export async function adminBulkDeleteProducts(
  req: AuthedRequest,
  res: Response,
) {
  const data = deleteProductsSchema.parse(req.sanitized.body);
  await deleteProductsService(data);

  return res.json({ message: req.t("products:messages.deleted") });
}

export async function adminReorderProducts(req: AuthedRequest, res: Response) {
  const data = reorderProductsSchema.parse(req.sanitized.body);
  await reorderProductsService(data);

  return res.json({ message: req.t("products:messages.reordered") });
}

// ─── Admin: SupplierProduct ───────────────────────────────────────────────────

export async function adminGetProductSuppliers(
  req: AuthedRequest,
  res: Response,
) {
  const { id } = productIdParamSchema.parse(req.params);
  const supplierProducts = await getProductSuppliersService(id);
  return res.json({ supplierProducts });
}

export async function adminUpdateSupplierProduct(
  req: AuthedRequest,
  res: Response,
) {
  const { id, spId } = supplierProductParamSchema.parse(req.params);
  const data = supplierProductSchema
    .omit({ supplier_id: true })
    .partial()
    .parse(req.body);
  const supplierProduct = await updateSupplierProductService(id, spId, data);
  return res.json({
    message: req.t("products:messages.supplier_product_created"),
    supplierProduct,
  });
}

export async function adminCreateSupplierProduct(
  req: AuthedRequest,
  res: Response,
) {
  const { id } = productIdParamSchema.parse(req.sanitized.params);
  const data = supplierProductSchema.parse(req.sanitized.body);

  const supplierProduct = await supplierProductService(id, data);

  return res.status(201).json({
    message: req.t("products:messages.supplier_product_created"),
    supplierProduct,
  });
}

export async function adminDeleteSupplierProduct(
  req: AuthedRequest,
  res: Response,
) {
  const { id, spId } = supplierProductParamSchema.parse(req.sanitized.params);
  await deleteSupplierProductService(id, spId);

  return res.json({
    message: req.t("products:messages.supplier_product_deleted"),
  });
}

export async function adminResetSupplierProductPrice(
  req: AuthedRequest,
  res: Response,
) {
  const { id, spId } = supplierProductParamSchema.parse(req.sanitized.params);
  const sp = await resetSupplierProductPriceService(id, spId);

  return res.json({
    message: req.t("products:messages.supplier_product_price_reset"),
    supplierProduct: sp,
  });
}

// ─── Reviews ──────────────────────────────────────────────────────────────────

export async function getProductReviews(req: Request, res: Response) {
  const { id } = productIdParamSchema.parse(req.sanitized.params);

  const data = new FeatureApi(req)
    .filter({ productId: id })
    .fields()
    .sort()
    .skip()
    .limit(10)
    .includes()
    .keyword(
      ["user.full_name", "user.email", "user.phone", "comment"],
      "OR",
    ).data;

  (data.where as any).status = "APPROVED";

  return res.json({ message: req.t("products:messages.success") });
}
