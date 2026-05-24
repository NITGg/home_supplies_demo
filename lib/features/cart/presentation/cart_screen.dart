import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:go_router/go_router.dart';
import 'package:tawreedat_go/core/widgets/banners.dart';
import 'package:tawreedat_go/features/cart/presentation/slot_picker_sheet.dart';
import 'package:tawreedat_go/features/cart/presentation/widgets/cart_item_tile.dart';
import 'package:tawreedat_go/features/cart/presentation/widgets/cart_price_helpers.dart';
import 'package:tawreedat_go/features/home/layout/manager/home_cubit.dart';

import '../../../core/style/app_colors.dart';
import '../../../core/utils/app_dynamic_settings.dart';
import '../../../core/widgets/circel_back_button.dart';
import '../../../l10n/app_localizations.dart';
import '../../addresses/manager/address_cubit.dart';
import '../../addresses/manager/address_states.dart';
import '../../addresses/presentation/default_address_chip.dart';
import '../../auth/manager/profile_cubit.dart';
import '../../auth/manager/profile_states.dart';
import '../../coupons/manager/coupons_cubit.dart';
import '../../home/layout/manager/guest_cubit.dart';
import '../../orders/manager/order_cubit.dart';
import '../../orders/manager/order_states.dart';
import '../../orders/presentation/widgets/sheets/create_order_sheet/insufficient_balance_sheet.dart';
import '../../search/presentation/search_dialog.dart';
import '../../wallet/manager/wallet_cubit.dart';
import '../../wallet/manager/wallet_state.dart';
import '../data/models/slot_model.dart';
import '../data/repo/slot_repo.dart';
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

  // ── Schedule ───────────────────────────────────────────────────────────────
  bool _isScheduled = false;
  DateTime? _scheduleAt;

  /// The slot the user selected from the picker (null if none yet or ASAP).
  SlotModel? _selectedSlot;
  CouponValid? _appliedCoupon;
  bool _couponValidating = false;
  final _couponController = TextEditingController();
  final FocusNode _couponFocus = FocusNode();

  // false = pill only visible; true = full summary visible
  bool _summaryExpanded = false;
  bool _pillVisible = true;
  late final ScrollController _scrollController = ScrollController();
  double _lastScrollOffset = 0;

  double _codLimit() {
    return (double.tryParse(AppSettings.customer_catalog_cod_limit ?? '0') ??
            0) /
        100;
  }

  bool _isOverCodLimit(CartLoaded state) {
    return _computeDisplayTotal(state) > _codLimit();
  }

  void _toggleSummary() {
    _couponFocus.unfocus();
    setState(() => _summaryExpanded = !_summaryExpanded);
  }

  // ── Price helpers ──────────────────────────────────────────────────────────

  double _priceBeforeCoupon(CartLoaded state) {
    final summary = state.data.summary;
    final originalTotal = toDouble(summary.originalTotal);
    final totalDiscount = toBool(summary.hasDiscount)
        ? toDouble(summary.totalDiscount)
        : 0.0;
    return originalTotal - totalDiscount;
  }

  double _computeRequiredAmount(CartLoaded state) {
    final priceBeforeCoupon = _priceBeforeCoupon(state);
    final couponDiscount = _appliedCoupon != null
        ? computeCouponCartDiscount(_appliedCoupon!, priceBeforeCoupon)
        : null;
    final finalTotal = priceBeforeCoupon - (couponDiscount ?? 0.0);
    final preview = state.preview;
    if (preview == null) return finalTotal;

    return finalTotal +
        preview.totalFee.ceilToDouble() +
        preview.vatAmount.ceilToDouble() -
        preview.discountAmount.ceilToDouble();
  }

  double _computeDisplayTotal(CartLoaded state) {
    final priceBeforeCoupon = _priceBeforeCoupon(state);
    final couponDiscount = _appliedCoupon != null
        ? computeCouponCartDiscount(_appliedCoupon!, priceBeforeCoupon)
        : null;
    final subtotal = priceBeforeCoupon - (couponDiscount ?? 0.0);
    final preview = state.preview;
    if (preview == null) return subtotal;
    return subtotal;
  }

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  void _onScroll() {
    final offset = _scrollController.offset;
    final delta = offset - _lastScrollOffset;
    _lastScrollOffset = offset;

    if (delta > 4 && _pillVisible) {
      setState(() {
        _pillVisible = false;
        _summaryExpanded = false;
      });
    } else if (delta < -4 && !_pillVisible) {
      setState(() => _pillVisible = true);
    }
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);

    context.read<CartCubit>().reset();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      context.read<CartCubit>().fetchCart();
      context.read<WalletCubit>().fetchWalletData();

      if (_couponController.text.isNotEmpty) return;

      final profileState = context.read<ProfileCubit>().state;
      if (profileState is ProfileLoaded && profileState.profile.roleId == 4) {
        return;
      }

      final code = await _couponCubit.getOrFetchFirstOrderCoupon();
      if (!mounted || code == null || code.isEmpty) return;
      _couponController.text = code;
      _validateCoupon();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _couponCubit.close();
    _couponController.dispose();
    _couponFocus.dispose();
    super.dispose();
  }

  CartCubit get _cubit => context.read<CartCubit>();

  Future<void> _onRefresh() async {
    _cubit.fetchCart();
    context.read<WalletCubit>().fetchWalletData();
    await Future.any([
      _cubit.stream.firstWhere((s) => s is CartLoaded || s is CartError),
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
    _cubit.refreshPreview();
  }

  Future<void> _checkout() async {
    if (_isScheduled && _scheduleAt == null) return;

    if (_paymentMethod == 'WALLET') {
      final cartState = _cubit.state;
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
      scheduleAt: _isScheduled ? _scheduleAt : null,
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

  // ── Schedule / slot helpers ────────────────────────────────────────────────

  /// Opens the slot picker sheet. On confirmation sets [_scheduleAt] and
  /// [_selectedSlot]. Falls back to the free date/time picker if no
  /// [_storeAddressId] is available.
  /// Opens the slot picker sheet.
  ///
  /// If the network call inside the sheet fails, the sheet silently dismisses
  /// itself and [_pickScheduleDateTimeFallback] is invoked so the user can
  /// still pick a date/time manually.
  Future<void> _pickSlot() async {
    final result = await showSlotPickerSheet(
      context: context,
      initialSelection: _scheduleAt,
      initialSlot: _selectedSlot,
      fetchSlots: () => SlotRepository().fetchSlots(),
      onFetchError: _pickScheduleDateTimeFallback, // ← fallback wired here
    );

    if (result != null && mounted) {
      setState(() {
        _scheduleAt = result.dateTime;
        _selectedSlot = result.slot; // null for free windows
      });
    }
  }

  /// Fallback free date/time picker used when no storeAddressId is known.
  Future<void> _pickScheduleDateTimeFallback() async {
    final now = DateTime.now();

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 30)),
    );
    if (pickedDate == null || !mounted) return;

    final isToday =
        pickedDate.year == now.year &&
        pickedDate.month == now.month &&
        pickedDate.day == now.day;
    final initialTime = TimeOfDay.fromDateTime(
      isToday ? now.add(const Duration(minutes: 5)) : pickedDate,
    );

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );
    if (pickedTime == null || !mounted) return;

    final scheduled = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    if (scheduled.isBefore(now)) {
      Fluttertoast.showToast(
        msg: AppLocalizations.of(context)!.pleaseChooseFutureTime,
        gravity: ToastGravity.BOTTOM,
      );
      return;
    }

    setState(() {
      _scheduleAt = scheduled;
      _selectedSlot = null;
    });
  }

  /// Clears the scheduled time and selected slot.
  void _clearSchedule() {
    setState(() {
      _scheduleAt = null;
      _selectedSlot = null;
    });
  }

  String _formatScheduleDate(DateTime dt) => '${dt.day}/${dt.month}/${dt.year}';

  String _formatScheduleTime(DateTime dt) {
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour < 12 ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  Widget _buildScheduleOption({
    required IconData icon,
    required String label,
    required bool selected,
  }) {
    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Icon(
              icon,
              key: ValueKey('$icon-$selected'),
              size: 20,
              color: selected
                  ? AppColors.kSecondaryColor
                  : Colors.grey.shade400,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: selected
                ? TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.kSecondaryColor,
                  )
                : TextStyle(fontSize: 13, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleSection(AppLocalizations l10n) {
    final accent = AppColors.kSecondaryColor;
    final isAsap = !_isScheduled;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── ASAP / Schedule toggle ─────────────────────────────────────────
        Container(
          height: 56,
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
                  alignment: isAsap
                      ? Alignment.centerLeft
                      : Alignment.centerRight,
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
                        onTap: () => setState(() {
                          _isScheduled = false;
                          _clearSchedule();
                        }),
                        child: _buildScheduleOption(
                          icon: Icons.bolt_rounded,
                          label: l10n.asap,
                          selected: isAsap,
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          setState(() => _isScheduled = true);
                          if (_scheduleAt == null) _pickSlot();
                        },
                        child: _buildScheduleOption(
                          icon: Icons.schedule_rounded,
                          label: l10n.scheduleOrder,
                          selected: !isAsap,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // ── Slot / date picker tile ────────────────────────────────────────
        ClipRect(
          child: AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            clipBehavior: Clip.hardEdge,
            child: _isScheduled
                ? Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Picker tile ──────────────────────────────────
                        InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: _pickSlot,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _scheduleAt != null
                                    ? accent.withOpacity(0.4)
                                    : Colors.grey.shade300,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.calendar_today_rounded,
                                  size: 18,
                                  color: _scheduleAt != null
                                      ? accent
                                      : Colors.grey.shade400,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _scheduleAt == null
                                      ? Text(
                                          l10n.tapToChooseDateTime,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey.shade500,
                                          ),
                                        )
                                      : _buildSelectedSlotContent(accent),
                                ),
                                if (_scheduleAt != null)
                                  GestureDetector(
                                    onTap: _clearSchedule,
                                    child: Icon(
                                      Icons.close_rounded,
                                      size: 18,
                                      color: Colors.grey.shade500,
                                    ),
                                  )
                                else
                                  Icon(
                                    Icons.edit_rounded,
                                    size: 16,
                                    color: Colors.grey.shade400,
                                  ),
                              ],
                            ),
                          ),
                        ),

                        // ── Info note ─────────────────────────────────────
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline_rounded,
                                size: 14,
                                color: Colors.grey.shade500,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  l10n.scheduledOrderNote,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // ── Validation error ──────────────────────────────
                        if (_scheduleAt == null) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(
                                Icons.error_outline_rounded,
                                size: 13,
                                color: Colors.red.shade400,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                l10n.pleaseChooseFutureTime,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.red.shade400,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }

  /// The content shown inside the picker tile when a time is selected.
  ///
  /// - If the user picked a slot from the sheet → show the slot window
  ///   (e.g. "08:00 – 14:00") so they know which capacity block they're in.
  /// - If they used the fallback free picker → show raw date + time.
  Widget _buildSelectedSlotContent(Color accent) {
    if (_selectedSlot != null) {
      // Slot-based selection
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _formatScheduleDate(_scheduleAt!),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Icon(Icons.access_time_rounded, size: 13, color: accent),
              const SizedBox(width: 4),
              Text(
                '${_selectedSlot!.timeFrom} – ${_selectedSlot!.timeTo}',
                style: TextStyle(
                  fontSize: 12,
                  color: accent,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      );
    }

    // Fallback: free date/time selection
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _formatScheduleDate(_scheduleAt!),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          _formatScheduleTime(_scheduleAt!),
          style: TextStyle(
            fontSize: 12,
            color: accent,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return BlocBuilder<GuestModeCubit, bool>(
      builder: (context, isGuest) {
        if (isGuest) {
          return Scaffold(
            appBar: AppBar(leading: CircleBackButton()),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.shopping_cart_outlined,
                      size: 72,
                      color: Colors.grey.shade300,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      l10n.cart,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 28),
                    FilledButton.icon(
                      onPressed: () => context.go('/auth/login'),
                      icon: const Icon(Icons.login_rounded),
                      label: Text(l10n.signin),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(200, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return BlocProvider.value(
          value: _couponCubit,
          child: BlocListener<AddressCubit, AddressState>(
            listenWhen: (_, curr) => curr is AddressesLoaded,
            listener: (context, state) {
              if (state is AddressesLoaded) {
                final newDefaultId = state.addresses
                    .where((a) => a.isDefault)
                    .firstOrNull
                    ?.id;
                if (newDefaultId != _currentDefaultAddressId) {
                  _currentDefaultAddressId = newDefaultId;
                  if (newDefaultId != null) _cubit.refreshCart();
                }
              }
            },
            child: BlocListener<WalletCubit, WalletState>(
              listenWhen: (_, curr) => curr is WalletLoaded,
              listener: (context, state) {
                if (state is WalletLoaded) {
                  setState(
                    () => _walletBalance = state.walletData.wallet.balance,
                  );
                }
              },
              child: BlocListener<OrderCubit, OrderState>(
                listener: (context, state) =>
                    _handleOrderState(context, state, l10n),
                child: BlocConsumer<CartCubit, CartState>(
                  listenWhen: (_, curr) => curr is CartError,
                  listener: (context, state) {
                    if (state is CartError) {
                      showErrorBanner(context, state.message);
                    }
                  },
                  buildWhen: (prev, curr) {
                    if (prev is CartLoaded && curr is CartLoaded) {
                      return prev.data != curr.data ||
                          prev.busyItemIds != curr.busyItemIds ||
                          prev.preview != curr.preview;
                    }
                    return true;
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
                            _buildEmptyWithRefresh(
                              key: const ValueKey('empty'),
                            ),
                          CartLoaded() => _buildLoaded(context, state),
                        },
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _handleOrderState(
    BuildContext context,
    OrderState state,
    AppLocalizations l10n,
  ) {
    if (state is CouponValidating) {
      if (!_couponValidating) setState(() => _couponValidating = true);
    } else if (state is CouponRedeemed) {
      setState(() {
        _couponValidating = false;
        if (state.coupon != null) _appliedCoupon = state.coupon;
      });
      if (state.coupon != null) {
        _cubit.refreshPreview(couponCode: state.coupon!.code);
      }
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
      _cubit.refreshCart();
      showSuccessBanner(context, '${l10n.created}: ${state.order.orderNumber}');
    } else if (state is OrderError) {
      // Fluttertoast.showToast(
      //   msg: state.message,
      //   toastLength: Toast.LENGTH_LONG,
      //   gravity: ToastGravity.BOTTOM,
      //   backgroundColor: Colors.red,
      //   textColor: Colors.white,
      // );
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
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(0, 0, 8.0, 0),
          child: CircleAvatar(
            radius: 20,
            backgroundColor: Colors.grey.shade200,
            child: IconButton(
              icon: Icon(Icons.search_rounded, color: Colors.grey.shade700),
              onPressed: () => showSearchDialog(context),
              padding: EdgeInsets.zero,
            ),
          ),
        ),
        if (state is CartLoaded && state.data.cartItems.isNotEmpty)
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(0, 0, 8.0, 0),
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
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final screenWidth = MediaQuery.of(context).size.width;
    final hPad = screenWidth < 360 ? 14.0 : 20.0;
    final displayTotal = _computeDisplayTotal(state);

    // ── COD limit ────────────────────────────────────────────────────────────
    final overCodLimit = _isOverCodLimit(state);
    if (overCodLimit && _paymentMethod == 'CASH') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _paymentMethod == 'CASH') {
          setState(() => _paymentMethod = 'WALLET');
        }
      });
    }

    return Column(
      key: const ValueKey('loaded'),
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(hPad, 10, hPad, 0),
          child: const Align(
            alignment: AlignmentDirectional.centerStart,
            child: DefaultAddressChip(),
          ),
        ),

        // ── Items list ───────────────────────────────────────────────────────
        Expanded(
          child: RefreshIndicator(
            onRefresh: _onRefresh,
            child: ListView.builder(
              controller: _scrollController,
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

        // ── Animated bottom section ──────────────────────────────────────────
        AnimatedSlide(
          offset: _pillVisible ? Offset.zero : const Offset(0, 1),
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeInOut,
          child: AnimatedOpacity(
            opacity: _pillVisible ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Pill ────────────────────────────────────────────────────
                _CheckoutPill(
                  total: displayTotal,
                  expanded: _summaryExpanded,
                  onTap: _toggleSummary,
                ),

                // ── Full summary panel ───────────────────────────────────────
                ClipRect(
                  child: AnimatedAlign(
                    duration: const Duration(milliseconds: 320),
                    curve: Curves.easeInOut,
                    alignment: Alignment.bottomCenter,
                    heightFactor: _summaryExpanded ? 1.0 : 0.0,
                    child: BlocBuilder<CartCubit, CartState>(
                      buildWhen: (prev, curr) {
                        if (prev is CartLoaded && curr is CartLoaded) {
                          return prev.preview != curr.preview ||
                              prev.data.summary != curr.data.summary;
                        }
                        return false;
                      },
                      builder: (context, innerState) {
                        final loadedInner = innerState is CartLoaded
                            ? innerState
                            : state;
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // ── Schedule section ─────────────────────────
                            Container(
                              color: Colors.white,
                              child: Padding(
                                padding: EdgeInsets.fromLTRB(
                                  hPad,
                                  12,
                                  hPad,
                                  12,
                                ),
                                child: _buildScheduleSection(l10n),
                              ),
                            ),

                            // ── Price / payment / checkout ───────────────
                            CartSummaryBar(
                              summary: loadedInner.data.summary,
                              preview: loadedInner.preview,
                              hPad: hPad,
                              bottomPadding: bottomPadding,
                              theme: theme,
                              l10n: l10n,
                              overCodLimit: overCodLimit,
                              codLimit: _codLimit(),
                              paymentMethod: _paymentMethod,
                              onPaymentMethodChanged: (m) =>
                                  setState(() => _paymentMethod = m),
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
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _handleIncrement(BuildContext context, int spId) async {
    try {
      await _cubit.incrementItem(spId);
    } catch (_) {
      if (context.mounted) {
        showErrorBanner(
          context,
          AppLocalizations.of(context)!.updateQuantityFailed,
        );
      }
    }
  }

  void _handleDecrement(BuildContext context, int spId) async {
    try {
      await _cubit.decrementItem(spId);
    } catch (_) {
      if (context.mounted) {
        showErrorBanner(
          context,
          AppLocalizations.of(context)!.updateQuantityFailed,
        );
      }
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

// ── Checkout pill ──────────────────────────────────────────────────────────────

/// A slim persistent bar that shows the running total and a chevron.
/// Tapping it expands / collapses the full [CartSummaryBar].
class _CheckoutPill extends StatelessWidget {
  final double total;
  final bool expanded;
  final VoidCallback onTap;

  const _CheckoutPill({
    required this.total,
    required this.expanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final safePad = MediaQuery.of(context).padding.bottom;

    return Material(
      elevation: expanded ? 0 : 6,
      shadowColor: Colors.black12,
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            12,
            20,
            12 + (expanded ? 0 : safePad),
          ),
          child: Row(
            children: [
              // ── Total badge ──────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: AppColors.kPrimaryColor.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Text(
                  '${total.toStringAsFixed(2)} ${l10n.egp}',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppColors.kPrimaryColor,
                  ),
                ),
              ),

              const Spacer(),

              // ── Label ────────────────────────────────────────────────────
              Text(
                l10n.checkout,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
              const SizedBox(width: 4),

              // ── Chevron ──────────────────────────────────────────────────
              AnimatedRotation(
                turns: expanded ? 0.5 : 0.0,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                child: const Icon(Icons.keyboard_arrow_up_rounded, size: 24),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
