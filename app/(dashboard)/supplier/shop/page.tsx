"use client";

import { useState, useEffect, useMemo } from "react";
import { useQuery } from "@tanstack/react-query";
import { supplierApi } from "@/lib/api";
import { useT } from "@/contexts/LanguageContext";
import {
  Search, ShoppingCart, Plus, Minus, X, Package2,
  RefreshCw, ShoppingBag, Tag, Trash2, ChevronRight,
  Star, Percent, Sparkles,
} from "lucide-react";
import toast from "react-hot-toast";
import Image from "next/image";
import { useRouter } from "next/navigation";

// ── Types ─────────────────────────────────────────────────────────────────────
interface ProductOffer {
  id: number;
  offer_type: "PERCENT" | "FIXED_CENTS";
  offer_value: number | string;
  is_active: boolean;
  deleted_at: string | null;
  start_date: string;
  end_date: string;
  created_by_role?: "SUPPLIER" | "ADMIN";
}

interface ProductInListing {
  id: number;
  name: string;
  name_ar?: string | null;
  description?: string | null;
  images?: any;
  category?: { id: number; name: string; name_ar?: string | null } | null;
}

interface SupplierListing {
  id: number;               // supplier_product.id = sp_id for cart
  product_id: number;
  supplier_id: number;
  price: number | null;     // base price in piastres
  cost_price: number | null;
  stock: number;
  is_active: boolean;
  is_featured: boolean;
  max_amount_for_one_order: number | null;
  min_amount_for_one_order: number | null;
  offers?: ProductOffer[] | null;
  product?: ProductInListing | null;
}

export interface CartItem {
  supplierProductId: number;  // sp_id sent to POST /cart
  productId: number;
  name: string;
  name_ar?: string | null;
  image: string | null;
  price: number;              // effective price in piastres (offer applied if any)
  originalPrice: number;      // base price before offer, in piastres
  qty: number;
  stock: number;
  maxPerOrder: number | null;
  minPerOrder: number | null;
}

// ── Helpers ───────────────────────────────────────────────────────────────────
function firstImage(images: any): string | null {
  if (!images) return null;
  if (Array.isArray(images) && images.length > 0) return images[0];
  if (typeof images === "string") {
    const s = images.trim();
    if (s.startsWith("[")) {
      try { const a = JSON.parse(s); return Array.isArray(a) && a.length ? a[0] : null; }
      catch { /* ignore */ }
    }
    if (s.startsWith("http")) return s;
  }
  return null;
}

function fmt(n: number) {
  return `${(n / 100).toFixed(2)} EGP`;
}

/** Compute effective (offer-applied) price from a SupplierListing.
 *  - PERCENT offer: discount = price × (value / 100)
 *  - FIXED_CENTS offer: discount = value (already in piastres)
 *  All values in piastres.
 */
function computeEffectivePrice(sp: SupplierListing): {
  price: number;
  originalPrice: number;
  discountPct: number;
  discountFixed: number;   // piastres, only meaningful when offerType === "FIXED_CENTS"
  offerType: "PERCENT" | "FIXED_CENTS" | null;
  hasOffer: boolean;
} {
  const base = sp.price ?? 0;
  const now = Date.now();

  const activeOffer = sp.offers?.find(o =>
    o.is_active &&
    !o.deleted_at &&
    new Date(o.start_date).getTime() <= now &&
    new Date(o.end_date).getTime() >= now
  ) ?? null;

  if (!activeOffer) return { price: base, originalPrice: base, discountPct: 0, discountFixed: 0, offerType: null, hasOffer: false };

  const val = Number(activeOffer.offer_value);
  const isPercent = activeOffer.offer_type === "PERCENT";
  const discount = isPercent
    ? Math.round((base * val) / 100)
    : val; // FIXED_CENTS — value already in piastres

  const finalPrice = Math.max(0, base - discount);
  const discountPct = base > 0 ? Math.round((discount / base) * 100) : 0;

  return {
    price: finalPrice,
    originalPrice: base,
    discountPct,
    discountFixed: discount,
    offerType: activeOffer.offer_type,
    hasOffer: true,
  };
}

export const CART_KEY = "supplier_shop_cart";

export function loadCart(): CartItem[] {
  if (typeof window === "undefined") return [];
  try { return JSON.parse(localStorage.getItem(CART_KEY) ?? "[]"); }
  catch { return []; }
}

export function saveCart(items: CartItem[]) {
  if (typeof window !== "undefined")
    localStorage.setItem(CART_KEY, JSON.stringify(items));
}

// ── Page ──────────────────────────────────────────────────────────────────────
export default function SupplierShopPage() {
  const { t, isRTL } = useT();
  const router = useRouter();

  const [search, setSearch] = useState("");
  const [selectedCat, setSelectedCat] = useState<number | null>(null);
  const [cartOpen, setCartOpen] = useState(false);
  const [cart, setCart] = useState<CartItem[]>([]);

  useEffect(() => { setCart(loadCart()); }, []);
  useEffect(() => { saveCart(cart); }, [cart]);

  // ── Fetch supplier's own active listings (request offers too) ─────────────
  const { data, isLoading, refetch, isFetching } = useQuery({
    queryKey: ["supplier-shop-listings"],
    queryFn: async () => {
      const res = await supplierApi.get("/product/list-supplier-products", {
        params: { limit: 500, skip: 0, includes: "product,offers" },
      });
      return res.data?.data ?? res.data;
    },
    staleTime: 30_000,
  });

  const allListings: SupplierListing[] = useMemo(() => {
    const arr = Array.isArray(data?.supplierProducts) ? data.supplierProducts : [];
    return arr.filter((sp: SupplierListing) => sp.is_active && sp.product);
  }, [data]);

  // ── Derive categories ─────────────────────────────────────────────────────
  const categories = useMemo(() => {
    const map = new Map<number, { id: number; name: string; name_ar?: string | null; count: number }>();
    allListings.forEach(sp => {
      const cat = sp.product?.category;
      if (!cat) return;
      if (map.has(cat.id)) map.get(cat.id)!.count++;
      else map.set(cat.id, { ...cat, count: 1 });
    });
    return Array.from(map.values()).sort((a, b) => a.name.localeCompare(b.name));
  }, [allListings]);

  // ── Filtered listings ─────────────────────────────────────────────────────
  const filtered = useMemo(() => {
    let items = allListings;
    if (selectedCat !== null)
      items = items.filter(sp => sp.product?.category?.id === selectedCat);
    if (search.trim()) {
      const q = search.toLowerCase();
      items = items.filter(sp =>
        sp.product?.name?.toLowerCase().includes(q) ||
        sp.product?.name_ar?.toLowerCase().includes(q)
      );
    }
    return items;
  }, [allListings, selectedCat, search]);

  // ── Cart helpers ──────────────────────────────────────────────────────────
  const cartCount      = cart.reduce((s, c) => s + c.qty, 0);
  const cartSubtotal   = cart.reduce((s, c) => s + c.price * c.qty, 0);
  const cartOriginal   = cart.reduce((s, c) => s + c.originalPrice * c.qty, 0);
  const totalSavings   = cartOriginal - cartSubtotal;
  const inCart = (spId: number) => cart.find(c => c.supplierProductId === spId);

  function addToCart(sp: SupplierListing) {
    const product = sp.product;
    if (!product || !sp.price) return;
    const { price, originalPrice } = computeEffectivePrice(sp);

    setCart(prev => {
      const idx = prev.findIndex(c => c.supplierProductId === sp.id);
      if (idx >= 0) {
        const updated = [...prev];
        const max = sp.max_amount_for_one_order ?? sp.stock;
        updated[idx] = { ...updated[idx], qty: Math.min(updated[idx].qty + 1, max) };
        return updated;
      }
      return [...prev, {
        supplierProductId: sp.id,
        productId: sp.product_id,
        name: product.name,
        name_ar: product.name_ar,
        image: firstImage(product.images),
        price,
        originalPrice,
        qty: sp.min_amount_for_one_order ?? 1,
        stock: sp.stock,
        maxPerOrder: sp.max_amount_for_one_order,
        minPerOrder: sp.min_amount_for_one_order,
      }];
    });
    toast.success(t("sp.shop.addedToCart"));
  }

  function updateQty(spId: number, delta: number) {
    setCart(prev => prev.map(c => {
      if (c.supplierProductId !== spId) return c;
      const max = c.maxPerOrder ?? c.stock;
      const min = c.minPerOrder ?? 1;
      return { ...c, qty: Math.min(Math.max(min, c.qty + delta), max) };
    }));
  }

  function removeFromCart(spId: number) {
    setCart(prev => prev.filter(c => c.supplierProductId !== spId));
  }

  // ── Render ────────────────────────────────────────────────────────────────
  return (
    <div className="flex h-[calc(100vh-64px)] overflow-hidden" dir={isRTL ? "rtl" : "ltr"}>

      {/* ── Category Sidebar ───────────────────────────────────────────────── */}
      <aside className="hidden md:flex flex-col w-56 shrink-0 border-e border-gray-200 bg-gray-50 overflow-y-auto">
        <div className="px-4 py-3 border-b border-gray-100">
          <p className="text-[11px] font-semibold text-gray-400 uppercase tracking-wider">
            {t("sp.shop.categories")}
          </p>
        </div>
        <nav className="p-2 space-y-0.5">
          <button
            onClick={() => setSelectedCat(null)}
            className={`w-full flex items-center justify-between px-3 py-2 rounded-xl text-sm font-medium transition ${
              selectedCat === null
                ? "bg-indigo-600 text-white shadow-sm"
                : "text-gray-700 hover:bg-white hover:shadow-sm"
            }`}
          >
            <span>{t("sp.shop.allProducts")}</span>
            <span className={`text-[11px] px-2 py-0.5 rounded-full font-semibold ${
              selectedCat === null ? "bg-white/20 text-white" : "bg-gray-200 text-gray-500"
            }`}>
              {allListings.length}
            </span>
          </button>

          {categories.map(cat => (
            <button
              key={cat.id}
              onClick={() => setSelectedCat(cat.id)}
              className={`w-full flex items-center justify-between px-3 py-2 rounded-xl text-sm font-medium transition ${
                selectedCat === cat.id
                  ? "bg-indigo-600 text-white shadow-sm"
                  : "text-gray-700 hover:bg-white hover:shadow-sm"
              }`}
            >
              <span className="truncate text-start">
                {isRTL ? (cat.name_ar ?? cat.name) : cat.name}
              </span>
              <span className={`text-[11px] px-2 py-0.5 rounded-full font-semibold shrink-0 ms-1 ${
                selectedCat === cat.id ? "bg-white/20 text-white" : "bg-gray-200 text-gray-500"
              }`}>
                {cat.count}
              </span>
            </button>
          ))}
        </nav>
      </aside>

      {/* ── Main ──────────────────────────────────────────────────────────── */}
      <div className="flex-1 flex flex-col overflow-hidden">

        {/* Top bar */}
        <div className="sticky top-0 z-10 bg-white border-b border-gray-200 px-5 py-3 flex items-center gap-3 shadow-sm">
          <div className="hidden sm:block me-2">
            <h1 className="text-base font-bold text-gray-900">{t("sp.shop.title")}</h1>
            <p className="text-xs text-gray-400">{t("sp.shop.subtitle")}</p>
          </div>

          <div className="flex-1 relative">
            <Search size={15} className="absolute top-1/2 -translate-y-1/2 start-3 text-gray-400 pointer-events-none" />
            <input
              type="text"
              value={search}
              onChange={e => setSearch(e.target.value)}
              placeholder={t("sp.shop.searchPlaceholder")}
              className="w-full ps-9 pe-4 py-2 border border-gray-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-indigo-400 bg-gray-50"
            />
            {search && (
              <button onClick={() => setSearch("")} className="absolute top-1/2 -translate-y-1/2 end-2 text-gray-400 hover:text-gray-600">
                <X size={14} />
              </button>
            )}
          </div>

          <button
            onClick={() => refetch()}
            disabled={isFetching}
            className="p-2 border border-gray-200 rounded-xl text-gray-500 hover:bg-gray-50 disabled:opacity-40"
          >
            <RefreshCw size={15} className={isFetching ? "animate-spin" : ""} />
          </button>

          {/* Cart button */}
          <button
            onClick={() => setCartOpen(true)}
            className="relative flex items-center gap-2 px-4 py-2 bg-indigo-600 text-white rounded-xl text-sm font-semibold hover:bg-indigo-700 transition"
          >
            <ShoppingCart size={16} />
            <span className="hidden sm:inline">{t("sp.shop.cart")}</span>
            {cartCount > 0 && (
              <span className="absolute -top-2 -end-2 min-w-[20px] h-5 bg-red-500 text-white text-[11px] rounded-full flex items-center justify-center font-bold px-1">
                {cartCount}
              </span>
            )}
          </button>
        </div>

        {/* Products grid */}
        <div className="flex-1 overflow-y-auto p-5">
          {isLoading ? (
            <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 xl:grid-cols-5 gap-4">
              {Array.from({ length: 15 }).map((_, i) => (
                <div key={i} className="h-72 bg-gray-100 rounded-2xl animate-pulse" />
              ))}
            </div>
          ) : filtered.length === 0 ? (
            <div className="flex flex-col items-center justify-center py-24 text-gray-400">
              <Package2 size={52} className="mb-4 text-gray-200" />
              <p className="text-lg font-semibold text-gray-500">{t("sp.shop.noProducts")}</p>
              <p className="text-sm mt-1">{t("sp.shop.noProductsHint")}</p>
              {search && (
                <button onClick={() => setSearch("")} className="mt-4 text-indigo-600 text-sm hover:underline">
                  {t("sp.shop.clearSearch")}
                </button>
              )}
            </div>
          ) : (
            <>
              <p className="text-xs text-gray-400 mb-4">
                {filtered.length} {t("sp.shop.productsFound")}
              </p>
              <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 xl:grid-cols-5 gap-4">
                {filtered.map(sp => {
                  const cartItem = inCart(sp.id);
                  const img = firstImage(sp.product?.images);
                  const hasStock = sp.stock > 0;
                  const maxReached = cartItem && cartItem.qty >= (sp.max_amount_for_one_order ?? sp.stock);
                  const { price: effectivePrice, originalPrice, discountPct, discountFixed, offerType, hasOffer } = computeEffectivePrice(sp);

                  return (
                    <div
                      key={sp.id}
                      className={`bg-white rounded-2xl border flex flex-col overflow-hidden transition-all hover:shadow-md ${
                        cartItem
                          ? "border-indigo-400 ring-2 ring-indigo-100 shadow-sm"
                          : "border-gray-200 shadow-sm"
                      }`}
                    >
                      {/* Image */}
                      <div className="relative w-full aspect-square bg-gray-50 overflow-hidden">
                        {img ? (
                          <Image
                            src={img}
                            alt={sp.product?.name ?? ""}
                            fill
                            className="object-cover"
                            sizes="(max-width: 640px) 50vw, (max-width: 1024px) 33vw, 20vw"
                          />
                        ) : (
                          <div className="w-full h-full flex items-center justify-center">
                            <Package2 size={40} className="text-gray-200" />
                          </div>
                        )}

                        {/* Out of stock overlay */}
                        {!hasStock && (
                          <div className="absolute inset-0 bg-black/50 flex items-center justify-center">
                            <span className="bg-white text-gray-800 text-xs font-bold px-3 py-1 rounded-full">
                              {t("sp.shop.outOfStock")}
                            </span>
                          </div>
                        )}

                        {/* Offer badge — top start */}
                        {hasOffer && (
                          <span className="absolute top-2 start-2 flex items-center gap-0.5 bg-red-500 text-white text-[10px] font-bold px-2 py-0.5 rounded-full shadow">
                            {offerType === "PERCENT" ? (
                              <><Percent size={8} />-{discountPct}%</>
                            ) : (
                              <>-{(discountFixed / 100).toFixed(0)} EGP</>
                            )}
                          </span>
                        )}

                        {/* Featured badge */}
                        {sp.is_featured && !hasOffer && (
                          <span className="absolute top-2 start-2 flex items-center gap-0.5 bg-amber-400 text-white text-[10px] font-bold px-2 py-0.5 rounded-full">
                            <Star size={9} fill="white" />
                            {t("sp.shop.featured")}
                          </span>
                        )}

                        {/* In-cart qty badge */}
                        {cartItem && (
                          <span className="absolute top-2 end-2 bg-indigo-600 text-white text-[10px] font-bold w-6 h-6 rounded-full flex items-center justify-center">
                            {cartItem.qty}
                          </span>
                        )}
                      </div>

                      {/* Info */}
                      <div className="p-3 flex flex-col gap-2 flex-1">
                        <div className="flex-1">
                          <p className="text-sm font-semibold text-gray-900 line-clamp-2 leading-snug">
                            {isRTL ? (sp.product?.name_ar ?? sp.product?.name) : sp.product?.name}
                          </p>
                          {sp.product?.category && (
                            <p className="text-[11px] text-gray-400 mt-0.5 flex items-center gap-1">
                              <Tag size={10} />
                              {isRTL
                                ? (sp.product.category.name_ar ?? sp.product.category.name)
                                : sp.product.category.name}
                            </p>
                          )}
                        </div>

                        {/* Price block */}
                        <div className="flex items-end justify-between gap-1">
                          <div>
                            <p className="text-base font-bold text-indigo-700">
                              {sp.price ? fmt(effectivePrice) : "—"}
                            </p>
                            {hasOffer && originalPrice !== effectivePrice && (
                              <p className="text-[11px] text-gray-400 line-through">
                                {fmt(originalPrice)}
                              </p>
                            )}
                          </div>
                          <p className="text-[11px] text-gray-400">
                            {t("sp.shop.stock")}: <span className={sp.stock < 5 ? "text-red-500 font-medium" : ""}>{sp.stock}</span>
                          </p>
                        </div>

                        {/* Controls */}
                        {cartItem ? (
                          <div className="flex items-center gap-1.5">
                            <button
                              onClick={() => {
                                if (cartItem.qty <= (cartItem.minPerOrder ?? 1)) removeFromCart(sp.id);
                                else updateQty(sp.id, -1);
                              }}
                              className="w-8 h-8 rounded-lg border border-gray-200 flex items-center justify-center text-gray-600 hover:bg-gray-50 transition"
                            >
                              <Minus size={13} />
                            </button>
                            <span className="flex-1 text-center text-sm font-bold text-gray-900">
                              {cartItem.qty}
                            </span>
                            <button
                              onClick={() => addToCart(sp)}
                              disabled={!!maxReached}
                              className="w-8 h-8 rounded-lg border border-indigo-200 bg-indigo-50 flex items-center justify-center text-indigo-600 hover:bg-indigo-100 disabled:opacity-40 transition"
                            >
                              <Plus size={13} />
                            </button>
                            <button
                              onClick={() => removeFromCart(sp.id)}
                              className="w-8 h-8 rounded-lg border border-red-200 bg-red-50 flex items-center justify-center text-red-400 hover:bg-red-100 transition"
                            >
                              <Trash2 size={13} />
                            </button>
                          </div>
                        ) : (
                          <button
                            onClick={() => addToCart(sp)}
                            disabled={!hasStock || !sp.price}
                            className="w-full flex items-center justify-center gap-1.5 py-2 bg-indigo-600 text-white text-sm font-semibold rounded-xl hover:bg-indigo-700 disabled:opacity-40 disabled:cursor-not-allowed transition"
                          >
                            <Plus size={14} />
                            {t("sp.shop.addToCart")}
                          </button>
                        )}
                      </div>
                    </div>
                  );
                })}
              </div>
            </>
          )}
        </div>
      </div>

      {/* ── Cart Drawer ────────────────────────────────────────────────────── */}
      {cartOpen && (
        <div className="fixed inset-0 z-50 flex" dir={isRTL ? "rtl" : "ltr"}>
          {/* Backdrop */}
          <div className="flex-1 bg-black/40 backdrop-blur-[2px]" onClick={() => setCartOpen(false)} />

          {/* Drawer */}
          <div className="w-full max-w-md bg-white shadow-2xl flex flex-col h-full">

            {/* Header */}
            <div className="flex items-center justify-between px-5 py-4 border-b border-gray-200 bg-gray-50">
              <div className="flex items-center gap-2">
                <div className="w-9 h-9 rounded-xl bg-indigo-100 flex items-center justify-center">
                  <ShoppingCart size={18} className="text-indigo-600" />
                </div>
                <div>
                  <h2 className="text-base font-bold text-gray-900">{t("sp.shop.cart")}</h2>
                  <p className="text-xs text-gray-400">{cartCount} {t("sp.shop.items")}</p>
                </div>
              </div>
              <button onClick={() => setCartOpen(false)} className="p-1.5 rounded-lg hover:bg-gray-200 text-gray-500">
                <X size={18} />
              </button>
            </div>

            {/* Items */}
            <div className="flex-1 overflow-y-auto p-4 space-y-3">
              {cart.length === 0 ? (
                <div className="flex flex-col items-center justify-center py-20 text-gray-400">
                  <ShoppingBag size={52} className="mb-4 text-gray-200" />
                  <p className="text-base font-semibold text-gray-500">{t("sp.shop.emptyCart")}</p>
                  <p className="text-sm mt-1">{t("sp.shop.emptyCartHint")}</p>
                </div>
              ) : (
                cart.map(item => {
                  const hasDiscount = item.originalPrice > item.price;
                  const itemSaving = (item.originalPrice - item.price) * item.qty;

                  return (
                    <div
                      key={item.supplierProductId}
                      className="flex items-start gap-3 p-3 bg-gray-50 rounded-2xl border border-gray-100"
                    >
                      {/* Thumbnail */}
                      <div className="w-14 h-14 rounded-xl bg-gray-200 shrink-0 overflow-hidden relative">
                        {item.image ? (
                          <Image src={item.image} alt={item.name} fill className="object-cover" sizes="56px" />
                        ) : (
                          <div className="w-full h-full flex items-center justify-center">
                            <Package2 size={22} className="text-gray-400" />
                          </div>
                        )}
                      </div>

                      {/* Info */}
                      <div className="flex-1 min-w-0">
                        <p className="text-sm font-semibold text-gray-900 line-clamp-1">
                          {isRTL ? (item.name_ar ?? item.name) : item.name}
                        </p>

                        {/* Price line */}
                        <div className="flex items-center gap-2 mt-0.5">
                          <p className="text-xs font-bold text-indigo-600">{fmt(item.price)}</p>
                          {hasDiscount && (
                            <p className="text-[11px] text-gray-400 line-through">{fmt(item.originalPrice)}</p>
                          )}
                          <span className="text-gray-400 text-[11px]">× {item.qty}</span>
                        </div>

                        {/* Per-item saving */}
                        {hasDiscount && itemSaving > 0 && (
                          <p className="text-[11px] text-green-600 font-medium mt-0.5">
                            {t("sp.shop.totalSavings")} {fmt(itemSaving)}
                          </p>
                        )}

                        {/* Qty controls */}
                        <div className="flex items-center gap-1.5 mt-2">
                          <button
                            onClick={() => {
                              if (item.qty <= (item.minPerOrder ?? 1)) removeFromCart(item.supplierProductId);
                              else updateQty(item.supplierProductId, -1);
                            }}
                            className="w-7 h-7 rounded-lg border border-gray-200 flex items-center justify-center text-gray-600 hover:bg-white"
                          >
                            <Minus size={12} />
                          </button>
                          <span className="w-7 text-center text-sm font-bold text-gray-900">{item.qty}</span>
                          <button
                            onClick={() => updateQty(item.supplierProductId, 1)}
                            disabled={item.qty >= (item.maxPerOrder ?? item.stock)}
                            className="w-7 h-7 rounded-lg border border-indigo-200 bg-indigo-50 flex items-center justify-center text-indigo-600 hover:bg-indigo-100 disabled:opacity-40"
                          >
                            <Plus size={12} />
                          </button>
                        </div>
                      </div>

                      {/* Line total + remove */}
                      <div className="flex flex-col items-end gap-2 shrink-0">
                        <p className="text-sm font-bold text-gray-900">{fmt(item.price * item.qty)}</p>
                        {hasDiscount && (
                          <p className="text-[11px] text-gray-400 line-through">{fmt(item.originalPrice * item.qty)}</p>
                        )}
                        <button
                          onClick={() => removeFromCart(item.supplierProductId)}
                          className="w-7 h-7 rounded-lg border border-red-200 bg-red-50 flex items-center justify-center text-red-400 hover:bg-red-100"
                        >
                          <Trash2 size={12} />
                        </button>
                      </div>
                    </div>
                  );
                })
              )}
            </div>

            {/* Footer */}
            {cart.length > 0 && (
              <div className="border-t border-gray-200 p-5 space-y-3 bg-gray-50">
                {/* Subtotal */}
                <div className="flex items-center justify-between">
                  <span className="text-sm text-gray-500">{t("sp.shop.subtotal")}</span>
                  <span className="text-xl font-bold text-gray-900">{fmt(cartSubtotal)}</span>
                </div>

                {/* Savings banner */}
                {totalSavings > 0 && (
                  <div className="flex items-center gap-2 px-3 py-2 bg-green-50 border border-green-200 rounded-xl">
                    <Sparkles size={14} className="text-green-500 shrink-0" />
                    <p className="text-xs font-medium text-green-700">
                      {t("sp.shop.totalSavings")} <span className="font-bold">{fmt(totalSavings)}</span>
                    </p>
                  </div>
                )}

                <button
                  onClick={() => { setCartOpen(false); router.push("/supplier/shop/checkout"); }}
                  className="w-full flex items-center justify-center gap-2 py-3 bg-indigo-600 text-white font-bold rounded-2xl hover:bg-indigo-700 transition text-base shadow-md shadow-indigo-200"
                >
                  {t("sp.shop.proceedToCheckout")}
                  <ChevronRight size={18} />
                </button>

                <button
                  onClick={() => { setCart([]); toast.success(t("sp.shop.cartCleared")); }}
                  className="w-full py-2 text-sm text-red-500 hover:text-red-700 transition font-medium"
                >
                  {t("sp.shop.clearCart")}
                </button>
              </div>
            )}
          </div>
        </div>
      )}
    </div>
  );
}
