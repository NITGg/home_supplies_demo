import 'package:flutter/material.dart';
import '../../../core/style/app_colors.dart';
import '../../../core/style/text_styles.dart';
import '../../../l10n/app_localizations.dart';
import 'available_orders_screen.dart';
import 'order_history_screen.dart';

class OrdersMainScreen extends StatefulWidget {
  const OrdersMainScreen({super.key});

  @override
  State<OrdersMainScreen> createState() => _OrdersMainScreenState();
}

class _OrdersMainScreenState extends State<OrdersMainScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppColors.kBackgroundColor,
      body: Column(
        children: [
          TabBar(
            controller: _tabController,
            labelColor: AppColors.kPrimaryColor,
            unselectedLabelColor: Colors.grey.shade600,
            labelStyle: AppTextStyles.bold14,
            unselectedLabelStyle: AppTextStyles.regular14,
            indicatorColor: AppColors.kPrimaryColor,
            indicatorWeight: 3,
            tabs: [
              Tab(icon: const Icon(Icons.list_alt), text: l10n.availableOrders),
              Tab(icon: const Icon(Icons.history), text: l10n.history),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [AvailableOrdersScreen(), OrderHistoryScreen()],
            ),
          ),
        ],
      ),
    );
  }
}
