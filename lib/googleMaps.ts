// src/lib/googleMaps.ts  ← shared across all map components
let promise: Promise<any> | null = null;

export const loadGoogleMaps = (apiKey: string): Promise<any> => {
  if (globalThis.google?.maps?.geometry)
    return Promise.resolve(globalThis.google);
  if (promise) return promise;

  promise = new Promise((resolve, reject) => {
    const script = document.createElement("script");
    script.src = `https://maps.googleapis.com/maps/api/js?key=${apiKey}&libraries=geometry,places`;
    script.async = true;
    script.defer = true;
    script.onload = () => resolve(globalThis.google);
    script.onerror = reject;
    document.head.appendChild(script);
  });

  return promise;
};
