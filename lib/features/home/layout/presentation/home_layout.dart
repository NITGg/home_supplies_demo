import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:tawreedat_courier/features/home/layout/presentation/widgets/app_bar.dart';
import 'package:tawreedat_courier/features/home/layout/presentation/widgets/avalability_sheet.dart';
import 'package:tawreedat_courier/features/home/layout/presentation/widgets/link_account_sheet.dart';
import 'package:tawreedat_courier/features/home/layout/presentation/widgets/profile_avatar.dart';
import 'package:tawreedat_courier/features/orders/presentation/active_order/active_order_screen.dart';
import 'package:tawreedat_courier/features/stats/presentation/stats_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/utils/app_life_manager.dart';
import '../../../../core/utils/biometric_auth_service.dart';
import '../../../../core/utils/location_service.dart';
import '../../../../core/utils/logger.dart';
import '../../../../core/utils/socket_service.dart';
import '../../../../core/widgets/bio_lock_screen.dart';
import '../../../../core/widgets/loading_screen.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../core/utils/secure_storage_service.dart';
import '../../../../core/style/app_colors.dart';
import '../../../../core/style/text_styles.dart';
import '../../../../l10n/manager/locale_cubit.dart';
import '../../../../main.dart';
import '../../../auth/manager/auth_cubit.dart';
import '../../../auth/manager/auth_state.dart';
import '../../../auth/manager/profile_cubit.dart';
import '../../../auth/manager/profile_states.dart';
import '../../../chat/config/chat_injection.dart';
import '../../../delivery_areas/prenestation/delivery_areas_bottom_sheet.dart';
import '../../../notifications/notifications_dialog.dart';
import '../../../orders/manager/orders_cubit.dart';
import '../../../orders/presentation/orders_main_screen.dart';
import '../../../static_text/app_dynamic_info.dart';
import '../../../stats/manager/stats_cubit.dart';
import '../../../stats/manager/stats_states.dart';
import '../manager/availability_cubit.dart';
import '../manager/home_cubit.dart';

class HomeLayout extends StatefulWidget {
  const HomeLayout({super.key});

  @override
  State<HomeLayout> createState() => _HomeLayoutState();
}

class _HomeLayoutState extends State<HomeLayout> with WidgetsBindingObserver {
  final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();

  late final HomeCubit _homeCubit;
  late final AppLifecycleManager _lifecycleManager;

  bool _chatModuleReady = false;
  bool _biometricChecking = true; // true until we know if lock is needed
  bool _biometricChecked = false;
  bool _biometricRequired = false;
  bool _biometricPassed = false;
  bool _profileReadyHandled = false;
  bool _startupComplete = false;

  StreamSubscription<ProfileState>? _profileSub;

  @override
  void initState() {
    super.initState();
    _homeCubit = HomeCubit();
    _lifecycleManager = AppLifecycleManager(
      onLockRequired: _lockForBiometric,
    );
    WidgetsBinding.instance.addObserver(this);
    notificationDialogTrigger.addListener(_onExternalNotificationTrigger);

    context.read<StatsCubit>().fetchBadgeProgress();

    context.read<AvailabilityCubit>().initialize(
      onUnavailable: () {
        context.read<OrderCubit>().blockAvailableOrdersFetch();
      },
    );

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      context.read<ProfileCubit>().fetchProfile();

      final needsBiometric = !_biometricChecked &&
          await SecureStorageService().hasDeliveryAreasBeenShown() &&
          await BiometricAuthService().shouldShowBiometric();

      if (!mounted) return;

      if (needsBiometric) {
        _biometricChecked = true;
        setState(() {
          _biometricRequired = true;
          _biometricChecking = false;
        });
        // _waitForProfileThenConnect is called by _onBiometricPassed
      } else {
        setState(() => _biometricChecking = false);
        _waitForProfileThenConnect();
      }
    });
  }

  // ─── Biometric ────────────────────────────────────────────────────────────

  void _onBiometricPassed() {
    if (!mounted) return;
    setState(() {
      _biometricRequired = false;
      _biometricPassed = true;
    });
    _waitForProfileThenConnect();
  }

  void _onBiometricLogout() async {
    await SocketService().stop();
    ChatModule.dispose();
    if (mounted) context.go('/auth/login');
  }

  void _lockForBiometric() {
    if (!mounted) return;
    setState(() {
      _biometricRequired = true;
      _biometricPassed = false;
    });
  }

  // ─── Notifications ────────────────────────────────────────────────────────

  void _onExternalNotificationTrigger() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _showPendingNotificationDialog();
    });
  }

  // ─── Profile / startup ───────────────────────────────────────────────────

  void _waitForProfileThenConnect() {
    final profileCubit = context.read<ProfileCubit>();

    if (profileCubit.state is ProfileLoaded) {
      if (!_profileReadyHandled) {
        _profileReadyHandled = true;
        _onProfileReady();
      }
      return;
    }

    _profileSub = profileCubit.stream.listen((state) {
      if (state is ProfileLoaded && !_profileReadyHandled) {
        _profileReadyHandled = true;
        _profileSub?.cancel();
        _profileSub = null;
        if (mounted) _onProfileReady();
      }
    });
  }

  Future<void> _initChatModule() async {
    if (ChatModule.isInitialized) return;

    final profile = context.read<ProfileCubit>().currentProfile;
    final userId = profile?.id ?? 0;
    if (userId == 0) {
      dLog('⚠️ [HomeLayout] Profile has no userId — chat not initialised');
      return;
    }

    final token = await SecureStorageService().getToken();
    if (token == null || token.isEmpty) {
      dLog('⚠️ [HomeLayout] No token — chat not initialised');
      return;
    }

    try {
      ChatModule.init(
        currentUserId: userId,
        accessToken: token,
        baseUrl: 'https://tawreedat.nitg-eg.com',
        socketPath: '/courier_apis/socket.io',
      );
      if (mounted) setState(() => _chatModuleReady = true);
      dLog('✅ [HomeLayout] ChatModule initialised for userId: $userId');
    } catch (e) {
      dLog('⚠️ [HomeLayout] ChatModule init failed: $e');
    }
  }

  Future<void> _onProfileReady() async {
    dLog('📱 [HomeLayout] Profile ready');
    if (!mounted) return;

    await _initChatModule();

    _showPendingNotificationDialog();

    final isAvailable = await _maybeShowUnavailableReminder();

    if (!isAvailable) {
      _startupComplete = true;
      return;
    }
    await SocketService().requestLocationUpdate();

    if (!mounted) return;
    await _maybeShowLinkAccountSheet();

    if (!mounted) return;
    await _maybeShowDeliveryAreasSheet();
    _startupComplete = true;
  }

  // ─── Lifecycle ────────────────────────────────────────────────────────────

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _onAppResumed();
    }
  }

  Future<void> _onAppResumed() async {
    dLog('📱 [HomeLayout] App resumed');
    LocationService.instance.requestPermissionIfNeeded();
    if (!_startupComplete) return;

    final isAvailable = context.read<AvailabilityCubit>().state.isAvailable;
    if (isAvailable && !SocketService().isConnected) {
      context.read<AvailabilityCubit>().reconnectIfAvailable();
    }
  }

  // ─── Availability sheet ───────────────────────────────────────────────────

  Future<bool> _maybeShowUnavailableReminder() async {
    if (!mounted) return true;

    final availCubit = context.read<AvailabilityCubit>();

    if (availCubit.state.isLoading) {
      await availCubit.stream.firstWhere(
            (s) => !s.isLoading,
        orElse: () =>
        const AvailabilityState(status: AvailabilityStatus.unavailable),
      );
    }

    if (!mounted) return false;

    final isAvailable = availCubit.state.isAvailable;
    if (isAvailable) return true;

    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return false;

    await showModalBottomSheet(
      context: context,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider.value(
        value: context.read<AvailabilityCubit>(),
        child: const UnavailableReminderSheet(),
      ),
    );

    if (!mounted) return false;
    return context.read<AvailabilityCubit>().state.isAvailable;
  }

  // ─── Link-account sheet ───────────────────────────────────────────────────

  Future<void> _maybeShowLinkAccountSheet() async {
    dLog('🔗 [LinkAccountSheet] Starting check...');

    if (!context.mounted) return;

    final profile = context.read<ProfileCubit>().currentProfile;
    if (profile == null) return;

    final needsGoogle = profile.googleId == null;
    final needsApple = Platform.isIOS && profile.appleId == null;

    if (!needsGoogle && !needsApple) {
      dLog('🔗 [LinkAccountSheet] Skipped — nothing to link');
      return;
    }

    final alreadyShown =
    await SecureStorageService().hasLinkAccountBeenShown();
    if (alreadyShown) return;

    if (!context.mounted) return;

    dLog('🔗 [LinkAccountSheet] Showing sheet ✅');
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LinkAccountSheet(
        googleId: profile.googleId,
        appleId: profile.appleId,
      ),
    );

    await SecureStorageService().setLinkAccountShown();
    dLog('🔗 [LinkAccountSheet] Done');
  }

  // ─── Delivery-areas sheet ─────────────────────────────────────────────────

  Future<void> _maybeShowDeliveryAreasSheet() async {
    if (!mounted) return;

    final token = await SecureStorageService().getToken();
    if (token == null || token.isEmpty) return;

    final alreadyShown =
    await SecureStorageService().hasDeliveryAreasBeenShown();
    if (alreadyShown) return;

    if (!mounted) return;
    final result = await SelectDeliveryAreasBottomSheet.show(context);
    await SecureStorageService().setDeliveryAreasShown();
    if (result == true && mounted) {
      context.read<OrderCubit>().fetchAvailableOrders(
        refresh: true,
        context: context,
      );
    }
  }

  // ─── Pending notification ─────────────────────────────────────────────────

  void _showPendingNotificationDialog() {
    if (!mounted) return;
    if (pendingNotificationData == null && !shouldShowNotificationDialog) {
      return;
    }

    shouldShowNotificationDialog = false;
    pendingNotificationData = null;

    final profile = context.read<ProfileCubit>().currentProfile;
    final userId = profile?.id.toString() ?? '';

    HomeCubit? homeCubit;
    try {
      homeCubit = context.read<HomeCubit>();
    } catch (_) {
      homeCubit = _homeCubit;
    }

    showNotificationsDialog(context, userId, homeCubit: homeCubit);
  }

  // ─── Dispose ─────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _lifecycleManager.dispose();
    notificationDialogTrigger.removeListener(_onExternalNotificationTrigger);
    _profileSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _homeCubit.close();
    super.dispose();
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Hold a blank screen while we determine if biometric is needed,
    // so the home scaffold never flashes before the lock screen appears.
    if (_biometricChecking) {
      return const Scaffold(backgroundColor: Colors.white);
    }

    // Lock screen replaces the entire widget tree.
    // The home Scaffold does not exist until biometric passes.
    if (_biometricRequired && !_biometricPassed) {
      return BiometricLockScreen(
        onPassed: _onBiometricPassed,
        onLogout: _onBiometricLogout,
      );
    }

    final localizations = AppLocalizations.of(context)!;

    final screens = const [
      ActiveOrderScreen(),
      OrdersMainScreen(),
      StatsScreen(),
      SizedBox.shrink(),
    ];

    return BlocProvider.value(
      value: _homeCubit,
      child: BlocBuilder<HomeCubit, HomeState>(
        builder: (context, state) {
          final cubit = context.read<HomeCubit>();

          final itemsList = [
            BottomNavigationBarItem(
              icon: const Icon(Icons.inventory_2_outlined, size: 18),
              activeIcon: const Icon(Icons.inventory_2_rounded, size: 15),
              label: localizations.packages,
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.receipt_long, size: 18),
              activeIcon: const Icon(Icons.receipt, size: 15),
              label: localizations.orders,
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.analytics_outlined, size: 18),
              activeIcon: const Icon(Icons.analytics_rounded, size: 15),
              label: localizations.statistics,
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.menu, size: 18),
              label: localizations.menu,
            ),
          ];

          return BlocListener<AuthCubit, AuthState>(
            listener: (context, state) {
              if (state is AuthLoggedOut) {
                context.read<AvailabilityCubit>().resetForLogout();
              }
            },
            child: Scaffold(
              key: scaffoldKey,
              appBar: PreferredSize(
                preferredSize: Size.fromHeight(Platform.isIOS ? 60 : 60),
                child: Padding(
                  padding: Platform.isIOS
                      ? const EdgeInsets.only(top: 0.0)
                      : const EdgeInsets.only(top: 10.0),
                  child: AppLayoutAppBar(localizations: localizations),
                ),
              ),
              endDrawer: Drawer(
                backgroundColor: AppColors.kBackgroundColor,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Column(
                      children: [
                        Expanded(
                          child: ListView(
                            padding: EdgeInsets.zero,
                            children: [
                              BlocBuilder<ProfileCubit, ProfileState>(
                                builder: (context, profileState) {
                                  final profile = context
                                      .read<ProfileCubit>()
                                      .currentProfile;

                                  return BlocBuilder<StatsCubit, StatsState>(
                                    builder: (context, statsState) {
                                      final badgeProgress = context
                                          .read<StatsCubit>()
                                          .badgeProgress;

                                      return DrawerHeader(
                                        decoration: const BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              Color(0xFF2D3436),
                                              Color(0xFF636E72),
                                            ],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                        ),
                                        child: GestureDetector(
                                          onTap: () {
                                            if (profile != null) {
                                              context.push('/ProfileScreen');
                                            }
                                          },
                                          child: Row(
                                            spacing: 10,
                                            children: [
                                              Padding(
                                                padding:
                                                const EdgeInsets.only(
                                                  bottom: 10.0,
                                                ),
                                                child: ProfileAvatar(
                                                  imageUrl:
                                                  profile?.personalPhoto,
                                                  badgeProgress: badgeProgress,
                                                ),
                                              ),
                                              Expanded(
                                                child: Column(
                                                  mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                                  crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                                  spacing: 10,
                                                  children: [
                                                    Text(
                                                      profile != null &&
                                                          profile.fullName
                                                              .trim()
                                                              .isNotEmpty
                                                          ? '${localizations.welcome} ${profile.fullName.trim().split(' ').first}'
                                                          : localizations
                                                          .welcome,
                                                      style: AppTextStyles
                                                          .bold16
                                                          .copyWith(
                                                        color: Colors.white,
                                                      ),
                                                      overflow:
                                                      TextOverflow.ellipsis,
                                                      maxLines: 1,
                                                    ),
                                                    Text(
                                                      localizations
                                                          .tawreedatIsYourBestChoice,
                                                      style: AppTextStyles
                                                          .regular14
                                                          .copyWith(
                                                        fontSize: 12,
                                                        color: Colors.white,
                                                      ),
                                                      overflow:
                                                      TextOverflow.ellipsis,
                                                      maxLines: 2,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                },
                              ),
                              Padding(
                                padding: const EdgeInsets.all(17.0),
                                child: Material(
                                  elevation: 4,
                                  color: Colors.white,
                                  shadowColor:
                                  Colors.black.withOpacity(0.1),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: Column(
                                    children: [
                                      ListTile(
                                        leading: const Icon(
                                          Icons.language_outlined,
                                        ),
                                        title: Text(
                                          localizations.lang,
                                          style: AppTextStyles.bold16,
                                        ),
                                        trailing: SizedBox(
                                          width: 100,
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            mainAxisAlignment:
                                            MainAxisAlignment
                                                .spaceBetween,
                                            children: [
                                              Text(
                                                'EN',
                                                style:
                                                AppTextStyles.regular14,
                                              ),
                                              Switch(
                                                value: localizations
                                                    .localeName ==
                                                    'ar',
                                                onChanged: (v) => context
                                                    .read<LocaleCubit>()
                                                    .toggleLocale(),
                                                trackOutlineColor:
                                                WidgetStateProperty
                                                    .resolveWith(
                                                      (_) => AppColors
                                                      .kPrimaryColor,
                                                ),
                                                activeThumbColor: AppColors
                                                    .kPrimaryColor,
                                                activeTrackColor:
                                                Colors.white,
                                                inactiveTrackColor:
                                                Colors.white,
                                                inactiveThumbColor: AppColors
                                                    .kPrimaryColor,
                                              ),
                                              Text(
                                                'AR',
                                                style:
                                                AppTextStyles.regular14,
                                              ),
                                            ],
                                          ),
                                        ),
                                        onTap: () => context
                                            .read<LocaleCubit>()
                                            .toggleLocale(),
                                      ),
                                      const Divider(),
                                      ListTile(
                                        onTap: () =>
                                            context.push('/ProfileScreen'),
                                        leading:
                                        const Icon(Icons.person),
                                        title: Text(
                                          localizations.profile,
                                          style: AppTextStyles.bold16,
                                        ),
                                      ),
                                      const Divider(),
                                      ListTile(
                                        onTap: () =>
                                            context.push('/WalletScreen'),
                                        leading: const Icon(
                                          Icons
                                              .account_balance_wallet_rounded,
                                        ),
                                        title: Text(
                                          localizations.wallet,
                                          style: AppTextStyles.bold16,
                                        ),
                                      ),
                                      const Divider(),
                                      ListTile(
                                        onTap: () async {
                                          context.pop();
                                          final result =
                                          await SelectDeliveryAreasBottomSheet
                                              .show(context);
                                          if (result == true &&
                                              context.mounted) {
                                            context
                                                .read<OrderCubit>()
                                                .fetchAvailableOrders(
                                              refresh: true,
                                              context: context,
                                            );
                                          }
                                        },
                                        leading: const Icon(
                                          Icons.pin_drop_rounded,
                                        ),
                                        title: Text(
                                          localizations.deliveryAreas,
                                          style: AppTextStyles.bold16,
                                        ),
                                      ),
                                      const Divider(),
                                      ListTile(
                                        onTap: () =>
                                            context.push('/ReviewsScreen'),
                                        leading: const Icon(
                                          Icons.star_half,
                                        ),
                                        title: Text(
                                          localizations.reviews,
                                          style: AppTextStyles.bold16,
                                        ),
                                      ),
                                      const Divider(),
                                      ListTile(
                                        onTap: () =>
                                            context.push('/FaqPage'),
                                        leading: const Icon(
                                          Icons.question_mark,
                                        ),
                                        title: Text(
                                          localizations.faq,
                                          style: AppTextStyles.bold16,
                                        ),
                                      ),
                                      const Divider(),
                                      ListTile(
                                        onTap: () {
                                          launchUrl(
                                            Uri.parse(
                                              "https://wa.me/${AppInfoManager().data!.supportNumber.replaceAll(' ', '')}",
                                            ),
                                            mode: LaunchMode
                                                .externalApplication,
                                          );
                                        },
                                        leading: const Icon(
                                          Icons.support_agent_rounded,
                                        ),
                                        title: Text(
                                          localizations.support,
                                          style: AppTextStyles.bold16,
                                        ),
                                      ),
                                      const Divider(),
                                      ListTile(
                                        onTap: () =>
                                            context.push('/PrivacyPage'),
                                        leading: const Icon(
                                          Icons.policy_rounded,
                                        ),
                                        title: Text(
                                          localizations.privecyPolicy,
                                          style: AppTextStyles.bold16,
                                        ),
                                      ),
                                      const Divider(),
                                      ListTile(
                                        onTap: () =>
                                            context.push('/Terms'),
                                        leading: const Icon(Icons.lock),
                                        title: Text(
                                          localizations.termsAndConditions,
                                          style: AppTextStyles.bold16,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        FutureBuilder(
                          future: SecureStorageService().getToken(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return Expanded(
                                child: Center(
                                  child: CircularProgressIndicator(color: Colors.orange,),
                                ),
                              );
                            }
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 17.0,
                                vertical: 10.0,
                              ),
                              child: Material(
                                elevation: 1,
                                color: Colors.white,
                                shadowColor: AppColors.kPrimaryColor,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: InkWell(
                                  onTap: () async {
                                    await SocketService().stop();
                                    ChatModule.dispose();
                                    if (context.mounted) {
                                      context.read<AuthCubit>().logout();
                                      context.go('/auth/login');
                                    }
                                  },
                                  child: Container(
                                    color: Colors.white,
                                    height: 70,
                                    width: double.infinity,
                                    child: Row(
                                      mainAxisAlignment:
                                      MainAxisAlignment.center,
                                      spacing: 10,
                                      children: [
                                        SvgPicture.asset(
                                          'assets/images/drawer/logout.svg',
                                        ),
                                        Text(
                                          localizations.logout,
                                          style:
                                          AppTextStyles.bold16.copyWith(
                                            color: AppColors.kPrimaryColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              body: _chatModuleReady
                  ? ChatInboxProvider(child: screens[cubit.currentIndex])
                  : screens[cubit.currentIndex],
              bottomNavigationBar: Directionality(
                textDirection: Directionality.of(context),
                child: Container(
                  height: 90,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 6,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final totalWidth = constraints.maxWidth;
                      final itemCount = itemsList.length;
                      final itemWidth = totalWidth / itemCount;

                      final textDirection = Directionality.of(context);
                      final logicalIndex =
                      textDirection == TextDirection.ltr
                          ? cubit.currentIndex
                          : (itemCount - 1 - cubit.currentIndex);

                      const indicatorWidth = 65.0;
                      final leftPos = logicalIndex * itemWidth +
                          (itemWidth - indicatorWidth) / 2;

                      return Container(
                        color: Colors.white,
                        child: Stack(
                          alignment: Alignment.topCenter,
                          children: [
                            Theme(
                              data: Theme.of(context).copyWith(
                                splashColor: Colors.transparent,
                                highlightColor: Colors.transparent,
                              ),
                              child: Positioned.fill(
                                top: 8,
                                child: BottomNavigationBar(
                                  backgroundColor: Colors.white,
                                  currentIndex: cubit.currentIndex,
                                  onTap: (index) {
                                    if (index == 3) {
                                      scaffoldKey.currentState
                                          ?.openEndDrawer();
                                      return;
                                    }
                                    cubit.changeTab(index);
                                  },
                                  selectedItemColor:
                                  AppColors.kPrimaryColor,
                                  unselectedItemColor: Colors.grey,
                                  type: BottomNavigationBarType.fixed,
                                  selectedLabelStyle: const TextStyle(
                                    height: 2,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  unselectedLabelStyle: const TextStyle(
                                    height: 2,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  showUnselectedLabels: true,
                                  items: itemsList,
                                ),
                              ),
                            ),
                            AnimatedPositioned(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                              top: 2,
                              left: leftPos,
                              child: SvgPicture.asset(
                                'assets/images/navbar/indicator.svg',
                                height: 10,
                                width: indicatorWidth,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
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