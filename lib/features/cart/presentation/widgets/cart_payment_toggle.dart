import 'package:flutter/material.dart';
import 'package:tawreedat_go/core/style/app_colors.dart';
import 'package:tawreedat_go/core/style/text_styles.dart';
import 'package:tawreedat_go/core/utils/app_dynamic_settings.dart';
import 'package:tawreedat_go/l10n/app_localizations.dart';

/// Payment toggle: CASH · WALLET · CARD (CARD hidden when no provider is enabled).
///
/// The sliding white pill animates to whichever option is active.
/// [cashDisabled] prevents selecting CASH (e.g. when over COD limit).
class CartPaymentToggle extends StatelessWidget {
  final String paymentMethod;
  final ValueChanged<String> onChanged;
  final AppLocalizations l10n;
  final bool cashDisabled;

  const CartPaymentToggle({
    super.key,
    required this.paymentMethod,
    required this.onChanged,
    required this.l10n,
    this.cashDisabled = false,
  });

  /// CARD is shown only when at least one card provider is enabled.
  static bool get _cardEnabled =>
      AppSettings.kashier_enabled == true || AppSettings.paymob_enabled == true;

  List<String> get _options =>
      _cardEnabled ? ['CASH', 'WALLET', 'CARD'] : ['CASH', 'WALLET'];

  Alignment _pillAlignment() {
    final idx = _options.indexOf(paymentMethod).clamp(0, _options.length - 1);
    // 2 options: left=-1, right=1   |   3 options: left=-1, centre=0, right=1
    final step = 2.0 / (_options.length - 1);
    return Alignment(-1.0 + idx * step, 0.0);
  }

  @override
  Widget build(BuildContext context) {
    final cardEnabled = _cardEnabled;
    final widthFactor = 1 / _options.length;

    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Stack(
        children: [
          // Animated sliding pill
          Directionality(
            textDirection: TextDirection.ltr,
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              alignment: _pillAlignment(),
              child: FractionallySizedBox(
                widthFactor: widthFactor,
                child: Container(
                  margin: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(11),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.10),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Tappable labels
          Directionality(
            textDirection: TextDirection.ltr,
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: cashDisabled ? null : () => onChanged('CASH'),
                    child: _PaymentOption(
                      icon: Icons.payments_outlined,
                      label: l10n.codN,
                      selected: paymentMethod == 'CASH',
                      disabled: cashDisabled,
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onChanged('WALLET'),
                    child: _PaymentOption(
                      icon: Icons.account_balance_wallet_outlined,
                      label: l10n.wallet,
                      selected: paymentMethod == 'WALLET',
                    ),
                  ),
                ),
                if (cardEnabled)
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onChanged('CARD'),
                      child: _PaymentOption(
                        icon: Icons.credit_card_outlined,
                        label: l10n.onlinePayment,
                        selected: paymentMethod == 'CARD',
                      ),
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

class _PaymentOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final bool disabled;

  const _PaymentOption({
    required this.icon,
    required this.label,
    required this.selected,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = disabled
        ? Colors.grey.shade300
        : selected
            ? AppColors.kSecondaryColor
            : Colors.grey.shade400;

    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Icon(
              icon,
              key: ValueKey('$icon-$selected'),
              size: 18,
              color: color,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            textAlign: TextAlign.center,
            label,
            style: selected && !disabled
                ? AppTextStyles.bold14.copyWith(fontSize: 10)
                : AppTextStyles.regular14.copyWith(color: color, fontSize: 10),
          ),
        ],
      ),
    );
  }
}
