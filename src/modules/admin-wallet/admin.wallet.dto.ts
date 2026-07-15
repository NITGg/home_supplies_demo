import z from "zod";
import {
  walletsSchema,
  unpaidCommissionSchema,
  penaltiesSchema,
  escrowsSchema,
  paymentMethodsSchema,
  transactionsSchema,
  adjustBalanceSchema,
  freezeSchema,
  applyPenaltySchema,
  CPWRSchema,
  changeUserIdPWRSchema,
  incBalancePWRSchema,
  decBalancePWRSchema,
  settlingBalanceSchema,
  settlementReportSchema,
} from "./admin.wallet.validation";

export type WalletDTO = z.infer<typeof walletsSchema>;
export type UnpaidCommissionDTO = z.infer<typeof unpaidCommissionSchema>;
export type PenaltiesDTO = z.infer<typeof penaltiesSchema>;
export type EscrowsDTO = z.infer<typeof escrowsSchema>;
export type PaymentMethodsDTO = z.infer<typeof paymentMethodsSchema>;
export type TransactionsDTO = z.infer<typeof transactionsSchema>;
export type AdjustBalanceDTO = z.infer<typeof adjustBalanceSchema>;
export type FreezeDTO = z.infer<typeof freezeSchema>;
export type ApplyPenaltyDTO = z.infer<typeof applyPenaltySchema>;
export type CPWRDTO = z.infer<typeof CPWRSchema>;
export type ChangeUserIdPWRDTO = z.infer<typeof changeUserIdPWRSchema>;
export type IncBalancePWRDTO = z.infer<typeof incBalancePWRSchema>;
export type DecBalancePWRDTO = z.infer<typeof decBalancePWRSchema>;
export type SettlingBalanceDTO = z.infer<typeof settlingBalanceSchema>;
export type SettlementReportDTO = z.infer<typeof settlementReportSchema>;
