"use client";
import { useEffect, useMemo, useRef } from "react";
import {
  MapContainer, TileLayer, Marker, Popup, Polyline, Tooltip, useMap,
} from "react-leaflet";
import L from "leaflet";
import "leaflet/dist/leaflet.css";
import type { OnlineCourier } from "@/lib/couriers";
import { courierName, courierPhone, courierPhoto } from "@/lib/couriers";
import type { Order } from "@/lib/orders";
import { formatDistance, formatDuration } from "@/lib/formatters";

function CallChatButtons({ phone, userId }: { phone?: string | null; userId: number }) {
  return (
    <div className="flex items-center gap-2 pt-1 border-t border-gray-100 mt-1">
      {phone && (
        <a href={`tel:${phone}`} className="flex items-center gap-1 text-xs text-green-700 bg-green-50 px-2 py-1 rounded-lg hover:bg-green-100">
          📞 Call
        </a>
      )}
      <a href={`/chat?userId=${userId}`} target="_blank" rel="noreferrer" className="flex items-center gap-1 text-xs text-indigo-700 bg-indigo-50 px-2 py-1 rounded-lg hover:bg-indigo-100">
        💬 Chat
      </a>
    </div>
  );
}

delete (L.Icon.Default.prototype as unknown as Record<string, unknown>)._getIconUrl;
L.Icon.Default.mergeOptions({
  iconUrl: "https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon.png",
  iconRetinaUrl: "https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon-2x.png",
  shadowUrl: "https://unpkg.com/leaflet@1.9.4/dist/images/marker-shadow.png",
});

function makeIcon(color: string, size: [number, number] = [25, 41]): L.Icon {
  return new L.Icon({
    iconUrl: `https://raw.githubusercontent.com/pointhi/leaflet-color-markers/master/img/marker-icon-2x-${color}.png`,
    shadowUrl: "https://unpkg.com/leaflet@1.9.4/dist/images/marker-shadow.png",
    iconSize: size,
    iconAnchor: [size[0] / 2, size[1]],
    popupAnchor: [1, -34],
    shadowSize: [41, 41],
  });
}

const courierOnlineIcon = makeIcon("green");
const orderPendingIcon   = makeIcon("yellow", [30, 49]);
const orderUrgentIcon    = makeIcon("red",    [30, 49]);
const orderActiveIcon    = makeIcon("violet", [30, 49]);
const orderSelectedIcon  = makeIcon("orange", [34, 55]);

const CAIRO: [number, number] = [30.0444, 31.2357];
const URGENT_MS = 5 * 60 * 1000;
const SPREAD_R  = 0.00022; // ~24 m — radius to spread overlapping markers

function toNum(v: string | number | null | undefined): number | null {
  if (v == null) return null;
  const n = Number(v);
  return isNaN(n) ? null : n;
}

// Spread orders that share the same pickup location so none are hidden
function spreadOrders(orders: Order[]): Array<Order & { displayLat: number; displayLng: number }> {
  const groups = new Map<string, number[]>();
  orders.forEach((o, i) => {
    const lat = toNum(o.pickup_lat);
    const lng = toNum(o.pickup_long);
    if (lat == null || lng == null) return;
    const key = `${lat.toFixed(3)},${lng.toFixed(3)}`; // ~111 m grid
    if (!groups.has(key)) groups.set(key, []);
    groups.get(key)!.push(i);
  });

  const result = orders.map((o) => ({
    ...o,
    displayLat: toNum(o.pickup_lat) ?? 0,
    displayLng: toNum(o.pickup_long) ?? 0,
  }));

  groups.forEach((indices) => {
    if (indices.length <= 1) return;
    indices.forEach((idx, j) => {
      const angle = (j / indices.length) * 2 * Math.PI;
      result[idx].displayLat += SPREAD_R * Math.cos(angle);
      result[idx].displayLng += SPREAD_R * Math.sin(angle);
    });
  });

  return result;
}

function FitBounds({ couriers, orders }: { couriers: OnlineCourier[]; orders: Order[] }) {
  const map = useMap();
  useEffect(() => {
    const points: [number, number][] = [];
    couriers.forEach((c) => {
      const lat = toNum(c.lat), lng = toNum(c.lng);
      if (lat != null && lng != null) points.push([lat, lng]);
    });
    orders.forEach((o) => {
      const lat = toNum(o.pickup_lat), lng = toNum(o.pickup_long);
      if (lat != null && lng != null) points.push([lat, lng]);
    });
    if (points.length === 0) { map.setView(CAIRO, 11); return; }
    if (points.length === 1) { map.setView(points[0], 13); return; }
    map.fitBounds(L.latLngBounds(points), { padding: [50, 50], maxZoom: 14 });
  }, [couriers, orders, map]);
  return null;
}

interface Props {
  couriers: OnlineCourier[];
  onlineUserIds: Set<number>;
  orders: Order[];
  selectedOrderId: number | null;
  onOrderSelect: (id: number) => void;
  isFetchingDistances: boolean;
  noLocationLabel: string;
  phoneLabel: string;
}

export default function CouriersLeafletMap({
  couriers,
  onlineUserIds,
  orders,
  selectedOrderId,
  onOrderSelect,
  isFetchingDistances,
  noLocationLabel,
  phoneLabel,
}: Props) {
  const mapRef = useRef<L.Map | null>(null);

  // Remove the Leaflet instance on unmount so HMR / Strict Mode re-mounts work cleanly
  useEffect(() => {
    return () => {
      if (mapRef.current) {
        mapRef.current.remove();
        mapRef.current = null;
      }
    };
  }, []);

  // Only couriers WITH a location are shown on the map — offline/no-location ones are omitted
  const located = couriers.filter((c) => toNum(c.lat) != null && toNum(c.lng) != null);

  const selectedOrder = orders.find((o) => o.id === selectedOrderId) ?? null;
  const selLat = toNum(selectedOrder?.pickup_lat);
  const selLng = toNum(selectedOrder?.pickup_long);
  const hasSelLocation = selLat != null && selLng != null;

  const spreadOrds = useMemo(() => spreadOrders(orders), [orders]);

  return (
    <MapContainer ref={mapRef} center={CAIRO} zoom={11} className="w-full h-full rounded-xl" scrollWheelZoom>
      <TileLayer
        attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>'
        url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
      />
      <FitBounds couriers={couriers} orders={orders} />

      {/* Dashed lines: courier → selected order pickup */}
      {hasSelLocation &&
        located.map((courier) => {
          const cLat = toNum(courier.lat)!;
          const cLng = toNum(courier.lng)!;
          const color = courier.has_active_order ? "#f97316" : "#6366f1";
          return (
            <Polyline
              key={`line-${courier.id}`}
              positions={[[cLat, cLng], [selLat!, selLng!]]}
              pathOptions={{ color, weight: 2, dashArray: "6 6", opacity: 0.8 }}
            >
              <Tooltip sticky>
                <span className="text-xs font-medium">
                  {courierName(courier)}
                  {courier.real_distance != null
                    ? ` · ${formatDistance(courier.real_distance)}${courier.duration != null ? ` · ${formatDuration(courier.duration)}` : ""}`
                    : ""}
                </span>
              </Tooltip>
            </Polyline>
          );
        })}

      {/* Order markers (spread to avoid overlap) */}
      {spreadOrds.map((order) => {
        const lat = order.displayLat;
        const lng = order.displayLng;
        if (!lat && !lng) return null;
        const ageMs = Date.now() - new Date(order.created_at).getTime();
        const isUrgent = ageMs > URGENT_MS && order.status === "PENDING";
        const ageMin = Math.floor(ageMs / 60000);
        const isSelected = order.id === selectedOrderId;
        const isInProgress = order.status === "IN_PROGRESS";

        let icon = isSelected
          ? orderSelectedIcon
          : isInProgress
          ? orderActiveIcon
          : isUrgent
          ? orderUrgentIcon
          : orderPendingIcon;

        return (
          <Marker
            key={`order-${order.id}`}
            position={[lat, lng]}
            icon={icon}
            eventHandlers={{ click: () => onOrderSelect(order.id) }}
            zIndexOffset={isSelected ? 1000 : 0}
          >
            <Popup minWidth={220}>
              <div className="text-sm space-y-2">
                <div className="font-bold text-gray-800 flex items-center gap-2">
                  #{order.order_number}
                  <span className={`text-xs font-medium px-1.5 py-0.5 rounded-full ${
                    isInProgress
                      ? "bg-violet-100 text-violet-700"
                      : isUrgent
                      ? "bg-red-100 text-red-600"
                      : "bg-yellow-100 text-yellow-700"
                  }`}>
                    {isInProgress ? "In Progress" : `${ageMin} min ago`}
                  </span>
                </div>
                {order.product_description && (
                  <p className="text-gray-600 text-xs">{order.product_description}</p>
                )}
                {order.customer && (
                  <div className="text-xs text-gray-600">
                    👤 {order.customer.full_name}
                    {order.customer.phone && (
                      <a href={`tel:${order.customer.phone}`} className="ml-2 text-green-600">📞</a>
                    )}
                  </div>
                )}
                {isInProgress && order.courier && (
                  <div className="text-xs text-violet-600">
                    🛵 {order.courier.full_name ?? order.courier.user?.full_name}
                  </div>
                )}
                {order.pickup_address_description && (
                  <div className="text-xs text-gray-500">
                    📍 <span className="text-gray-700">{order.pickup_address_description}</span>
                  </div>
                )}
                {order.delivery_address_description && (
                  <div className="text-xs text-gray-500">
                    🏁 <span className="text-gray-700">{order.delivery_address_description}</span>
                  </div>
                )}
                {order.status === "PENDING" && (
                  <div className="border-t border-gray-100 pt-2">
                    {isFetchingDistances && isSelected && (
                      <p className="text-xs text-gray-400 animate-pulse">Loading couriers…</p>
                    )}
                    {!isFetchingDistances && isSelected && located.length > 0 && (
                      <div className="space-y-1.5">
                        <p className="text-xs font-semibold text-gray-500 uppercase tracking-wide">
                          Nearest couriers
                        </p>
                        {located.slice(0, 5).map((c, i) => (
                          <div key={c.id} className="flex items-center gap-2 text-xs">
                            <span className="text-gray-400 w-4">{i + 1}.</span>
                            <span className="font-medium text-gray-700 flex-1 truncate">
                              {courierName(c)}
                            </span>
                            {c.real_distance != null && (
                              <span className="text-indigo-600 font-medium">
                                {formatDistance(c.real_distance)}
                              </span>
                            )}
                            {c.duration != null && (
                              <span className="text-amber-600">{formatDuration(c.duration)}</span>
                            )}
                            {c.has_active_order && <span className="text-red-500">●</span>}
                          </div>
                        ))}
                      </div>
                    )}
                    {!isSelected && (
                      <p className="text-xs text-indigo-600 cursor-pointer" onClick={() => onOrderSelect(order.id)}>
                        Click to see distances →
                      </p>
                    )}
                  </div>
                )}
              </div>
            </Popup>
          </Marker>
        );
      })}

      {/* Courier markers with location */}
      {located.map((courier) => {
        const lat = toNum(courier.lat)!;
        const lng = toNum(courier.lng)!;
        const name = courierName(courier);
        const phone = courierPhone(courier);
        const photo = courierPhoto(courier);
        const uid = courier.user?.id ?? courier.user_id;
        const isOnline = onlineUserIds.has(uid);
        return (
          <Marker key={`c-${uid}`} position={[lat, lng]} icon={courierOnlineIcon}>
            <Popup>
              <div className="text-sm space-y-1 min-w-[180px]">
                <div className="flex items-center gap-2">
                  {photo ? (
                    // eslint-disable-next-line @next/next/no-img-element
                    <img src={photo} alt={name} className="w-8 h-8 rounded-full object-cover" />
                  ) : (
                    <div className="w-8 h-8 rounded-full bg-green-100 flex items-center justify-center text-green-700 font-bold text-xs">
                      {name.charAt(0).toUpperCase()}
                    </div>
                  )}
                  <div>
                    <strong className="font-semibold text-gray-800">{name}</strong>
                    <div className="text-xs text-green-500">● Online</div>
                  </div>
                </div>
                <div className="text-gray-500 text-xs">
                  {phoneLabel}: <span className="text-gray-700">{phone}</span>
                </div>
                {courier.real_distance != null && (
                  <div className="flex items-center gap-2 pt-1 border-t border-gray-100">
                    <span className="bg-indigo-50 text-indigo-700 text-xs font-medium px-2 py-0.5 rounded-full">
                      {formatDistance(courier.real_distance)}
                    </span>
                    {courier.duration != null && (
                      <span className="bg-amber-50 text-amber-700 text-xs font-medium px-2 py-0.5 rounded-full">
                        {formatDuration(courier.duration)}
                      </span>
                    )}
                    {courier.has_active_order && (
                      <span className="bg-red-50 text-red-600 text-xs font-medium px-2 py-0.5 rounded-full">Busy</span>
                    )}
                  </div>
                )}
                <CallChatButtons phone={phone} userId={uid} />
              </div>
            </Popup>
          </Marker>
        );
      })}

      {/* Couriers without location are intentionally omitted from the map */}
    </MapContainer>
  );
}
