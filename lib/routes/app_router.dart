
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:tawreedat_go/features/products/presentation/all_best_selling_screen.dart';
import 'package:tawreedat_go/features/products/presentation/all_offered_screen.dart';
import '../core/utils/check_for_updates.dart';
import '../core/utils/logger.dart';
import '../core/widgets/loading_screen.dart';
import '../features/addresses/presentation/default_address_chip.dart';
import '../features/auth/presentation/pages/auth_otp_screen.dart';
import '../features/auth/presentation/pages/forgot_password_screen.dart';
import '../features/auth/presentation/pages/login_screen.dart';
import '../features/auth/presentation/pages/new_password_screen.dart';
import '../features/auth/presentation/pages/profile_screen.dart';
import '../features/auth/presentation/pages/register_screen.dart';
import '../features/cart/presentation/cart_screen.dart';
import '../features/categories/data/models/category_models.dart';
import '../features/categories/presentation/all_categories_screen.dart';
import '../features/categories/presentation/category_details_screen.dart';
import '../features/chat/config/chat_injection.dart';
import '../features/home/drawer_pages/faq_page.dart';
import '../features/home/drawer_pages/privacy_page.dart';
import '../features/home/drawer_pages/support_page.dart';
import '../features/home/drawer_pages/terms_page.dart';
import '../features/home/layout/presentation/home_layout.dart';
import '../features/know_us_more/know_us_more.dart';
import '../features/onboarding/onboarding.dart';
import '../core/utils/secure_storage_service.dart';
import '../features/points/presentation/points_screen.dart';
import '../features/products/data/models/product_model.dart';
import '../features/products/presentation/all_featured_screen.dart';
import '../features/products/presentation/all_last_purchased_screen.dart';
import '../features/products/presentation/product_details_screen.dart';
import '../features/referral/referral_screen.dart';
import '../features/reviews/data/data_source/reviews_remote_data_source.dart';
import '../features/reviews/data/repositories/reviews_repo.dart';
import '../features/reviews/manager/reviews_cubit.dart';
import '../features/reviews/presentation/reviews_screen.dart';
import '../features/suppliers/data/models/supplier_models.dart';
import '../features/suppliers/presentation/supplier_details_screen.dart';
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
    observers: [addressChipRouteObserver],
    routes: [
      GoRoute(
        path: '/splash',
        name: 'splash',
        builder: (context, state) => LoadingScreen(
          isSplash: true,
          onComplete: () async {
            try {
              bool updateShown = await checkForUpdate(context);
              if (!updateShown) {
                final storage = SecureStorageService();

                String? token;
                bool shouldOnboard = true;

                try {
                  // On Android, a reinstall/update invalidates Keystore keys
                  // while the encrypted prefs file survives → crypto exception.
                  // Catch it, wipe the stale data, and continue as a fresh install.
                  token = await storage.getToken();
                  shouldOnboard = await storage.shouldShowOnboarding();
                } catch (e) {
                  dLog('⚠️ SecureStorage corrupted (Keystore invalidated?), clearing: $e');
                  try {
                    await storage.clearAll();
                  } catch (_) {}
                  // token stays null → will go to onboarding/login below
                }

                final destination = (token != null && token.isNotEmpty)
                    ? '/mainHome'
                    : shouldOnboard
                    ? '/onboarding'
                    : '/auth/login';

                if (context.mounted) {
                  GoRouter.of(context).go(destination);
                }
              }
            } catch (e) {
              // Last-resort fallback — never leave the user stuck on splash.
              dLog('⚠️ Splash onComplete error: $e');
              if (context.mounted) {
                GoRouter.of(context).go('/auth/login');
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
            path: '/suppliers/:id',
            builder: (context, state) {
              // extra is always a Map passed from SuppliersStripWidget
              final extra = state.extra as Map<String, dynamic>? ?? {};
              final supplier = extra['supplier'] as SupplierModel?;
              final filterCategoryId = extra['filterCategoryId'] as int?;
              final id = int.parse(state.pathParameters['id']!);
              return SupplierDetailScreen(
                supplier: supplier,
                supplierId: id,
                filterCategoryId:
                    filterCategoryId, // null = home (all), non-null = category filtered
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
          // GoRoute(
          //   path: '/addressesManagement',
          //   name: 'addressesManagement',
          //   builder: (context, state) => BlocProvider(
          //     create: (_) => AddressCubit(),
          //     child: const AddressManagementScreen(),
          //   ),
          // ),
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
        path: '/wallet/points',
        builder: (context, state) {
          return PointsScreen();
        },
      ),
      GoRoute(
        path: '/mainHome',
        name: 'mainHome',
        builder: (context, state) =>
            ChatInboxProvider(child: const HomeLayout()),
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
      GoRoute(path: '/cart', builder: (context, state) => const CartScreen()),
      GoRoute(
        path: '/categories',
        builder: (context, state) => const AllCategoriesScreen(),
      ),

      GoRoute(
        path: '/featured',
        builder: (context, state) => const AllFeaturedProductsScreen(),
      ),
      GoRoute(
        path: '/best-selling',
        builder: (context, state) => const AllBestSellingScreen(),
      ),
      GoRoute(
        path: '/offered',
        builder: (context, state) => const AllOfferedScreen(),
      ),

      GoRoute(
        path: '/last-purchased',
        builder: (context, state) => const AllLastPurchasedScreen(),
      ),
    ],
    errorBuilder: (context, state) {
      dLog('❌ 404 Error - Location: ${state.uri}');
      return Scaffold(body: Center(child: LoadingScreen()));
    },
  );
}
