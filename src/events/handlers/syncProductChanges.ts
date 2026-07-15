import { prisma } from "@/config/prisma";
// import { updateBrandUpTo } from "@/modules/brands/brands.service";
import { notifyAdminsExcept } from "@/services/notification.service";
import { AppEvents } from "@/types/events";

export async function syncProductChanges(params: AppEvents["syncProduct"]) {
  const { action, product, admin } = params;

  // 1. Brand Logic
  if (product.brand_id) {
    // await updateBrandUpTo(product.brand_id);

    // Create relationship if it doesn't exist
    await prisma.brandCategory.upsert({
      where: {
        brand_id_category_id: {
          brand_id: product.brand_id,
          category_id: product.category_id,
        },
      },
      update: {},
      create: { brand_id: product.brand_id, category_id: product.category_id },
    });
  }

  // 3. Notification (only on update as per your original code)
  if (action === "update") {
    await notifyAdminsExcept(
      [admin.id],
      {
        titleKey: "notification_product_updated_title",
        bodyKey: "notification_product_updated_desc",
        bodyParams: {
          adminName: admin.full_name,
          productName: product.name,
        },
      },
      {
        navigate: "products",
        route: `/products?id=${product.id}`,
      },
    );
  }
}
