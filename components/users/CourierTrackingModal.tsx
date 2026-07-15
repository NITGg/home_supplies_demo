"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import { RefreshCw } from "lucide-react";
import axiosInstance from "@/lib/axios";

/**
 * Mock translation function
 */
const t = (key: string, fallback?: string) => fallback || key;

interface CourierTrackingModalProps {
  readonly open: boolean;
  readonly onOpenChange: (open: boolean) => void;
  readonly courierId: number;
  readonly userId: number;
  readonly adminSocket: any;
}

interface LocationUpdateData {
  courierId: number;
  lat: string | number;
  lng: string | number;
}

export function CourierTrackingModal({
  open,
  onOpenChange,
  courierId,
  userId,
  adminSocket,
}: CourierTrackingModalProps) {
  const [lat, setLat] = useState<string | null>(null);
  const [lng, setLng] = useState<string | null>(null);
  const [lastLocationUpdate, setLastLocationUpdate] = useState<string | null>(
    null,
  );
  const [isLoading, setIsLoading] = useState(false);
  const [isRefreshing, setIsRefreshing] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const iframeKeyRef = useRef(0);

  const fetchCourierLocation = useCallback(async () => {
    setIsLoading(true);
    setError(null);
    try {
      const response = await axiosInstance.get(`/users/${userId}`, {
        params: { includes: "courier" },
      });

      const data = response.data;
      // Pattern matching for various API response structures
      const courier =
        data?.user?.courier ||
        data?.data?.courier ||
        data?.courier ||
        (data?.user?.lat !== undefined ? data.user : null);

      if (courier) {
        const newLat =
          courier.lat !== null && courier.lat !== undefined
            ? String(courier.lat)
            : null;
        const newLng =
          courier.lng !== null && courier.lng !== undefined
            ? String(courier.lng)
            : null;

        setLat(newLat);
        setLng(newLng);
        setLastLocationUpdate(courier.last_location_update || null);
        iframeKeyRef.current += 1;

        if (!newLat || !newLng) {
          setError(
            t("noLocationData", "Courier location data not available yet"),
          );
        }
      } else {
        setError(
          t("courierDataNotFound", "Courier data not found in response"),
        );
      }
    } catch (err: any) {
      const errorMsg =
        err?.response?.data?.message ||
        err?.message ||
        "Failed to fetch location";
      setError(errorMsg);
    } finally {
      setIsLoading(false);
    }
  }, [userId, t]);

  const emitRequestLocation = useCallback(() => {
    if (adminSocket?.connected) {
      adminSocket.emit("courier:request_location", {
        courierIds: [courierId],
      });
    }
  }, [adminSocket, courierId]);

  // Initial load logic
  useEffect(() => {
    if (open) {
      fetchCourierLocation();
      emitRequestLocation();
    }
  }, [open, fetchCourierLocation, emitRequestLocation]);

  // Socket listener logic
  useEffect(() => {
    if (!adminSocket || !open) return;

    const handleLocationUpdated = (data: LocationUpdateData) => {
      if (Number(data.courierId) === courierId) {
        const newLat = String(data.lat);
        const newLng = String(data.lng);

        setLat(newLat);
        setLng(newLng);
        setLastLocationUpdate(new Date().toISOString());
        setError(null);
        iframeKeyRef.current += 1;

        // Optionally refresh DB data to keep UI synced with backend timestamps
        fetchCourierLocation();
      }
    };

    adminSocket.on("courier:location_updated", handleLocationUpdated);

    return () => {
      adminSocket.off("courier:location_updated", handleLocationUpdated);
    };
  }, [adminSocket, courierId, open, fetchCourierLocation]);

  const handleRefresh = async () => {
    setIsRefreshing(true);
    emitRequestLocation();
    await fetchCourierLocation();
    setIsRefreshing(false);
  };

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-[600px]">
        <DialogHeader>
          <DialogTitle>{t("courierTracking", "Courier Tracking")}</DialogTitle>
          <DialogDescription>
            {t(
              "courierTrackingDescription",
              "Real-time location tracking for couriers",
            )}
          </DialogDescription>
        </DialogHeader>

        <div className="space-y-4">
          {error && (
            <div className="p-3 bg-destructive/10 border border-destructive/20 text-destructive text-sm rounded-md">
              {error}
            </div>
          )}

          <div className="flex items-center justify-between">
            <Button
              onClick={handleRefresh}
              variant="outline"
              className="flex-1"
              disabled={isRefreshing || isLoading}
            >
              <RefreshCw
                className={`mr-2 h-4 w-4 ${isRefreshing || isLoading ? "animate-spin" : ""}`}
              />
              {isRefreshing
                ? t("refreshing", "Refreshing...")
                : t("refreshLocation", "Refresh Location")}
            </Button>
          </div>

          <div className="grid grid-cols-2 gap-4">
            <div className="space-y-2">
              <p className="text-sm font-medium text-muted-foreground">
                {t("latitude", "Latitude")}
              </p>
              <div className="text-base font-medium font-mono">
                {isLoading ? (
                  <span className="text-muted-foreground italic text-xs">
                    {t("loading", "Loading...")}
                  </span>
                ) : (
                  (lat ?? "-")
                )}
              </div>
            </div>
            <div className="space-y-2">
              <p className="text-sm font-medium text-muted-foreground">
                {t("longitude", "Longitude")}
              </p>
              <div className="text-base font-medium font-mono">
                {isLoading ? (
                  <span className="text-muted-foreground italic text-xs">
                    {t("loading", "Loading...")}
                  </span>
                ) : (
                  (lng ?? "-")
                )}
              </div>
            </div>
          </div>

          <div className="space-y-2">
            <p className="text-sm font-medium text-muted-foreground">
              {t("lastLocationUpdate", "Last Location Update")}
            </p>
            <div className="text-base font-medium">
              {lastLocationUpdate
                ? new Date(lastLocationUpdate).toLocaleString()
                : "-"}
            </div>
          </div>

          {lat && lng && (
            <div className="space-y-2">
              <p className="text-sm font-medium text-muted-foreground">
                {t("mapView", "Map View")}
              </p>
              <div className="w-full h-[300px] rounded-lg overflow-hidden border bg-muted">
                <iframe
                  key={iframeKeyRef.current}
                  width="100%"
                  height="100%"
                  style={{ border: 0 }}
                  src={`https://maps.google.com/maps?q=${lat},${lng}&t=&z=15&ie=UTF8&iwloc=&output=embed`}
                  title="Google Maps"
                />
              </div>
            </div>
          )}
        </div>
      </DialogContent>
    </Dialog>
  );
}
