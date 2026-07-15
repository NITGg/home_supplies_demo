"use client";

import { useEffect } from "react";
// import { useTranslation } from "react-i18next";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import {
  Sheet,
  SheetContent,
  SheetHeader,
  SheetTitle,
} from "@/components/ui/sheet";
import {
  Form,
  FormField,
  FormItem,
  FormLabel,
  FormControl,
  FormMessage,
} from "@/components/ui/form";
import { Input } from "@/components/ui/input";
import { Button } from "@/components/ui/button";
import { useToast } from "@/hooks/use-toast";
import axiosInstance from "@/lib/axios";

const t = (key: string, fallback?: string) => fallback || key;

const addressSchema = z.object({
  area_id: z.coerce.number().min(1, "Area is required"),
  address_lat: z.string().min(1, "Latitude is required"),
  address_long: z.string().min(1, "Longitude is required"),
  detailed_address: z.string().min(1, "Detailed address is required"),
});

// Use the OUTPUT type (post-coerce), not the input type
type AddressFormValues = z.output<typeof addressSchema>;

interface AddressEditSheetProps {
  readonly userId: string | number;
  readonly address: Record<string, unknown> | null;
  readonly open: boolean;
  readonly onOpenChange: (open: boolean) => void;
  readonly onSuccess: () => void;
}

export function AddressEditSheet({
  userId,
  address,
  open,
  onOpenChange,
  onSuccess,
}: AddressEditSheetProps) {
  const { toast } = useToast();
  const isEditing = !!address;

  const form = useForm<AddressFormValues, unknown, AddressFormValues>({
    resolver: zodResolver(addressSchema) as any, // coerce mismatch: safe cast
    defaultValues: {
      area_id: 1,
      address_lat: "",
      address_long: "",
      detailed_address: "",
    },
  });

  useEffect(() => {
    if (!open) return;

    if (address) {
      form.reset({
        area_id: address.area_id !== undefined ? Number(address.area_id) : 1,
        address_lat: address.address_lat ? String(address.address_lat) : "",
        address_long: address.address_long ? String(address.address_long) : "",
        detailed_address: address.detailed_address
          ? String(address.detailed_address)
          : "",
      });
    } else {
      form.reset({
        area_id: 1,
        address_lat: "",
        address_long: "",
        detailed_address: "",
      });
    }
  }, [address, open, form]);

  const onSubmit = async (values: AddressFormValues) => {
    try {
      if (isEditing && address?.id) {
        await axiosInstance.post(
          `/users/${userId}/addresses/${address.id}?_method=PUT`,
          values
        );
        toast({ title: t("addressUpdated", "Address updated successfully") });
      } else {
        await axiosInstance.post(`/users/${userId}/addresses`, values);
        toast({ title: t("addressCreated", "Address created successfully") });
      }
      onSuccess();
      onOpenChange(false);
    } catch (error) {
      console.error("Submission error:", error);
      toast({
        variant: "destructive",
        title: t("saveFailed", "Failed to save address"),
      });
    }
  };

  return (
    <Sheet open={open} onOpenChange={onOpenChange}>
      <SheetContent
        side="right"
        className="w-full sm:max-w-md flex flex-col h-full"
      >
        <SheetHeader>
          <SheetTitle>
            {isEditing
              ? t("editAddress", "Edit Address")
              : t("createAddress", "Create Address")}
          </SheetTitle>
        </SheetHeader>

        <Form {...form}>
          <form
            onSubmit={form.handleSubmit(onSubmit)}
            className="space-y-4 mt-6 flex-1 overflow-y-auto pr-2"
          >
            <FormField
              control={form.control}
              name="area_id"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>{t("areaId", "Area ID")}</FormLabel>
                  <FormControl>
                    <Input type="number" {...field} placeholder="e.g. 1" />
                  </FormControl>
                  <FormMessage />
                </FormItem>
              )}
            />

            <FormField
              control={form.control}
              name="detailed_address"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>
                    {t("detailedAddress", "Detailed Address")}
                  </FormLabel>
                  <FormControl>
                    <Input
                      {...field}
                      placeholder={t(
                        "enterAddress",
                        "Street, building, floor..."
                      )}
                    />
                  </FormControl>
                  <FormMessage />
                </FormItem>
              )}
            />

            <div className="grid grid-cols-2 gap-4">
              <FormField
                control={form.control}
                name="address_lat"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel>{t("latitude", "Latitude")}</FormLabel>
                    <FormControl>
                      <Input {...field} placeholder="0.0000" />
                    </FormControl>
                    <FormMessage />
                  </FormItem>
                )}
              />
              <FormField
                control={form.control}
                name="address_long"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel>{t("longitude", "Longitude")}</FormLabel>
                    <FormControl>
                      <Input {...field} placeholder="0.0000" />
                    </FormControl>
                    <FormMessage />
                  </FormItem>
                )}
              />
            </div>

            <div className="flex gap-2 pt-6 sticky bottom-0 bg-background pb-2 mt-auto">
              <Button
                type="submit"
                disabled={form.formState.isSubmitting}
                className="flex-1"
              >
                {form.formState.isSubmitting
                  ? t("saving", "Saving...")
                  : t("save", "Save Address")}
              </Button>
              <Button
                type="button"
                variant="outline"
                className="flex-1"
                onClick={() => onOpenChange(false)}
              >
                {t("cancel", "Cancel")}
              </Button>
            </div>
          </form>
        </Form>
      </SheetContent>
    </Sheet>
  );
}