"use client";

import { useState, useEffect, useMemo, useCallback, useRef } from "react";
import { useQuery } from "@tanstack/react-query";
import { useRouter } from "next/navigation";
import api from "@/lib/api";
import { useT } from "@/contexts/LanguageContext";
import {
  ShoppingBag, MapPin, CreditCard, Wallet, Plus,
  ChevronLeft, ChevronRight, Package, ArrowLeft,
  Loader2, CheckCircle, AlertCircle, Tag, Truck,
  Sparkles, Navigation, BadgePercent, X,
} from "lucide-react";
import toast from "react-hot-toast";
import Image from "next/image";
import { CART_KEY, loadCart, CartItem } from "../page";

// ── Types ─────────────────────────────────────────────────────────────────────
interface SavedAddress {
  id: number;
  name?: string | null;
  detailed_address: string;
  area_id: number;
  is_default: boolean;
  address_lat?: string | null;
  address_long?: string | null;
  area?: { id: number; name: string; name_ar?: string | null } | null;
}

interface Area {
  id: number;
  name: string;
  name_ar?: string | null;
  governorate?: { id: number; name: string; name_ar?: string | null } | null;
}

interface OrderPreview {
  productsTotal: number;    // cents — product subtotal after offers applied by server
  deliveryFee: number;      // cents — courier + platform (excl. VAT)
  vatAmount: number;        // cents — 14% on platform fee
  totalFee: number;         // cents — total delivery cost incl. VAT
  courierFee: number;       // cents — courier's share
  platformFee: number;      // cents — platform's share (excl. VAT)
  discountAmount: number;   // cents — coupon discount
  couponId: number | null;
  payableAmount: number;    // cents — final amount customer pays
  distanceM: number;        // meters
  itemCount: number;
}

type PaymentMethod = "CASH" | "WALLET";

// ── Helpers ───────────────────────────────────────────────────────────────────
function fmt(n: number) {
  return `${(n / 100).toFixed(2)} EGP`;
}

function fmtKm(m: number) {
  return `${(m / 1000).toFixed(1)} km`;
}

function firstImage(images: any): string | null {
  if (!images) return null;
  if (Array.isArray(images) && images.length > 0) return images[0];
  if (typeof images === "string") {
    const s = images.trim();
    if (s.startsWith("[")) {
      try { const a = JSON.parse(s); return Array.isArray(a) && a.length ? a[0] : null; } catch { }
    }
    if (s.startsWith("http")) return s;
  }
  return null;
}

// ── Price row ─────────────────────────────────────────────────────────────────
function PriceRow({
  label, value, sub, green, red, bold, indent,
}: {
  label: string; value: string;
  sub?: string; green?: boolean; red?: boolean; bold?: boolean; indent?: boolean;
}) {
  return (
    <div className={`flex items-center justify-between ${indent ? "ps-3" : ""}`}>
      <div>
        <span className={`text-sm ${bold ? "font-semibold text-gray-800" : "text-gray-500"}`}>{label}</span>
        {sub && <span className="ms-1.5 text-[11px] text-gray-400">{sub}</span>}
      </div>
      <span className={`text-sm font-semibold ${
        green ? "text-green-600" : red ? "text-red-500" : bold ? "text-gray-900" : "text-gray-700"
      }`}>
        {value}
      </span>
    </div>
  );
}

// ── Component ─────────────────────────────────────────────────────────────────
export default function CheckoutPage() {
  const { t, isRTL: isRtl } = useT();
  const router = useRouter();

  // Cart
  const [cart, setCart] = useState<CartItem[]>([]);

  // Payment
  const [payment, setPayment] = useState<PaymentMethod>("CASH");

  // Delivery address
  const [selectedAddressId, setSelectedAddressId] = useState<number | null>(null);
  const [showNewAddress, setShowNewAddress] = useState(false);
  const [newAreaId, setNewAreaId] = useState<number | null>(null);
  const [newAddressText, setNewAddressText] = useState("");
  const [setAsDefault, setSetAsDefault] = useState(false);

  // Server cart sync
  const [cartSyncing, setCartSyncing] = useState(false);
  const [cartSynced, setCartSynced] = useState(false);
  const [syncError, setSyncError] = useState(false);

  // Order preview
  const [preview, setPreview] = useState<OrderPreview | null>(null);
  const [previewLoading, setPreviewLoading] = useState(false);
  const [previewError, setPreviewError] = useState(false);

  // Coupon
  const [couponInput, setCouponInput] = useState("");
  const [appliedCoupon, setAppliedCoupon] = useState<string | null>(null);
  const [couponValidating, setCouponValidating] = useState(false);

  // Place order
  const [placing, setPlacing] = useState(false);

  // Track whether we need to re-sync (cart changed after sync)
  const syncedCartRef = useRef<string>("");

  // ── Load cart ──────────────────────────────────────────────────────────────
  useEffect(() => {
    const c = loadCart();
    setCart(c);
    if (c.length === 0) router.replace("/supplier/shop");
  }, []);

  // ── Cart derived values ───────────────────────────────────────────────────
  const localSubtotal  = useMemo(() => cart.reduce((s, i) => s + i.originalPrice * i.qty, 0), [cart]);
  const localDiscounted = useMemo(() => cart.reduce((s, i) => s + i.price * i.qty, 0), [cart]);
  const localOfferSavings = localSubtotal - localDiscounted;

  // ── Fetch addresses ───────────────────────────────────────────────────────
  const { data: addressesData, isLoading: loadingAddresses } = useQuery({
    queryKey: ["my-addresses"],
    queryFn: () => api.get("/profile/addresses").then(r => r.data),
  });

  const addresses: SavedAddress[] = useMemo(() => {
    if (!addressesData) return [];
    if (Array.isArray(addressesData)) return addressesData;
    if (Array.isArray(addressesData?.addresses)) return addressesData.addresses;
    if (Array.isArray(addressesData?.data)) return addressesData.data;
    return [];
  }, [addressesData]);

  // Auto-select default address
  useEffect(() => {
    if (addresses.length > 0 && selectedAddressId === null) {
      const def = addresses.find(a => a.is_default) ?? addresses[0];
      setSelectedAddressId(def.id);
    }
  }, [addresses]);

  // ── Fetch wallet balance ──────────────────────────────────────────────────
  const { data: walletData } = useQuery({
    queryKey: ["my-wallet"],
    queryFn: () => api.get("/profile/wallet").then(r => r.data),
  });
  const walletBalance: number = useMemo(() => {
    return walletData?.wallet?.balance ?? walletData?.balance ?? 0;
  }, [walletData]);

  // ── Fetch areas (only when adding new address) ────────────────────────────
  const { data: areasData, isLoading: loadingAreas } = useQuery({
    queryKey: ["public-areas"],
    queryFn: () => api.get("/areas", { params: { limit: 200 } }).then(r => r.data),
    enabled: showNewAddress,
  });

  const areas: Area[] = useMemo(() => {
    if (!areasData) return [];
    if (Array.isArray(areasData)) return areasData;
    if (Array.isArray(areasData?.areas)) return areasData.areas;
    if (Array.isArray(areasData?.data)) return areasData.data;
    return [];
  }, [areasData]);

  // ── Sync cart to server on mount ──────────────────────────────────────────
  const syncCart = useCallback(async (items: CartItem[]) => {
    const key = JSON.stringify(items.map(i => ({ id: i.supplierProductId, q: i.qty })));
    if (key === syncedCartRef.current) return; // already synced this exact cart
    setCartSyncing(true);
    setSyncError(false);
    try {
      await api.delete("/cart").catch(() => {}); // clear existing (ignore error)
      for (const item of items) {
        await api.post("/cart", { sp_id: item.supplierProductId, quantity: item.qty });
      }
      syncedCartRef.current = key;
      setCartSynced(true);
    } catch {
      setSyncError(true);
      toast.error(t("sp.checkout.syncError"));
    } finally {
      setCartSyncing(false);
    }
  }, [t]);

  // Sync as soon as cart is loaded
  useEffect(() => {
    if (cart.length > 0) syncCart(cart);
  }, [cart, syncCart]);

  // ── Fetch order preview ───────────────────────────────────────────────────
  const fetchPreview = useCallback(async (addressId: number | null, pm: PaymentMethod, coupon: string | null) => {
    if (!cartSynced || !addressId) return;
    setPreviewLoading(true);
    setPreviewError(false);
    try {
      const res = await api.post("/orders/preview", {
        type: "CATALOG_PURCHASE",
        payment_method: pm,
        customer_address_id: addressId,
        ...(coupon ? { coupon_code: coupon } : {}),
      });
      const data = res.data?.preview ?? res.data;
      setPreview(data as OrderPreview);
    } catch {
      setPreviewError(true);
      setPreview(null);
    } finally {
      setPreviewLoading(false);
    }
  }, [cartSynced]);

  // Re-fetch preview when synced, address, payment, or coupon changes
  useEffect(() => {
    if (cartSynced && selectedAddressId && !showNewAddress) {
      fetchPreview(selectedAddressId, payment, appliedCoupon);
    }
  }, [cartSynced, selectedAddressId, payment, appliedCoupon, showNewAddress, fetchPreview]);

  // ── Coupon ────────────────────────────────────────────────────────────────
  async function handleApplyCoupon() {
    const code = couponInput.trim().toUpperCase();
    if (!code) return;
    setCouponValidating(true);
    try {
      await api.post("/customer-coupons/validate", {
        code,
        orderType: "CATALOG_PURCHASE",
      });
      setAppliedCoupon(code);
      toast.success(t("sp.checkout.couponApplied"));
    } catch (err: any) {
      const msg = err?.response?.data?.message ?? t("sp.checkout.couponInvalid");
      toast.error(msg);
    } finally {
      setCouponValidating(false);
    }
  }

  function removeCoupon() {
    setAppliedCoupon(null);
    setCouponInput("");
  }

  // ── Place order ───────────────────────────────────────────────────────────
  async function handlePlaceOrder() {
    if (cart.length === 0) return;

    // Validate address
    const needsAddress = !showNewAddress && selectedAddressId === null && addresses.length > 0;
    const newAddressIncomplete = showNewAddress && (!newAreaId || !newAddressText.trim());
    if (needsAddress || newAddressIncomplete) {
      toast.error(t("sp.checkout.addressRequired"));
      return;
    }

    // Check wallet balance
    if (payment === "WALLET" && preview && walletBalance < preview.payableAmount) {
      toast.error(t("sp.checkout.insufficientBalance"));
      return;
    }

    setPlacing(true);
    try {
      // Re-sync if cart changed since last sync
      await syncCart(cart);

      // Create new address if needed
      let deliveryAddressId: number | undefined = selectedAddressId ?? undefined;
      if (showNewAddress && newAreaId && newAddressText.trim()) {
        const addrRes = await api.post("/profile/addresses", {
          area_id: newAreaId,
          detailed_address: newAddressText.trim(),
          is_default: setAsDefault,
        });
        deliveryAddressId = addrRes.data?.address?.id ?? addrRes.data?.id;
      }

      // Place order
      const orderRes = await api.post("/orders", {
        type: "CATALOG_PURCHASE",
        payment_method: payment,
        ...(deliveryAddressId ? { customer_address_id: deliveryAddressId } : {}),
        ...(appliedCoupon ? { coupon_code: appliedCoupon } : {}),
      });

      const order = orderRes.data?.order ?? orderRes.data?.data?.order ?? orderRes.data;
      const orderId: number | undefined = order?.id;
      const orderNumber: string | undefined = order?.order_number;

      // Clear local cart
      localStorage.removeItem(CART_KEY);

      toast.success(t("sp.success.title"));
      router.push(
        `/supplier/shop/success?orderId=${orderId ?? ""}&orderNumber=${encodeURIComponent(orderNumber ?? "")}`
      );
    } catch (err: any) {
      const msg = err?.response?.data?.message ?? err?.response?.data?.error ?? t("sp.checkout.orderError");
      toast.error(msg);
    } finally {
      setPlacing(false);
    }
  }

  // ── Derived: insufficient wallet ──────────────────────────────────────────
  const insufficientWallet = payment === "WALLET" && preview !== null && walletBalance < preview.payableAmount;
  const offerSavings = preview ? (localSubtotal - preview.productsTotal) : localOfferSavings;

  // ── Empty cart guard ──────────────────────────────────────────────────────
  if (cart.length === 0) {
    return (
      <div className="flex flex-col items-center justify-center min-h-[60vh] gap-4">
        <ShoppingBag className="w-16 h-16 text-gray-300" />
        <p className="text-lg font-medium text-gray-600">{t("sp.checkout.emptyCart")}</p>
        <p className="text-sm text-gray-400">{t("sp.checkout.emptyCartHint")}</p>
        <button
          onClick={() => router.push("/supplier/shop")}
          className="mt-2 flex items-center gap-2 px-4 py-2 bg-indigo-600 text-white rounded-lg hover:bg-indigo-700"
        >
          <ArrowLeft className="w-4 h-4" />
          {t("sp.checkout.backToShop")}
        </button>
      </div>
    );
  }

  return (
    <div className="max-w-5xl mx-auto px-4 py-6 space-y-6" dir={isRtl ? "rtl" : "ltr"}>

      {/* Header */}
      <div className="flex items-center gap-3">
        <button onClick={() => router.back()} className="p-2 rounded-lg hover:bg-gray-100 text-gray-600">
          {isRtl ? <ChevronRight className="w-5 h-5" /> : <ChevronLeft className="w-5 h-5" />}
        </button>
        <div>
          <h1 className="text-2xl font-bold text-gray-900">{t("sp.checkout.title")}</h1>
          <p className="text-sm text-gray-500">{t("sp.checkout.subtitle")}</p>
        </div>
        {/* Cart sync indicator */}
        {cartSyncing && (
          <div className="ms-auto flex items-center gap-1.5 text-xs text-gray-400">
            <Loader2 className="w-3.5 h-3.5 animate-spin" />
            {t("sp.checkout.syncingCart")}
          </div>
        )}
        {syncError && (
          <div className="ms-auto flex items-center gap-1.5 text-xs text-red-500">
            <AlertCircle className="w-3.5 h-3.5" />
            {t("sp.checkout.syncError")}
            <button onClick={() => syncCart(cart)} className="underline">{t("common.refresh")}</button>
          </div>
        )}
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">

        {/* ── LEFT: Payment + Address ───────────────────────────────────────── */}
        <div className="lg:col-span-2 space-y-5">

          {/* Payment Method */}
          <section className="bg-white rounded-2xl shadow-sm border border-gray-100 p-5">
            <h2 className="text-base font-semibold text-gray-800 mb-4 flex items-center gap-2">
              <CreditCard className="w-4 h-4 text-indigo-500" />
              {t("sp.checkout.payment")}
            </h2>
            <div className="grid grid-cols-2 gap-3">
              {(["CASH", "WALLET"] as PaymentMethod[]).map(pm => {
                const isSelected = payment === pm;
                return (
                  <button
                    key={pm}
                    onClick={() => setPayment(pm)}
                    className={`flex flex-col items-center gap-2 p-4 rounded-xl border-2 transition-all ${
                      isSelected
                        ? "border-indigo-500 bg-indigo-50 text-indigo-700"
                        : "border-gray-200 hover:border-gray-300 text-gray-600"
                    }`}
                  >
                    {pm === "CASH" ? <Truck className="w-6 h-6" /> : <Wallet className="w-6 h-6" />}
                    <span className="text-sm font-medium">
                      {pm === "CASH" ? t("sp.checkout.cod") : t("sp.checkout.wallet")}
                    </span>
                    {pm === "WALLET" && (
                      <span className={`text-[11px] ${isSelected ? "text-indigo-500" : "text-gray-400"}`}>
                        {t("sp.checkout.walletBalance")}: {fmt(walletBalance)}
                      </span>
                    )}
                  </button>
                );
              })}
            </div>

            {/* Insufficient balance warning */}
            {insufficientWallet && (
              <div className="mt-3 flex items-center gap-2 px-3 py-2 bg-red-50 border border-red-200 rounded-xl">
                <AlertCircle className="w-4 h-4 text-red-500 shrink-0" />
                <p className="text-xs text-red-600 font-medium">
                  {t("sp.checkout.insufficientBalance")} —{" "}
                  {t("sp.checkout.walletBalance")} {fmt(walletBalance)},{" "}
                  {t("sp.checkout.totalPayable")} {fmt(preview?.payableAmount ?? 0)}
                </p>
              </div>
            )}
          </section>

          {/* Delivery Address */}
          <section className="bg-white rounded-2xl shadow-sm border border-gray-100 p-5">
            <h2 className="text-base font-semibold text-gray-800 mb-4 flex items-center gap-2">
              <MapPin className="w-4 h-4 text-indigo-500" />
              {t("sp.checkout.deliveryAddress")}
            </h2>

            {loadingAddresses ? (
              <div className="flex items-center gap-2 text-gray-400 py-4">
                <Loader2 className="w-4 h-4 animate-spin" />
                <span className="text-sm">{t("common.loading")}</span>
              </div>
            ) : addresses.length === 0 && !showNewAddress ? (
              <p className="text-sm text-gray-400 py-2 mb-3">{t("sp.checkout.noAddresses")}</p>
            ) : (
              <div className="space-y-2 mb-3">
                {addresses.map(addr => {
                  const selected = selectedAddressId === addr.id && !showNewAddress;
                  return (
                    <button
                      key={addr.id}
                      onClick={() => { setSelectedAddressId(addr.id); setShowNewAddress(false); }}
                      className={`w-full text-start flex items-start gap-3 p-3 rounded-xl border-2 transition-all ${
                        selected ? "border-indigo-500 bg-indigo-50" : "border-gray-200 hover:border-gray-300"
                      }`}
                    >
                      <div className={`mt-0.5 w-4 h-4 rounded-full border-2 flex-shrink-0 flex items-center justify-center ${
                        selected ? "border-indigo-500 bg-indigo-500" : "border-gray-300"
                      }`}>
                        {selected && <div className="w-2 h-2 rounded-full bg-white" />}
                      </div>
                      <div className="flex-1 min-w-0">
                        <p className="text-sm font-medium text-gray-800 truncate">
                          {addr.name ?? addr.detailed_address}
                        </p>
                        {addr.name && (
                          <p className="text-xs text-gray-500 truncate">{addr.detailed_address}</p>
                        )}
                        {addr.is_default && (
                          <span className="inline-flex items-center px-1.5 py-0.5 rounded text-xs font-medium bg-green-100 text-green-700 mt-1">
                            ✓ {isRtl ? "افتراضي" : "Default"}
                          </span>
                        )}
                      </div>
                    </button>
                  );
                })}
              </div>
            )}

            {/* Add new address */}
            {!showNewAddress ? (
              <button
                onClick={() => { setShowNewAddress(true); setSelectedAddressId(null); }}
                className="flex items-center gap-2 text-sm text-indigo-600 hover:text-indigo-700 font-medium"
              >
                <Plus className="w-4 h-4" />
                {t("sp.checkout.addNewAddress")}
              </button>
            ) : (
              <div className="border border-indigo-200 rounded-xl p-4 bg-indigo-50 space-y-3">
                {/* Area */}
                <div>
                  <label className="block text-xs font-medium text-gray-700 mb-1">
                    {t("sp.checkout.selectArea")} *
                  </label>
                  {loadingAreas ? (
                    <div className="flex items-center gap-2 text-gray-400 text-sm">
                      <Loader2 className="w-4 h-4 animate-spin" />
                      {t("sp.checkout.loadingAreas")}
                    </div>
                  ) : (
                    <select
                      value={newAreaId ?? ""}
                      onChange={e => setNewAreaId(Number(e.target.value) || null)}
                      className="w-full text-sm border border-gray-300 rounded-lg px-3 py-2 focus:ring-2 focus:ring-indigo-400 focus:border-indigo-400 bg-white"
                    >
                      <option value="">{t("sp.checkout.selectArea")}</option>
                      {areas.map(a => (
                        <option key={a.id} value={a.id}>
                          {isRtl && a.name_ar ? a.name_ar : a.name}
                          {a.governorate ? ` — ${isRtl && a.governorate.name_ar ? a.governorate.name_ar : a.governorate.name}` : ""}
                        </option>
                      ))}
                    </select>
                  )}
                </div>

                {/* Address text */}
                <div>
                  <label className="block text-xs font-medium text-gray-700 mb-1">
                    {t("sp.checkout.addressDetails")} *
                  </label>
                  <textarea
                    rows={2}
                    value={newAddressText}
                    onChange={e => setNewAddressText(e.target.value)}
                    placeholder={t("sp.checkout.addressPlaceholder")}
                    className="w-full text-sm border border-gray-300 rounded-lg px-3 py-2 focus:ring-2 focus:ring-indigo-400 focus:border-indigo-400 resize-none"
                  />
                </div>

                <label className="flex items-center gap-2 text-sm text-gray-700 cursor-pointer">
                  <input
                    type="checkbox"
                    checked={setAsDefault}
                    onChange={e => setSetAsDefault(e.target.checked)}
                    className="rounded text-indigo-500 focus:ring-indigo-400"
                  />
                  {t("sp.checkout.setDefault")}
                </label>

                {addresses.length > 0 && (
                  <button
                    onClick={() => {
                      setShowNewAddress(false);
                      const def = addresses.find(a => a.is_default) ?? addresses[0];
                      setSelectedAddressId(def.id);
                    }}
                    className="text-xs text-gray-500 underline"
                  >
                    {t("common.cancel")}
                  </button>
                )}
              </div>
            )}
          </section>

          {/* Coupon */}
          <section className="bg-white rounded-2xl shadow-sm border border-gray-100 p-5">
            <h2 className="text-base font-semibold text-gray-800 mb-4 flex items-center gap-2">
              <BadgePercent className="w-4 h-4 text-indigo-500" />
              {t("sp.checkout.couponCode")}
            </h2>

            {appliedCoupon ? (
              <div className="flex items-center justify-between px-3 py-2 bg-green-50 border border-green-200 rounded-xl">
                <div className="flex items-center gap-2">
                  <Tag className="w-4 h-4 text-green-600" />
                  <span className="text-sm font-bold text-green-700 font-mono">{appliedCoupon}</span>
                </div>
                <button onClick={removeCoupon} className="text-green-600 hover:text-green-800">
                  <X className="w-4 h-4" />
                </button>
              </div>
            ) : (
              <div className="flex gap-2">
                <input
                  type="text"
                  value={couponInput}
                  onChange={e => setCouponInput(e.target.value.toUpperCase())}
                  onKeyDown={e => e.key === "Enter" && handleApplyCoupon()}
                  placeholder="SAVE10"
                  className="flex-1 text-sm border border-gray-300 rounded-lg px-3 py-2 focus:ring-2 focus:ring-indigo-400 focus:border-indigo-400 font-mono uppercase"
                />
                <button
                  onClick={handleApplyCoupon}
                  disabled={!couponInput.trim() || couponValidating}
                  className="px-4 py-2 bg-indigo-600 text-white text-sm font-semibold rounded-lg hover:bg-indigo-700 disabled:opacity-50 transition"
                >
                  {couponValidating
                    ? <Loader2 className="w-4 h-4 animate-spin" />
                    : t("sp.checkout.applyCoupon")}
                </button>
              </div>
            )}
          </section>
        </div>

        {/* ── RIGHT: Order Summary + Fee Breakdown ─────────────────────────── */}
        <div className="space-y-5">
          <div className="bg-white rounded-2xl shadow-sm border border-gray-100 p-5 sticky top-6 space-y-5">

            {/* Items list */}
            <div>
              <h2 className="text-base font-semibold text-gray-800 mb-3 flex items-center gap-2">
                <ShoppingBag className="w-4 h-4 text-indigo-500" />
                {t("sp.checkout.orderSummary")}
                <span className="text-xs font-normal text-gray-400">
                  ({cart.length} {t("sp.checkout.items")})
                </span>
              </h2>

              <div className="space-y-2.5 max-h-52 overflow-y-auto pe-1">
                {cart.map(item => {
                  const img = firstImage(item.image);
                  const hasDiscount = item.originalPrice > item.price;
                  return (
                    <div key={item.supplierProductId} className="flex gap-2.5">
                      {img ? (
                        <Image src={img} alt={item.name} width={40} height={40}
                          className="rounded-lg object-cover flex-shrink-0" />
                      ) : (
                        <div className="w-10 h-10 rounded-lg bg-gray-100 flex items-center justify-center flex-shrink-0">
                          <Package className="w-4 h-4 text-gray-400" />
                        </div>
                      )}
                      <div className="flex-1 min-w-0">
                        <p className="text-xs font-medium text-gray-800 truncate">
                          {isRtl && item.name_ar ? item.name_ar : item.name}
                        </p>
                        <div className="flex items-center gap-1.5 mt-0.5">
                          <span className="text-xs text-indigo-600 font-semibold">{fmt(item.price)}</span>
                          {hasDiscount && (
                            <span className="text-[10px] text-gray-400 line-through">{fmt(item.originalPrice)}</span>
                          )}
                          <span className="text-[10px] text-gray-400">× {item.qty}</span>
                        </div>
                      </div>
                      <p className="text-xs font-bold text-gray-800 whitespace-nowrap shrink-0">
                        {fmt(item.price * item.qty)}
                      </p>
                    </div>
                  );
                })}
              </div>
            </div>

            {/* Divider */}
            <div className="border-t border-gray-100" />

            {/* Fee breakdown */}
            <div>
              <h3 className="text-sm font-semibold text-gray-700 mb-3 flex items-center gap-1.5">
                <Truck className="w-3.5 h-3.5 text-gray-500" />
                {t("sp.checkout.feeBreakdown")}
              </h3>

              {/* No address selected */}
              {!selectedAddressId && !showNewAddress && (
                <div className="flex items-center gap-2 px-3 py-2.5 bg-amber-50 border border-amber-200 rounded-xl">
                  <Navigation className="w-4 h-4 text-amber-500 shrink-0" />
                  <p className="text-xs text-amber-700">{t("sp.checkout.selectAddressForFees")}</p>
                </div>
              )}

              {/* Loading preview */}
              {previewLoading && (
                <div className="flex items-center gap-2 text-gray-400 py-3">
                  <Loader2 className="w-4 h-4 animate-spin" />
                  <span className="text-sm">{t("sp.checkout.loadingPreview")}</span>
                </div>
              )}

              {/* Preview error */}
              {previewError && !previewLoading && (
                <div className="flex items-center gap-2 px-3 py-2 bg-red-50 border border-red-200 rounded-xl">
                  <AlertCircle className="w-3.5 h-3.5 text-red-400" />
                  <p className="text-xs text-red-600">{t("sp.checkout.previewError")}</p>
                </div>
              )}

              {/* Preview data */}
              {preview && !previewLoading && (
                <div className="space-y-2">
                  <PriceRow
                    label={t("sp.checkout.productSubtotal")}
                    value={fmt(preview.productsTotal)}
                  />
                  {offerSavings > 0 && (
                    <PriceRow
                      label={t("sp.checkout.offerSavings")}
                      value={`-${fmt(offerSavings)}`}
                      green
                    />
                  )}
                  <PriceRow
                    label={t("sp.checkout.courierFee")}
                    value={fmt(preview.courierFee)}
                    indent
                    sub="70%"
                  />
                  <PriceRow
                    label={t("sp.checkout.platformFee")}
                    value={fmt(preview.platformFee)}
                    indent
                    sub="30%"
                  />
                  <PriceRow
                    label={t("sp.checkout.vat")}
                    value={fmt(preview.vatAmount)}
                    indent
                  />
                  {preview.discountAmount > 0 && (
                    <PriceRow
                      label={t("sp.checkout.couponDiscount")}
                      value={`-${fmt(preview.discountAmount)}`}
                      green
                    />
                  )}

                  {/* Distance chip */}
                  {preview.distanceM > 0 && (
                    <div className="flex items-center gap-1.5 text-[11px] text-gray-400 pt-1">
                      <Navigation className="w-3 h-3" />
                      {t("sp.checkout.estimatedDistance")}: {fmtKm(preview.distanceM)}
                    </div>
                  )}

                  <div className="border-t border-gray-100 pt-2 mt-1">
                    <PriceRow
                      label={t("sp.checkout.totalPayable")}
                      value={fmt(preview.payableAmount)}
                      bold
                    />
                  </div>
                </div>
              )}

              {/* Fallback: local subtotal when no preview yet */}
              {!preview && !previewLoading && !previewError && (
                <div className="space-y-2">
                  <PriceRow label={t("sp.checkout.productSubtotal")} value={fmt(localDiscounted)} />
                  {localOfferSavings > 0 && (
                    <PriceRow label={t("sp.checkout.offerSavings")} value={`-${fmt(localOfferSavings)}`} green />
                  )}
                </div>
              )}
            </div>

            {/* Offer savings banner */}
            {offerSavings > 0 && (
              <div className="flex items-center gap-2 px-3 py-2 bg-green-50 border border-green-200 rounded-xl">
                <Sparkles className="w-3.5 h-3.5 text-green-500 shrink-0" />
                <p className="text-xs font-medium text-green-700">
                  {t("sp.shop.totalSavings")} <span className="font-bold">{fmt(offerSavings)}</span>
                </p>
              </div>
            )}

            {/* Place order */}
            <button
              onClick={handlePlaceOrder}
              disabled={placing || cartSyncing || insufficientWallet}
              className="w-full flex items-center justify-center gap-2 px-4 py-3 bg-indigo-600 text-white rounded-xl font-semibold hover:bg-indigo-700 disabled:opacity-60 disabled:cursor-not-allowed transition-colors"
            >
              {placing ? (
                <>
                  <Loader2 className="w-4 h-4 animate-spin" />
                  {t("sp.checkout.placingOrder")}
                </>
              ) : cartSyncing ? (
                <>
                  <Loader2 className="w-4 h-4 animate-spin" />
                  {t("sp.checkout.syncingCart")}
                </>
              ) : (
                <>
                  <CheckCircle className="w-4 h-4" />
                  {t("sp.checkout.placeOrder")}
                  {preview && (
                    <span className="ms-1 opacity-80">· {fmt(preview.payableAmount)}</span>
                  )}
                </>
              )}
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}
