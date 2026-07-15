"use client";
import { useEffect, useRef, useState } from "react";

export type BoundaryPoint = { lat: number; lng: number };
export type BoundariesRecord = Record<string, BoundaryPoint>;

const DEFAULT_CENTER = { lat: 30.0444, lng: 31.2357 }; // Cairo

declare global {
  interface Window {
    google?: any;
    __googleMapsPromise?: Promise<any>;
  }
}

const loadGoogleMaps = (apiKey: string) => {
  if (typeof window === "undefined") return Promise.reject("No window");
  if (window.google?.maps) return Promise.resolve(window.google);
  if (window.__googleMapsPromise) return window.__googleMapsPromise;

  window.__googleMapsPromise = new Promise((resolve, reject) => {
    const script = document.createElement("script");
    script.src = `https://maps.googleapis.com/maps/api/js?key=${apiKey}&libraries=drawing`;
    script.async = true;
    script.defer = true;
    script.onload = () => resolve(window.google);
    script.onerror = reject;
    document.head.appendChild(script);
  });

  return window.__googleMapsPromise;
};

const toPoints = (boundaries: BoundariesRecord): BoundaryPoint[] =>
  Object.keys(boundaries)
    .sort((a, b) => {
      const ai = Number(a.replace("point", ""));
      const bi = Number(b.replace("point", ""));
      return ai - bi;
    })
    .map((key) => boundaries[key]);

const toBoundaries = (points: BoundaryPoint[]): BoundariesRecord => {
  const result: BoundariesRecord = {};
  points.forEach((point, index) => {
    result[`point${index + 1}`] = { lat: point.lat, lng: point.lng };
  });
  return result;
};

interface AreaBoundariesMapProps {
  boundaries: BoundariesRecord | null;
  onBoundariesChange: (boundaries: BoundariesRecord) => void;
  heightClassName?: string;
  isReadOnly?: boolean;
  governorates?: { id: number; name: string }[];
}

export default function AreaBoundariesMap({
  boundaries,
  onBoundariesChange,
  heightClassName = "h-72",
  isReadOnly = false,
  governorates = [],
}: AreaBoundariesMapProps) {
  const mapRef = useRef<HTMLDivElement | null>(null);
  const mapInstanceRef = useRef<any>(null);
  const polygonRef = useRef<any>(null);
  const drawingRef = useRef<any>(null);
  const listenersRef = useRef<any[]>([]);
  const applyingExternalRef = useRef(false);
  const isInternalChangeRef = useRef(false);
  const [mapReady, setMapReady] = useState(false);
  const [apiKeyMissing, setApiKeyMissing] = useState(false);

  const apiKey = process.env.NEXT_PUBLIC_GOOGLE_MAPS_API_KEY;

  // Initialize map
  useEffect(() => {
    if (!mapRef.current || !apiKey) {
      if (!apiKey) setApiKeyMissing(true);
      return;
    }

    let isMounted = true;

    loadGoogleMaps(apiKey)
      .then((google) => {
        if (!isMounted || mapInstanceRef.current) return;

        mapInstanceRef.current = new google.maps.Map(mapRef.current, {
          center: DEFAULT_CENTER,
          zoom: 11,
          mapTypeControl: false,
          streetViewControl: false,
        });

        if (!isReadOnly) {
          drawingRef.current = new google.maps.drawing.DrawingManager({
            drawingMode: google.maps.drawing.OverlayType.POLYGON,
            drawingControl: true,
            drawingControlOptions: {
              drawingModes: [google.maps.drawing.OverlayType.POLYGON],
              position: google.maps.ControlPosition.TOP_CENTER,
            },
            polygonOptions: {
              editable: true,
              draggable: true,
              fillColor: "#3b82f6",
              fillOpacity: 0.2,
              strokeColor: "#1d4ed8",
              strokeWeight: 2,
            },
          });

          drawingRef.current.setMap(mapInstanceRef.current);

          google.maps.event.addListener(
            drawingRef.current,
            "overlaycomplete",
            (event: any) => {
              if (event.type !== google.maps.drawing.OverlayType.POLYGON)
                return;

              if (polygonRef.current) {
                polygonRef.current.setMap(null);
              }

              polygonRef.current = event.overlay;
              polygonRef.current.setEditable(true);
              polygonRef.current.setDraggable(true);

              attachPolygonListeners();
              syncFromPolygon();
              drawingRef.current.setDrawingMode(null);
            },
          );
        }

        if (boundaries && Object.keys(boundaries).length > 0) {
          applyBoundaries(boundaries);
        }

        setMapReady(true);
      })
      .catch(() => {
        setApiKeyMissing(true);
      });

    return () => {
      isMounted = false;
    };
  }, [apiKey, isReadOnly]);

  // Update polygon when boundaries prop changes (skip if change came from the map itself)
  useEffect(() => {
    if (!mapInstanceRef.current) return;
    if (isInternalChangeRef.current) {
      isInternalChangeRef.current = false;
      return;
    }
    applyBoundaries(boundaries);
  }, [boundaries]);

  const clearListeners = () => {
    listenersRef.current.forEach((listener) => listener?.remove?.());
    listenersRef.current = [];
  };

  const attachPolygonListeners = () => {
    if (!polygonRef.current) return;
    clearListeners();

    const path = polygonRef.current.getPath();
    listenersRef.current.push(
      path.addListener("set_at", syncFromPolygon),
      path.addListener("insert_at", syncFromPolygon),
      path.addListener("remove_at", syncFromPolygon),
    );
  };

  const syncFromPolygon = () => {
    if (!polygonRef.current || applyingExternalRef.current) return;
    const path = polygonRef.current.getPath();
    const points = path.getArray().map((p: any) => ({
      lat: p.lat(),
      lng: p.lng(),
    }));
    if (points.length === 0) return;
    // Mark this as an internal change so the boundaries useEffect
    // doesn't re-apply and overwrite the polygon we just edited
    isInternalChangeRef.current = true;
    onBoundariesChange(toBoundaries(points));
  };

  const applyBoundaries = (next: BoundariesRecord | null) => {
    if (!mapInstanceRef.current || !window.google?.maps) return;

    if (!next || Object.keys(next).length === 0) {
      if (polygonRef.current) {
        polygonRef.current.setMap(null);
        polygonRef.current = null;
      }
      return;
    }

    applyingExternalRef.current = true;
    const points = toPoints(next).map(
      (point) => new window.google.maps.LatLng(point.lat, point.lng),
    );

    if (!polygonRef.current) {
      polygonRef.current = new window.google.maps.Polygon({
        paths: points,
        editable: !isReadOnly,
        draggable: !isReadOnly,
        fillColor: "#3b82f6",
        fillOpacity: 0.2,
        strokeColor: "#1d4ed8",
        strokeWeight: 2,
      });
      polygonRef.current.setMap(mapInstanceRef.current);
      if (!isReadOnly) attachPolygonListeners();
    } else {
      polygonRef.current.setPath(points);
    }

    // Fit bounds to show the polygon
    const bounds = new window.google.maps.LatLngBounds();
    points.forEach((p: any) => bounds.extend(p));
    if (!bounds.isEmpty() && mapInstanceRef.current) {
      mapInstanceRef.current.fitBounds(bounds);
    }

    applyingExternalRef.current = false;
  };

  if (apiKeyMissing) {
    return (
      <div
        className={`rounded-md border border-gray-200 bg-gray-50 p-4 ${heightClassName} flex items-center justify-center`}
      >
        <div className="text-sm text-gray-500 text-center">
          <p className="font-medium text-gray-700 mb-1">
            Google Maps API Key Required
          </p>
          <p>
            Set{" "}
            <code className="bg-gray-100 px-1 py-0.5 rounded text-xs">
              NEXT_PUBLIC_GOOGLE_MAPS_API_KEY
            </code>{" "}
            in your .env.local
          </p>
          <p className="mt-2 text-xs text-gray-400">
            You can still enter boundaries manually below
          </p>
        </div>
      </div>
    );
  }

  return (
    <div className="space-y-2">
      <div
        ref={mapRef}
        className={`w-full rounded-md border border-gray-200 ${heightClassName}`}
      />
      {!isReadOnly && (
        <p className="text-xs text-gray-500">
          Draw a polygon on the map using the polygon tool, or enter boundaries
          manually below.
        </p>
      )}
    </div>
  );
}
