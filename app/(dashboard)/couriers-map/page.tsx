"use client";
import dynamic from "next/dynamic";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import {
  fetchOnlineCouriers,
  fetchAllActiveCouriers,
  courierName,
  courierPhone,
  OnlineCourier,
} from "@/lib/couriers";
import { fetchMapOrders } from "@/lib/orders";
import type { Order } from "@/lib/orders";
import { useT } from "@/contexts/LanguageContext";
import {
  MapPin,
  RefreshCw,
  Wifi,
  WifiOff,
  Clock,
  X,
  Phone,
  MessageSquare,
  ChevronLeft,
  ChevronRight,
  Users,
  GripVertical,
  Package,
  Eye,
  EyeOff,
} from "lucide-react";
import { cn } from "@/lib/utils";
import { useState, useEffect, useMemo, useRef } from "react";
import { formatDistance, formatDuration } from "@/lib/formatters";

const CouriersLeafletMap = dynamic(
  () => import("@/components/couriers/CouriersLeafletMap"),
  { ssr: false, loading: () => <MapSkeleton /> }
);

function MapSkeleton() {
  return (
    <div className="w-full h-full rounded-xl bg-gray-100 animate-pulse flex items-center justify-center">
      <MapPin className="text-gray-300" size={48} />
    </div>
  );
}

const STATUS_META: Record<string, { label: string; dot: string; bg: string; text: string }> = {
  PENDING:          { label: "Pending",    dot: "bg-yellow-400",  bg: "bg-yellow-50",  text: "text-yellow-700" },
  IN_PROGRESS:      { label: "Active",     dot: "bg-violet-500",  bg: "bg-violet-50",  text: "text-violet-700" },
  DELIVERED:        { label: "Delivered",  dot: "bg-green-500",   bg: "bg-green-50",   text: "text-green-700"  },
  CANCELLED:        { label: "Cancelled",  dot: "bg-red-400",     bg: "bg-red-50",     text: "text-red-600"    },
  EXPIRED:          { label: "Expired",    dot: "bg-gray-400",    bg: "bg-gray-100",   text: "text-gray-500"   },
  SEARCHING_FAILED: { label: "Failed",     dot: "bg-orange-400",  bg: "bg-orange-50",  text: "text-orange-600" },
};

function StatusBadge({ status }: { status: string }) {
  const m = STATUS_META[status] ?? { label: status, dot: "bg-gray-400", bg: "bg-gray-100", text: "text-gray-600" };
  return (
    <span className={cn("inline-flex items-center gap-1 text-xs font-medium px-1.5 py-0.5 rounded-full", m.bg, m.text)}>
      <span className={cn("w-1.5 h-1.5 rounded-full flex-shrink-0", m.dot)} />
      {m.label}
    </span>
  );
}

// Draggable list hook
function useDraggableList<T>(items: T[]) {
  const [order, setOrder] = useState<number[]>([]);
  const dragIdx = useRef<number | null>(null);

  // Reset order when items length changes
  useEffect(() => {
    setOrder(items.map((_, i) => i));
  }, [items.length]);

  const sorted = useMemo(() => order.map((i) => items[i]).filter(Boolean), [order, items]);

  function onDragStart(idx: number) { dragIdx.current = idx; }
  function onDragOver(e: React.DragEvent, idx: number) {
    e.preventDefault();
    if (dragIdx.current === null || dragIdx.current === idx) return;
    setOrder((prev) => {
      const next = [...prev];
      const from = next.indexOf(prev[dragIdx.current!]);
      const to   = next.indexOf(prev[idx]);
      // swap positions in next
      const fromVal = next[from];
      const toVal   = next[to];
      next[from] = toVal;
      next[to]   = fromVal;
      return next;
    });
    dragIdx.current = idx;
  }
  function onDrop() { dragIdx.current = null; }

  return { sorted, onDragStart, onDragOver, onDrop };
}

export default function CouriersMapPage() {
  const { t } = useT();
  const [now, setNow] = useState<Date>(new Date());
  const [selectedOrderId, setSelectedOrderId] = useState<number | null>(null);
  const [rightOpen, setRightOpen] = useState(true);
  const [distOpen, setDistOpen] = useState(true);
  const [showAllCouriers, setShowAllCouriers] = useState(false); // false = online only
  const queryClient = useQueryClient();

  // Map orders (PENDING + IN_PROGRESS)
  const { data: mapOrders = [], isFetching: isFetchingOrders, dataUpdatedAt } = useQuery({
    queryKey: ["map-orders"],
    queryFn: fetchMapOrders,
    refetchInterval: 30_000,
    refetchIntervalInBackground: true,
    staleTime: 0,
  });

  const selectedOrder = mapOrders.find((o) => o.id === selectedOrderId) ?? null;
  const pickupLat = selectedOrder?.pickup_lat != null ? Number(selectedOrder.pickup_lat) : null;
  const pickupLng = selectedOrder?.pickup_long != null ? Number(selectedOrder.pickup_long) : null;
  const orderLocation =
    pickupLat != null && !isNaN(pickupLat) && pickupLng != null && !isNaN(pickupLng)
      ? { order_lat: pickupLat, order_lng: pickupLng }
      : undefined;

  // All active couriers (DB-backed)
  const { data: activeCouriersData, isFetching: isFetchingActive } = useQuery({
    queryKey: ["active-couriers"],
    queryFn: () => fetchAllActiveCouriers({ limit: 200 }),
    refetchInterval: 30_000,
    refetchIntervalInBackground: true,
    staleTime: 0,
  });

  // Online couriers — uses the 3-source detection endpoint (sockets + recent location)
  const { data: onlineCouriersData } = useQuery({
    queryKey: ["online-couriers-admin"],
    queryFn: () => fetchOnlineCouriers({ take: 200 }),
    refetchInterval: 30_000,
    refetchIntervalInBackground: true,
    staleTime: 0,
  });

  // Distance-sorted couriers when an order is selected
  const { data: distanceData, isFetching: isFetchingDist } = useQuery({
    queryKey: ["online-couriers-dist", orderLocation],
    queryFn: () => fetchOnlineCouriers(orderLocation),
    enabled: orderLocation != null,
    refetchInterval: 30_000,
    refetchIntervalInBackground: true,
    staleTime: 0,
  });

  useEffect(() => {
    const id = setInterval(() => setNow(new Date()), 1000);
    return () => clearInterval(id);
  }, []);

  const isFetching = isFetchingActive || isFetchingOrders || isFetchingDist;
  const secondsAgo = dataUpdatedAt
    ? Math.floor((now.getTime() - dataUpdatedAt) / 1000)
    : null;

  // Convert active couriers response → OnlineCourier shape for the right panel
  const allCouriers: OnlineCourier[] = useMemo(() => {
    return (activeCouriersData?.users ?? []).map((u) => ({
      id: u.courier?.id ?? u.id,
      user_id: u.id,
      lat: u.courier?.lat ?? null,
      lng: u.courier?.lng ?? null,
      user: { id: u.id, full_name: u.full_name, phone: u.phone, personal_photo: u.personal_photo },
      has_active_order: u.courier?.has_active_order,
    }));
  }, [activeCouriersData]);

  // Online couriers from the 3-source detection endpoint
  const onlineCouriers: OnlineCourier[] = useMemo(
    () => onlineCouriersData?.couriers ?? [],
    [onlineCouriersData]
  );

  // Set of online user IDs — used for the green dot in the "All" panel view
  const onlineUserIds = useMemo<Set<number>>(() => {
    const ids = new Set<number>();
    onlineCouriers.forEach((c) => ids.add(c.user?.id ?? c.user_id));
    return ids;
  }, [onlineCouriers]);

  const displayCouriers = showAllCouriers ? allCouriers : onlineCouriers;

  // Map shows only online couriers; distance-mode uses the sorted subset
  const mapCouriers = orderLocation != null && distanceData
    ? distanceData.couriers
    : onlineCouriers;

  const total = activeCouriersData?.totalUsers ?? 0;
  const onlineCount = onlineCouriersData?.total ?? onlineCouriers.length;
  const locatedCount = allCouriers.filter((c) => c.lat != null && c.lng != null).length;

  const pendingCount    = mapOrders.filter((o) => o.status === "PENDING").length;
  const inProgressCount = mapOrders.filter((o) => o.status === "IN_PROGRESS").length;

  const urgentCount = mapOrders.filter(
    (o) => o.status === "PENDING" && Date.now() - new Date(o.created_at).getTime() > 5 * 60_000
  ).length;

  const distanceMode = orderLocation != null;
  const distCouriers = distanceData?.couriers.filter((c) => c.lat != null && c.lng != null) ?? [];

  // Draggable lists
  const courierDrag = useDraggableList(displayCouriers);
  const orderDrag   = useDraggableList(mapOrders);

  function handleRefresh() {
    queryClient.invalidateQueries({ queryKey: ["map-orders"] });
    queryClient.invalidateQueries({ queryKey: ["active-couriers"] });
    queryClient.invalidateQueries({ queryKey: ["online-couriers-admin"] });
    queryClient.invalidateQueries({ queryKey: ["online-couriers-dist"] });
  }

  return (
    <div className="flex flex-col h-screen p-6 gap-4">
      {/* Header */}
      <div className="flex items-start justify-between flex-wrap gap-3">
        <div>
          <h1 className="text-2xl font-bold text-gray-900 flex items-center gap-2">
            <MapPin size={24} className="text-indigo-600" />
            {t("couriersMap.title")}
          </h1>
          <p className="text-sm text-gray-500 mt-0.5">{t("couriersMap.subtitle")}</p>
        </div>
        <div className="flex items-center gap-3 flex-wrap">
          <span className="flex items-center gap-1.5 text-xs text-gray-400 bg-gray-100 px-3 py-1.5 rounded-full">
            <Clock size={12} />
            {t("couriersMap.autoRefresh")}
          </span>
          {secondsAgo !== null && (
            <span className="text-xs text-gray-400">
              {t("couriersMap.lastUpdated")}: {secondsAgo}s ago
            </span>
          )}
          <button
            onClick={handleRefresh}
            disabled={isFetching}
            className="flex items-center gap-1.5 px-3 py-1.5 text-sm bg-indigo-600 text-white rounded-lg hover:bg-indigo-700 disabled:opacity-50 transition-colors"
          >
            <RefreshCw size={14} className={cn(isFetching && "animate-spin")} />
            {t("couriersMap.refresh")}
          </button>
        </div>
      </div>

      {/* Stats row */}
      <div className="flex gap-3 flex-wrap">
        <div className="flex items-center gap-2 bg-white border border-gray-200 rounded-lg px-4 py-2.5 shadow-sm">
          <Users size={18} className="text-blue-500" />
          <div>
            <div className="text-xs text-gray-500">Active Couriers</div>
            <div className="text-xl font-bold text-gray-900">{total}</div>
          </div>
        </div>
        <div className="flex items-center gap-2 bg-white border border-green-200 rounded-lg px-4 py-2.5 shadow-sm">
          <Wifi size={18} className="text-green-500" />
          <div>
            <div className="text-xs text-gray-500">{t("couriersMap.onlineCount")}</div>
            <div className="text-xl font-bold text-gray-900">{onlineCount}</div>
          </div>
        </div>
        <div className="flex items-center gap-2 bg-white border border-gray-200 rounded-lg px-4 py-2.5 shadow-sm">
          <MapPin size={18} className="text-indigo-500" />
          <div>
            <div className="text-xs text-gray-500">With Location</div>
            <div className="text-xl font-bold text-gray-900">{locatedCount}</div>
          </div>
        </div>
        {total - locatedCount > 0 && (
          <div className="flex items-center gap-2 bg-white border border-orange-200 rounded-lg px-4 py-2.5 shadow-sm">
            <WifiOff size={18} className="text-orange-400" />
            <div>
              <div className="text-xs text-gray-500">{t("couriersMap.noLocation")}</div>
              <div className="text-xl font-bold text-gray-900">{total - locatedCount}</div>
            </div>
          </div>
        )}
        <div className="flex items-center gap-2 bg-white border border-yellow-200 rounded-lg px-4 py-2.5 shadow-sm">
          <Package size={18} className="text-yellow-500" />
          <div>
            <div className="text-xs text-gray-500">Pending</div>
            <div className="text-xl font-bold text-gray-900">{pendingCount}</div>
          </div>
        </div>
        <div className="flex items-center gap-2 bg-white border border-violet-200 rounded-lg px-4 py-2.5 shadow-sm">
          <Package size={18} className="text-violet-500" />
          <div>
            <div className="text-xs text-gray-500">In Progress</div>
            <div className="text-xl font-bold text-gray-900">{inProgressCount}</div>
          </div>
        </div>
        {urgentCount > 0 && (
          <div className="flex items-center gap-2 bg-white border border-red-200 rounded-lg px-4 py-2.5 shadow-sm">
            <MapPin size={18} className="text-red-500" />
            <div>
              <div className="text-xs text-gray-500">Urgent (&gt;5 min)</div>
              <div className="text-xl font-bold text-red-600">{urgentCount}</div>
            </div>
          </div>
        )}
      </div>

      {/* Selected order banner */}
      {selectedOrder && (
        <div className="flex items-center gap-3 bg-indigo-50 border border-indigo-200 rounded-xl px-4 py-2.5 flex-wrap">
          <StatusBadge status={selectedOrder.status} />
          <span className="text-sm font-semibold text-indigo-800">
            #{selectedOrder.order_number}
          </span>
          {selectedOrder.customer && (
            <span className="text-xs text-indigo-600">
              👤 {selectedOrder.customer.full_name}
            </span>
          )}
          {selectedOrder.pickup_address_description && (
            <span className="text-xs text-indigo-600 flex-1 truncate">
              📍 {selectedOrder.pickup_address_description}
            </span>
          )}
          {distanceMode && (
            <span className="text-xs bg-indigo-200 text-indigo-800 font-medium px-2 py-0.5 rounded-full">
              {t("couriersMap.sortedByDistance")}
            </span>
          )}
          <button
            onClick={() => setSelectedOrderId(null)}
            className="flex items-center gap-1 text-xs text-indigo-500 hover:text-red-500 transition-colors ml-auto"
          >
            <X size={14} /> {t("couriersMap.clearOrder")}
          </button>
        </div>
      )}

      {/* Map + side panels */}
      <div className="flex-1 min-h-0 flex gap-4">
        {/* Map */}
        <div className="flex-1 min-h-0 min-w-0 bg-white rounded-xl border border-gray-200 shadow-sm overflow-hidden relative">
          {total === 0 && mapOrders.length === 0 && !isFetching && (
            <div className="absolute inset-0 flex flex-col items-center justify-center gap-3 text-gray-400 z-10 pointer-events-none">
              <WifiOff size={48} className="opacity-40" />
              <p className="text-base font-medium">{t("couriersMap.noOnline")}</p>
            </div>
          )}
          <CouriersLeafletMap
            couriers={mapCouriers}
            onlineUserIds={onlineUserIds}
            orders={mapOrders}
            selectedOrderId={selectedOrderId}
            onOrderSelect={setSelectedOrderId}
            isFetchingDistances={isFetchingDist && distanceMode}
            noLocationLabel={t("couriersMap.noLocation")}
            phoneLabel={t("couriersMap.phone")}
          />
        </div>

        {/* Distance side panel (collapsible, when order selected + PENDING) */}
        {distanceMode && selectedOrder?.status === "PENDING" && distCouriers.length > 0 && (
          <div
            className={cn(
              "flex-shrink-0 bg-white border border-gray-200 rounded-xl shadow-sm flex flex-col transition-all duration-300 overflow-hidden",
              distOpen ? "w-56" : "w-10"
            )}
          >
            {/* Toggle */}
            <button
              onClick={() => setDistOpen((v) => !v)}
              className="flex-shrink-0 flex items-center justify-center h-10 border-b border-gray-100 hover:bg-gray-50 transition-colors"
              title={distOpen ? "Collapse" : "Expand"}
            >
              {distOpen ? <ChevronRight size={16} /> : <ChevronLeft size={16} />}
            </button>

            {distOpen && (
              <>
                <div className="px-4 py-3 border-b border-gray-100 sticky top-0 bg-white z-10">
                  <p className="text-sm font-semibold text-gray-800">
                    {t("couriersMap.sortedByDistance")}
                  </p>
                  <p className="text-xs text-gray-400 mt-0.5">
                    #{selectedOrder?.order_number}
                  </p>
                </div>
                <ul className="divide-y divide-gray-50 flex-1 overflow-y-auto">
                  {distCouriers.map((courier, idx) => (
                    <li key={`d-${courier.user?.id ?? courier.user_id}`} className="px-4 py-3 flex items-start gap-2">
                      <span className="text-xs font-bold text-gray-400 w-5 text-center mt-0.5">
                        {idx + 1}
                      </span>
                      <div className="flex-1 min-w-0">
                        <p className="text-sm font-medium text-gray-800 truncate">
                          {courierName(courier)}
                        </p>
                        <div className="flex items-center gap-1.5 mt-0.5">
                          {courierPhone(courier) && (
                            <a href={`tel:${courierPhone(courier)}`} className="text-green-600 hover:text-green-700">
                              <Phone size={11} />
                            </a>
                          )}
                          <a
                            href={`/chat?userId=${courier.user?.id ?? courier.user_id}`}
                            target="_blank" rel="noreferrer"
                            className="text-indigo-500 hover:text-indigo-700"
                          >
                            <MessageSquare size={11} />
                          </a>
                        </div>
                        <div className="flex items-center gap-1.5 mt-1 flex-wrap">
                          {courier.real_distance != null && (
                            <span className="bg-indigo-50 text-indigo-700 text-xs font-medium px-1.5 py-0.5 rounded-full">
                              {formatDistance(courier.real_distance)}
                            </span>
                          )}
                          {courier.duration != null && (
                            <span className="bg-amber-50 text-amber-700 text-xs font-medium px-1.5 py-0.5 rounded-full">
                              {formatDuration(courier.duration)}
                            </span>
                          )}
                          {courier.has_active_order && (
                            <span className="bg-red-50 text-red-600 text-xs font-medium px-1.5 py-0.5 rounded-full">
                              {t("couriersMap.busy")}
                            </span>
                          )}
                        </div>
                      </div>
                    </li>
                  ))}
                </ul>
              </>
            )}
          </div>
        )}

        {/* Right panel — Couriers + Orders (collapsible) */}
        <div
          className={cn(
            "flex-shrink-0 bg-white border border-gray-200 rounded-xl shadow-sm flex flex-col transition-all duration-300 overflow-hidden",
            rightOpen ? "w-72" : "w-10"
          )}
        >
          {/* Toggle */}
          <button
            onClick={() => setRightOpen((v) => !v)}
            className="flex-shrink-0 flex items-center justify-center h-10 border-b border-gray-100 hover:bg-gray-50 transition-colors"
            title={rightOpen ? "Collapse" : "Expand"}
          >
            {rightOpen ? <ChevronRight size={16} /> : <ChevronLeft size={16} />}
          </button>

          {rightOpen && (
            <div className="flex-1 overflow-y-auto flex flex-col">

              {/* ── Couriers section ── */}
              <div className="flex-shrink-0">
                <div className="px-4 py-2.5 border-b border-gray-100 flex items-center justify-between sticky top-0 bg-white z-10">
                  <div>
                    <p className="text-sm font-semibold text-gray-800 flex items-center gap-1.5">
                      <Users size={14} className="text-indigo-500" />
                      {showAllCouriers ? "All Couriers" : "Online Couriers"}
                    </p>
                    <p className="text-xs text-gray-400">
                      {showAllCouriers ? `${total} active` : `${onlineCount} online`}
                    </p>
                  </div>
                  <button
                    onClick={() => setShowAllCouriers((v) => !v)}
                    className="flex items-center gap-1 text-xs text-indigo-500 hover:text-indigo-700 bg-indigo-50 hover:bg-indigo-100 px-2 py-1 rounded-lg transition-colors"
                    title={showAllCouriers ? "Show online only" : "Show all couriers"}
                  >
                    {showAllCouriers ? <EyeOff size={12} /> : <Eye size={12} />}
                    {showAllCouriers ? "Online" : "All"}
                  </button>
                </div>
                <ul className="divide-y divide-gray-50">
                  {courierDrag.sorted.map((courier, idx) => {
                    const uid = courier.user?.id ?? courier.user_id;
                    const isOnline = onlineUserIds.has(uid);
                    const phone = courierPhone(courier);
                    const name = courierName(courier);
                    return (
                      <li
                        key={`cp-${courier.user_id}`}
                        draggable
                        onDragStart={() => courierDrag.onDragStart(idx)}
                        onDragOver={(e) => courierDrag.onDragOver(e, idx)}
                        onDrop={courierDrag.onDrop}
                        className="px-3 py-2.5 flex items-center gap-2 cursor-grab active:cursor-grabbing hover:bg-gray-50 transition-colors"
                      >
                        <GripVertical size={12} className="text-gray-300 flex-shrink-0" />
                        <div className="relative flex-shrink-0">
                          {courier.user?.personal_photo ? (
                            // eslint-disable-next-line @next/next/no-img-element
                            <img
                              src={courier.user.personal_photo}
                              alt={name}
                              className="w-7 h-7 rounded-full object-cover"
                            />
                          ) : (
                            <div className="w-7 h-7 rounded-full bg-indigo-100 flex items-center justify-center text-indigo-600 text-xs font-bold">
                              {name.charAt(0).toUpperCase()}
                            </div>
                          )}
                          <span
                            className={cn(
                              "absolute -bottom-0.5 -right-0.5 w-2 h-2 rounded-full border-2 border-white",
                              isOnline ? "bg-green-500" : "bg-gray-300"
                            )}
                          />
                        </div>
                        <div className="flex-1 min-w-0">
                          <p className="text-xs font-medium text-gray-800 truncate">{name}</p>
                          {courier.has_active_order && (
                            <span className="text-xs text-red-500">Busy</span>
                          )}
                        </div>
                        <div className="flex gap-1 flex-shrink-0">
                          {phone && (
                            <a
                              href={`tel:${phone}`}
                              onClick={(e) => e.stopPropagation()}
                              className="flex items-center justify-center w-6 h-6 rounded-full bg-green-50 text-green-600 hover:bg-green-100 transition-colors"
                              title="Call"
                            >
                              <Phone size={11} />
                            </a>
                          )}
                          <a
                            href={`/chat?userId=${uid}`}
                            target="_blank"
                            rel="noreferrer"
                            onClick={(e) => e.stopPropagation()}
                            className="flex items-center justify-center w-6 h-6 rounded-full bg-indigo-50 text-indigo-600 hover:bg-indigo-100 transition-colors"
                            title="Chat"
                          >
                            <MessageSquare size={11} />
                          </a>
                        </div>
                      </li>
                    );
                  })}
                  {courierDrag.sorted.length === 0 && (
                    <li className="px-4 py-6 text-center text-xs text-gray-400">
                      {showAllCouriers ? "No active couriers" : "No online couriers"}
                    </li>
                  )}
                </ul>
              </div>

              {/* ── Orders section ── */}
              <div className="flex-1 border-t-4 border-gray-100">
                <div className="px-4 py-2.5 border-b border-gray-100 sticky top-0 bg-white z-10">
                  <p className="text-sm font-semibold text-gray-800 flex items-center gap-1.5">
                    <Package size={14} className="text-yellow-500" />
                    Active Orders
                  </p>
                  <p className="text-xs text-gray-400">
                    {pendingCount} pending · {inProgressCount} in progress
                  </p>
                </div>
                <ul className="divide-y divide-gray-50">
                  {orderDrag.sorted.map((order, idx) => {
                    const isSelected = order.id === selectedOrderId;
                    const ageMin = Math.floor((Date.now() - new Date(order.created_at).getTime()) / 60000);
                    const hasLoc = order.pickup_lat != null && order.pickup_long != null;
                    return (
                      <li
                        key={order.id}
                        draggable
                        onDragStart={() => orderDrag.onDragStart(idx)}
                        onDragOver={(e) => orderDrag.onDragOver(e, idx)}
                        onDrop={orderDrag.onDrop}
                        onClick={() => hasLoc && setSelectedOrderId(isSelected ? null : order.id)}
                        className={cn(
                          "px-3 py-2.5 flex items-start gap-2 cursor-pointer hover:bg-gray-50 transition-colors",
                          isSelected && "bg-indigo-50 border-l-2 border-indigo-400"
                        )}
                      >
                        <GripVertical size={12} className="text-gray-300 flex-shrink-0 mt-1 cursor-grab active:cursor-grabbing" />
                        <div className="flex-1 min-w-0">
                          <div className="flex items-center gap-1.5 flex-wrap">
                            <span className="text-xs font-bold text-gray-800">
                              #{order.order_number}
                            </span>
                            <StatusBadge status={order.status} />
                          </div>
                          {order.customer && (
                            <p className="text-xs text-gray-500 truncate mt-0.5">
                              👤 {order.customer.full_name}
                            </p>
                          )}
                          {order.pickup_address_description && (
                            <p className="text-xs text-gray-400 truncate">
                              📍 {order.pickup_address_description}
                            </p>
                          )}
                          <div className="flex items-center gap-1.5 mt-1 flex-wrap">
                            <span className="text-xs text-gray-400">{ageMin}m ago</span>
                            {!hasLoc && (
                              <span className="text-xs text-orange-500">No location</span>
                            )}
                            {isSelected && (
                              <span className="text-xs text-indigo-600 font-medium">● Selected</span>
                            )}
                          </div>
                        </div>
                        {order.customer && (
                          <div className="flex flex-col gap-1 flex-shrink-0">
                            {order.customer.phone && (
                              <a
                                href={`tel:${order.customer.phone}`}
                                onClick={(e) => e.stopPropagation()}
                                className="flex items-center justify-center w-6 h-6 rounded-full bg-green-50 text-green-600 hover:bg-green-100"
                                title="Call customer"
                              >
                                <Phone size={11} />
                              </a>
                            )}
                            <a
                              href={`/chat?userId=${order.customer.id}&orderId=${order.id}&orderNum=${order.order_number}&orderStatus=${order.status}`}
                              target="_blank"
                              rel="noreferrer"
                              onClick={(e) => e.stopPropagation()}
                              className="flex items-center justify-center w-6 h-6 rounded-full bg-indigo-50 text-indigo-600 hover:bg-indigo-100"
                              title="Chat with customer"
                            >
                              <MessageSquare size={11} />
                            </a>
                          </div>
                        )}
                      </li>
                    );
                  })}
                  {orderDrag.sorted.length === 0 && (
                    <li className="px-4 py-6 text-center text-xs text-gray-400">
                      No active orders
                    </li>
                  )}
                </ul>
              </div>

            </div>
          )}
        </div>
      </div>
    </div>
  );
}
