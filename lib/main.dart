import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:floating_draggable_widget/floating_draggable_widget.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:safe_device/safe_device.dart';
import 'package:tawreedat_courier/features/auth/data/data_sources/profile_remote_data_source.dart';
import 'package:tawreedat_courier/features/auth/data/repositories/profile_repository.dart';
import 'package:tawreedat_courier/features/orders/data/repositories/orders_repo.dart';
import 'package:url_launcher/url_launcher.dart';
import 'core/connectivity/connectivity_manager.dart';
import 'core/connectivity/network_aware_widget.dart';
import 'core/connectivity/offline_screen.dart';
import 'core/error/config.dart';
import 'core/error/handler.dart';
import 'core/error/restart_widget.dart';
import 'core/utils/api_client.dart';
import 'core/utils/app_dynamic_settings.dart';
import 'core/utils/keep_alive_service.dart';
import 'core/utils/logger.dart';
import 'core/utils/secure_storage_service.dart';
import 'core/style/app_colors.dart';
import 'core/widgets/CompromisedDeviceWarningApp.dart';
import 'core/widgets/animated_support_fab.dart';
import 'core/widgets/loading_screen.dart';
import 'features/auth/data/repositories/auth_repository.dart';
import 'features/auth/manager/profile_cubit.dart';
import 'features/coupons/manager/coupons_cubit.dart';
import 'features/home/layout/manager/availability_cubit.dart';
import 'features/notifications/manager/notification_services.dart';
import 'features/orders/manager/orders_cubit.dart';
import 'features/static_text/app_dynamic_info.dart';
import 'features/stats/data/data_source/stats_remote_data_source.dart';
import 'features/stats/data/repository/stats_repo.dart';
import 'features/stats/manager/stats_cubit.dart';
import 'routes/app_router.dart';
import 'features/auth/data/data_sources/auth_remote_data_source.dart';
import 'features/auth/manager/auth_cubit.dart';
import 'l10n/app_localizations.dart';
import 'l10n/manager/locale_cubit.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();
final ValueNotifier<int> notificationDialogTrigger = ValueNotifier(0);

/// Payload from a notification tap that arrived before HomeLayout was ready.
/// HomeLayout checks and consumes this on first build.
Map<String, dynamic>? pendingNotificationData;

/// Set to true so HomeLayout shows the notifications diadLog once it mounts.
bool shouldShowNotificationDialog = false;

// ── Background message handler (must be top-level) ────────────────────────────
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  dLog('📬 Background message: ${message.messageId}');
}

Future<void> main() async {
  KeepAliveService.initPort();

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
      dLog('🔴 Error: $error\nStack: $stackTrace');
    },
  );

  GlobalErrorHandler.runAppWithErrorHandling(
    RestartWidget(child: const MyAppWrapper()),
    onBeforeRunApp: () async {
      // ✅ MUST be here (same zone)
      WidgetsFlutterBinding.ensureInitialized();

      // ── Security check ──────────────────────────────────────────────────────────
      // SafeDevice.isJailBroken → true on rooted Android / jailbroken iOS.
      // Wrap in try-catch so a plugin failure never blocks a legitimate user.
      bool isCompromised = false;
      if (!kDebugMode) {
        try {
          final results = await Future.wait([
            SafeDevice.isJailBroken,
            SafeDevice.isRealDevice.then((v) => !v), // true = emulator
          ]);
          isCompromised = results.any((r) => r);
        } catch (e) {
          dLog('⚠️ SafeDevice check failed: $e');
        }
      }

      if (isCompromised) {
        runApp(const CompromisedDeviceWarningApp());
        return false; // ← stop here; nothing else initialises
      }
      // ────────────────────────────────────────────────────────────────────────────

      await KeepAliveService.init();

      await _initializeFirebase();
      await _initializeNotifications();

      try {
        await GoogleSignIn.instance.initialize(
          serverClientId:
              '644970780839-jevk4ojdbj232uvk66na27et844iip8o.apps.googleusercontent.com',
        );
      } catch (e) {
        dLog('⚠️ Google Sign-In initialization failed: $e');
      }

      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);

      ApiClient.instance.init();
      await ConnectivityManager.instance.init();

      if (ConnectivityManager.instance.isConnected) {
        await Future.wait([
          AppSettings().load(),
          AppSettings().loadPublicSettings(),
          AppInfoManager().loadAppInfo(),
        ]);
      }

      return true;
    },
  );
}

Future<void> _initializeFirebase() async {
  try {
    await Firebase.initializeApp();
    dLog('✅ Firebase initialized successfully');
  } catch (e) {
    dLog('⚠️ Firebase initialization: $e');
    try {
      final app = Firebase.app();
      dLog('✅ Firebase app already exists: ${app.name}');
    } catch (_) {
      dLog('⚠️ Running without Firebase services');
    }
  }
}

Future<void> _initializeNotifications() async {
  try {
    await NotificationService.initialize();
    dLog('✅ Local notifications initialized');
    await _initializeFirebaseMessaging();
    dLog('✅ Firebase Messaging initialized');
  } catch (e) {
    dLog('⚠️ Notification initialization failed: $e');
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
      dLog('✅ Notification permission granted');
    } else if (settings.authorizationStatus ==
        AuthorizationStatus.provisional) {
      dLog('⚠️ Provisional notification permission');
    } else {
      dLog('❌ Notification permission denied');
      return;
    }

    await messaging.getToken();
    if (Platform.isIOS) {
      String? apnsToken = await FirebaseMessaging.instance.getAPNSToken();
      dLog('APNS TOKEN: $apnsToken');
    }

    // When FCM rotates the token, update the backend.
    // The ApiClient interceptor injects the Bearer header automatically,
    // so we don't need to read or cache the auth token here.
    messaging.onTokenRefresh.listen((newToken) async {
      dLog('🔄 FCM token refreshed');
      try {
        await ApiClient.instance.dio2.post(
          '/profile/fcm-token',
          data: {'fcmToken': newToken},
        );
        dLog('✅ Refreshed FCM token sent to backend');
      } catch (e) {
        dLog('⚠️ Failed to update FCM token: $e');
      }
    });

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Foreground FCM message → show local notification.
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      dLog('📬 Foreground message: ${message.messageId}');
      if (message.notification != null) {
        NotificationService.showNotification(
          message.notification!.title ?? 'New Notification',
          message.notification!.body ?? '',
          message.data,
        );
      }
      // Silent push (no notification body) on iOS: reconnect socket if needed.
      // Server should send content-available:1 for this to wake the app.
      if (message.notification == null && message.data.isNotEmpty) {
        dLog('🔔 Silent push received — triggering socket reconnect');
        // Import SocketService here only if needed; lazy to avoid circular deps.
        // SocketService().reconnect(); // ← Uncomment if you import it here.
      }
    });

    // App was in background — user tapped the notification.
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      dLog('🔔 Notification tapped (background): ${message.messageId}');
      handleNotificationTap(message.data);
    });

    // App was terminated — user tapped the notification.
    // Store as pending; HomeLayout will consume it after it mounts.
    // Do NOT call handleNotificationTap here because the router is not
    // ready yet and GoRouter.of(context).go() would silently fail.
    final initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) {
      dLog('🚀 App opened from terminated state via notification');
      pendingNotificationData = initialMessage.data;
      // shouldShowNotificationDiadLog is intentionally NOT set here.
      // HomeLayout checks pendingNotificationData directly.
    }
  } catch (e) {
    dLog('⚠️ Firebase Messaging initialization failed: $e');
  }
}

/// Central entry-point for ALL in-app notification taps (FCM background /
/// local notification tap from NotificationService).
///
/// Strategy:
///   • If already on /mainHome → show the diadLog directly.
///   • If on splash/root      → HomeLayout will consume pendingNotificationData.
///   • Otherwise              → navigate to /mainHome.
void handleNotificationTap(Map<String, dynamic> data) {
  dLog('🔔 handleNotificationTap: $data');

  pendingNotificationData = data;
  shouldShowNotificationDialog = true;

  final context = rootNavigatorKey.currentContext;
  if (context == null) {
    dLog('⚠️ Context null — stored as pending');
    return;
  }

  final currentUri = GoRouter.of(
    context,
  ).routerDelegate.currentConfiguration.uri.toString();

  if (currentUri == '/mainHome') {
    // ❌ Don't clear flags here — HomeLayout needs to read them
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notificationDialogTrigger.value++;
    });
  } else if (currentUri == '/splash' || currentUri == '/') {
    dLog('⏳ App initialising — HomeLayout will consume on mount');
  } else {
    dLog('🚀 Navigating to /mainHome');
    context.go('/mainHome');
  }
}

// ── MyAppWrapper ──────────────────────────────────────────────────────────────

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
        if (snapshot.hasError) throw snapshot.error!;
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

// ── MyApp ─────────────────────────────────────────────────────────────────────

class MyApp extends StatefulWidget {
  final GoRouter router;

  const MyApp({super.key, required this.router});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // NOTE: We deliberately do NOT handle pendingNotificationData here.
  // The router is not ready at this point, so any navigation call would
  // fail silently. HomeLayout handles cold-start notifications via
  // _showPendingNotificationDiadLog() once it is mounted.

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
          create: (_) => ProfileCubit(profileRepository),
        ),
        BlocProvider<OrderCubit>(create: (_) => OrderCubit(OrderRepository())),
        BlocProvider<StatsCubit>(
          create: (_) => StatsCubit(StatsRepository(StatsRemoteDataSource())),
        ),
        BlocProvider(create: (_) => AvailabilityCubit()),
        BlocProvider(create: (_) => CouponCubit()),
      ],
      child: BlocBuilder<LocaleCubit, LocaleState>(
        builder: (context, state) {
          return Directionality(
            textDirection: state.locale.languageCode == 'ar'
                ? TextDirection.rtl
                : TextDirection.ltr,
            child: FloatingDraggableWidget(
              floatingWidget: Container(
                decoration: BoxDecoration(
                  color: AppColors.kSecondaryColor.withValues(alpha: 0.8),
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
              ),
              floatingWidgetWidth: 40,
              floatingWidgetHeight: 40,
              dy: 250,
              autoAlign: true,
              autoAlignType: AlignmentType.both,
              mainScreenWidget: NetworkAwareWidget(
                offlineWidget: OfflineScreen(),
                child: MaterialApp.router(
                  routerConfig: widget.router,
                  debugShowCheckedModeBanner: false,
                  builder: (context, child) {
                    final mq = MediaQuery.of(context);
                    return MediaQuery(
                      data: mq.copyWith(
                        textScaler: mq.textScaler.clamp(maxScaleFactor: 1.1),
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
                    colorScheme: ColorScheme(
                      brightness: Brightness.light,

                      primary: AppColors.kPrimaryColor,
                      onPrimary: Colors.black,

                      secondary: AppColors.kSecondaryColor,
                      onSecondary: Colors.white,

                      error: Colors.red,
                      onError: Colors.white,

                      surface: Colors.white,
                      onSurface: Colors.black,
                    ),
                    pageTransitionsTheme: PageTransitionsTheme(
                      builders: {
                        TargetPlatform.android:
                            CupertinoPageTransitionsBuilder(),
                        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
                      },
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
              ),
            ),
          );
        },
      ),
    );
  }
}
