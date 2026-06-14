import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:tawreedat_go/core/widgets/banners.dart';
import 'package:tawreedat_go/features/cart/presentation/widgets/cart_item_tile.dart';
import 'package:tawreedat_go/features/cart/presentation/widgets/cart_price_helpers.dart';
import 'package:tawreedat_go/features/home/layout/manager/home_cubit.dart';

import '../../../core/style/app_colors.dart';
import '../../../core/utils/app_dynamic_settings.dart';
import '../../wallet/presentation/paymob_webview.dart';
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
import 'slot_picker_sheet.dart';
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

  String _paymentMethod =
      (AppSettings.kashier_enabled == true || AppSettings.paymob_enabled == true)
          ? 'CARD'
          : 'CASH';

  // ── Schedule ───────────────────────────────────────────────────────────────
  bool _isScheduled = false;
  DateTime? _scheduleAt;

  // ── Delivery-window scheduling (requires_delivery_windows products) ─────────
  /// True when the cart contains at least one product that requires window
  /// scheduling. Determined by checking CartItem.product.requiresDeliveryWindows.
  bool _requiresWindowScheduling = false;

  /// Delivery windows fetched for the matching product's spId.
  ProductDeliveryWindowsData? _productDeliveryWindows;

  /// The selected delivery slot (set after the picker is confirmed).
  CartDeliverySlot? _selectedDeliverySlot;

  final _deliveryWindowsRepo = DeliveryWindowsRepository();

  /// The slot the user selected from the picker (null if none yet or ASAP).
  CouponValid? _appliedCoupon;
  bool _couponValidating = false;
  final _couponController = TextEditingController();
  final FocusNode _couponFocus = FocusNode();

  // false = pill only visible; true = full summary visible
  final _summaryExpanded = ValueNotifier<bool>(false);
  final _pillVisible = ValueNotifier<bool>(true);
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
    _summaryExpanded.value = !_summaryExpanded.value;
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

    if (delta > 4 && _pillVisible.value) {
      _pillVisible.value = false;
      _summaryExpanded.value = false;
    } else if (delta < -4 && !_pillVisible.value) {
      _pillVisible.value = true;
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
    _pillVisible.dispose();
    _summaryExpanded.dispose();
    super.dispose();
  }

  CartCubit get _cubit => context.read<CartCubit>();

  // ── Window scheduling detection ────────────────────────────────────────────

  /// Called whenever the cart state changes to CartLoaded.
  /// Finds the first cart item with requires_delivery_windows == true and
  /// fetches its product delivery windows so we know which dates to show.
  Future<void> _detectWindowScheduling(CartLoaded state) async {
    final windowProduct = state.data.cartItems
        .where((i) => i.product.requiresDeliveryWindows)
        .firstOrNull;

    final needsWindows = windowProduct != null;

    if (!needsWindows) {
      // Cart has no window products — reset to normal scheduling
      if (_requiresWindowScheduling) {
        setState(() {
          _requiresWindowScheduling = false;
          _productDeliveryWindows = null;
          _selectedDeliverySlot = null;
          _scheduleAt = null;
        });
      }
      return;
    }

    // Already fetched for the same product
    if (_requiresWindowScheduling && _productDeliveryWindows != null) return;

    setState(() => _requiresWindowScheduling = true);

    try {
      final spId = windowProduct.spId;
      final sId = windowProduct.product.supplierId;
      final data = await _deliveryWindowsRepo.fetchWindows(spId,sId!);
      if (mounted) {
        setState(() => _productDeliveryWindows = data);
      }
    } catch (_) {
      // On failure, fall back to normal scheduling
      if (mounted) {
        setState(() {
          _requiresWindowScheduling = false;
          _productDeliveryWindows = null;
        });
      }
    }
  }

  /// Opens the delivery-window date+slot picker.
  Future<void> _openDeliveryWindowPicker() async {
    final windows = _productDeliveryWindows;
    if (windows == null) return;

    final dates = windows.nextDeliveryDates(
      from: DateTime.now().add(const Duration(days: 1)),
      count: 30,
    );

    if (dates.isEmpty) {
      showErrorBanner(context, AppLocalizations.of(context)!.noDeliveryDatesAvailable);
      return;
    }

    final result = await showDeliveryWindowPicker(
      context: context,
      deliveryDates: dates,
    );

    if (!mounted || result == null) return;
    setState(() {
      _selectedDeliverySlot = result.slot;
      _scheduleAt = result.scheduleAt;
      _isScheduled = true;
    });
  }

  String _formatWindowDate(DateTime dt) =>
      '${_weekdayName(dt.weekday == 7 ? 0 : dt.weekday)}, '
      '${dt.day}/${dt.month}/${dt.year}';

  static const _weekdays = [
    'Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat',
  ];
  static String _weekdayName(int jsDay) => _weekdays[jsDay];

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
    // Window-scheduling products MUST have a delivery slot selected
    if (_requiresWindowScheduling && _scheduleAt == null) {
      showErrorBanner(context, AppLocalizations.of(context)!.pleaseSelectDeliveryDateAndSlot);
      return;
    }
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

    // Window-scheduling always sends scheduleAt; normal flow only when _isScheduled
    final effectiveScheduleAt = _requiresWindowScheduling
        ? _scheduleAt
        : (_isScheduled ? _scheduleAt : null);

    // CARD: ask which provider before placing the order, unless only one is enabled
    if (_paymentMethod == 'CARD') {
      final enabledProviders = [
        if (AppSettings.kashier_enabled == true) 'kashier',
        if (AppSettings.paymob_enabled == true) 'paymob',
      ];

      if (enabledProviders.length == 1) {
        await context.read<OrderCubit>().createCatalogOrder(
          paymentMethod: 'CARD',
          provider: enabledProviders.first,
          couponCode: _appliedCoupon?.code,
          scheduleAt: effectiveScheduleAt,
        );
        return;
      }

      _showCardProviderSheet();
      return;
    }

    await context.read<OrderCubit>().createCatalogOrder(
      paymentMethod: _paymentMethod,
      couponCode: _appliedCoupon?.code,
      scheduleAt: effectiveScheduleAt,
    );
  }

  void _showCardProviderSheet() {
    final l10n = AppLocalizations.of(context)!;
    final effectiveScheduleAt = _requiresWindowScheduling
        ? _scheduleAt
        : (_isScheduled ? _scheduleAt : null);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) => _CardProviderSheet(
        l10n: l10n,
        onProviderSelected: (provider) {
          Navigator.pop(sheetCtx);
          context.read<OrderCubit>().createCatalogOrder(
            paymentMethod: 'CARD',
            provider: provider,
            couponCode: _appliedCoupon?.code,
            scheduleAt: effectiveScheduleAt,
          );
        },
      ),
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
    final earliest = now.add(const Duration(minutes: 30));
    final initialTime = TimeOfDay.fromDateTime(
      isToday ? earliest : pickedDate,
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

    if (scheduled.isBefore(earliest)) {
      showErrorBanner(context, AppLocalizations.of(context)!.pleaseChooseFutureTime);
      return;
    }

    setState(() {
      _scheduleAt = scheduled;
    });
  }

  /// Clears the scheduled time and selected slot.
  void _clearSchedule() {
    setState(() {
      _scheduleAt = null;
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

  // ── Window schedule section (for requires_delivery_windows products) ──────

  Widget _buildWindowScheduleSection() {
    final accent  = Colors.indigo.shade700;
    final hasSlot = _selectedDeliverySlot != null && _scheduleAt != null;
    final isLoading = _requiresWindowScheduling && _productDeliveryWindows == null;
    final l10n    = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Info banner ─────────────────────────────────────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.indigo.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.indigo.shade100),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline_rounded, size: 14, color: accent),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  l10n.cartRequiresWindowScheduling,
                  style: TextStyle(fontSize: 12, color: accent, height: 1.4),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // ── Pick / change slot button ────────────────────────────────────────
        if (isLoading)
          const Center(child: CircularProgressIndicator(strokeWidth: 2))
        else
          InkWell(
            onTap: _openDeliveryWindowPicker,
            borderRadius: BorderRadius.circular(12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: hasSlot ? Colors.indigo.shade50 : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: hasSlot ? accent.withOpacity(0.5) : Colors.grey.shade300,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_month_rounded,
                    size: 18,
                    color: hasSlot ? accent : Colors.grey.shade400,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: hasSlot
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _formatWindowDate(_scheduleAt!),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${_scheduleAt!.hour.toString().padLeft(2, '0')}:${_scheduleAt!.minute.toString().padLeft(2, '0')}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: accent,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          )
                        : Text(
                            l10n.tapToChooseDeliveryDateTime,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade500,
                            ),
                          ),
                  ),
                  Icon(
                    hasSlot ? Icons.edit_rounded : Icons.chevron_right_rounded,
                    size: 18,
                    color: Colors.grey.shade400,
                  ),
                ],
              ),
            ),
          ),

        // ── Validation error ─────────────────────────────────────────────────
        if (!hasSlot) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.error_outline_rounded, size: 13, color: Colors.red.shade400),
              const SizedBox(width: 5),
              Text(
                l10n.pleaseSelectDeliverySlot,
                style: TextStyle(fontSize: 12, color: Colors.red.shade400),
              ),
            ],
          ),
        ],
      ],
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
                          if (_scheduleAt == null) _pickScheduleDateTimeFallback();
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
                    onTap: _pickScheduleDateTimeFallback,
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
                  // Padding(
                  //   padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  //   child: Row(
                  //     children: [
                  //       Icon(
                  //         Icons.info_outline_rounded,
                  //         size: 14,
                  //         color: Colors.grey.shade500,
                  //       ),
                  //       const SizedBox(width: 6),
                  //       Expanded(
                  //         child: Text(
                  //           l10n.scheduledOrderNote,
                  //           style: TextStyle(
                  //             fontSize: 12,
                  //             color: Colors.grey.shade500,
                  //           ),
                  //         ),
                  //       ),
                  //     ],
                  //   ),
                  // ),

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
                  _walletBalance = state.walletData.wallet.balance;
                }
              },
              child: BlocListener<OrderCubit, OrderState>(
                listener: (context, state) =>
                    _handleOrderState(context, state, l10n),
                child: BlocConsumer<CartCubit, CartState>(
                  listenWhen: (_, curr) => curr is CartError || curr is CartLoaded,
                  listener: (context, state) {
                    if (state is CartError) {
                      showErrorBanner(context, state.message);
                    } else if (state is CartLoaded) {
                      // Detect if this cart requires delivery-window scheduling
                      _detectWindowScheduling(state);
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
                    final appBar = _buildAppBar(context, state);
                    return Scaffold(
                      appBar: PreferredSize(
                        preferredSize: appBar.preferredSize,
                        child: Stack(
                          children: [
                            appBar,
                            // Tapping the app bar while the summary panel is
                            // expanded closes it instead of triggering the
                            // app bar's controls.
                            ValueListenableBuilder<bool>(
                              valueListenable: _summaryExpanded,
                              builder: (context, expanded, _) {
                                if (!expanded) return const SizedBox.shrink();
                                return Positioned.fill(
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () =>
                                        _summaryExpanded.value = false,
                                    child: const ColoredBox(
                                      color: Colors.transparent,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
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
      showSuccessBanner(context, l10n.couponRedeemed);
    } else if (state is CouponInvalid) {
      setState(() => _couponValidating = false);
      showErrorBanner(context, state.message);
    } else if (state is CouponRedeemError) {
      setState(() => _couponValidating = false);
      showErrorBanner(context, state.message);
    } else if (state is OrderPendingPayment) {
      // CARD payment: push the payment WebView; on success go to orders tab.
      if (mounted) {
        FocusScope.of(context).unfocus();
        final payment = state.order.payment!;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PaymobWebViewScreen(
              paymentUrl: payment.checkoutUrl,
              amount: 0, // amount not needed for order payment confirmation
              transactionId: payment.transactionId,
              provider: payment.provider,
              onPaymentSuccess: () {
                _cubit.refreshCart();
                context.go('/mainHome', extra: GoToTab(HomeCubit.ordersTabIndex));
                showSuccessBanner(context, '${l10n.created}: ${state.order.orderNumber}');
                // Delay the orders refresh so the server has time to process
                // the payment before we fetch the list.
                context.read<OrderCubit>().refreshAfterCardPayment();
              },
              onPaymentFailed: () {
                showErrorBanner(context, l10n.paymentFailed);
                Navigator.pop(context);
              },
            ),
          ),
        ).then((_) {
          if (mounted) _cubit.refreshCart();
        });
      }
    } else if (state is OrderSuccess) {
      if (mounted) {
        FocusScope.of(context).unfocus();
        context.go('/mainHome', extra: GoToTab(HomeCubit.ordersTabIndex));
      }
      _cubit.refreshCart();
      showSuccessBanner(context, '${l10n.created}: ${state.order.orderNumber}');
    } else if (state is OrderError) {
      showErrorBanner(context, state.message);
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
          child: Stack(
            children: [
              RefreshIndicator(
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
              // Tapping outside the expanded summary panel closes it.
              ValueListenableBuilder<bool>(
                valueListenable: _summaryExpanded,
                builder: (context, expanded, _) {
                  if (!expanded) return const SizedBox.shrink();
                  return Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _summaryExpanded.value = false,
                      child: const ColoredBox(color: Colors.transparent),
                    ),
                  );
                },
              ),
            ],
          ),
        ),

        // ── Animated bottom section ──────────────────────────────────────────
        AnimatedBuilder(
          animation: Listenable.merge([_pillVisible, _summaryExpanded]),
          builder: (context, _) => AnimatedSlide(
          offset: _pillVisible.value ? Offset.zero : const Offset(0, 1),
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeInOut,
          child: AnimatedOpacity(
            opacity: _pillVisible.value ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Pill ────────────────────────────────────────────────────
                _CheckoutPill(
                  total: displayTotal,
                  hasCoupon: _appliedCoupon != null,
                  expanded: _summaryExpanded.value,
                  onTap: _toggleSummary,
                ),

                // ── Full summary panel ───────────────────────────────────────
                ClipRect(
                  child: AnimatedAlign(
                    duration: const Duration(milliseconds: 320),
                    curve: Curves.easeInOut,
                    alignment: Alignment.bottomCenter,
                    heightFactor: _summaryExpanded.value ? 1.0 : 0.0,
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
                        return ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight: MediaQuery.sizeOf(context).height
                          ),
                          child: SingleChildScrollView(
                            child: Column(
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
                                    child: _requiresWindowScheduling
                                        ? _buildWindowScheduleSection()
                                        : _buildScheduleSection(l10n),
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
                                  minOrderTotal: loadedInner
                                      .data.supplierLimits.minPriceForOneOrder,
                                  maxOrderTotal: loadedInner
                                      .data.supplierLimits.maxPriceForOneOrder,
                                  orderTotalForLimits:
                                      _priceBeforeCoupon(loadedInner),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
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
  final bool hasCoupon;
  final bool expanded;
  final VoidCallback onTap;

  const _CheckoutPill({
    required this.total,
    required this.hasCoupon,
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
              // ── Total badge / coupon badge ───────────────────────────────
              hasCoupon
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.green.shade300),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.local_offer_outlined,
                              size: 14, color: Colors.green.shade700),
                          const SizedBox(width: 5),
                          Text(
                            l10n.couponRedeemed,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ],
                      ),
                    )
                  : Container(
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

// ── Card provider selection bottom sheet ──────────────────────────────────────

class _CardProviderSheet extends StatelessWidget {
  final AppLocalizations l10n;
  final ValueChanged<String> onProviderSelected;

  const _CardProviderSheet({
    required this.l10n,
    required this.onProviderSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.selectPaymentMethod,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (AppSettings.kashier_enabled == true) ...[
            _ProviderTile(
              asset: 'assets/images/kashier.png',
              name: "${l10n.creditDebitCard} / ${l10n.mobileWallet}",
              onTap: () => onProviderSelected('kashier'),
            ),
            const SizedBox(height: 12),
          ],
          if (AppSettings.paymob_enabled == true) ...[
            _ProviderTile(
              asset: 'assets/images/Paymob.jpg',
              name: l10n.creditDebitCard,
              onTap: () => onProviderSelected('paymob'),
            ),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _ProviderTile extends StatelessWidget {
  final String asset;
  final String name;
  final VoidCallback onTap;

  const _ProviderTile({
    required this.asset,
    required this.name,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Image.asset(
                asset,
                width: 40,
                height: 40,
                fit: BoxFit.scaleDown,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 18,
              color: Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }
}
