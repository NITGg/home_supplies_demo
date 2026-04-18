import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../core/utils/check_for_updates.dart';
import '../core/widgets/loading_screen.dart';
import '../features/addresses/manager/address_cubit.dart';
import '../features/addresses/presentation/address_management_screen.dart';
import '../features/auth/presentation/pages/auth_otp_screen.dart';
import '../features/auth/presentation/pages/forgot_password_screen.dart';
import '../features/auth/presentation/pages/login_screen.dart';
import '../features/auth/presentation/pages/new_password_screen.dart';
import '../features/auth/presentation/pages/profile_screen.dart';
import '../features/auth/presentation/pages/register_screen.dart';
import '../features/categories/data/models/category_models.dart';
import '../features/categories/presentation/category_details_screen.dart';
import '../features/home/drawer_pages/faq_page.dart';
import '../features/home/drawer_pages/privacy_page.dart';
import '../features/home/drawer_pages/support_page.dart';
import '../features/home/drawer_pages/terms_page.dart';
import '../features/home/layout/presentation/home_layout.dart';
import '../features/know_us_more/know_us_more.dart';
import '../features/onboarding/onboarding.dart';
import '../core/utils/secure_storage_service.dart';
import '../features/products/data/models/product_model.dart';
import '../features/products/presentation/product_details_screen.dart';
import '../features/referral/referral_screen.dart';
import '../features/reviews/data/data_source/reviews_remote_data_source.dart';
import '../features/reviews/data/repositories/reviews_repo.dart';
import '../features/reviews/manager/reviews_cubit.dart';
import '../features/reviews/presentation/reviews_screen.dart';
import '../features/wallet/presentation/manual_topup_screen.dart';
import '../features/wallet/presentation/payment_success_screen.dart';
import '../features/wallet/presentation/paymob_webview.dart';
import '../features/wallet/presentation/penalties_screen.dart';
import '../features/wallet/presentation/topup_screen.dart';
import '../features/wallet/presentation/transaction_history_screen.dart';
import '../features/wallet/presentation/wallet_screen.dart';

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
            bool updateShown = await checkForUpdate(context);
            if (!updateShown) {
              final storage = SecureStorageService();
              final token = await storage.getToken();
              final destination = (token != null && token.isNotEmpty)
                  ? '/mainHome'
                  : await storage.shouldShowOnboarding()
                  ? '/onboarding'
                  : '/auth/login';
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
      GoRoute(
        path: '/ProfileScreen',
        name: 'ProfileScreen',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/ReferralQrScreen',
        name: 'ReferralQrScreen',
        builder: (context, state) => const ReferralQrScreen(),
      ),
      GoRoute(
        path: '/KnowUsMoreScreen',
        name: 'KnowUsMoreScreen',
        builder: (context, state) => const KnowUsMoreScreen(),
      ),
      GoRoute(
        path: '/ReviewsScreen',
        name: 'ReviewsScreen',
        builder: (context, state) => BlocProvider(
          create: (_) =>
              ReviewsCubit(ReviewsRepository(ReviewsRemoteDataSource())),
          child: const ReviewsScreen(),
        ),
      ),
      ShellRoute(
        builder: (context, state, child) => child,
        routes: [
          GoRoute(
            path: '/auth/login',
            name: 'login',
            builder: (context, state) => const LoginScreen(),
          ),
          GoRoute(
            path: '/auth/loginDeleted',
            name: 'loginDeleted',
            builder: (context, state) =>
                const LoginScreen(isAccountDeleted: true),
          ),
          GoRoute(
            path: '/auth/register',
            name: 'register',
            builder: (context, state) => RegisterScreen(),
          ),
          GoRoute(
            path: '/auth/forgot-password',
            builder: (context, state) => const ForgotPasswordScreen(),
          ),
          GoRoute(
            path: '/auth/verify-otp',
            builder: (context, state) {
              final extra = state.extra as Map<String, dynamic>;
              return OtpVerificationScreen(
                destination: extra['destination'] as String,
                isPasswordReset: (extra['isPasswordReset'] as bool?) ?? false,
              );
            },
          ),
          GoRoute(
            path: '/auth/new-password',
            builder: (context, state) {
              final extra = state.extra as Map<String, dynamic>;
              return NewPasswordScreen(otp: extra['otp'] as String);
            },
          ),
          GoRoute(
            path: '/addressesManagement',
            name: 'addressesManagement',
            builder: (context, state) => BlocProvider(
              create: (_) => AddressCubit(),
              child: const AddressManagementScreen(),
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/FaqPage',
        name: 'FaqPage',
        builder: (context, state) => FaqPage(),
      ),
      GoRoute(
        path: '/Terms',
        name: 'Terms',
        builder: (context, state) => TermsPage(),
      ),
      GoRoute(
        path: '/SupportPage',
        name: 'SupportPage',
        builder: (context, state) => SupportPage(),
      ),
      GoRoute(
        path: '/PrivacyPage',
        name: 'PrivacyPage',
        builder: (context, state) => PrivacyPage(),
      ),
      GoRoute(
        path: '/WalletScreen',
        name: 'WalletScreen',
        builder: (context, state) => WalletScreen(),
      ),
      GoRoute(
        path: '/wallet/topup',
        builder: (context, state) => const TopUpScreen(),
      ),
      GoRoute(
        path: '/wallet/topup/payment',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>;
          return PaymobWebViewScreen(
            paymentUrl: extra['paymentUrl'] as String,
            amount: extra['amount'] as int,
            transactionId: extra['transactionId'] as int,
          );
        },
      ),
      GoRoute(
        path: '/wallet/topup/success',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>;
          return PaymentSuccessScreen(
            amount: extra['amount'] as int,
            transactionId: extra['transactionId'] as int,
          );
        },
      ),
      GoRoute(
        path: '/wallet/topup/manual',
        builder: (context, state) {
          final amount = state.extra as int;
          return ManualTopUpScreen(amount: amount);
        },
      ),
      GoRoute(
        path: '/wallet/penalties',
        builder: (context, state) => const PenaltiesScreen(),
      ),
      GoRoute(
        path: '/wallet/transactions',
        builder: (context, state) => const TransactionHistoryScreen(),
      ),
      GoRoute(
        path: '/mainHome',
        name: 'mainHome',
        builder: (context, state) => const HomeLayout(),
      ),

      GoRoute(
        path: '/categories/:id',
        builder: (context, state) => CategoryDetailScreen(
          categoryId: int.parse(state.pathParameters['id']!),
          category: state.extra as CategoryModel?,
        ),
      ),
      GoRoute(
        path: '/products/:id',
        builder: (context, state) => ProductDetailScreen(
          productId: int.parse(state.pathParameters['id']!),
          product: state.extra as ProductModel?,
        ),
      ),
    ],
    errorBuilder: (context, state) {
      log('❌ 404 Error - Location: ${state.uri}');
      return Scaffold(body: Center(child: LoadingScreen()));
    },
  );
}
