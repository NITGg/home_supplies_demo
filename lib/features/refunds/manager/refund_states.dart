
import '../data/models/refund_model.dart';

abstract class RefundState {
  const RefundState();
}

class RefundInitial extends RefundState {}

// ── Reasons ───────────────────────────────────────────────────────────────────

class RefundReasonsLoading extends RefundState {}

class RefundReasonsLoaded extends RefundState {
  final List<RefundReason> reasons;
  const RefundReasonsLoaded(this.reasons);
}

class RefundReasonsError extends RefundState {
  final String message;
  const RefundReasonsError(this.message);
}

// ── Refunds list ──────────────────────────────────────────────────────────────

class RefundsLoading extends RefundState {}

class RefundsLoadingMore extends RefundState {}

class RefundsLoaded extends RefundState {
  final List<Refund> refunds;
  final int total;

  const RefundsLoaded({required this.refunds, required this.total});

  bool get hasMore => refunds.length < total;
}

class RefundsError extends RefundState {
  final String message;
  const RefundsError(this.message);
}

// ── Create refund ─────────────────────────────────────────────────────────────

class RefundSubmitting extends RefundState {}

class RefundSubmitted extends RefundState {
  final Refund refund;
  const RefundSubmitted(this.refund);
}

class RefundSubmitError extends RefundState {
  final String message;
  const RefundSubmitError(this.message);
}