import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:tawreedat_courier/core/style/app_colors.dart';
import 'package:tawreedat_courier/core/widgets/banners.dart';
import 'package:tawreedat_courier/core/widgets/loading_screen.dart';

import '../../../core/widgets/circel_back_button.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/manager/locale_cubit.dart';
import '../../auth/manager/profile_cubit.dart';
import '../../points/manager/points_cubit.dart';
import '../../points/manager/points_states.dart';
import '../data/models/wallet_models.dart';
import '../manager/wallet_cubit.dart';
import '../manager/wallet_states.dart';

class UnpaidCommissionsScreen extends StatelessWidget {
  const UnpaidCommissionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => WalletCubit()..loadUnpaidCommissions(),
        ),
        BlocProvider(create: (_) => PointsCubit()),
      ],
      child: const UnpaidCommissionsView(),
    );
  }
}

class UnpaidCommissionsView extends StatefulWidget {
  const UnpaidCommissionsView({super.key});

  @override
  State<UnpaidCommissionsView> createState() => _UnpaidCommissionsViewState();
}

class _UnpaidCommissionsViewState extends State<UnpaidCommissionsView> {
  final ScrollController _scrollController = ScrollController();
  int _currentSkip = 0;

  bool _selectionMode = false;
  final Set<int> _selectedIds = {};

  bool get isArabic => LocaleManager.currentLocale == 'ar';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      final state = context.read<WalletCubit>().state;
      if (state is UnpaidCommissionsLoaded &&
          state.pagination.hasMore &&
          !state.isLoadingMore) {
        _currentSkip = state.pagination.nextSkip;
        context.read<WalletCubit>().loadUnpaidCommissions(skip: _currentSkip);
      }
    }
  }

  void _toggleSelection(int id) => setState(() {
    _selectedIds.contains(id)
        ? _selectedIds.remove(id)
        : _selectedIds.add(id);
  });

  void _selectAll(List<UnpaidCommissionModel> unpaid) => setState(() {
    if (_selectedIds.length == unpaid.length) {
      _selectedIds.clear();
    } else {
      _selectedIds
        ..clear()
        ..addAll(unpaid.map((c) => c.id));
    }
  });

  void _enterSelectionMode() => setState(() {
    _selectionMode = true;
    _selectedIds.clear();
  });

  void _exitSelectionMode() => setState(() {
    _selectionMode = false;
    _selectedIds.clear();
  });

  Future<void> _confirmPayment() async {
    if (_selectedIds.isEmpty) return;

    final l10n = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          isArabic ? 'تأكيد الدفع' : 'Confirm Payment',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          isArabic
              ? 'سيتم خصم النقاط اللازمة لسداد ${_selectedIds.length} عمولة. هل تريد المتابعة؟'
              : 'Points will be deducted to pay ${_selectedIds.length} '
              '${_selectedIds.length == 1 ? 'commission' : 'commissions'}. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel,
                style: TextStyle(color: Colors.grey.shade600)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.confirm,),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    context.read<PointsCubit>().payFinesWithPoints(
      commissionIds: _selectedIds.toList(),
      userId: context.read<ProfileCubit>().currentProfile?.id.toString()??'',
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return BlocListener<PointsCubit, PointsState>(
      listener: (context, state) {
        if (state is FinesPaidWithPoints) {
          showSuccessBanner(context, isArabic
              ? '✅ تم سداد العمولات بنجاح!'
              : '✅ Commissions paid successfully!');
          _exitSelectionMode();
          _currentSkip = 0;
          context.read<WalletCubit>().loadUnpaidCommissions();
        } else if (state is PayFinesError) {
          showErrorBanner(context, state.message);
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F6FA),
        appBar: AppBar(
          title: Text(l10n.unpaidCommissions,
              style: const TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          leading: _selectionMode
              ? IconButton(
            icon: const Icon(Icons.close, color: Colors.black),
            onPressed: _exitSelectionMode,
          )
              : CircleBackButton(onPressed: context.pop,),
          actions: [
            if (_selectionMode)
              BlocBuilder<WalletCubit, WalletState>(
                builder: (context, state) {
                  if (state is! UnpaidCommissionsLoaded) {
                    return const SizedBox.shrink();
                  }
                  final unpaid =
                  state.commissions.where((c) => !c.isPaid).toList();
                  if (unpaid.isEmpty) return const SizedBox.shrink();
                  final allSelected = _selectedIds.length == unpaid.length;
                  return TextButton(
                    onPressed: () => _selectAll(unpaid),
                    child: Text(
                      allSelected
                          ? (isArabic ? 'إلغاء الكل' : 'Deselect All')
                          : (isArabic ? 'اختيار الكل' : 'Select All'),
                      style: TextStyle(color: AppColors.kPrimaryColor),
                    ),
                  );
                },
              )
            else
              BlocBuilder<WalletCubit, WalletState>(
                builder: (context, state) {
                  if (state is! UnpaidCommissionsLoaded) {
                    return const SizedBox.shrink();
                  }
                  final hasUnpaid = state.commissions.any((c) => !c.isPaid);
                  if (!hasUnpaid) return const SizedBox.shrink();
                  return TextButton.icon(
                    onPressed: _enterSelectionMode,
                    icon: Icon(Icons.stars_rounded,
                        size: 18, color: AppColors.kPrimaryColor),
                    label: Text(
                      isArabic ? 'دفع بالنقاط' : 'Pay with Points',
                      style: TextStyle(color: AppColors.kPrimaryColor),
                    ),
                  );
                },
              ),
          ],
        ),
        body: BlocBuilder<WalletCubit, WalletState>(
          builder: (context, state) {
            if (state is UnpaidCommissionsLoading) {
              return const Center(child: LoadingScreen(isOne: true));
            }

            if (state is UnpaidCommissionsError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline,
                        size: 64, color: Colors.red.shade300),
                    const SizedBox(height: 16),
                    Text(l10n.errorOccurred,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(state.message,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey.shade600)),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        _currentSkip = 0;
                        context.read<WalletCubit>().loadUnpaidCommissions();
                      },
                      child: Text(l10n.retry),
                    ),
                  ],
                ),
              );
            }

            if (state is UnpaidCommissionsLoaded) {
              final unpaidList =
              state.commissions.where((c) => !c.isPaid).toList();
              final totalUnpaid = state.commissions
                  .where((c) => !c.isPaid)
                  .fold(0.0, (sum, c) => sum + c.amount);

              if (state.commissions.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.verified_outlined,
                          size: 80, color: Colors.green.shade300),
                      const SizedBox(height: 16),
                      Text(l10n.noUnpaidCommissions,
                          style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                );
              }

              return Stack(
                children: [
                  Column(
                    children: [
                      // Summary card
                      if (totalUnpaid > 0)
                        Container(
                          margin: const EdgeInsets.all(16),
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFF6B6B), Color(0xFFE17055)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color:
                                const Color(0xFFFF6B6B).withOpacity(0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.money_off_rounded,
                                    color: Colors.white, size: 32),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(l10n.totalOwed,
                                        style: TextStyle(
                                            fontSize: 14,
                                            color:
                                            Colors.white.withOpacity(0.9))),
                                    const SizedBox(height: 4),
                                    Text(
                                      NumberFormat.currency(
                                        symbol: l10n.egp,
                                        decimalDigits: 2,
                                      ).format(totalUnpaid),
                                      style: const TextStyle(
                                          fontSize: 28,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                      // List
                      Expanded(
                        child: RefreshIndicator(
                          onRefresh: () async {
                            _currentSkip = 0;
                            _exitSelectionMode();
                            await context
                                .read<WalletCubit>()
                                .loadUnpaidCommissions();
                          },
                          color: const Color(0xFFFF6B6B),
                          child: ListView.builder(
                            controller: _scrollController,
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: EdgeInsets.fromLTRB(
                                16, 0, 16, _selectionMode ? 120 : 16),
                            itemCount: state.commissions.length +
                                (state.isLoadingMore ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index == state.commissions.length) {
                                return const Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Center(
                                      child: CircularProgressIndicator(
                                          color: Color(0xFFFF6B6B))),
                                );
                              }
                              final commission = state.commissions[index];
                              final isSelectable = !commission.isPaid;
                              return _CommissionCard(
                                commission: commission,
                                isArabic: isArabic,
                                selectionMode: _selectionMode,
                                isSelected:
                                _selectedIds.contains(commission.id),
                                onTap: (_selectionMode && isSelectable)
                                    ? () => _toggleSelection(commission.id)
                                    : null,
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Pay bar
                  if (_selectionMode)
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: _PayBar(
                        selectedCount: _selectedIds.length,
                        isArabic: isArabic,
                        onPay: _confirmPayment,
                        itemLabel: isArabic ? 'عمولة' : 'commission',
                        itemLabelPlural: isArabic ? 'عمولات' : 'commissions',
                      ),
                    ),
                ],
              );
            }

            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }
}

// ─── Commission Card ──────────────────────────────────────────────────────────

class _CommissionCard extends StatelessWidget {
  final UnpaidCommissionModel commission;
  final bool isArabic;
  final bool selectionMode;
  final bool isSelected;
  final VoidCallback? onTap;

  const _CommissionCard({
    required this.commission,
    required this.isArabic,
    required this.selectionMode,
    required this.isSelected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isSelectable = !commission.isPaid;
    final paidColor = const Color(0xFF00B894);
    final unpaidColor = const Color(0xFFFF6B6B);
    final color = commission.isPaid ? paidColor : unpaidColor;
    final currencyFormatter =
    NumberFormat.currency(symbol: l10n.egp, decimalDigits: 2);
    final dateFormatter = DateFormat('dd MMM yyyy, hh:mm a');

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: (selectionMode && isSelectable && isSelected)
                ? AppColors.kPrimaryColor
                : color.withOpacity(0.3),
            width: (selectionMode && isSelectable && isSelected) ? 2 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: (selectionMode && isSelectable && isSelected)
                  ? AppColors.kPrimaryColor.withOpacity(0.12)
                  : Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Checkbox
                if (selectionMode && isSelectable) ...[
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 22,
                    height: 22,
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.kPrimaryColor : Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.kPrimaryColor
                            : Colors.grey.shade400,
                        width: 2,
                      ),
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, size: 14, color: Colors.white)
                        : null,
                  ),
                ],
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    commission.isPaid
                        ? Icons.check_circle_outline
                        : Icons.money_off_outlined,
                    color: color,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${l10n.order} #${commission.orderId}',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text(l10n.platformCommission,
                          style: TextStyle(
                              fontSize: 13, color: Colors.grey.shade600)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      currencyFormatter.format(commission.amount),
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: color),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: (commission.isPaid ? paidColor : Colors.orange)
                            .withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        commission.isPaid ? l10n.paid : l10n.pending,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: commission.isPaid
                              ? paidColor
                              : Colors.orange.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            Row(children: [
              Icon(Icons.calendar_today,
                  size: 14, color: Colors.grey.shade500),
              const SizedBox(width: 4),
              Text(dateFormatter.format(commission.createdAt),
                  textDirection: ui.TextDirection.ltr,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
            ]),
            if (commission.isPaid && commission.paidAt != null) ...[
              const SizedBox(height: 6),
              Row(children: [
                Icon(Icons.check_circle,
                    size: 14, color: Colors.green.shade600),
                const SizedBox(width: 4),
                Text(
                    '${l10n.paidDate} ${dateFormatter.format(commission.paidAt!)}',
                    style:
                    TextStyle(fontSize: 12, color: Colors.green.shade600)),
              ]),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Pay Bar ──────────────────────────────────────────────────────────────────

class _PayBar extends StatelessWidget {
  final int selectedCount;
  final bool isArabic;
  final VoidCallback onPay;
  final String itemLabel;
  final String itemLabelPlural;

  const _PayBar({
    required this.selectedCount,
    required this.isArabic,
    required this.onPay,
    required this.itemLabel,
    required this.itemLabelPlural,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PointsCubit, PointsState>(
      builder: (context, state) {
        final isLoading = state is PayingFinesWithPoints;
        return Container(
          padding: EdgeInsets.fromLTRB(
            20,
            16,
            20,
            24 + MediaQuery.paddingOf(context).bottom,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 20,
                  offset: const Offset(0, -4)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selectedCount > 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.info_outline,
                          size: 14, color: Colors.grey.shade500),
                      const SizedBox(width: 6),
                      Text(
                        isArabic
                            ? 'تم اختيار $selectedCount $itemLabel'
                            : '$selectedCount ${selectedCount == 1 ? itemLabel : itemLabelPlural} selected',
                        style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: (selectedCount == 0 || isLoading) ? null : onPay,
                  icon: isLoading
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2),
                  )
                      : const Icon(Icons.stars_rounded,
                      color: Colors.white, size: 20),
                  label: Text(
                    isLoading
                        ? (isArabic ? 'جاري الدفع...' : 'Paying...')
                        : selectedCount == 0
                        ? (isArabic
                        ? 'اختر عنصرًا للسداد'
                        : 'Select an item to pay')
                        : (isArabic
                        ? 'سداد $selectedCount $itemLabel بالنقاط'
                        : 'Pay $selectedCount ${selectedCount == 1 ? itemLabel : itemLabelPlural} with Points'),
                    style: TextStyle(
                      color: selectedCount == 0
                          ? Colors.grey.shade500
                          : Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}