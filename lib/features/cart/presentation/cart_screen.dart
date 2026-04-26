import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:go_router/go_router.dart';
import 'package:tawreedat_go/core/widgets/banners.dart';
import 'package:tawreedat_go/features/home/layout/manager/home_cubit.dart';

import '../../../core/style/app_colors.dart';
import '../../../core/style/text_styles.dart';
import '../../../core/widgets/circel_back_cutton.dart';
import '../../../core/widgets/highlighter_widget.dart';
import '../../../l10n/app_localizations.dart';
import '../../addresses/presentation/default_address_chip.dart';
import '../../auth/manager/profile_cubit.dart';
import '../../auth/manager/profile_states.dart';
import '../../coupons/manager/coupons_cubit.dart';
import '../../orders/manager/order_cubit.dart';
import '../../orders/manager/order_states.dart';
import '../../orders/presentation/widgets/sheets/create_order_sheet/coupon_section.dart';
import '../../orders/presentation/widgets/sheets/create_order_sheet/insufficient_balance_sheet.dart';
import '../../wallet/manager/wallet_cubit.dart';
import '../../wallet/manager/wallet_state.dart';
import '../data/models/order_preview_model.dart';
import '../manager/cart_cubit.dart';
import '../manager/cart_state.dart';
import 'cart_item_tile.dart';

// ── Price formatting helper ───────────────────────────────────────────────────
// Centralised so every monetary value in this file shows exactly 2 decimals.
String _fmt(double v) => v.toStringAsFixed(2);

// ── Safe numeric coercions ────────────────────────────────────────────────────
// The summary DTO fields are typed as `dynamic` (or occasionally come back as
// int/String from the backend serialiser).  These helpers normalise all three
// variants without ever throwing a runtime cast error.
double _toDouble(dynamic v) =>
    v == null ? 0.0 : double.tryParse(v.toString()) ?? 0.0;

bool _toBool(dynamic v) {
  if (v == null) return false;
  if (v is bool) return v;
  return v.toString().toLowerCase() == 'true';
}

double? _computeDeliveryFeeDiscount(CouponValid coupon, double rawFee) {
  if (!coupon.isDeliveryFeeDiscount) return null;
  final value = coupon.discountValueInEgp;
  if (value == null) return null;
  if (coupon.isPercentDiscount) {
    return (rawFee * value / 100).clamp(0.0, rawFee);
  }
  if (coupon.isFixedDiscount) {
    return value.clamp(0.0, rawFee);
  }
  return null;
}

// ── Helper: compute coupon discount against a cart subtotal ───────────────────
double? _computeCouponCartDiscount(CouponValid coupon, double subtotal) {
  if (coupon.isWalletCredit) return null;
  if (coupon.isDeliveryFeeDiscount) return null;

  final value = coupon.discountValueInEgp;
  if (value == null) return null;

  if (coupon.isPercentDiscount) {
    return (subtotal * value / 100).clamp(0.0, subtotal);
  }
  if (coupon.isFixedDiscount) {
    return value.clamp(0.0, subtotal);
  }
  return null;
}

// ─────────────────────────────────────────────────────────────────────────────

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  double _walletBalance = 0.0;
  late final CouponCubit _couponCubit = CouponCubit()..loadCoupons();


  // ── Payment & coupon state ─────────────────────────────────────────────────
  String _paymentMethod = 'CASH';
  CouponValid? _appliedCoupon;
  bool _couponValidating = false;
  final _couponController = TextEditingController();
  final FocusNode _couponFocus = FocusNode();

  // ── Required amount for wallet validation ──────────────────────────────────
  // All intermediate values are doubles; only the final wallet comparison
  // rounds up via .ceil() to avoid false "insufficient balance" rejections.
  double _computeRequiredAmount(CartLoaded state) {
    final summary = state.data.summary;
    final originalTotal = _toDouble(summary.originalTotal);
    final totalDiscount =
    _toBool(summary.hasDiscount) ? _toDouble(summary.totalDiscount) : 0.0;
    final priceBeforeCoupon = originalTotal - totalDiscount;
    final couponDiscount = _appliedCoupon != null
        ? _computeCouponCartDiscount(_appliedCoupon!, priceBeforeCoupon)
        : null;
    final finalTotal = priceBeforeCoupon - (couponDiscount ?? 0.0);
    final preview = state.preview;
    return preview != null
        ? finalTotal +
        preview.deliveryFee.ceilToDouble() +
        preview.vatAmount.ceilToDouble()
        : finalTotal;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      context.read<CartCubit>().fetchCart();
      context.read<WalletCubit>().fetchWalletData();

      if (_couponController.text.isNotEmpty) return;

      final profileState = context.read<ProfileCubit>().state;
      if (profileState is ProfileLoaded &&
          profileState.profile.roleId == 4) return;

      // ── Use the local cubit directly — no context.read needed ──────────
      final code = await _couponCubit.getOrFetchFirstOrderCoupon();

      if (!mounted || code == null || code.isEmpty) return;
      _couponController.text = code;
      _validateCoupon();
    });
  }
  @override
  void dispose() {
    _couponCubit.close();
    _couponController.dispose();
    _couponFocus.dispose();
    super.dispose();
  }

  CartCubit get _cubit => context.read<CartCubit>();

  // ── Coupon helpers ─────────────────────────────────────────────────────────

  void _validateCoupon() {
    final code = _couponController.text.trim();
    if (code.isEmpty) return;
    setState(() {
      _couponValidating = true;
      _appliedCoupon = null;
    });
    context.read<OrderCubit>().validateCoupon(code);
  }

  void _removeCoupon() {
    setState(() {
      _appliedCoupon = null;
      _couponController.clear();
    });
  }

  // ── Checkout ───────────────────────────────────────────────────────────────

  Future<void> _checkout() async {
    if (_paymentMethod == 'WALLET') {
      final cartState = context.read<CartCubit>().state;
      if (cartState is CartLoaded) {
        final required = _computeRequiredAmount(cartState);
        if (_walletBalance < required) {
          _showInsufficientBalanceDialog(
            required: required,
            balance: _walletBalance,
          );
          return;
        }
      }
    }
    await context.read<OrderCubit>().createCatalogOrder(
      paymentMethod: _paymentMethod,
      couponCode: _appliedCoupon?.code,
    );
  }

  void _showInsufficientBalanceDialog({
    required double required,
    required double balance,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final shortfall = (required - balance).ceilToDouble();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) => InsufficientBalanceSheet(
        currentBalance: balance,
        requiredAmount: required,
        shortfall: shortfall,
        isShopping: true,
        l10n: l10n,
        onTopUp: () async {
          Navigator.pop(sheetCtx);
          await context.push('/wallet/topup');
        },
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return BlocProvider.value(
  value: _couponCubit,
  child: BlocListener<WalletCubit, WalletState>(
      listenWhen: (_, curr) => curr is WalletLoaded,
      listener: (context, state) {
        if (state is WalletLoaded) {
          setState(() => _walletBalance = state.walletData.wallet.balance);
        }
      },
      child: BlocListener<OrderCubit, OrderState>(
        listener: (context, state) {
          if (state is CouponValidating) {
            if (!_couponValidating) setState(() => _couponValidating = true);
          } else if (state is CouponRedeemed) {
            setState(() {
              _couponValidating = false;
              if (state.coupon != null) _appliedCoupon = state.coupon;
            });
            Fluttertoast.showToast(
              msg: l10n.couponRedeemed,
              toastLength: Toast.LENGTH_SHORT,
              gravity: ToastGravity.BOTTOM,
              backgroundColor: Colors.green.shade700,
            );
          } else if (state is CouponInvalid) {
            setState(() => _couponValidating = false);
            Fluttertoast.showToast(
              msg: state.message,
              toastLength: Toast.LENGTH_LONG,
              gravity: ToastGravity.BOTTOM,
              backgroundColor: Colors.red,
              textColor: Colors.white,
            );
          } else if (state is CouponRedeemError) {
            setState(() => _couponValidating = false);
            Fluttertoast.showToast(
              msg: state.message,
              toastLength: Toast.LENGTH_LONG,
              gravity: ToastGravity.BOTTOM,
              backgroundColor: Colors.orange,
              textColor: Colors.white,
            );
          } else if (state is OrderSuccess) {
            if (mounted) {
              FocusScope.of(context).unfocus();
              context.go('/mainHome', extra: GoToTab(HomeCubit.ordersTabIndex));
            }
            context.read<CartCubit>().fetchCart();
            showSuccessBanner(
              context,
              '${l10n.created}: ${state.order.orderNumber}',
            );
          } else if (state is OrderError) {
            Fluttertoast.showToast(
              msg: state.message,
              toastLength: Toast.LENGTH_LONG,
              gravity: ToastGravity.BOTTOM,
              backgroundColor: Colors.red,
              textColor: Colors.white,
            );
          }
        },
        child: BlocConsumer<CartCubit, CartState>(
          listenWhen: (_, curr) => curr is CartError,
          listener: (context, state) {
            if (state is CartError) {
              showErrorBanner(context, state.message);
            }
          },
          builder: (context, state) {
            return Scaffold(
              appBar: _buildAppBar(context, state),
              body: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: switch (state) {
                  CartInitial() ||
                  CartLoading() =>
                  const _LoadingView(key: ValueKey('loading')),
                  CartError(:final message) => _ErrorView(
                    key: const ValueKey('error'),
                    message: message,
                    onRetry: _cubit.fetchCart,
                  ),
                  CartLoaded(:final data) when data.cartItems.isEmpty =>
                  const _EmptyView(key: ValueKey('empty')),
                  CartLoaded() => _buildLoaded(context, state as CartLoaded),
                },
              ),
            );
          },
        ),
      ),
    ),
);
  }

  AppBar _buildAppBar(BuildContext context, CartState state) {
    final l10n = AppLocalizations.of(context)!;
    final count = state is CartLoaded ? state.data.summary.totalItems : 0;

    return AppBar(
      leading: CircleBackButton(),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.cart),
          if (count > 0) ...[
            const SizedBox(width: 8),
            _CountBadge(count: count),
          ],
        ],
      ),
      actions: [
        if (state is CartLoaded && state.data.cartItems.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: CircleAvatar(
              radius: 20,
              backgroundColor: Colors.grey.shade200,
              child: IconButton(
                icon: Icon(
                  Icons.delete_sweep_outlined,
                  color: Colors.grey.shade700,
                ),
                tooltip: l10n.clearCart,
                onPressed: () => _confirmClear(context),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildLoaded(BuildContext context, CartLoaded state) {
    final items = state.data.cartItems;
    final summary = state.data.summary;
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final screenWidth = MediaQuery.of(context).size.width;
    final hPad = screenWidth < 360 ? 14.0 : 20.0;

    return Column(
      key: ValueKey('loaded_${items.length}'),
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(hPad, 10, hPad, 0),
          child: const Align(
            alignment: AlignmentDirectional.centerStart,
            child: DefaultAddressChip(),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(top: 12, bottom: 8),
            itemCount: items.length,
            itemBuilder: (_, index) {
              final item = items[index];
              return CartItemTile(
                key: ValueKey(item.id),
                item: item,
                isBusy: state.isItemBusy(item.spId),
                onIncrement: () => _handleIncrement(context, item.spId),
                onDecrement: () => _handleDecrement(context, item.spId),
                onRemove: () => _cubit.removeItem(item.spId),
              );
            },
          ),
        ),
        _CartSummaryBar(
          summary: summary,
          preview: state.preview,
          hPad: hPad,
          bottomPadding: bottomPadding,
          theme: theme,
          l10n: l10n,
          paymentMethod: _paymentMethod,
          onPaymentMethodChanged: (m) => setState(() => _paymentMethod = m),
          couponController: _couponController,
          couponFocus: _couponFocus,
          appliedCoupon: _appliedCoupon,
          couponValidating: _couponValidating,
          onValidateCoupon: _validateCoupon,
          onRemoveCoupon: _removeCoupon,
          onCheckout: _checkout,
        ),
      ],
    );
  }

  // ── Action handlers ────────────────────────────────────────────────────────

  void _handleIncrement(BuildContext context, int spId) async {
    try {
      await _cubit.incrementItem(spId);
    } catch (_) {
      if (context.mounted) _showUpdateError(context);
    }
  }

  void _handleDecrement(BuildContext context, int spId) async {
    try {
      await _cubit.decrementItem(spId);
    } catch (_) {
      if (context.mounted) _showUpdateError(context);
    }
  }

  void _showUpdateError(BuildContext context) {
    showErrorBanner(
      context,
      AppLocalizations.of(context)!.updateQuantityFailed,
    );
  }

  Future<void> _confirmClear(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.clearCart),
        content: Text(l10n.clearCartConfirmation),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.emptyCart),
          ),
        ],
      ),
    );
    if (confirmed == true) await _cubit.clearCart();
  }
}

// ── Summary bar ───────────────────────────────────────────────────────────────

class _CartSummaryBar extends StatelessWidget {
  final dynamic summary;
  final double hPad;
  final double bottomPadding;
  final ThemeData theme;
  final AppLocalizations l10n;

  final String paymentMethod;
  final ValueChanged<String> onPaymentMethodChanged;

  final TextEditingController couponController;
  final FocusNode couponFocus;
  final CouponValid? appliedCoupon;
  final bool couponValidating;
  final VoidCallback onValidateCoupon;
  final VoidCallback onRemoveCoupon;

  final VoidCallback onCheckout;
  final OrderPreviewModel? preview;

  const _CartSummaryBar({
    required this.preview,
    required this.summary,
    required this.hPad,
    required this.bottomPadding,
    required this.theme,
    required this.l10n,
    required this.paymentMethod,
    required this.onPaymentMethodChanged,
    required this.couponController,
    required this.couponFocus,
    required this.appliedCoupon,
    required this.couponValidating,
    required this.onValidateCoupon,
    required this.onRemoveCoupon,
    required this.onCheckout,
  });

  @override
  Widget build(BuildContext context) {
    // ── Safe coercions — no hard `as double` casts ─────────────────────────
    // Previously `(summary.originalTotal??0 as double)` only cast the literal
    // `0` (the fallback) and threw when the actual value was an int or String.
    final bool hasDiscount = _toBool(summary.hasDiscount);
    final double originalTotal = _toDouble(summary.originalTotal);
    final double totalDiscount =
    hasDiscount ? _toDouble(summary.totalDiscount) : 0.0;
    final double priceBeforeCoupon = originalTotal - totalDiscount;

    final double? couponDiscount = appliedCoupon != null
        ? _computeCouponCartDiscount(appliedCoupon!, priceBeforeCoupon)
        : null;

    final double finalTotal = priceBeforeCoupon - (couponDiscount ?? 0.0);

    // Delivery / VAT: ceil to avoid showing fractions for fee lines.
    final double rawDeliveryFee = preview?.deliveryFee ?? 0.0;
    final double? deliveryFeeRounded = preview != null ? double.parse(rawDeliveryFee.toStringAsFixed(2)): null;
    final double? vatAmountRounded = preview?.vatAmount;

    final double? deliveryFeeDiscount = (appliedCoupon != null && preview != null)
        ? _computeDeliveryFeeDiscount(appliedCoupon!, rawDeliveryFee)
        : null;
    final double? discountedDeliveryFee =
    deliveryFeeDiscount != null
        ? (rawDeliveryFee - deliveryFeeDiscount)
        .clamp(0.0, rawDeliveryFee)
        : null;

    final double effectiveDeliveryFee =
        discountedDeliveryFee ?? deliveryFeeRounded ?? 0.0;
    final double? grandTotal = preview != null
        ? finalTotal + effectiveDeliveryFee + vatAmountRounded!
        : null;

    return Container(
      padding: EdgeInsets.fromLTRB(hPad, 16, hPad, 16 + bottomPadding),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Coupon section ──────────────────────────────────────────────
          CouponSection(
            couponController: couponController,
            couponFocus: couponFocus,
            appliedCoupon: appliedCoupon,
            couponValidating: couponValidating,
            onValidate: onValidateCoupon,
            onRemove: onRemoveCoupon,
          ),

          const SizedBox(height: 12),

          // ── Payment method toggle ───────────────────────────────────────
          _PaymentToggle(
            paymentMethod: paymentMethod,
            onChanged: onPaymentMethodChanged,
            l10n: l10n,
          ),

          const Divider(height: 24),

          // ── Item counts ─────────────────────────────────────────────────
          _SummaryRow(label: l10n.numberOfItems, value: '${summary.itemCount}'),
          const SizedBox(height: 4),
          _SummaryRow(
            label: l10n.totalQuantity,
            value: '${summary.totalItems}',
          ),

          const Divider(height: 20),

          // ── Pricing breakdown ──────────────────────────────────────────
          _SummaryRow(
            label: l10n.cartTotal,
            // Fixed: was '$originalTotal' which printed "1000.0"; now "1000.00"
            value: '${_fmt(originalTotal)} ${l10n.egp}',
          ),

          // Backend sale discount
          if (hasDiscount) ...[
            const SizedBox(height: 6),
            _DiscountRow(
              discount: totalDiscount,
              egp: l10n.egp,
              theme: theme,
            ),
          ],

          // Coupon discount — only rendered for order-total coupons.
          if (couponDiscount != null) ...[
            const SizedBox(height: 6),
            _CouponDiscountRow(
              coupon: appliedCoupon!,
              discount: couponDiscount,
              egp: l10n.egp,
              theme: theme,
            ),
          ],

          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: DashedDivider(color: theme.dividerColor),
          ),

          // Products subtotal (only shown when different from original)
          if (finalTotal != originalTotal)
            _SummaryRow(
              label: l10n.subtotal,
              value: '${_fmt(finalTotal)} ${l10n.egp}',
            ),

          // Delivery fee + VAT — only shown when preview is available
          if (preview != null) ...[
            const SizedBox(height: 6),
            _DeliveryFeeRow(
              original: deliveryFeeRounded!,
              discounted: discountedDeliveryFee,
              egp: l10n.egp,
              label: '${l10n.deliveryFee} ${l10n.estimate}',
              theme: theme,
            ),
            const SizedBox(height: 6),
            _SummaryRow(
              label: l10n.vat,
              value: '$vatAmountRounded ${l10n.egp}',
            ),
          ],

          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: DashedDivider(color: theme.dividerColor),
          ),

          // Grand total
          _SummaryRow(
            label: l10n.subtotal,
            value: grandTotal != null
                ? '${_fmt(grandTotal)} ${l10n.egp}'
                : '${_fmt(finalTotal)} ${l10n.egp}',
            isTotal: true,
          ),

          const SizedBox(height: 16),

          // ── Checkout button ─────────────────────────────────────────────
          BlocBuilder<OrderCubit, OrderState>(
            buildWhen: (_, s) =>
            s is OrderOperationLoading ||
                s is OrderSuccess ||
                s is OrderError ||
                s is OrdersLoaded,
            builder: (context, orderState) {
              final isLoading = orderState is OrderOperationLoading;
              return FilledButton.icon(
                onPressed: isLoading ? null : onCheckout,
                icon: isLoading
                    ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
                    : const Icon(Icons.check_circle_outline_rounded),
                label: Text(
                  l10n.proceedToCheckout,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
class _DeliveryFeeRow extends StatelessWidget {
  final double original;
  final double? discounted;
  final String egp;
  final String label;
  final ThemeData theme;

  const _DeliveryFeeRow({
    required this.original,
    required this.discounted,
    required this.egp,
    required this.label,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final hasDiscount = discounted != null && discounted != original;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: Colors.grey.shade600,
          ),
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (child, anim) =>
              FadeTransition(opacity: anim, child: child),
          child: hasDiscount
              ? Row(
            key: ValueKey('discounted_$discounted'),
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$original $egp',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.red.shade400,
                  decoration: TextDecoration.lineThrough,
                  decorationColor: Colors.red.shade400,
                ),
              ),
              const SizedBox(width: 6),
              HighlighterWidget(
                child: Text(
                  '$discounted $egp',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          )
              : Text(
            key: ValueKey('normal_$original'),
            '$original $egp',
            style: theme.textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}

// ── Payment toggle ────────────────────────────────────────────────────────────

class _PaymentToggle extends StatelessWidget {
  final String paymentMethod;
  final ValueChanged<String> onChanged;
  final AppLocalizations l10n;

  const _PaymentToggle({
    required this.paymentMethod,
    required this.onChanged,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final isCash = paymentMethod == 'CASH';

    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Stack(
        children: [
          Directionality(
            textDirection: TextDirection.ltr,
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              alignment: isCash ? Alignment.centerLeft : Alignment.centerRight,
              child: FractionallySizedBox(
                widthFactor: 0.5,
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
          Directionality(
            textDirection: TextDirection.ltr,
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onChanged('CASH'),
                    child: _PaymentOption(
                      icon: Icons.payments_outlined,
                      label: l10n.cod,
                      selected: isCash,
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
                      selected: !isCash,
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

  const _PaymentOption({
    required this.icon,
    required this.label,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
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
              color: selected
                  ? AppColors.kSecondaryColor
                  : Colors.grey.shade400,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: selected
                ? AppTextStyles.bold14.copyWith(fontSize: 12)
                : AppTextStyles.regular14.copyWith(
              color: Colors.grey,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Backend sale discount row ─────────────────────────────────────────────────

class _DiscountRow extends StatelessWidget {
  final double discount;
  final String egp;
  final ThemeData theme;

  const _DiscountRow({
    required this.discount,
    required this.egp,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.percent_rounded, size: 14),
            const SizedBox(width: 4),
            Text(
              AppLocalizations.of(context)!.discount,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (child, anim) =>
              FadeTransition(opacity: anim, child: child),
          child: HighlighterWidget(
            child: Text(
              '${_fmt(discount)} $egp',
              style: const TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Coupon discount row ───────────────────────────────────────────────────────

class _CouponDiscountRow extends StatelessWidget {
  final CouponValid coupon;
  final double discount; // changed from int — keeps the cents
  final String egp;
  final ThemeData theme;

  const _CouponDiscountRow({
    required this.coupon,
    required this.discount,
    required this.egp,
    required this.theme,
  });

  String _label(AppLocalizations l10n) {
    final value = coupon.discountValueInEgp;
    if (coupon.isPercentDiscount && value != null) {
      return '${value.toInt()}% ${l10n.offYourOrder}';
    }
    if (coupon.isFixedDiscount && value != null) {
      return '${_fmt(value)} $egp ${l10n.offYourOrder}';
    }
    return coupon.title;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.local_offer_outlined, size: 14),
            const SizedBox(width: 4),
            Text(
              _label(l10n),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (child, anim) =>
              FadeTransition(opacity: anim, child: child),
          child: HighlighterWidget(
            key: ValueKey(discount),
            child: Text(
              '${_fmt(discount)} $egp',
              style: const TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Dashed divider ────────────────────────────────────────────────────────────

class DashedDivider extends StatelessWidget {
  final Color color;

  const DashedDivider({super.key, required this.color});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, constraints) {
        const dashWidth = 6.0;
        const gapWidth = 4.0;
        final count = (constraints.maxWidth / (dashWidth + gapWidth)).floor();
        return Row(
          children: List.generate(
            count,
                (_) => Container(
              width: dashWidth,
              height: 1,
              margin: const EdgeInsets.only(right: gapWidth),
              color: color,
            ),
          ),
        );
      },
    );
  }
}

// ── Summary row ───────────────────────────────────────────────────────────────

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isTotal;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.isTotal = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: isTotal
              ? theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          )
              : theme.textTheme.bodyMedium?.copyWith(
            color: Colors.grey.shade600,
          ),
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (child, anim) =>
              FadeTransition(opacity: anim, child: child),
          child: Text(
            value,
            key: ValueKey(value),
            style: isTotal
                ? theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
            )
                : theme.textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}

// ── Count badge ───────────────────────────────────────────────────────────────

class _CountBadge extends StatelessWidget {
  final int count;

  const _CountBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      transitionBuilder: (child, anim) =>
          ScaleTransition(scale: anim, child: child),
      child: Container(
        key: ValueKey(count),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          '$count',
          style: TextStyle(
            color: theme.colorScheme.onPrimary,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

// ── Loading / empty / error states ────────────────────────────────────────────

class _LoadingView extends StatelessWidget {
  const _LoadingView({super.key});

  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator());
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.shopping_cart_outlined,
              size: 80,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.cartIsEmpty,
              style: theme.textTheme.titleMedium?.copyWith(
                color: Colors.grey.shade500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.startAddingProducts,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.grey.shade400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(l10n.retry),
            ),
          ],
        ),
      ),
    );
  }
}