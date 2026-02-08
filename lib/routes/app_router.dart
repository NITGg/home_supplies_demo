import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/widgets/loading_screen.dart';
import '../features/auth/presentation/pages/forgot_password.dart';
import '../features/auth/presentation/pages/login_screen.dart';
import '../features/auth/presentation/pages/otp_screen.dart';
import '../features/auth/presentation/pages/profile_screen.dart';
import '../features/auth/presentation/pages/register_screen.dart';
import '../features/auth/presentation/pages/reset_password.dart';
import '../features/home/layout/presentation/home_layout.dart';
import '../features/onboarding/onboarding.dart';
import '../features/orders/data/models/orders_model.dart';
import '../features/orders/presentation/order_details_screen.dart';
import '../features/orders/presentation/qr_code_screen.dart';
import '../core/utils/secure_storage_service.dart';

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
                  :
                    // await storage.shouldShowOnboarding()
                    //     ? '/onboarding'
                    //     :
                    '/auth/login';
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
            path: '/auth/verify-otp',
            builder: (context, state) {
              final phone = state.extra as String;
              return OtpVerificationScreen(
                phone: phone,
                isPasswordReset: false,
              );
            },
          ),
          GoRoute(
            path: '/auth/verify-otp-password-reset',
            builder: (context, state) {
              final phone = state.extra as String;
              return OtpVerificationScreen(phone: phone, isPasswordReset: true);
            },
          ),
          GoRoute(
            path: '/auth/forgot-password',
            builder: (context, state) => const ForgotPasswordScreen(),
          ),
          GoRoute(
            path: '/auth/new-password',
            builder: (context, state) {
              final data = state.extra as Map<String, String>;
              return NewPasswordScreen(
                phone: data['phone']!,
                otp: data['otp']!,
              );
            },
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

      // ============== ORDER ROUTES ==============
      GoRoute(
        path: '/orders/details',
        name: 'orderDetails',
        builder: (context, state) {
          final orderId = state.extra as int;
          return OrderDetailsScreen(orderId: orderId);
        },
      ),
      GoRoute(
        path: '/orders/qr-code',
        name: 'qrCode',
        builder: (context, state) {
          final qrCodeModel = state.extra as QrCodeModel;
          return QrCodeScreen(qrCodeModel: qrCodeModel);
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
