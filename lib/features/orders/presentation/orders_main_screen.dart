import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tawreedat_courier/features/orders/presentation/widgets/orders_toggle_button.dart';
import '../../../core/style/app_colors.dart';
import '../../home/layout/manager/home_cubit.dart';
import 'available_orders_screen.dart';
import 'order_history_screen.dart';

class OrdersMainScreen extends StatefulWidget {
  const OrdersMainScreen({super.key});

  @override
  State<OrdersMainScreen> createState() => _OrdersMainScreenState();
}

class _OrdersMainScreenState extends State<OrdersMainScreen> {
  bool _showAvailable = true;
  StreamSubscription? _historyTabSub;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final homeCubit = context.read<HomeCubit>();

      // 👇 Subscribe to the stream for future requests (screen already visible)
      _historyTabSub = homeCubit.onHistoryTabRequested.listen((_) {
        if (mounted) setState(() => _showAvailable = false);
      });

      // 👇 Handle requests that fired before this screen was listening
      if (homeCubit.pendingHistoryTab) {
        homeCubit.consumePendingHistoryTab();
        if (mounted) setState(() => _showAvailable = false);
      }
    });
  }

  @override
  void dispose() {
    _historyTabSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.kBackgroundColor,
      body: Column(
        children: [
          // ── Toggle ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: OrderToggleButton(
                      active: _showAvailable,
                      onToggle: (isAvailable) =>
                          setState(() => _showAvailable = isAvailable),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Content ───────────────────────────────────────────────────
          Expanded(
            child: IndexedStack(
              index: _showAvailable ? 0 : 1,
              children: const [
                AvailableOrdersScreen(),
                OrderHistoryScreen(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}