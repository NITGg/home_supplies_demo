import { NextFunction, Request, Response } from "express";
import { AppError } from "../../core/errors/app.error";
import { responseHandler } from "../../core/handlers/response.handler";
import { HttpStatusCode } from "../../core/http/http.status.code";
import { prisma } from "../../DB/lib/prisma";
import { Prisma } from "@prisma/client";
import FeatureApi from "../../utils/featureApi";
import {
  createProductDTO,
  createSupplierProductDTO,
  updateProductDTO,
  updateSupplierProductDTO,
  setDeliveryWindowsDTO,
  createSupplierOfferDTO,
  updateSupplierOfferDTO,
} from "./product.dto";
import Fuse from "fuse.js";

export class OrderService {
  constructor() {}

  // ============================ replaceDeliveryWindows (helper) ============================
  // step: claude: atomically replace a supplier product's ORDER + DELIVERY windows.
  // shared by create/update supplier product (was the /set-supplier-product-delivery-windows logic).
  private replaceDeliveryWindows = async (
    tx: Prisma.TransactionClient,
    supplierProductId: number,
    order_windows: setDeliveryWindowsDTO["order_windows"],
    delivery_windows: setDeliveryWindowsDTO["delivery_windows"],
  ) => {
    await tx.supplierProductDeliveryWindow.deleteMany({
      where: { supplier_product_id: supplierProductId },
    });
    await tx.supplierProductDeliveryWindow.createMany({
      data: [
        ...order_windows.map((w) => ({
          supplier_product_id: supplierProductId,
          window_type: "ORDER" as const,
          day_of_week: w.day_of_week,
          time_from: w.time_from,
          time_to: w.time_to,
        })),
        ...delivery_windows.map((w) => ({
          supplier_product_id: supplierProductId,
          window_type: "DELIVERY" as const,
          day_of_week: w.day_of_week,
          time_from: w.time_from,
          time_to: w.time_to,
          max_orders: w.max_orders ?? null,
        })),
      ],
    });
  };

  // ============================ createSupplierProduct ============================
  createSupplierProduct = async (
    req: Request,
    res: Response,
    next: NextFunction,
  ) => {
    const user = res.locals.user;
    // step: validate request body
    const {
      product_id,
      price,
      cost_price,
      stock,
      min_stock,
      is_active,
      // is_featured,
      max_amount_for_one_order,
      max_amount_for_one_user,
      min_amount_for_one_order,
      min_amount_for_one_user,
      reserved_in_carts_amount,
      pickup_ready_duration,
      order_windows,
      delivery_windows,
    }: createSupplierProductDTO = req.body;

    // step: get Supplier
    const supplier = await prisma.supplier.findUnique({
      where: { user_id: user.id },
    });
    if (!supplier) {
      throw new AppError(
        HttpStatusCode.NOT_FOUND,
        res.__("errors.supplier_not_found"),
      );
    }

    // step: check if product exists
    const product = await prisma.product.findUnique({
      where: { id: product_id },
    });
    if (!product) {
      throw new AppError(
        HttpStatusCode.NOT_FOUND,
        res.__("errors.product_not_found"),
      );
    }

    // step: claude: does this product's category require type-3 delivery windows?
    const category = await prisma.category.findUnique({
      where: { id: product.category_id },
      select: { has_window: true },
    });
    const requiresWindows = category?.has_window === true;

    // step: claude: type-3 categories must include both ORDER + DELIVERY windows in the body
    if (
      requiresWindows &&
      (!order_windows?.length || !delivery_windows?.length)
    ) {
      throw new AppError(
        HttpStatusCode.BAD_REQUEST,
        res.__("errors.delivery_windows_required"),
      );
    }

    // step: claude: non-type-3 categories must NOT include delivery windows
    if (
      !requiresWindows &&
      (order_windows?.length || delivery_windows?.length)
    ) {
      throw new AppError(
        HttpStatusCode.BAD_REQUEST,
        res.__("errors.delivery_windows_not_allowed"),
      );
    }

    // step: check if supplier product already exists
    const existingSupplierProduct = await prisma.supplierProduct.findUnique({
      where: {
        supplier_id_product_id: {
          supplier_id: supplier.id,
          product_id,
        },
      },
    });
    if (existingSupplierProduct) {
      throw new AppError(
        HttpStatusCode.CONFLICT,
        res.__("errors.supplier_product_already_exists"),
      );
    }

    // Auto-compute selling price from cost_price × supplier's markup_ratio
    const resolvedPrice =
      price !== undefined
        ? price
        : cost_price !== undefined && supplier.markup_ratio != null
          ? Math.round(cost_price * supplier.markup_ratio * 100) / 100
          : price;

    // step: create supplier product (+ delivery windows when the category is type-3)
    const createdSupplierProduct = await prisma.$transaction(async (tx) => {
      const created = await tx.supplierProduct.create({
        data: {
          supplier_id: supplier.id,
          product_id,
          price: resolvedPrice,
          cost_price,
          stock,
          min_stock,
          ...(is_active !== undefined && { is_active }),
          // ...(is_featured !== undefined && { is_featured }),
          ...(max_amount_for_one_order !== undefined && {
            max_amount_for_one_order,
          }),
          ...(max_amount_for_one_user !== undefined && {
            max_amount_for_one_user,
          }),
          ...(min_amount_for_one_order !== undefined && {
            min_amount_for_one_order,
          }),
          ...(min_amount_for_one_user !== undefined && {
            min_amount_for_one_user,
          }),
          ...(reserved_in_carts_amount !== undefined && {
            reserved_in_carts_amount,
          }),
          ...(pickup_ready_duration !== undefined && { pickup_ready_duration }),
          // step: claude: flag is derived from the category — true for type-3, false otherwise
          requires_delivery_windows: requiresWindows,
        },
      });

      // step: create supplier category
      const supplierCategory = await tx.supplierCategory.upsert({
        where: {
          supplier_id_category_id: {
            supplier_id: supplier.id,
            category_id: product.category_id,
          },
        },
        update: { deleted_at: null },
        create: {
          supplier_id: supplier.id,
          category_id: product.category_id,
        },
      });

      // step: claude: persist the type-3 ORDER + DELIVERY windows for this product
      if (requiresWindows) {
        await this.replaceDeliveryWindows(
          tx,
          created.id,
          order_windows!,
          delivery_windows!,
        );
      }

      return created;
    });

    // step: claude: surface the configured windows alongside the created product
    const windows = requiresWindows
      ? await prisma.supplierProductDeliveryWindow.findMany({
          where: { supplier_product_id: createdSupplierProduct.id },
          orderBy: [
            { window_type: "asc" },
            { day_of_week: "asc" },
            { time_from: "asc" },
          ],
        })
      : [];

    return responseHandler({
      res,
      message: res.__("messages.supplier_product_created"),
      data: { supplierProduct: createdSupplierProduct, windows },
    });
  };

  // ============================ listSupplierProducts ============================
  listSupplierProducts = async (
    req: Request,
    res: Response,
    next: NextFunction,
  ) => {
    const user = res.locals.user;

    // step: get Supplier
    const supplier = await prisma.supplier.findUnique({
      where: { user_id: user.id },
    });
    if (!supplier) {
      throw new AppError(
        HttpStatusCode.NOT_FOUND,
        res.__("errors.supplier_not_found"),
      );
    }

    // step: get query options
    const queryOptions = new FeatureApi(req) // queryOptions :{where, orderBy, take, skip}
      .filter({})
      .sort("-created_at") // ?sort=-created_at
      .limit(10) // ?limit=10
      .skip(0) // ?skip=0
      .includes("product") // ?includes=role=id-name,wallet,penalties
      .keyword([]) // ?keyword=xxx&items=name,description
      .fields().data; // ?fields=id,name,description

    // Ensure we only query the current supplier's products
    if (!queryOptions.where) {
      queryOptions.where = {};
    }
    queryOptions.where.supplier_id = supplier.id;

    // step: get SupplierProducts
    const [totalSupplierProducts, supplierProducts] = await prisma.$transaction(
      [
        prisma.supplierProduct.count({
          where: queryOptions.where,
        }),
        prisma.supplierProduct.findMany(queryOptions as any),
      ],
    );

    return responseHandler({
      res,
      message: res.__("messages.done"),
      data: {
        totalSupplierProducts,
        totalPages: Math.ceil(
          totalSupplierProducts / (queryOptions.take ?? 10),
        ),
        supplierProducts,
      },
    });
  };

  // ============================ updateSupplierProduct ============================
  updateSupplierProduct = async (
    req: Request,
    res: Response,
    next: NextFunction,
  ) => {
    // step: validate request body
    const { supplierProductId } = req.params;
    const {
      price,
      cost_price,
      stock,
      min_stock,
      is_active,
      // is_featured,
      max_amount_for_one_order,
      max_amount_for_one_user,
      min_amount_for_one_order,
      min_amount_for_one_user,
      reserved_in_carts_amount,
      pickup_ready_duration,
      estimated_time_from,
      estimated_time_to,
      order_windows,
      delivery_windows,
    }: updateSupplierProductDTO = req.body;

    // step: get supplier + supplier product (need markup_ratio for auto-price)
    const user = res.locals.user;
    const [supplierProduct, supplierRecord] = await Promise.all([
      prisma.supplierProduct.findUnique({
        where: { id: Number(supplierProductId) },
      }),
      prisma.supplier.findUnique({
        where: { user_id: user.id },
        select: { markup_ratio: true },
      }),
    ]);
    if (!supplierProduct) {
      throw new AppError(
        HttpStatusCode.NOT_FOUND,
        res.__("errors.product_not_found"),
      );
    }

    // step: claude: does this product's category require type-3 delivery windows?
    const productWithCategory = await prisma.product.findUnique({
      where: { id: supplierProduct.product_id },
      select: { category: { select: { has_window: true } } },
    });
    const requiresWindows = productWithCategory?.category?.has_window === true;

    // step: claude: type-3 categories must include both ORDER + DELIVERY windows in the body
    if (
      requiresWindows &&
      (!order_windows?.length || !delivery_windows?.length)
    ) {
      throw new AppError(
        HttpStatusCode.BAD_REQUEST,
        res.__("errors.delivery_windows_required"),
      );
    }

    // step: claude: non-type-3 categories must NOT include delivery windows
    if (
      !requiresWindows &&
      (order_windows?.length || delivery_windows?.length)
    ) {
      throw new AppError(
        HttpStatusCode.BAD_REQUEST,
        res.__("errors.delivery_windows_not_allowed"),
      );
    }

    // Resolve effective cost_price and price for this update
    const effectiveCostPrice =
      cost_price !== undefined
        ? Number(cost_price)
        : supplierProduct.cost_price;

    // If caller provides price explicitly, use it.
    // If caller updates cost_price but leaves price untouched AND we have a markup_ratio,
    // recompute price from the new cost_price × markup_ratio.
    let effectivePrice: number | null;
    if (price !== undefined) {
      effectivePrice = Number(price);
    } else if (
      cost_price !== undefined &&
      supplierRecord?.markup_ratio != null &&
      effectiveCostPrice != null
    ) {
      effectivePrice =
        Math.round(effectiveCostPrice * supplierRecord.markup_ratio * 100) /
        100;
    } else {
      effectivePrice = supplierProduct.price;
    }

    // step: update supplier product (+ replace delivery windows when the category is type-3)
    const updatedSupplierProduct = await prisma.$transaction(async (tx) => {
      const updated = await tx.supplierProduct.update({
        where: { id: Number(supplierProductId) },
        data: {
          price: effectivePrice,
          cost_price: effectiveCostPrice,
          stock: stock !== undefined ? Number(stock) : supplierProduct.stock,
          min_stock:
            min_stock !== undefined
              ? Number(min_stock)
              : supplierProduct.min_stock,
          is_active:
            is_active !== undefined ? is_active : supplierProduct.is_active,
          // is_featured:
          //   is_featured !== undefined
          //     ? is_featured
          //     : supplierProduct.is_featured,
          max_amount_for_one_order:
            max_amount_for_one_order !== undefined
              ? Number(max_amount_for_one_order)
              : supplierProduct.max_amount_for_one_order,
          max_amount_for_one_user:
            max_amount_for_one_user !== undefined
              ? Number(max_amount_for_one_user)
              : supplierProduct.max_amount_for_one_user,
          min_amount_for_one_order:
            min_amount_for_one_order !== undefined
              ? Number(min_amount_for_one_order)
              : supplierProduct.min_amount_for_one_order,
          min_amount_for_one_user:
            min_amount_for_one_user !== undefined
              ? Number(min_amount_for_one_user)
              : supplierProduct.min_amount_for_one_user,
          reserved_in_carts_amount:
            reserved_in_carts_amount !== undefined
              ? Number(reserved_in_carts_amount)
              : supplierProduct.reserved_in_carts_amount,
          pickup_ready_duration:
            pickup_ready_duration !== undefined
              ? Number(pickup_ready_duration)
              : supplierProduct.pickup_ready_duration,
          estimated_time_from:
            Number(estimated_time_from) === 0 && Number(estimated_time_to) === 0
              ? null
              : estimated_time_from !== undefined
                ? Number(estimated_time_from)
                : supplierProduct.estimated_time_from,
          estimated_time_to:
            Number(estimated_time_from) === 0 && Number(estimated_time_to) === 0
              ? null
              : estimated_time_to !== undefined
                ? Number(estimated_time_to)
                : supplierProduct.estimated_time_to,
          // step: claude: flag is derived from the category — keeps it in sync with has_window
          requires_delivery_windows: requiresWindows,
        },
      });

      // step: claude: replace the type-3 ORDER + DELIVERY windows for this product
      if (requiresWindows) {
        await this.replaceDeliveryWindows(
          tx,
          updated.id,
          order_windows!,
          delivery_windows!,
        );
      }

      return updated;
    });

    // step: claude: surface the configured windows alongside the updated product
    const windows = requiresWindows
      ? await prisma.supplierProductDeliveryWindow.findMany({
          where: { supplier_product_id: updatedSupplierProduct.id },
          orderBy: [
            { window_type: "asc" },
            { day_of_week: "asc" },
            { time_from: "asc" },
          ],
        })
      : [];

    return responseHandler({
      res,
      message: res.__("messages.supplier_product_updated"),
      data: { supplierProduct: updatedSupplierProduct, windows },
    });
  };

  // ============================ deleteSupplierProduct ============================
  deleteSupplierProduct = async (
    req: Request,
    res: Response,
    next: NextFunction,
  ) => {
    const { supplierProductId } = req.params;
    const user = res.locals.user;

    // step: get Supplier
    const supplier = await prisma.supplier.findUnique({
      where: { user_id: user.id },
    });
    if (!supplier) {
      throw new AppError(
        HttpStatusCode.NOT_FOUND,
        res.__("errors.supplier_not_found"),
      );
    }

    // step: get supplier product
    const supplierProduct = await prisma.supplierProduct.findUnique({
      where: { id: Number(supplierProductId) },
      include: { product: true },
    });
    if (!supplierProduct) {
      throw new AppError(
        HttpStatusCode.NOT_FOUND,
        res.__("errors.supplier_product_not_found"),
      );
    }

    // step: verify the product belongs to this supplier
    if (supplierProduct.supplier_id !== supplier.id) {
      throw new AppError(
        HttpStatusCode.FORBIDDEN,
        res.__("errors.supplier_product_not_related_to_supplier"),
      );
    }

    // step: delete supplier product
    try {
      await prisma.supplierProduct.delete({
        where: { id: Number(supplierProductId) },
      });
    } catch (error: any) {
      if (
        error instanceof Prisma.PrismaClientKnownRequestError &&
        error.code === "P2003"
      ) {
        throw new AppError(
          HttpStatusCode.CONFLICT,
          res.__("errors.supplier_product_in_use"),
        );
      }
      throw error;
    }

    // step: delete supplier category
    const remainingProductsInCategory = await prisma.supplierProduct.count({
      where: {
        supplier_id: supplier.id,
        product: {
          category_id: supplierProduct.product.category_id,
        },
      },
    });

    if (remainingProductsInCategory === 0) {
      await prisma.supplierCategory.deleteMany({
        where: {
          supplier_id: supplier.id,
          category_id: supplierProduct.product.category_id,
        },
      });
    }

    return responseHandler({
      res,
      message: res.__("messages.supplier_product_deleted"),
      data: { supplierProduct },
    });
  };

  // ============================ setSupplierProductDeliveryWindows ============================
  // step: claude: replace a product's ORDER + DELIVERY windows in one call and mark it type-3
  setSupplierProductDeliveryWindows = async (
    req: Request,
    res: Response,
    next: NextFunction,
  ) => {
    const { supplierProductId, supplierId } = req.params;
    const { order_windows, delivery_windows }: setDeliveryWindowsDTO = req.body;
    const user = res.locals.user;

    // step: claude: resolve supplier and verify ownership of the product
    const supplier = await prisma.supplier.findUnique({
      where: { id: Number(supplierId) },
    });
    if (!supplier) {
      throw new AppError(
        HttpStatusCode.NOT_FOUND,
        res.__("errors.supplier_not_found"),
      );
    }
    const supplierProduct = await prisma.supplierProduct.findUnique({
      where: { id: Number(supplierProductId) },
    });
    if (!supplierProduct) {
      throw new AppError(
        HttpStatusCode.NOT_FOUND,
        res.__("errors.supplier_product_not_found"),
      );
    }
    if (supplierProduct.supplier_id !== supplier.id) {
      throw new AppError(
        HttpStatusCode.FORBIDDEN,
        res.__("errors.supplier_product_not_related_to_supplier"),
      );
    }

    // step: claude: atomically replace the whole window set and enable the type-3 flag
    await prisma.$transaction(async (tx) => {
      await tx.supplierProductDeliveryWindow.deleteMany({
        where: { supplier_product_id: supplierProduct.id },
      });
      await tx.supplierProductDeliveryWindow.createMany({
        data: [
          ...order_windows.map((w) => ({
            supplier_product_id: supplierProduct.id,
            window_type: "ORDER" as const,
            day_of_week: w.day_of_week,
            time_from: w.time_from,
            time_to: w.time_to,
          })),
          ...delivery_windows.map((w) => ({
            supplier_product_id: supplierProduct.id,
            window_type: "DELIVERY" as const,
            day_of_week: w.day_of_week,
            time_from: w.time_from,
            time_to: w.time_to,
            max_orders: w.max_orders ?? null,
          })),
        ],
      });
      await tx.supplierProduct.update({
        where: { id: supplierProduct.id },
        data: { requires_delivery_windows: true },
      });
    });

    const windows = await prisma.supplierProductDeliveryWindow.findMany({
      where: { supplier_product_id: supplierProduct.id },
      orderBy: [
        { window_type: "asc" },
        { day_of_week: "asc" },
        { time_from: "asc" },
      ],
    });

    return responseHandler({
      res,
      message: res.__("messages.delivery_windows_updated"),
      data: { windows },
    });
  };

  // ============================ getSupplierProductDeliveryWindows ============================
  // step: claude: list a product's configured ORDER + DELIVERY windows
  getSupplierProductDeliveryWindows = async (
    req: Request,
    res: Response,
    next: NextFunction,
  ) => {
    const { supplierProductId, supplierId } = req.params;
    const user = res.locals.user;

    const supplier = await prisma.supplier.findUnique({
      where: { id: Number(supplierId) },
    });
    if (!supplier) {
      throw new AppError(
        HttpStatusCode.NOT_FOUND,
        res.__("errors.supplier_not_found"),
      );
    }
    const supplierProduct = await prisma.supplierProduct.findUnique({
      where: { id: Number(supplierProductId) },
      select: { id: true, supplier_id: true, requires_delivery_windows: true },
    });
    if (!supplierProduct) {
      throw new AppError(
        HttpStatusCode.NOT_FOUND,
        res.__("errors.supplier_product_not_found"),
      );
    }
    if (supplierProduct.supplier_id !== supplier.id) {
      throw new AppError(
        HttpStatusCode.FORBIDDEN,
        res.__("errors.supplier_product_not_related_to_supplier"),
      );
    }

    const windows = await prisma.supplierProductDeliveryWindow.findMany({
      where: { supplier_product_id: supplierProduct.id },
      orderBy: [
        { window_type: "asc" },
        { day_of_week: "asc" },
        { time_from: "asc" },
      ],
    });

    return responseHandler({
      res,
      message: res.__("messages.delivery_windows_retrieved"),
      data: {
        requires_delivery_windows: supplierProduct.requires_delivery_windows,
        windows,
      },
    });
  };

  // ============================ createProduct ============================
  createProduct = async (req: Request, res: Response, next: NextFunction) => {
    const user = res.locals.user;
    const {
      name,
      name_ar,
      description,
      description_ar,
      sku,
      barcode,
      slug,
      synonyms,
      images,
      weight,
      dimensions,
      category_id,
      brand_id,
      sort_id,
      color,
      refund_policy,
      refundable,
      refundable_period,
    }: createProductDTO = req.body;

    // step: find category
    const category = await prisma.category.findUnique({
      where: { id: category_id },
    });
    if (!category) {
      throw new AppError(
        HttpStatusCode.NOT_FOUND,
        res.__("errors.category_not_found"),
      );
    }

    // step: create product
    const product = await prisma.product.create({
      data: {
        name,
        name_ar,
        description,
        description_ar,
        sku,
        barcode: barcode ?? null,
        slug: slug ?? null,
        synonyms: synonyms ?? null,
        images: images ?? null,
        weight: weight ?? null,
        dimensions: dimensions ?? null,
        category_id,
        brand_id: brand_id ?? null,
        sort_id: sort_id ?? 0,
        color: color ?? null,
        refund_policy: refund_policy ?? null,
        refundable: refundable ?? null,
        refundable_period: refundable_period ?? null,
      },
    });

    return responseHandler({
      res,
      message: res.__("messages.product_created"),
      data: { product },
    });
  };

  // ============================ listProducts ============================
  listProducts = async (req: Request, res: Response, next: NextFunction) => {
    const user = res.locals.user;

    // step: get Supplier
    const supplier = await prisma.supplier.findUnique({
      where: { user_id: user.id },
    });
    if (!supplier) {
      throw new AppError(
        HttpStatusCode.NOT_FOUND,
        res.__("errors.supplier_not_found"),
      );
    }

    // step: get query options (without keyword for now - using Fuse instead)
    const queryOptions = new FeatureApi(req)
      .filter({})
      .sort("-created_at")
      .limit(10)
      .skip(0)
      .includes()
      .fields().data;

    // step: get all products for this supplier
    const whereClause = {
      ...queryOptions.where,
      // suppliers: {
      //   some: {
      //     supplier_id: supplier.id,
      //   },
      // },
    };

    // step: get all products
    const allProducts = await prisma.product.findMany({
      where: whereClause,
      orderBy: queryOptions.orderBy,
    });

    // step: apply Fuse.js fuzzy search if keyword provided
    let filteredProducts = allProducts;
    const keyword = req.query.keyword as string | undefined;
    if (keyword) {
      const fuse = new Fuse(allProducts, {
        keys: [
          "name",
          "name_ar",
          "description",
          "description_ar",
          "synonyms",
          "slug",
        ],
        threshold: 0.4,
        distance: 100,
        includeScore: false,
      });
      filteredProducts = fuse.search(keyword).map((result) => result.item);
    }

    // step: manual pagination after fuzzy filtering
    const limit = queryOptions.take ?? 10;
    const skip = queryOptions.skip ?? 0;
    const paginatedProducts = filteredProducts.slice(skip, skip + limit);

    return responseHandler({
      res,
      message: res.__("messages.done"),
      data: {
        totalProducts: filteredProducts.length,
        totalPages: Math.ceil(filteredProducts.length / limit),
        products: paginatedProducts,
      },
    });
  };

  // ============================ updateProduct ============================
  updateProduct = async (req: Request, res: Response, next: NextFunction) => {
    // step: validate request body
    const { productId } = req.params;
    const {
      name,
      name_ar,
      description,
      description_ar,
      sku,
      barcode,
      slug,
      synonyms,
      images,
      weight,
      dimensions,
      category_id,
      brand_id,
      sort_id,
      color,
      refund_policy,
      refundable,
      refundable_period,
    }: updateProductDTO = req.body;

    // step: get product
    const product = await prisma.product.findUnique({
      where: { id: Number(productId) },
    });
    if (!product) {
      throw new AppError(
        HttpStatusCode.NOT_FOUND,
        res.__("errors.product_not_found"),
      );
    }

    // step: find category if updating category
    if (category_id !== undefined) {
      const category = await prisma.category.findUnique({
        where: { id: category_id },
      });
      if (!category) {
        throw new AppError(
          HttpStatusCode.NOT_FOUND,
          res.__("errors.category_not_found"),
        );
      }
    }
    // step: check sku uniqueness if changing
    if (sku !== undefined && sku !== product.sku) {
      const existingProduct = await prisma.product.findUnique({
        where: { sku },
      });
      if (existingProduct) {
        throw new AppError(
          HttpStatusCode.CONFLICT,
          res.__("errors.sku_already_exists"),
        );
      }
    }

    // step: check barcode uniqueness if changing
    if (
      barcode !== undefined &&
      barcode !== product.barcode &&
      barcode !== null
    ) {
      const existingProduct = await prisma.product.findUnique({
        where: { barcode },
      });
      if (existingProduct) {
        throw new AppError(
          HttpStatusCode.CONFLICT,
          res.__("errors.barcode_already_exists"),
        );
      }
    }

    // step: check slug uniqueness if changing
    if (slug !== undefined && slug !== product.slug && slug !== null) {
      const existingProduct = await prisma.product.findUnique({
        where: { slug },
      });
      if (existingProduct) {
        throw new AppError(
          HttpStatusCode.CONFLICT,
          res.__("errors.slug_already_exists"),
        );
      }
    }

    // step: update product
    const updatedProduct = await prisma.product.update({
      where: { id: Number(productId) },
      data: {
        name: name !== undefined ? name : product.name,
        name_ar: name_ar !== undefined ? name_ar : product.name_ar,
        description:
          description !== undefined ? description : product.description,
        description_ar:
          description_ar !== undefined
            ? description_ar
            : product.description_ar,
        sku: sku !== undefined ? sku : product.sku,
        barcode: barcode !== undefined ? barcode : product.barcode,
        slug: slug !== undefined ? slug : product.slug,
        synonyms: synonyms !== undefined ? synonyms : product.synonyms,
        images: images !== undefined ? images : product.images,
        weight: weight !== undefined ? weight : product.weight,
        dimensions: dimensions !== undefined ? dimensions : product.dimensions,
        category_id:
          category_id !== undefined ? category_id : product.category_id,
        brand_id: brand_id !== undefined ? brand_id : product.brand_id,
        sort_id: sort_id !== undefined ? sort_id : product.sort_id,
        color: color !== undefined ? color : product.color,
        refund_policy:
          refund_policy !== undefined ? refund_policy : product.refund_policy,
        refundable: refundable !== undefined ? refundable : product.refundable,
        refundable_period:
          refundable_period !== undefined
            ? refundable_period
            : product.refundable_period,
      },
    });

    return responseHandler({
      res,
      message: res.__("messages.product_updated"),
      data: { product: updatedProduct },
    });
  };

  // ============================ createOffer ============================
  // Supplier offer creation: price + cost_price are required.
  // price updates SupplierProduct.price; cost_price is for the supplier's own
  // margin visibility and is NOT written to the product (no restriction on
  // effective price vs cost — supplier may offer below their cost).
  // Validates: ownership, no overlapping active offers.
  createOffer = async (req: Request, res: Response, next: NextFunction) => {
    const user = res.locals.user;

    const {
      supplier_product_id,
      offer_type,
      offer_value,
      start_date,
      end_date,
      is_active,
    }: createSupplierOfferDTO = req.body;

    // Resolve the authenticated supplier
    const supplier = await prisma.supplier.findUnique({
      where: { user_id: user.id },
    });
    if (!supplier) {
      throw new AppError(
        HttpStatusCode.NOT_FOUND,
        res.__("errors.supplier_not_found"),
      );
    }

    // Verify the SupplierProduct belongs to this supplier
    const sp = await prisma.supplierProduct.findUnique({
      where: { id: supplier_product_id },
    });
    if (!sp) {
      throw new AppError(
        HttpStatusCode.NOT_FOUND,
        res.__("errors.supplier_product_not_found"),
      );
    }
    if (sp.supplier_id !== supplier.id) {
      throw new AppError(
        HttpStatusCode.FORBIDDEN,
        res.__("errors.supplier_product_not_related_to_supplier"),
      );
    }

    // Coerce to Date objects — Prisma @db.Date fields require full DateTime,
    // not bare date strings like "2026-07-07".
    const startDate = new Date(start_date);
    const endDate = new Date(end_date);

    // No overlapping active offers on this product
    const overlapping = await prisma.offer.findFirst({
      where: {
        supplier_product_id,
        deleted_at: null,
        is_active: true,
        start_date: { lte: endDate },
        end_date: { gte: startDate },
      },
    });
    if (overlapping) {
      throw new AppError(
        HttpStatusCode.CONFLICT,
        res.__("errors.overlapping_offer"),
      );
    }

    // Atomically update only price on the product (cost_price is supplier-side context only)
    const offer = await prisma.offer.create({
      data: {
        supplier_product_id,
        offer_type,
        offer_value,
        start_date: startDate,
        end_date: endDate,
        is_active: is_active ?? true,
        created_by_role: "SUPPLIER",
      },
    });

    return responseHandler({
      res,
      message: res.__("messages.offer_created"),
      data: { offer },
    });
  };

  // ============================ listOffers ============================
  listOffers = async (req: Request, res: Response, next: NextFunction) => {
    const user = res.locals.user;

    const supplier = await prisma.supplier.findUnique({
      where: { user_id: user.id },
    });
    if (!supplier) {
      throw new AppError(
        HttpStatusCode.NOT_FOUND,
        res.__("errors.supplier_not_found"),
      );
    }

    const queryOptions = new FeatureApi(req)
      .filter({})
      .sort("-created_at")
      .limit(10)
      .skip(0)
      .includes()
      .keyword([])
      .fields().data;

    // Scope to this supplier's products only
    const where = {
      ...queryOptions.where,
      deleted_at: null,
      supplierProduct: { supplier_id: supplier.id },
    };

    const [total, offers] = await prisma.$transaction([
      prisma.offer.count({ where }),
      prisma.offer.findMany({ ...queryOptions, where } as any),
    ]);

    return responseHandler({
      res,
      message: res.__("messages.done"),
      data: {
        totalOffers: total,
        totalPages: Math.ceil(total / (queryOptions.take ?? 10)),
        offers,
      },
    });
  };

  // ============================ updateOffer ============================
  updateOffer = async (req: Request, res: Response, next: NextFunction) => {
    const user = res.locals.user;
    const offerId = Number(req.params.offerId);

    const {
      offer_type,
      offer_value,
      start_date,
      end_date,
      is_active,
    }: updateSupplierOfferDTO = req.body;

    const supplier = await prisma.supplier.findUnique({
      where: { user_id: user.id },
    });
    if (!supplier) {
      throw new AppError(
        HttpStatusCode.NOT_FOUND,
        res.__("errors.supplier_not_found"),
      );
    }

    const offer = await prisma.offer.findUnique({
      where: { id: offerId },
      include: {
        supplierProduct: {
          select: {
            id: true,
            supplier_id: true,
            price: true,
            cost_price: true,
          },
        },
      },
    });
    if (!offer || offer.deleted_at) {
      throw new AppError(
        HttpStatusCode.NOT_FOUND,
        res.__("errors.offer_not_found"),
      );
    }
    if (offer.supplierProduct?.supplier_id !== supplier.id) {
      throw new AppError(
        HttpStatusCode.FORBIDDEN,
        res.__("errors.supplier_product_not_related_to_supplier"),
      );
    }

    // Coerce incoming date strings to Date objects before touching Prisma
    const newStart = start_date ? new Date(start_date) : offer.start_date!;
    const newEnd = end_date ? new Date(end_date) : offer.end_date!;

    // Overlap check if dates change
    if (newStart && newEnd) {
      const overlapping = await prisma.offer.findFirst({
        where: {
          id: { not: offerId },
          supplier_product_id: offer.supplier_product_id,
          deleted_at: null,
          is_active: true,
          start_date: { lte: newEnd },
          end_date: { gte: newStart },
        },
      });
      if (overlapping) {
        throw new AppError(
          HttpStatusCode.CONFLICT,
          res.__("errors.overlapping_offer"),
        );
      }
    }

    const updated = await prisma.offer.update({
      where: { id: offerId },
      data: {
        ...(offer_type !== undefined && { offer_type }),
        ...(offer_value !== undefined && { offer_value: Number(offer_value) }),
        ...(start_date !== undefined && { start_date: new Date(start_date) }),
        ...(end_date !== undefined && { end_date: new Date(end_date) }),
        ...(is_active !== undefined && { is_active }),
      },
    });

    return responseHandler({
      res,
      message: res.__("messages.offer_updated"),
      data: { offer: updated },
    });
  };

  // ============================ deleteOffer ============================
  deleteOffer = async (req: Request, res: Response, next: NextFunction) => {
    const user = res.locals.user;
    const offerId = Number(req.params.offerId);

    const supplier = await prisma.supplier.findUnique({
      where: { user_id: user.id },
    });
    if (!supplier) {
      throw new AppError(
        HttpStatusCode.NOT_FOUND,
        res.__("errors.supplier_not_found"),
      );
    }

    const offer = await prisma.offer.findUnique({
      where: { id: offerId },
      include: { supplierProduct: { select: { supplier_id: true } } },
    });
    if (!offer || offer.deleted_at) {
      throw new AppError(
        HttpStatusCode.NOT_FOUND,
        res.__("errors.offer_not_found"),
      );
    }
    if (offer.supplierProduct?.supplier_id !== supplier.id) {
      throw new AppError(
        HttpStatusCode.FORBIDDEN,
        res.__("errors.supplier_product_not_related_to_supplier"),
      );
    }

    await prisma.offer.update({
      where: { id: offerId },
      data: { deleted_at: new Date(), is_active: false },
    });

    return responseHandler({
      res,
      message: res.__("messages.offer_deleted"),
      data: { offerId },
    });
  };

  // ============================ listCategories ============================
  listCategories = async (req: Request, res: Response, next: NextFunction) => {
    const queryOptions = new FeatureApi(req) // queryOptions :{where, orderBy, take, skip}
      .filter({})
      .sort("-created_at") // ?sort=-created_at
      .limit(10) // ?limit=10
      .skip(0) // ?skip=0
      .includes() // ?includes=role=id-name,wallet,penalties
      .keyword([]) // ?keyword=xxx&items=reason_ar,reason_en
      .fields().data; // ?fields=id,reason_ar,reason_en

    const [totalCategories, categories] = await prisma.$transaction([
      prisma.category.count({
        ...(queryOptions.where ? { where: queryOptions.where } : {}),
      }),
      prisma.category.findMany(queryOptions as any),
    ]);

    return responseHandler({
      res,
      message: res.__("messages.done"),
      data: {
        totalCategories,
        totalPages: Math.ceil(totalCategories / (queryOptions.take ?? 10)),
        categories,
      },
    });
  };
}
