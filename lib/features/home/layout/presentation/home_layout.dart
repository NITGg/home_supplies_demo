import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:tawreedat_go/core/widgets/banners.dart';
import 'package:tawreedat_go/features/coupons/manager/coupons_cubit.dart';
import 'package:tawreedat_go/features/wallet/manager/wallet_cubit.dart';
import 'package:tawreedat_go/features/wallet/manager/wallet_state.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/utils/socket_service.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/loading_screen.dart';
import '../../../../core/widgets/text_form.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../main.dart';
import '../../../addresses/data/models/governorate_model.dart';
import '../../../addresses/manager/governorate_cubit.dart';
import '../../../addresses/manager/governorate_states.dart';
import '../../../auth/manager/auth_cubit.dart';
import '../../../../core/utils/secure_storage_service.dart';
import '../../../../core/style/app_colors.dart';
import '../../../../core/style/text_styles.dart';
import '../../../../l10n/manager/locale_cubit.dart';
import '../../../auth/manager/auth_state.dart';
import '../../../auth/manager/profile_cubit.dart';
import '../../../auth/manager/profile_states.dart';
import '../../../coupons/presentation/coupons_ticker_title.dart';
import '../../../notifications/presentation/widgets/notification_dialog.dart';
import '../../../orders/presentation/orders_list_screen.dart';
import '../../../orders/presentation/widgets/sheets/create_order_sheet/create_order_sheet.dart';
import '../../../referral/refferal_service.dart';
import '../../../static_text/app_dynamic_info.dart';
import '../manager/home_cubit.dart';
import 'go_button.dart';

class HomeLayout extends StatefulWidget {
  const HomeLayout({super.key});

  @override
  State<HomeLayout> createState() => _HomeLayoutState();
}

class _HomeLayoutState extends State<HomeLayout> with WidgetsBindingObserver {
  String _userId = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    notificationDialogTrigger.addListener(_onExternalNotificationTrigger);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Fetch profile from cubit — single source of truth
      if (mounted) {
        context.read<ProfileCubit>().fetchProfile();
        context.read<WalletCubit>().fetchWalletData();
      }

      // Connect socket
      final token = await SecureStorageService().getToken();
      if (token != null && token.isNotEmpty) {
        final socketService = SocketService();
        socketService.connect(
          baseUrl: 'https://tawreedat.nitg-eg.com',
          accessToken: token,
        );
      }
    });
  }

  void _onExternalNotificationTrigger() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      HomeCubit? homeCubit;
      CouponCubit? couponCubit;
      try {
        homeCubit = context.read<HomeCubit>();
        couponCubit = context.read<CouponCubit>();
      } catch (e) {
        debugPrint('⚠️ Could not read cubits in HomeLayout: $e');
      }
      showNotificationsDialog(
        context,
        _userId,
        homeCubit: homeCubit,
        couponCubit: couponCubit,
      );
    });
  }

  void _showPendingNotificationDialog() {
    if (!mounted) return;
    if (pendingNotificationData == null && !shouldShowNotificationDialog)
      return;

    shouldShowNotificationDialog = false;
    pendingNotificationData = null;

    HomeCubit? homeCubit;
    CouponCubit? couponCubit;
    try {
      homeCubit = context.read<HomeCubit>();
      couponCubit = context.read<CouponCubit>();
    } catch (e) {
      debugPrint('⚠️ Could not read cubits in HomeLayout: $e');
    }

    showNotificationsDialog(
      context,
      _userId,
      homeCubit: homeCubit,
      couponCubit: couponCubit,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    notificationDialogTrigger.removeListener(_onExternalNotificationTrigger);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _ensureSocketConnection();
    }
  }

  Future<void> _ensureSocketConnection() async {
    try {
      final socketService = SocketService();
      if (!socketService.isConnected) {
        debugPrint('🔄 Socket disconnected, attempting to reconnect...');
        final token = await SecureStorageService().getToken();
        if (token != null && token.isNotEmpty) {
          socketService.connect(
            baseUrl: 'https://tawreedat.nitg-eg.com',
            accessToken: token,
          );
        }
      }
    } catch (e) {
      debugPrint('Error ensuring socket connection: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final scaffoldKey = GlobalKey<ScaffoldState>();
    final localizations = AppLocalizations.of(context)!;
    final screens = const [OrdersListScreen(), SizedBox.shrink()];

    return MultiBlocProvider(
      providers: [
        BlocProvider<HomeCubit>(create: (_) => HomeCubit()),
        BlocProvider<CouponCubit>(create: (_) => CouponCubit()..loadCoupons()),
        BlocProvider<GovernorateCubit>(
          create: (_) => GovernorateCubit()..loadGovernorates(),
        ),
      ],
      child: BlocBuilder<HomeCubit, HomeState>(
        builder: (context, state) {
          final cubit = context.read<HomeCubit>();

          return BlocBuilder<ProfileCubit, ProfileState>(
            builder: (context, profileState) {
              final profile = profileState is ProfileLoaded
                  ? profileState.profile
                  : null;

              return MultiBlocListener(
                listeners: [
                  BlocListener<AuthCubit, AuthState>(
                    listener: (context, state) {
                      if (state is AuthUpdateSuccess) {
                        context.read<ProfileCubit>().fetchProfile();
                      }
                    },
                  ),
                  BlocListener<ProfileCubit, ProfileState>(
                    listener: (context, profileState) {
                      if (profileState is ProfileLoaded) {
                        setState(() {
                          _userId = profileState.profile.id.toString();
                        });

                        // ✅ Now we have userId — safe to capture referral
                        if (profileState.profile.referralCode == null) {
                          ReferralCaptureService.captureOnFirstLaunch(
                            userId: _userId,
                          ).then((code) {
                            if (code != null && mounted) {
                              showSuccessBanner(
                                context,
                                'your referral code is: $code',
                              );
                            }
                          });
                        }

                        if (profileState.profile.phone == null) {
                          _showPhoneNumberBottomSheet(context);
                        }
                        _showPendingNotificationDialog();
                      }
                    },
                  ),
                ],
                child: Scaffold(
                  key: scaffoldKey,
                  appBar: PreferredSize(
                    preferredSize: const Size.fromHeight(60),
                    child: Padding(
                      padding: Platform.isIOS
                          ? const EdgeInsets.only(top: 0.0)
                          : const EdgeInsets.only(top: 10.0),
                      child: AppLayoutAppBar(
                        scaffoldKey: scaffoldKey,
                        localizations: localizations,
                      ),
                    ),
                  ),
                  floatingActionButtonLocation:
                      FloatingActionButtonLocation.centerDocked,
                  floatingActionButton: FloatingActionButton.large(
                    onPressed: () {
                      final govState = context.read<GovernorateCubit>().state;
                      final governorates = govState is GovernoratesLoaded
                          ? govState.response
                          : GovernoratesResponse(
                              governorates: [],
                              totalCount: 0,
                              totalPages: 0,
                            );
                      final walletCubit = context.read<WalletCubit>();
                      final balance =
                          walletCubit.cachedWalletData?.wallet.balance ?? 0.0;

                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => CreateOrderBottomSheet(
                          governorates: governorates,
                          walletBalance: balance,
                        ),
                      );
                    },
                    backgroundColor: AppColors.kSecondaryColor,
                    shape: const CircleBorder(),
                    child: AnimatedGoButton(),
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
                                  BlocBuilder<WalletCubit, WalletState>(
                                    builder: (context, walletState) {
                                      final walletCubit = context
                                          .read<WalletCubit>();
                                      final badge = walletCubit.currentBadge;
                                      final isArabic =
                                          localizations.localeName == 'ar';

                                      final badgeName = badge == null
                                          ? null
                                          : isArabic &&
                                                (badge.nameAr?.isNotEmpty ??
                                                    false)
                                          ? badge.nameAr
                                          : badge.name;

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
                                            context.push('/ProfileScreen');
                                          },
                                          child: Row(
                                            spacing: 10,
                                            children: [
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  bottom: 10.0,
                                                ),
                                                // ✅ Photo now reactive to ProfileCubit
                                                child: _ProfileAvatar(
                                                  imageUrl:
                                                      profile?.personalPhoto,
                                                  badgeName: badgeName,
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
                                                      localizations.welcome,
                                                      style: AppTextStyles
                                                          .bold16
                                                          .copyWith(
                                                            color: Colors.white,
                                                          ),
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
                                  ),

                                  Padding(
                                    padding: const EdgeInsets.all(17.0),
                                    child: Material(
                                      elevation: 4,
                                      color: Colors.white,
                                      shadowColor: Colors.black.withOpacity(
                                        0.1,
                                      ),
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
                                                    value:
                                                        localizations
                                                            .localeName ==
                                                        'ar',
                                                    onChanged: (value) =>
                                                        context
                                                            .read<LocaleCubit>()
                                                            .toggleLocale(),
                                                    trackOutlineColor:
                                                        WidgetStateProperty.resolveWith(
                                                          (_) => AppColors
                                                              .kPrimaryColor,
                                                        ),
                                                    activeThumbColor:
                                                        AppColors.kPrimaryColor,
                                                    activeTrackColor:
                                                        Colors.white,
                                                    inactiveTrackColor:
                                                        Colors.white,
                                                    inactiveThumbColor:
                                                        AppColors.kPrimaryColor,
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

                                          // ✅ Referral tile — reactive to ProfileLoaded state
                                          if (profileState is ProfileLoaded &&
                                              profileState.profile.roleId
                                                      .toString() ==
                                                  '4') ...[
                                            const Divider(),
                                            ListTile(
                                              onTap: () => context.push(
                                                '/ReferralQrScreen',
                                              ),
                                              leading: const Icon(Icons.share),
                                              title: Text(
                                                localizations.referral,
                                                style: AppTextStyles.bold16,
                                              ),
                                            ),
                                          ],

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
                                            onTap: () => context.push(
                                              '/addressesManagement',
                                            ),
                                            leading: const Icon(
                                              Icons.location_pin,
                                            ),
                                            title: Text(
                                              localizations.address,
                                              style: AppTextStyles.bold16,
                                            ),
                                          ),
                                          const Divider(),
                                          ListTile(
                                            onTap: () =>
                                                context.push('/ProfileScreen'),
                                            leading: const Icon(Icons.person),
                                            title: Text(
                                              localizations.profile,
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
                                            onTap: () => context.push('/Terms'),
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
                                  return const Expanded(
                                    child: Center(
                                      child: LoadingScreen(asWidget: true),
                                    ),
                                  );
                                } else if (snapshot.hasData &&
                                    snapshot.data != null) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 17.0,
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
                                          await SecureStorageService()
                                              .clearAll();
                                          if (context.mounted) {
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
                                                style: AppTextStyles.bold16
                                                    .copyWith(
                                                      color: AppColors
                                                          .kPrimaryColor,
                                                    ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                } else {
                                  return const SizedBox.shrink();
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  body: screens[cubit.currentIndex],
                  bottomNavigationBar: _BottomNavBar(
                    currentIndex: cubit.currentIndex,
                    userId: _userId,
                    localizations: localizations,
                    onOrdersTap: () => cubit.changeTab(0),
                    onNotificationsTap: () =>
                        showNotificationsDialog(context, _userId),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showPhoneNumberBottomSheet(BuildContext context) {
    final TextEditingController phoneController = TextEditingController();
    final localizations = AppLocalizations.of(context)!;
    final formKey = GlobalKey<FormState>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(localizations.enterPhoneNumber, style: AppTextStyles.bold18),
              const SizedBox(height: 8),
              Text(
                localizations.weNeedYourPhoneNumber,
                style: AppTextStyles.regular14.copyWith(color: Colors.grey),
              ),
              const SizedBox(height: 20),
              Form(
                key: formKey,
                child: AppTextFormField(
                  label: AppLocalizations.of(context)!.phone,
                  controller: phoneController,
                  isPhone: true,
                ),
              ),
              const SizedBox(height: 20),
              AppCustomButton(
                onPressed: () {
                  if (formKey.currentState!.validate()) {
                    Navigator.pop(context);
                    context.read<ProfileCubit>().changePhone(
                      phone: phoneController.text,
                    );
                  }
                },
                text: localizations.confirm,
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }
}

// ── _BottomNavBar ─────────────────────────────────────────────────────────────

class _BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final String userId;
  final AppLocalizations localizations;
  final VoidCallback onOrdersTap;
  final VoidCallback onNotificationsTap;

  const _BottomNavBar({
    required this.currentIndex,
    required this.userId,
    required this.localizations,
    required this.onOrdersTap,
    required this.onNotificationsTap,
  });

  @override
  Widget build(BuildContext context) {
    const itemCount = 2;

    return Container(
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
          final itemWidth = totalWidth / itemCount;

          final textDirection = Directionality.of(context);
          final logicalIndex = textDirection == TextDirection.ltr
              ? currentIndex
              : (itemCount - 1 - currentIndex);

          const indicatorWidth = 65.0;
          final leftPos =
              logicalIndex * itemWidth + (itemWidth - indicatorWidth) / 2;

          return Stack(
            alignment: Alignment.topCenter,
            children: [
              Positioned.fill(
                top: 8,
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: onOrdersTap,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              currentIndex == 0
                                  ? Icons.receipt
                                  : Icons.receipt_long,
                              color: currentIndex == 0
                                  ? AppColors.kPrimaryColor
                                  : Colors.grey,
                            ),
                            Text(
                              localizations.orders,
                              style: TextStyle(
                                height: 2,
                                fontSize: 10,
                                fontWeight: currentIndex == 0
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: currentIndex == 0
                                    ? AppColors.kPrimaryColor
                                    : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: InkWell(
                        onTap: onNotificationsTap,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            NotificationButton(userId: userId),
                            Text(
                              localizations.notifications,
                              style: const TextStyle(
                                height: 2,
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
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
          );
        },
      ),
    );
  }
}

// ── _ProfileAvatar ────────────────────────────────────────────────────────────

class _ProfileAvatar extends StatelessWidget {
  final String? imageUrl;
  final String? badgeName;

  const _ProfileAvatar({this.imageUrl, this.badgeName});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Hero(
            tag: 'profile-avatar',
            child: ClipOval(
              child: imageUrl != null && imageUrl!.isNotEmpty
                  ? Image.network(
                      imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          SvgPicture.asset(
                            'assets/images/drawer/profile_placholder.svg',
                          ),
                    )
                  : SvgPicture.asset(
                      'assets/images/drawer/profile_placholder.svg',
                    ),
            ),
          ),
        ),
        if (badgeName != null && badgeName!.isNotEmpty)
          Positioned(
            bottom: -20,
            left: 10,
            right: 10,
            child: Text(
              badgeName!,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }
}

// ── AppLayoutAppBar ───────────────────────────────────────────────────────────

class AppLayoutAppBar extends StatefulWidget {
  const AppLayoutAppBar({
    super.key,
    required this.localizations,
    required this.scaffoldKey,
  });

  final AppLocalizations localizations;
  final GlobalKey<ScaffoldState> scaffoldKey;

  @override
  State<AppLayoutAppBar> createState() => _AppLayoutAppBarState();
}

class _AppLayoutAppBarState extends State<AppLayoutAppBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;
  late Animation<double> _companyLogoOpacity;
  late Animation<double> _companyLogoScale;
  late Animation<double> _appLogoOpacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.0,
          end: 1.3,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.3,
          end: 0.9,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.9,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.elasticOut)),
        weight: 40,
      ),
    ]).animate(_controller);

    _rotationAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.0,
          end: 0.1,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.1,
          end: -0.1,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: -0.1,
          end: 0.05,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.05,
          end: 0.0,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 25,
      ),
    ]).animate(_controller);

    _appLogoOpacity = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.0,
          end: 0.0,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 30,
      ),
      TweenSequenceItem(tween: ConstantTween<double>(0.0), weight: 40),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.0,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 30,
      ),
    ]).animate(_controller);

    _companyLogoOpacity = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.0,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 30,
      ),
      TweenSequenceItem(tween: ConstantTween<double>(1.0), weight: 40),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.0,
          end: 0.0,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 30,
      ),
    ]).animate(_controller);

    _companyLogoScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.5,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 30,
      ),
      TweenSequenceItem(tween: ConstantTween<double>(1.0), weight: 40),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.0,
          end: 1.2,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 30,
      ),
    ]).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _triggerEasterEgg() {
    if (!_controller.isAnimating) {
      _controller.forward(from: 0.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,
      scrolledUnderElevation: 0,
      elevation: 0,
      actions: const [SizedBox.shrink()],
      title: Directionality(
        textDirection: AppLocalizations.of(context)!.localeName == 'ar'
            ? TextDirection.ltr
            : TextDirection.rtl,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: Colors.grey.shade200,
              child: IconButton(
                icon: const Icon(Icons.menu),
                color: Colors.grey.shade700,
                onPressed: () {
                  widget.scaffoldKey.currentState?.openEndDrawer();
                },
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: CouponTickerTitle(),
              ),
            ),
            GestureDetector(
              onTap: _triggerEasterEgg,
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _scaleAnimation.value,
                    child: Transform.rotate(
                      angle: _rotationAnimation.value,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Opacity(
                            opacity: _appLogoOpacity.value,
                            child: child!,
                          ),
                          if (_companyLogoOpacity.value > 0)
                            Opacity(
                              opacity: _companyLogoOpacity.value,
                              child: Transform.scale(
                                scale: _companyLogoScale.value,
                                child: SvgPicture.asset(
                                  'assets/images/appbar/company_logo.svg',
                                  height: 30,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
                child: SvgPicture.asset(
                  'assets/images/appbar/logo.svg',
                  height: 30,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
