import { CourierLocation } from "@/types/order";
import { useEffect, useRef } from "react";
import "leaflet/dist/leaflet.css";
import L from "leaflet";

import markerIcon2x from "leaflet/dist/images/marker-icon-2x.png";
import markerIcon from "leaflet/dist/images/marker-icon.png";
import markerShadow from "leaflet/dist/images/marker-shadow.png";

delete (L.Icon.Default.prototype as any)._getIconUrl;
L.Icon.Default.mergeOptions({
  iconUrl: markerIcon,
  iconRetinaUrl: markerIcon2x,
  shadowUrl: markerShadow,
});

interface LatLng {
  lat: number;
  lng: number;
}

interface Props {
  location: CourierLocation;
  pickupLat?: string | null;
  pickupLng?: string | null;
  deliveryLat?: string | null;
  deliveryLng?: string | null;
  orderCollectedAt?: string | null;
}

function parseLatLng(lat?: string | null, lng?: string | null): LatLng | null {
  const la = Number(lat);
  const lo = Number(lng);
  if (!lat || !lng || Number.isNaN(la) || Number.isNaN(lo)) return null;
  return { lat: la, lng: lo };
}

function computeBearing(from: LatLng, to: LatLng): number {
  const toRad = (d: number) => (d * Math.PI) / 180;
  const dLng = toRad(to.lng - from.lng);
  const lat1 = toRad(from.lat);
  const lat2 = toRad(to.lat);
  const y = Math.sin(dLng) * Math.cos(lat2);
  const x =
    Math.cos(lat1) * Math.sin(lat2) -
    Math.sin(lat1) * Math.cos(lat2) * Math.cos(dLng);
  return ((Math.atan2(y, x) * 180) / Math.PI + 360) % 360;
}

function makeCourierIcon(bearing: number): L.DivIcon {
  return L.divIcon({
    className: "",
    html: `
      <div style="
        width:32px;height:32px;
        display:flex;align-items:center;justify-content:center;
        transform:rotate(${bearing}deg);
        transition:transform 0.3s ease;
      ">
        <svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" viewBox="0 0 32 32">
          <circle cx="16" cy="16" r="15" fill="#2563eb" stroke="#fff" stroke-width="2"/>
          <polygon points="16,5 22,24 16,19 10,24" fill="#fff"/>
        </svg>
      </div>`,
    iconSize: [32, 32],
    iconAnchor: [16, 16],
  });
}

// ── OSRM with AbortController ─────────────────────────────────────────────────
const fetchRoadRoute = async (
  origin: LatLng,
  destination: LatLng,
  signal?: AbortSignal,
): Promise<LatLng[]> => {
  try {
    const url =
      `https://router.project-osrm.org/route/v1/driving/` +
      `${origin.lng},${origin.lat};${destination.lng},${destination.lat}` +
      `?overview=simplified&geometries=geojson`;
    const res = await fetch(url, { signal });
    if (!res.ok) throw new Error("osrm error");
    const data = await res.json();
    const coords: [number, number][] =
      data?.routes?.[0]?.geometry?.coordinates ?? [];
    if (coords.length === 0) return [origin, destination];
    return coords.map(([lng, lat]) => ({ lat, lng }));
  } catch {
    return [origin, destination];
  }
};

// ── Minimum distance threshold to bother re-routing (~20m) ───────────────────
const MIN_MOVE_DEGREES = 0.0002;
function movedEnough(a: LatLng, b: LatLng): boolean {
  return (
    Math.abs(a.lat - b.lat) > MIN_MOVE_DEGREES ||
    Math.abs(a.lng - b.lng) > MIN_MOVE_DEGREES
  );
}

// ── Static icons ──────────────────────────────────────────────────────────────
const pickupPendingIcon = L.divIcon({
  className: "",
  html: `<svg xmlns="http://www.w3.org/2000/svg" width="32" height="40" viewBox="0 0 32 40">
    <path d="M16 0C7.163 0 0 7.163 0 16c0 10 16 24 16 24s16-14 16-24C32 7.163 24.837 0 16 0z" fill="#16a34a" stroke="#fff" stroke-width="1.5"/>
    <circle cx="16" cy="16" r="6" fill="#fff"/>
    <text x="16" y="20" text-anchor="middle" font-size="9" font-weight="bold" fill="#16a34a">P</text>
  </svg>`,
  iconSize: [32, 40],
  iconAnchor: [16, 40],
  popupAnchor: [0, -40],
});

const pickupCollectedIcon = L.divIcon({
  className: "",
  html: `<svg xmlns="http://www.w3.org/2000/svg" width="32" height="40" viewBox="0 0 32 40">
    <path d="M16 0C7.163 0 0 7.163 0 16c0 10 16 24 16 24s16-14 16-24C32 7.163 24.837 0 16 0z" fill="#6b7280" stroke="#fff" stroke-width="1.5"/>
    <circle cx="16" cy="16" r="6" fill="#fff"/>
    <text x="16" y="20" text-anchor="middle" font-size="10" font-weight="bold" fill="#6b7280">✓</text>
  </svg>`,
  iconSize: [32, 40],
  iconAnchor: [16, 40],
  popupAnchor: [0, -40],
});

const deliveryIcon = L.divIcon({
  className: "",
  html: `<svg xmlns="http://www.w3.org/2000/svg" width="32" height="40" viewBox="0 0 32 40">
    <path d="M16 0C7.163 0 0 7.163 0 16c0 10 16 24 16 24s16-14 16-24C32 7.163 24.837 0 16 0z" fill="#dc2626" stroke="#fff" stroke-width="1.5"/>
    <circle cx="16" cy="16" r="6" fill="#fff"/>
    <text x="16" y="20" text-anchor="middle" font-size="9" font-weight="bold" fill="#dc2626">D</text>
  </svg>`,
  iconSize: [32, 40],
  iconAnchor: [16, 40],
  popupAnchor: [0, -40],
});

export default function CourierTrackingMap({
  location,
  pickupLat,
  pickupLng,
  deliveryLat,
  deliveryLng,
  orderCollectedAt,
}: Readonly<Props>) {
  const mapRef = useRef<HTMLDivElement | null>(null);
  const mapInstanceRef = useRef<L.Map | null>(null);
  const courierMarkerRef = useRef<L.Marker | null>(null);
  const livePolylineRef = useRef<L.Polyline | null>(null);
  const abortRef = useRef<AbortController | null>(null);
  const prevLocationRef = useRef<LatLng | null>(null);
  const isInitializedRef = useRef(false);
  const isCollectedRef = useRef(!!orderCollectedAt);

  const pickup = parseLatLng(pickupLat, pickupLng);
  const delivery = parseLatLng(deliveryLat, deliveryLng);
  const isCollected = !!orderCollectedAt;

  useEffect(() => {
    isCollectedRef.current = isCollected;
  }, [isCollected]);

  // ── Initialize map once ───────────────────────────────────────────────────
  useEffect(() => {
    if (isInitializedRef.current || !mapRef.current) return;
    isInitializedRef.current = true;

    let mounted = true;
    const courierPos: L.LatLngTuple = [location.lat, location.lng];
    prevLocationRef.current = { lat: location.lat, lng: location.lng };

    const map = L.map(mapRef.current, { zoomControl: true }).setView(
      courierPos,
      14,
    );
    mapInstanceRef.current = map;

    L.tileLayer("https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png", {
      attribution:
        '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors',
      maxZoom: 19,
    }).addTo(map);

    // Fit bounds
    const allPoints: L.LatLngTuple[] = [courierPos];
    if (pickup) allPoints.push([pickup.lat, pickup.lng]);
    if (delivery && isCollected) allPoints.push([delivery.lat, delivery.lng]);
    if (allPoints.length > 1) {
      map.fitBounds(L.latLngBounds(allPoints), { padding: [40, 40] });
    }

    // Courier marker
    courierMarkerRef.current = L.marker(courierPos, {
      icon: makeCourierIcon(0),
      zIndexOffset: 1000,
    })
      .addTo(map)
      .bindPopup(`<b>Courier #${location.courierId}</b>`);

    // Pickup marker
    if (pickup) {
      const icon = isCollected ? pickupCollectedIcon : pickupPendingIcon;
      const popupContent = isCollected
        ? `<b>Pickup</b><br/><span style="color:#6b7280;font-size:12px">✓ Collected at ${new Date(orderCollectedAt).toLocaleTimeString()}</span>`
        : "<b>Pickup</b><br/><span style='color:#16a34a;font-size:12px'>⏳ Courier heading here</span>";
      L.marker([pickup.lat, pickup.lng], { icon })
        .addTo(map)
        .bindPopup(popupContent);
    }

    // Delivery marker
    if (delivery && isCollected) {
      L.marker([delivery.lat, delivery.lng], { icon: deliveryIcon })
        .addTo(map)
        .bindPopup(
          "<b>Delivery</b><br/><span style='color:#dc2626;font-size:12px'>🎯 Destination</span>",
        );
    }

    // ── Create live polyline immediately as straight line (no lag) ──
    const destination = isCollected ? delivery : pickup;
    livePolylineRef.current = L.polyline(
      destination
        ? [
            [location.lat, location.lng],
            [destination.lat, destination.lng],
          ]
        : [[location.lat, location.lng]],
      { color: "#2563eb", weight: 5, opacity: 0.85 },
    ).addTo(map);

    // ── Then upgrade to real road route async ──
    const initRoute = async () => {
      if (!destination) return;
      const controller = new AbortController();
      abortRef.current = controller;

      const path = await fetchRoadRoute(
        { lat: location.lat, lng: location.lng },
        destination,
        controller.signal,
      );
      if (!mounted) return;

      livePolylineRef.current?.setLatLngs(path.map((p) => [p.lat, p.lng]));

      if (path.length >= 2) {
        const bearing = computeBearing(path[0], path[1]);
        courierMarkerRef.current?.setIcon(makeCourierIcon(bearing));
      }

      // Static dashed reference line pickup → delivery (phase 2 only)
      if (isCollected && pickup && delivery) {
        const staticPath = await fetchRoadRoute(
          pickup,
          delivery,
          controller.signal,
        );
        if (!mounted) return;
        L.polyline(
          staticPath.map((p) => [p.lat, p.lng] as L.LatLngTuple),
          { color: "#94a3b8", weight: 3, opacity: 0.4, dashArray: "8 6" },
        ).addTo(map);
      }
    };

    initRoute();

    return () => {
      mounted = false;
      abortRef.current?.abort();
      map.remove();
      mapInstanceRef.current = null;
      courierMarkerRef.current = null;
      livePolylineRef.current = null;
      isInitializedRef.current = false;
      prevLocationRef.current = null;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // ── Update on every location push ─────────────────────────────────────────
  useEffect(() => {
    if (!courierMarkerRef.current || !mapInstanceRef.current) return;

    const current: LatLng = { lat: location.lat, lng: location.lng };
    const destination = isCollectedRef.current ? delivery : pickup;

    // 1. Move marker instantly — zero lag
    courierMarkerRef.current.setLatLng([current.lat, current.lng]);
    mapInstanceRef.current.panTo([current.lat, current.lng]);

    if (!destination) return;

    // 2. Draw straight fallback immediately so line follows courier with no delay
    if (
      !prevLocationRef.current ||
      movedEnough(prevLocationRef.current, current)
    ) {
      livePolylineRef.current?.setLatLngs([
        [current.lat, current.lng],
        [destination.lat, destination.lng],
      ]);
    }

    // 3. Skip OSRM re-fetch if courier barely moved
    if (
      prevLocationRef.current &&
      !movedEnough(prevLocationRef.current, current)
    ) {
      return;
    }
    prevLocationRef.current = current;

    // 4. Cancel previous in-flight request, fetch new road route
    abortRef.current?.abort();
    abortRef.current = new AbortController();

    fetchRoadRoute(current, destination, abortRef.current.signal).then(
      (path) => {
        // Replace straight line with real road route when ready
        livePolylineRef.current?.setLatLngs(path.map((p) => [p.lat, p.lng]));

        // Update arrow bearing from road
        if (path.length >= 2) {
          const bearing = computeBearing(path[0], path[1]);
          courierMarkerRef.current?.setIcon(makeCourierIcon(bearing));
        }
      },
    );
  }, [location.lat, location.lng, pickup, delivery]);

  useEffect(() => {
    return () => {
      abortRef.current?.abort();
    };
  }, []);

  return (
    <div className="space-y-2">
      <div className="flex items-center gap-2 text-sm">
        {isCollected ? (
          <>
            <span className="inline-flex items-center gap-1.5 rounded-full bg-blue-100 px-3 py-1 text-blue-700 font-medium">
              <span className="h-2 w-2 rounded-full bg-blue-500 animate-pulse" /> {" "}
              Heading to delivery
            </span>
            <span className="text-muted-foreground text-xs">
              Collected at {new Date(orderCollectedAt).toLocaleTimeString()}
            </span>
          </>
        ) : (
          <span className="inline-flex items-center gap-1.5 rounded-full bg-green-100 px-3 py-1 text-green-700 font-medium">
            <span className="h-2 w-2 rounded-full bg-green-500 animate-pulse" /> {" "}
            Heading to pickup
          </span>
        )}
      </div>

      <div
        ref={mapRef}
        className="w-full rounded-md border h-96"
        style={{ zIndex: 0 }}
      />
    </div>
  );
}
