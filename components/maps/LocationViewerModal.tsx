"use client";

import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
// import { useTranslation } from "react-i18next";
import { Copy, MapPin } from "lucide-react";
import { Button } from "@/components/ui/button";
import { useToast } from "@/hooks/use-toast";
import LocationPointMap from "./LocationPointMap";

interface LocationViewerModalProps {
  isOpen: boolean;
  onClose: () => void;
  lat: number | string | null | undefined;
  long: number | string | null | undefined;
  label?: string;
}

export default function LocationViewerModal({
  isOpen,
  onClose,
  lat,
  long,
  label,
}: Readonly<LocationViewerModalProps>) {
  // const { t } = useTranslation();
  const t = (key: string, fallback: string) => fallback;
  const { toast } = useToast();

  const numLat = Number(lat);
  const numLng = Number(long);
  
  // Strict validation: Coordinates must be numbers and within valid GPS ranges
  const isValid =
    lat != null &&
    long != null &&
    !Number.isNaN(numLat) &&
    !Number.isNaN(numLng) &&
    Math.abs(numLat) <= 90 &&
    Math.abs(numLng) <= 180;

  const copyToClipboard = () => {
    const coords = `${numLat}, ${numLng}`;
    navigator.clipboard.writeText(coords);
    toast({
      description: t("coordsCopied", "Coordinates copied to clipboard"),
    });
  };

  return (
    <Dialog open={isOpen} onOpenChange={(open) => !open && onClose()}>
      <DialogContent className="max-w-2xl gap-0 p-0 overflow-hidden">
        <DialogHeader className="p-6 pb-2">
          <DialogTitle className="flex items-center gap-2">
            <MapPin className="h-5 w-5 text-primary" />
            {label ?? t("unavailableAreaRequest.viewLocation", "View Location")}
          </DialogTitle>
        </DialogHeader>

        <div className="p-6 pt-2">
          {isValid ? (
            <div className="space-y-4">
              <div className="flex items-center justify-between bg-muted/50 p-2 px-3 rounded-lg border border-border/50">
                <p className="text-xs font-mono font-medium text-muted-foreground">
                  {numLat.toFixed(6)}, {numLng.toFixed(6)}
                </p>
                <Button 
                  variant="ghost" 
                  size="icon" 
                  className="h-7 w-7" 
                  onClick={copyToClipboard}
                  title={t("copyCoordinates", "Copy Coordinates")}
                >
                  <Copy className="h-3.5 w-3.5" />
                </Button>
              </div>
              
              <div className="rounded-xl border overflow-hidden shadow-inner bg-muted/20">
                <LocationPointMap
                  lat={numLat}
                  long={numLng}
                  heightClassName="h-[400px]"
                  label={label}
                />
              </div>
            </div>
          ) : (
            <div className="py-20 flex flex-col items-center justify-center space-y-2 opacity-60">
              <MapPin className="h-10 w-10 text-muted" />
              <p className="text-sm font-medium">
                {t("unavailableAreaRequest.noLocation", "No location data available.")}
              </p>
            </div>
          )}
        </div>
      </DialogContent>
    </Dialog>
  );
}