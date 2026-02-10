import 'dart:developer';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/loading_screen.dart';
import '../../../../core/widgets/text_form.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../addresses/presentation/address_form_sheet.dart';
import '../../../auth/data/models/user_profile_model.dart';
import '../../../auth/manager/auth_cubit.dart';
import '../../../../core/utils/secure_storage_service.dart';
import '../../../../core/style/app_colors.dart';
import '../../../../core/style/text_styles.dart';
import '../../../../l10n/manager/locale_cubit.dart';
import '../../../auth/manager/auth_state.dart';
import '../../../orders/presentation/orders_list_screen.dart';
import '../../../orders/presentation/widgets/create_order_sheet.dart';
import '../manager/home_cubit.dart';

class HomeLayout extends StatefulWidget {
  const HomeLayout({super.key});

  @override
  State<HomeLayout> createState() => _HomeLayoutState();
}

class _HomeLayoutState extends State<HomeLayout> {
  late Future<UserProfileModel?> _userProfileFuture;

  @override
  void initState() {
    super.initState();
    _userProfileFuture = _loadUserProfile();
    // if(shouldShowNotificationDialog==true){
    //   WidgetsBinding.instance.addPostFrameCallback((_) {
    //     showNotificationsDialog(context, kUserId);
    //   });
    // }
  }

  Future<UserProfileModel?> _loadUserProfile() async {
    final userProfileJson = await SecureStorageService().getUserProfile();
    if (userProfileJson != null) {
      if (userProfileJson['phone'] == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _showPhoneNumberBottomSheet(context);
          }
        });
      }
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
    final scaffoldKey = GlobalKey<ScaffoldState>();

    // This is needed inside the build method as it depends on context.
    // It was previously in a separate method but build context should not be passed around.
    final localizations = AppLocalizations.of(context)!;

    final screens = const [OrdersListScreen(), SizedBox.shrink()];

    return MultiBlocProvider(
      providers: [
        BlocProvider<HomeCubit>(create: (_) => HomeCubit()),
        // BlocProvider(create: (context) => AdsCubit()..getHomeAds()),
      ],
      child: BlocBuilder<HomeCubit, HomeState>(
        builder: (context, state) {
          final cubit = context.read<HomeCubit>();
          final itemsList = [
            BottomNavigationBarItem(
              icon: Icon(Icons.receipt_long),
              activeIcon: Icon(Icons.receipt),
              label: localizations.orders,
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.notifications_none_rounded),
              activeIcon: Icon(Icons.notifications),
              label: localizations.notifications,
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
                        scaffoldKey: scaffoldKey,
                        localizations: localizations,
                      ),
                    ),
                  ),
                  floatingActionButtonLocation:
                      FloatingActionButtonLocation.centerDocked,
                  floatingActionButton: FloatingActionButton.large(
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => const CreateOrderBottomSheet(),
                      );
                    },
                    backgroundColor: AppColors.kSecondaryColor,
                    shape: const CircleBorder(),
                    child: SvgPicture.asset(
                      'assets/images/go.svg',
                      fit: BoxFit.scaleDown,
                      height: 40,
                    ),
                  ),
                  endDrawer: Drawer(
                    backgroundColor: AppColors.kBackgroundColor,
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: Column(
                          children: [
                            // Scrollable part
                            Expanded(
                              child: ListView(
                                padding: EdgeInsets.zero,
                                children: [
                                  DrawerHeader(
                                    decoration: BoxDecoration(
                                      color: AppColors.kSecondaryColor,
                                    ),
                                    child: GestureDetector(
                                      onTap: () {
                                        if (profile != null) {
                                          context.push('/MyDataPage');
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
                                                      color: Colors.white,
                                                    ),
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
                                            leading: const Icon(
                                              Icons
                                                  .account_balance_wallet_rounded,
                                            ),
                                            title: Text(
                                              localizations.wallet,
                                              style: AppTextStyles.bold16,
                                            ),
                                          ),
                                          Divider(),ListTile(
                                            onTap: () {
                                              context.push('/addressesManagement');
                                            },
                                            leading: const Icon(
                                              Icons
                                                  .location_pin,
                                            ),
                                            title: Text(
                                              localizations.address,
                                              style: AppTextStyles.bold16,
                                            ),
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
                                          // ListTile(
                                          //   onTap: () async {
                                          //       showModalBottomSheet(
                                          //         context: context,
                                          //         isScrollControlled: true,
                                          //         backgroundColor: Colors.transparent,
                                          //         builder: (_) => const AddressFormBottomSheet(),
                                          //       );
                                          //   },
                                          //   leading: const Icon(
                                          //     Icons.pin_drop_rounded,
                                          //   ),
                                          //   title: Text(
                                          //     localizations.address,
                                          //     style: AppTextStyles.bold16,
                                          //   ),
                                          // ),
                                          // Divider(),
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
                                  return SizedBox.shrink();
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
                                        if (index == 4) {
                                          scaffoldKey.currentState
                                              ?.openEndDrawer();
                                          return; // Prevent navigation to menu tab
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

  Widget _buildNavIcon({
    required int index,
    required int cubitIndex,
    required String icon,
    required String selectedIcon,
  }) {
    final isSelected = index == cubitIndex;
    return SvgPicture.asset(isSelected ? selectedIcon : icon);
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
                  validator: (v) {
                    if (v!.isEmpty) {
                      return AppLocalizations.of(context)!.enterPhoneNumber;
                    } else if (v.length != 11) {
                      return AppLocalizations.of(context)!.invalidPhoneNumber;
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(height: 20),
              AppCustomButton(
                onPressed: () {
                  formKey.currentState!.validate();
                  if (formKey.currentState!.validate()) {
                    // context.read<AuthCubit>().updateProfile(
                    //   phone: phoneController.text.toString(),
                    // );
                    log(phoneController.text.toString());
                    Navigator.pop(context);
                  }
                },
                text: localizations.confirm,
              ),
              const SizedBox(height: 10),
              Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: Text(
                    localizations.maybeLater,
                    style: AppTextStyles.bold16,
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }
}

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

    // App logo fade out/in animation
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

    // Company logo fade in/out animation
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

    // Company logo scale animation
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
        textDirection: AppLocalizations.of(context)!.localeName == 'ar'
            ? TextDirection.ltr
            : TextDirection.rtl,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            // NotificationButton(userId: kUserId),
            // InkWell(
            //   onTap: () {
            //     context.push('/PointsPage');
            //   },
            //   customBorder: const RoundedRectangleBorder(
            //     borderRadius: BorderRadius.only(
            //       topLeft: Radius.circular(5),
            //       bottomLeft: Radius.circular(25),
            //       topRight: Radius.circular(25),
            //       bottomRight: Radius.circular(25),
            //     ),
            //   ),
            //   child: Container(
            //     height: 38,
            //     width: 76,
            //     decoration: BoxDecoration(
            //       borderRadius: BorderRadius.only(
            //         topLeft: Radius.circular(5),
            //         bottomLeft: Radius.circular(25),
            //         topRight: Radius.circular(25),
            //         bottomRight: Radius.circular(25),
            //       ),
            //       border: Border.all(color: Colors.grey.shade300, width: 1),
            //     ),
            //     child: Row(
            //       mainAxisAlignment: MainAxisAlignment.center,
            //       spacing: 5,
            //       children: [
            //         SvgPicture.asset('assets/images/appbar/points.svg'),
            //         Text(
            //           widget.localizations.points,
            //           style: AppTextStyles.bold14.copyWith(fontSize: 11),
            //         ),
            //       ],
            //     ),
            //   ),
            // ),
            CircleAvatar(
              radius: 20,
              backgroundColor: Colors.grey.shade200,
              child: IconButton(
                icon: Icon(Icons.menu),
                color: Colors.grey.shade700,
                onPressed: () {
                  widget.scaffoldKey.currentState?.openEndDrawer();
                },
              ),
            ),

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
                          // App logo (fades out during animation)
                          Opacity(
                            opacity: _appLogoOpacity.value,
                            child: child!,
                          ),
                          // Company logo overlay (fades in during animation)
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
                  height: 40,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
