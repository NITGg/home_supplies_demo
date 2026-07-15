import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/style/app_colors.dart';
import '../../../../core/style/text_styles.dart';
import '../../../../core/utils/logger.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../l10n/app_localizations.dart';

class OfferForm extends StatefulWidget {
  final bool isResubmit;
  final bool isSubmitting;
  final bool hasDiscount;
  final bool isLocating;
  final GlobalKey<FormState> formKey;
  final TextEditingController feeController;
  final double minFee;
  final double maxFee;
  final double estimatedFee;
  final double? customerDiscountAmount;

  /// Peak-time / bonus fields populated from the fee-bounds endpoint
  final bool isPeakTime;
  final double peakTimeSurcharge; // already divided by 100, in EGP
  final double appliedBonus;      // already divided by 100, in EGP

  final Future<void> Function() onSubmit;
  final String? distanceM;

  const OfferForm({
    super.key,
    this.customerDiscountAmount,
    required this.isResubmit,
    required this.hasDiscount,
    required this.isSubmitting,
    required this.isLocating,
    required this.formKey,
    required this.feeController,
    required this.minFee,
    required this.maxFee,
    required this.estimatedFee,
    required this.onSubmit,
    required this.distanceM,
    this.isPeakTime = false,
    this.peakTimeSurcharge = 0,
    this.appliedBonus = 0,
  });

  @override
  State<OfferForm> createState() => _OfferFormState();
}

class _OfferFormState extends State<OfferForm>
    with SingleTickerProviderStateMixin {
  late double _currentFee;
  static const double _step = 1.0;

  late double _snappedMin;
  late double _snappedEstimated;
  late double _snappedMax;

  int _slideDirection = 1;

  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  // ── Snap helpers ──────────────────────────────────────────────────────────

  double _snapToStep(double v) => (v / _step).round() * _step;

  double _snapUp(double v) => (v / _step).ceil() * _step;

  double _snapDown(double v) => (v / _step).floor() * _step;

  // ── Life-cycle ────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _snappedMin       = _snapUp(widget.minFee);
    _snappedEstimated = _snapToStep(widget.estimatedFee);
    _snappedMax       = _snapDown(widget.maxFee);
    if (_snappedMax < _snappedMin) _snappedMax = _snappedMin;

    _currentFee = widget.hasDiscount
        ? _snappedMin
        : _snappedEstimated.clamp(_snappedMin, _snappedMax);

    dLog('min: $_snappedMin, est: $_snappedEstimated, max: $_snappedMax');
    _syncController();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.5,
    ).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _syncController() {
    widget.feeController.text = _currentFee.toStringAsFixed(0);
  }

  void _update(double newFee) {
    HapticFeedback.lightImpact();
    setState(() {
      _slideDirection = newFee > _currentFee ? 1 : -1;
      _currentFee = newFee.clamp(_snappedMin, _snappedMax);
      _syncController();
    });
    if (_currentFee == _snappedMin ||
        _currentFee == _snappedMax ||
        _currentFee == _snappedEstimated) {
      _pulseController.forward(from: 0);
    }
  }

  void _increment() => _update(_currentFee + _step);

  void _decrement() => _update(_currentFee - _step);

  void _jumpTo(double value) => _update(value);

  bool get _atMin => _currentFee <= _snappedMin;

  bool get _atMax => _currentFee >= _snappedMax;

  bool get _atEstimated => _currentFee == _snappedEstimated;

  double get _progress =>
      ((_currentFee - _snappedMin) / (_snappedMax - _snappedMin)).clamp(
        0.0,
        1.0,
      );

  Color get _progressColor {
    if (_progress < 0.5) return const Color(0xFF4CAF50);
    if (_progress < 0.85) return Colors.orange;
    return Colors.red.shade400;
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final showPeakBanner  = widget.isPeakTime && widget.peakTimeSurcharge > 0;
    final showBonusBanner = widget.appliedBonus > 0;

    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.all(20),
      child: Form(
        key: widget.formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ────────────────────────────────────────────────
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.kPrimaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.local_offer,
                    color: AppColors.kPrimaryColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.isResubmit ? l10n.submitOffer : l10n.submitYourOffer,
                    style: AppTextStyles.bold18,
                  ),
                ),
              ],
            ),

            // ── Peak-time banner ─────────────────────────────────────
            if (showPeakBanner) ...[
              const SizedBox(height: 14),
              _buildPeakTimeBanner(l10n),
            ],

            // ── Applied bonus banner ─────────────────────────────────
            if (showBonusBanner) ...[
              SizedBox(height: showPeakBanner ? 8 : 14),
              _buildBonusBanner(l10n),
            ],

            const SizedBox(height: 24),

            // ── Fee card ──────────────────────────────────────────────
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) => Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 24,
                  horizontal: 20,
                ),
                decoration: BoxDecoration(
                  color: AppColors.kPrimaryColor.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.kPrimaryColor.withOpacity(
                      0.10 + (_pulseAnimation.value - 1.0) * 0.3,
                    ),
                    width: _pulseAnimation.value,
                  ),
                ),
                child: child,
              ),
              child: Column(
                children: [
                  // ── "Your earnings" label ──────────────────────────
                  Text(
                    l10n.yourFee,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.kPrimaryColor.withOpacity(0.6),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 6),

                  // ── Animated net amount ────────────────────────────
                  SizedBox(
                    height: 68,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      transitionBuilder: (child, animation) {
                        final offset = _slideDirection > 0
                            ? const Offset(0, 0.4)
                            : const Offset(0, -0.4);
                        return SlideTransition(
                          position: Tween<Offset>(
                            begin: offset,
                            end: Offset.zero,
                          ).animate(
                            CurvedAnimation(
                              parent: animation,
                              curve: Curves.easeOutCubic,
                            ),
                          ),
                          child: FadeTransition(
                            opacity: animation,
                            child: child,
                          ),
                        );
                      },
                      child: Text(
                        _currentFee.toStringAsFixed(0),
                        key: ValueKey(_currentFee),
                        style: TextStyle(
                          fontSize: 56,
                          fontWeight: FontWeight.w800,
                          color: AppColors.kPrimaryColor,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
                  Text(
                    l10n.egp,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.kPrimaryColor.withOpacity(0.6),
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Slider + range labels (hidden when locked) ─────
                  if (!widget.hasDiscount && _snappedMin < _snappedMax) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0, end: _progress),
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutCubic,
                        builder: (context, value, _) =>
                            LinearProgressIndicator(
                              value: value,
                              minHeight: 8,
                              backgroundColor: Colors.grey.shade200,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                _progressColor,
                              ),
                            ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _RangeLabel(
                          icon: Icons.arrow_downward_rounded,
                          label: l10n.minimum,
                          value:
                          '${_snappedMin.toStringAsFixed(0)} ${l10n.egp}',
                          isActive: _atMin,
                          color: const Color(0xFF4CAF50),
                        ),
                        _RangeLabel(
                          icon: Icons.auto_awesome,
                          label: l10n.estimatedFee,
                          value:
                          '${_snappedEstimated.toStringAsFixed(0)} ${l10n.egp}',
                          isActive: _atEstimated,
                          color: AppColors.kPrimaryColor,
                          center: true,
                        ),
                        _RangeLabel(
                          icon: Icons.arrow_upward_rounded,
                          label: l10n.maximum,
                          value:
                          '${_snappedMax.toStringAsFixed(0)} ${l10n.egp}',
                          isActive: _atMax,
                          color: Colors.red.shade400,
                          alignEnd: true,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Discount notice ───────────────────────────────────────
            if (widget.hasDiscount) ...[
              _buildDiscountNotice(l10n),
              const SizedBox(height: 16),
            ],

            // ── Stepper row ───────────────────────────────────────────
            if (!widget.hasDiscount && _snappedMin < _snappedMax)
              Row(
                children: [
                  _StepButton(
                    icon: Icons.remove_rounded,
                    onTap: _atMin ? null : _decrement,
                    size: 60,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: _QuickChip(
                            label: l10n.minimum,
                            onTap: () => _jumpTo(_snappedMin),
                            isActive: _atMin,
                            activeColor: const Color(0xFF4CAF50),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _QuickChip(
                            label: l10n.estimatedFee,
                            onTap: () => _jumpTo(_snappedEstimated),
                            isActive: _atEstimated,
                            activeColor: AppColors.kPrimaryColor,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _QuickChip(
                            label: l10n.maximum,
                            onTap: () => _jumpTo(_snappedMax),
                            isActive: _atMax,
                            activeColor: Colors.red.shade400,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  _StepButton(
                    icon: Icons.add_rounded,
                    onTap: _atMax ? null : _increment,
                    size: 60,
                  ),
                ],
              ),

            // ── Hidden validator ──────────────────────────────────────
            SizedBox(
              height: 0,
              child: TextFormField(
                controller: widget.feeController,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                style: const TextStyle(fontSize: 0, color: Colors.transparent),
                validator: (value) {
                  final fee = double.tryParse(value ?? '');
                  if (fee == null) return l10n.pleaseEnterValidNumber;
                  if (fee < _snappedMin) {
                    return '${l10n.minimumFeeIs} '
                        '${_snappedMin.toStringAsFixed(0)} ${l10n.egp}';
                  }
                  if (fee > _snappedMax) {
                    return '${l10n.maximumFeeIs} '
                        '${_snappedMax.toStringAsFixed(0)} ${l10n.egp}';
                  }
                  return null;
                },
              ),
            ),

            const SizedBox(height: 20),

            AppCustomButton(
              onPressed: widget.onSubmit,
              text: widget.isSubmitting ? l10n.submitting : l10n.submitOffer,
              isLoading: widget.isSubmitting || widget.isLocating,
            ),
          ],
        ),
      ),
    );
  }

  // ── Peak-time banner ──────────────────────────────────────────────────────

  Widget _buildPeakTimeBanner(AppLocalizations l10n) {
    final surchargeStr = widget.peakTimeSurcharge % 1 == 0
        ? widget.peakTimeSurcharge.toInt().toString()
        : widget.peakTimeSurcharge.toStringAsFixed(2);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.deepOrange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.deepOrange.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.local_fire_department_rounded,
              size: 18, color: Colors.deepOrange.shade600),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${l10n.peakHoursTitle} 🔥',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.deepOrange.shade800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${l10n.peakHoursMessage1} $surchargeStr ${l10n.egp} ${l10n.peakHoursMessage2}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.deepOrange.shade700,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Applied bonus banner ──────────────────────────────────────────────────

  Widget _buildBonusBanner(AppLocalizations l10n) {
    final bonusStr = widget.appliedBonus % 1 == 0
        ? widget.appliedBonus.toInt().toString()
        : widget.appliedBonus.toStringAsFixed(2);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.stars_rounded, size: 18, color: Colors.green.shade600),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${l10n.bonusAddedTitle} ⭐',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.green.shade800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${l10n.bonusAddedMessage1} $bonusStr ${l10n.egp} ${l10n.bonusAddedMessage2}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.green.shade700,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Discount notice (shown when fee is locked due to customer coupon) ──────

  Widget _buildDiscountNotice(AppLocalizations l10n) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade300),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.card_giftcard_rounded,
              size: 18, color: Colors.orange.shade700),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.customerHasDiscount,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.orange.shade800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.customerHasDiscountHint,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.orange.shade700,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Range label ───────────────────────────────────────────────────────────────

class _RangeLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isActive;
  final Color color;
  final bool center;
  final bool alignEnd;

  const _RangeLabel({
    required this.icon,
    required this.label,
    required this.value,
    required this.isActive,
    required this.color,
    this.center = false,
    this.alignEnd = false,
  });

  @override
  Widget build(BuildContext context) {
    final align = alignEnd
        ? CrossAxisAlignment.end
        : center
        ? CrossAxisAlignment.center
        : CrossAxisAlignment.start;

    return AnimatedDefaultTextStyle(
      duration: const Duration(milliseconds: 200),
      style: AppTextStyles.regular14.copyWith(
        fontSize: 11,
        fontWeight: isActive ? FontWeight.w700 : FontWeight.normal,
        color: isActive ? color : Colors.grey.shade500,
      ),
      child: Column(
        crossAxisAlignment: align,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  icon,
                  key: ValueKey(isActive),
                  size: 11,
                  color: isActive ? color : Colors.grey.shade400,
                ),
              ),
              const SizedBox(width: 3),
              Text(label),
            ],
          ),
          const SizedBox(height: 2),
          Text(value),
        ],
      ),
    );
  }
}

// ── Step button ───────────────────────────────────────────────────────────────

class _StepButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final double size;

  const _StepButton({required this.icon, required this.onTap, this.size = 52});

  @override
  State<_StepButton> createState() => _StepButtonState();
}

class _StepButtonState extends State<_StepButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scaleController;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
      reverseDuration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.88).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  void _onTapDown(_) {
    if (widget.onTap != null) _scaleController.forward();
  }

  void _onTapUp(_) {
    _scaleController.reverse();
    widget.onTap?.call();
  }

  void _onTapCancel() => _scaleController.reverse();

  @override
  Widget build(BuildContext context) {
    final disabled = widget.onTap == null;
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: disabled ? Colors.grey.shade100 : AppColors.kPrimaryColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: disabled
                ? []
                : [
              BoxShadow(
                color: AppColors.kPrimaryColor.withOpacity(0.35),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(
            widget.icon,
            size: 28,
            color: disabled ? Colors.grey.shade300 : Colors.white,
          ),
        ),
      ),
    );
  }
}

// ── Quick-jump chip ───────────────────────────────────────────────────────────

class _QuickChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool isActive;
  final Color activeColor;

  const _QuickChip({
    required this.label,
    required this.onTap,
    required this.isActive,
    required this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? activeColor : activeColor.withOpacity(0.07),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? activeColor : activeColor.withOpacity(0.2),
            width: 1.5,
          ),
          boxShadow: isActive
              ? [
            BoxShadow(
              color: activeColor.withOpacity(0.25),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ]
              : [],
        ),
        child: Center(
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: AppTextStyles.regular14.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isActive ? Colors.white : activeColor,
            ),
            child: Text(label, textAlign: TextAlign.center),
          ),
        ),
      ),
    );
  }
}