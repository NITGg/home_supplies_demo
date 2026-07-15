"use client";
import { useState, useMemo, useEffect } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { supplierApi } from "@/lib/api";
import { useRole } from "@/hooks/useRole";
import { getCurrentUserId } from "@/lib/auth";
import {
  Clock, Plus, Trash2, Save, ToggleLeft, ToggleRight, Loader2, Info
} from "lucide-react";
import toast from "react-hot-toast";

// types
interface Slot {
  open: string;
  close: string;
}

interface DayWorkingHours {
  is_closed: boolean;
  slots: Slot[];
}

interface WorkingHoursMap {
  [dayIndex: string]: DayWorkingHours;
}

interface WorkingHoursData {
  timezone: string;
  days: WorkingHoursMap;
}

interface MaxOrderSlot {
  id: number;
  store_address_id: number;
  day_of_week: number;
  time_from: string;
  time_to: string;
  max_orders: number;
}

const DAYS_ORDER = [6, 0, 1, 2, 3, 4, 5]; // Saturday to Friday
const DAY_NAMES: Record<number, string> = {
  0: "Sunday",
  1: "Monday",
  2: "Tuesday",
  3: "Wednesday",
  4: "Thursday",
  5: "Friday",
  6: "Saturday",
};

export function WorkingHoursSection() {
  const { user } = useRole();
  const userId = user?.id ?? getCurrentUserId();
  const qc = useQueryClient();

  const [editingWH, setEditingWH] = useState(false);
  const [localWH, setLocalWH] = useState<WorkingHoursData | null>(null);

  // 1. Fetch profile
  const { data: profile, isLoading: isProfileLoading } = useQuery({
    queryKey: ["supplier-profile", userId],
    queryFn: async () => {
      const res = await supplierApi.get(`/profile/get-profile/${userId}?includes=supplier.addresses`);
      return res.data?.data?.user ?? res.data?.data;
    },
    enabled: !!userId,
  });

  const address = profile?.supplier?.addresses?.[0];
  const addressId = address?.id;
  const dbWorkingHours = address?.working_hours as WorkingHoursData | undefined;

  // 2. Fetch max order slots
  const { data: maxOrderSlotsData, isLoading: isSlotsLoading } = useQuery({
    queryKey: ["supplier-max-order-slots", addressId],
    queryFn: async () => {
      const res = await supplierApi.get(`/profile/list-supplier-slot-max-order/${addressId}?limit=100&skip=0`);
      return res.data?.data?.supplierSlotMaxOrders as MaxOrderSlot[];
    },
    enabled: !!addressId,
  });

  const maxOrderSlots = maxOrderSlotsData ?? [];

  // Update local WH state when DB data changes and not currently editing
  useEffect(() => {
    if (dbWorkingHours && !editingWH) {
      setLocalWH(JSON.parse(JSON.stringify(dbWorkingHours))); // Deep copy
    } else if (!dbWorkingHours && !editingWH) {
      // default empty state
      const defaultDays: WorkingHoursMap = {};
      DAYS_ORDER.forEach(d => {
        defaultDays[d] = { is_closed: true, slots: [] };
      });
      setLocalWH({ timezone: "Africa/Cairo", days: defaultDays });
    }
  }, [dbWorkingHours, editingWH]);

  // Mutations
  const updateWHMut = useMutation({
    mutationFn: async (data: WorkingHoursData) => {
      await supplierApi.patch(`/profile/update-profile/${userId}`, { working_hours: data });
    },
    onSuccess: () => {
      toast.success("Working hours updated successfully");
      qc.invalidateQueries({ queryKey: ["supplier-profile", userId] });
      setEditingWH(false);
    },
    onError: (e: any) => toast.error(e?.response?.data?.message ?? "Update failed"),
  });

  const createMaxSlotMut = useMutation({
    mutationFn: async (data: { day_of_week: number; time_from: string; time_to: string; max_orders: number }) => {
      await supplierApi.post(`/profile/create-supplier-slot-max-order`, {
        store_address_id: addressId,
        ...data,
      });
    },
    onSuccess: () => {
      toast.success("Max order slot added");
      qc.invalidateQueries({ queryKey: ["supplier-max-order-slots", addressId] });
    },
    onError: (e: any) => toast.error(e?.response?.data?.message ?? "Failed to add slot"),
  });

  const updateMaxSlotMut = useMutation({
    mutationFn: async (data: { id: number; time_from?: string; time_to?: string; max_orders?: number }) => {
      const { id, ...rest } = data;
      await supplierApi.patch(`/profile/update-supplier-slot-max-order`, {
        supplierSlotMaxOrderId: id,
        ...rest,
      });
    },
    onSuccess: () => {
      toast.success("Max order slot updated");
      qc.invalidateQueries({ queryKey: ["supplier-max-order-slots", addressId] });
    },
    onError: (e: any) => toast.error(e?.response?.data?.message ?? "Failed to update slot"),
  });

  const deleteMaxSlotMut = useMutation({
    mutationFn: async (slotId: number) => {
      await supplierApi.delete(`/profile/delete-supplier-slot-max-order/${slotId}`);
    },
    onSuccess: () => {
      toast.success("Max order slot removed");
      qc.invalidateQueries({ queryKey: ["supplier-max-order-slots", addressId] });
    },
    onError: (e: any) => toast.error(e?.response?.data?.message ?? "Failed to delete slot"),
  });

  // State for creating new max order slot
  const [newMaxSlot, setNewMaxSlot] = useState<{ day: number; time_from: string; time_to: string; max_orders: number } | null>(null);

  if (isProfileLoading || isSlotsLoading || !localWH) {
    return (
      <div className="flex items-center justify-center min-h-[400px]">
        <Loader2 className="animate-spin text-indigo-600" size={32} />
      </div>
    );
  }

  if (!addressId) {
    return (
      <div className="p-6">
        <div className="bg-amber-50 text-amber-700 p-4 rounded-xl border border-amber-200 flex items-center gap-3">
          <Info size={20} />
          <p>Please complete your store address profile first before setting working hours.</p>
        </div>
      </div>
    );
  }

  const handleToggleDay = (day: number) => {
    setLocalWH((prev) => {
      if (!prev) return prev;
      const days = { ...prev.days };
      const current = days[day];
      days[day] = {
        ...current,
        is_closed: !current.is_closed,
        slots: !current.is_closed ? [] : [{ open: "08:00", close: "22:00" }], // Auto add slot if opening
      };
      return { ...prev, days };
    });
    if (!editingWH) setEditingWH(true);
  };

  const handleAddWHSlot = (day: number) => {
    setLocalWH((prev) => {
      if (!prev) return prev;
      const days = { ...prev.days };
      days[day] = {
        ...days[day],
        slots: [...days[day].slots, { open: "08:00", close: "22:00" }]
      };
      return { ...prev, days };
    });
    if (!editingWH) setEditingWH(true);
  };

  const handleRemoveWHSlot = (day: number, slotIndex: number) => {
    setLocalWH((prev) => {
      if (!prev) return prev;
      const days = { ...prev.days };
      days[day] = {
        ...days[day],
        slots: days[day].slots.filter((_, i) => i !== slotIndex)
      };
      return { ...prev, days };
    });
    if (!editingWH) setEditingWH(true);
  };

  const handleUpdateWHSlot = (day: number, slotIndex: number, field: "open" | "close", value: string) => {
    setLocalWH((prev) => {
      if (!prev) return prev;
      const days = { ...prev.days };
      days[day] = {
        ...days[day],
        slots: days[day].slots.map((slot, i) =>
          i === slotIndex ? { ...slot, [field]: value } : slot
        )
      };
      return { ...prev, days };
    });
    if (!editingWH) setEditingWH(true);
  };

  const saveWorkingHours = () => {
    if (!localWH) return;
    updateWHMut.mutate(localWH);
  };

  const cancelEditing = () => {
    setEditingWH(false);
    if (dbWorkingHours) {
      setLocalWH(JSON.parse(JSON.stringify(dbWorkingHours)));
    }
  };

  return (
    <div className="bg-white rounded-xl border border-gray-200 p-5 space-y-4">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-base font-semibold text-gray-900 flex items-center gap-2">
            <Clock size={16} className="text-indigo-500" />
            Working Hours
          </h2>
          <p className="text-xs text-gray-400 mt-1">Manage your store's weekly schedule and maximum order capacity per time slot.</p>
        </div>
        {editingWH && (
          <div className="flex items-center gap-2">
            <button
              onClick={cancelEditing}
              className="px-4 py-2 border border-gray-200 rounded-xl text-sm text-gray-600 hover:bg-gray-50 transition"
            >
              Cancel
            </button>
            <button
              onClick={saveWorkingHours}
              disabled={updateWHMut.isPending}
              className="flex items-center gap-2 px-4 py-2 bg-indigo-600 text-white rounded-xl text-sm font-medium hover:bg-indigo-700 disabled:opacity-60 transition"
            >
              {updateWHMut.isPending ? <Loader2 size={14} className="animate-spin" /> : <Save size={14} />}
              Save Changes
            </button>
          </div>
        )}
      </div>

      <div className="space-y-4">
        {DAYS_ORDER.map((dayNum) => {
          const dayData = localWH.days[dayNum] || { is_closed: true, slots: [] };
          const dayMaxSlots = maxOrderSlots.filter(s => s.day_of_week === dayNum);

          return (
            <div key={dayNum} className="bg-white rounded-xl border border-gray-200 p-5 shadow-sm">
              <div className="flex items-center justify-between mb-4">
                <h3 className="text-lg font-semibold text-gray-900 w-32">{DAY_NAMES[dayNum]}</h3>
                <button
                  onClick={() => handleToggleDay(dayNum)}
                  className="flex items-center gap-2 text-sm font-medium transition"
                >
                  {dayData.is_closed ? (
                    <span className="text-gray-400">Closed</span>
                  ) : (
                    <span className="text-indigo-600">Open</span>
                  )}
                  {dayData.is_closed ? (
                    <ToggleLeft size={28} className="text-gray-300" />
                  ) : (
                    <ToggleRight size={28} className="text-indigo-600" />
                  )}
                </button>
              </div>

              {!dayData.is_closed && (
                <div className="space-y-4 pl-4 border-l-2 border-gray-100">
                  {dayData.slots.map((slot, sIdx) => {
                    // Find max order slots that fall within this WH slot (visually group them, backend handles logic independently)
                    const slotMaxOrders = dayMaxSlots.filter(ms => {
                      return ms.time_from >= slot.open && ms.time_from < slot.close;
                    });

                    return (
                      <div key={sIdx} className="bg-gray-50 rounded-xl p-4 border border-gray-200">
                        <div className="flex flex-wrap items-end gap-4 mb-3">
                          <div>
                            <label className="text-[11px] uppercase font-bold text-gray-500 mb-1.5 block">From</label>
                            <input
                              type="time"
                              value={slot.open}
                              onChange={(e) => handleUpdateWHSlot(dayNum, sIdx, "open", e.target.value)}
                              className="px-3 py-2 border border-gray-200 rounded-lg text-sm bg-white outline-none focus:border-indigo-500 shadow-sm"
                            />
                          </div>
                          <div>
                            <label className="text-[11px] uppercase font-bold text-gray-500 mb-1.5 block">To</label>
                            <input
                              type="time"
                              value={slot.close}
                              onChange={(e) => handleUpdateWHSlot(dayNum, sIdx, "close", e.target.value)}
                              className="px-3 py-2 border border-gray-200 rounded-lg text-sm bg-white outline-none focus:border-indigo-500 shadow-sm"
                            />
                          </div>
                          <button
                            onClick={() => handleRemoveWHSlot(dayNum, sIdx)}
                            className="p-2 mb-0.5 text-gray-400 hover:text-red-500 hover:bg-red-50 rounded-lg transition"
                            title="Remove time slot"
                          >
                            <Trash2 size={18} />
                          </button>
                        </div>

                        {/* Max Order Slots Section within this WH slot */}
                        <div className="mt-4 pl-3 border-l-2 border-indigo-200 space-y-2">
                          <p className="text-xs font-semibold text-gray-700">Max Capacity Slots (Optional)</p>
                          
                          {slotMaxOrders.length > 0 && (
                            <div className="space-y-2 mt-2">
                              {slotMaxOrders.map(ms => (
                                <div key={ms.id} className="flex items-center gap-3 bg-white p-2.5 rounded-lg border border-gray-200 text-sm shadow-sm transition hover:border-indigo-200">
                                  <input 
                                    type="time" 
                                    defaultValue={ms.time_from}
                                    onBlur={(e) => {
                                      if(e.target.value !== ms.time_from) updateMaxSlotMut.mutate({ id: ms.id, time_from: e.target.value });
                                    }}
                                    className="px-2 py-1.5 bg-gray-50 rounded-md border border-gray-100 outline-none focus:border-indigo-500" 
                                  />
                                  <span className="text-gray-400">-</span>
                                  <input 
                                    type="time" 
                                    defaultValue={ms.time_to}
                                    onBlur={(e) => {
                                      if(e.target.value !== ms.time_to) updateMaxSlotMut.mutate({ id: ms.id, time_to: e.target.value });
                                    }}
                                    className="px-2 py-1.5 bg-gray-50 rounded-md border border-gray-100 outline-none focus:border-indigo-500" 
                                  />
                                  <span className="text-gray-500 text-xs ml-2 font-medium uppercase">Max orders:</span>
                                  <input 
                                    type="number" 
                                    min="0"
                                    defaultValue={ms.max_orders}
                                    onBlur={(e) => {
                                      if(parseInt(e.target.value) !== ms.max_orders) updateMaxSlotMut.mutate({ id: ms.id, max_orders: parseInt(e.target.value) });
                                    }}
                                    className="w-16 px-2 py-1.5 bg-gray-50 rounded-md border border-gray-100 text-center outline-none focus:border-indigo-500 font-bold text-gray-700" 
                                  />
                                  <button 
                                    onClick={() => deleteMaxSlotMut.mutate(ms.id)}
                                    disabled={deleteMaxSlotMut.isPending}
                                    className="p-1.5 ml-auto text-gray-400 hover:text-red-500 hover:bg-red-50 rounded-md transition"
                                  >
                                    <Trash2 size={16} />
                                  </button>
                                </div>
                              ))}
                            </div>
                          )}

                          {newMaxSlot?.day === dayNum && newMaxSlot?.time_from >= slot.open && newMaxSlot?.time_from < slot.close ? (
                            <div className="flex items-center gap-3 bg-indigo-50 p-2.5 rounded-lg border border-indigo-200 text-sm mt-2 shadow-sm animate-in fade-in slide-in-from-top-1">
                              <input 
                                type="time" 
                                value={newMaxSlot.time_from}
                                onChange={(e) => setNewMaxSlot({...newMaxSlot, time_from: e.target.value})}
                                className="px-2 py-1.5 bg-white rounded-md border border-gray-200 outline-none focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500" 
                              />
                              <span className="text-gray-400">-</span>
                              <input 
                                type="time" 
                                value={newMaxSlot.time_to}
                                onChange={(e) => setNewMaxSlot({...newMaxSlot, time_to: e.target.value})}
                                className="px-2 py-1.5 bg-white rounded-md border border-gray-200 outline-none focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500" 
                              />
                              <span className="text-indigo-700 text-xs ml-2 font-bold uppercase tracking-wide">Max orders:</span>
                              <input 
                                type="number" 
                                min="0"
                                value={newMaxSlot.max_orders}
                                onChange={(e) => setNewMaxSlot({...newMaxSlot, max_orders: parseInt(e.target.value) || 0})}
                                className="w-16 px-2 py-1.5 bg-white rounded-md border border-gray-200 outline-none focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500 text-center font-bold text-gray-900" 
                              />
                              <div className="flex gap-1.5 ml-auto">
                                <button 
                                  onClick={() => setNewMaxSlot(null)}
                                  className="px-3 py-1.5 text-xs text-gray-600 hover:bg-gray-200 rounded-md transition font-medium"
                                >
                                  Cancel
                                </button>
                                <button 
                                  onClick={() => {
                                    createMaxSlotMut.mutate({
                                      day_of_week: dayNum,
                                      time_from: newMaxSlot.time_from,
                                      time_to: newMaxSlot.time_to,
                                      max_orders: newMaxSlot.max_orders
                                    });
                                    setNewMaxSlot(null);
                                  }}
                                  disabled={createMaxSlotMut.isPending}
                                  className="px-3 py-1.5 text-xs bg-indigo-600 text-white hover:bg-indigo-700 rounded-md transition font-medium shadow-sm"
                                >
                                  Save
                                </button>
                              </div>
                            </div>
                          ) : (
                            <button
                              onClick={() => setNewMaxSlot({ day: dayNum, time_from: slot.open, time_to: slot.close, max_orders: 5 })}
                              className="text-[13px] text-indigo-600 font-medium flex items-center gap-1 hover:text-indigo-800 transition mt-2"
                            >
                              <Plus size={14} /> Add max order capacity to this slot
                            </button>
                          )}
                        </div>
                      </div>
                    );
                  })}
                  
                  <button
                    onClick={() => handleAddWHSlot(dayNum)}
                    className="text-sm text-indigo-600 font-bold flex items-center gap-1.5 hover:text-indigo-800 transition pt-2"
                  >
                    <Plus size={16} /> Add Working Hour
                  </button>
                </div>
              )}
            </div>
          );
        })}
      </div>
    </div>
  );
}
