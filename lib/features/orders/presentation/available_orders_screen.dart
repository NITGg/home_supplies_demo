import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:tawreedat_courier/features/orders/presentation/widgets/order_card.dart';
import '../../../core/style/app_colors.dart';
import '../../../core/style/text_styles.dart';
import '../../../core/widgets/loading_screen.dart';
import '../manager/orders_cubit.dart';
import '../manager/orders_states.dart';

class AvailableOrdersScreen extends StatefulWidget {
  const AvailableOrdersScreen({super.key});

  @override
  State<AvailableOrdersScreen> createState() => _AvailableOrdersScreenState();
}

class _AvailableOrdersScreenState extends State<AvailableOrdersScreen> {
  @override
  void initState() {
    super.initState();
    context.read<OrderCubit>().fetchAvailableOrders();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.kBackgroundColor,
      body: BlocConsumer<OrderCubit, OrderState>(
        listener: (context, state) {
          if (state is AvailableOrdersError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is AvailableOrdersLoading) {
            return const LoadingScreen(isOne: true);
          }

          if (state is AvailableOrdersLoaded) {
            if (state.orders.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.shopping_bag_outlined,
                      size: 80,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No available orders',
                      style: AppTextStyles.bold16.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Check back later for new orders',
                      style: AppTextStyles.regular14.copyWith(
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: () async {
                await context.read<OrderCubit>().fetchAvailableOrders();
              },
              color: AppColors.kPrimaryColor,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: state.orders.length,
                itemBuilder: (context, index) {
                  final order = state.orders[index];
                  return OrderCardWidget(
                    order: order,
                    onTap: () {
                      context.push('/orders/details', extra: order.id);
                    },
                  );
                },
              ),
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }
}
