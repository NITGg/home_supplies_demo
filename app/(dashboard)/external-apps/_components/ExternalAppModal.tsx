import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogFooter,
  DialogDescription,
} from "@/components/ui/dialog";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { Switch } from "@/components/ui/switch";
import { ScrollArea } from "@/components/ui/scroll-area";
import { useMutation, useQuery } from "@tanstack/react-query";
import { fetchVehicles } from "@/lib/vehicles";
import { fetchBadges } from "@/lib/badges";
import {
  createExternalApp,
  updateExternalApp,
  type CreateExternalAppInput,
  type UpdateExternalAppInput,
} from "@/lib/external-apps";
import { useState, useEffect } from "react";
import { Truck, Percent, Info, RefreshCw } from "lucide-react";
import toast from "react-hot-toast";
import type { ExternalApp } from "@/types/external-apps";

type Badge = { id: number; name: string };

type FormState = {
  name: string;
  environment: "SANDBOX" | "PRODUCTION";
  is_active: boolean;
  webhook_url: string;
  contract: {
    start_date: string;
    end_date: string;
    can_receive_courier_offers: boolean;
    vehicles: {
      vehicle_id: number;
      min_fee: number;
      m_min: number;
      m_max: number;
      fee_per_m: number;
      extra_m_price: number;
      splits: {
        badge_id: number;
        app_ratio: number;
        courier_ratio: number;
        partner_ratio: number;
      }[];
    }[];
  };
};

const defaultForm = (): FormState => ({
  name: "",
  environment: "SANDBOX",
  is_active: true,
  webhook_url: "",
  contract: {
    start_date: new Date().toISOString().split("T")[0],
    end_date: new Date(Date.now() + 31536000000).toISOString().split("T")[0],
    can_receive_courier_offers: true,
    vehicles: [],
  },
});

type Props = {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  app: ExternalApp | null;
  onSaved: () => void;
};

export function ExternalAppModal({
  open,
  onOpenChange,
  app,
  onSaved,
}: Readonly<Props>) {
  const [activeTab, setActiveTab] = useState("general");
  const [form, setForm] = useState<FormState>(defaultForm());

  const { data: vehiclesData } = useQuery({
    queryKey: ["vehicles-list"],
    queryFn: () => fetchVehicles({ limit: 100 }),
  });

  const { data: badgesData } = useQuery({
    queryKey: ["badges-role-2"],
    queryFn: () => fetchBadges({ role_id: 2 }),
  });

  const vehicles = vehiclesData?.vehicles ?? [];
  const badges: Badge[] = badgesData?.badges ?? [];

  useEffect(() => {
    if (app) {
      const contract = app.contracts?.[0];
      setForm({
        name: app.name,
        environment: app.environment,
        is_active: app.is_active,
        webhook_url: app.webhook_url ?? "",
        contract: {
          start_date: contract?.start_date
            ? new Date(contract.start_date).toISOString().split("T")[0]
            : defaultForm().contract.start_date,
          end_date: contract?.end_date
            ? new Date(contract.end_date).toISOString().split("T")[0]
            : defaultForm().contract.end_date,
          can_receive_courier_offers:
            contract?.can_receive_courier_offers ?? true,
          vehicles:
            contract?.vehicle_configs?.map((vc) => ({
              vehicle_id: vc.vehicle_id,
              min_fee: Number(vc.min_fee),
              m_min: vc.m_min,
              m_max: vc.m_max,
              fee_per_m: Number(vc.fee_per_m),
              extra_m_price: Number(vc.extra_m_price),
              splits: vc.splits.map((s) => ({
                badge_id: s.badge_id,
                app_ratio: s.app_ratio,
                courier_ratio: s.courier_ratio,
                partner_ratio: s.partner_ratio,
              })),
            })) ?? [],
        },
      });
    } else {
      setForm(defaultForm());
    }
  }, [app]);
  console.log(app);

  type SaveResult =
    | { client_secret_raw: string; newSecretRaw?: never }
    | { newSecretRaw?: string; client_secret_raw?: never };

  const saveMut = useMutation<
    SaveResult,
    Error,
    CreateExternalAppInput | UpdateExternalAppInput
  >({
    mutationFn: (data) =>
      app
        ? updateExternalApp(app.id, data as UpdateExternalAppInput)
        : createExternalApp(data as CreateExternalAppInput),
    onSuccess: (res) => {
      const secret = res.client_secret_raw ?? res.newSecretRaw;
      if (secret) {
        alert(
          `IMPORTANT: Copy this secret now, it won't be shown again:\n${secret}`,
        );
      }
      toast.success("Saved successfully");
      onSaved();
      onOpenChange(false);
    },
  });
  const regenerateMut = useMutation({
    mutationFn: (data: UpdateExternalAppInput) =>
      updateExternalApp(app!.id, data),

    onSuccess: (res) => {
      const secret = res.newSecretRaw;

      if (secret) {
        alert(
          `IMPORTANT: Copy this secret now, it won't be shown again:\n${secret}`,
        );
      }

      toast.success("Credential regenerated");
      onSaved();
    },
  });

  const updateVehicleField = (idx: number, field: string, value: number) => {
    const newVehicles = form.contract.vehicles.map((v, i) =>
      i === idx ? { ...v, [field]: value } : v,
    );
    setForm({ ...form, contract: { ...form.contract, vehicles: newVehicles } });
  };

  const toggleVehicle = (vId: number) => {
    const exists = form.contract.vehicles.find((v) => v.vehicle_id === vId);
    if (exists) {
      setForm({
        ...form,
        contract: {
          ...form.contract,
          vehicles: form.contract.vehicles.filter((v) => v.vehicle_id !== vId),
        },
      });
    } else {
      const newVehicle = {
        vehicle_id: vId,
        min_fee: 10,
        m_min: 0,
        m_max: 5000,
        fee_per_m: 0.01,
        extra_m_price: 0.02,
        splits: badges.map((b) => ({
          badge_id: b.id,
          app_ratio: 0.2,
          courier_ratio: 0.7,
          partner_ratio: 0.1,
        })),
      };
      setForm({
        ...form,
        contract: {
          ...form.contract,
          vehicles: [...form.contract.vehicles, newVehicle],
        },
      });
    }
  };

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-w-4xl h-[95svh] flex flex-col p-0 bg-white">
        <DialogHeader className="p-6 pb-0">
          <DialogTitle className="text-xl font-bold flex items-center gap-2">
            {app ? "Update External App" : "Register New External App"}
          </DialogTitle>
          <DialogDescription></DialogDescription>
        </DialogHeader>

        <Tabs
          value={activeTab}
          onValueChange={setActiveTab}
          className="flex flex-col flex-1 overflow-hidden min-h-0"
        >
          <div className="px-6 border-b">
            <TabsList className="bg-transparent gap-6 h-12">
              <TabsTrigger
                value="general"
                className="data-[state=active]:border-b-2 data-[state=active]:border-b-indigo-600 rounded-none px-0"
              >
                Settings
              </TabsTrigger>
              <TabsTrigger
                value="contract"
                className="data-[state=active]:border-b-2 data-[state=active]:border-b-indigo-600 rounded-none px-0"
              >
                Contract & Pricing
              </TabsTrigger>
              <TabsTrigger
                value="webhooks"
                className="data-[state=active]:border-b-2 data-[state=active]:border-b-indigo-600 rounded-none px-0"
              >
                Webhooks
              </TabsTrigger>
            </TabsList>
          </div>
          <ScrollArea className="flex-1 p-6 min-h-0">
            <TabsContent value="general" className="mt-0 space-y-4">
              <div className="grid grid-cols-2 gap-4">
                <div className="space-y-2">
                  <label htmlFor="app-name" className="text-sm font-medium">
                    App Name
                  </label>
                  <input
                    id="app-name"
                    className="input w-full"
                    value={form.name}
                    onChange={(e) => setForm({ ...form, name: e.target.value })}
                  />
                </div>
                <div className="space-y-2">
                  <label htmlFor="app-env" className="text-sm font-medium">
                    Environment
                  </label>
                  <select
                    id="app-env"
                    className="input w-full"
                    value={form.environment}
                    onChange={(e) =>
                      setForm({
                        ...form,
                        environment: e.target.value as FormState["environment"],
                      })
                    }
                  >
                    <option value="SANDBOX">Sandbox (Testing)</option>
                    <option value="PRODUCTION">Production (Live)</option>
                  </select>
                </div>
              </div>
              <div className="flex items-center justify-between p-4 bg-gray-50 rounded-xl">
                <div>
                  <p className="font-medium">Active Status</p>
                  <p className="text-xs text-gray-500">
                    Allow this app to authenticate and place orders
                  </p>
                </div>
                <Switch
                  checked={form.is_active}
                  onCheckedChange={(v) => setForm({ ...form, is_active: v })}
                />
              </div>
              {app && (
                <div className="border rounded-xl p-4 space-y-4">
                  <div>
                    <h3 className="font-semibold">Credentials</h3>
                    <p className="text-xs text-muted-foreground">
                      Regenerate application credentials and webhook secrets.
                    </p>
                  </div>

                  <div className="flex flex-wrap gap-2">
                    <button
                      type="button"
                      onClick={() =>
                        regenerateMut.mutate({
                          regenerate_client_id: true,
                        })
                      }
                      disabled={regenerateMut.isPending}
                      className="inline-flex items-center gap-2 rounded-md border px-3 py-2 text-sm"
                    >
                      <RefreshCw className="h-4 w-4" />
                      Regenerate Client ID
                    </button>

                    <button
                      type="button"
                      onClick={() => {
                        if (
                          confirm(
                            "Are you sure? Existing integrations using the current secret will stop working.",
                          )
                        ) {
                          regenerateMut.mutate({
                            regenerate_client_secret: true,
                          });
                        }
                      }}
                      disabled={regenerateMut.isPending}
                      className="inline-flex items-center gap-2 rounded-md border px-3 py-2 text-sm"
                    >
                      <RefreshCw className="h-4 w-4" />
                      Regenerate Client Secret
                    </button>

                    <button
                      type="button"
                      onClick={() =>
                        regenerateMut.mutate({
                          regenerate_webhook_secret: true,
                        })
                      }
                      disabled={regenerateMut.isPending}
                      className="inline-flex items-center gap-2 rounded-md border px-3 py-2 text-sm"
                    >
                      <RefreshCw className="h-4 w-4" />
                      Regenerate Webhook Secret
                    </button>
                  </div>
                </div>
              )}
            </TabsContent>

            <TabsContent value="contract" className="mt-0 space-y-6">
              <div className="grid grid-cols-2 gap-4">
                <div className="space-y-2">
                  <label
                    htmlFor="contract-start"
                    className="text-sm font-medium"
                  >
                    Start Date
                  </label>
                  <input
                    id="contract-start"
                    type="date"
                    className="input w-full"
                    value={form.contract.start_date}
                    onChange={(e) =>
                      setForm({
                        ...form,
                        contract: {
                          ...form.contract,
                          start_date: e.target.value,
                        },
                      })
                    }
                  />
                </div>
                <div className="space-y-2">
                  <label htmlFor="contract-end" className="text-sm font-medium">
                    End Date
                  </label>
                  <input
                    id="contract-end"
                    type="date"
                    className="input w-full"
                    value={form.contract.end_date}
                    onChange={(e) =>
                      setForm({
                        ...form,
                        contract: {
                          ...form.contract,
                          end_date: e.target.value,
                        },
                      })
                    }
                  />
                </div>
              </div>

              <div className="space-y-4 border-t pt-4">
                <h4 className="font-bold text-sm flex items-center gap-2">
                  <Truck size={16} /> Vehicle Configurations
                </h4>
                <div className="grid grid-cols-4 gap-2">
                  {vehicles.map((v) => (
                    <button
                      key={v.id}
                      type="button"
                      onClick={() => toggleVehicle(v.id)}
                      className={`p-3 rounded-xl border-2 text-sm text-left transition ${
                        form.contract.vehicles.some(
                          (cv) => cv.vehicle_id === v.id,
                        )
                          ? "border-indigo-600 bg-indigo-50"
                          : "border-gray-100 bg-white"
                      }`}
                    >
                      <p className="font-bold">{v.name}</p>
                      <p className="text-[10px] text-gray-400">ID: {v.id}</p>
                    </button>
                  ))}
                </div>
              </div>

              {form.contract.vehicles.map((cv, idx) => (
                <div
                  key={cv.vehicle_id}
                  className="p-4 border rounded-xl space-y-4 bg-white shadow-sm"
                >
                  <div className="flex justify-between items-center">
                    <span className="font-bold text-indigo-700">
                      Config:{" "}
                      {vehicles.find((v) => v.id === cv.vehicle_id)?.name}
                    </span>
                  </div>
                  <div className="grid grid-cols-3 gap-3">
                    <div>
                      <label
                        htmlFor={`min-fee-${idx}`}
                        className="text-[10px] uppercase font-bold text-gray-400"
                      >
                        Min Fee
                      </label>
                      <input
                        id={`min-fee-${idx}`}
                        type="number"
                        className="input-sm w-full"
                        value={cv.min_fee}
                        onChange={(e) =>
                          updateVehicleField(
                            idx,
                            "min_fee",
                            Number(e.target.value),
                          )
                        }
                      />
                    </div>
                    <div>
                      <label
                        htmlFor={`fee-per-m-${idx}`}
                        className="text-[10px] uppercase font-bold text-gray-400"
                      >
                        Fee per Meter
                      </label>
                      <input
                        id={`fee-per-m-${idx}`}
                        type="number"
                        step="0.0001"
                        className="input-sm w-full"
                        value={cv.fee_per_m}
                        onChange={(e) =>
                          updateVehicleField(
                            idx,
                            "fee_per_m",
                            Number(e.target.value),
                          )
                        }
                      />
                    </div>
                    <div>
                      <label
                        htmlFor={`m-max-${idx}`}
                        className="text-[10px] uppercase font-bold text-gray-400"
                      >
                        Max Meter
                      </label>
                      <input
                        id={`m-max-${idx}`}
                        type="number"
                        className="input-sm w-full"
                        value={cv.m_max}
                        onChange={(e) =>
                          updateVehicleField(
                            idx,
                            "m_max",
                            Number(e.target.value),
                          )
                        }
                      />
                    </div>
                  </div>

                  <div className="bg-gray-50 p-3 rounded-lg space-y-2">
                    <p className="text-[11px] font-bold text-gray-500 uppercase flex items-center gap-1">
                      <Percent size={12} /> Courier Badge Split Ratios (Role ID
                      2)
                    </p>
                    {cv.splits.map((split, sIdx) => {
                      const badgeName = badges.find(
                        (b) => b.id === split.badge_id,
                      )?.name;
                      return (
                        <div
                          key={split.badge_id}
                          className="grid grid-cols-4 gap-2 items-center text-xs"
                        >
                          <span className="font-medium truncate">
                            {badgeName}
                          </span>
                          <input
                            type="number"
                            placeholder="App"
                            className="input-xs"
                            value={split.app_ratio}
                            onChange={(e) => {
                              const newVehicles = form.contract.vehicles.map(
                                (v, i) => {
                                  if (i !== idx) return v;
                                  const newSplits = v.splits.map((s, si) =>
                                    si === sIdx
                                      ? {
                                          ...s,
                                          app_ratio: Number(e.target.value),
                                        }
                                      : s,
                                  );
                                  return { ...v, splits: newSplits };
                                },
                              );
                              setForm({
                                ...form,
                                contract: {
                                  ...form.contract,
                                  vehicles: newVehicles,
                                },
                              });
                            }}
                          />
                          <input
                            type="number"
                            placeholder="Courier"
                            className="input-xs"
                            value={split.courier_ratio}
                            onChange={(e) => {
                              const newVehicles = form.contract.vehicles.map(
                                (v, i) => {
                                  if (i !== idx) return v;
                                  const newSplits = v.splits.map((s, si) =>
                                    si === sIdx
                                      ? {
                                          ...s,
                                          courier_ratio: Number(e.target.value),
                                        }
                                      : s,
                                  );
                                  return { ...v, splits: newSplits };
                                },
                              );
                              setForm({
                                ...form,
                                contract: {
                                  ...form.contract,
                                  vehicles: newVehicles,
                                },
                              });
                            }}
                          />
                          <input
                            type="number"
                            placeholder="Partner"
                            className="input-xs"
                            value={split.partner_ratio}
                            onChange={(e) => {
                              const newVehicles = form.contract.vehicles.map(
                                (v, i) => {
                                  if (i !== idx) return v;
                                  const newSplits = v.splits.map((s, si) =>
                                    si === sIdx
                                      ? {
                                          ...s,
                                          partner_ratio: Number(e.target.value),
                                        }
                                      : s,
                                  );
                                  return { ...v, splits: newSplits };
                                },
                              );
                              setForm({
                                ...form,
                                contract: {
                                  ...form.contract,
                                  vehicles: newVehicles,
                                },
                              });
                            }}
                          />
                        </div>
                      );
                    })}
                  </div>
                </div>
              ))}
            </TabsContent>

            <TabsContent value="webhooks" className="mt-0 space-y-4">
              <div className="space-y-2">
                <label htmlFor="webhook-url" className="text-sm font-medium">
                  Webhook Endpoint URL
                </label>
                <input
                  id="webhook-url"
                  className="input w-full"
                  placeholder="https://api.yourdomain.com/webhooks"
                  value={form.webhook_url}
                  onChange={(e) =>
                    setForm({ ...form, webhook_url: e.target.value })
                  }
                />
                <p className="text-[11px] text-gray-400 flex items-center gap-1">
                  <Info size={12} /> Orders and status changes will be sent
                  here.
                </p>
              </div>
            </TabsContent>
          </ScrollArea>

          <DialogFooter className="p-6 border-t bg-gray-50 shrink-0">
            <button
              onClick={() => onOpenChange(false)}
              className="px-4 py-2 text-sm text-gray-600"
            >
              Cancel
            </button>
            <button
              onClick={() => saveMut.mutate(form)}
              className="bg-indigo-600 text-white px-6 py-2 rounded-xl text-sm font-bold hover:bg-indigo-700"
            >
              {saveMut.isPending
                ? "Saving..."
                : app
                  ? "Update App"
                  : "Create App"}
            </button>
          </DialogFooter>
        </Tabs>
      </DialogContent>
    </Dialog>
  );
}
