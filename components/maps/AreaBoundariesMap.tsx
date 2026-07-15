"use client";

import { useEffect, useRef, useState } from "react";

export type BoundaryPoint = { lat: number; lng: number };
export type BoundariesRecord = Record<string, BoundaryPoint>;

const DEFAULT_CENTER = { lat: 30.0444, lng: 31.2357 };

/**
 * Mock translation function
 */
const t = (key: string, fallback?: string) => fallback || key;

declare global {
  interface Window {
    google?: any;
    __googleMapsPromise?: Promise<any>;
  }
}

const loadGoogleMaps = (apiKey: string) => {
  if (typeof window === "undefined") return Promise.reject();
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

const toPoints = (boundaries: BoundariesRecord) =>
  Object.keys(boundaries)
    .sort((a, b) => {
      const ai = Number(a.replace("point", ""));
      const bi = Number(b.replace("point", ""));
      return ai - bi;
    })
    .map((key) => boundaries[key]);

const toBoundaries = (points: BoundaryPoint[]) => {
  const result: BoundariesRecord = {};
  points.forEach((point, index) => {
    result[`point${index + 1}`] = { lat: point.lat, lng: point.lng };
  });
  return result;
};

interface ExistingAreaOverlay {
  name: string;
  boundaries: BoundariesRecord;
}

interface AreaBoundariesMapProps {
  readonly boundaries: BoundariesRecord | null;
  readonly onBoundariesChange: (boundaries: BoundariesRecord) => void;
  readonly heightClassName?: string;
  readonly isReadOnly?: boolean;
  readonly illustrativeBoundaries?: BoundariesRecord[];
  readonly existingAreaBoundaries?: ExistingAreaOverlay[];
  readonly referenceAreaBoundary?: BoundariesRecord | null;
}

export default function AreaBoundariesMap({
  boundaries,
  onBoundariesChange,
  heightClassName = "h-72",
  isReadOnly = false,
  illustrativeBoundaries = [],
  existingAreaBoundaries = [],
  referenceAreaBoundary = null,
}: AreaBoundariesMapProps) {
  const mapRef = useRef<HTMLDivElement | null>(null);
  const mapInstanceRef = useRef<any>(null);
  const polygonRef = useRef<any>(null);
  const illustrativePolygonsRef = useRef<any[]>([]);
  const existingAreaPolygonsRef = useRef<any[]>([]);
  const existingAreaLabelsRef = useRef<any[]>([]);
  const referenceAreaPolygonRef = useRef<any>(null);
  const drawingRef = useRef<any>(null);
  const listenersRef = useRef<any[]>([]);
  const applyingExternalRef = useRef(false);
  const [mapReady, setMapReady] = useState(false);

  // Support both Next.js and Vite env vars
  const apiKey = (process.env.NEXT_PUBLIC_GOOGLE_MAPS_API_KEY as string | undefined);

  // 1. Initialize Map
  useEffect(() => {
    if (!mapRef.current || !apiKey || apiKey === "FAKE_KEY") return;

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

        drawingRef.current = new google.maps.drawing.DrawingManager({
          drawingMode: isReadOnly ? null : google.maps.drawing.OverlayType.POLYGON,
          drawingControl: !isReadOnly,
          drawingControlOptions: {
            drawingModes: [google.maps.drawing.OverlayType.POLYGON],
          },
          polygonOptions: {
            editable: !isReadOnly,
            draggable: !isReadOnly,
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
            if (event.type !== google.maps.drawing.OverlayType.POLYGON) return;

            if (polygonRef.current) {
              polygonRef.current.setMap(null);
            }

            polygonRef.current = event.overlay;
            polygonRef.current.setEditable(!isReadOnly);
            polygonRef.current.setDraggable(!isReadOnly);

            attachPolygonListeners();
            syncFromPolygon();
            drawingRef.current.setDrawingMode(null);
          }
        );

        if (boundaries && Object.keys(boundaries).length > 0) {
          applyBoundaries(boundaries);
        }

        setMapReady(true);
      })
      .catch((err) => {
        console.error("Google Maps Load Error:", err);
      });

    return () => {
      isMounted = false;
    };
  }, [apiKey]);

  // 2. Sync Boundaries
  useEffect(() => {
    if (!mapInstanceRef.current) return;
    applyBoundaries(boundaries);
  }, [boundaries]);

  // 3. Illustrative Governorates
  useEffect(() => {
    if (!mapReady || !mapInstanceRef.current || !window.google?.maps) return;

    illustrativePolygonsRef.current.forEach((p) => p.setMap(null));
    illustrativePolygonsRef.current = [];

    illustrativeBoundaries.forEach((boundary) => {
      if (!boundary || Object.keys(boundary).length === 0) return;
      const points = toPoints(boundary).map(
        (point) => new window.google.maps.LatLng(point.lat, point.lng)
      );

      const poly = new window.google.maps.Polygon({
        paths: points,
        editable: false,
        draggable: false,
        fillColor: "#90caf9",
        fillOpacity: 0.25,
        strokeColor: "#42a5f5",
        strokeWeight: 1,
        clickable: false,
      });

      poly.setMap(mapInstanceRef.current);
      illustrativePolygonsRef.current.push(poly);
    });
  }, [illustrativeBoundaries, mapReady]);

  // 4. Existing Areas (Orange)
  useEffect(() => {
    if (!mapReady || !mapInstanceRef.current || !window.google?.maps) return;

    existingAreaPolygonsRef.current.forEach((p) => p.setMap(null));
    existingAreaPolygonsRef.current = [];
    existingAreaLabelsRef.current.forEach((l) => l.setMap(null));
    existingAreaLabelsRef.current = [];

    existingAreaBoundaries.forEach((areaOverlay) => {
      if (!areaOverlay.boundaries || Object.keys(areaOverlay.boundaries).length === 0) return;
      const points = toPoints(areaOverlay.boundaries).map(
        (point) => new window.google.maps.LatLng(point.lat, point.lng)
      );

      const poly = new window.google.maps.Polygon({
        paths: points,
        editable: false,
        draggable: false,
        fillColor: "#fb8c00",
        fillOpacity: 0.15,
        strokeColor: "#ef6c00",
        strokeWeight: 2,
        strokeOpacity: 0.8,
        clickable: false,
      });
      poly.setMap(mapInstanceRef.current);
      existingAreaPolygonsRef.current.push(poly);

      let latSum = 0;
      let lngSum = 0;
      points.forEach((p: any) => {
        latSum += p.lat();
        lngSum += p.lng();
      });
      const centroid = {
        lat: latSum / points.length,
        lng: lngSum / points.length,
      };

      const label = new window.google.maps.Marker({
        position: centroid,
        map: mapInstanceRef.current,
        label: {
          text: areaOverlay.name,
          color: "#e65100",
          fontSize: "11px",
          fontWeight: "bold",
        },
        icon: {
          path: window.google.maps.SymbolPath.CIRCLE,
          scale: 0,
        },
        clickable: false,
      });
      existingAreaLabelsRef.current.push(label);
    });
  }, [existingAreaBoundaries, mapReady]);

  // 5. Reference OSM (Green)
  useEffect(() => {
    if (!mapReady || !mapInstanceRef.current || !window.google?.maps) return;

    if (referenceAreaPolygonRef.current) {
      referenceAreaPolygonRef.current.setMap(null);
      referenceAreaPolygonRef.current = null;
    }

    if (!referenceAreaBoundary || Object.keys(referenceAreaBoundary).length === 0) return;

    const points = toPoints(referenceAreaBoundary).map(
      (point) => new window.google.maps.LatLng(point.lat, point.lng)
    );

    referenceAreaPolygonRef.current = new window.google.maps.Polygon({
      paths: points,
      editable: false,
      draggable: false,
      fillColor: "#66bb6a",
      fillOpacity: 0.15,
      strokeColor: "#2e7d32",
      strokeWeight: 2,
      strokeOpacity: 0.9,
      clickable: false,
    });
    referenceAreaPolygonRef.current.setMap(mapInstanceRef.current);
  }, [referenceAreaBoundary, mapReady]);

  const clearListeners = () => {
    listenersRef.current.forEach((listener) => listener.remove());
    listenersRef.current = [];
  };

  const attachPolygonListeners = () => {
    if (!polygonRef.current) return;
    clearListeners();

    const path = polygonRef.current.getPath();
    listenersRef.current.push(
      path.addListener("set_at", syncFromPolygon),
      path.addListener("insert_at", syncFromPolygon),
      path.addListener("remove_at", syncFromPolygon)
    );
  };

  function syncFromPolygon() {
    if (!polygonRef.current || applyingExternalRef.current) return;
    const path = polygonRef.current.getPath();
    const points = path.getArray().map((p: any) => ({
      lat: p.lat(),
      lng: p.lng(),
    }));
    if (points.length === 0) return;
    onBoundariesChange(toBoundaries(points));
  }

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
      (point) => new window.google.maps.LatLng(point.lat, point.lng)
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
      attachPolygonListeners();
    } else {
      polygonRef.current.setPath(points);
    }

    const bounds = new window.google.maps.LatLngBounds();
    points.forEach((p: any) => bounds.extend(p));
    if (!bounds.isEmpty()) {
      mapInstanceRef.current.fitBounds(bounds);
    }

    applyingExternalRef.current = false;
  };

  if (!apiKey || apiKey === "FAKE_KEY") {
    return (
      <div className={`rounded-md border bg-muted/30 p-4 flex items-center justify-center ${heightClassName}`}>
        <div className="text-sm text-muted-foreground text-center">
          {t("mapsDisabled", "Google Maps is disabled. Set your API Key to enable the map.")}
        </div>
      </div>
    );
  }

  return <div ref={mapRef} className={`w-full rounded-md border ${heightClassName}`} />;
}