import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:go_router/go_router.dart';
import 'package:tawreedat_go/core/widgets/banners.dart';
import 'package:tawreedat_go/features/cart/presentation/widgets/cart_item_tile.dart';
import 'package:tawreedat_go/features/cart/presentation/widgets/cart_price_helpers.dart';
import 'package:tawreedat_go/features/home/layout/manager/home_cubit.dart';

import '../../../core/widgets/circel_back_cutton.dart';
import '../../../l10n/app_localizations.dart';
import '../../addresses/manager/address_cubit.dart';
import '../../addresses/manager/address_states.dart';
import '../../addresses/presentation/default_address_chip.dart';
import '../../auth/manager/profile_cubit.dart';
import '../../auth/manager/profile_states.dart';
import '../../coupons/manager/coupons_cubit.dart';
import '../../orders/manager/order_cubit.dart';
import '../../orders/manager/order_states.dart';
import '../../orders/presentation/widgets/sheets/create_order_sheet/insufficient_balance_sheet.dart';
import '../../wallet/manager/wallet_cubit.dart';
import '../../wallet/manager/wallet_state.dart';
import '../manager/cart_cubit.dart';
import '../manager/cart_state.dart';
import 'widgets/cart_count_badge.dart';
import 'widgets/cart_state_views.dart';
import 'widgets/cart_summary_bar.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  double _walletBalance = 0.0;
  late final CouponCubit _couponCubit = CouponCubit()..loadCoupons();

  int? _currentDefaultAddressId;

  String _paymentMethod = 'CASH';
  CouponValid? _appliedCoupon;
  bool _couponValidating = false;
  final _couponController = TextEditingController();
  final FocusNode _couponFocus = FocusNode();

  double _computeRequiredAmount(CartLoaded state) {
    final summary = state.data.summary;
    final originalTotal = toDouble(summary.originalTotal);
    final totalDiscount = toBool(summary.hasDiscount) ? toDouble(summary.totalDiscount) : 0.0;
    final priceBeforeCoupon = originalTotal - totalDiscount;
    final couponDiscount = _appliedCoupon != null
        ? computeCouponCartDiscount(_appliedCoupon!, priceBeforeCoupon)
        : null;
    final finalTotal = priceBeforeCoupon - (couponDiscount ?? 0.0);
    final preview = state.preview;
    return preview != null
        ? finalTotal + preview.deliveryFee.ceilToDouble() + preview.vatAmount.ceilToDouble()
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
      if (profileState is ProfileLoaded && profileState.profile.roleId == 4) return;

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

  Future<void> _onRefresh() async {
    context.read<CartCubit>().fetchCart();
    context.read<WalletCubit>().fetchWalletData();
    await Future.any([
      context.read<CartCubit>().stream.firstWhere((s) => s is CartLoaded || s is CartError),
      Future.delayed(const Duration(seconds: 4)),
    ]);
  }

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

  Future<void> _checkout() async {
    if (_paymentMethod == 'WALLET') {
      final cartState = context.read<CartCubit>().state;
      if (cartState is CartLoaded) {
        final required = _computeRequiredAmount(cartState);
        if (_walletBalance < required) {
          _showInsufficientBalanceDialog(required: required, balance: _walletBalance);
          return;
        }
      }
    }
    await context.read<OrderCubit>().createCatalogOrder(
      paymentMethod: _paymentMethod,
      couponCode: _appliedCoupon?.code,
    );
  }

  void _showInsufficientBalanceDialog({required double required, required double balance}) {
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return BlocProvider.value(
      value: _couponCubit,
      child: BlocListener<AddressCubit, AddressState>(
        listenWhen: (_, curr) => curr is AddressesLoaded,
        listener: (context, state) {
          if (state is AddressesLoaded) {
            final newDefaultId = state.addresses.where((a) => a.isDefault).firstOrNull?.id;
            if (newDefaultId != _currentDefaultAddressId) {
              _currentDefaultAddressId = newDefaultId;
              if (newDefaultId != null) _cubit.fetchCart();
            }
          }
        },
        child: BlocListener<WalletCubit, WalletState>(
          listenWhen: (_, curr) => curr is WalletLoaded,
          listener: (context, state) {
            if (state is WalletLoaded) {
              setState(() => _walletBalance = state.walletData.wallet.balance);
            }
          },
          child: BlocListener<OrderCubit, OrderState>(
            listener: (context, state) => _handleOrderState(context, state, l10n),
            child: BlocConsumer<CartCubit, CartState>(
              listenWhen: (_, curr) => curr is CartError,
              listener: (context, state) {
                if (state is CartError) showErrorBanner(context, state.message);
              },
              builder: (context, state) {
                return Scaffold(
                  appBar: _buildAppBar(context, state),
                  body: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: switch (state) {
                      CartInitial() || CartLoading() =>
                      const CartLoadingView(key: ValueKey('loading')),
                      CartError(:final message) => CartErrorView(
                        key: const ValueKey('error'),
                        message: message,
                        onRetry: _cubit.fetchCart,
                      ),
                      CartLoaded(:final data) when data.cartItems.isEmpty =>
                          _buildEmptyWithRefresh(key: const ValueKey('empty')),
                      CartLoaded() => _buildLoaded(context, state as CartLoaded),
                    },
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  void _handleOrderState(BuildContext context, OrderState state, AppLocalizations l10n) {
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
      showSuccessBanner(context, '${l10n.created}: ${state.order.orderNumber}');
    } else if (state is OrderError) {
      Fluttertoast.showToast(
        msg: state.message,
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
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
            CartCountBadge(count: count),
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
                icon: Icon(Icons.delete_sweep_outlined, color: Colors.grey.shade700),
                tooltip: l10n.clearCart,
                onPressed: () => _confirmClear(context),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyWithRefresh({Key? key}) {
    return RefreshIndicator(
      key: key,
      onRefresh: _onRefresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.6,
          child: const CartEmptyView(),
        ),
      ),
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
          child: RefreshIndicator(
            onRefresh: _onRefresh,
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
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
        ),
        CartSummaryBar(
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

  void _handleIncrement(BuildContext context, int spId) async {
    try {
      await _cubit.incrementItem(spId);
    } catch (_) {
      if (context.mounted) showErrorBanner(context, AppLocalizations.of(context)!.updateQuantityFailed);
    }
  }

  void _handleDecrement(BuildContext context, int spId) async {
    try {
      await _cubit.decrementItem(spId);
    } catch (_) {
      if (context.mounted) showErrorBanner(context, AppLocalizations.of(context)!.updateQuantityFailed);
    }
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