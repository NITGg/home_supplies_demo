import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tawreedat_go/features/auth/manager/profile_cubit.dart';

import '../../../../../core/style/text_styles.dart';
import '../../../../../core/utils/api_client.dart';
import '../../../../../core/widgets/banners.dart';
import '../../../../../core/widgets/custom_button.dart';
import '../../../../../core/widgets/text_form.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../data/models/cancel_reason_model.dart';
import '../../../manager/order_cubit.dart';
import '../../../manager/order_states.dart';

/// Reusable bottom sheet for canceling orders.
/// Fetches preset cancellation reasons internally on open — no cubit needed.
class OrderCancelBottomSheet extends StatefulWidget {
  final bool isUnavailable;
  final int orderId;

  const OrderCancelBottomSheet({
    super.key,
    required this.isUnavailable,
    required this.orderId,
  });

  @override
  State<OrderCancelBottomSheet> createState() => _OrderCancelBottomSheetState();
}

class _OrderCancelBottomSheetState extends State<OrderCancelBottomSheet> {
  final TextEditingController _noteController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  List<CancellationReason> _reasons = [];
  bool _isLoadingReasons = false;
  String? _reasonsError;

  CancellationReason? _selectedReason;
  bool _isOtherSelected = false;

  @override
  void initState() {
    super.initState();
    if (!widget.isUnavailable) {
      _fetchReasons();
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  // ─── Data Fetching ─────────────────────────────────────────────────────────

  Future<void> _fetchReasons() async {
    setState(() {
      _isLoadingReasons = true;
      _reasonsError = null;
    });

    try {
      final response = await ApiClient.instance.dio.get(
        '/admin/cancellation-reason/all-reasons',
        queryParameters: {'role_id': context.read<ProfileCubit>().currentProfile?.roleId ?? 3, 'page': 1, 'limit': 50},
      );

      final data = response.data['data'] as Map<String, dynamic>;
      final list = (data['reasons'] as List<dynamic>)
          .map((e) => CancellationReason.fromJson(e as Map<String, dynamic>))
          .toList();

      if (mounted) {
        setState(() {
          _reasons = list;
          _isLoadingReasons = false;
        });
      }
    } on DioException {
      if (mounted) {
        setState(() {
          'Failed to load reasons';
          _isLoadingReasons = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _reasonsError = e.toString();
          _isLoadingReasons = false;
        });
      }
    }
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

  bool get _canSubmit {
    if (widget.isUnavailable) return true;
    if (_isOtherSelected) return _noteController.text.trim().length >= 10;
    return _selectedReason != null;
  }

  void _handleCancel() {
    if (!_formKey.currentState!.validate()) return;

    final cubit = context.read<OrderCubit>();

    if (widget.isUnavailable) {
      cubit.cancelOrderUnavailable(orderId: widget.orderId);
      return;
    }

    if (_isOtherSelected) {
      cubit.cancelOrderOther(
        orderId: widget.orderId,
        note: _noteController.text.trim(),
      );
    } else {
      final locale = Localizations.localeOf(context).languageCode;
      cubit.cancelOrderOther(
        orderId: widget.orderId,
        note: _selectedReason!.localizedReason(locale),
      );
    }
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return BlocListener<OrderCubit, OrderState>(
      listener: (context, state) {
        if (state is OrderCancelled) {
          Navigator.pop(context, true);
        } else if (state is OrderCancelError) {
          Navigator.pop(context, true);
          showErrorBanner(context, state.message);
        }
      },
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(l10n),
                    const SizedBox(height: 24),
                    _buildWarningBanner(l10n),
                    const SizedBox(height: 24),
                    if (!widget.isUnavailable) ...[
                      _buildReasonsSection(l10n),
                      const SizedBox(height: 24),
                    ],
                    _buildButtons(l10n),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader(AppLocalizations l10n) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.cancel_outlined,
            color: Colors.red.shade700,
            size: 28,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.cancelOrder,
                style: AppTextStyles.bold18.copyWith(
                  color: Colors.red.shade900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.isUnavailable
                    ? l10n.productUnAvailable
                    : l10n.otherReason,
                style: AppTextStyles.regular14.copyWith(
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
          color: Colors.grey.shade600,
        ),
      ],
    );
  }

  // ─── Warning Banner ────────────────────────────────────────────────────────

  Widget _buildWarningBanner(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200, width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: Colors.orange.shade700,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              l10n.cancelOrderWarning,
              style: AppTextStyles.regular14.copyWith(
                color: Colors.orange.shade900,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Reasons Section ───────────────────────────────────────────────────────

  Widget _buildReasonsSection(AppLocalizations l10n) {
    if (_isLoadingReasons) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: CircularProgressIndicator(color: Colors.orange,),
        ),
      );
    }

    if (_reasonsError != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red.shade700),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _reasonsError!,
                    style: AppTextStyles.regular14.copyWith(
                      color: Colors.red.shade900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _fetchReasons,
            icon: const Icon(Icons.refresh),
            label: Text(l10n.retry),
          ),
          const SizedBox(height: 8),
          // Fallback: let user type manually even if fetch failed
          _buildNoteField(l10n),
        ],
      );
    }

    return _buildReasonChips(l10n);
  }

  Widget _buildReasonChips(AppLocalizations l10n) {
    final locale = Localizations.localeOf(context).languageCode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.selectReason,
          style: AppTextStyles.bold14.copyWith(color: Colors.grey.shade800),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ..._reasons.map(
              (reason) => _ReasonChip(
                label: reason.localizedReason(locale),
                isSelected:
                    !_isOtherSelected && _selectedReason?.id == reason.id,
                onTap: () => setState(() {
                  _selectedReason = reason;
                  _isOtherSelected = false;
                  _noteController.clear();
                }),
              ),
            ),
            _ReasonChip(
              label: l10n.otherReason,
              isSelected: _isOtherSelected,
              isOther: true,
              onTap: () => setState(() {
                _isOtherSelected = true;
                _selectedReason = null;
              }),
            ),
          ],
        ),
        if (_isOtherSelected) ...[
          const SizedBox(height: 20),
          _buildNoteField(l10n),
        ],
      ],
    );
  }

  Widget _buildNoteField(AppLocalizations l10n) {
    return AppTextFormField(
      label: l10n.reason,
      controller: _noteController,
      prefixIcon: const Icon(Icons.note_alt_outlined),
      onChanged: (_) => setState(() {}),
      validator: (value) {
        if (!_isOtherSelected && _reasonsError == null) return null;
        if (value == null || value.trim().isEmpty) {
          return l10n.pleaseEnterReason;
        }
        if (value.trim().length < 10) return l10n.tooShort;
        return null;
      },
    );
  }

  // ─── Buttons ───────────────────────────────────────────────────────────────

  Widget _buildButtons(AppLocalizations l10n) {
    return BlocBuilder<OrderCubit, OrderState>(
      builder: (context, state) {
        final isLoading = state is CancelingOrder;

        return Row(
          children: [
            Expanded(
              child: AppCustomButton(
                onPressed: () => Navigator.pop(context),
                text: l10n.back,
                isSecondary: true,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppCustomButton(
                enabled: _canSubmit,
                onPressed: _handleCancel,
                text: l10n.confirm,
                isDelete: true,
                isLoading: isLoading,
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─── Reason Chip ──────────────────────────────────────────────────────────────

class _ReasonChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final bool isOther;
  final VoidCallback onTap;

  const _ReasonChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.isOther = false,
  });

  @override
  Widget build(BuildContext context) {
    final selectedColor = isOther ? Colors.blue.shade700 : Colors.red.shade700;
    final selectedBg = isOther ? Colors.blue.shade50 : Colors.red.shade50;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? selectedBg : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? selectedColor : Colors.grey.shade300,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected) ...[
              Icon(
                isOther ? Icons.edit_outlined : Icons.check_circle_outline,
                size: 16,
                color: selectedColor,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: AppTextStyles.regular14.copyWith(
                color: isSelected ? selectedColor : Colors.grey.shade700,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
