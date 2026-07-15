"use client";

import { useState, useEffect, useRef, useCallback } from "react";
import { X, Loader2, Clock, Plus, Trash2, MapPin } from "lucide-react";
import { useQuery } from "@tanstack/react-query";
import { cn } from "@/lib/utils";
import type {
  SupplierProfileUser,
  UpdateSupplierProfileData,
  WorkingHours,
} from "@/lib/supplier-api";
import { fetchBadgesByRoleId, type UserBadge } from "@/lib/users";
import LocationPickerMap from "@/components/maps/LocationPickerMap";

function normalizeEgPhone(raw: string): string {
  let p = raw.trim().replace(/[\s\-()]/g, "");
  if (!p) return p;
  if (p.startsWith("+20")) p = p.slice(3);
  else if (p.startsWith("0020")) p = p.slice(4);
  else if (p.startsWith("20")) p = p.slice(2);
  else if (p.startsWith("0")) p = p.slice(1);
  return `+20${p}`;
}

interface UpdateProfileModalProps {
  isOpen: boolean;
  onClose: () => void;
  profile: SupplierProfileUser;
  onSubmit: (data: UpdateSupplierProfileData) => void;
  isLoading: boolean;
  /** When true, renders only the form body (no overlay/header) so it can be
   *  embedded inside a tabbed container such as EditSupplierModal. */
  embedded?: boolean;
}

const DAYS_OF_WEEK = [
  "Sunday",
  "Monday",
  "Tuesday",
  "Wednesday",
  "Thursday",
  "Friday",
  "Saturday",
];

/** Small pill shown next to a label when its value differs from the original. */
function ChangedBadge() {
  return (
    <span className="ml-2 inline-flex items-center text-[10px] font-medium text-amber-700 bg-amber-50 border border-amber-200 px-1.5 py-0.5 rounded-full align-middle">
      Changed
    </span>
  );
}

export default function UpdateProfileModal({
  isOpen,
  onClose,
  profile,
  onSubmit,
  isLoading,
  embedded = false,
}: UpdateProfileModalProps) {
  const [formData, setFormData] = useState<UpdateSupplierProfileData>({});
  const initialFormDataRef = useRef<UpdateSupplierProfileData | null>(null);

  const { data: badgesData } = useQuery({
    queryKey: ["badges", "role", 6],
    queryFn: () => fetchBadgesByRoleId(6), // 6 is the Supplier role_id
  });

  useEffect(() => {
    if (profile && isOpen) {
      const address = profile.supplier?.addresses?.[0];
      const initialData: UpdateSupplierProfileData = {
        full_name: profile.full_name,
        phone: profile.phone,
        gender: profile.gender || "MALE",
        language: profile.lang || "AR",
        type_id: profile.supplier?.type_id?.toString() || "",
        badge_id: profile.badge_id?.toString() || "",
        synonyms: profile.supplier?.synonyms || "",
        tax_card: profile.supplier?.tax_card || "",
        commercial_register: profile.supplier?.commercial_register || "",
        // Stored as cents in the DB — show/edit in EGP (÷100).
        min_price_for_one_order:
          profile.supplier?.min_price_for_one_order != null
            ? profile.supplier.min_price_for_one_order / 100
            : undefined,
        max_price_for_one_order:
          profile.supplier?.max_price_for_one_order != null
            ? profile.supplier.max_price_for_one_order / 100
            : undefined,
        shopping_min_price_for_one_order:
          profile.supplier?.shopping_min_price_for_one_order != null
            ? profile.supplier.shopping_min_price_for_one_order / 100
            : undefined,
        shopping_max_price_for_one_order:
          profile.supplier?.shopping_max_price_for_one_order != null
            ? profile.supplier.shopping_max_price_for_one_order / 100
            : undefined,
        // Stored as a percentage (e.g. 5 for 5%) — use the value as-is.
        shopping_budget_fee: profile.supplier?.shopping_budget_fee ?? undefined,
        address_line_1: address?.address_line_1 || "",
        address_line_2: address?.address_line_2 || "",
        city: address?.city || "",
        state: address?.state || "",
        country: address?.country || "",
        google_map_link: address?.google_map_link || "",
        latitude: address?.latitude || "",
        longitude: address?.longitude || "",
        contact_name: address?.contact_name || "",
        contact_phone: address?.contact_phone || "",
        working_hours: address?.working_hours || {
          timezone: "Africa/Cairo",
          days: Object.fromEntries(
            DAYS_OF_WEEK.map((_, index) => [
              index,
              {
                is_closed: false,
                slots: [{ open: "09:00", close: "22:00" }],
              },
            ]),
          ),
        },
      };
      setFormData(initialData);
      initialFormDataRef.current = JSON.parse(JSON.stringify(initialData));
    }
  }, [profile, isOpen]);

  const handleChange = (
    field: keyof UpdateSupplierProfileData,
    value: string | number,
  ) => {
    setFormData((prev) => ({ ...prev, [field]: value }));
  };

  const handleNumberChange = (
    field:
      | "min_price_for_one_order"
      | "max_price_for_one_order"
      | "shopping_min_price_for_one_order"
      | "shopping_max_price_for_one_order"
      | "shopping_budget_fee",
    value: string,
  ) => {
    setFormData((prev) => ({
      ...prev,
      [field]: value === "" ? undefined : Number(value),
    }));
  };

  const handlePhoneBlur = (field: "phone" | "contact_phone") => () => {
    setFormData((prev) => ({
      ...prev,
      [field]: normalizeEgPhone((prev[field] as string) || ""),
    }));
  };

  const handleMapLocationChange = useCallback((lat: number, lng: number) => {
    const latStr = lat.toFixed(6);
    const lngStr = lng.toFixed(6);
    setFormData((prev) => ({
      ...prev,
      latitude: latStr,
      longitude: lngStr,
      google_map_link: `https://www.google.com/maps?q=${latStr},${lngStr}`,
    }));
  }, []);

  const handleWorkingHoursChange = (workingHours: WorkingHours) => {
    setFormData((prev) => ({ ...prev, working_hours: workingHours }));
  };

  // ── Change tracking ────────────────────────────────────────────────────────
  const fieldChanged = (field: keyof UpdateSupplierProfileData) => {
    const init = initialFormDataRef.current;
    if (!init) return false;
    return (
      JSON.stringify(formData[field] ?? "") !==
      JSON.stringify(init[field] ?? "")
    );
  };

  /** Input className that highlights a field amber once it differs from origin. */
  const fieldCls = (field: keyof UpdateSupplierProfileData) =>
    cn(
      "w-full px-3 py-2 border rounded-lg focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500",
      fieldChanged(field)
        ? "border-amber-400 bg-amber-50"
        : "border-gray-300",
    );

  const hasChanges = () => {
    if (!initialFormDataRef.current) return false;
    return (
      JSON.stringify(formData) !== JSON.stringify(initialFormDataRef.current)
    );
  };

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    // Prices are edited in EGP but stored as cents — convert (×100) on send.
    const payload: UpdateSupplierProfileData = { ...formData };
    if (payload.min_price_for_one_order != null) {
      payload.min_price_for_one_order = Math.round(
        payload.min_price_for_one_order * 100,
      );
    }
    if (payload.max_price_for_one_order != null) {
      payload.max_price_for_one_order = Math.round(
        payload.max_price_for_one_order * 100,
      );
    }
    if (payload.shopping_min_price_for_one_order != null) {
      payload.shopping_min_price_for_one_order = Math.round(
        payload.shopping_min_price_for_one_order * 100,
      );
    }
    if (payload.shopping_max_price_for_one_order != null) {
      payload.shopping_max_price_for_one_order = Math.round(
        payload.shopping_max_price_for_one_order * 100,
      );
    }
    // shopping_budget_fee is a percentage — sent as-is, no cents conversion.
    onSubmit(payload);
  };

  if (!isOpen) return null;

  const formBody = (
    <form onSubmit={handleSubmit} className="p-6 space-y-6">
      {/* Basic Information */}
      <div>
        <h3 className="text-sm font-medium text-gray-900 mb-3">
          Basic Information
        </h3>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">
              Full Name
              {fieldChanged("full_name") && <ChangedBadge />}
            </label>
            <input
              type="text"
              value={formData.full_name || ""}
              onChange={(e) => handleChange("full_name", e.target.value)}
              className={fieldCls("full_name")}
              disabled={isLoading}
            />
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">
              Phone
              {fieldChanged("phone") && <ChangedBadge />}
            </label>
            <input
              type="text"
              value={formData.phone || ""}
              onChange={(e) => handleChange("phone", e.target.value)}
              onBlur={handlePhoneBlur("phone")}
              placeholder="+201001001003"
              className={fieldCls("phone")}
              disabled={isLoading}
            />
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">
              Gender
              {fieldChanged("gender") && <ChangedBadge />}
            </label>
            <select
              value={formData.gender || "MALE"}
              onChange={(e) => handleChange("gender", e.target.value)}
              className={fieldCls("gender")}
              disabled={isLoading}
            >
              <option value="MALE">Male</option>
              <option value="FEMALE">Female</option>
            </select>
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">
              Language
              {fieldChanged("language") && <ChangedBadge />}
            </label>
            <select
              value={formData.language || "AR"}
              onChange={(e) => handleChange("language", e.target.value)}
              className={fieldCls("language")}
              disabled={isLoading}
            >
              <option value="AR">Arabic</option>
              <option value="EN">English</option>
            </select>
          </div>
        </div>
      </div>

      {/* Supplier Details */}
      <div>
        <h3 className="text-sm font-medium text-gray-900 mb-3">
          Supplier Details
        </h3>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">
              Badge
              {fieldChanged("badge_id") && <ChangedBadge />}
            </label>
            <select
              value={formData.badge_id?.toString() || ""}
              onChange={(e) => handleChange("badge_id", e.target.value)}
              className={fieldCls("badge_id")}
              disabled={isLoading}
            >
              <option value="">Select Badge</option>
              {badgesData?.map((badge: UserBadge) => (
                <option key={badge.id} value={badge.id}>
                  {badge.name} ({badge.name_ar})
                </option>
              ))}
            </select>
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">
              Synonyms
              {fieldChanged("synonyms") && <ChangedBadge />}
            </label>
            <input
              type="text"
              value={formData.synonyms || ""}
              onChange={(e) => handleChange("synonyms", e.target.value)}
              placeholder="e.g., Ahmed Store, Ahmed Market"
              className={fieldCls("synonyms")}
              disabled={isLoading}
            />
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">
              Tax Card
              {fieldChanged("tax_card") && <ChangedBadge />}
            </label>
            <input
              type="text"
              value={formData.tax_card || ""}
              onChange={(e) => handleChange("tax_card", e.target.value)}
              className={fieldCls("tax_card")}
              disabled={isLoading}
            />
          </div>
          <div className="md:col-span-2">
            <label className="block text-sm font-medium text-gray-700 mb-1">
              Commercial Register
              {fieldChanged("commercial_register") && <ChangedBadge />}
            </label>
            <input
              type="text"
              value={formData.commercial_register || ""}
              onChange={(e) =>
                handleChange("commercial_register", e.target.value)
              }
              className={fieldCls("commercial_register")}
              disabled={isLoading}
            />
          </div>
        </div>
      </div>

      {/* Address */}
      <div>
        <h3 className="text-sm font-medium text-gray-900 mb-3">Address</h3>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">
              Address Line 1
              {fieldChanged("address_line_1") && <ChangedBadge />}
            </label>
            <input
              type="text"
              value={formData.address_line_1 || ""}
              onChange={(e) => handleChange("address_line_1", e.target.value)}
              className={fieldCls("address_line_1")}
              disabled={isLoading}
            />
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">
              Address Line 2
              {fieldChanged("address_line_2") && <ChangedBadge />}
            </label>
            <input
              type="text"
              value={formData.address_line_2 || ""}
              onChange={(e) => handleChange("address_line_2", e.target.value)}
              className={fieldCls("address_line_2")}
              disabled={isLoading}
            />
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">
              City
              {fieldChanged("city") && <ChangedBadge />}
            </label>
            <input
              type="text"
              value={formData.city || ""}
              onChange={(e) => handleChange("city", e.target.value)}
              className={fieldCls("city")}
              disabled={isLoading}
            />
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">
              State
              {fieldChanged("state") && <ChangedBadge />}
            </label>
            <input
              type="text"
              value={formData.state || ""}
              onChange={(e) => handleChange("state", e.target.value)}
              className={fieldCls("state")}
              disabled={isLoading}
            />
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">
              Country
              {fieldChanged("country") && <ChangedBadge />}
            </label>
            <input
              type="text"
              value={formData.country || ""}
              onChange={(e) => handleChange("country", e.target.value)}
              className={fieldCls("country")}
              disabled={isLoading}
            />
          </div>
          {/* Location Picker Map — auto-fills lat, lng & google map link */}
          <div className="md:col-span-2">
            <label className="block text-sm font-medium text-gray-700 mb-2 flex items-center gap-1.5">
              <MapPin size={15} className="text-indigo-500" />
              Pick Location on Map
              {(fieldChanged("latitude") ||
                fieldChanged("longitude") ||
                fieldChanged("google_map_link")) && <ChangedBadge />}
            </label>
            <LocationPickerMap
              lat={formData.latitude ? parseFloat(formData.latitude) : null}
              long={formData.longitude ? parseFloat(formData.longitude) : null}
              onChange={handleMapLocationChange}
              heightClassName="h-64"
              disabled={isLoading}
            />
            {formData.latitude && formData.longitude && (
              <p className="mt-2 text-xs text-gray-500">
                📍 Lat: {formData.latitude}, Lng: {formData.longitude}
              </p>
            )}
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">
              Contact Name
              {fieldChanged("contact_name") && <ChangedBadge />}
            </label>
            <input
              type="text"
              value={formData.contact_name || ""}
              onChange={(e) => handleChange("contact_name", e.target.value)}
              className={fieldCls("contact_name")}
              disabled={isLoading}
            />
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">
              Contact Phone
              {fieldChanged("contact_phone") && <ChangedBadge />}
            </label>
            <input
              type="text"
              value={formData.contact_phone || ""}
              onChange={(e) => handleChange("contact_phone", e.target.value)}
              onBlur={handlePhoneBlur("contact_phone")}
              className={fieldCls("contact_phone")}
              disabled={isLoading}
            />
          </div>
        </div>
      </div>

      {/* Working Hours */}
      <div>
        <h3 className="text-sm font-medium text-gray-900 mb-3 flex items-center gap-2">
          <Clock size={16} />
          Working Hours
          {fieldChanged("working_hours") && <ChangedBadge />}
        </h3>
        <div className="space-y-3">
          {/* Timezone */}
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">
              Timezone
            </label>
            <input
              type="text"
              value={formData.working_hours?.timezone || "Africa/Cairo"}
              onChange={(e) =>
                handleWorkingHoursChange({
                  ...formData.working_hours!,
                  timezone: e.target.value,
                })
              }
              className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500"
              disabled={isLoading}
            />
          </div>

          {/* Days */}
          <div className="grid grid-cols-1 gap-3">
            {DAYS_OF_WEEK.map((dayName, dayIndex) => {
              const dayData = formData.working_hours?.days?.[dayIndex] || {
                is_closed: false,
                slots: [{ open: "09:00", close: "22:00" }],
              };
              return (
                <div
                  key={dayIndex}
                  className="flex items-start gap-3 p-3 bg-gray-50 rounded-lg"
                >
                  <div className="w-24 shrink-0">
                    <label className="flex items-center gap-2">
                      <input
                        type="checkbox"
                        checked={!dayData.is_closed}
                        onChange={(e) => {
                          const newDays = {
                            ...formData.working_hours!.days,
                            [dayIndex]: {
                              ...dayData,
                              is_closed: !e.target.checked,
                            },
                          };
                          handleWorkingHoursChange({
                            ...formData.working_hours!,
                            days: newDays,
                          });
                        }}
                        className="w-4 h-4 text-indigo-600 rounded border-gray-300"
                        disabled={isLoading}
                      />
                      <span className="text-sm font-medium text-gray-700">
                        {dayName}
                      </span>
                    </label>
                  </div>

                  {!dayData.is_closed && (
                    <div className="flex-1 space-y-2">
                      {dayData.slots.map((slot, slotIndex) => (
                        <div key={slotIndex} className="flex items-center gap-2">
                          <input
                            type="time"
                            value={slot.open}
                            onChange={(e) => {
                              const newSlots = [...dayData.slots];
                              newSlots[slotIndex] = {
                                ...slot,
                                open: e.target.value,
                              };
                              const newDays = {
                                ...formData.working_hours!.days,
                                [dayIndex]: {
                                  ...dayData,
                                  slots: newSlots,
                                },
                              };
                              handleWorkingHoursChange({
                                ...formData.working_hours!,
                                days: newDays,
                              });
                            }}
                            className="px-2 py-1 border border-gray-300 rounded text-sm"
                            disabled={isLoading}
                          />
                          <span className="text-gray-500">-</span>
                          <input
                            type="time"
                            value={slot.close}
                            onChange={(e) => {
                              const newSlots = [...dayData.slots];
                              newSlots[slotIndex] = {
                                ...slot,
                                close: e.target.value,
                              };
                              const newDays = {
                                ...formData.working_hours!.days,
                                [dayIndex]: {
                                  ...dayData,
                                  slots: newSlots,
                                },
                              };
                              handleWorkingHoursChange({
                                ...formData.working_hours!,
                                days: newDays,
                              });
                            }}
                            className="px-2 py-1 border border-gray-300 rounded text-sm"
                            disabled={isLoading}
                          />
                          {dayData.slots.length > 1 && (
                            <button
                              type="button"
                              onClick={() => {
                                const newSlots = dayData.slots.filter(
                                  (_, i) => i !== slotIndex,
                                );
                                const newDays = {
                                  ...formData.working_hours!.days,
                                  [dayIndex]: {
                                    ...dayData,
                                    slots: newSlots,
                                  },
                                };
                                handleWorkingHoursChange({
                                  ...formData.working_hours!,
                                  days: newDays,
                                });
                              }}
                              className="p-1 text-red-500 hover:bg-red-50 rounded"
                              disabled={isLoading}
                            >
                              <Trash2 size={14} />
                            </button>
                          )}
                        </div>
                      ))}
                      <button
                        type="button"
                        onClick={() => {
                          const newSlots = [
                            ...dayData.slots,
                            { open: "09:00", close: "22:00" },
                          ];
                          const newDays = {
                            ...formData.working_hours!.days,
                            [dayIndex]: {
                              ...dayData,
                              slots: newSlots,
                            },
                          };
                          handleWorkingHoursChange({
                            ...formData.working_hours!,
                            days: newDays,
                          });
                        }}
                        className="flex items-center gap-1 text-xs text-indigo-600 hover:text-indigo-700 font-medium"
                        disabled={isLoading}
                      >
                        <Plus size={12} />
                        Add Slot
                      </button>
                    </div>
                  )}

                  {dayData.is_closed && (
                    <span className="text-sm text-gray-500 italic">Closed</span>
                  )}
                </div>
              );
            })}
          </div>
        </div>
      </div>

      {/* Order Limits */}
      <div>
        <h3 className="text-sm font-medium text-gray-900 mb-3">Order Limits</h3>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">
              Min Price For One Order (EGP)
              {fieldChanged("min_price_for_one_order") && <ChangedBadge />}
            </label>
            <input
              type="number"
              step="0.01"
              min="0"
              value={formData.min_price_for_one_order ?? ""}
              onChange={(e) =>
                handleNumberChange("min_price_for_one_order", e.target.value)
              }
              placeholder="e.g., 50"
              className={fieldCls("min_price_for_one_order")}
              disabled={isLoading}
            />
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">
              Max Price For One Order (EGP)
              {fieldChanged("max_price_for_one_order") && <ChangedBadge />}
            </label>
            <input
              type="number"
              step="0.01"
              min="0"
              value={formData.max_price_for_one_order ?? ""}
              onChange={(e) =>
                handleNumberChange("max_price_for_one_order", e.target.value)
              }
              placeholder="e.g., 5000"
              className={fieldCls("max_price_for_one_order")}
              disabled={isLoading}
            />
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">
              Shopping Min Price For One Order (EGP)
              {fieldChanged("shopping_min_price_for_one_order") && (
                <ChangedBadge />
              )}
            </label>
            <input
              type="number"
              step="0.01"
              min="0"
              value={formData.shopping_min_price_for_one_order ?? ""}
              onChange={(e) =>
                handleNumberChange(
                  "shopping_min_price_for_one_order",
                  e.target.value,
                )
              }
              placeholder="e.g., 50"
              className={fieldCls("shopping_min_price_for_one_order")}
              disabled={isLoading}
            />
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">
              Shopping Max Price For One Order (EGP)
              {fieldChanged("shopping_max_price_for_one_order") && (
                <ChangedBadge />
              )}
            </label>
            <input
              type="number"
              step="0.01"
              min="0"
              value={formData.shopping_max_price_for_one_order ?? ""}
              onChange={(e) =>
                handleNumberChange(
                  "shopping_max_price_for_one_order",
                  e.target.value,
                )
              }
              placeholder="e.g., 5000"
              className={fieldCls("shopping_max_price_for_one_order")}
              disabled={isLoading}
            />
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">
              Shopping Budget Fee (%)
              {fieldChanged("shopping_budget_fee") && <ChangedBadge />}
            </label>
            <input
              type="number"
              step="0.01"
              min="0"
              value={formData.shopping_budget_fee ?? ""}
              onChange={(e) =>
                handleNumberChange("shopping_budget_fee", e.target.value)
              }
              placeholder="e.g., 5"
              className={fieldCls("shopping_budget_fee")}
              disabled={isLoading}
            />
          </div>
        </div>
      </div>

      <div className="flex justify-end gap-3 pt-4 border-t border-gray-200">
        <button
          type="button"
          onClick={onClose}
          disabled={isLoading}
          className="px-4 py-2 text-gray-700 bg-gray-100 hover:bg-gray-200 rounded-lg font-medium transition"
        >
          Cancel
        </button>
        <button
          type="submit"
          disabled={isLoading || !hasChanges()}
          className="flex items-center gap-2 px-4 py-2 bg-indigo-600 hover:bg-indigo-700 text-white rounded-lg font-medium transition disabled:opacity-50 disabled:cursor-not-allowed"
        >
          {isLoading && <Loader2 size={16} className="animate-spin" />}
          {isLoading ? "Saving..." : "Save Changes"}
        </button>
      </div>
    </form>
  );

  // Embedded mode: caller (e.g. EditSupplierModal) supplies the chrome.
  if (embedded) return formBody;

  return (
    <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
      <div className="bg-white rounded-xl w-full max-w-4xl max-h-[90vh] overflow-y-auto">
        <div className="flex items-center justify-between p-6 border-b border-gray-200">
          <h2 className="text-xl font-semibold text-gray-900">
            Update Supplier Profile
          </h2>
          <button
            onClick={onClose}
            className="p-2 hover:bg-gray-100 rounded-lg transition"
            disabled={isLoading}
          >
            <X size={20} />
          </button>
        </div>

        {formBody}
      </div>
    </div>
  );
}
