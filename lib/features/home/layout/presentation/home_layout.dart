import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:tawreedat_courier/features/orders/presentation/active_order_screen.dart';
import 'package:tawreedat_courier/features/stats/presentation/stats_screen.dart';
import '../../../../core/utils/biometric_auth_service.dart';
import '../../../../core/widgets/loading_screen.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/data/models/user_profile_model.dart';
import '../../../../core/utils/secure_storage_service.dart';
import '../../../../core/style/app_colors.dart';
import '../../../../core/style/text_styles.dart';
import '../../../../l10n/manager/locale_cubit.dart';
import '../../../auth/manager/auth_cubit.dart';
import '../../../auth/manager/auth_state.dart';
import '../../../auth/manager/profile_cubit.dart';
import '../../../delivery_areas/prenestation/delivery_areas_bottom_sheet.dart';
import '../../../orders/presentation/orders_main_screen.dart';
import '../manager/home_cubit.dart';

class HomeLayout extends StatefulWidget {
  const HomeLayout({super.key});

  @override
  State<HomeLayout> createState() => _HomeLayoutState();
}

class _HomeLayoutState extends State<HomeLayout> {
  final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();
  late Future<UserProfileModel?> _userProfileFuture;
  bool _biometricChecked = false;

  @override
  void initState() {
    super.initState();
    context.read<ProfileCubit>().fetchProfile();
    context.read<ProfileCubit>().fetchBadgeProgress();
    _userProfileFuture = _loadUserProfile();

    // Only check biometric once when the widget is first created
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_biometricChecked) {
        _checkBiometricOnStart();
      }
    });
  }

  Future<void> _checkBiometricOnStart() async {
    if (_biometricChecked) return; // Prevent multiple checks

    _biometricChecked = true; // Mark as checked immediately

    final success = await BiometricManager().verifyBiometric(context: context);
    if (!success) {
      // Biometric failed - logout and redirect
      await SecureStorageService().clearAll();
      if (mounted) {
        context.go('/auth/login');
      }
    }
  }

  Future<UserProfileModel?> _loadUserProfile() async {
    final userProfileJson = await SecureStorageService().getUserProfile();
    if (userProfileJson != null) {
      return UserProfileModel.fromJson(userProfileJson);
    }
    return null;
  }

  Future<void> _refreshUserProfile() async {
    final newUserProfile = await _loadUserProfile();
    setState(() {
      _userProfileFuture = Future.value(newUserProfile);
    });
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    final screens = const [
      ActiveOrderScreen(),
      OrdersMainScreen(),
      StatsScreen(),
      SizedBox.shrink(),
    ];

    return MultiBlocProvider(
      providers: [BlocProvider<HomeCubit>(create: (_) => HomeCubit())],
      child: BlocBuilder<HomeCubit, HomeState>(
        builder: (context, state) {
          final cubit = context.read<HomeCubit>();
          final itemsList = [
            BottomNavigationBarItem(
              icon: Icon(Icons.inventory_2_outlined),
              activeIcon: Icon(Icons.inventory_2_rounded),
              label: localizations.packages,
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.receipt_long),
              activeIcon: Icon(Icons.receipt),
              label: localizations.orders,
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.analytics_outlined),
              activeIcon: Icon(Icons.analytics_rounded),
              label: localizations.statistics,
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.menu),
              label: localizations.menu,
            ),
          ];

          return FutureBuilder<UserProfileModel?>(
            future: _userProfileFuture,
            builder: (context, snapshot) {
              final profile = snapshot.data;

              return BlocListener<AuthCubit, AuthState>(
                listener: (context, state) {
                  if (state is AuthUpdateSuccess) {
                    _refreshUserProfile();
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
                      child: AppLayoutAppBar(
                        isLoggedIn: profile != null,
                        localizations: localizations,
                      ),
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
                                  DrawerHeader(
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
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
                                          profile?.personalPhoto == null
                                              ? SvgPicture.asset(
                                                  'assets/images/drawer/profile_placholder.svg',
                                                )
                                              : CircleAvatar(
                                                  radius: 30,
                                                  backgroundImage: NetworkImage(
                                                    profile!.personalPhoto!,
                                                  ),
                                                ),
                                          Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            spacing: 10,
                                            children: [
                                              Text(
                                                localizations.welcome,
                                                style: AppTextStyles.bold16
                                                    .copyWith(
                                                      color: Colors.white,
                                                    ),
                                              ),
                                              Text(
                                                localizations
                                                    .tawreedatIsYourBestChoice,
                                                style: AppTextStyles.regular14
                                                    .copyWith(
                                                      fontSize: 12,
                                                      color: Colors.white,
                                                    ),
                                                overflow: TextOverflow.ellipsis,
                                                maxLines: 2,
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
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
                                                    onChanged: (value) {
                                                      context
                                                          .read<LocaleCubit>()
                                                          .toggleLocale();
                                                    },
                                                    trackOutlineColor:
                                                        WidgetStateProperty.resolveWith(
                                                          (states) => AppColors
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
                                            onTap: () {
                                              context
                                                  .read<LocaleCubit>()
                                                  .toggleLocale();
                                            },
                                          ),
                                          Divider(),
                                          ListTile(
                                            onTap: () {
                                              context.push('/ProfileScreen');
                                            },
                                            leading: const Icon(Icons.person),
                                            title: Text(
                                              localizations.profile,
                                              style: AppTextStyles.bold16,
                                            ),
                                          ),
                                          Divider(),
                                          ListTile(
                                            onTap: () async {
                                              context.pop();
                                              await SelectDeliveryAreasBottomSheet.show(
                                                context,
                                              );
                                            },
                                            leading: const Icon(
                                              Icons.pin_drop_rounded,
                                            ),
                                            title: Text(
                                              localizations.deliveryAreas,
                                              style: AppTextStyles.bold16,
                                            ),
                                          ),
                                          Divider(),
                                          ListTile(
                                            leading: const Icon(
                                              Icons.star_half,
                                            ),
                                            title: Text(
                                              localizations.reviews,
                                              style: AppTextStyles.bold16,
                                            ),
                                          ),
                                          Divider(),
                                          ListTile(
                                            leading: const Icon(
                                              Icons.question_mark,
                                            ),
                                            title: Text(
                                              localizations.faq,
                                              style: AppTextStyles.bold16,
                                            ),
                                          ),
                                          Divider(),
                                          ListTile(
                                            leading: const Icon(
                                              Icons.support_agent_rounded,
                                            ),
                                            title: Text(
                                              localizations.support,
                                              style: AppTextStyles.bold16,
                                            ),
                                          ),
                                          Divider(),
                                          ListTile(
                                            leading: const Icon(
                                              Icons.policy_rounded,
                                            ),
                                            title: Text(
                                              localizations.privecyPolicy,
                                              style: AppTextStyles.bold16,
                                            ),
                                          ),
                                          Divider(),
                                          ListTile(
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
                                } else {
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
                                          context.read<AuthCubit>().logout();
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
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  body: screens[cubit.currentIndex],
                  bottomNavigationBar: Directionality(
                    textDirection: Directionality.of(context),
                    child: Container(
                      height: 100,
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

                          final indicatorWidth = 65.0;
                          final leftPos =
                              logicalIndex * itemWidth +
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
          );
        },
      ),
    );
  }
}

class AppLayoutAppBar extends StatefulWidget {
  const AppLayoutAppBar({
    super.key,
    required this.localizations,
    required this.isLoggedIn,
  });

  final AppLocalizations localizations;
  final bool isLoggedIn;

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
      actions: [SizedBox.shrink()],
      title: Directionality(
        textDirection: TextDirection.rtl,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            const Spacer(),
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
