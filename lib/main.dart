import 'dart:developer';
import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:floating_draggable_widget/floating_draggable_widget.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:tawreedat_go/features/addresses/data/repo/address_repo.dart';
import 'package:tawreedat_go/features/orders/manager/order_cubit.dart';
import 'package:tawreedat_go/features/wallet/manager/wallet_cubit.dart';
import 'package:url_launcher/url_launcher.dart';
import 'core/connectivity/connectivity_manager.dart';
import 'core/connectivity/network_aware_widget.dart';
import 'core/connectivity/offline_screen.dart';
import 'core/error/config.dart';
import 'core/error/handler.dart';
import 'core/error/restart_widget.dart';
import 'core/utils/api_client.dart';
import 'core/utils/app_dynamic_settings.dart';
import 'core/utils/constants.dart';
import 'core/utils/secure_storage_service.dart';
import 'core/style/app_colors.dart';
import 'core/widgets/animated_support_fab.dart';
import 'core/widgets/loading_screen.dart';
import 'features/addresses/data/data_source/address_remote_data_source.dart';
import 'features/addresses/manager/address_cubit.dart';
import 'features/auth/data/data_sources/profile_remote_data_source.dart';
import 'features/auth/data/repositories/auth_repository.dart';
import 'features/auth/data/repositories/profile_repository.dart';
import 'features/auth/manager/profile_cubit.dart';
import 'features/notifications/manager/notification_services.dart';
import 'features/static_text/app_dynamic_info.dart';
import 'features/wallet/data/data_source/wallet_remote_data_source.dart';
import 'features/wallet/data/repositories/wallet_repo.dart';
import 'routes/app_router.dart';
import 'features/auth/data/data_sources/auth_remote_data_source.dart';
import 'features/auth/manager/auth_cubit.dart';
import 'l10n/app_localizations.dart';
import 'l10n/manager/locale_cubit.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();
final ValueNotifier<bool> showFloatingButton = ValueNotifier(true);
final ValueNotifier<int> notificationDialogTrigger = ValueNotifier(0);

/// Payload from a notification tap that arrived before the home screen was
/// ready. HomeLayout checks this on first build and consumes it.
Map<String, dynamic>? pendingNotificationData;

/// Set to true to show the notifications dialog once HomeLayout is mounted.
bool shouldShowNotificationDialog = false;

// ── Background message handler (must be top-level) ────────────────────────────
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  log('📬 Background message received: ${message.messageId}');
}

Future<void> main() async {
  // ✅ Initialize error handler FIRST (before ensureInitialized)
  GlobalErrorHandler.initialize(
    config: const ErrorScreenConfig(
      title: 'عذراً! حدث خطأ ما',
      fallbackMessage: 'واجهنا خطأ غير متوقع يرجى إعادة تشغيل التطبيق للمتابعة',
      buttonText: 'إعادة التشغيل',
      backgroundColor: Color(0xFFFAFAFA),
      textColor: Color(0xFF1A1A1A),
      buttonColor: Colors.orange,
      buttonTextColor: Colors.white,
      assetPath: 'assets/images/loading.svg',
      assetType: ErrorAssetType.svg,
      showDetailsInDebug: true,
    ),
    errorLogger: (error, stackTrace) {
      log('🔴 Error: $error');
      log('Stack: $stackTrace');
    },
  );

  // ✅ Run app with error handling - ALL initialization goes in onBeforeRunApp
  GlobalErrorHandler.runAppWithErrorHandling(
    RestartWidget(child: const MyAppWrapper()),
    onBeforeRunApp: () async {
      // All initialization happens here, inside the error-handling zone

      // Initialize Firebase with error handling
      await _initializeFirebase();

      // ✅ Initialize Notifications AFTER Firebase
      await _initializeNotifications();

      // Initialize Google Sign-In
      try {
        await GoogleSignIn.instance.initialize(
          serverClientId:
              '644970780839-jevk4ojdbj232uvk66na27et844iip8o.apps.googleusercontent.com',
        );
      } catch (e) {
        log('⚠️ Google Sign-In initialization failed: $e');
        // Continue app initialization even if Google Sign-In fails
      }

      // Enable Hybrid Composition for Android Google Maps
      AndroidGoogleMapsFlutter.useAndroidViewSurface = true;

      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
      assert(
        AppConstants.googleMapsApiKey.isNotEmpty,
        'MAPS_API_KEY is not set. Add --dart-define=MAPS_API_KEY=... to your run config.',
      );
      ApiClient.instance.init();
      await ConnectivityManager.instance.init();
      if (ConnectivityManager.instance.isConnected) {
        await AppSettings().load();
        await AppInfoManager().loadAppInfo();
      }
    },
  );
}

Future<void> _initializeFirebase() async {
  try {
    await Firebase.initializeApp();
    log('✅ Firebase initialized successfully');
  } catch (e) {
    log('⚠️ Firebase initialization failed: $e');
    if (e.toString().contains('FirebaseApp') ||
        e.toString().contains('duplicate') ||
        e.toString().contains('no Firebase App')) {
      try {
        final app = Firebase.app();
        log('✅ Firebase app already exists: ${app.name}');
        return;
      } catch (_) {
        log('⚠️ Running without Firebase services');
      }
    }
  }
}

Future<void> _initializeNotifications() async {
  try {
    await NotificationService.initialize();
    log('✅ Local notifications initialized');
    await _initializeFirebaseMessaging();
    log('✅ Firebase Messaging initialized');
  } catch (e) {
    log('⚠️ Notification initialization failed: $e');
  }
}

Future<void> _initializeFirebaseMessaging() async {
  try {
    final messaging = FirebaseMessaging.instance;

    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      log('✅ User granted notification permission');
    } else if (settings.authorizationStatus ==
        AuthorizationStatus.provisional) {
      log('⚠️ User granted provisional notification permission');
    } else {
      log('❌ User declined notification permission');
      return;
    }

    final token = await messaging.getToken();
    log('📱 FCM Token: $token');

    messaging.onTokenRefresh.listen((newToken) async {
      log('🔄 FCM Token refreshed: $newToken');
      try {
        if (kAuthtoken.isNotEmpty) {
          await ApiClient.instance.dio.post(
            '/profile/fcm-token',
            data: {'fcmToken': newToken},
            options: Options(headers: {'Authorization': 'Bearer $kAuthtoken'}),
          );
          log('✅ Refreshed FCM token sent to backend');
        }
      } catch (e) {
        log('⚠️ Failed to update refreshed FCM token: $e');
      }
    });

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Foreground FCM messages → show local notification
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      log('📬 Foreground message: ${message.messageId}');
      if (message.notification != null) {
        NotificationService.showNotification(
          message.notification!.title ?? 'New Notification',
          message.notification!.body ?? '',
          message.data,
        );
      }
    });

    // App was in background — user tapped the system notification
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      log('🔔 Notification tapped (background): ${message.messageId}');
      handleNotificationTap(message.data);
    });

    // App was terminated — user tapped the system notification
    final initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) {
      log('🚀 App opened from terminated state via notification');
      // Store as pending; HomeLayout will consume it after mounting.
      pendingNotificationData = initialMessage.data;
    }
  } catch (e) {
    log('⚠️ Firebase Messaging initialization failed: $e');
  }
}

/// Central entry-point for ALL notification taps (FCM background/terminated,
/// local notification tap from the OS notification centre).
///
/// Strategy:
///   • Navigate to /mainHome so HomeLayout is on screen.
///   • Store the payload so HomeLayout (or the dialog) can act on it.
///   • Set [shouldShowNotificationDialog] = true so HomeLayout opens the dialog.
void handleNotificationTap(Map<String, dynamic> data) {
  log('🔔 handleNotificationTap called');
  log('📦 Raw payload: $data');

  pendingNotificationData = data;
  shouldShowNotificationDialog = true;

  final context = rootNavigatorKey.currentContext;

  if (context == null) {
    log('⚠️ Context NULL — stored as pending, HomeLayout will consume it');
    return;
  }

  final currentUri = GoRouter.of(context)
      .routerDelegate
      .currentConfiguration
      .uri
      .toString();
  log('🧭 Current route: $currentUri');

  if (currentUri == '/mainHome') {
    log('🏠 Already on /mainHome — triggering HomeLayout listener');
    // ✅ Don't try to read HomeCubit/ProfileCubit from root context.
    // Flip the notifier; HomeLayout's listener will show the dialog
    // using its own scoped context where everything is available.
    shouldShowNotificationDialog = false;
    pendingNotificationData = null;
    notificationDialogTrigger.value++;          // ← triggers HomeLayout
  } else if (currentUri == '/splash' || currentUri == '/') {
    log('⏳ App initialising — dialog will show after HomeLayout mounts');
  } else {
    log('🚀 Navigating to /mainHome');
    context.go('/mainHome');
  }
}

// ✅ Wrapper widget to create router after initialization
class MyAppWrapper extends StatelessWidget {
  const MyAppWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<GoRouter>(
      future: createAppRouter(rootNavigatorKey: rootNavigatorKey),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              backgroundColor: AppColors.kBackgroundColor,
              body: const Center(child: LoadingScreen(isOne: true)),
            ),
          );
        }

        if (snapshot.hasError) {
          // This error will be caught by the error handler
          throw snapshot.error!;
        }

        if (!snapshot.hasData) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              backgroundColor: AppColors.kBackgroundColor,
              body: const Center(child: Text('Failed to initialize router')),
            ),
          );
        }

        return MyApp(router: snapshot.data!);
      },
    );
  }
}

class MyApp extends StatefulWidget {
  final GoRouter router;

  const MyApp({super.key, required this.router});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (pendingNotificationData != null) {
        handleNotificationTap(pendingNotificationData!);
        pendingNotificationData = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final profileRepository = ProfileRepository(ProfileRemoteDataSource());
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) {
            final cubit = LocaleCubit(SecureStorageService());
            cubit.profileRepository = profileRepository;

            LocaleManager.cubit = cubit;
            return cubit;
          },
        ),
        BlocProvider<AuthCubit>(
          create: (_) => AuthCubit(
            AuthRepository(AuthRemoteDataSource(), SecureStorageService()),
          ),
        ),
        BlocProvider<ProfileCubit>(
          create: (_) => ProfileCubit(
            ProfileRepository(ProfileRemoteDataSource()),
            AuthRepository(AuthRemoteDataSource(), SecureStorageService()),
          ),
        ),

        BlocProvider<OrderCubit>(create: (_) => OrderCubit()),

        BlocProvider<AddressCubit>(
          create: (_) => AddressCubit(
            repository: AddressRepository(
              remoteDataSource: AddressRemoteDataSource(),
            ),
          ),
        ),
        BlocProvider<WalletCubit>(
          create: (_) => WalletCubit(
            repository: WalletRepository(
              remoteDataSource: WalletRemoteDataSource(),
            ),
          ),
        ),
      ],
      child: BlocBuilder<LocaleCubit, LocaleState>(
        builder: (context, state) {
          return Directionality(
            textDirection: state.locale.languageCode == 'ar'
                ? TextDirection.rtl
                : TextDirection.ltr,
            child: ValueListenableBuilder<bool>(
              valueListenable: showFloatingButton,
              builder: (context, show, child) {
                final mainScreenWidget= NetworkAwareWidget(
                  offlineWidget: OfflineScreen(),
                  child: MaterialApp.router(
                    routerConfig: widget.router,
                    debugShowCheckedModeBanner: false,
                    builder: (context, child) {
                      final mediaQuery = MediaQuery.of(context);

                      return MediaQuery(
                        data: mediaQuery.copyWith(
                          textScaler: mediaQuery.textScaler.clamp(
                            maxScaleFactor: 1.1,
                          ),
                        ),
                        child: child!,
                      );
                    },
                    localizationsDelegates: const [
                      AppLocalizations.delegate,
                      GlobalMaterialLocalizations.delegate,
                      GlobalWidgetsLocalizations.delegate,
                      GlobalCupertinoLocalizations.delegate,
                    ],
                    supportedLocales: const [Locale('en'), Locale('ar')],
                    locale: state.locale,
                    title: 'Tawreedat',
                    theme: ThemeData(
                      pageTransitionsTheme: PageTransitionsTheme(
                        builders: {
                          TargetPlatform.android:
                          CupertinoPageTransitionsBuilder(),
                          TargetPlatform.iOS:
                          CupertinoPageTransitionsBuilder(),
                        },
                      ),
                      cupertinoOverrideTheme: const CupertinoThemeData(
                        primaryColor: AppColors.kSecondaryColor,
                      ),
                      appBarTheme: AppBarTheme(
                        backgroundColor: AppColors.kBackgroundColor,
                        elevation: 0,
                      ),
                      elevatedButtonTheme: ElevatedButtonThemeData(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.kSecondaryColor,
                          foregroundColor: AppColors.kPrimaryColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                      scaffoldBackgroundColor: AppColors.kBackgroundColor,
                      textTheme: Theme.of(
                        context,
                      ).textTheme.apply(fontFamily: 'Cairo'),
                      primaryColor: AppColors.kPrimaryColor,
                    ),
                  ),
                );
                if (!show) {
                  // On map screen — render without FloatingDraggableWidget entirely
                  return mainScreenWidget;
                }
                return FloatingDraggableWidget(
                  floatingWidget: show
                      ? Container(
                          decoration: BoxDecoration(
                            color: AppColors.kSecondaryColor.withValues(
                              alpha: 0.8,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () {
                              launchUrl(
                                Uri.parse(
                                  "https://wa.me/${AppInfoManager().data!.supportNumber.replaceAll(' ', '')}",
                                ),
                                mode: LaunchMode.externalApplication,
                              );
                            },
                            child: AnimatedFAB(),
                          ),
                        )
                      : const SizedBox.shrink(),
                  // ← invisible, no gesture surface
                  floatingWidgetWidth: show ? 40 : 0,
                  floatingWidgetHeight: show ? 40 : 0,
                  dy: 400,
                  autoAlign: true,
                  autoAlignType: AlignmentType.both,
                  mainScreenWidget: mainScreenWidget,
                );
              },
            ),
          );
        },
      ),
    );
  }
}
