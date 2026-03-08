import 'dart:developer';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
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
import 'core/widgets/loading_screen.dart';
import 'features/addresses/data/data_source/address_remote_data_source.dart';
import 'features/addresses/manager/address_cubit.dart';
import 'features/auth/data/data_sources/profile_remote_data_source.dart';
import 'features/auth/data/repositories/auth_repository.dart';
import 'features/auth/data/repositories/profile_repository.dart';
import 'features/auth/manager/profile_cubit.dart';
import 'features/deep_links/deep_link_manager.dart';
import 'features/notifications/notification_services.dart';
import 'features/static_text/app_dynamic_info.dart';
import 'features/wallet/data/data_source/wallet_remote_data_source.dart';
import 'features/wallet/data/repositories/wallet_repo.dart';
import 'routes/app_router.dart';
import 'features/auth/data/data_sources/auth_remote_data_source.dart';
import 'features/auth/manager/auth_cubit.dart';
import 'l10n/app_localizations.dart';
import 'l10n/manager/locale_cubit.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();
Map<String, dynamic>? pendingNotificationData;
bool shouldShowNotificationDialog = false;

// ✅ Background message handler (MUST be top-level function)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  log('📬 Background message received: ${message.messageId}');
  log('Title: ${message.notification?.title}');
  log('Body: ${message.notification?.body}');
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

/// Initialize Firebase with proper error handling for iOS simulator
Future<void> _initializeFirebase() async {
  try {
    await Firebase.initializeApp();
    log('✅ Firebase initialized successfully');
  } catch (e) {
    log('⚠️ Firebase initialization failed: $e');

    // Check if it's a specific iOS simulator error
    if (e.toString().contains('FirebaseApp') ||
        e.toString().contains('duplicate') ||
        e.toString().contains('no Firebase App')) {
      // Try to get the default app (might already be initialized)
      try {
        final app = Firebase.app();
        log('✅ Firebase app already exists: ${app.name}');
        return;
      } catch (_) {
        // App doesn't exist, log and continue without Firebase
        log('⚠️ Running without Firebase services');
      }
    }

    // For iOS simulator specific issues
    if (defaultTargetPlatform == TargetPlatform.iOS && kDebugMode) {
      log('⚠️ iOS Simulator detected - Firebase may not be fully configured');
      log('💡 Ensure GoogleService-Info.plist is present in ios/Runner/');
    }

    // Don't rethrow - allow app to continue without Firebase
    // If your app absolutely requires Firebase, uncomment the line below:
    // rethrow;
  }
}

/// Initialize Notification Services
Future<void> _initializeNotifications() async {
  try {
    // ✅ Initialize local notifications
    await NotificationService.initialize();
    log('✅ Local notifications initialized');

    // ✅ Initialize Firebase Messaging
    await _initializeFirebaseMessaging();
    log('✅ Firebase Messaging initialized');
  } catch (e) {
    log('⚠️ Notification initialization failed: $e');
    // Continue app initialization even if notifications fail
  }
}

/// Initialize Firebase Cloud Messaging
Future<void> _initializeFirebaseMessaging() async {
  try {
    final messaging = FirebaseMessaging.instance;

    // ✅ Request permission for iOS
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

    // ✅ Get FCM token
    final token = await messaging.getToken();
    log('📱 FCM Token: $token');
    // TODO: Send this token to your backend server

    // ✅ Listen to token refresh
    messaging.onTokenRefresh.listen((newToken) {
      log('🔄 FCM Token refreshed: $newToken');
      // TODO: Update token on your backend server
    });

    // ✅ Handle background messages
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // ✅ Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      log('📬 Foreground message received: ${message.messageId}');
      log('Title: ${message.notification?.title}');
      log('Body: ${message.notification?.body}');
      log('Data: ${message.data}');

      // Show local notification when app is in foreground
      if (message.notification != null) {
        NotificationService.showNotification(
          message.notification!.title ?? 'New Notification',
          message.notification!.body ?? '',
          message.data,
        );
      }
    });

    // ✅ Handle notification tap when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      log('🔔 Notification tapped (app in background): ${message.messageId}');
      handleNotificationTap(message.data);
    });

    // ✅ Handle notification tap when app was terminated
    final initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) {
      log('App opened from terminated via notification');

      pendingNotificationData = initialMessage.data;
    }
  } catch (e) {
    log('⚠️ Firebase Messaging initialization failed: $e');
  }
}

/// Handle notification tap navigation
void handleNotificationTap(Map<String, dynamic> data) {
  log('Handling notification tap: $data');
  log('Navigator ready: ${_rootNavigatorKey.currentContext != null}');
  shouldShowNotificationDialog = true;
  final context = _rootNavigatorKey.currentContext;
  if (context == null) {
    log('Context not ready. Skipping tap handling.');
    return;
  }
  context.go('/mainHome');
}

// ✅ Wrapper widget to create router after initialization
class MyAppWrapper extends StatelessWidget {
  const MyAppWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<GoRouter>(
      future: createAppRouter(rootNavigatorKey: _rootNavigatorKey),
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
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => LocaleCubit(SecureStorageService())),
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
          return NetworkAwareWidget(
            offlineWidget: OfflineScreen(),
            child: MaterialApp.router(
              routerConfig: widget.router,
              debugShowCheckedModeBanner: false,
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
                    TargetPlatform.android: CupertinoPageTransitionsBuilder(),
                    TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
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
        },
      ),
    );
  }
}
