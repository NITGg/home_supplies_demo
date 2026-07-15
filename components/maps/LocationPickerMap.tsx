"use client";
import { useEffect, useRef } from "react";

const DEFAULT_ZOOM = 14;
const DEFAULT_CENTER = { lat: 30.0444, lng: 31.2357 }; // Cairo

import { loadGoogleMaps } from "@/lib/googleMaps";

interface LocationPickerMapProps {
  readonly lat: number | null;
  readonly long: number | null;
  /** Called with the picked coordinates whenever the user clicks/drags the marker. */
  readonly onChange: (lat: number, long: number) => void;
  /** Fallback center (e.g. the selected area's centroid) used when no point is set yet. */
  readonly centerLat?: number | null;
  readonly centerLong?: number | null;
  readonly heightClassName?: string;
  readonly disabled?: boolean;
}

/**
 * Interactive marker picker. Click anywhere on the map (or drag the marker) to
 * set a point; the chosen latitude/longitude are reported through `onChange`.
 * Falls back to a friendly notice when no Google Maps API key is configured —
 * the parent form still exposes manual latitude/longitude inputs in that case.
 */
export default function LocationPickerMap({
  lat,
  long,
  onChange,
  centerLat,
  centerLong,
  heightClassName = "h-64",
  disabled = false,
}: LocationPickerMapProps) {
  const mapRef = useRef<HTMLDivElement | null>(null);
  const searchInputRef = useRef<HTMLInputElement | null>(null);
  const mapInstanceRef = useRef<any>(null);
  const markerRef = useRef<any>(null);

  // Keep the latest props in refs so the map is initialised only once.
  const onChangeRef = useRef(onChange);
  onChangeRef.current = onChange;
  const disabledRef = useRef(disabled);
  disabledRef.current = disabled;

  const apiKey = process.env.NEXT_PUBLIC_GOOGLE_MAPS_API_KEY;

  // ── Initialise the map once ──────────────────────────────────────────────
  useEffect(() => {
    if (!mapRef.current || !apiKey || apiKey === "FAKE_KEY") return;

    let isMounted = true;

    loadGoogleMaps(apiKey)
      .then((google) => {
        if (!isMounted || !mapRef.current || mapInstanceRef.current) return;

        const hasPoint = typeof lat === "number" && typeof long === "number";
        const hasCenter = typeof centerLat === "number" && typeof centerLong === "number";
        const center = hasPoint
          ? { lat: lat as number, lng: long as number }
          : hasCenter
            ? { lat: centerLat as number, lng: centerLong as number }
            : DEFAULT_CENTER;

        mapInstanceRef.current = new google.maps.Map(mapRef.current, {
          center,
          zoom: hasPoint || hasCenter ? DEFAULT_ZOOM + 1 : DEFAULT_ZOOM,
          mapTypeControl: false,
          streetViewControl: false,
          fullscreenControl: true,
        });

        if (hasPoint) placeMarker(google, center.lat, center.lng);

        const searchInput = searchInputRef.current;
        if (searchInput && google.maps.places) {
          const searchBox = new google.maps.places.SearchBox(searchInput);
          mapInstanceRef.current.controls[google.maps.ControlPosition.TOP_CENTER].push(searchInput);

          searchBox.addListener("places_changed", () => {
            if (disabledRef.current) return;
            const places = searchBox.getPlaces();
            if (!places || places.length === 0) return;

            const place = places[0];
            if (!place.geometry || !place.geometry.location) return;

            const newLat = place.geometry.location.lat();
            const newLng = place.geometry.location.lng();

            placeMarker(google, newLat, newLng);
            mapInstanceRef.current.panTo({ lat: newLat, lng: newLng });
            mapInstanceRef.current.setZoom(16);
            onChangeRef.current(newLat, newLng);
          });

          mapInstanceRef.current.addListener("bounds_changed", () => {
            searchBox.setBounds(mapInstanceRef.current.getBounds());
          });
        }

        // Click listener is always attached; it short-circuits while disabled.
        mapInstanceRef.current.addListener("click", (e: any) => {
          if (disabledRef.current) return;
          const clickedLat = e.latLng.lat();
          const clickedLng = e.latLng.lng();
          placeMarker(google, clickedLat, clickedLng);
          onChangeRef.current(clickedLat, clickedLng);
        });
      })
      .catch((err) => console.error("Google Maps Load Error:", err));

    return () => {
      isMounted = false;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [apiKey]);

  // ── Sync marker when the lat/long props change externally ────────────────
  useEffect(() => {
    const google = (globalThis as any).google;
    if (!mapInstanceRef.current || !google?.maps) return;
    if (typeof lat !== "number" || typeof long !== "number") return;

    placeMarker(google, lat, long);
    mapInstanceRef.current.panTo({ lat, lng: long });
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [lat, long]);

  // ── Recenter on the area centroid when there is no pin yet ───────────────
  useEffect(() => {
    if (!mapInstanceRef.current) return;
    const hasPoint = typeof lat === "number" && typeof long === "number";
    if (hasPoint) return;
    if (typeof centerLat !== "number" || typeof centerLong !== "number") return;
    mapInstanceRef.current.panTo({ lat: centerLat, lng: centerLong });
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [centerLat, centerLong]);

  // ── Reflect disabled state on the marker drag handle ─────────────────────
  useEffect(() => {
    if (markerRef.current) markerRef.current.setDraggable(!disabled);
  }, [disabled]);

  function placeMarker(google: any, markerLat: number, markerLng: number) {
    const position = { lat: markerLat, lng: markerLng };
    if (markerRef.current) {
      markerRef.current.setPosition(position);
      return;
    }
    markerRef.current = new google.maps.Marker({
      position,
      map: mapInstanceRef.current,
      draggable: !disabledRef.current,
      animation: google.maps.Animation.DROP,
    });
    markerRef.current.addListener("dragend", (e: any) => {
      if (disabledRef.current) return;
      onChangeRef.current(e.latLng.lat(), e.latLng.lng());
    });
  }

  if (!apiKey || apiKey === "FAKE_KEY") {
    return (
      <div
        className={`rounded-xl border border-dashed border-gray-300 bg-gray-50 p-4 flex items-center justify-center ${heightClassName}`}
      >
        <p className="text-xs text-gray-500 text-center">
          Google Maps is disabled. Enter the latitude / longitude manually below.
        </p>
      </div>
    );
  }

  return (
    <div className="relative w-full">
      <input
        ref={searchInputRef}
        type="text"
        placeholder="Search for a place..."
        className={`mt-2.5 w-[80%] max-w-sm px-4 py-2 text-sm text-gray-900 bg-white border border-gray-300 rounded-lg shadow-md focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500 outline-none ${
          disabled ? "opacity-60 pointer-events-none" : ""
        }`}
        disabled={disabled}
      />
      <div
        ref={mapRef}
        className={`w-full rounded-xl border border-gray-200 ${heightClassName} ${
          disabled ? "opacity-60 pointer-events-none" : ""
        }`}
      />
    </div>
  );
}
