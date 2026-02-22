import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../core/widgets/loading_screen.dart';
import '../features/addresses/manager/address_cubit.dart';
import '../features/addresses/presentation/address_management_screen.dart';
import '../features/auth/presentation/pages/login_screen.dart';
import '../features/auth/presentation/pages/profile_screen.dart';
import '../features/auth/presentation/pages/register_screen.dart';
import '../features/home/drawer_pages/faq_page.dart';
import '../features/home/drawer_pages/privacy_page.dart';
import '../features/home/drawer_pages/support_page.dart';
import '../features/home/drawer_pages/terms_page.dart';
import '../features/home/layout/presentation/home_layout.dart';
import '../features/onboarding/onboarding.dart';
import '../core/utils/secure_storage_service.dart';
import '../features/reviews/data/data_source/reviews_remote_data_source.dart';
import '../features/reviews/data/repositories/reviews_repo.dart';
import '../features/reviews/manager/reviews_cubit.dart';
import '../features/reviews/presentation/reviews_screen.dart';
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
            // First, check for update
            // bool updateShown = await checkForUpdate(context);
            bool updateShown = false;

            // Only navigate if update was NOT shown
            if (!updateShown) {
              final storage = SecureStorageService();
              final token = await storage.getToken();
              // kAuthtoken = await storage.getToken() ?? '';
              var prof = await SecureStorageService().getUserProfile();
              // if (prof != null) {
              //   kUserId = UserProfileModel.fromJson(prof).id;
              // }
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
        path: '/ReviewsScreen',
        name: 'ReviewsScreen',
        builder: (context, state) => BlocProvider(
          create: (_) =>
              ReviewsCubit(ReviewsRepository(ReviewsRemoteDataSource())),
          child: const ReviewsScreen(),
        ),
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
            path: '/addressesManagement',
            name: 'addressesManagement',
            builder: (context, state) => BlocProvider(
              create: (_) => AddressCubit(),
              child: const AddressManagementScreen(),
            ),
          ),
          // GoRoute(
          //   path: '/auth/verify-otp',
          //   builder: (context, state) {
          //     final phone = state.extra as String;
          //     return OtpVerificationScreen(
          //       phone: phone,
          //       isPasswordReset: false,
          //     );
          //   },
          // ),
          // GoRoute(
          //   path: '/auth/verify-otp-password-reset',
          //   builder: (context, state) {
          //     final phone = state.extra as String;
          //     return OtpVerificationScreen(phone: phone, isPasswordReset: true);
          //   },
          // ),
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
        path: '/mainHome',
        name: 'mainHome',
        builder: (context, state) => const HomeLayout(),
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
