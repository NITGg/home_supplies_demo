export interface ProductWithImages {
  images?: string | null;
  [key: string]: any;
}

export const parseProductImages = <T extends ProductWithImages>(product: T) => {
  if (product && product.images !== undefined) {
    return {
      ...product,
      images:
        typeof product.images === "string"
          ? JSON.parse(product.images)
          : product.images || [],
    };
  }
  return product;
};

export const parseProductsImages = <T extends ProductWithImages>(
  products: T[],
) => {
  if (!Array.isArray(products) || products.length === 0) return [];
  return products.map((product) => parseProductImages(product));
};
