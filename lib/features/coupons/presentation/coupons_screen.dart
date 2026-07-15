// In app_router.dart, update the coupons route to pass initialTab:
//
//   GoRoute(
//     path: '/wallet/coupons',
//     builder: (context, state) {
//       final extra = state.extra as Map<String, dynamic>?;
//       final initialTab = extra?['initialTab'] as int? ?? 0;
//       return CouponsScreen(initialTab: initialTab);
//     },
//   ),

// ─────────────────────────────────────────────────────────────────────────────
// coupons_screen.dart  (replace the whole file)
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:tawreedat_courier/core/style/app_colors.dart';
import 'package:tawreedat_courier/core/widgets/banners.dart';
import 'package:tawreedat_courier/core/widgets/loading_screen.dart';
import 'package:tawreedat_courier/features/coupons/presentation/widgets/active_coupon_tab.dart';
import 'package:tawreedat_courier/features/coupons/presentation/widgets/available_coupons_tab.dart';
import 'package:tawreedat_courier/features/coupons/presentation/widgets/history_coupons_tab.dart';
import 'package:tawreedat_courier/l10n/app_localizations.dart';

import '../../../core/widgets/circel_back_button.dart';
import '../manager/coupons_cubit.dart';
import '../manager/coupons_states.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Entry point
// ─────────────────────────────────────────────────────────────────────────────

class CouponsScreen extends StatelessWidget {
  /// 0 = Active, 1 = History, 2 = Available (default: 0)
  final int initialTab;

  const CouponsScreen({super.key, this.initialTab = 0});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => CouponCubit()..loadAll(),
      child: _CouponsView(initialTab: initialTab),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Private view
// ─────────────────────────────────────────────────────────────────────────────

class _CouponsView extends StatefulWidget {
  final int initialTab;

  const _CouponsView({this.initialTab = 0});

  @override
  State<_CouponsView> createState() => _CouponsViewState();
}

class _CouponsViewState extends State<_CouponsView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  CouponDataLoaded? _lastLoaded;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 2),
    );
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return BlocConsumer<CouponCubit, CouponState>(
      listener: (context, state) {
        if (state is CouponBuySuccess) {
          showSuccessBanner(context, l10n.couponActivatedSuccess);
        }
        if (state is CouponBuyError) {
          showErrorBanner(context, state.message);
        }
      },
      builder: (context, state) {
        if (state is CouponDataLoaded) _lastLoaded = state;

        // ── 1. First-load spinner ────────────────────────────────────────
        if (state is CouponLoading && _lastLoaded == null) {
          return Scaffold(
            backgroundColor: const Color(0xFFF5F6FA),
            body: Center(child: LoadingScreen(asWidget: true, isOne: true)),
          );
        }

        // ── 2. Full-screen error ─────────────────────────────────────────
        if (state is CouponError && _lastLoaded == null) {
          return Scaffold(
            backgroundColor: const Color(0xFFF5F6FA),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Colors.red.shade300,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      state.message,
                      style: TextStyle(color: Colors.grey.shade600),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => context.read<CouponCubit>().loadAll(),
                      icon: const Icon(Icons.refresh, color: Colors.black),
                      label: Text(l10n.retry),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        // ── 3. Data available ────────────────────────────────────────────
        final data = (state is CouponDataLoaded ? state : _lastLoaded)!;
        final isBuying = state is CouponBuying;
        final hasActiveCoupon = data.activeCoupon != null;

        return Scaffold(
          backgroundColor: const Color(0xFFF5F6FA),
          appBar: AppBar(
            title: Text(
              l10n.coupons,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: Colors.white,
            elevation: 0,
            centerTitle: true,
            leading: CircleBackButton(
              onPressed: () =>
                  context.canPop() ? context.pop() : context.go('/mainHome'),
            ),
            bottom: PreferredSize(
              preferredSize: Size.fromHeight(isBuying ? 50 : 48),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TabBar(
                    controller: _tabs,
                    labelColor: AppColors.kPrimaryColor,
                    unselectedLabelColor: Colors.grey,
                    indicatorColor: AppColors.kPrimaryColor,
                    tabs: [
                      Tab(text: l10n.active),
                      Tab(text: l10n.history),
                      Tab(text: l10n.coupons),
                    ],
                  ),
                  if (isBuying)
                    LinearProgressIndicator(
                      color: AppColors.kPrimaryColor,
                      backgroundColor: AppColors.kPrimaryColor.withOpacity(
                        0.15,
                      ),
                      minHeight: 2,
                    ),
                ],
              ),
            ),
          ),
          body: TabBarView(
            controller: _tabs,
            children: [
              ActiveCouponTab(
                active: data.activeCoupon,
                isRtl: Directionality.of(context) == TextDirection.rtl,
              ),
              CouponHistoryTab(
                history: data.history,
                isLoadingMore: data.isLoadingMoreHistory,
                hasMore: data.historyPagination?.hasNext ?? false,
                isRtl: Directionality.of(context) == TextDirection.rtl,
              ),
              AvailableCouponsTab(
                coupons: data.availableCoupons,
                isRtl: Directionality.of(context) == TextDirection.rtl,
                hasActiveCoupon: hasActiveCoupon,
                isBuying: isBuying,
              ),
            ],
          ),
        );
      },
    );
  }
}
