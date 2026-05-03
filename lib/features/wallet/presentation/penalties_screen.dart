import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:tawreedat_go/features/wallet/data/data_source/wallet_remote_data_source.dart';
import 'package:tawreedat_go/features/wallet/data/repositories/wallet_repo.dart';

import '../../../core/style/app_colors.dart';
import '../../../core/widgets/loading_screen.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/manager/locale_cubit.dart';
import '../../auth/manager/profile_cubit.dart';
import '../../points/manager/points_cubit.dart';
import '../../points/manager/points_states.dart';
import '../data/models/transaction_penality_models.dart';
import '../manager/wallet_cubit.dart';
import '../manager/wallet_state.dart';

class PenaltiesScreen extends StatelessWidget {
  const PenaltiesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => WalletCubit(
            repository: WalletRepository(
              remoteDataSource: WalletRemoteDataSource(),
            ),
          )..fetchPenalties(),
        ),
        BlocProvider(create: (_) => PointsCubit()),
      ],
      child: const PenaltiesView(),
    );
  }
}

class PenaltiesView extends StatefulWidget {
  const PenaltiesView({super.key});

  @override
  State<PenaltiesView> createState() => _PenaltiesViewState();
}

class _PenaltiesViewState extends State<PenaltiesView> {
  final ScrollController _scrollController = ScrollController();
  int _currentPage = 1;

  // ── Pay-with-points selection state ──────────────────────────────────────
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
      if (state is PenaltiesLoaded &&
          state.pagination.hasMore &&
          !state.isLoadingMore) {
        _currentPage++;
        context.read<WalletCubit>().fetchPenalties(page: _currentPage);
      }
    }
  }

  void _toggleSelection(int id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _selectAll(List<PenaltyModel> unpaid) {
    setState(() {
      if (_selectedIds.length == unpaid.length) {
        _selectedIds.clear();
      } else {
        _selectedIds
          ..clear()
          ..addAll(unpaid.map((p) => p.id));
      }
    });
  }

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
              ? 'سيتم خصم النقاط اللازمة لسداد ${_selectedIds.length} غرامة. هل تريد المتابعة؟'
              : 'Points will be deducted to pay ${_selectedIds.length} '
                    '${_selectedIds.length == 1 ? 'penalty' : 'penalties'}. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              isArabic ? 'إلغاء' : 'Cancel',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.kPrimaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              isArabic ? 'تأكيد' : 'Confirm',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    context.read<PointsCubit>().payFinesWithPoints(
      penaltyIds: _selectedIds.toList(),
      userId: context.read<ProfileCubit>().currentProfile?.id.toString()??'',
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<PointsCubit, PointsState>(
      listener: (context, state) {
        if (state is FinesPaidWithPoints) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isArabic
                    ? '✅ تم سداد الغرامات بنجاح!'
                    : '✅ Penalties paid successfully!',
              ),
              backgroundColor: Colors.green.shade600,
              behavior: SnackBarBehavior.floating,
            ),
          );
          _exitSelectionMode();
          _currentPage = 1;
          context.read<WalletCubit>().fetchPenalties();
        } else if (state is PayFinesError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Colors.red.shade600,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F6FA),
        appBar: AppBar(
          title: Text(
            AppLocalizations.of(context)!.penalties,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          leading: _selectionMode
              ? IconButton(
                  icon: const Icon(Icons.close, color: Colors.black),
                  onPressed: _exitSelectionMode,
                )
              : BackButton(color: Colors.black, onPressed: () => context.pop()),
          actions: [
            // ── Select-all when in selection mode ──────────────────────
            if (_selectionMode)
              BlocBuilder<WalletCubit, WalletState>(
                builder: (context, state) {
                  if (state is! PenaltiesLoaded) return const SizedBox.shrink();
                  final unpaid = state.penalties
                      .where((p) => !p.isPaid && !p.isWaived)
                      .toList();
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
            // ── "Pay with Points" entry button ─────────────────────────
            else
              BlocBuilder<WalletCubit, WalletState>(
                builder: (context, state) {
                  if (state is! PenaltiesLoaded) return const SizedBox.shrink();
                  final hasUnpaid = state.penalties.any(
                    (p) => !p.isPaid && !p.isWaived,
                  );
                  if (!hasUnpaid) return const SizedBox.shrink();
                  return TextButton.icon(
                    onPressed: _enterSelectionMode,
                    icon: Icon(
                      Icons.stars_rounded,
                      size: 18,
                      color: AppColors.kPrimaryColor,
                    ),
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
            if (state is PenaltiesLoading) {
              return const Center(child: LoadingScreen(isOne: true));
            }

            if (state is PenaltiesError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.red.shade300,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      AppLocalizations.of(context)!.errorOccurred,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        state.message,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        _currentPage = 1;
                        context.read<WalletCubit>().fetchPenalties();
                      },
                      child: Text(AppLocalizations.of(context)!.retry),
                    ),
                  ],
                ),
              );
            }

            if (state is PenaltiesLoaded) {
              if (state.penalties.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.verified_outlined,
                        size: 80,
                        color: Colors.green.shade300,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        AppLocalizations.of(context)!.noPenalties,
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        AppLocalizations.of(context)!.youreInGoodStanding,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return Stack(
                children: [
                  RefreshIndicator(
                    onRefresh: () async {
                      _currentPage = 1;
                      _exitSelectionMode();
                      await context.read<WalletCubit>().fetchPenalties();
                    },
                    color: const Color(0xFFE17055),
                    child: ListView.builder(
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(
                        16,
                        16,
                        16,
                        _selectionMode ? 120 : 16,
                      ),
                      itemCount:
                          state.penalties.length +
                          (state.isLoadingMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == state.penalties.length) {
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(
                              child: CircularProgressIndicator(
                                color: Color(0xFFE17055),
                              ),
                            ),
                          );
                        }
                        final penalty = state.penalties[index];
                        final isSelectable =
                            !penalty.isPaid && !penalty.isWaived;
                        final isSelected = _selectedIds.contains(penalty.id);

                        return _PenaltyCard(
                          penalty: penalty,
                          isArabic: isArabic,
                          selectionMode: _selectionMode,
                          isSelected: isSelected,
                          onTap: (_selectionMode && isSelectable)
                              ? () => _toggleSelection(penalty.id)
                              : null,
                        );
                      },
                    ),
                  ),

                  // ── Sticky pay bar (visible only in selection mode) ────
                  // Replace _PayWithPointsBar widget with:
                  if (_selectionMode)
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: _PayBar(
                        selectedCount: _selectedIds.length,
                        isArabic: isArabic,
                        onPay: _confirmPayment,
                        itemLabel: isArabic ? 'غرامة' : 'penalty',
                        itemLabelPlural: isArabic ? 'غرامات' : 'penalties',
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

// ─── Pay Bar (shared) ─────────────────────────────────────────────────────────

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
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
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
                      Icon(
                        Icons.info_outline,
                        size: 14,
                        color: Colors.grey.shade500,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isArabic
                            ? 'تم اختيار $selectedCount $itemLabel'
                            : '$selectedCount ${selectedCount == 1 ? itemLabel : itemLabelPlural} selected',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: (selectedCount == 0 || isLoading) ? null : onPay,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.kPrimaryColor,
                    disabledBackgroundColor: Colors.grey.shade300,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  icon: isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(
                          Icons.stars_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
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

// ─── Penalty Card (extended with optional selection UI) ───────────────────────

class _PenaltyCard extends StatelessWidget {
  final PenaltyModel penalty;
  final bool isArabic;
  final bool selectionMode;
  final bool isSelected;
  final VoidCallback? onTap;

  const _PenaltyCard({
    required this.penalty,
    required this.isArabic,
    required this.selectionMode,
    required this.isSelected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelectable = !penalty.isPaid && !penalty.isWaived;
    final currencyFormatter = NumberFormat.currency(
      symbol: AppLocalizations.of(context)!.egp,
      decimalDigits: 2,
    );
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
                : _getStatusColor().withOpacity(0.3),
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
                // Checkbox (visible only in selection mode for unpaid items)
                if (selectionMode && isSelectable) ...[
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 22,
                    height: 22,
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.kPrimaryColor
                          : Colors.white,
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
                    color: _getStatusColor().withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _getStatusIcon(),
                    color: _getStatusColor(),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        penalty.reason ?? AppLocalizations.of(context)!.penalty,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      if (penalty.orderId != null)
                        Text(
                          '${AppLocalizations.of(context)!.order} #${penalty.orderId}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '- ${currencyFormatter.format(penalty.amount)}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _getStatusColor(),
                      ),
                    ),
                    const SizedBox(height: 4),
                    _StatusChip(status: penalty.statusText, isArabic: isArabic),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 14,
                  color: Colors.grey.shade500,
                ),
                const SizedBox(width: 4),
                Text(
                  dateFormatter.format(penalty.createdAt),
                  textDirection: ui.TextDirection.ltr,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
              ],
            ),
            if (penalty.isPaid && penalty.paidAt != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    size: 14,
                    color: Colors.green.shade600,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${AppLocalizations.of(context)!.paidDate} ${dateFormatter.format(penalty.paidAt!)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green.shade600,
                    ),
                  ),
                ],
              ),
            ],
            if (penalty.isWaived && penalty.waivedAt != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.cancel, size: 14, color: Colors.blue.shade600),
                  const SizedBox(width: 4),
                  Text(
                    '${AppLocalizations.of(context)!.waivedDate} ${dateFormatter.format(penalty.waivedAt!)}',
                    style: TextStyle(fontSize: 12, color: Colors.blue.shade600),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getStatusColor() {
    if (penalty.isWaived) return Colors.blue;
    if (penalty.isPaid) return const Color(0xFF00B894);
    return const Color(0xFFE17055);
  }

  IconData _getStatusIcon() {
    if (penalty.isWaived) return Icons.cancel_outlined;
    if (penalty.isPaid) return Icons.check_circle_outline;
    return Icons.warning_amber_outlined;
  }
}

// ─── Status chip (unchanged) ──────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  final String status;
  final bool isArabic;

  const _StatusChip({required this.status, required this.isArabic});

  @override
  Widget build(BuildContext context) {
    Color backgroundColor;
    Color textColor;
    String label;

    switch (status) {
      case 'COMPLETED':
        backgroundColor = const Color(0xFF00B894).withOpacity(0.1);
        textColor = const Color(0xFF00B894);
        label = AppLocalizations.of(context)!.paid;
        break;
      case 'PENDING':
        backgroundColor = Colors.orange.withOpacity(0.1);
        textColor = Colors.orange.shade700;
        label = AppLocalizations.of(context)!.pending;
        break;
      case 'WAIVED':
        backgroundColor = Colors.blue.withOpacity(0.1);
        textColor = Colors.blue.shade700;
        label = AppLocalizations.of(context)!.waived;
        break;
      default:
        backgroundColor = Colors.grey.withOpacity(0.1);
        textColor = Colors.grey.shade700;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }
}
