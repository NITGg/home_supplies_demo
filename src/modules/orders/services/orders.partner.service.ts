import { prisma } from "@/config/prisma";
import { adjustWalletBalance } from "@/lib/adjustWalletBalance";
import { HttpError } from "@/lib/httpError";
import { PartnerFeeSplit, Prisma } from "@prisma/client";
import type { CreateOrderInput, ProposalDecisionInput } from "../orders.schema";
import { uploadSingleFile } from "@/lib/cloudinary/cloudinary.service";
import { generateOtp } from "@/lib/otp";
import { getRoadDistanceM } from "@/lib/distance";
import {
  assertOrderAcceptable,
  genOrderNumber,
  getProposalOrThrow,
  rejectOtherProposals,
  rejectProposal,
  getOrderOrThrow,
  roundTo100Ceil,
} from "../order.utils";
import { bus } from "@/events/bus";
import { logger } from "@/config/logger";
import { Decimal } from "@prisma/client/runtime/client";
import {
  ContractVehicle,
  PartnerContract,
  PartnerFeeResult,
  PartnerOrderPreview,
  PartnerPayoutData,
  PartnerVehicleQuote,
} from "@/types/orders/partner";
import { RawProposalRow } from "@/types/orders";
import type { Lang } from "@/types/express";
import { initiateOrderPayment } from "@/services/payment-gateway.service";

// ─── Contract resolver ────────────────────────────────────────────────────────

// Overload 1: getVehicleData is true
export async function resolvePartnerContract(
  externalAppId: number,
  getVehicleData: true,
): Promise<PartnerContract<true>>;

// Overload 2: getVehicleData is false (or default)
export async function resolvePartnerContract(
  externalAppId: number,
  getVehicleData?: false,
): Promise<PartnerContract<false>>;

// Implementation
export async function resolvePartnerContract(
  externalAppId: number,
  getVehicleData: boolean = false,
) {
  // Use 'any' or a union in the implementation signature
  const now = new Date();

  const contract = await prisma.partnerContract.findUnique({
    where: { external_app_id: externalAppId },
    select: {
      id: true,
      is_active: true,
      start_date: true,
      end_date: true,
      can_receive_courier_offers: true,
      vehicle_configs: {
        select: {
          id: true,
          vehicle_id: true,
          min_fee: true,
          m_min: true,
          m_max: true,
          extra_m_price: true,
          fee_per_m: true,
          // Prisma conditional select
          vehicle: getVehicleData
            ? {
                select: {
                  id: true,
                  name: true,
                  name_ar: true,
                },
              }
            : false,
          splits: {
            select: {
              badge_id: true,
              app_ratio: true,
              courier_ratio: true,
              partner_ratio: true,
            },
            take: 1,
            orderBy: { badge: { ratio: "desc" } },
          },
        },
      },
    },
  });

  if (!contract) throw new HttpError(404, "Contract not found");

  if (!contract.is_active)
    throw new HttpError(403, "external_apps:errors.no_active_contract");

  if (now < contract.start_date || now > contract.end_date)
    throw new HttpError(403, "external_apps:errors.contract_expired");

  return contract;
}

// ─── Vehicle resolver ─────────────────────────────────────────────────────────

function computeRawFee(vc: ContractVehicle, distanceM: number): Prisma.Decimal {
  const feePerCents = new Prisma.Decimal(vc.fee_per_m);
  const extraMPrice = new Prisma.Decimal(vc.extra_m_price);
  const minFee = new Prisma.Decimal(vc.min_fee);
  const billableM = distanceM;
  const extraM = Math.max(0, distanceM - vc.m_max);
  const rawFee = feePerCents.mul(billableM).add(extraMPrice.mul(extraM));
  return rawFee.lt(minFee) ? minFee : rawFee;
}

export function resolveContractVehicles(
  vehicleConfigs: ContractVehicle[],
  distanceM: number,
  requestedVehicleId?: number,
): {
  feeVehicle: ContractVehicle;
  lockedVehicleId: number | null;
  eligibleVehicleIds: number[];
} {
  if (requestedVehicleId !== undefined) {
    const match = vehicleConfigs.find(
      (vc) => vc.vehicle_id === requestedVehicleId,
    );
    if (!match)
      throw new HttpError(400, "external_apps:errors.vehicle_not_in_contract");
    if (distanceM < match.m_min)
      throw new HttpError(400, "external_apps:errors.distance_below_minimum");
    if (distanceM > match.m_max)
      throw new HttpError(400, "external_apps:errors.distance_above_maximum");

    return {
      feeVehicle: match,
      lockedVehicleId: match.vehicle_id,
      eligibleVehicleIds: [match.vehicle_id],
    };
  }

  const eligible = vehicleConfigs.filter(
    (vc) => distanceM >= vc.m_min && distanceM <= vc.m_max,
  );
  if (eligible.length === 0)
    throw new HttpError(
      400,
      "external_apps:errors.no_eligible_vehicle_for_distance",
    );

  // Pick the vehicle with the lowest computed fee for this distance
  const cheapest = eligible.reduce(
    (best, vc) =>
      computeRawFee(vc, distanceM).lt(computeRawFee(best, distanceM))
        ? vc
        : best,
    eligible[0],
  );

  return {
    feeVehicle: cheapest,
    lockedVehicleId: null,
    eligibleVehicleIds: eligible.map((vc) => vc.vehicle_id),
  };
}

// ─── Fee computation ──────────────────────────────────────────────────────────

export function computePartnerFee(
  vehicleConfig: ContractVehicle,
  distanceM: number,
  vatRate = 0,
): PartnerFeeResult {
  console.log(`--- [START] Fee Computation (Dist: ${distanceM}m) ---`);

  // 1. Normalize all inputs to Cents
  // min_fee is already 2500 (cents), so we keep it.
  const minFee = new Prisma.Decimal(vehicleConfig.min_fee);
  const feePerCents = new Prisma.Decimal(vehicleConfig.fee_per_m);
  const extraPriceCents = new Prisma.Decimal(vehicleConfig.extra_m_price);

  const extraM = Math.max(0, distanceM - vehicleConfig.m_max);

  // Raw fee calculations
  const baseFee = feePerCents.mul(distanceM);
  const extraFee = extraPriceCents.mul(extraM);
  const rawFee = baseFee.add(extraFee).mul(100);

  // Min fee comparison
  const totalFeeDecimal = rawFee.lt(minFee) ? minFee : rawFee;

  // Splits
  const defaultSplit = vehicleConfig.splits[0] ?? {
    app_ratio: 0.34,
    courier_ratio: 0.33,
    partner_ratio: 0.33,
  };

  // Split calculations
  const courierFeeDecimal = totalFeeDecimal
    .mul(defaultSplit.courier_ratio)
    .toDecimalPlaces(0);

  const partnerFeeDecimal = totalFeeDecimal
    .mul(defaultSplit.partner_ratio)
    .toDecimalPlaces(0);

  const appFeePreVat = totalFeeDecimal
    .sub(courierFeeDecimal)
    .sub(partnerFeeDecimal);

  // VAT
  const vatAmountDecimal = appFeePreVat.mul(vatRate).toDecimalPlaces(0);

  const appFeeDecimal = appFeePreVat.add(vatAmountDecimal);

  const totalWithVatDecimal = totalFeeDecimal.add(vatAmountDecimal);

  // Final result
  const results = {
    totalFee: totalFeeDecimal,
    vatAmount: vatAmountDecimal,
    totalFeeWithVat: totalWithVatDecimal,
    courierFeeAmount: courierFeeDecimal,
    appFeeAmount: appFeeDecimal,
    partnerFeeAmount: partnerFeeDecimal,
    app_ratio: defaultSplit.app_ratio,
    courier_ratio: defaultSplit.courier_ratio,
    partner_ratio: defaultSplit.partner_ratio,
    contractVehicleId: vehicleConfig.id,
  };

  return results;
}

// ─── Wallet helpers (scoped to partner) ──────────────────────────────────────

async function getPartnerWallet(
  tx: Prisma.TransactionClient,
  externalAppId: number,
) {
  const wallet = await tx.wallet.findUnique({
    where: { external_app_id: externalAppId },
    select: { id: true, balance: true, status: true },
  });
  if (!wallet)
    throw new HttpError(404, "external_apps:errors.wallet_not_found");
  if (wallet.status !== "ACTIVE")
    throw new HttpError(409, "external_apps:errors.wallet_not_active");

  return wallet;
}

async function holdPartnerWalletFunds(
  tx: Prisma.TransactionClient,
  externalAppId: number,
  orderId: number,
  orderNumber: string,
  holdCents: number,
): Promise<void> {
  const wallet = await getPartnerWallet(tx, externalAppId);
  logger.info(
    `Partner Wallet ${wallet} balance: ${wallet.balance} cents, holding ${holdCents} cents for order ${orderNumber}`,
  );
  if (wallet.balance < holdCents)
    throw new HttpError(
      400,
      "external_apps:errors.insufficient_wallet_balance",
      undefined,
      {
        required: holdCents,
        current: wallet.balance,
      },
    );

  await adjustWalletBalance(tx, wallet.id, -holdCents, { order_id: orderId });

  const escrow = await tx.escrow.create({
    data: {
      order_id: orderId,
      wallet_id: wallet.id,
      held_amount: holdCents,
    },
  });

  await tx.transaction.create({
    data: {
      wallet_id: wallet.id,
      order_id: orderId,
      escrow_id: escrow.id,
      type: "ESCROW_HOLD",
      status: "COMPLETED",
      amount: holdCents,
      description: `Hold for order ${orderNumber}`,
    },
  });
}

// ─── Create partner order ─────────────────────────────────────────────────────

export async function createPartnerOrderService(
  input: Extract<CreateOrderInput, { type: "CUSTOM_PICKUP" }>,
  externalAppId: number,
  file?: Express.Multer.File,
  paymentCtx?: {
    lang: Lang;
    paymobWebhookUrl: string;
    kashierWebhookUrl: string;
    easykashWebhookUrl: string;
  },
) {
  // 1. Contract
  const contract = await resolvePartnerContract(externalAppId);

  // 2. Distance
  const { distance: distanceM } = await getRoadDistanceM(
    { lat: +input.pickup_lat, lng: +input.pickup_long },
    { lat: +input.delivery_lat, lng: +input.delivery_long },
  );

  // 3. Vehicle resolution
  const { feeVehicle, lockedVehicleId, eligibleVehicleIds } =
    resolveContractVehicles(
      contract.vehicle_configs,
      distanceM,
      input.vehicle_id,
    );

  // 4. Areas + settings
  const [pickupArea, deliveryArea, settings] = await Promise.all([
    prisma.area.findUnique({
      where: { id: input.pickup_area_id },
      select: { id: true },
    }),
    prisma.area.findUnique({
      where: { id: input.delivery_area_id },
      select: { id: true },
    }),
    prisma.applicationSetting.findFirst({
      select: {
        proposal_waiting_time_minutes: true,
        order_expiration_time_minutes: true,
        vat: true,
      },
    }),
  ]);

  if (!pickupArea)
    throw new HttpError(400, "orders:errors.pickup_area_not_found");
  if (!deliveryArea)
    throw new HttpError(400, "orders:errors.delivery_area_not_found");

  const now = new Date();
  const proposalMinutes = settings?.proposal_waiting_time_minutes ?? 5;
  const expirationMinutes = settings?.order_expiration_time_minutes ?? 15;
  const proposalsDeadline = new Date(now.getTime() + proposalMinutes * 60_000);
  const expiresAt = new Date(now.getTime() + expirationMinutes * 60_000);
  const vatRate = settings?.vat ? settings.vat / 100 : 0;

  // 5. Fee
  const fee = computePartnerFee(feeVehicle, distanceM, vatRate);

  // 6. Image
  let product_image = input.product_image ?? null;
  if (file) {
    const { secure_url } = await uploadSingleFile({
      fileLocation: file.path, // .path or .buffer
      storagePathOnCloudinary: "orders",
    });
    product_image = secure_url;
  }

  // 7. Transaction
  const order = await prisma.$transaction(async (tx) => {
    const order = await tx.order.create({
      data: {
        external_app_id: externalAppId,
        customer_id: null,
        order_number: genOrderNumber(),
        type: "CUSTOM_PICKUP",
        product_description: input.product_description,
        product_image,
        budget: input.budget,
        courier_fee: fee.courierFeeAmount,
        platform_fee: fee.appFeeAmount,
        partner_fee: fee.partnerFeeAmount,
        vat_amount: fee.vatAmount,
        total_fee: fee.totalFeeWithVat,
        payable_amount: fee.totalFeeWithVat.add(
          new Prisma.Decimal(input.budget),
        ),
        payment_method: input.payment_method,
        discount_amount: 0,
        partner_app_ratio: fee.app_ratio,
        partner_courier_ratio: fee.courier_ratio,
        partner_ratio: fee.partner_ratio,
        contract_vehicle_id: fee.contractVehicleId,
        pickup_area_id: input.pickup_area_id,
        pickup_address_description: input.pickup_address_description,
        pickup_lat: input.pickup_lat ?? null,
        pickup_long: input.pickup_long ?? null,
        delivery_area_id: input.delivery_area_id,
        delivery_address_description: input.delivery_address_description,
        delivery_lat: input.delivery_lat ?? null,
        delivery_long: input.delivery_long ?? null,
        estemated_delivery_fee: fee.totalFee,
        distance_m: distanceM,
        vehicle_id: lockedVehicleId,
        status:
          input.payment_method === "CARD" ? "PENDING_PAYMENT" : "PENDING",
        proposals_deadline_at: proposalsDeadline,
        expires_at: expiresAt,
        // Fixed fee when contract disallows courier offers
        // or when vehicle was explicitly chosen by the partner
        is_fixed_fee:
          !contract.can_receive_courier_offers || lockedVehicleId !== null,
        confirmation_otp: generateOtp(4),
      },
    });

    // Wallet hold (same pattern as customer wallet)
    if (input.payment_method === "WALLET") {
      await holdPartnerWalletFunds(
        tx,
        externalAppId,
        order.id,
        order.order_number,
        order?.payable_amount!.toNumber(),
      );
    }

    return order;
  });

  // 8. CARD: initiate payment gateway — bus event is deferred until the
  // payment webhook confirms (see order-payment.handler.ts).
  if (input.payment_method === "CARD") {
    if (!paymentCtx)
      throw new HttpError(500, "orders:errors.payment_init_failed");

    const externalApp = await prisma.externalApp.findUnique({
      where: { id: externalAppId },
      select: { name: true },
    });

    const amountCents = Math.round(Number(order.payable_amount ?? 0));

    try {
      const cardPayment = await initiateOrderPayment({
        externalAppId,
        orderId: order.id,
        amountCents,
        orderNumber: order.order_number,
        user: { full_name: externalApp?.name ?? "Partner" },
        provider: input.card_provider ?? "paymob",
        lang: paymentCtx.lang,
        redirectionUrl: input.card_redirection_url,
        paymobWebhookUrl: paymentCtx.paymobWebhookUrl,
        kashierWebhookUrl: paymentCtx.kashierWebhookUrl,
        easykashWebhookUrl: paymentCtx.easykashWebhookUrl,
      });

      return { order, cardPayment };
    } catch (err) {
      await prisma.order.update({
        where: { id: order.id },
        data: { status: "CANCELLED" },
      });
      throw err;
    }
  }

  // 8. Bus event
  bus.emit("order.created", {
    orderId: order.id,
    deliveryAreaId: order.delivery_area_id!,
    createdAt: now.toISOString(),
    externalAppId,
    budget: +order.budget!,
    pickupAreaId: order.pickup_area_id!,
    vehicleIds: eligibleVehicleIds,
    distanceM,
    proposalsDeadline: proposalsDeadline.toISOString(),
    expiresAt: expiresAt.toISOString(),
    type: "CUSTOM_PICKUP",
    pickupLat: +order.pickup_lat!,
    pickupLng: +order.pickup_long!,
    isFixedFee: order.is_fixed_fee,
  });

  return { order };
}

/**
 * Resolves the correct split amounts for a partner order using the courier's
 * real badge. Returns the computed fee data — caller is responsible for
 * merging into their order update (avoids a double fetch + double write).
 *
 * Returns null if not a partner order or no split row exists for this badge,
 * in which case the caller should keep the creation-time defaults.
 */
export async function computePartnerPayoutForCourier(
  tx: Prisma.TransactionClient,
  input: {
    contractVehicleId: number;
    courierBudgetCents: Prisma.Decimal; // 👈 What the courier wants
    courierId: number;
    vatRate: number;
  },
): Promise<PartnerPayoutData | null> {
  const courier = await tx.courier.findUnique({
    where: { id: input.courierId },
    select: { user: { select: { badge_id: true } } },
  });

  if (!courier?.user?.badge_id) return null;

  const split = await tx.partnerFeeSplit.findFirst({
    where: {
      contract_vehicle_id: input.contractVehicleId,
      badge_id: courier.user.badge_id,
    },
    select: { app_ratio: true, courier_ratio: true, partner_ratio: true },
  });

  if (!split) return null;

  // Logic: courierBudgetCents = TotalNoVat * split.courier_ratio
  // TotalNoVat = courierBudgetCents / split.courier_ratio
  const courierFee = input.courierBudgetCents;
  const totalFeeNoVat = courierFee.div(split.courier_ratio).toDecimalPlaces(2);

  const partnerFee = totalFeeNoVat.mul(split.partner_ratio).toDecimalPlaces(2);
  const appFeePreVat = totalFeeNoVat.sub(courierFee).sub(partnerFee);

  const vatAmount = appFeePreVat.mul(input.vatRate).toDecimalPlaces(2);
  const platformFee = appFeePreVat.add(vatAmount);

  // Final total seen by partner
  const totalFeeWithVat = totalFeeNoVat.add(vatAmount);

  return {
    courier_fee: courierFee,
    platform_fee: platformFee,
    partner_fee: partnerFee,
    vat_amount: vatAmount,
    total_fee: totalFeeWithVat, // 👈 Total partner pays for delivery
    partner_app_ratio: split.app_ratio,
    partner_courier_ratio: split.courier_ratio,
    partner_ratio: split.partner_ratio,
  };
}

// ─── Partner proposal accept ──────────────────────────────────────────────────

export async function acceptPartnerProposalService(
  orderId: number,
  proposalId: number,
  input: ProposalDecisionInput,
  externalAppId: number,
) {
  const order = await getOrderOrThrow(orderId);

  if (order.external_app_id !== externalAppId)
    throw new HttpError(403, "orders:errors.forbidden");

  assertOrderAcceptable(order);

  const proposal = await getProposalOrThrow(proposalId, orderId);

  if (input.status === "REJECTED") {
    const updatedProposal = await rejectProposal(proposalId, {
      orderId,
      courierId: proposal.courier_id!,
      actorId: externalAppId,
      isPartner: true,
    });
    return { order, proposal: updatedProposal };
  }

  const settings = await prisma.applicationSetting.findFirst({
    select: { vat: true },
  });
  const vatRate = settings?.vat ? settings.vat / 100 : 0;

  const result = await prisma.$transaction(async (tx) => {
    const acceptedProposal = await tx.orderProposal.update({
      where: { id: proposalId },
      data: { status: "ACCEPTED", confirmed_at: new Date() },
    });

    await rejectOtherProposals(tx, orderId, proposalId);

    const payoutData = order.contract_vehicle_id
      ? await computePartnerPayoutForCourier(tx, {
          contractVehicleId: order.contract_vehicle_id,
          courierBudgetCents: proposal.total_fee, // The "total_fee" on proposal is the courier's ask
          courierId: proposal.courier_id!,
          vatRate,
        })
      : null;

    // Use the computed total_fee if available
    const finalTotalFee = payoutData?.total_fee ?? proposal.total_fee;
    const finalPayableAmount = finalTotalFee.add(order.budget ?? 0);

    const updatedOrder = await tx.order.update({
      where: { id: orderId },
      data: {
        courier_id: proposal.courier_id,
        status: "IN_PROGRESS",
        offer_accepted_at: new Date(),
        // Fee breakdown
        courier_fee: payoutData?.courier_fee,
        platform_fee: payoutData?.platform_fee,
        partner_fee: payoutData?.partner_fee,
        vat_amount: payoutData?.vat_amount,
        total_fee: finalTotalFee,
        payable_amount: finalPayableAmount,
      },
      select: {
        id: true,
        external_app_id: true,
        courier_id: true,
        delivery_area_id: true,
        pickup_area_id: true,
        payment_method: true,
        budget: true,
        total_fee: true,
        courier_fee: true,
        platform_fee: true,
        partner_fee: true,
        order_number: true,
        payable_amount: true,
      },
    });

    if (updatedOrder.payment_method === "WALLET") {
      await adjustPartnerOrderEscrow(tx, {
        orderId: updatedOrder.id,
        externalAppId,
        requiredAmount: updatedOrder.payable_amount!,
      });
    }

    return { order: updatedOrder, proposal: acceptedProposal };
  });

  bus.emit("offer.accepted", {
    orderId: result.order.id,
    offerId: result.proposal.id,
    courierId: result.order.courier_id!,
    customerId: 1,
    pickupAreaId: result.order.pickup_area_id!,
    acceptedAt: new Date().toISOString(),
  });

  return result;
}

export async function adjustPartnerOrderEscrow(
  tx: Prisma.TransactionClient,
  input: {
    orderId: number;
    externalAppId: number;
    requiredAmount: Prisma.Decimal;
  },
): Promise<void> {
  const wallet = await tx.wallet.findUnique({
    where: { external_app_id: input.externalAppId },
    select: { id: true, balance: true, status: true },
  });

  if (!wallet)
    throw new HttpError(404, "external_apps:errors.wallet_not_found");
  if (wallet.status !== "ACTIVE")
    throw new HttpError(409, "wallet:errors.wallet_not_active");

  const escrow = await tx.escrow.findFirst({
    where: { order_id: input.orderId, wallet_id: wallet.id },
    select: { id: true, held_amount: true },
  });

  if (!escrow) throw new HttpError(500, "orders:errors.escrow_missing");

  const currentHeld = new Prisma.Decimal(escrow.held_amount);
  const diff = input.requiredAmount.sub(currentHeld);

  if (diff.isZero()) return;

  const diffAmountCents = diff.abs().toNumber();

  if (diff.isPositive()) {
    // Check if partner has enough balance for the additional amount
    if (wallet.balance < diffAmountCents) {
      throw new HttpError(
        400,
        "orders:errors.insufficient_wallet_balance_for_fee",
        undefined,
        { required: diffAmountCents, current: wallet.balance },
      );
    }

    // Charge the shortfall
    await adjustWalletBalance(tx, wallet.id, -diffAmountCents, {
      order_id: input.orderId,
    });

    await tx.transaction.create({
      data: {
        wallet_id: wallet.id,
        order_id: input.orderId,
        escrow_id: escrow.id,
        type: "ESCROW_HOLD",
        status: "COMPLETED",
        amount: diffAmountCents,
        description: "Partner escrow adjusted (shortfall charged)",
      },
    });
  } else {
    // Refund the overage
    await adjustWalletBalance(tx, wallet.id, diffAmountCents, {
      order_id: input.orderId,
    });

    await tx.transaction.create({
      data: {
        wallet_id: wallet.id,
        order_id: input.orderId,
        escrow_id: escrow.id,
        type: "ESCROW_RELEASE",
        status: "COMPLETED",
        amount: diffAmountCents,
        description: "Partner escrow adjusted (overage refunded)",
      },
    });
  }

  // Finalize the escrow record
  await tx.escrow.update({
    where: { id: escrow.id },
    data: { held_amount: input.requiredAmount },
  });
}

export async function releasePartnerEscrow(
  tx: Prisma.TransactionClient,
  input: {
    orderId: number;
    externalAppId: number;
    totalFee: Prisma.Decimal;
  },
): Promise<void> {
  const wallet = await tx.wallet.findUnique({
    where: { external_app_id: input.externalAppId },
    select: { id: true },
  });
  if (!wallet) return;

  const escrow = await tx.escrow.findFirst({
    where: { order_id: input.orderId, wallet_id: wallet.id },
    select: { id: true, held_amount: true },
  });
  if (!escrow) return;

  // Mark escrow as released
  await tx.escrow.update({
    where: { id: escrow.id },
    data: { held_amount: 0 },
  });

  await tx.transaction.create({
    data: {
      wallet_id: wallet.id,
      order_id: input.orderId,
      escrow_id: escrow.id,
      type: "ESCROW_RELEASE",
      status: "COMPLETED",
      amount: input.totalFee.toNumber(),
      description: `Escrow released on delivery for order #${input.orderId}`,
    },
  });
}

export async function previewPartnerOrderService(
  input: Extract<CreateOrderInput, { type: "CUSTOM_PICKUP" }>,
  externalAppId: number,
): Promise<PartnerOrderPreview> {
  const [contract, distanceResult, settings] = await Promise.all([
    resolvePartnerContract(externalAppId, true),
    getRoadDistanceM(
      { lat: +input.pickup_lat, lng: +input.pickup_long },
      { lat: +input.delivery_lat, lng: +input.delivery_long },
    ),
    prisma.applicationSetting.findFirst({ select: { vat: true } }),
  ]);

  const distanceM = distanceResult.distance;
  const vatRate = settings?.vat ? settings.vat / 100 : 0;
  const budget = input.budget ?? 0;

  const eligible = contract.vehicle_configs.filter(
    (vc) => distanceM >= vc.m_min && distanceM <= vc.m_max,
  );
  if (eligible.length === 0)
    throw new HttpError(
      400,
      "external_apps:errors.no_eligible_vehicle_for_distance",
    );

  // Compute fee for every eligible vehicle
  const computed = eligible.map((vc) => ({
    vc,
    fee: computePartnerFee(vc, distanceM, vatRate),
  }));

  // Find cheapest by total_fee
  const cheapestFee = computed.reduce(
    (min, c) => (c.fee.totalFeeWithVat.lt(min) ? c.fee.totalFeeWithVat : min),
    computed[0].fee.totalFeeWithVat,
  );

  const toQuote = (
    vc: ContractVehicle,
    fee: PartnerFeeResult,
    isSelected: boolean,
  ): PartnerVehicleQuote => ({
    vehicle_id: vc.vehicle_id,
    name: vc.vehicle?.name ?? "",
    name_ar: vc.vehicle?.name_ar ?? "",
    contract_vehicle_id: vc.id,
    total_fee: fee.totalFeeWithVat.toNumber(),
    courier_fee: fee.courierFeeAmount.toNumber(),
    platform_fee: fee.appFeeAmount.toNumber(),
    partner_fee: fee.partnerFeeAmount.toNumber(),
    vat_amount: fee.vatAmount.toNumber(),
    // payable = delivery fee + goods budget (mirrors order.payable_amount)
    payable_amount: fee.totalFeeWithVat.add(budget).toNumber(),
    is_cheapest: fee.totalFeeWithVat.eq(cheapestFee),
    is_selected: isSelected,
  });

  const options = computed.map(({ vc, fee }) =>
    toQuote(vc, fee, vc.vehicle_id === input.vehicle_id),
  );

  // Cheapest is the auto-selected vehicle on create when none is specified
  const recommendedEntry = computed.find(({ fee }) =>
    fee.totalFeeWithVat.eq(cheapestFee),
  )!;
  const recommended = toQuote(recommendedEntry.vc, recommendedEntry.fee, false);

  // Validate and surface selected vehicle if requested
  let selected: PartnerVehicleQuote | null = null;
  if (input.vehicle_id !== undefined) {
    selected = options.find((o) => o.vehicle_id === input.vehicle_id) ?? null;
    if (!selected)
      throw new HttpError(400, "external_apps:errors.vehicle_not_in_contract");
  }

  return {
    distance_m: distanceM,
    budget,
    recommended,
    selected,
    options,
  };
}

export function computePartnerSplitFromCourierBudget(
  courierBid: Decimal,
  row: RawProposalRow,
  splits: PartnerFeeSplit[],
  vatRate: Decimal,
  isPeakTimeActive: boolean,
) {
  const split = splits.find((s) => s.badge_id === row.badge_id);

  // 1. Get Ratios (Defaults to 33/33/33 if split record is missing)
  const cRatio = Decimal(split?.courier_ratio ?? 0.33);
  const pRatio = Decimal(split?.partner_ratio ?? 0.33);

  // 2. Derive Total Base Fee (No VAT) from Courier Bid
  // Formula: Bid = Total * cRatio -> Total = Bid / cRatio
  const totalFeeNoVat = courierBid.div(cRatio).toDecimalPlaces(2);

  // 3. Calculate Surcharges
  const partnerFee = totalFeeNoVat.mul(pRatio).toDecimalPlaces(2);
  const platformFeePreVat = totalFeeNoVat.sub(courierBid).sub(partnerFee);

  // 4. Handle Peak Time logic (Matching standard behavior)
  const peakRatio = isPeakTimeActive ? (row.v_peak_time_fee_ratio ?? 0) : 0;
  // Surcharge is usually derived from the subtotal
  const peakTimeSurcharge =
    peakRatio > 0
      ? roundTo100Ceil(totalFeeNoVat.mul(peakRatio).div(100))
      : Decimal(0);

  // 5. VAT calculation
  const vatAmount = roundTo100Ceil(platformFeePreVat.mul(vatRate));

  // 6. Final Return Object (Same schema as computeOrderFeeSplit)
  return {
    courierFee: courierBid, // The bid is what the courier gets
    platformFee: platformFeePreVat.add(vatAmount), // Platform share + VAT
    vatAmount: vatAmount,
    totalFeeWithVat: totalFeeNoVat.add(vatAmount).add(peakTimeSurcharge),
    isPeakTime: peakRatio > 0,
    peakTimeSurcharge: peakTimeSurcharge,
  };
}
