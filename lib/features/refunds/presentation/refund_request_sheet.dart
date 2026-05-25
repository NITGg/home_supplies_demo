import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fluttertoast/fluttertoast.dart';

import '../../../../../core/style/text_styles.dart';
import '../../../../../core/widgets/banners.dart';
import '../../../../../core/widgets/custom_button.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../core/utils/image_picker.dart';

import '../../orders/data/models/order_items.dart';
import '../../orders/data/models/order_model.dart';
import '../data/models/refund_model.dart';
import '../manager/refund_cubit.dart';
import '../manager/refund_states.dart';

/// Bottom sheet that lets a customer request a refund for a delivered order.
///
/// Usage:
/// ```dart
/// showModalBottomSheet(
///   context: context,
///   isScrollControlled: true,
///   backgroundColor: Colors.transparent,
///   builder: (_) => BlocProvider(
///     create: (_) => RefundCubit()..loadReasons(),
///     child: RefundRequestSheet(order: order),
///   ),
/// );
/// ```
class RefundRequestSheet extends StatefulWidget {
  final Order order;

  const RefundRequestSheet({super.key, required this.order});

  @override
  State<RefundRequestSheet> createState() => _RefundRequestSheetState();
}

class _RefundRequestSheetState extends State<RefundRequestSheet> {
  // ── item selections: orderItemId → quantity chosen ────────────────────────
  final Map<int, int> _selectedQuantities = {};

  RefundReason? _selectedReason;
  bool _isOtherReason = false;
  final TextEditingController _otherReasonCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  final List<File> _evidenceImages = [];

  @override
  void dispose() {
    _otherReasonCtrl.dispose();
    super.dispose();
  }

  // ── helpers ───────────────────────────────────────────────────────────────

  bool get _hasItems => widget.order.orderItems
      .any((i) => i.product.isStillRefundable(widget.order.createdAt));

  bool get _anyItemSelected => _selectedQuantities.values.any((q) => q > 0);

  bool get _reasonSelected => _isOtherReason
      ? _otherReasonCtrl.text.trim().length >= 5
      : _selectedReason != null;

  bool get _canSubmit => _anyItemSelected && _reasonSelected;

  String get _resolvedReason {
    if (_isOtherReason) return _otherReasonCtrl.text.trim();
    final locale = Localizations.localeOf(context).languageCode;
    return _selectedReason!.localizedReason(locale);
  }

  List<RefundItemRequest> get _items => _selectedQuantities.entries
      .where((e) => e.value > 0)
      .map((e) => RefundItemRequest(orderItemId: e.key, quantity: e.value))
      .toList();

  // ── actions ───────────────────────────────────────────────────────────────

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (!_canSubmit) return;

    context.read<RefundCubit>().createRefund(
      orderId: widget.order.id!,
      reason: _resolvedReason,
      items: _items,
      evidenceImages: _evidenceImages.isEmpty ? null : _evidenceImages,
    );
  }

  Future<void> _addImage() async {
    if (_evidenceImages.length >= 5) return;
    final file = await ImagePickerService.pickSingle(context);
    if (file != null && mounted) {
      setState(() => _evidenceImages.add(file));
    }
  }

  void _removeImage(int index) =>
      setState(() => _evidenceImages.removeAt(index));

  // ── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return BlocListener<RefundCubit, RefundState>(
      listener: (context, state) {
        if (state is RefundSubmitted) {
          Navigator.pop(context, true);
          showSuccessBanner(context, l10n.refundRequestSubmitted);
        } else if (state is RefundSubmitError) {
          Fluttertoast.showToast(
            msg: state.message,
            toastLength: Toast.LENGTH_LONG,
            gravity: ToastGravity.BOTTOM,
            backgroundColor: Colors.red,
            textColor: Colors.white,
          );
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
          child: Form(
            key: _formKey,
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.all(24),
              children: [
                _buildHeader(l10n),
                const SizedBox(height: 20),
                _buildInfoBanner(l10n),
                const SizedBox(height: 24),
                if (_hasItems) ...[
                  _buildItemsSection(l10n),
                  const SizedBox(height: 24),
                ],
                _buildReasonsSection(l10n),
                const SizedBox(height: 24),
                _buildImagesSection(l10n),
                const SizedBox(height: 28),
                _buildButtons(l10n),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader(AppLocalizations l10n) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.assignment_return_outlined,
            color: Colors.orange.shade700,
            size: 28,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.requestRefund,
                style: AppTextStyles.bold18.copyWith(
                  color: Colors.orange.shade900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                textDirection: TextDirection.ltr,
                '#${widget.order.orderNumber ?? widget.order.id}',
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

  // ── Info banner ───────────────────────────────────────────────────────────

  Widget _buildInfoBanner(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: Colors.blue.shade700,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              l10n.refundInfoBanner,
              style: AppTextStyles.regular14.copyWith(
                color: Colors.blue.shade900,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Items section ─────────────────────────────────────────────────────────

  Widget _buildItemsSection(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.selectItemsToRefund,
          style: AppTextStyles.bold14.copyWith(color: Colors.grey.shade800),
        ),
        const SizedBox(height: 4),
        Text(
          l10n.selectItemsToRefundHint,
          style: AppTextStyles.regular14.copyWith(
            fontSize: 12,
            color: Colors.grey.shade500,
          ),
        ),
        const SizedBox(height: 12),
        ...widget.order.orderItems
            .where((item) => item.product.isStillRefundable(widget.order.createdAt))
            .map(
              (item) => _RefundItemRow(
                item: item,
                selectedQty: _selectedQuantities[item.id] ?? 0,
                onChanged: (qty) =>
                    setState(() => _selectedQuantities[item.id] = qty),
              ),
            ),
        if (!_anyItemSelected)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              l10n.pleaseSelectAtLeastOneItem,
              style: TextStyle(fontSize: 12, color: Colors.red.shade600),
            ),
          ),
      ],
    );
  }

  // ── Reasons section ───────────────────────────────────────────────────────

  Widget _buildReasonsSection(AppLocalizations l10n) {
    return BlocBuilder<RefundCubit, RefundState>(
      buildWhen: (prev, curr) =>
          curr is RefundReasonsLoading ||
          curr is RefundReasonsLoaded ||
          curr is RefundReasonsError,
      builder: (context, state) {
        if (state is RefundReasonsLoading) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: CircularProgressIndicator(color: Colors.orange),
            ),
          );
        }

        if (state is RefundReasonsError) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildErrorBox(state.message),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => context.read<RefundCubit>().loadReasons(),
                icon: const Icon(Icons.refresh),
                label: Text(l10n.retry),
              ),
              const SizedBox(height: 8),
              _buildOtherReasonField(l10n, forceShow: true),
            ],
          );
        }

        final reasons = state is RefundReasonsLoaded
            ? state.reasons
            : <RefundReason>[];

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
                ...reasons.map(
                  (r) => _ReasonChip(
                    label: r.localizedReason(
                      Localizations.localeOf(context).languageCode,
                    ),
                    isSelected: !_isOtherReason && _selectedReason?.id == r.id,
                    color: Colors.orange,
                    onTap: () => setState(() {
                      _selectedReason = r;
                      _isOtherReason = false;
                      _otherReasonCtrl.clear();
                    }),
                  ),
                ),
                _ReasonChip(
                  label: l10n.otherReason,
                  isSelected: _isOtherReason,
                  color: Colors.blue,
                  isOther: true,
                  onTap: () => setState(() {
                    _isOtherReason = true;
                    _selectedReason = null;
                  }),
                ),
              ],
            ),
            if (_isOtherReason) ...[
              const SizedBox(height: 16),
              _buildOtherReasonField(l10n),
            ],
          ],
        );
      },
    );
  }

  Widget _buildOtherReasonField(
    AppLocalizations l10n, {
    bool forceShow = false,
  }) {
    return TextFormField(
      controller: _otherReasonCtrl,
      maxLines: 3,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        labelText: l10n.reason,
        hintText: l10n.describeYourRefundReason,
        prefixIcon: const Icon(Icons.note_alt_outlined),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.orange, width: 1.5),
        ),
      ),
      validator: (value) {
        if (!_isOtherReason && !forceShow) return null;
        if (value == null || value.trim().isEmpty) {
          return l10n.pleaseEnterReason;
        }
        if (value.trim().length < 5) return l10n.tooShort;
        return null;
      },
    );
  }

  Widget _buildErrorBox(String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade600, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.regular14.copyWith(
                color: Colors.red.shade900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Images section ────────────────────────────────────────────────────────

  Widget _buildImagesSection(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              l10n.evidencePhotos,
              style: AppTextStyles.bold14.copyWith(color: Colors.grey.shade800),
            ),
            const SizedBox(width: 6),
            Text(
              l10n.optional,
              style: AppTextStyles.regular14.copyWith(
                fontSize: 12,
                color: Colors.grey.shade500,
              ),
            ),
            const Spacer(),
            Text(
              '${_evidenceImages.length}/5',
              style: AppTextStyles.regular14.copyWith(
                fontSize: 12,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          l10n.evidencePhotosHint,
          style: AppTextStyles.regular14.copyWith(
            fontSize: 12,
            color: Colors.grey.shade500,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 90,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              ..._evidenceImages.asMap().entries.map(
                (e) => _ImageThumb(
                  file: e.value,
                  onRemove: () => _removeImage(e.key),
                ),
              ),
              if (_evidenceImages.length < 5) _AddImageButton(onTap: _addImage),
            ],
          ),
        ),
      ],
    );
  }

  // ── Buttons ───────────────────────────────────────────────────────────────

  Widget _buildButtons(AppLocalizations l10n) {
    return BlocBuilder<RefundCubit, RefundState>(
      buildWhen: (_, curr) =>
          curr is RefundSubmitting ||
          curr is RefundSubmitted ||
          curr is RefundSubmitError,
      builder: (context, state) {
        final isLoading = state is RefundSubmitting;
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
                onPressed: _submit,
                text: l10n.submitRefund,
                isLoading: isLoading,
              ),
            ),
          ],
        );
      },
    );
  }
}

// ── Item row ──────────────────────────────────────────────────────────────────

class _RefundItemRow extends StatelessWidget {
  final OrderItem item;
  final int selectedQty;
  final ValueChanged<int> onChanged;

  const _RefundItemRow({
    required this.item,
    required this.selectedQty,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).languageCode;
    final name = locale == 'ar' && item.product.nameAr.isNotEmpty
        ? item.product.nameAr
        : item.product.name;

    final isSelected = selectedQty > 0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isSelected ? Colors.orange.shade50 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? Colors.orange.shade300 : Colors.grey.shade200,
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          // ── thumbnail ───────────────────────────────────────────────────
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: item.product.images.isNotEmpty
                ? Image.network(
                    item.product.images.first,
                    width: 44,
                    height: 44,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _placeholder(),
                  )
                : _placeholder(),
          ),
          const SizedBox(width: 12),
          // ── name & price ─────────────────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: AppTextStyles.regular14.copyWith(
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // ── qty stepper ──────────────────────────────────────────────────
          _QtyStepper(
            current: selectedQty,
            max: item.quantity,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _placeholder() => Container(
    width: 44,
    height: 44,
    decoration: BoxDecoration(
      color: Colors.grey.shade200,
      borderRadius: BorderRadius.circular(8),
    ),
    child: const Icon(
      Icons.image_not_supported_outlined,
      size: 20,
      color: Colors.grey,
    ),
  );
}

// ── Qty stepper ───────────────────────────────────────────────────────────────

class _QtyStepper extends StatelessWidget {
  final int current;
  final int max;
  final ValueChanged<int> onChanged;

  const _QtyStepper({
    required this.current,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StepBtn(
          icon: Icons.remove,
          enabled: current > 0,
          onTap: () => onChanged(current - 1),
          active: current > 0,
        ),
        SizedBox(
          width: 30,
          child: Text(
            '$current',
            textAlign: TextAlign.center,
            style: AppTextStyles.bold14.copyWith(
              color: current > 0
                  ? Colors.orange.shade700
                  : Colors.grey.shade500,
            ),
          ),
        ),
        _StepBtn(
          icon: Icons.add,
          enabled: current < max,
          onTap: () => onChanged(current + 1),
          active: current < max,
        ),
      ],
    );
  }
}

class _StepBtn extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final bool active;
  final VoidCallback onTap;

  const _StepBtn({
    required this.icon,
    required this.enabled,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: active ? Colors.orange.shade600 : Colors.grey.shade200,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: 16,
          color: active ? Colors.white : Colors.grey.shade400,
        ),
      ),
    );
  }
}

// ── Reason chip ───────────────────────────────────────────────────────────────

class _ReasonChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final bool isOther;
  final Color color;
  final VoidCallback onTap;

  const _ReasonChip({
    required this.label,
    required this.isSelected,
    required this.color,
    required this.onTap,
    this.isOther = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
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
                color: color,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: AppTextStyles.regular14.copyWith(
                color: isSelected ? color : Colors.grey.shade700,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Image thumb ───────────────────────────────────────────────────────────────

class _ImageThumb extends StatelessWidget {
  final File file;
  final VoidCallback onRemove;

  const _ImageThumb({required this.file, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          width: 80,
          height: 80,
          margin: const EdgeInsets.only(right: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade300),
            image: DecorationImage(image: FileImage(file), fit: BoxFit.cover),
          ),
        ),
        Positioned(
          top: 2,
          right: 12,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: Colors.red.shade600,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, size: 12, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Add image button ──────────────────────────────────────────────────────────

class _AddImageButton extends StatelessWidget {
  final VoidCallback onTap;

  const _AddImageButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 80,
        height: 80,
        margin: const EdgeInsets.only(right: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: Colors.orange.shade300,
            style: BorderStyle.solid,
          ),
          color: Colors.orange.shade50,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_a_photo_outlined,
              color: Colors.orange.shade600,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              AppLocalizations.of(context)!.addPhoto,
              style: TextStyle(fontSize: 10, color: Colors.orange.shade700),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
