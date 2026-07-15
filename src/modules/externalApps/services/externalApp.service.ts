import { prisma } from "@/config/prisma";
import { HttpError } from "@/lib/httpError";
import type FeatureApi from "@/lib/featureApi";
import type { Prisma } from "@prisma/client";
import crypto from "node:crypto";
import bcrypt from "bcrypt";
import type {
  CreateExternalAppInput,
  UpdateExternalAppInput,
} from "../schemas/externalApp.schema";
import { Tx } from "@/types/prisma.types";

// ─── Types ────────────────────────────────────────────────────────────────────

type ContractInput = NonNullable<CreateExternalAppInput["contract"]>;
type VehicleInput = NonNullable<ContractInput["vehicles"]>[number];
type SplitInput = VehicleInput["splits"][number];

// ─── Helpers ──────────────────────────────────────────────────────────────────

const generateClientId = (env: string) =>
  `ca_${env.toLowerCase()}_${crypto.randomBytes(12).toString("hex")}`;

const generateSecret = () => crypto.randomBytes(32).toString("hex");

const generateWebhookSecret = () =>
  `whsec_${crypto.randomBytes(24).toString("hex")}`;
// ─── Contract helpers (used inside $transaction) ──────────────────────────────

async function upsertSplits(
  tx: Tx,
  vehicleConfigId: number,
  splits: SplitInput[],
): Promise<void> {
  const existing = await tx.partnerFeeSplit.findMany({
    where: { contract_vehicle_id: vehicleConfigId },
    select: { id: true, badge_id: true },
  });
  const splitMap = new Map(existing.map((s) => [s.badge_id, s.id]));
  const incomingBadgeIds = new Set(splits.map((s) => s.badge_id));

  for (const s of splits) {
    const existingId = splitMap.get(s.badge_id);
    const data = {
      app_ratio: s.app_ratio,
      courier_ratio: s.courier_ratio,
      partner_ratio: s.partner_ratio,
    };

    if (existingId) {
      await tx.partnerFeeSplit.update({ where: { id: existingId }, data });
    } else {
      await tx.partnerFeeSplit.create({
        data: {
          contract_vehicle_id: vehicleConfigId,
          badge_id: s.badge_id,
          ...data,
        },
      });
    }
  }

  // Remove splits for badges no longer present in the contract update
  const staleSplitIds = existing
    .filter((s) => !incomingBadgeIds.has(s.badge_id))
    .map((s) => s.id);

  if (staleSplitIds.length > 0) {
    await tx.partnerFeeSplit.deleteMany({
      where: { id: { in: staleSplitIds } },
    });
  }
}

async function upsertVehicles(
  tx: Tx,
  contractId: number,
  vehicles: VehicleInput[],
): Promise<void> {
  const existing = await tx.partnerContractVehicle.findMany({
    where: { contract_id: contractId },
    select: {
      id: true,
      vehicle_id: true,
      _count: { select: { orders: true } },
    },
  });
  const vehicleMap = new Map(existing.map((v) => [v.vehicle_id, v.id]));
  const incomingVehicleIds = new Set(vehicles.map((v) => v.vehicle_id));

  for (const v of vehicles) {
    const pricingData = {
      min_fee: v.min_fee,
      m_min: v.m_min,
      m_max: v.m_max,
      extra_m_price: v.extra_m_price,
      fee_per_m: v.fee_per_m,
    };

    const existingId = vehicleMap.get(v.vehicle_id);
    let vehicleConfigId: number;

    if (existingId) {
      const updated = await tx.partnerContractVehicle.update({
        where: { id: existingId },
        data: pricingData,
        select: { id: true },
      });
      vehicleConfigId = updated.id;
    } else {
      const created = await tx.partnerContractVehicle.create({
        data: {
          contract_id: contractId,
          vehicle_id: v.vehicle_id,
          ...pricingData,
        },
        select: { id: true },
      });
      vehicleConfigId = created.id;
    }

    await upsertSplits(tx, vehicleConfigId, v.splits);
  }

  // Remove vehicle configs no longer present in the contract update
  const staleVehicles = existing.filter(
    (v) => !incomingVehicleIds.has(v.vehicle_id),
  );

  for (const stale of staleVehicles) {
    await tx.partnerFeeSplit.deleteMany({
      where: { contract_vehicle_id: stale.id },
    });

    // Keep configs that are still referenced by historical orders
    if (stale._count.orders === 0) {
      await tx.partnerContractVehicle.delete({ where: { id: stale.id } });
    }
  }
}

async function upsertContract(
  tx: Tx,
  appId: number,
  contract: ContractInput,
): Promise<void> {
  const contractData = {
    start_date: contract.start_date,
    end_date: contract.end_date,
    can_receive_courier_offers: contract.can_receive_courier_offers,
  };

  const partnerContract = await tx.partnerContract.upsert({
    where: { external_app_id: appId },
    update: contractData,
    create: { external_app_id: appId, ...contractData },
    select: { id: true },
  });

  if (contract.vehicles) {
    await upsertVehicles(tx, partnerContract.id, contract.vehicles);
  }
}

// ─── Services ─────────────────────────────────────────────────────────────────

export async function listExternalAppsService(data: FeatureApi["data"]) {
  const take = Number(data.take) || 10;
  const [totalCount, apps] = await prisma.$transaction([
    prisma.externalApp.count({ where: data.where }),
    prisma.externalApp.findMany(data as Prisma.ExternalAppFindManyArgs),
  ]);

  return { totalCount, totalPages: Math.ceil(totalCount / take), apps };
}

export async function getExternalAppByIdService(
  data: Pick<FeatureApi["data"], "where" | "select" | "include">,
) {
  const app = await prisma.externalApp.findUnique(data as any);
  if (!app) throw new HttpError(404, "external_apps:errors.not_found");
  return app;
}

export async function createExternalAppService(
  input: CreateExternalAppInput,
  queryOptions?: Pick<FeatureApi["data"], "select" | "include">,
) {
  const { contract, ...baseData } = input;

  const rawSecret = generateSecret();
  const webhookSecret = generateWebhookSecret();
  const clientId = generateClientId(baseData.environment);
  const client_secret = await bcrypt.hash(rawSecret, 10);

  return await prisma.$transaction(async (tx) => {
    const app = await tx.externalApp.create({
      data: {
        ...baseData,
        client_id: clientId,
        client_secret,
        webhook_secret: webhookSecret,
        wallet: {
          create: { balance: 0, status: "ACTIVE", owner_type: "EXTERNAL_APP" },
        },
      },
      select: queryOptions?.select ?? undefined,
    });

    if (contract) {
      await upsertContract(tx, app.id, contract);
    }

    return { app, rawSecret };
  });
}

export async function updateExternalAppService(
  id: number,
  input: UpdateExternalAppInput,
  queryOptions?: Pick<FeatureApi["data"], "select" | "include">,
) {
  const {
    regenerate_client_id,
    regenerate_client_secret,
    regenerate_webhook_secret,
    contract,
    ...baseData
  } = input;

  return await prisma.$transaction(async (tx) => {
    const existing = await tx.externalApp.findUnique({ where: { id } });
    if (!existing) throw new HttpError(404, "external_apps:errors.not_found");

    let newSecretRaw: string | undefined;
    const credentialPatch: Partial<Prisma.ExternalAppUpdateInput> = {};

    if (regenerate_client_id) {
      credentialPatch.client_id = generateClientId(
        baseData.environment ?? existing.environment,
      );
    }
    if (regenerate_client_secret) {
      newSecretRaw = generateSecret();
      credentialPatch.client_secret = await bcrypt.hash(newSecretRaw, 10);
    }
    if (regenerate_webhook_secret) {
      credentialPatch.webhook_secret = generateWebhookSecret();
    }

    const updatedApp = await tx.externalApp.update({
      where: { id },
      data: { ...baseData, ...credentialPatch },
      select: queryOptions?.select ?? undefined,
    });

    if (contract) {
      await upsertContract(tx, id, contract);
    }

    return { app: updatedApp, newSecretRaw };
  });
}

export async function deleteExternalAppService(id: number) {
  const existing = await prisma.externalApp.findUnique({ where: { id } });
  if (!existing) throw new HttpError(404, "external_apps:errors.not_found");

  await prisma.externalApp.delete({ where: { id } });
  return { ok: true as const };
}
