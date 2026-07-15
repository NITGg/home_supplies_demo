"use client";
import { useEffect, useRef } from "react";

const DEFAULT_ZOOM = 15;

/** 
 * Extend the NodeJS Global and globalThis types for TypeScript 
 */
declare global {
  // Use var for global augmentation in declare global
  var google: any;
  var __googleMapsPromise: Promise<any> | undefined;
}

const loadGoogleMaps = (apiKey: string): Promise<any> => {
  // Use a type-safe reference to the global object
  const _global = globalThis as any;

  if (_global.google?.maps) return Promise.resolve(_global.google);
  if (_global.__googleMapsPromise) return _global.__googleMapsPromise;

  _global.__googleMapsPromise = new Promise((resolve, reject) => {
    // Check if document is defined (for SSR safety)
    if (typeof document === "undefined") return;

    const script = document.createElement("script");
    script.src = `https://maps.googleapis.com/maps/api/js?key=${apiKey}`;
    script.async = true;
    script.defer = true;
    script.onload = () => resolve(_global.google);
    script.onerror = reject;
    document.head.appendChild(script);
  });

  return _global.__googleMapsPromise;
};

interface LocationPointMapProps {
  readonly lat: number;
  readonly long: number;
  readonly heightClassName?: string;
  readonly label?: string;
}

export default function LocationPointMap({
  lat,
  long,
  heightClassName = "h-72",
  label,
}: LocationPointMapProps) {
  const mapRef = useRef<HTMLDivElement | null>(null);
  const mapInstanceRef = useRef<any>(null);
  const markerRef = useRef<any>(null);

  // Use process.env or import.meta based on your bundler (Next.js uses process.env)
  const apiKey = (process.env.NEXT_PUBLIC_GOOGLE_MAPS_API_KEY || 
                  (import.meta as any).env?.VITE_GOOGLE_MAPS_API_KEY) as string | undefined;

  useEffect(() => {
    if (!mapRef.current || !apiKey || apiKey === "FAKE_KEY") return;

    let isMounted = true;

    loadGoogleMaps(apiKey)
      .then((google) => {
        if (!isMounted || !mapRef.current) return;

        const position = { lat, lng: long };

        if (mapInstanceRef.current) {
          mapInstanceRef.current.setCenter(position);
        } else {
          mapInstanceRef.current = new google.maps.Map(mapRef.current, {
            center: position,
            zoom: DEFAULT_ZOOM,
            mapTypeControl: false,
            streetViewControl: false,
            fullscreenControl: true,
          });
        }

        // clear old marker
        if (markerRef.current) {
          markerRef.current.setMap(null);
        }

        markerRef.current = new google.maps.Marker({
          position,
          map: mapInstanceRef.current,
          title: label,
          animation: google.maps.Animation.DROP,
        });

        if (label) {
          const infoWindow = new google.maps.InfoWindow({ content: label });
          markerRef.current.addListener("click", () => {
            infoWindow.open(mapInstanceRef.current, markerRef.current);
          });
        }
      })
      .catch((err) => console.error("Google Maps Load Error:", err));

    return () => {
      isMounted = false;
    };
  }, [lat, long, label, apiKey]);

  if (!apiKey || apiKey === "FAKE_KEY") {
    return (
      <div className={`rounded-md border bg-muted/30 p-4 flex items-center justify-center ${heightClassName}`}>
        <p className="text-sm text-muted-foreground text-center">
          Google Maps is disabled. <br />
          Set <code className="bg-muted px-1">NEXT_PUBLIC_GOOGLE_MAPS_API_KEY</code> to enable.
        </p>
      </div>
    );
  }

  return (
    <div
      ref={mapRef}
      className={`w-full rounded-md border ${heightClassName}`}
    />
  );
}