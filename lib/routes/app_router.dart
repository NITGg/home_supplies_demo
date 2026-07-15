import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:tawreedat_courier/features/wallet/presentation/payment_success_screen.dart';
import 'package:tawreedat_courier/features/wallet/presentation/penalties_screen.dart';
import 'package:tawreedat_courier/features/wallet/presentation/topup_screen.dart';
import 'package:tawreedat_courier/features/wallet/presentation/transaction_history_screen.dart';
import 'package:tawreedat_courier/features/wallet/presentation/upaid_commissions_screen.dart';
import '../core/utils/check_for_updates.dart';
import '../core/utils/logger.dart';
import '../core/widgets/loading_screen.dart';
import '../features/auth/data/models/social_registration_data.dart';
import '../features/auth/presentation/pages/account_otp_verification_screen.dart';
import '../features/auth/presentation/pages/change_phone_screen.dart';
import '../features/auth/presentation/pages/forgot_password_v2.dart';
import '../features/auth/presentation/pages/new_password_v2.dart';
import '../features/auth/presentation/pages/login_screen.dart';
import '../features/auth/presentation/pages/profile_screen.dart';
import '../features/auth/presentation/pages/register_screen.dart';
import '../features/coupons/presentation/coupons_screen.dart';
import '../features/home/layout/presentation/drawer_pages/faq_page.dart';
import '../features/home/layout/presentation/drawer_pages/privacy_page.dart';
import '../features/home/layout/presentation/drawer_pages/terms_page.dart';
import '../features/home/layout/presentation/home_layout.dart';
import '../features/onboarding/onboarding.dart';
import '../features/orders/data/models/orders_model.dart';
import '../features/orders/presentation/order_details/order_details_screen.dart';
import '../features/orders/presentation/qr_code_screen.dart';
import '../core/utils/secure_storage_service.dart';
import '../features/points/presentation/points_screen.dart';
import '../features/reviews/data/data_source/reviews_remote_data_source.dart';
import '../features/reviews/data/repositories/reviews_repo.dart';
import '../features/reviews/manager/reviews_cubit.dart';
import '../features/reviews/presentation/reviews_screen.dart';
import '../features/stats/presentation/earning_history_screen.dart';
import '../features/wallet/presentation/manual_topup_screen.dart';
import '../features/wallet/presentation/paymob_webview.dart';
import '../features/wallet/presentation/wallet_screen.dart';

Future<GoRouter> createAppRouter({
  required GlobalKey<NavigatorState> rootNavigatorKey,
}) async {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/splash',

    // Silently ignore any unknown route (e.g. /maintenance from FCM payload).
    // Our own handleNotificationTap logic handles notification navigation.
    onException: (_, __, ___) {},

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
                  token = await storage.getToken();
                  shouldOnboard = await storage.shouldShowOnboarding();
                } catch (e) {
                  dLog(
                    '⚠️ SecureStorage corrupted (Keystore invalidated?), clearing: $e',
                  );
                  try {
                    await storage.clearAll();
                  } catch (_) {}
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
        path: '/FaqPage',
        name: 'FaqPage',
        builder: (context, state) => FaqPage(),
      ),
      GoRoute(
        path: '/EarningsHistoryScreen',
        name: 'EarningsHistoryScreen',
        builder: (context, state) => EarningsHistoryScreen(),
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
        path: '/ProfileScreen',
        name: 'ProfileScreen',
        builder: (context, state) => const ProfileScreen(),
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
            path: '/ReviewsScreen',
            name: 'ReviewsScreen',
            builder: (context, state) => BlocProvider(
              create: (_) =>
                  ReviewsCubit(ReviewsRepository(ReviewsRemoteDataSource())),
              child: const ReviewsScreen(),
            ),
          ),
          GoRoute(
            path: '/WalletScreen',
            builder: (context, state) => const WalletScreen(),
          ),
          GoRoute(
            path: '/wallet/coupons',
            builder: (context, state) {
              final extra = state.extra as Map<String, dynamic>?;
              final initialTab = extra?['initialTab'] as int? ?? 0;
              return CouponsScreen(initialTab: initialTab);
            },
          ),
          GoRoute(
            path: '/wallet/unpaid-commissions',
            builder: (context, state) => const UnpaidCommissionsScreen(),
          ),
          GoRoute(
            path: '/wallet/topup',
            builder: (context, state) => const TopUpScreen(),
          ),
          GoRoute(
            path: '/wallet/topup/success',
            builder: (context, state) {
              final extra = state.extra as Map<String, dynamic>?;
              if (extra == null) {
                return const Scaffold(
                  body: Center(child: Text('No transaction data provided')),
                );
              }
              return PaymentSuccessScreen(
                amount: extra['amount'] as int,
                transactionId: extra['transactionId'] as int,
              );
            },
          ),
          GoRoute(
            path: '/wallet/topup/payment',
            builder: (context, state) {
              final extra = state.extra as Map<String, dynamic>;
              return PaymobWebViewScreen(
                paymentUrl: extra['paymentUrl'] as String,
                amount: extra['amount'] as int,
                transactionId: extra['transactionId'] as int,
                provider: extra['provider'] as String? ?? 'paymob',
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
            path: '/wallet/points',
            builder: (context, state) {
              return PointsScreen();
            },
          ),
          GoRoute(
            path: '/wallet/transactions',
            builder: (context, state) => const TransactionHistoryScreen(),
          ),
          GoRoute(
            path: '/auth/register',
            builder: (context, state) => RegisterScreen(
              socialData: state.extra as SocialRegistrationData?,
            ),
          ),
          // ── New multi-channel OTP / password-reset routes (not yet wired) ──
          // Nothing currently navigates to these; built ahead of time so the
          // new flow can be switched on quickly once the backend requires it.
          //
          // TO ACTIVATE LATER:
          // 1. Forgot password: point the login screen's "forgot password"
          //    action (currently commented out in login_screen.dart) at
          //    '/auth/forgot-password-v2' instead of '/auth/forgot-password'.
          //    ForgotPasswordScreenV2 lets the user pick phone/email and
          //    calls AuthCubit.requestPasswordResetByChannel(), which on
          //    AuthForgotPasswordChannelOtpSent navigates here to
          //    '/auth/new-password-v2' (combined OTP + new password screen).
          //    actually make it with phone only as we removed email option
          // 2. Registration OTP: after register()/login() emits
          //    AuthOtpRequired, navigate to '/auth/verify-account-otp' with
          //    extra: {'destination': <phone or email>, 'channel': 'phone'|'email'}
          //    instead of '/auth/verify-otp'. AccountOtpVerificationScreen
          //    calls AuthCubit.verifyAccountOtp(); on AuthNextOtpRequired it
          //    auto-chains to the next channel, on AuthSuccess it goes home.
          //    note that after register we will always need to verify phone and in log in if we get 401 we will need to verify phone.
          // 3. AppSettings.otp_length / otp_resend_duration_seconds are
          //    already fetched at startup via loadPublicSettings() (see
          //    app_dynamic_settings.dart) and used by these new screens —
          //    no extra wiring needed for those.
          // 4. Once switched over, the old screens/routes/cubit methods
          //    (otp_screen.dart, forgot_password.dart, reset_password.dart,
          //    verifyPhoneOtp/resendPhoneOtp/forgotPassword/resetPassword)
          //    can be removed if no longer needed.
          GoRoute(
            path: '/auth/verify-account-otp',
            builder: (context, state) {
              final data = state.extra as Map<String, dynamic>;
              return AccountOtpVerificationScreen(
                destination: data['destination'] as String,
                channel: data['channel'] as String,
              );
            },
          ),
          GoRoute(
            path: '/auth/forgot-password-v2',
            builder: (context, state) => const ForgotPasswordScreenV2(),
          ),
          GoRoute(
            path: '/auth/new-password-v2',
            builder: (context, state) {
              final data = state.extra as Map<String, dynamic>;
              return NewPasswordScreenV2(
                identifier: data['identifier'] as String,
                channel: data['channel'] as String,
                destination: data['destination'] as String,
              );
            },
          ),
          GoRoute(
            path: '/auth/loginDeleted',
            name: 'loginDeleted',
            builder: (context, state) =>
                const LoginScreen(isAccountDeleted: true),
          ),
          GoRoute(
            path: '/profile/change-phone',
            builder: (context, state) => const ChangePhoneScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/mainHome',
        name: 'mainHome',
        builder: (context, state) => const HomeLayout(),
      ),
      GoRoute(
        path: '/orders/details',
        name: 'orderDetails',
        builder: (context, state) {
          final order = state.extra as OrderModel;
          return OrderDetailsScreen(order: order);
        },
      ),
      GoRoute(
        path: '/orders/qr-code',
        name: 'qrCode',
        builder: (context, state) {
          final data = state.extra as Map<String, dynamic>;
          return QrCodeScreen(
            qrCodeModel: data['qrCodeModel'] as QrCodeModel,
            orderId: data['orderId'] as int,
            actualPrice: data['actualPrice'] as double,
            courierId: data['courierId'] as int,
            customerId: data['customerId'] as int,
          );
        },
      ),
    ],
  );
}

class _AuthRouteShell extends StatelessWidget {
  const _AuthRouteShell();

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
