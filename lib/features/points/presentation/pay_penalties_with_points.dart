import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/style/app_colors.dart';
import '../../../core/widgets/loading_screen.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/manager/locale_cubit.dart';
import '../../wallet/data/data_source/wallet_remote_data_source.dart';
import '../../wallet/data/models/transaction_penality_models.dart';
import '../../wallet/data/repositories/wallet_repo.dart';
import '../../wallet/manager/wallet_cubit.dart';
import '../../wallet/manager/wallet_state.dart';
import '../manager/points_cubit.dart';
import '../manager/points_states.dart';

/// Wraps the screen with its own WalletCubit (penalty loading)
/// and PointsCubit (pay action).
class PayPenaltiesWithPointsScreen extends StatelessWidget {
  const PayPenaltiesWithPointsScreen({super.key});

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
        BlocProvider(
          create: (_) => PointsCubit(),
        ),
      ],
      child: const _PayPenaltiesView(),
    );
  }
}

class _PayPenaltiesView extends StatefulWidget {
  const _PayPenaltiesView();

  @override
  State<_PayPenaltiesView> createState() => _PayPenaltiesViewState();
}

class _PayPenaltiesViewState extends State<_PayPenaltiesView> {
  final Set<int> _selectedIds = {};
  int _page = 1;
  final ScrollController _scrollController = ScrollController();

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
        _page++;
        context.read<WalletCubit>().fetchPenalties(page: _page);
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

  void _selectAll(List<PenaltyModel> penalties) {
    setState(() {
      final unpaid = penalties.where((p) => !p.isPaid && !p.isWaived);
      if (_selectedIds.length == unpaid.length) {
        _selectedIds.clear();
      } else {
        _selectedIds
          ..clear()
          ..addAll(unpaid.map((p) => p.id));
      }
    });
  }

  Future<void> _confirmPayment(BuildContext context) async {
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
              : 'Points will be deducted to pay ${_selectedIds.length} ${_selectedIds.length == 1 ? 'penalty' : 'penalties'}. Continue?',
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
      isArabic: isArabic,
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
          setState(() => _selectedIds.clear());
          // Reload penalties to reflect the changes
          _page = 1;
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
            isArabic ? 'سداد الغرامات بالنقاط' : 'Pay Penalties with Points',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          leading: BackButton(
            color: Colors.black,
            onPressed: () => context.pop(),
          ),
          actions: [
            // Select All toggle
            BlocBuilder<WalletCubit, WalletState>(
              builder: (context, state) {
                if (state is! PenaltiesLoaded || state.penalties.isEmpty) {
                  return const SizedBox.shrink();
                }
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
            ),
          ],
        ),
        body: BlocBuilder<WalletCubit, WalletState>(
          builder: (context, state) {
            if (state is PenaltiesLoading) {
              return const Center(child: LoadingScreen(isOne: true));
            }

            if (state is PenaltiesError) {
              return _ErrorView(
                message: state.message,
                onRetry: () {
                  _page = 1;
                  context.read<WalletCubit>().fetchPenalties();
                },
                isArabic: isArabic,
              );
            }

            if (state is PenaltiesLoaded) {
              final unpaid = state.penalties
                  .where((p) => !p.isPaid && !p.isWaived)
                  .toList();

              if (unpaid.isEmpty) {
                return const _NoPenaltiesView();
              }

              return Stack(
                children: [
                  RefreshIndicator(
                    onRefresh: () async {
                      _page = 1;
                      setState(() => _selectedIds.clear());
                      await context.read<WalletCubit>().fetchPenalties();
                    },
                    color: AppColors.kPrimaryColor,
                    child: ListView.builder(
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                      itemCount: unpaid.length + (state.isLoadingMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == unpaid.length) {
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(
                              child: CircularProgressIndicator(
                                color: Color(0xFFE17055),
                              ),
                            ),
                          );
                        }
                        final penalty = unpaid[index];
                        final isSelected = _selectedIds.contains(penalty.id);
                        return _SelectablePenaltyCard(
                          penalty: penalty,
                          isSelected: isSelected,
                          isArabic: isArabic,
                          onTap: () => _toggleSelection(penalty.id),
                        );
                      },
                    ),
                  ),

                  // ── Sticky bottom action bar ──────────────────────────────
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: _BottomActionBar(
                      selectedCount: _selectedIds.length,
                      isArabic: isArabic,
                      onPay: () => _confirmPayment(context),
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

// ─── Selectable Penalty Card ──────────────────────────────────────────────────

class _SelectablePenaltyCard extends StatelessWidget {
  final PenaltyModel penalty;
  final bool isSelected;
  final bool isArabic;
  final VoidCallback onTap;

  const _SelectablePenaltyCard({
    required this.penalty,
    required this.isSelected,
    required this.isArabic,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(
      symbol: AppLocalizations.of(context)!.egp,
      decimalDigits: 2,
    );
    final dateFormatter = DateFormat('dd MMM yyyy, hh:mm a');
    final borderColor =
    isSelected ? AppColors.kPrimaryColor : const Color(0xFFE17055);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: borderColor.withOpacity(isSelected ? 1.0 : 0.3),
            width: isSelected ? 2 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? AppColors.kPrimaryColor.withOpacity(0.12)
                  : Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Checkbox
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 24,
                height: 24,
                margin: const EdgeInsets.only(top: 2, right: 12),
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
                    ? const Icon(Icons.check, size: 16, color: Colors.white)
                    : null,
              ),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            penalty.reason ??
                                (isArabic ? 'غرامة' : 'Penalty'),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1A1A2E),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '- ${currencyFormatter.format(penalty.amount)}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFE17055),
                          ),
                        ),
                      ],
                    ),
                    if (penalty.orderId != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        '${isArabic ? 'طلب' : 'Order'} #${penalty.orderId}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.calendar_today,
                            size: 12, color: Colors.grey.shade500),
                        const SizedBox(width: 4),
                        Text(
                          dateFormatter.format(penalty.createdAt),
                          textDirection: ui.TextDirection.ltr,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Bottom Action Bar ────────────────────────────────────────────────────────

class _BottomActionBar extends StatelessWidget {
  final int selectedCount;
  final bool isArabic;
  final VoidCallback onPay;

  const _BottomActionBar({
    required this.selectedCount,
    required this.isArabic,
    required this.onPay,
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
                      Icon(Icons.info_outline,
                          size: 14, color: Colors.grey.shade500),
                      const SizedBox(width: 6),
                      Text(
                        isArabic
                            ? 'تم اختيار $selectedCount غرامة'
                            : '$selectedCount ${selectedCount == 1 ? 'penalty' : 'penalties'} selected',
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
                  onPressed:
                  (selectedCount == 0 || isLoading) ? null : onPay,
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
                      : const Icon(Icons.stars_rounded,
                      color: Colors.white, size: 20),
                  label: Text(
                    isLoading
                        ? (isArabic ? 'جاري الدفع...' : 'Paying...')
                        : selectedCount == 0
                        ? (isArabic
                        ? 'اختر غرامة للسداد'
                        : 'Select a penalty to pay')
                        : (isArabic
                        ? 'سداد $selectedCount غرامة بالنقاط'
                        : 'Pay $selectedCount ${selectedCount == 1 ? 'penalty' : 'penalties'} with Points'),
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

// ─── Helper views ─────────────────────────────────────────────────────────────

class _NoPenaltiesView extends StatelessWidget {
  const _NoPenaltiesView();

  @override
  Widget build(BuildContext context) {
    final isArabic = LocaleManager.currentLocale == 'ar';
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.verified_outlined, size: 80, color: Colors.green.shade300),
          const SizedBox(height: 16),
          Text(
            isArabic ? 'لا توجد غرامات معلقة' : 'No pending penalties',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isArabic ? 'أنت في وضع ممتاز 🎉' : "You're in great standing! 🎉",
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final bool isArabic;

  const _ErrorView({
    required this.message,
    required this.onRetry,
    required this.isArabic,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
          const SizedBox(height: 16),
          Text(
            isArabic ? 'حدث خطأ' : 'Something went wrong',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: onRetry,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.kPrimaryColor,
            ),
            child: Text(isArabic ? 'إعادة المحاولة' : 'Retry'),
          ),
        ],
      ),
    );
  }
}