import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:tawreedat/core/widgets/loading_screen.dart';
import 'package:tawreedat/features/home/layout/pages/product_page/data/products_model.dart';
import '../features/auth/data/models/user_profile_model.dart';
import '../features/auth/data/repositories/auth_repository.dart';
import '../features/auth/presentation/pages/login_screen.dart';
import '../features/auth/presentation/pages/register_screen.dart';
import '../features/favourites/presentation/favourites_page.dart';
import '../features/home/layout/pages/cart_page/presentation/cart_page.dart';
import '../features/home/layout/pages/cart_page/presentation/invoice_page.dart';
import '../features/home/layout/pages/cart_page/presentation/payment_details_page.dart';
import '../features/home/layout/pages/product_details_page/manager/review_cubit.dart';
import '../features/home/layout/pages/product_details_page/repositories/reviews_repo.dart';
import '../features/home/layout/pages/product_page/data/products_repo.dart';
import '../features/home/layout/pages/product_page/manager/product_cubit.dart';
import '../features/home/layout/pages/product_page/presentation/products_page.dart';
import '../features/home/layout/pages/drawer_pages/faq_page.dart';
import '../features/home/layout/pages/drawer_pages/privacy_page.dart';
import '../features/home/layout/pages/drawer_pages/support_page.dart';
import '../features/home/layout/pages/drawer_pages/terms_page.dart';
import '../features/home/layout/pages/product_details_page/presentation/product_detail_page.dart';
import '../features/home/layout/pages/profile_page/presentation/my_data_page.dart';
import '../features/home/layout/pages/search/data/repositories/search_repository.dart';
import '../features/home/layout/pages/search/manager/search_cubit.dart';
import '../features/home/layout/pages/search/presentation/search_page.dart';
import '../features/home/layout/presentation/home_layout.dart';
import '../features/onboarding/onboarding.dart';
import '../features/order/presentation/my_orders_page.dart';
import '../features/points/points_page.dart';
import '../core/utils/secure_storage_service.dart';
import '../core/utils/check_for_updates.dart';

Future<GoRouter> createAppRouter({
  required GlobalKey<NavigatorState> rootNavigatorKey,
}) async {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/splash',
    routes: [
      GoRoute(
        path: '/splash',
        name: 'splash',
        builder: (context, state) => LoadingScreen(
          isSplash: true,
          onComplete: () async {
            // First, check for update
            bool updateShown = await checkForUpdate(context);

            // Only navigate if update was NOT shown
            if (!updateShown) {
              final storage = SecureStorageService();
              final token = await storage.getToken();
              kAuthtoken = await storage.getToken() ?? '';
              var prof = await SecureStorageService().getUserProfile();
              if (prof != null) {
                kUserId = UserProfileModel.fromJson(prof).id;
              }
              final destination = (token != null && token.isNotEmpty)
                  ? '/mainHome'
                  : await storage.shouldShowOnboarding()
                  ? '/onboarding'
                  : '/mainHome';
              if (context.mounted) {
                GoRouter.of(context).go(destination);
              }
            }
          },
        ),
      ),
      GoRoute(
        path: '/onboarding',
        name: 'onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) {
          return child;
        },
        routes: [
          GoRoute(
            path: '/auth/login',
            name: 'login',
            builder: (context, state) => const LoginScreen(),
          ),
          GoRoute(
            path: '/auth/register',
            name: 'register',
            builder: (context, state) => RegisterScreen(),
          ),
          GoRoute(
            path: '/auth/loginDeleted',
            name: 'loginDeleted',
            builder: (context, state) =>
                const LoginScreen(isAccountDeleted: true),
          ),
        ],
      ),
      GoRoute(
        path: '/mainHome',
        name: 'mainHome',
        builder: (context, state) => const HomeLayout(),
      ),
      GoRoute(
        path: '/cart',
        name: 'cart',
        builder: (context, state) => const CartPage(),
      ),
      // Updated route with proper path parameters and query parameters support
      GoRoute(
        path: '/products',
        name: 'ProductsPage',
        redirect: (context, state) {
          // Handle deep link query parameters
          final queryParams = state.uri.queryParameters;
          log('🔍 ProductsPage redirect - query params: $queryParams');

          if (queryParams.isNotEmpty && queryParams.containsKey('id')) {
            // Deep link case - allow navigation
            return null;
          }

          // Regular navigation case - allow navigation
          return null;
        },
        builder: (context, state) {
          // Try to get data from extra first (regular navigation)
          Map<String, dynamic> data = {};

          if (state.extra != null) {
            data = state.extra as Map<String, dynamic>;
            log('📦 Using data from extra: $data');
          } else {
            // Deep link case - get from query parameters
            final queryParams = state.uri.queryParameters;
            log('📦 Using data from query parameters: $queryParams');

            data = {
              'id': queryParams['id'] ?? '',
              'name': queryParams['name'] ?? '',
              'nameAr': queryParams['nameAr'],
              'imageUrl': queryParams['imageUrl'] ?? '',
              'iconUrl': queryParams['iconUrl'] ?? '',
              'description': queryParams['description'] ?? '',
              'descriptionAr': queryParams['descriptionAr'],
              'isBrand': queryParams['isBrand'] == 'true',
            };
          }

          return BlocProvider(
            create: (context) => ProductsCubit(ProductsRepository()),
            child: ProductsPage(
              subCategories: data['subCategories'] ?? [],
              name: Localizations.localeOf(context).languageCode == 'ar'
                  ? (data['nameAr'] != null &&
                            data['nameAr'].toString().isNotEmpty &&
                            data['nameAr'] != 'null'
                        ? data['nameAr']
                        : (data['name'] ?? ''))
                  : (data['name'] ?? ''),

              description: Localizations.localeOf(context).languageCode == 'ar'
                  ? (data['descriptionAr'] != null &&
                            data['descriptionAr'].toString().isNotEmpty &&
                            data['descriptionAr'] != 'null'
                        ? data['descriptionAr']
                        : (data['description'] ?? ''))
                  : (data['description'] ?? ''),
              imageUrl: data['imageUrl'] ?? '',
              iconUrl: data['iconUrl'] ?? '',
              id: data['id'] ?? '',
              isBrand: data['isBrand'] ?? false,
              isDeepLink: true,
            ),
          );
        },
      ),
      GoRoute(
        path: '/PaymentDetailsPage',
        name: 'PaymentDetailsPage',
        builder: (context, state) {
          final data = state.extra as Map<String, dynamic>;
          return PaymentDetailsPage(
            total: data['total'] ?? 0,
            nItems: data['nItems'] ?? '',
            quantity: data['quantity'] ?? '',
            items: data['items'],
          );
        },
      ),
      GoRoute(
        path: '/ProductDetailsPage',
        name: 'ProductDetailsPage',
        builder: (context, state) {
          final data = state.extra as ProductModel;
          return BlocProvider(
            create: (context) => ReviewCubit(ReviewsRepo()),
            child: ProductDetailPage(product: data),
          );
        },
      ),
      GoRoute(
        path: '/MyDataPage',
        name: 'MyDataPage',
        builder: (context, state) => const MyDataPage(),
      ),
      GoRoute(
        path: '/InvoicePage',
        name: 'InvoicePage',
        builder: (context, state) {
          final successful = state.extra as Map<String, dynamic>;
          return InvoicePage(
            successful: successful['successful'],
            order: successful['order'],
          );
        },
      ),
      GoRoute(
        path: '/Terms',
        name: 'Terms',
        builder: (context, state) => TermsPage(),
      ),
      GoRoute(
        path: '/PrivacyPage',
        name: 'PrivacyPage',
        builder: (context, state) => PrivacyPage(),
      ),
      GoRoute(
        path: '/Favourites',
        name: 'Favourites',
        builder: (context, state) => FavoritesPage(),
      ),
      GoRoute(
        path: '/SupportPage',
        name: 'SupportPage',
        builder: (context, state) => SupportPage(),
      ),
      GoRoute(
        path: '/FaqPage',
        name: 'FaqPage',
        builder: (context, state) => FaqPage(),
      ),
      GoRoute(
        path: '/PointsPage',
        name: 'PointsPage',
        builder: (context, state) => PointsPage(),
      ),
      GoRoute(
        path: '/Search',
        name: 'Search',
        builder: (context, state) => BlocProvider(
          create: (context) => SearchCubit(SearchRepository()),
          child: SearchPage(),
        ),
      ),
      GoRoute(
        path: '/my-orders',
        name: 'my-orders',
        builder: (context, state) {
          final userId = state.extra as String?;
          if (userId == null) {
            return const Scaffold(
              body: Center(child: Text('User ID required')),
            );
          }
          return MyOrdersPage(userId: userId);
        },
      ),
    ],
    errorBuilder: (context, state) {
      log('❌ 404 Error - Location: ${state.uri}');
      return Scaffold(body: Center(child: LoadingScreen()));
    },
  );
}

/// 🧩 Shell widget to group all auth-related routes under one BlocProvider
class _AuthRouteShell extends StatelessWidget {
  const _AuthRouteShell();

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
